#!/usr/bin/env python3
"""Consume frontend-jobs.json and query SourceKit."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
FRONTEND_JOBS_PATH = Path.cwd() / "frontend-jobs.json"

TARGET_KIND_PREFIXES = (
    "source.lang.swift.decl.class",
    "source.lang.swift.decl.struct",
    "source.lang.swift.decl.enum",
    "source.lang.swift.decl.protocol",
    "source.lang.swift.decl.function",
    "source.lang.swift.decl.var",
)

WALK_LIMIT = int(os.environ.get("COLLECT_WALK_LIMIT", "1000"))


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: collect.py <swift-file>", file=sys.stderr)
    print("Consumes llm-temp/frontend-jobs.json only.", file=sys.stderr)
    return 2 if error else 0


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=True, capture_output=True)


def find_xcrun_path(tool_name: str) -> Path | None:
    try:
        result = run_command(["xcrun", "--find", tool_name])
    except subprocess.CalledProcessError:
        return None
    path = result.stdout.strip()
    return Path(path) if path else None


def find_toolchain_root() -> Path:
    xcrun_sourcekit_lsp = find_xcrun_path("sourcekit-lsp")
    if xcrun_sourcekit_lsp:
        return xcrun_sourcekit_lsp.parent.parent.parent

    local_sourcekit_lsp = shutil.which("sourcekit-lsp")
    if local_sourcekit_lsp:
        return Path(local_sourcekit_lsp).resolve().parent.parent.parent

    raise FileNotFoundError("Could not find the Xcode toolchain root")


def load_structure(file_path: Path) -> dict:
    result = run_command(["sourcekitten", "structure", "--file", str(file_path)])
    return json.loads(result.stdout)


def load_frontend_jobs() -> list[dict[str, object]]:
    if not FRONTEND_JOBS_PATH.exists():
        raise FileNotFoundError(f"frontend-jobs.json not found: {FRONTEND_JOBS_PATH}")

    payload = json.loads(FRONTEND_JOBS_PATH.read_text(encoding="utf-8"))
    jobs = payload.get("jobs")
    if not isinstance(jobs, list):
        raise RuntimeError("frontend-jobs.json must contain a jobs array")

    return jobs


def select_frontend_job(jobs: list[dict[str, object]], source_file: Path) -> dict[str, object]:
    if not jobs:
        raise FileNotFoundError("frontend-jobs.json contains no jobs")

    source_file_text = str(source_file)
    matching_jobs: list[dict[str, object]] = []
    for job in jobs:
        source_files = job.get("source_files")
        if isinstance(source_files, list) and source_file_text in source_files:
            matching_jobs.append(job)

    if len(matching_jobs) == 1:
        return matching_jobs[0]

    if len(jobs) == 1:
        return jobs[0]

    raise RuntimeError(
        f"Could not select a single frontend job for {source_file}; "
        "provide a jobs.json with one job or source_files metadata"
    )


def find_sourcekit_lsp() -> list[str]:
    path = shutil.which("sourcekit-lsp")
    if path:
        return [path]

    xcrun_sourcekit_lsp = find_xcrun_path("sourcekit-lsp")
    if xcrun_sourcekit_lsp:
        return [str(xcrun_sourcekit_lsp)]

    swift = shutil.which("swift")
    if swift:
        return [swift, "run", "-c", "debug", "sourcekit-lsp"]

    raise FileNotFoundError("Could not find sourcekit-lsp or swift in PATH")


def find_sourcekitd() -> Path:
    toolchain_root = find_toolchain_root()
    inproc_candidate = toolchain_root / "usr" / "lib" / "sourcekitdInProc.framework" / "sourcekitdInProc"
    if inproc_candidate.exists():
        return inproc_candidate

    candidate = toolchain_root / "usr" / "lib" / "sourcekitd.framework" / "sourcekitd"
    if candidate.exists():
        return candidate

    raise FileNotFoundError("Could not find sourcekitd in the active Xcode toolchain")


def build_cursorinfo_request(source_file: Path, offset: int, compiler_argv: list[str], request_path: Path) -> None:
    quoted_args = ",\n    ".join(json.dumps(arg, ensure_ascii=False) for arg in compiler_argv)
    request = f"""\
{{
  key.request: source.request.cursorinfo,
  key.offset: {offset},
  key.sourcefile: {json.dumps(str(source_file), ensure_ascii=False)},
  key.primary_file: {json.dumps(str(source_file), ensure_ascii=False)},
  key.compilerargs: [
    {quoted_args}
  ],
}}
"""
    request_path.write_text(request, encoding="utf-8")


def extract_usr(output: str) -> str:
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("key.usr:"):
            value = stripped.split(":", 1)[1].strip().rstrip(",")
            return value.strip().strip('"')
        if stripped.startswith("usr:"):
            value = stripped.split(":", 1)[1].strip().rstrip(",")
            return value.strip().strip('"')
    raise RuntimeError(f"Could not find usr in response:\n{output}")


def query_usr(
    source_file: Path,
    offset: int,
    *,
    compiler_argv: list[str],
    sourcekit_lsp_cmd: list[str],
    sourcekitd: Path,
) -> str | None:
    with tempfile.TemporaryDirectory(prefix="cursorinfo-") as tmpdir:
        request_path = Path(tmpdir) / "cursorinfo.yml"
        build_cursorinfo_request(source_file, offset, compiler_argv, request_path)
        if os.environ.get("COLLECT_DEBUG_QUERY_TRACE") == "1":
            print(f"query start offset={offset}", file=sys.stderr)
        result = subprocess.run(
            [
                *sourcekit_lsp_cmd,
                "debug",
                "run-sourcekitd-request",
                "--sourcekitd",
                str(sourcekitd),
                "--request-file",
                str(request_path),
            ],
            cwd=str(PROJECT_ROOT),
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
        )
        if os.environ.get("COLLECT_DEBUG_QUERY_TRACE") == "1":
            print(f"query end offset={offset} rc={result.returncode}", file=sys.stderr)
        if result.returncode != 0:
            raise RuntimeError(result.stderr or result.stdout or "sourcekitd request failed")

        try:
            return extract_usr(result.stdout)
        except RuntimeError:
            return None


class WalkLimitReached(Exception):
    pass


def is_target_kind(kind: object) -> bool:
    if not isinstance(kind, str):
        return False
    return any(kind == prefix or kind.startswith(prefix + ".") for prefix in TARGET_KIND_PREFIXES)


def walk_nodes(
    node: object,
    source_file: Path,
    *,
    compiler_argv: list[str],
    sourcekit_lsp_cmd: list[str],
    sourcekitd: Path,
    usr_cache: dict[int, str | None],
    walk_count: list[int],
) -> None:
    if walk_count[0] >= WALK_LIMIT:
        raise WalkLimitReached

    if isinstance(node, dict):
        walk_count[0] += 1
        kind = node.get("key.kind")
        offset = node.get("key.offset")
        name = node.get("key.name")
        if is_target_kind(kind) and isinstance(offset, int):
            if offset not in usr_cache:
                usr_cache[offset] = query_usr(
                    source_file,
                    offset,
                    compiler_argv=compiler_argv,
                    sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                    sourcekitd=sourcekitd,
                )
            usr = usr_cache[offset]
            if isinstance(name, str) and usr:
                print(f"{name}\t{usr}")

        substructure = node.get("key.substructure")
        if isinstance(substructure, list):
            for child in substructure:
                walk_nodes(
                    child,
                    source_file,
                    compiler_argv=compiler_argv,
                    sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                    sourcekitd=sourcekitd,
                    usr_cache=usr_cache,
                    walk_count=walk_count,
                )
    elif isinstance(node, list):
        for child in node:
            walk_nodes(
                child,
                source_file,
                compiler_argv=compiler_argv,
                sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                sourcekitd=sourcekitd,
                usr_cache=usr_cache,
                walk_count=walk_count,
            )


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(
            None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected exactly one Swift file path"
        )

    source_file = Path(sys.argv[1]).expanduser().resolve()
    if not source_file.exists():
        return usage(f"file not found: {source_file}")
    if source_file.suffix != ".swift":
        return usage(f"not a Swift file: {source_file}")

    structure = load_structure(source_file)
    jobs = load_frontend_jobs()
    job = select_frontend_job(jobs, source_file)

    compiler_argv = job.get("argv")
    if (
        not isinstance(compiler_argv, list)
        or not compiler_argv
        or not all(isinstance(item, str) for item in compiler_argv)
    ):
        raise RuntimeError("frontend job argv must be a non-empty list of strings")

    sourcekitd = find_sourcekitd()
    sourcekit_lsp_cmd = find_sourcekit_lsp()

    usr_cache: dict[int, str | None] = {}
    walk_count = [0]
    walk_status = "completed"
    try:
        walk_nodes(
            structure.get("key.substructure", structure),
            source_file,
            compiler_argv=compiler_argv,
            sourcekit_lsp_cmd=sourcekit_lsp_cmd,
            sourcekitd=sourcekitd,
            usr_cache=usr_cache,
            walk_count=walk_count,
        )
    except WalkLimitReached:
        walk_status = "stopped_at_limit"

    if walk_status == "stopped_at_limit":
        print(f"walk stopped at limit {WALK_LIMIT}: {walk_count[0]} nodes", file=sys.stderr)
    else:
        print(f"walk completed: {walk_count[0]} nodes", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
