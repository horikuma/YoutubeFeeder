#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE_PATH = REPO_ROOT / "temp-llm" / "github" / "issue-defaults.json"


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
        description="Resolve and cache default GitHub assignee/project settings."
    )
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"))
    parser.add_argument("--assignee", default="horikuma")
    parser.add_argument("--project-title", default="YoutubeFeeder")
    parser.add_argument("--project-owner")
    parser.add_argument("--cache-file", default=str(DEFAULT_CACHE_PATH))
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--config", default=os.getenv("GITHUB_APP_CONFIG_PATH"))
    args = parser.parse_args()

    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if "/" not in args.repo:
        parser.error("repository must be in owner/repo format")
    if not args.project_owner:
        args.project_owner = args.repo.split("/", 1)[0]
    return args


def cache_matches(
    payload: dict,
    *,
    repo: str,
    assignee: str,
    project_owner: str,
    project_title: str,
) -> bool:
    return (
        payload.get("repo") == repo
        and payload.get("assignee", {}).get("login") == assignee
        and payload.get("project", {}).get("owner") == project_owner
        and payload.get("project", {}).get("title") == project_title
        and bool(payload.get("project", {}).get("id"))
    )


def read_cache(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"GitHub defaults cache is invalid JSON: {path}: {exc}") from exc


def write_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def resolve_assignee(repository, login: str) -> dict:
    for assignee in repository.get_assignees():
        if assignee.login == login:
            return {
                "login": assignee.login,
                "id": assignee.id,
                "node_id": assignee.node_id,
            }
    raise SystemExit(f"Default assignee not found in repository assignees: {login}")


def run_gh_project_query(project_owner: str) -> list[dict]:
    query = """
query($login: String!) {
  user(login: $login) {
    projectsV2(first: 100) {
      nodes {
        id
        title
        number
      }
    }
  }
  organization(login: $login) {
    projectsV2(first: 100) {
      nodes {
        id
        title
        number
      }
    }
  }
}
""".strip()

    command = [
        "gh",
        "api",
        "graphql",
        "-f",
        f"query={query}",
        "-F",
        f"login={project_owner}",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)

    if result.returncode != 0:
        stderr = result.stderr.strip()
        if "read:project" in stderr:
            raise SystemExit(
                "GitHub project defaults could not be fetched because gh auth lacks "
                "`read:project` scope. Run `gh auth refresh -s read:project,project` once, "
                "then rerun `scripts/resolve-github-defaults` to seed the cache."
            )
        raise SystemExit(f"Failed to query GitHub projects through gh: {stderr or result.stdout.strip()}")

    payload = json.loads(result.stdout)
    data = payload.get("data") or {}
    projects: list[dict] = []
    for key in ("user", "organization"):
        subject = data.get(key)
        if not subject:
            continue
        projects.extend(subject.get("projectsV2", {}).get("nodes", []))
    return projects


def resolve_project(project_owner: str, project_title: str) -> dict:
    matches = [project for project in run_gh_project_query(project_owner) if project.get("title") == project_title]

    if not matches:
        raise SystemExit(f"GitHub project not found: owner={project_owner} title={project_title}")
    if len(matches) > 1:
        numbers = ", ".join(str(project.get("number")) for project in matches)
        raise SystemExit(
            f"GitHub project title is ambiguous: owner={project_owner} title={project_title} numbers={numbers}"
        )

    match = matches[0]
    return {
        "owner": project_owner,
        "title": project_title,
        "id": match.get("id"),
        "number": match.get("number"),
    }


def resolve_defaults(
    *,
    repo: str,
    assignee_login: str,
    project_owner: str,
    project_title: str,
    cache_file: Path,
    refresh: bool,
    config_path: str | None,
) -> dict:
    if not refresh:
        cached = read_cache(cache_file)
        if cached and cache_matches(
            cached,
            repo=repo,
            assignee=assignee_login,
            project_owner=project_owner,
            project_title=project_title,
        ):
            return cached

    github_app = load_github_app_module()
    repository = github_app.get_repository(repo, config_path=config_path)
    payload = {
        "repo": repo,
        "resolvedAt": datetime.now(timezone.utc).isoformat(),
        "assignee": resolve_assignee(repository, assignee_login),
        "project": resolve_project(project_owner, project_title),
    }
    write_cache(cache_file, payload)
    return payload


def main() -> int:
    args = parse_args()
    payload = resolve_defaults(
        repo=args.repo,
        assignee_login=args.assignee,
        project_owner=args.project_owner,
        project_title=args.project_title,
        cache_file=Path(args.cache_file).expanduser().resolve(),
        refresh=args.refresh,
        config_path=args.config,
    )
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
