#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

import duckdb

from collect_database import DATABASE_PATH

LATEST_RUN_ID_SQL = "SELECT MAX(id) FROM runs"

TYPE_KIND_SQL = "kind LIKE 'source.lang.swift.decl.%'"


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


def query_rows(
    connection: duckdb.DuckDBPyConnection,
    sql: str,
    parameters: list[object] | tuple[object, ...],
) -> list[dict[str, object]]:
    cursor = connection.execute(sql, parameters)

    columns = [column[0] for column in cursor.description]

    return [
        dict(zip(columns, row, strict=False))
        for row in cursor.fetchall()
    ]


# =============================================================================
# Architecture views
# =============================================================================


def print_largest_files(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("LARGEST FILES")

    rows = query_rows(
        connection,
        """
        SELECT
            file_path,
            COUNT(*) AS symbol_count
        FROM inspector.symbols
        WHERE run_id = ?
        GROUP BY file_path
        ORDER BY symbol_count DESC
        LIMIT 20
        """,
        (run_id,),
    )

    for row in rows:
        file_path = Path(str(row["file_path"])).name

        print(
            f"{row['symbol_count']:>4} symbols  {file_path}"
        )


def print_type_hotspots(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("TYPE HOTSPOTS")

    rows = query_rows(
        connection,
        """
        SELECT
            readable_owner_name,
            effective_owner_kind,
            COUNT(*) AS child_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name != ''
            AND effective_owner_name != '<root>'
            AND kind LIKE 'source.lang.swift.decl.%'
        GROUP BY
            readable_owner_name,
            effective_owner_kind
        HAVING child_count >= 8
        ORDER BY child_count DESC
        LIMIT 20
        """,
        (run_id,),
    )

    for row in rows:
        owner_name = str(row["readable_owner_name"])
        owner_kind = str(row["effective_owner_kind"])

        print(
            f"{row['child_count']:>4} children  "
            f"[{owner_kind}] {owner_name}"
        )


def print_extension_hotspots(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("EXTENSION HOTSPOTS")

    rows = query_rows(
        connection,
        """
        SELECT
            name,
            COUNT(DISTINCT file_path) AS file_count,
            COUNT(*) AS symbol_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND kind = 'source.lang.swift.decl.extension'
        GROUP BY name
        HAVING file_count >= 2
        ORDER BY file_count DESC, symbol_count DESC
        LIMIT 20
        """,
        [run_id],
    )

    if not rows:
        print("none")
        return

    for row in rows:
        print(
            f"{row['file_count']:>4} files  "
            f"{row['symbol_count']:>4} symbols  "
            f"{row['name']}"
        )



def print_symbol_kinds(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("SYMBOL KINDS")

    rows = query_rows(
        connection,
        """
        SELECT
            kind,
            COUNT(*) AS symbol_count
        FROM inspector.symbols
        WHERE run_id = ?
        GROUP BY kind
        ORDER BY symbol_count DESC
        LIMIT 30
        """,
        [run_id],
    )

    for row in rows:
        print(
            f"{row['symbol_count']:>5}  {row['kind']}"
        )



def print_type_density(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("TYPE DENSITY")

    rows = query_rows(
        connection,
        """
        SELECT
            readable_owner_name,
            effective_owner_kind,
            COUNT(*) AS symbol_count,
            COUNT(DISTINCT file_path) AS file_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name != ''
            AND effective_owner_name != '<root>'
            AND kind LIKE 'source.lang.swift.decl.%'
        GROUP BY
            readable_owner_name,
            effective_owner_kind
        HAVING symbol_count >= 8
        ORDER BY symbol_count DESC
        LIMIT 20
        """,
        [run_id],
    )

    for row in rows:
        print(
            f"{row['symbol_count']:>4} symbols  "
            f"{row['file_count']:>3} files  "
            f"[{row['effective_owner_kind']}] "
            f"{row['readable_owner_name']}"
        )



def print_parent_kind_distribution(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("PARENT KIND DISTRIBUTION")

    rows = query_rows(
        connection,
        """
        SELECT
            effective_owner_kind,
            COUNT(*) AS child_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_kind != ''
        GROUP BY effective_owner_kind
        ORDER BY child_count DESC
        LIMIT 20
        """,
        [run_id],
    )

    for row in rows:
        print(
            f"{row['child_count']:>5} children  "
            f"[{row['effective_owner_kind']}]"
        )



def print_file_kind_composition(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("FILE KIND COMPOSITION")

    rows = query_rows(
        connection,
        """
        SELECT
            file_path,
            kind,
            COUNT(*) AS symbol_count
        FROM inspector.symbols
        WHERE run_id = ?
        GROUP BY file_path, kind
        HAVING symbol_count >= 5
        ORDER BY symbol_count DESC
        LIMIT 40
        """,
        [run_id],
    )

    for row in rows:
        file_name = Path(str(row['file_path'])).name

        print(
            f"{row['symbol_count']:>4}  "
            f"[{row['kind']}] {file_name}"
        )


def print_parent_fanout(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("PARENT FANOUT")

    rows = query_rows(
        connection,
        """
        SELECT
            readable_owner_name,
            effective_owner_kind,
            COUNT(*) AS child_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name != ''
            AND effective_owner_name != '<root>'
        GROUP BY
            readable_owner_name,
            effective_owner_kind
        HAVING child_count >= 8
        ORDER BY child_count DESC
        LIMIT 20
        """,
        (run_id,),
    )

    for row in rows:
        print(
            f"{row['child_count']:>4} children  "
            f"[{row['effective_owner_kind']}] "
            f"{row['readable_owner_name']}"
        )


def print_type_child_breakdown(
    connection: duckdb.DuckDBPyConnection,
    run_id: int,
) -> None:
    print_section("TYPE CHILD BREAKDOWN")

    rows = query_rows(
        connection,
        """
        SELECT
            readable_owner_name,
            kind,
            COUNT(*) AS child_count
        FROM inspector.symbols
        WHERE run_id = ?
            AND effective_owner_name != ''
            AND effective_owner_name != '<root>'
        GROUP BY
            readable_owner_name,
            kind
        HAVING child_count >= 5
        ORDER BY child_count DESC
        LIMIT 40
        """,
        (run_id,),
    )

    for row in rows:
        print(
            f"{row['child_count']:>4} children  "
            f"[{row['kind']}] "
            f"{row['readable_owner_name']}"
        )


# =============================================================================
# Main
# =============================================================================


def main() -> None:
    connection = connect_database()

    try:
        run_id = latest_run_id(connection)

        print_largest_files(connection, run_id)
        print_type_hotspots(connection, run_id)
        print_extension_hotspots(connection, run_id)
        print_symbol_kinds(connection, run_id)
        print_type_density(connection, run_id)
        print_parent_fanout(connection, run_id)
        print_parent_kind_distribution(connection, run_id)
        print_type_child_breakdown(connection, run_id)
        print_file_kind_composition(connection, run_id)
    finally:
        connection.close()


if __name__ == "__main__":
    main()