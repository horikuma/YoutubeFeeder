#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE_PATH = REPO_ROOT / "llm-cache" / "issue-defaults.json"
DEFAULT_SESSION_CONTEXT_PATH = REPO_ROOT / "llm-cache" / "session-context.json"


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


def read_session_main_branch(path_text: str | None = None) -> str | None:
    path = Path(path_text or DEFAULT_SESSION_CONTEXT_PATH).expanduser().resolve()
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Session context cache is invalid JSON: {path}: {exc}") from exc
    branch = payload.get("sessionMainBranch")
    if branch is None:
        return None
    return str(branch)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub pull request through PyGithub.")
    parser.add_argument("--repo")
    parser.add_argument("--base")
    parser.add_argument("--head", required=True)
    parser.add_argument("--title", required=True)
    body_group = parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--body")
    body_group.add_argument("--body-file")
    parser.add_argument("--assignee")
    parser.add_argument("--cache-file", default=str(DEFAULT_CACHE_PATH))
    parser.add_argument("--session-context-file", default=str(DEFAULT_SESSION_CONTEXT_PATH))
    parser.add_argument("--config")
    args = parser.parse_args()

    defaults_module = load_issue_defaults_module()
    if not args.repo:
        args.repo = defaults_module.resolve_cached_repo(args.cache_file)
    if not args.repo:
        parser.error("--repo or cache-file repo is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if not args.base:
        args.base = read_session_main_branch(args.session_context_file)
    if not args.base:
        args.base = "main"
    if not args.assignee:
        args.assignee = defaults_module.resolve_cached_assignee_login(args.cache_file)
    github_app = load_github_app_module()
    if not args.assignee:
        args.assignee = github_app.get_default_assignee(args.repo, args.config)
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
    pull_request = repository.create_pull(
        title=args.title,
        body=read_body(args),
        base=args.base,
        head=args.head,
    )
    github_app.add_assignees_to_issue(
        repo_slug=args.repo,
        issue_number=pull_request.number,
        assignees=[args.assignee],
        config_path=args.config,
    )
    json.dump(pull_request.raw_data, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
