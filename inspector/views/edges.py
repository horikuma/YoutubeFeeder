#!/usr/bin/env python3
"""Render collect.db call-edge rows through DuckDB."""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: edges.py <collect.db>", file=sys.stderr)
    return 2 if error else 0


def _load_sqlite_scanner(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute("INSTALL sqlite_scanner")
    connection.execute("LOAD sqlite_scanner")


def _emit_edges(db_path: Path) -> None:
    connection = duckdb.connect(database=":memory:")
    _load_sqlite_scanner(connection)
    rows = connection.execute(
        """
        SELECT
            caller.name,
            callee.name,
            edges.caller_usr,
            edges.callee_usr
        FROM sqlite_scan(?, 'call_edges') AS edges
        LEFT JOIN sqlite_scan(?, 'functions') AS caller
            ON edges.caller_usr = caller.usr
        LEFT JOIN sqlite_scan(?, 'functions') AS callee
            ON edges.callee_usr = callee.usr
        ORDER BY caller.name, callee.name, edges.caller_usr, edges.callee_usr
        """,
        [str(db_path), str(db_path), str(db_path)],
    ).fetchall()
    for caller_name, callee_name, caller_usr, callee_usr in rows:
        print(f"{caller_name or ''}\t{callee_name or ''}\t{caller_usr}\t{callee_usr}")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected one collect.db path")

    db_path = Path(sys.argv[1]).expanduser().resolve()
    if not db_path.exists():
        return usage(f"file not found: {db_path}")

    try:
        _emit_edges(db_path)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
