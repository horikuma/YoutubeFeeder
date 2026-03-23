#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import sys

from github_app import get_repository


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub pull request through PyGithub.")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--base", default="main")
    parser.add_argument("--head", required=True)
    parser.add_argument("--title", required=True)
    body_group = parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--body")
    body_group.add_argument("--body-file")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    return args


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None:
        return args.body
    with open(args.body_file, "r", encoding="utf-8") as handle:
        return handle.read()


def main() -> int:
    args = parse_args()
    repository = get_repository(args.repo, config_path=args.config)
    pull_request = repository.create_pull(
        title=args.title,
        body=read_body(args),
        base=args.base,
        head=args.head,
    )
    json.dump(pull_request.raw_data, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
