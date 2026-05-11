#!/usr/bin/env python3
"""Render collect.db function rows through DuckDB."""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: view.py <collect.db>", file=sys.stderr)
    return 2 if error else 0


def _load_sqlite_scanner(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute("INSTALL sqlite_scanner")
    connection.execute("LOAD sqlite_scanner")


def _emit_functions(db_path: Path) -> None:
    connection = duckdb.connect(database=":memory:")
    _load_sqlite_scanner(connection)
    rows = connection.execute(
        """
        SELECT name, usr
        FROM sqlite_scan(?, 'functions')
        ORDER BY name, usr
        """,
        [str(db_path)],
    ).fetchall()
    for name, usr in rows:
        print(f"{name}\t{usr}")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected one collect.db path")

    db_path = Path(sys.argv[1]).expanduser().resolve()
    if not db_path.exists():
        return usage(f"file not found: {db_path}")

    try:
        _emit_functions(db_path)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
