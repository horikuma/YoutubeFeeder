#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import subprocess
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Record an issue work branch in a standardized GitHub issue comment."
    )
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--issue-number", type=int, required=True)
    parser.add_argument("--branch")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if args.issue_number <= 0:
        parser.error("--issue-number must be positive")
    return args


def resolve_branch_name(branch: str | None) -> str:
    if branch:
        resolved = branch.strip()
    else:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            stderr = result.stderr.strip() or result.stdout.strip()
            raise SystemExit(f"Failed to resolve current branch: {stderr}")
        resolved = result.stdout.strip()

    if not resolved or resolved == "HEAD":
        raise SystemExit("A non-detached branch name is required to register an issue branch")
    return resolved


def build_comment_body(branch: str) -> str:
    return "\n".join(
        [
            "作業ブランチを記録する。",
            "",
            f"- branch: `{branch}`",
        ]
    )


def find_existing_comment(issue, body: str):
    for comment in issue.get_comments():
        if (comment.body or "").strip() == body:
            return comment
    return None


def dump_payload(*, issue_number: int, branch: str, already_recorded: bool, comment) -> int:
    payload = {
        "issue_number": issue_number,
        "branch": branch,
        "already_recorded": already_recorded,
        "comment": comment.raw_data,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def main() -> int:
    args = parse_args()
    branch = resolve_branch_name(args.branch)
    body = build_comment_body(branch)

    github_app = load_github_app_module()
    repository = github_app.get_repository(args.repo, config_path=args.config)
    issue = repository.get_issue(number=args.issue_number)
    existing = find_existing_comment(issue, body)
    if existing is not None:
        return dump_payload(
            issue_number=args.issue_number,
            branch=branch,
            already_recorded=True,
            comment=existing,
        )

    comment = issue.create_comment(body)
    return dump_payload(
        issue_number=args.issue_number,
        branch=branch,
        already_recorded=False,
        comment=comment,
    )


if __name__ == "__main__":
    raise SystemExit(main())
