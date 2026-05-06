#!/usr/bin/env python3

from __future__ import annotations

import duckdb

from collect_database import DATABASE_PATH


# =============================================================================
# Database helpers
# =============================================================================


def connect_database() -> duckdb.DuckDBPyConnection:
    connection = duckdb.connect()

    database_path = str(DATABASE_PATH).replace("'", "''")

    connection.execute(
        f"ATTACH '{database_path}' AS inspector (TYPE SQLITE)"
    )

    return connection


# =============================================================================
# Run helpers
# =============================================================================


def latest_run_id(connection: duckdb.DuckDBPyConnection) -> int:
    row = connection.execute(
        "SELECT MAX(id) FROM inspector.runs"
    ).fetchone()

    if row is None or row[0] is None:
        raise RuntimeError("No runs found")

    return int(row[0])


# =============================================================================
# Rendering helpers
# =============================================================================


def print_section(title: str) -> None:
    print()
    print(f"# {title}")


# =============================================================================
# Summary views
# =============================================================================


def print_inspector_summary(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("INSPECTOR SUMMARY")

    row = connection.execute(
        """
        SELECT
            COUNT(*) AS symbol_count,
            COUNT(DISTINCT file_path) AS file_count,
            COUNT(DISTINCT kind) AS kind_count,
            COUNT(DISTINCT effective_owner_name) AS owner_count
        FROM inspector.symbols
        WHERE run_id = ?
        """,
        [run_id],
    ).fetchone()

    print(f"symbols : {row[0]}")
    print(f"files   : {row[1]}")
    print(f"kinds   : {row[2]}")
    print(f"owners  : {row[3]}")



def print_run_summary(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("RUN SUMMARY")

    row = connection.execute(
        """
        SELECT
            runs.id,
            runs.created_at,
            runs.root_path,
            COUNT(symbols.symbol_id) AS symbol_count
        FROM inspector.runs AS runs
        LEFT JOIN inspector.symbols AS symbols
            ON symbols.run_id = runs.id
        WHERE runs.id = ?
        GROUP BY
            runs.id,
            runs.created_at,
            runs.root_path
        """,
        [run_id],
    ).fetchone()

    print(f"run_id      : {row[0]}")
    print(f"created_at  : {row[1]}")
    print(f"root_path   : {row[2]}")
    print(f"symbols     : {row[3]}")


# =============================================================================
# Main
# =============================================================================


def main() -> None:
    connection = connect_database()

    try:
        run_id = latest_run_id(connection)

        print_inspector_summary(connection, run_id)
        print_run_summary(connection, run_id)
    finally:
        connection.close()


if __name__ == "__main__":
    main()