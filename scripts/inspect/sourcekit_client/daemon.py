#!/usr/bin/env python3
"""Direct SourceKit daemon helpers."""

from __future__ import annotations

import ctypes
import json
import subprocess
from pathlib import Path

_LIBC = ctypes.CDLL(None)
_LIBC.free.argtypes = [ctypes.c_void_p]
_LIBC.free.restype = None


def _find_xcrun_path(tool_name: str) -> Path | None:
    try:
        result = subprocess.run(["xcrun", "--find", tool_name], check=True, text=True, capture_output=True)
    except Exception:
        return None
    path = result.stdout.strip()
    return Path(path) if path else None


def _find_toolchain_root() -> Path:
    xcrun_sourcekit_lsp = _find_xcrun_path("sourcekit-lsp")
    if xcrun_sourcekit_lsp:
        return xcrun_sourcekit_lsp.parent.parent.parent

    raise FileNotFoundError("Could not find the Xcode toolchain root")


def find_sourcekitd() -> Path:
    toolchain_root = _find_toolchain_root()
    inproc_candidate = toolchain_root / "usr" / "lib" / "sourcekitdInProc.framework" / "sourcekitdInProc"
    if inproc_candidate.exists():
        return inproc_candidate

    candidate = toolchain_root / "usr" / "lib" / "sourcekitd.framework" / "sourcekitd"
    if candidate.exists():
        return candidate

    raise FileNotFoundError("Could not find sourcekitd in the active Xcode toolchain")


def _build_cursorinfo_request(source_file: Path, offset: int, compiler_argv: list[str]) -> bytes:
    quoted_args = ",\n    ".join(json.dumps(arg, ensure_ascii=False) for arg in compiler_argv if arg != "-incremental")
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
    return request.encode("utf-8")


def _extract_usr(output: str) -> str:
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("key.usr:"):
            value = stripped.split(":", 1)[1].strip().rstrip(",")
            return value.strip().strip('"')
        if stripped.startswith("usr:"):
            value = stripped.split(":", 1)[1].strip().rstrip(",")
            return value.strip().strip('"')
    raise RuntimeError(f"Could not find usr in response:\n{output}")


class SourceKitDaemon:
    def __init__(self) -> None:
        self._library_path = find_sourcekitd()
        self._library = ctypes.CDLL(str(self._library_path))
        self._configure()
        self._library.sourcekitd_initialize()
        self.request_count = 0
        self._closed = False

    def _configure(self) -> None:
        self._library.sourcekitd_initialize.restype = None
        self._library.sourcekitd_shutdown.restype = None
        self._library.sourcekitd_request_create_from_yaml.argtypes = [
            ctypes.c_char_p,
            ctypes.POINTER(ctypes.c_void_p),
        ]
        self._library.sourcekitd_request_create_from_yaml.restype = ctypes.c_void_p
        self._library.sourcekitd_send_request_sync.argtypes = [ctypes.c_void_p]
        self._library.sourcekitd_send_request_sync.restype = ctypes.c_void_p
        self._library.sourcekitd_response_description_copy.argtypes = [ctypes.c_void_p]
        self._library.sourcekitd_response_description_copy.restype = ctypes.c_void_p
        self._library.sourcekitd_response_is_error.argtypes = [ctypes.c_void_p]
        self._library.sourcekitd_response_is_error.restype = ctypes.c_bool
        self._library.sourcekitd_response_dispose.argtypes = [ctypes.c_void_p]
        self._library.sourcekitd_response_dispose.restype = None
        self._library.sourcekitd_request_release.argtypes = [ctypes.c_void_p]
        self._library.sourcekitd_request_release.restype = None

    def close(self) -> None:
        if self._closed:
            return
        self._library.sourcekitd_shutdown()
        self._closed = True

    def __enter__(self) -> "SourceKitDaemon":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def _create_request(self, yaml_request: bytes) -> ctypes.c_void_p:
        error = ctypes.c_void_p()
        request = self._library.sourcekitd_request_create_from_yaml(yaml_request, ctypes.byref(error))
        if request:
            return request

        if error.value:
            error_message = ctypes.string_at(error.value).decode("utf-8", "replace")
            _LIBC.free(error.value)
            raise RuntimeError(error_message)

        raise RuntimeError("sourcekitd request creation failed")

    def _response_description(self, response: ctypes.c_void_p) -> str:
        description_ptr = self._library.sourcekitd_response_description_copy(response)
        if not description_ptr:
            return ""
        try:
            return ctypes.string_at(description_ptr).decode("utf-8", "replace")
        finally:
            _LIBC.free(description_ptr)

    def query_usr(self, source_file: Path, offset: int, *, compiler_argv: list[str]) -> str | None:
        self.request_count += 1
        print(f"cursorinfo request dispatch: file={source_file} offset={offset}", flush=True)
        request = self._create_request(_build_cursorinfo_request(source_file, offset, compiler_argv))
        response = self._library.sourcekitd_send_request_sync(request)
        try:
            if self._library.sourcekitd_response_is_error(response):
                return None
            return _extract_usr(self._response_description(response))
        finally:
            self._library.sourcekitd_response_dispose(response)
            self._library.sourcekitd_request_release(request)
