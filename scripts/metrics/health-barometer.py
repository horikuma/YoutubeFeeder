#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FILE_WARN = 500
FILE_FAIL = 900
FUNC_WARN = 60
FUNC_FAIL = 80
TYPE_WARN = 12
PUBLISHED_WARN = 8
PUBLISHED_FAIL = 12

FUNC_START_PATTERN = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:private|fileprivate|internal|public|open)?\s*"
    r"(?:mutating|nonmutating|override|final|class|static|nonisolated|convenience|required|async|throws|rethrows|\s)*"
    r"func\s+([A-Za-z0-9_]+)"
)
TYPE_PATTERN = re.compile(r"^\s*(?:@MainActor\s+)?(?:private|fileprivate|internal|public|open)?\s*(?:final\s+)?(?:struct|class|actor|enum)\s+[A-Za-z0-9_]+")


def main() -> int:
    swift_files = sorted(REPO_ROOT.glob("YoutubeFeeder/**/*.swift"))
    large_files: list[tuple[int, Path]] = []
    wide_scope_files: list[tuple[int, Path]] = []
    published_files: list[tuple[int, Path]] = []
    long_functions: list[tuple[int, Path, int, str]] = []

    for path in swift_files:
        lines = path.read_text(encoding="utf-8").splitlines()
        line_count = len(lines)
        type_count = sum(1 for line in lines if TYPE_PATTERN.match(line))
        published_count = sum(1 for line in lines if "@Published" in line)

        if line_count >= FILE_WARN:
            large_files.append((line_count, path))
        if type_count >= TYPE_WARN:
            wide_scope_files.append((type_count, path))
        if published_count >= PUBLISHED_WARN:
            published_files.append((published_count, path))

        index = 0
        while index < len(lines):
            match = FUNC_START_PATTERN.match(lines[index])
            if not match:
                index += 1
                continue

            name = match.group(1)
            brace_balance = lines[index].count("{") - lines[index].count("}")
            start = index
            seen_open = "{" in lines[index]
            current = index
            while current + 1 < len(lines):
                if seen_open and brace_balance <= 0:
                    break
                current += 1
                next_line = lines[current]
                seen_open = seen_open or "{" in next_line
                brace_balance += next_line.count("{") - next_line.count("}")
                if seen_open and brace_balance <= 0:
                    break

            if seen_open:
                length = current - start + 1
                if length >= FUNC_WARN:
                    long_functions.append((length, path, start + 1, name))
                index = current + 1
            else:
                index += 1

    hard_failures: list[str] = []
    for line_count, path in large_files:
        if line_count >= FILE_FAIL:
            hard_failures.append(f"file {path.relative_to(REPO_ROOT)}: {line_count} lines")
    for length, path, line_no, name in long_functions:
        if length >= FUNC_FAIL:
            hard_failures.append(f"func {path.relative_to(REPO_ROOT)}:{line_no} {name}: {length} lines")
    for published_count, path in published_files:
        if published_count >= PUBLISHED_FAIL:
            hard_failures.append(f"published {path.relative_to(REPO_ROOT)}: {published_count}")

    print("YoutubeFeeder Health Barometer\n")
    print("Large files")
    if large_files:
        for line_count, path in sorted(large_files, reverse=True)[:10]:
            status = "FAIL" if line_count >= FILE_FAIL else "WARN"
            print(f"- [{status}] {path.relative_to(REPO_ROOT)}: {line_count} lines")
    else:
        print("- none")
    print("\nLong functions")
    if long_functions:
        for length, path, line_no, name in sorted(long_functions, reverse=True)[:12]:
            status = "FAIL" if length >= FUNC_FAIL else "WARN"
            print(f"- [{status}] {path.relative_to(REPO_ROOT)}:{line_no} {name}: {length} lines")
    else:
        print("- none")
    print("\nWide scope files")
    if wide_scope_files:
        for type_count, path in sorted(wide_scope_files, reverse=True)[:10]:
            print(f"- [WARN] {path.relative_to(REPO_ROOT)}: {type_count} top-level types")
    else:
        print("- none")
    print("\nObservableObject surface")
    if published_files:
        for published_count, path in sorted(published_files, reverse=True)[:10]:
            status = "FAIL" if published_count >= PUBLISHED_FAIL else "WARN"
            print(f"- [{status}] {path.relative_to(REPO_ROOT)}: {published_count} @Published properties")
    else:
        print("- none")

    if hard_failures:
        print("\nResult: FAIL")
        for failure in hard_failures:
            print(f"- {failure}")
        return 1

    print("\nResult: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
