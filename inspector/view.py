

#!/usr/bin/env python3

from __future__ import annotations

import sqlite3
from pathlib import Path


DATABASE_PATH = Path(__file__).resolve().parent / "inspector.db"


def main() -> None:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row

    try:
        print_summary(connection)
        print_hotspots(connection)
    finally:
        connection.close()


def print_summary(connection: sqlite3.Connection) -> None:
    symbol_count = connection.execute(
        "SELECT COUNT(*) FROM symbols"
    ).fetchone()[0]

    file_count = connection.execute(
        "SELECT COUNT(DISTINCT file_path) FROM symbols"
    ).fetchone()[0]

    print("################################################################################")
    print("# INSPECTOR SUMMARY")
    print("################################################################################")
    print()
    print(f"DATABASE : {DATABASE_PATH}")
    print(f"FILES    : {file_count}")
    print(f"SYMBOLS  : {symbol_count}")
    print()


def print_hotspots(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            file_path,
            name,
            line_count,
            kind
        FROM symbols
        WHERE line_count IS NOT NULL
        ORDER BY line_count DESC
        LIMIT 20
        """
    ).fetchall()

    print("HOTSPOTS")
    print("---------")

    for row in rows:
        short_kind = row["kind"].replace("source.lang.swift.decl.", "")

        print(
            f"{row['line_count']:>4}  "
            f"[{short_kind}] "
            f"{row['name']}  "
            f"({row['file_path']})"
        )

    print()


if __name__ == "__main__":
    main()