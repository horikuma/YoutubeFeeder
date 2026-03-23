#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import sys

from github_app import get_repository


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch repository issues through PyGithub using GitHub App credentials."
    )
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--state", default="open", choices=("open", "closed", "all"))
    parser.add_argument("--per-page", type=int, default=100)
    parser.add_argument("--page", type=int, default=1)
    parser.add_argument("--include-pulls", action="store_true")
    parser.add_argument(
        "--config",
        default=os.getenv("GITHUB_APP_CONFIG_PATH"),
    )
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
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
    repository = get_repository(args.repo, config_path=args.config, per_page=args.per_page)
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
