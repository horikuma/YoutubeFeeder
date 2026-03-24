#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE_PATH = REPO_ROOT / "temp-llm" / "github" / "issue-defaults.json"


def load_module(filename: str, module_name: str):
    module_path = Path(__file__).with_name(filename)
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub issue with cached default assignee/project.")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--title", required=True)
    body_group = parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--body")
    body_group.add_argument("--body-file")
    parser.add_argument("--assignee")
    parser.add_argument("--project-title")
    parser.add_argument("--project-owner")
    parser.add_argument("--cache-file", default=str(DEFAULT_CACHE_PATH))
    parser.add_argument("--refresh-defaults", action="store_true")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    github_app = load_module("github-app.py", "github_app")
    if not args.assignee:
        args.assignee = github_app.get_default_assignee(args.repo, args.config)
    project_defaults = github_app.get_project_settings(args.repo, args.config)
    if not args.project_owner:
        args.project_owner = project_defaults["owner"]
    if not args.project_title:
        args.project_title = project_defaults["title"]
    return args


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None:
        return args.body
    return Path(args.body_file).read_text(encoding="utf-8")


def main() -> int:
    args = parse_args()
    defaults_module = load_module("issue-defaults.py", "issue_defaults")
    github_app = load_module("github-app.py", "github_app")

    defaults = defaults_module.resolve_defaults(
        repo=args.repo,
        assignee_login=args.assignee,
        project_owner=args.project_owner,
        project_title=args.project_title,
        cache_file=Path(args.cache_file).expanduser().resolve(),
        refresh=args.refresh_defaults,
        config_path=args.config,
    )
    token = github_app.get_installation_token(args.repo, config_path=args.config)
    owner, repo_name = args.repo.split("/", 1)

    issue = github_app.json_request(
        f"https://api.github.com/repos/{owner}/{repo_name}/issues",
        method="POST",
        token=token,
        payload={
            "title": args.title,
            "body": read_body(args),
            "assignees": [defaults["assignee"]["login"]],
        },
    )

    github_app.add_content_to_project(
        repo_slug=args.repo,
        content_node_id=issue["node_id"],
        content_url=issue["html_url"],
        project=defaults["project"],
        config_path=args.config,
    )

    sys.stdout.write(json.dumps(issue, ensure_ascii=False, indent=2))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
