#!/usr/bin/env python3
"""Walk a Swift structure AST and print selected declarations with their USRs."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: collect.py <swift-file>", file=sys.stderr)
    print(
        "Parses the given Swift file with sourcekitten structure, walks key.substructure, "
        "and prints selected nodes' key.name with the USR resolved from key.offset.",
        file=sys.stderr,
    )
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


def find_swiftmodule() -> Path:
    build_root = PROJECT_ROOT / "build"
    for config in ("debug", "release"):
        config_root = build_root / config
        if not config_root.exists():
            continue
        matches = sorted(
            p
            for p in config_root.rglob("YoutubeFeeder.swiftmodule")
            if "Objects-normal" in p.parts and "YoutubeFeeder.build" in p.parts
        )
        if matches:
            return matches[0]
    raise FileNotFoundError(f"Could not find YoutubeFeeder.swiftmodule under {PROJECT_ROOT / 'build'}")


def load_structure(file_path: Path) -> dict:
    result = run_command(["sourcekitten", "structure", "--file", str(file_path)])
    return json.loads(result.stdout)


def sanitize_path_value(value: str) -> str:
    value = value.strip().strip("'\"")
    candidate = Path(value)
    if candidate.exists():
        return value

    trimmed = value
    while trimmed:
        trimmed = trimmed[:-1]
        if Path(trimmed).exists():
            return trimmed
    return value


def extract_compiler_args(swiftmodule: Path, source_file: Path, module_cache_path: Path) -> list[str]:
    strings_output = run_command(["strings", str(swiftmodule)]).stdout.splitlines()

    try:
        start = next(i for i, line in enumerate(strings_output) if line == "-working-directory")
    except StopIteration as exc:
        raise RuntimeError(f"Could not find compiler arguments in {swiftmodule}") from exc

    try:
        end = next(i for i in range(start, len(strings_output)) if strings_output[i].startswith("--target="))
    except StopIteration as exc:
        raise RuntimeError(f"Could not find --target=... in {swiftmodule}") from exc

    raw_args = strings_output[start : end + 1]
    args: list[str] = []
    i = 0
    while i < len(raw_args):
        token = raw_args[i].strip()
        if not token:
            i += 1
            continue

        if token in {"-working-directory", "-ivfsstatcache", "-iquote", "-isystem"} and i + 1 < len(raw_args):
            value = sanitize_path_value(raw_args[i + 1])
            args.extend([token, value])
            i += 2
            continue

        if token.startswith("-I") and token != "-I":
            args.append("-I" + sanitize_path_value(token[2:]))
            i += 1
            continue

        if token.startswith("-F") and token != "-F":
            args.append("-F" + sanitize_path_value(token[2:]))
            i += 1
            continue

        if token.startswith("-L") and token != "-L":
            args.append("-L" + sanitize_path_value(token[2:]))
            i += 1
            continue

        if token.startswith("-fmodule-file="):
            prefix, path_part = token.rsplit("=", 1)
            args.append(f"{prefix}={sanitize_path_value(path_part)}")
            i += 1
            continue

        args.append(token)
        i += 1

    sdk_path = next((sanitize_path_value(line) for line in strings_output if line.endswith(".sdk")), None)
    if sdk_path and "-sdk" not in args:
        args = ["-sdk", sdk_path] + args

    if "-module-cache-path" not in args:
        insert_at = 0
        if "-sdk" in args:
            insert_at = 2
        args[insert_at:insert_at] = ["-module-cache-path", str(module_cache_path)]

    return normalize_compiler_args_for_sourcekitd(args, source_file)


def normalize_compiler_args_for_sourcekitd(args: list[str], source_file: Path) -> list[str]:
    normalized: list[str] = []
    i = 0
    while i < len(args):
        token = args[i]

        if token in {"-sdk", "-module-cache-path", "-working-directory"} and i + 1 < len(args):
            normalized.extend([token, args[i + 1]])
            i += 2
            continue

        if token.startswith("--target="):
            normalized.append(token)
            i += 1
            continue

        if token.startswith("-D"):
            macro = token[2:]
            if macro.startswith("_") or macro.startswith("LIBCPP_") or macro.startswith("__"):
                normalized.extend(["-Xcc", token])
            else:
                normalized.append("-D" + macro.split("=", 1)[0])
            i += 1
            continue

        if token.startswith("-I") or token.startswith("-F") or token.startswith("-L"):
            normalized.append(token)
            i += 1
            continue

        if token in {"-fno-implicit-modules", "-fno-implicit-module-maps", "-fno-color-diagnostics"}:
            normalized.extend(["-Xcc", token])
            i += 1
            continue

        if token in {"-ivfsstatcache", "-iquote", "-isystem"} and i + 1 < len(args):
            normalized.extend(["-Xcc", token, "-Xcc", args[i + 1]])
            i += 2
            continue

        if token.startswith("-ffile-compilation-dir=") or token.startswith("-fmodule-file="):
            normalized.extend(["-Xcc", token])
            i += 1
            continue

        normalized.append(token)
        i += 1

    normalized.append(str(source_file))
    return normalized


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


def find_sourcekit_plugins() -> tuple[Path, Path]:
    toolchain_root = find_toolchain_root()
    service_plugin = toolchain_root / "usr" / "lib" / "libSwiftSourceKitPlugin.dylib"
    client_plugin = toolchain_root / "usr" / "lib" / "libSwiftSourceKitClientPlugin.dylib"
    if service_plugin.exists() and client_plugin.exists():
        return service_plugin, client_plugin
    raise FileNotFoundError("Could not find Swift SourceKit plugin dylibs in the active Xcode toolchain")


def build_cursorinfo_request(source_file: Path, offset: int, compiler_args: list[str], request_path: Path) -> None:
    quoted_args = ",\n    ".join(json.dumps(arg, ensure_ascii=False) for arg in compiler_args)
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
    compiler_args: list[str],
    sourcekit_lsp_cmd: list[str],
    sourcekitd: Path,
    service_plugin: Path,
    client_plugin: Path,
) -> str | None:
    with tempfile.TemporaryDirectory(prefix="cursorinfo-") as tmpdir:
        request_path = Path(tmpdir) / "cursorinfo.yml"
        build_cursorinfo_request(source_file, offset, compiler_args, request_path)
        result = subprocess.run(
            [
                *sourcekit_lsp_cmd,
                "debug",
                "run-sourcekitd-request",
                "--sourcekitd",
                str(sourcekitd),
                "--sourcekit-plugin-path",
                str(service_plugin),
                "--sourcekit-client-plugin-path",
                str(client_plugin),
                "--request-file",
                str(request_path),
            ],
            cwd=str(PROJECT_ROOT),
            text=True,
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr or result.stdout or "sourcekitd request failed")

        try:
            return extract_usr(result.stdout)
        except RuntimeError:
            return None


class WalkLimitReached(Exception):
    pass


WALK_LIMIT = 1000


TARGET_KIND_PREFIXES = (
    "source.lang.swift.decl.class",
    "source.lang.swift.decl.struct",
    "source.lang.swift.decl.enum",
    "source.lang.swift.decl.protocol",
    "source.lang.swift.decl.function",
    "source.lang.swift.decl.var",
)


def is_target_kind(kind: object) -> bool:
    if not isinstance(kind, str):
        return False
    return any(kind == prefix or kind.startswith(prefix + ".") for prefix in TARGET_KIND_PREFIXES)


def walk_nodes(
    node: object,
    source_file: Path,
    *,
    compiler_args: list[str],
    sourcekit_lsp_cmd: list[str],
    sourcekitd: Path,
    service_plugin: Path,
    client_plugin: Path,
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
                    compiler_args=compiler_args,
                    sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                    sourcekitd=sourcekitd,
                    service_plugin=service_plugin,
                    client_plugin=client_plugin,
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
                    compiler_args=compiler_args,
                    sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                    sourcekitd=sourcekitd,
                    service_plugin=service_plugin,
                    client_plugin=client_plugin,
                    usr_cache=usr_cache,
                    walk_count=walk_count,
                )
    elif isinstance(node, list):
        for child in node:
            walk_nodes(
                child,
                source_file,
                compiler_args=compiler_args,
                sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                sourcekitd=sourcekitd,
                service_plugin=service_plugin,
                client_plugin=client_plugin,
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

    module_cache_path = Path(tempfile.gettempdir()) / "structure-module-cache"
    module_cache_path.mkdir(parents=True, exist_ok=True)
    swiftmodule = find_swiftmodule()
    compiler_args = extract_compiler_args(swiftmodule, source_file, module_cache_path)
    sourcekitd = find_sourcekitd()
    service_plugin, client_plugin = find_sourcekit_plugins()
    sourcekit_lsp_cmd = find_sourcekit_lsp()

    usr_cache: dict[int, str | None] = {}
    walk_count = [0]
    walk_status = "completed"
    try:
        walk_nodes(
            structure.get("key.substructure", structure),
            source_file,
            compiler_args=compiler_args,
            sourcekit_lsp_cmd=sourcekit_lsp_cmd,
            sourcekitd=sourcekitd,
            service_plugin=service_plugin,
            client_plugin=client_plugin,
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
