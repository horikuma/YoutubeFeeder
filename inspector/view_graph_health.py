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
# Graph health views
# =============================================================================


def print_missing_owner_links(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("MISSING OWNER LINKS")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND parent_symbol_id != ''
            AND effective_owner_symbol_id = ''
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} ({row[2]})"
        )


def print_root_collapse_anomalies(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("ROOT COLLAPSE ANOMALIES")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name = '<root>'
            AND parent_symbol_id != ''
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} ({row[2]})"
        )


def print_self_ownership(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("SELF OWNERSHIP")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND symbol_id = effective_owner_symbol_id
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} ({row[2]})"
        )


def print_parent_graph_anomalies(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("PARENT GRAPH ANOMALIES")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            parent_symbol_id,
            effective_owner_symbol_id,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND parent_symbol_id != ''
            AND effective_owner_symbol_id != ''
            AND parent_symbol_id != effective_owner_symbol_id
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} "
            f"parent={row[2]} owner={row[3]} ({row[4]})"
        )



def print_ownership_chain_breaks(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("OWNERSHIP CHAIN BREAKS")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            effective_owner_name,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_symbol_id != ''
            AND effective_owner_name = ''
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} -> owner='' ({row[3]})"
        )



def print_owner_kind_mismatches(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("OWNER KIND MISMATCHES")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            effective_owner_kind,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_symbol_id != ''
            AND effective_owner_kind = ''
        ORDER BY file_path, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[0]}] {row[1]} -> owner_kind='' ({row[3]})"
        )


def print_ownership_chain(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("OWNERSHIP CHAIN")

    rows = connection.execute(
        """
        SELECT
            name,
            kind,
            parent_symbol_id,
            effective_owner_name,
            effective_owner_kind,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name != ''
            AND effective_owner_name != '<root>'
        ORDER BY effective_owner_name, name
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"[{row[1]}] {row[0]} "
            f"-> [{row[4]}] {row[3]} "
            f"parent={row[2]} ({row[5]})"
        )

def print_duplicate_symbol_ids(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("DUPLICATE SYMBOL IDS")

    rows = connection.execute(
        """
        SELECT
            symbol_id,
            COUNT(*) AS duplicate_count
        FROM inspector.symbols
        WHERE run_id = ?
        GROUP BY symbol_id
        HAVING duplicate_count > 1
        ORDER BY duplicate_count DESC
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"{row[1]:>4} duplicates  {row[0]}"
        )


# =============================================================================
# Main
# =============================================================================


def main() -> None:
    connection = connect_database()

    try:
        run_id = latest_run_id(connection)

        print_missing_owner_links(connection, run_id)
        print_root_collapse_anomalies(connection, run_id)
        print_parent_graph_anomalies(connection, run_id)
        print_ownership_chain_breaks(connection, run_id)
        print_owner_kind_mismatches(connection, run_id)
        print_ownership_chain(connection, run_id)
        print_self_ownership(connection, run_id)
        print_duplicate_symbol_ids(connection, run_id)
    finally:
        connection.close()


if __name__ == "__main__":
    main()