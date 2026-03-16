#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import pathlib
import re
import sys

repo_root = pathlib.Path(sys.argv[1])
swift_files = sorted(repo_root.glob("HelloWorld/**/*.swift"))

FILE_WARN = 500
FILE_FAIL = 900
FUNC_WARN = 60
FUNC_FAIL = 80
TYPE_WARN = 12
PUBLISHED_WARN = 8
PUBLISHED_FAIL = 12

func_start_pattern = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:private|fileprivate|internal|public|open)?\s*(?:mutating|nonmutating|override|final|class|static|nonisolated|convenience|required|async|throws|rethrows|\s)*func\s+([A-Za-z0-9_]+)")
type_pattern = re.compile(r"^\s*(?:@MainActor\s+)?(?:private|fileprivate|internal|public|open)?\s*(?:final\s+)?(?:struct|class|actor|enum)\s+[A-Za-z0-9_]+")

large_files = []
wide_scope_files = []
published_files = []
long_functions = []

for path in swift_files:
    text = path.read_text()
    lines = text.splitlines()
    line_count = len(lines)
    type_count = sum(1 for line in lines if type_pattern.match(line))
    published_count = sum(1 for line in lines if "@Published" in line)

    if line_count >= FILE_WARN:
        large_files.append((line_count, path))
    if type_count >= TYPE_WARN:
        wide_scope_files.append((type_count, path))
    if published_count >= PUBLISHED_WARN:
        published_files.append((published_count, path))

    index = 0
    while index < len(lines):
        line = lines[index]
        match = func_start_pattern.match(line)
        if not match:
            index += 1
            continue

        name = match.group(1)
        brace_balance = line.count("{") - line.count("}")
        start = index
        seen_open = "{" in line
        current = index

        while current + 1 < len(lines):
            if seen_open and brace_balance <= 0:
                break
            current += 1
            next_line = lines[current]
            if "{" in next_line:
                seen_open = True
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

hard_failures = []

for line_count, path in large_files:
    if line_count >= FILE_FAIL:
        hard_failures.append(f"file {path.relative_to(repo_root)}: {line_count} lines")

for length, path, line_no, name in long_functions:
    if length >= FUNC_FAIL:
        hard_failures.append(f"func {path.relative_to(repo_root)}:{line_no} {name}: {length} lines")

for published_count, path in published_files:
    if published_count >= PUBLISHED_FAIL:
        hard_failures.append(f"published {path.relative_to(repo_root)}: {published_count}")

print("HelloWorld Health Barometer")
print("")

print("Large files")
if large_files:
    for line_count, path in sorted(large_files, reverse=True)[:10]:
        status = "FAIL" if line_count >= FILE_FAIL else "WARN"
        print(f"- [{status}] {path.relative_to(repo_root)}: {line_count} lines")
else:
    print("- none")

print("")
print("Long functions")
if long_functions:
    for length, path, line_no, name in sorted(long_functions, reverse=True)[:12]:
        status = "FAIL" if length >= FUNC_FAIL else "WARN"
        print(f"- [{status}] {path.relative_to(repo_root)}:{line_no} {name}: {length} lines")
else:
    print("- none")

print("")
print("Wide scope files")
if wide_scope_files:
    for type_count, path in sorted(wide_scope_files, reverse=True)[:10]:
        print(f"- [WARN] {path.relative_to(repo_root)}: {type_count} top-level types")
else:
    print("- none")

print("")
print("ObservableObject surface")
if published_files:
    for published_count, path in sorted(published_files, reverse=True)[:10]:
        status = "FAIL" if published_count >= PUBLISHED_FAIL else "WARN"
        print(f"- [{status}] {path.relative_to(repo_root)}: {published_count} @Published properties")
else:
    print("- none")

print("")
if hard_failures:
    print("Result: FAIL")
    for failure in hard_failures:
        print(f"- {failure}")
    sys.exit(1)

print("Result: OK")
PY
