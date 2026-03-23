#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import sys

from github_app import get_repository


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read or update a GitHub issue through PyGithub.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    common.add_argument("--issue-number", type=int, required=True)
    common.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))

    show_parser = subparsers.add_parser("show", parents=[common])
    show_parser.add_argument("--body-only", action="store_true")

    update_parser = subparsers.add_parser("update-body", parents=[common])
    update_group = update_parser.add_mutually_exclusive_group(required=True)
    update_group.add_argument("--body")
    update_group.add_argument("--body-file")

    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if args.issue_number <= 0:
        parser.error("--issue-number must be positive")
    return args


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None:
        return args.body
    with open(args.body_file, "r", encoding="utf-8") as handle:
        return handle.read()


def main() -> int:
    args = parse_args()
    repository = get_repository(args.repo, config_path=args.config)
    issue = repository.get_issue(number=args.issue_number)

    if args.command == "show":
        if args.body_only:
            sys.stdout.write(issue.body or "")
            if issue.body:
                sys.stdout.write("\n")
        else:
            json.dump(issue.raw_data, sys.stdout, ensure_ascii=False, indent=2)
            sys.stdout.write("\n")
        return 0

    if args.command == "update-body":
        new_body = read_body(args)
        issue.edit(body=new_body)
        issue = repository.get_issue(number=args.issue_number)
        json.dump(issue.raw_data, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    raise SystemExit(f"unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
