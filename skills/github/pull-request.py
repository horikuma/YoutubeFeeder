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


def load_github_app_module():
    module_path = Path(__file__).with_name("github-app.py")
    spec = importlib.util.spec_from_file_location("github_app", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load GitHub App module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub pull request through PyGithub.")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--base", default="main")
    parser.add_argument("--head", required=True)
    parser.add_argument("--title", required=True)
    body_group = parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--body")
    body_group.add_argument("--body-file")
    parser.add_argument("--assignee", default="horikuma")
    parser.add_argument("--project-title", default="YoutubeFeeder")
    parser.add_argument("--project-owner")
    parser.add_argument("--cache-file", default=str(DEFAULT_CACHE_PATH))
    parser.add_argument("--refresh-defaults", action="store_true")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if not args.project_owner:
        args.project_owner = args.repo.split("/", 1)[0]
    return args


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None:
        return args.body
    with open(args.body_file, "r", encoding="utf-8") as handle:
        return handle.read()


def main() -> int:
    args = parse_args()
    github_app = load_github_app_module()
    defaults_module = load_issue_defaults_module()
    defaults = defaults_module.resolve_defaults(
        repo=args.repo,
        assignee_login=args.assignee,
        project_owner=args.project_owner,
        project_title=args.project_title,
        cache_file=Path(args.cache_file).expanduser().resolve(),
        refresh=args.refresh_defaults,
        config_path=args.config,
    )
    repository = github_app.get_repository(args.repo, config_path=args.config)
    pull_request = repository.create_pull(
        title=args.title,
        body=read_body(args),
        base=args.base,
        head=args.head,
    )
    github_app.add_assignees_to_issue(
        repo_slug=args.repo,
        issue_number=pull_request.number,
        assignees=[defaults["assignee"]["login"]],
        config_path=args.config,
    )
    github_app.add_content_to_project(
        repo_slug=args.repo,
        content_node_id=pull_request.node_id,
        content_url=pull_request.html_url,
        project=defaults["project"],
        config_path=args.config,
    )
    json.dump(pull_request.raw_data, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def load_issue_defaults_module():
    module_path = Path(__file__).with_name("issue-defaults.py")
    spec = importlib.util.spec_from_file_location("issue_defaults", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load issue defaults module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    raise SystemExit(main())
