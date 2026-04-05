#!/usr/bin/env python3

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path


CHECKBOX_PATTERN = re.compile(r"^(\d+)\.\s+\[([ xX])\]\s+(.*)$")
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
        description="Mark a checkbox item in a GitHub issue Description as completed."
    )
    parser.add_argument("--repo")
    parser.add_argument("--issue-number", type=int, required=True)
    parser.add_argument("--todo-section", choices=SECTION_NAMES, required=True)
    parser.add_argument("--todo-number", type=int, required=True)
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
    if args.todo_number <= 0:
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
        if match is None:
            continue
        seen_items += 1
        if seen_items != todo_number:
            continue
        found_index = index
        found_line = lines[index]
        found_state = match.group(2).lower()
        lines[index] = f"{match.group(1)}. [x] {match.group(3)}"
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


def dump_payload(*, issue_number: int, issue, change: dict) -> int:
    payload = {
        "issue_number": issue_number,
        "title": issue.title,
        "change": change,
        "body": issue.body,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def main() -> int:
    args = parse_args()
    github_app = load_github_app_module()
    repository = github_app.get_repository(args.repo, config_path=args.config)
    issue = repository.get_issue(number=args.issue_number)

    body = issue.body
    if not body:
        raise SystemExit("Issue body is empty")

    trailing_newline = body.endswith("\n")
    updated_lines, change = mark_todo_completed(
        body.splitlines(),
        section_name=args.todo_section,
        todo_number=args.todo_number,
    )
    updated_body = "\n".join(updated_lines)
    if trailing_newline:
        updated_body += "\n"

    if updated_body != body:
        issue.edit(body=updated_body)
        issue = repository.get_issue(number=args.issue_number)

    return dump_payload(issue_number=args.issue_number, issue=issue, change=change)


if __name__ == "__main__":
    raise SystemExit(main())
