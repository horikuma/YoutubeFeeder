#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path


CHECKBOX_PATTERN = re.compile(r"^(\d+)\.\s+\[([ xX])\]\s+(.*)$")
BULLET_CHECKBOX_PATTERN = re.compile(r"^-\s+\[([ xX])\]\s+(\d+)\.\s+(.*)$")
SECTION_NAMES = ("Issue詳細化ToDo", "Issue外ToDo", "IssueToDo")


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
    parser = argparse.ArgumentParser(
        description="Inspect or update checkbox items in a GitHub issue Description."
    )
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument("--get", action="store_true")
    mode_group.add_argument("--check", action="store_true")
    parser.add_argument("--repo")
    parser.add_argument("--issue-number", type=int, required=True)
    parser.add_argument("--todo-section", choices=SECTION_NAMES, required=True)
    parser.add_argument("--todo-number", type=int)
    parser.add_argument("--body-file", required=True)
    parser.add_argument(
        "--cache-file",
        default=str(Path(__file__).resolve().parents[2] / "llm-cache" / "issue-defaults.json"),
    )
    parser.add_argument("--config")
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
    if args.check and args.todo_number is None:
        parser.error("--check requires --todo-number")
    if args.get and args.todo_number is not None:
        parser.error("--get must not use --todo-number")
    if args.todo_number is not None and args.todo_number <= 0:
        parser.error("--todo-number must be positive")
    return args


def find_section_range(lines: list[str], section_name: str) -> tuple[int, int]:
    heading = f"### {section_name}"
    start_index = -1
    for index, line in enumerate(lines):
        if line == heading:
            start_index = index + 1
            break
    if start_index == -1:
        raise SystemExit(f"Section not found in issue body: {section_name}")

    end_index = len(lines)
    for index in range(start_index, len(lines)):
        if lines[index].startswith("### ") or lines[index].startswith("## "):
            end_index = index
            break
    return start_index, end_index


def mark_todo_completed(lines: list[str], *, section_name: str, todo_number: int) -> tuple[list[str], dict]:
    start_index, end_index = find_section_range(lines, section_name)
    found_index = None
    found_line = None
    found_state = None
    seen_items = 0

    for index in range(start_index, end_index):
        match = CHECKBOX_PATTERN.match(lines[index])
        bullet_match = BULLET_CHECKBOX_PATTERN.match(lines[index])
        if match is None and bullet_match is None:
            continue
        seen_items += 1
        if match is not None:
            parsed_number = int(match.group(1))
            updated_line = f"{match.group(1)}. [x] {match.group(3)}"
            parsed_state = match.group(2).lower()
        else:
            assert bullet_match is not None
            parsed_number = int(bullet_match.group(2))
            updated_line = f"- [x] {bullet_match.group(2)}. {bullet_match.group(3)}"
            parsed_state = bullet_match.group(1).lower()

        if parsed_number != todo_number and seen_items != todo_number:
            continue
        found_index = index
        found_line = lines[index]
        found_state = parsed_state
        lines[index] = updated_line
        break

    if found_index is None or found_line is None or found_state is None:
        raise SystemExit(f"Todo item not found: section={section_name} number={todo_number}")

    return lines, {
        "section": section_name,
        "todo_number": todo_number,
        "previous_line": found_line,
        "updated_line": lines[found_index],
        "already_checked": found_state == "x",
    }


def find_next_todo(lines: list[str], *, section_name: str) -> dict | None:
    start_index, end_index = find_section_range(lines, section_name)
    seen_items = 0

    for index in range(start_index, end_index):
        match = CHECKBOX_PATTERN.match(lines[index])
        bullet_match = BULLET_CHECKBOX_PATTERN.match(lines[index])
        if match is None and bullet_match is None:
            continue
        seen_items += 1
        if match is not None:
            parsed_number = int(match.group(1))
            parsed_state = match.group(2).lower()
            text = match.group(3)
        else:
            assert bullet_match is not None
            parsed_number = int(bullet_match.group(2))
            parsed_state = bullet_match.group(1).lower()
            text = bullet_match.group(3)

        if parsed_state == "x":
            continue

        return {
            "section": section_name,
            "todo_number": parsed_number,
            "ordinal": seen_items,
            "line": lines[index],
            "text": text,
        }

    return None


def dump_payload(*, issue_number: int, issue, mode: str, change: dict | None = None, next_todo: dict | None = None) -> int:
    payload = {
        "issue_number": issue_number,
        "title": issue.title,
        "mode": mode,
        "body": issue.body,
    }
    if mode == "get":
        payload["next"] = next_todo
    if mode == "check":
        payload["change"] = change
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def read_body_file(path_text: str) -> tuple[Path, str]:
    path = Path(path_text).expanduser()
    return path, path.read_text(encoding="utf-8")


def write_body_file(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")


def update_issue_body_via_body_file(args: argparse.Namespace) -> object:
    command = [
        sys.executable,
        str(Path(__file__).with_name("issue-description-update.py")),
        "--issue-number",
        str(args.issue_number),
        "--body-file",
        args.body_file,
        "--cache-file",
        args.cache_file,
    ]
    if args.repo:
        command.extend(["--repo", args.repo])
    if args.config:
        command.extend(["--config", args.config])

    process = subprocess.run(command, capture_output=True, text=True, check=False)
    if process.returncode != 0:
        stderr = process.stderr.strip() or process.stdout.strip()
        raise SystemExit(stderr or "Failed to update issue body from body file")

    return json.loads(process.stdout)


def main() -> int:
    args = parse_args()
    github_app = load_github_app_module()
    repository = github_app.get_repository(args.repo, config_path=args.config)
    issue = repository.get_issue(number=args.issue_number)

    body_path, body = read_body_file(args.body_file)
    if not body:
        raise SystemExit("Issue body file is empty")
    remote_body = issue.body
    if remote_body is None:
        raise SystemExit("Issue body is empty")
    if body != remote_body:
        raise SystemExit("Issue body file does not match current remote issue body")

    if args.get:
        next_todo = find_next_todo(body.splitlines(), section_name=args.todo_section)
        return dump_payload(issue_number=args.issue_number, issue=issue, mode="get", next_todo=next_todo)

    trailing_newline = body.endswith("\n")
    assert args.todo_number is not None
    updated_lines, change = mark_todo_completed(
        body.splitlines(),
        section_name=args.todo_section,
        todo_number=args.todo_number,
    )
    updated_body = "\n".join(updated_lines)
    if trailing_newline:
        updated_body += "\n"
    write_body_file(body_path, updated_body)

    if updated_body != body:
        issue_payload = update_issue_body_via_body_file(args)
        issue = type("IssuePayload", (), issue_payload)

    return dump_payload(issue_number=args.issue_number, issue=issue, mode="check", change=change)


if __name__ == "__main__":
    raise SystemExit(main())
