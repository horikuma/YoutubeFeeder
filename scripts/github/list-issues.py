#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path


def load_github_app_module():
    module_path = Path(__file__).with_name("github-app.py")
    spec = importlib.util.spec_from_file_location("github_app", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load GitHub App module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_issue_defaults_module():
    module_path = Path(__file__).with_name("issue-defaults.py")
    spec = importlib.util.spec_from_file_location("issue_defaults", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load issue defaults module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch repository issues through PyGithub using GitHub App credentials."
    )
    parser.add_argument("--repo")
    parser.add_argument("--state", default="open", choices=("open", "closed", "all"))
    parser.add_argument("--per-page", type=int, default=100)
    parser.add_argument("--page", type=int, default=1)
    parser.add_argument("--include-pulls", action="store_true")
    parser.add_argument(
        "--config",
        default=None,
    )
    parser.add_argument(
        "--cache-file",
        default=str(Path(__file__).resolve().parents[2] / "llm-cache" / "issue-defaults.json"),
    )
    args = parser.parse_args()

    if not args.repo:
        defaults_module = load_issue_defaults_module()
        args.repo = defaults_module.resolve_cached_repo(args.cache_file)
    if not args.repo:
        parser.error("--repo or cache-file repo is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if args.per_page <= 0:
        parser.error("--per-page must be positive")
    if args.page <= 0:
        parser.error("--page must be positive")
    return args


def issue_to_json(issue) -> dict:
    return issue.raw_data


def main() -> int:
    args = parse_args()
    github_app = load_github_app_module()
    repository = github_app.get_repository(args.repo, config_path=args.config, per_page=args.per_page)
    issues = repository.get_issues(state=args.state)
    page_items = issues.get_page(args.page - 1)

    if args.include_pulls:
        result = [issue_to_json(issue) for issue in page_items]
    else:
        result = [issue_to_json(issue) for issue in page_items if issue.pull_request is None]

    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
