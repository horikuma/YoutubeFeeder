#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from github import Auth, Github, GithubIntegration


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
        default=os.getenv(
            "GITHUB_APP_CONFIG_PATH",
            str(Path(__file__).resolve().parents[2] / "secrets" / "github-app-bot.json"),
        ),
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


def load_config(config_path: str) -> tuple[str, str]:
    config_file = Path(config_path).expanduser().resolve()
    if not config_file.is_file():
        raise SystemExit(f"GitHub App config not found: {config_file}")

    payload = json.loads(config_file.read_text())
    app_id = payload.get("appId") or payload.get("app_id")
    private_key_path = payload.get("privateKeyPath") or payload.get("private_key_path")

    if not app_id or not private_key_path:
        raise SystemExit(f"Config must contain appId and privateKeyPath: {config_file}")

    private_key_file = Path(private_key_path)
    if not private_key_file.is_absolute():
        private_key_file = (config_file.parent / private_key_file).resolve()

    if not private_key_file.is_file():
        raise SystemExit(f"Private key not found: {private_key_file}")

    return str(app_id), private_key_file.read_text()


def issue_to_json(issue) -> dict:
    return issue.raw_data


def main() -> int:
    args = parse_args()
    owner, repo_name = args.repo.split("/", 1)
    app_id, private_key = load_config(args.config)

    auth = Auth.AppAuth(app_id, private_key)
    integration = GithubIntegration(auth=auth)
    installation = integration.get_repo_installation(owner, repo_name)
    access_token = integration.get_access_token(installation.id)
    github_client = Github(auth=Auth.Token(access_token.token), per_page=args.per_page)

    repository = github_client.get_repo(args.repo)
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
