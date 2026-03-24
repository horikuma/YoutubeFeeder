#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


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
    return Path(args.body_file).read_text(encoding="utf-8")


def json_request(url: str, *, method: str, token: str, payload: dict | None = None) -> dict:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")

    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"GitHub API request failed: {method} {url}: {exc.code} {detail}") from exc


def graphql_request(token: str, *, query: str, variables: dict) -> dict:
    payload = json_request(
        "https://api.github.com/graphql",
        method="POST",
        token=token,
        payload={"query": query, "variables": variables},
    )
    if payload.get("errors"):
        raise SystemExit(f"GitHub GraphQL request failed: {json.dumps(payload['errors'], ensure_ascii=False)}")
    return payload["data"]


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

    issue = json_request(
        f"https://api.github.com/repos/{owner}/{repo_name}/issues",
        method="POST",
        token=token,
        payload={
            "title": args.title,
            "body": read_body(args),
            "assignees": [defaults["assignee"]["login"]],
        },
    )

    graphql_request(
        token,
        query="""
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
    item {
      id
    }
  }
}
""".strip(),
        variables={
            "projectId": defaults["project"]["id"],
            "contentId": issue["node_id"],
        },
    )

    json.dump(issue, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
