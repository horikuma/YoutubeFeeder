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
    parser = argparse.ArgumentParser(description="Read or update a GitHub issue through PyGithub.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--repo")
    common.add_argument("--issue-number", type=int, required=True)
    common.add_argument("--config")
    common.add_argument(
        "--cache-file",
        default=str(Path(__file__).resolve().parents[2] / "llm-cache" / "issue-defaults.json"),
    )

    show_parser = subparsers.add_parser("show", parents=[common])
    show_parser.add_argument("--body-only", action="store_true")

    update_parser = subparsers.add_parser("update-body", parents=[common])
    update_group = update_parser.add_mutually_exclusive_group(required=False)
    update_group.add_argument("--body")
    update_group.add_argument("--body-file")
    update_parser.add_argument("--title")

    comment_parser = subparsers.add_parser("comment", parents=[common])
    comment_group = comment_parser.add_mutually_exclusive_group(required=True)
    comment_group.add_argument("--body")
    comment_group.add_argument("--body-file")

    args = parser.parse_args()

    if not args.repo:
        defaults_module = load_issue_defaults_module()
        args.repo = defaults_module.resolve_cached_repo(args.cache_file)
    if not args.repo:
        parser.error("--repo or cache-file repo is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if args.issue_number <= 0:
        parser.error("--issue-number must be positive")
    if args.command == "update-body" and args.body is None and args.body_file is None:
        parser.error("update-body requires --body/--body-file")
    return args


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None:
        return args.body
    with open(args.body_file, "r", encoding="utf-8") as handle:
        return handle.read()


def main() -> int:
    args = parse_args()
    github_app = load_github_app_module()
    repository = github_app.get_repository(args.repo, config_path=args.config)
    issue = repository.get_issue(number=args.issue_number)

    if args.command == "show":
        if args.body_only:
            sys.stdout.write(issue.body or "")
        else:
            json.dump(issue.raw_data, sys.stdout, ensure_ascii=False, indent=2)
            sys.stdout.write("\n")
        return 0

    if args.command == "update-body":
        kwargs = {}
        if args.title is not None:
            kwargs["title"] = args.title
        if args.body is not None or args.body_file is not None:
            kwargs["body"] = read_body(args)
        issue.edit(**kwargs)
        issue = repository.get_issue(number=args.issue_number)
        json.dump(issue.raw_data, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    if args.command == "comment":
        comment = issue.create_comment(read_body(args))
        json.dump(comment.raw_data, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    raise SystemExit(f"unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
