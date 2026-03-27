#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


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
    for meta_path in sorted(repo_root.glob("skills/*/_meta.json")):
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
