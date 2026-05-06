#!/usr/bin/env python3

from __future__ import annotations

import sqlite3
import time
from pathlib import Path

DATABASE_PATH = Path(__file__).resolve().parent / "inspector.db"

# TODO View6C: extend timing observability details
# TODO View7B: expand graph-quality summary metrics


def print_section(title: str) -> None:
    print(title)
    print("-" * len(title))


def short_kind(kind: str) -> str:
    return kind.replace("source.lang.swift.decl.", "")


def annotated_or_name(row: sqlite3.Row) -> str:
    return row["annotated_decl"] or row["name"]


def readable_owner_name(row: sqlite3.Row) -> str:
    return row["readable_owner_name"] or row["effective_owner_name"] or row["name"] or "<root>"


def display_identity(
    usr: str | None,
    symbol_id: str | None,
) -> str:
    if usr:
        return usr

    return ""


def is_type_kind(kind: str) -> bool:
    return any(
        token in kind
        for token in [
            ".class",
            ".struct",
            ".enum",
            ".protocol",
            ".actor",
            ".extension",
        ]
    )


def is_framework_fragmentation_target(name: str) -> bool:
    return name not in {
        "View",
        "ObservableObject",
        "Codable",
        "Equatable",
        "Hashable",
        "Identifiable",
        "Sendable",
    }


TYPE_KIND_SQL = """
(
    kind LIKE '%struct%'
    OR kind LIKE '%class%'
    OR kind LIKE '%enum%'
    OR kind LIKE '%actor%'
    OR kind LIKE '%extension%'
)
"""


LATEST_RUN_ID: int | None = None


def run_timed_section(
    title: str,
    callback,
) -> None:
    start_time = time.perf_counter()

    print(f"[VIEW] START {title}")

    callback()

    elapsed = time.perf_counter() - start_time

    print(f"[VIEW] END   {title} ({elapsed:.3f}s)")
    print()


def main() -> None:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row

    global LATEST_RUN_ID

    LATEST_RUN_ID = connection.execute("SELECT MAX(run_id) FROM symbols").fetchone()[0]

    print(f"[VIEW] latest_run_id={LATEST_RUN_ID}")

    try:
        run_timed_section(
            "SUMMARY",
            lambda: print_summary(connection),
        )

        run_timed_section(
            "TYPE HOTSPOTS",
            lambda: print_type_hotspots(connection),
        )

        run_timed_section(
            "EXTENSION HOTSPOTS",
            lambda: print_extension_hotspots(connection),
        )

        run_timed_section(
            "SYMBOL KINDS",
            lambda: print_kind_summary(connection),
        )

        run_timed_section(
            "LARGEST FILES",
            lambda: print_largest_files(connection),
        )

        run_timed_section(
            "TYPE DENSITY",
            lambda: print_type_density(connection),
        )

        run_timed_section(
            "OWNERSHIP CHAIN",
            lambda: print_ownership_chain(connection),
        )

        run_timed_section(
            "EXTENSION FRAGMENTATION",
            lambda: print_extension_fragmentation(connection),
        )

        run_timed_section(
            "PARENT FANOUT",
            lambda: print_parent_fanout(connection),
        )

        run_timed_section(
            "PARENT KIND DISTRIBUTION",
            lambda: print_parent_kind_distribution(connection),
        )

        run_timed_section(
            "SYMBOL DUPLICATION",
            lambda: print_symbol_duplication(connection),
        )

        run_timed_section(
            "PARENT GRAPH ANOMALY",
            lambda: print_parent_graph_anomaly(connection),
        )

        run_timed_section(
            "TYPE CHILD BREAKDOWN",
            lambda: print_type_child_breakdown(connection),
        )

        run_timed_section(
            "MISSING USR BY KIND",
            lambda: print_missing_usr_by_kind(connection),
        )

        run_timed_section(
            "FILE KIND COMPOSITION",
            lambda: print_file_kind_composition(connection),
        )

        run_timed_section(
            "RUN SUMMARY",
            lambda: print_run_summary(connection),
        )

        run_timed_section(
            "MISSING USR",
            lambda: print_missing_usr_symbols(connection),
        )
    finally:
        connection.close()


def print_summary(connection: sqlite3.Connection) -> None:
    symbol_count = connection.execute(
        """
        SELECT COUNT(*)
        FROM symbols
        WHERE symbols.run_id = ?
        """,
        (LATEST_RUN_ID,),
    ).fetchone()[0]

    file_count = connection.execute(
        """
        SELECT COUNT(DISTINCT file_path)
        FROM symbols
        WHERE symbols.run_id = ?
        """,
        (LATEST_RUN_ID,),
    ).fetchone()[0]

    print("################################################################################")
    print("# INSPECTOR SUMMARY")
    print("################################################################################")
    print()
    print(f"DATABASE : {DATABASE_PATH}")
    print(f"FILES    : {file_count}")
    print(f"SYMBOLS  : {symbol_count}")
    print()


# --- Graph-oriented inspector views ---


def print_type_hotspots(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            file_path,
            name,
            total_span_lines,
            kind,
            annotated_decl,
            COUNT(*) AS child_count
        FROM symbols
        WHERE symbols.run_id = ?
            AND total_span_lines IS NOT NULL
            AND (
                kind LIKE '%struct%'
                OR kind LIKE '%class%'
                OR kind LIKE '%enum%'
                OR kind LIKE '%actor%'
            )
        GROUP BY symbol_id
        ORDER BY total_span_lines DESC, child_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("TYPE HOTSPOTS")

    for row in rows:
        kind_name = short_kind(row["kind"])
        decl = annotated_or_name(row)

        print(f"{row['total_span_lines']:>4} lines  children:{row['child_count']:>3}  [{kind_name}] {decl}  ({row['file_path']})")

    print()


def print_extension_hotspots(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            file_path,
            name,
            total_span_lines,
            kind,
            annotated_decl
        FROM symbols
        WHERE symbols.run_id = ?
            AND total_span_lines IS NOT NULL
            AND kind LIKE '%extension%'
        ORDER BY total_span_lines DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("EXTENSION HOTSPOTS")

    for row in rows:
        kind_name = short_kind(row["kind"])
        decl = annotated_or_name(row)

        print(f"{row['total_span_lines']:>4} lines  [{kind_name}] {decl}  ({row['file_path']})")

    print()


def print_kind_summary(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            kind,
            COUNT(*) AS count
        FROM symbols
        WHERE symbols.run_id = ?
        GROUP BY kind
        ORDER BY count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("SYMBOL KINDS")

    for row in rows:
        kind_name = short_kind(row["kind"])

        print(f"{row['count']:>6}  {kind_name}")

    print()


def print_largest_files(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            file_path,
            COUNT(*) AS symbol_count,
            COUNT(DISTINCT parent_symbol_id) AS parent_count,
            MAX(total_span_lines) AS max_line_count
        FROM symbols
        WHERE symbols.run_id = ?
        GROUP BY file_path
        ORDER BY symbol_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("LARGEST FILES")

    for row in rows:
        print(f"{row['symbol_count']:>4} symbols  parents:{row['parent_count']:>4}  max:{row['max_line_count'] or 0:>4}  {row['file_path']}")

    print()


def print_type_density(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            symbols.effective_owner_symbol_id AS owner_symbol_id,
            symbols.effective_owner_usr AS owner_usr,
            MIN(owner.readable_owner_name) AS owner_name,
            MIN(owner.kind) AS owner_kind,
            COUNT(*) AS symbol_count,
            COUNT(DISTINCT symbols.file_path) AS file_count
        FROM symbols
        JOIN symbols AS owner
            ON owner.symbol_id = symbols.effective_owner_symbol_id
            AND owner.run_id = symbols.run_id
        WHERE symbols.run_id = ?
            AND symbols.effective_owner_symbol_id != ''
            AND {type_kind_sql}
        GROUP BY symbols.effective_owner_symbol_id, symbols.effective_owner_usr
        HAVING symbol_count >= 8
        ORDER BY symbol_count DESC, file_count DESC
        LIMIT 20
        """.format(type_kind_sql=TYPE_KIND_SQL.replace("kind", "owner.kind")),
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("TYPE DENSITY")

    for row in rows:
        if not is_type_kind(row["owner_kind"]):
            continue
        parent_identity = display_identity(
            row["owner_usr"],
            row["owner_symbol_id"],
        )

        print(f"{row['symbol_count']:>4} symbols  {row['file_count']:>2} files  {row['owner_name']}  ({parent_identity})")

    print()


def print_missing_usr_symbols(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            name,
            kind,
            file_path,
            annotated_decl
        FROM symbols
        WHERE symbols.run_id = ?
            AND usr = ''
            AND is_system = 0
        ORDER BY file_path, name
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("MISSING USR")

    if not rows:
        print("none")
        print()
        return

    seen_missing_symbols: set[tuple[str, str]] = set()

    for row in rows:
        kind_name = short_kind(row["kind"])
        decl = annotated_or_name(row)

        dedupe_key = (
            kind_name,
            decl,
        )

        if dedupe_key in seen_missing_symbols:
            continue

        seen_missing_symbols.add(dedupe_key)

        print(f"[{kind_name}] {decl}  ({row['file_path']})")

    print()


def print_extension_fragmentation(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            name,
            COUNT(DISTINCT file_path) AS file_count,
            COUNT(*) AS symbol_count
        FROM symbols
        WHERE symbols.run_id = ?
            AND kind LIKE '%extension%'
            AND name NOT IN (
                'View',
                'ObservableObject',
                'Codable',
                'Equatable',
                'Hashable',
                'Identifiable',
                'Sendable'
            )
        GROUP BY name
        HAVING file_count > 1
        ORDER BY file_count DESC, symbol_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("EXTENSION FRAGMENTATION")

    if not rows:
        print("none")
        print()
        return

    for row in rows:
        if not is_framework_fragmentation_target(row["name"]):
            continue
        print(f"{row['file_count']:>2} files  {row['symbol_count']:>4} symbols  {row['name']}")

    print()


def print_ownership_chain(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            child.name AS child_name,
            child.kind AS child_kind,
            parent.name AS parent_name,
            parent.kind AS parent_kind,
            grandparent.name AS grandparent_name,
            grandparent.kind AS grandparent_kind,
            child.file_path AS file_path
        FROM symbols AS child
        LEFT JOIN symbols AS parent
            ON parent.symbol_id = child.parent_symbol_id
            AND parent.run_id = child.run_id
        LEFT JOIN symbols AS grandparent
            ON grandparent.symbol_id = parent.parent_symbol_id
            AND grandparent.run_id = parent.run_id
        WHERE child.run_id = ?
            AND child.parent_symbol_id != ''
        ORDER BY child.total_span_lines DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("OWNERSHIP CHAIN")

    for row in rows:
        child_kind = short_kind(row["child_kind"] or "")
        parent_kind = short_kind(row["parent_kind"] or "")
        grandparent_kind = short_kind(row["grandparent_kind"] or "")

        print(
            f"[{child_kind}] {row['child_name']}"
            f" -> [{parent_kind}] {row['parent_name']}"
            f" -> [{grandparent_kind}] {row['grandparent_name']}"
            f" ({row['file_path']})"
        )

    print()


def print_parent_fanout(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            parent.symbol_id AS parent_symbol_id,
            parent.usr AS parent_usr,
            parent.kind AS parent_kind,
            parent.annotated_decl AS parent_decl,
            parent.readable_owner_name AS readable_owner_name,
            COUNT(child.symbol_id) AS child_count
        FROM symbols AS child
        JOIN symbols AS parent
            ON parent.symbol_id = child.effective_owner_symbol_id
            AND parent.run_id = child.run_id
        WHERE child.run_id = ?
            AND child.effective_owner_symbol_id != ''
            AND {type_kind_sql}
        GROUP BY parent.symbol_id
        ORDER BY child_count DESC
        LIMIT 20
        """.format(type_kind_sql=TYPE_KIND_SQL.replace("kind", "parent.kind")),
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("PARENT FANOUT")

    for row in rows:
        kind_name = short_kind(row["parent_kind"])
        owner_name = row["readable_owner_name"] or row["parent_decl"]

        print(f"{row['child_count']:>4} children  [{kind_name}] {owner_name}")

    print()


def print_parent_kind_distribution(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            parent.kind AS parent_kind,
            COUNT(child.symbol_id) AS child_count,
            COUNT(DISTINCT parent.symbol_id) AS parent_count,
            AVG(child.total_span_lines) AS average_child_size
        FROM symbols AS child
        JOIN symbols AS parent
            ON parent.symbol_id = child.parent_symbol_id
            AND parent.run_id = child.run_id
        WHERE child.run_id = ?
            AND child.parent_symbol_id != ''
        GROUP BY parent.kind
        ORDER BY child_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("PARENT KIND DISTRIBUTION")

    for row in rows:
        kind_name = short_kind(row["parent_kind"])

        print(f"{row['child_count']:>5} children  {row['parent_count']:>4} parents  avg:{row['average_child_size'] or 0:>6.1f}  [{kind_name}]")

    print()


def print_symbol_duplication(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            symbol_id,
            name,
            kind,
            COUNT(*) AS duplicate_count,
            COUNT(DISTINCT parent_symbol_id) AS parent_variants,
            COUNT(DISTINCT file_path) AS file_variants
        FROM symbols
        WHERE symbols.run_id = ?
        GROUP BY symbol_id
        HAVING duplicate_count > 1
        ORDER BY duplicate_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("SYMBOL DUPLICATION")

    if not rows:
        print("none")
        print()
        return

    for row in rows:
        kind_name = short_kind(row["kind"])

        print(f"dup:{row['duplicate_count']:>3}  parents:{row['parent_variants']:>2}  files:{row['file_variants']:>2}  [{kind_name}] {row['name']}")

    print()


def print_parent_graph_anomaly(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            child.symbol_id AS child_symbol_id,
            child.name AS child_name,
            child.kind AS child_kind,
            child.parent_symbol_id AS parent_symbol_id,
            child.parent_usr AS parent_usr
        FROM symbols AS child
        WHERE child.run_id = ?
            AND (
                child.symbol_id = child.parent_symbol_id
                OR (
                    child.usr != ''
                    AND child.usr = child.parent_usr
                )
            )
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("PARENT GRAPH ANOMALY")

    if not rows:
        print("none")
        print()
        return

    for row in rows:
        kind_name = short_kind(row["child_kind"])

        print(f"[{kind_name}] {row['child_name']}  self-parent:{row['child_symbol_id'] == row['parent_symbol_id']}")

    print()


def print_type_child_breakdown(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            parent.annotated_decl AS parent_decl,
            parent.readable_owner_name AS readable_owner_name,
            child.kind AS child_kind,
            COUNT(*) AS child_count
        FROM symbols AS child
        JOIN symbols AS parent
            ON parent.symbol_id = child.effective_owner_symbol_id
            AND parent.run_id = child.run_id
        WHERE child.run_id = ?
            AND {type_kind_sql}
        GROUP BY parent.symbol_id, child.kind
        ORDER BY child_count DESC
        LIMIT 20
        """.format(type_kind_sql=TYPE_KIND_SQL.replace("kind", "parent.kind")),
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("TYPE CHILD BREAKDOWN")

    for row in rows:
        kind_name = short_kind(row["child_kind"])
        owner_name = row["readable_owner_name"] or row["parent_decl"]

        print(f"{row['child_count']:>4} children  [{kind_name}] {owner_name}")

    print()


def print_missing_usr_by_kind(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            kind,
            COUNT(*) AS missing_count,
            MIN(annotated_decl) AS sample_decl
        FROM symbols
        WHERE symbols.run_id = ?
            AND usr = ''
            AND is_system = 0
        GROUP BY kind
        ORDER BY missing_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("MISSING USR BY KIND")

    for row in rows:
        kind_name = short_kind(row["kind"])

        print(f"{row['missing_count']:>4} missing  [{kind_name}] {row['sample_decl']}")

    print()


def print_file_kind_composition(
    connection: sqlite3.Connection,
) -> None:
    rows = connection.execute(
        """
        SELECT
            file_path,
            kind,
            COUNT(*) AS kind_count
        FROM symbols
        WHERE symbols.run_id = ?
        GROUP BY file_path, kind
        ORDER BY kind_count DESC
        LIMIT 20
        """,
        (LATEST_RUN_ID,),
    ).fetchall()

    print_section("FILE KIND COMPOSITION")

    for row in rows:
        kind_name = short_kind(row["kind"])

        print(f"{row['kind_count']:>4}  [{kind_name}] {row['file_path']}")

    print()


def print_run_summary(connection: sqlite3.Connection) -> None:
    rows = connection.execute(
        """
        SELECT
            run_id,
            COUNT(*) AS symbol_count
        FROM symbols
        GROUP BY run_id
        ORDER BY run_id DESC
        LIMIT 20
        """
    ).fetchall()

    print_section("RUN SUMMARY")

    for row in rows:
        print(f"run:{row['run_id']:>4}  symbols:{row['symbol_count']:>6}")

    print()


if __name__ == "__main__":
    main()
