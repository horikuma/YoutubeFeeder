#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE_PATH = REPO_ROOT / "llm-cache" / "issue-defaults.json"


def load_module(filename: str, module_name: str):
    module_path = Path(__file__).with_name(filename)
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ensure or update a GitHub project number field for an Issue or PR.")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--field-name", default="LLM所要時間")
    parser.add_argument("--value", type=float, required=True)
    parser.add_argument("--assignee")
    parser.add_argument("--project-title")
    parser.add_argument("--project-owner")
    parser.add_argument("--cache-file", default=str(DEFAULT_CACHE_PATH))
    parser.add_argument("--refresh-defaults", action="store_true")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))

    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--content-url")
    target.add_argument("--issue-number", type=int)
    target.add_argument("--pull-request-number", type=int)
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if args.issue_number is not None and args.issue_number <= 0:
        parser.error("--issue-number must be positive")
    if args.pull_request_number is not None and args.pull_request_number <= 0:
        parser.error("--pull-request-number must be positive")
    return args


def resolve_content_url(args: argparse.Namespace) -> str:
    if args.content_url:
        return args.content_url
    owner, repo_name = args.repo.split("/", 1)
    if args.issue_number is not None:
        return f"https://github.com/{owner}/{repo_name}/issues/{args.issue_number}"
    return f"https://github.com/{owner}/{repo_name}/pull/{args.pull_request_number}"


def main() -> int:
    args = parse_args()
    defaults_module = load_module("issue-defaults.py", "issue_defaults")
    github_app = load_module("github-app.py", "github_app")

    assignee = args.assignee or github_app.get_default_assignee(args.repo, args.config)
    project_defaults = github_app.get_project_settings(args.repo, args.config)
    project_owner = args.project_owner or project_defaults["owner"]
    project_title = args.project_title or project_defaults["title"]

    defaults = defaults_module.resolve_defaults(
        repo=args.repo,
        assignee_login=assignee,
        project_owner=project_owner,
        project_title=project_title,
        cache_file=Path(args.cache_file).expanduser().resolve(),
        refresh=args.refresh_defaults,
        config_path=args.config,
    )
    result = github_app.set_project_number_field_value(
        repo_slug=args.repo,
        project=defaults["project"],
        content_url=resolve_content_url(args),
        field_name=args.field_name,
        value=args.value,
        config_path=args.config,
    )
    payload = {
        "project": defaults["project"],
        "field": result["field"],
        "item": result["item"],
        "value": args.value,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
