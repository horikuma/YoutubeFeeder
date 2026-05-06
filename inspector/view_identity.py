

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
# Identity views
# =============================================================================


def print_missing_usr(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("MISSING USR")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND usr = ''
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



def print_duplicate_usr(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("DUPLICATE USR")

    rows = connection.execute(
        """
        SELECT
            usr,
            COUNT(*) AS duplicate_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND usr != ''
        GROUP BY usr
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





def print_missing_usr_by_kind(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("MISSING USR BY KIND")

    rows = connection.execute(
        """
        SELECT
            kind,
            COUNT(*) AS missing_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND usr = ''
        GROUP BY kind
        ORDER BY missing_count DESC
        LIMIT 30
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"{row[1]:>5} missing  [{row[0]}]"
        )


def print_symbol_id_reuse(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("SYMBOL ID REUSE")

    rows = connection.execute(
        """
        SELECT
            symbol_id,
            COUNT(DISTINCT file_path) AS file_count,
            COUNT(*) AS symbol_count
        FROM inspector.symbols
        WHERE run_id = ?
        GROUP BY symbol_id
        HAVING file_count >= 2
        ORDER BY file_count DESC, symbol_count DESC
        LIMIT 50
        """,
        [run_id],
    ).fetchall()

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"{row[1]:>4} files  "
            f"{row[2]:>4} symbols  "
            f"{row[0]}"
        )




def print_fallback_symbol_ids(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("FALLBACK SYMBOL IDS")

    rows = connection.execute(
        """
        SELECT
            kind,
            name,
            symbol_id,
            file_path
        FROM inspector.symbols
        WHERE run_id = ?
            AND usr = ''
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
            f"[{row[0]}] {row[1]}"
            f" -> {row[2]} ({row[3]})"
        )

# =============================================================================
# Main
# =============================================================================


def main() -> None:
    connection = connect_database()

    try:
        run_id = latest_run_id(connection)

        print_missing_usr(connection, run_id)
        print_missing_usr_by_kind(connection, run_id)
        print_duplicate_usr(connection, run_id)
        print_symbol_id_reuse(connection, run_id)
        print_fallback_symbol_ids(connection, run_id)
    finally:
        connection.close()


if __name__ == "__main__":
    main()