#!/usr/bin/env python3
"""SourceKit client helpers."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
FRONTEND_JOBS_PATH = ROOT / "frontend-jobs.json"


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=True, capture_output=True)


def run_sourcekit_request(args: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd is not None else None,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )


def load_structure(file_path: Path) -> dict:
    result = run_command(["sourcekitten", "structure", "--file", str(file_path)])
    return json.loads(result.stdout)


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
        result = run_sourcekit_request(
            [
                *sourcekit_lsp_cmd,
                "debug",
                "run-sourcekitd-request",
                "--sourcekitd",
                str(sourcekitd),
                "--request-file",
                str(request_path),
            ],
            cwd=PROJECT_ROOT,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr or result.stdout or "sourcekitd request failed")

        try:
            return extract_usr(result.stdout)
        except RuntimeError:
            return None


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
