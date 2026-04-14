#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import shutil
from dataclasses import dataclass
from pathlib import Path


EXIT_WORKTREE_DIRTY = 10
EXIT_CHECKOUT_FAILED = 11
EXIT_FETCH_FAILED = 12
EXIT_REMOTE_REF_MISSING = 13
EXIT_MERGE_BASE_FAILED = 14
EXIT_RESET_FAILED = 15
EXIT_PULL_FAILED = 16
EXIT_BRANCH_CLEANUP_FAILED = 17


@dataclass
class GitMainSyncError(Exception):
    exit_code: int
    message: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Synchronize local main with origin/main through checkout, fetch, "
            "optional merge-base reset, ff-only pull, and cleanup of local "
            "branches whose PRs are merged."
        )
    )
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[2]),
        help="target repository root; defaults to this repository",
    )
    parser.add_argument("--branch", default="main", help="local branch to synchronize")
    parser.add_argument("--remote", default="origin", help="remote name to compare against")
    return parser.parse_args()


def run_git(
    repo_root: Path,
    *args: str,
    check_code: int | None = None,
    capture_output: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        text=True,
        capture_output=capture_output,
        check=False,
    )
    if check_code is not None and result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or "git command failed"
        raise GitMainSyncError(check_code, f"{' '.join(args)}: {detail}")
    return result


def ensure_clean_worktree(repo_root: Path) -> None:
    result = run_git(repo_root, "status", "--short")
    if result.returncode != 0:
        detail = (result.stderr or "").strip() or (result.stdout or "").strip() or "git status failed"
        raise GitMainSyncError(EXIT_CHECKOUT_FAILED, detail)
    if result.stdout.strip():
        raise GitMainSyncError(
            EXIT_WORKTREE_DIRTY,
            "working tree is dirty; checkout/reset would be unsafe",
        )


def rev_parse(repo_root: Path, ref: str, *, exit_code: int) -> str:
    result = run_git(repo_root, "rev-parse", "--verify", ref, check_code=exit_code)
    return result.stdout.strip()


def determine_scenario(local_sha: str, remote_sha: str, merge_base_sha: str) -> str:
    if local_sha == remote_sha:
        return "up_to_date"
    if local_sha == merge_base_sha:
        return "behind"
    if remote_sha == merge_base_sha:
        return "ahead"
    return "diverged"


def run_gh(repo_root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    if shutil.which("gh") is None:
        raise GitMainSyncError(EXIT_BRANCH_CLEANUP_FAILED, "gh command not found")

    result = subprocess.run(
        ["gh", *args],
        text=True,
        capture_output=True,
        cwd=str(repo_root),
        check=False,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or "gh command failed"
        raise GitMainSyncError(EXIT_BRANCH_CLEANUP_FAILED, f"gh {' '.join(args)}: {detail}")
    return result


def list_local_branches(repo_root: Path) -> list[str]:
    result = run_git(repo_root, "for-each-ref", "refs/heads", "--format=%(refname:short)")
    if result.returncode != 0:
        detail = (result.stderr or "").strip() or (result.stdout or "").strip() or "git for-each-ref failed"
        raise GitMainSyncError(EXIT_BRANCH_CLEANUP_FAILED, detail)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def branch_has_merged_pull_request(repo_root: Path, branch_name: str) -> bool:
    result = run_gh(
        repo_root,
        "pr",
        "list",
        "--head",
        branch_name,
        "--state",
        "merged",
        "--limit",
        "1",
        "--json",
        "number",
    )
    try:
        payload = json.loads(result.stdout or "[]")
    except json.JSONDecodeError as error:
        raise GitMainSyncError(
            EXIT_BRANCH_CLEANUP_FAILED,
            f"gh pr list --head {branch_name}: invalid JSON: {error}",
        ) from error
    if not isinstance(payload, list):
        raise GitMainSyncError(
            EXIT_BRANCH_CLEANUP_FAILED,
            f"gh pr list --head {branch_name}: expected JSON list",
        )
    return bool(payload)


def delete_local_branch(repo_root: Path, branch_name: str) -> None:
    run_git(repo_root, "branch", "-D", branch_name, check_code=EXIT_BRANCH_CLEANUP_FAILED)


def cleanup_merged_branches(repo_root: Path, protected_branch: str) -> list[str]:
    deleted_branches: list[str] = []
    for branch_name in list_local_branches(repo_root):
        if branch_name == protected_branch:
            continue
        if not branch_has_merged_pull_request(repo_root, branch_name):
            continue
        delete_local_branch(repo_root, branch_name)
        deleted_branches.append(branch_name)
    return deleted_branches


def sync_main(repo_root: Path, branch: str, remote: str) -> dict:
    ensure_clean_worktree(repo_root)

    actions: list[str] = [f"checkout {branch}"]
    run_git(repo_root, "checkout", branch, check_code=EXIT_CHECKOUT_FAILED)

    actions.append(f"fetch {remote} {branch}")
    run_git(repo_root, "fetch", remote, branch, check_code=EXIT_FETCH_FAILED)

    local_ref = f"refs/heads/{branch}"
    remote_ref = f"refs/remotes/{remote}/{branch}"
    local_sha = rev_parse(repo_root, local_ref, exit_code=EXIT_CHECKOUT_FAILED)
    remote_sha = rev_parse(repo_root, remote_ref, exit_code=EXIT_REMOTE_REF_MISSING)

    merge_base_result = run_git(repo_root, "merge-base", local_ref, remote_ref)
    if merge_base_result.returncode != 0:
        detail = (merge_base_result.stderr or "").strip() or (merge_base_result.stdout or "").strip()
        raise GitMainSyncError(
            EXIT_MERGE_BASE_FAILED,
            f"merge-base {local_ref} {remote_ref}: {detail or 'failed'}",
        )
    merge_base_sha = merge_base_result.stdout.strip()
    if not merge_base_sha:
        raise GitMainSyncError(EXIT_MERGE_BASE_FAILED, "merge-base returned empty output")

    scenario = determine_scenario(local_sha, remote_sha, merge_base_sha)
    if scenario in {"ahead", "diverged"}:
        actions.append(f"reset --hard {merge_base_sha}")
        run_git(repo_root, "reset", "--hard", merge_base_sha, check_code=EXIT_RESET_FAILED)

    actions.append(f"pull --ff-only {remote} {branch}")
    run_git(repo_root, "pull", "--ff-only", remote, branch, check_code=EXIT_PULL_FAILED)

    deleted_branches = cleanup_merged_branches(repo_root, protected_branch=branch)
    for deleted_branch in deleted_branches:
        actions.append(f"branch -D {deleted_branch}")

    final_sha = rev_parse(repo_root, "HEAD", exit_code=EXIT_PULL_FAILED)
    return {
        "branch": branch,
        "remote": remote,
        "scenario": scenario,
        "actions": actions,
        "deleted_branches": deleted_branches,
        "before": {
            "local": local_sha,
            "remote": remote_sha,
            "merge_base": merge_base_sha,
        },
        "after": {
            "head": final_sha,
        },
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).expanduser().resolve()
    try:
        payload = sync_main(repo_root, args.branch, args.remote)
    except GitMainSyncError as error:
        print(error.message, file=sys.stderr)
        return error.exit_code

    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
