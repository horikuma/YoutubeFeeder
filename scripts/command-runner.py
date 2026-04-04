#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import os
import subprocess
import sys
from pathlib import Path


LLM_TEMP_FILENAME_PREFIX = re.compile(r"^\d{8}-\d{6}-")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resolve a command through skill metadata and execute its Python entry point."
    )
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("command")
    parser.add_argument("command_args", nargs=argparse.REMAINDER)
    return parser.parse_args()


def load_command_definition(repo_root: Path, command_name: str) -> tuple[Path, dict]:
    matches: list[tuple[Path, dict]] = []
    for meta_path in sorted(repo_root.glob("scripts/*/_meta.json")):
        payload = json.loads(meta_path.read_text(encoding="utf-8"))
        for command in payload.get("commands", []):
            if command.get("name") == command_name:
                matches.append((meta_path, command))

    if not matches:
        raise SystemExit(f"Command is not defined in any _meta.json: {command_name}")
    if len(matches) > 1:
        sources = ", ".join(str(path.relative_to(repo_root)) for path, _ in matches)
        raise SystemExit(f"Command is defined multiple times: {command_name}: {sources}")
    return matches[0]


def resolve_entry_point(meta_path: Path, command: dict) -> Path:
    entry_point = command.get("entry_point")
    if not isinstance(entry_point, str) or not entry_point:
        raise SystemExit(f"Command metadata must define entry_point: {meta_path}")

    entry_path = (meta_path.parent / entry_point).resolve()
    if entry_path.suffix != ".py":
        raise SystemExit(f"Command entry point must be a Python file: {entry_path}")
    if not entry_path.is_file():
        raise SystemExit(f"Command entry point does not exist: {entry_path}")
    return entry_path


def validate_required_inputs(meta_path: Path, command: dict) -> None:
    required_inputs = command.get("required_inputs")
    if not isinstance(required_inputs, dict):
        raise SystemExit(f"Command metadata must define required_inputs: {meta_path}")

    for group_name in ("all_of", "one_of"):
        group = required_inputs.get(group_name)
        if not isinstance(group, list):
            raise SystemExit(f"required_inputs.{group_name} must be a list: {meta_path}")
        for entry in group:
            if not isinstance(entry, dict):
                raise SystemExit(f"required_inputs.{group_name} entries must be objects: {meta_path}")
            name = entry.get("name")
            description = entry.get("description")
            sources = entry.get("sources")
            if not isinstance(name, str) or not name:
                raise SystemExit(f"required_inputs.{group_name}.name must be a non-empty string: {meta_path}")
            if not isinstance(description, str) or not description:
                raise SystemExit(
                    f"required_inputs.{group_name}.description must be a non-empty string: {meta_path}"
                )
            if not isinstance(sources, list) or not sources or not all(isinstance(item, str) and item for item in sources):
                raise SystemExit(
                    f"required_inputs.{group_name}.sources must be a non-empty list of strings: {meta_path}"
                )


def validate_direct_arg_inputs(meta_path: Path, command: dict) -> None:
    direct_arg_inputs = command.get("direct_arg_inputs")
    if direct_arg_inputs is None:
        return
    if not isinstance(direct_arg_inputs, list) or not all(isinstance(item, str) and item for item in direct_arg_inputs):
        raise SystemExit(f"direct_arg_inputs must be a list of non-empty strings: {meta_path}")


def read_option_value(command_args: list[str], option_name: str) -> str | None:
    for index, value in enumerate(command_args):
        if value != option_name:
            continue
        if index + 1 >= len(command_args):
            raise SystemExit(f"Option requires a value: {option_name}")
        return command_args[index + 1]
    return None


def validate_llm_temp_markdown_path(path_text: str, *, command_name: str) -> None:
    path = Path(path_text).expanduser()
    if path.suffix != ".md":
        raise SystemExit("llm-temp file must use .md extension")
    if path.parent.name != "llm-temp":
        raise SystemExit("llm-temp file must be placed directly under llm-temp/")

    filename = path.name
    prefix_match = LLM_TEMP_FILENAME_PREFIX.match(filename)
    if prefix_match is None:
        raise SystemExit("llm-temp filename must start with YYYYMMDD-HHMMSS-")

    remainder = filename[prefix_match.end() :]
    expected_prefix = f"{command_name}-"
    if not remainder.startswith(expected_prefix):
        raise SystemExit(f"llm-temp filename must include command name: {command_name}")
    summary = remainder[len(expected_prefix) : -3]
    if not summary:
        raise SystemExit("llm-temp filename must include a non-empty summary before .md")


def validate_markdown_body_format(path_text: str, contract: dict) -> None:
    body = Path(path_text).read_text(encoding="utf-8")

    required_headings = contract.get("required_headings", [])
    if not isinstance(required_headings, list) or not all(isinstance(item, str) and item for item in required_headings):
        raise SystemExit("body_file_contract.required_headings must be a list of non-empty strings")
    for heading in required_headings:
        pattern = re.compile(rf"^{re.escape(heading)}$", re.MULTILINE)
        if pattern.search(body) is None:
            raise SystemExit(f"Markdown body must contain heading: {heading}")

    required_literals = contract.get("required_literals", [])
    if not isinstance(required_literals, list) or not all(isinstance(item, str) and item for item in required_literals):
        raise SystemExit("body_file_contract.required_literals must be a list of non-empty strings")
    for literal in required_literals:
        if literal not in body:
            raise SystemExit(f"Markdown body must contain literal: {literal}")


def validate_body_file_contract(command_name: str, command: dict, command_args: list[str]) -> None:
    if "--help" in command_args or "-h" in command_args:
        return

    contract = command.get("body_file_contract")
    if contract is None:
        return
    if not isinstance(contract, dict):
        raise SystemExit("body_file_contract must be an object")

    file_option = contract.get("file_option")
    inline_option = contract.get("inline_option")
    content_format = contract.get("content_format")
    if not isinstance(file_option, str) or not file_option:
        raise SystemExit("body_file_contract.file_option must be a non-empty string")
    if not isinstance(inline_option, str) or not inline_option:
        raise SystemExit("body_file_contract.inline_option must be a non-empty string")
    if content_format != "markdown":
        raise SystemExit("body_file_contract.content_format must be markdown")

    if inline_option in command_args:
        raise SystemExit(f"{command_name} must use {file_option}; {inline_option} is not allowed")

    file_value = read_option_value(command_args, file_option)
    if file_value is None:
        raise SystemExit(f"{command_name} requires {file_option}")

    validate_llm_temp_markdown_path(file_value, command_name=command_name)
    validate_markdown_body_format(file_value, contract)


def ensure_requirements(python_bin: Path, repo_root: Path, required_modules: list[str]) -> None:
    if not required_modules:
        return

    probe = "import " + ", ".join(required_modules)
    result = subprocess.run([str(python_bin), "-c", probe], capture_output=True, text=True, check=False)
    if result.returncode == 0:
        return

    requirements_file = repo_root / "requirements.txt"
    if not requirements_file.is_file():
        raise SystemExit(f"requirements.txt not found: {requirements_file}")

    install = subprocess.run(
        [str(python_bin), "-m", "pip", "install", "--quiet", "-r", str(requirements_file)],
        env={**os.environ, "PIP_DISABLE_PIP_VERSION_CHECK": "1"},
        capture_output=True,
        text=True,
        check=False,
    )
    if install.returncode != 0:
        stderr = install.stderr.strip() or install.stdout.strip()
        raise SystemExit(f"Failed to install Python requirements: {stderr}")


def resolve_python(repo_root: Path, command: dict) -> str:
    runtime = command.get("runtime", {})
    use_venv = bool(runtime.get("use_repo_venv"))
    required_modules = runtime.get("required_modules", [])
    if not isinstance(required_modules, list) or not all(isinstance(item, str) for item in required_modules):
        raise SystemExit("runtime.required_modules must be a list of strings")

    if not use_venv:
        ensure_requirements(Path(sys.executable), repo_root, required_modules)
        return sys.executable

    venv_dir = repo_root / ".venv"
    python_bin = venv_dir / "bin" / "python3"
    if not python_bin.exists():
        create = subprocess.run(
            [sys.executable, "-m", "venv", str(venv_dir)],
            capture_output=True,
            text=True,
            check=False,
        )
        if create.returncode != 0:
            stderr = create.stderr.strip() or create.stdout.strip()
            raise SystemExit(f"Failed to create repo virtualenv: {stderr}")

    ensure_requirements(python_bin, repo_root, required_modules)
    return str(python_bin)


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).expanduser().resolve()
    meta_path, command = load_command_definition(repo_root, args.command)
    validate_required_inputs(meta_path, command)
    validate_direct_arg_inputs(meta_path, command)
    validate_body_file_contract(args.command, command, args.command_args)
    entry_path = resolve_entry_point(meta_path, command)

    fixed_args = command.get("fixed_args", [])
    if not isinstance(fixed_args, list) or not all(isinstance(item, str) for item in fixed_args):
        raise SystemExit(f"fixed_args must be a list of strings: {meta_path}")

    python_bin = resolve_python(repo_root, command)
    process = subprocess.run(
        [python_bin, str(entry_path), *fixed_args, *args.command_args],
        check=False,
    )
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
