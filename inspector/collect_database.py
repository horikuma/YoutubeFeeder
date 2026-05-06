from __future__ import annotations

import sqlite3
from pathlib import Path

from collect_models import Symbol

DATABASE_PATH = Path(__file__).resolve().parent / "inspector.db"


def readable_owner_name(symbol: Symbol) -> str:
    return symbol.effective_owner_name


def persisted_owner_name(symbol: Symbol) -> str:
    return readable_owner_name(symbol)


def ensure_column(
    connection: sqlite3.Connection,
    existing_columns: set[str],
    column_name: str,
    column_sql: str,
) -> None:
    if column_name in existing_columns:
        return

    connection.execute(f"ALTER TABLE symbols ADD COLUMN {column_sql}")


def ensure_symbol_schema(
    connection: sqlite3.Connection,
    existing_columns: set[str],
) -> None:
    ensure_column(connection, existing_columns, "usr", "usr TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "parent_symbol_id", "parent_symbol_id TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "parent_usr", "parent_usr TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "parent_kind", "parent_kind TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "effective_owner_symbol_id", "effective_owner_symbol_id TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "effective_owner_usr", "effective_owner_usr TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "effective_owner_kind", "effective_owner_kind TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "effective_owner_name", "effective_owner_name TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "readable_owner_name", "readable_owner_name TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "annotated_decl", "annotated_decl TEXT NOT NULL DEFAULT ''")

    ensure_column(connection, existing_columns, "is_system", "is_system INTEGER NOT NULL DEFAULT 0")

    ensure_column(connection, existing_columns, "direct_child_count", "direct_child_count INTEGER NOT NULL DEFAULT 0")

    ensure_column(connection, existing_columns, "nested_depth", "nested_depth INTEGER NOT NULL DEFAULT 0")

    ensure_column(connection, existing_columns, "total_span_lines", "total_span_lines INTEGER")

    ensure_column(connection, existing_columns, "declaration_lines", "declaration_lines INTEGER")

    ensure_column(connection, existing_columns, "nested_subtree_lines", "nested_subtree_lines INTEGER")


# =============================================================================
# INSPECTOR_BLOCK_DATABASE_SCHEMA
# =============================================================================


def initialize_database(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            root_path TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS symbols (
            symbol_id TEXT NOT NULL,
            usr TEXT NOT NULL,
            parent_symbol_id TEXT NOT NULL,
            parent_usr TEXT NOT NULL,
            parent_kind TEXT NOT NULL,
            effective_owner_symbol_id TEXT NOT NULL,
            effective_owner_usr TEXT NOT NULL,
            effective_owner_kind TEXT NOT NULL,
            effective_owner_name TEXT NOT NULL,
            readable_owner_name TEXT NOT NULL,
            run_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            kind TEXT NOT NULL,
            access_level TEXT NOT NULL,
            name TEXT NOT NULL,
            typename TEXT NOT NULL,
            total_span_lines INTEGER,
            declaration_lines INTEGER,
            direct_child_count INTEGER NOT NULL,
            nested_depth INTEGER NOT NULL,
            nested_subtree_lines INTEGER,
            attributes TEXT NOT NULL,
            annotated_decl TEXT NOT NULL,
            is_system INTEGER NOT NULL,
            PRIMARY KEY(symbol_id, run_id)
        );

        CREATE INDEX IF NOT EXISTS symbols_file_path_index
        ON symbols(file_path);

        CREATE INDEX IF NOT EXISTS symbols_name_index
        ON symbols(name);

        CREATE INDEX IF NOT EXISTS symbols_kind_index
        ON symbols(kind);
        """
    )

    existing_columns = {row[1] for row in connection.execute("PRAGMA table_info(symbols)")}

    ensure_symbol_schema(
        connection,
        existing_columns,
    )


# =============================================================================
# INSPECTOR_BLOCK_DATABASE_RUNS
# =============================================================================


def create_run(connection: sqlite3.Connection, root: Path) -> int:
    cursor = connection.execute(
        "INSERT INTO runs(root_path) VALUES (?)",
        (str(root),),
    )

    return int(cursor.lastrowid)


# =============================================================================
# INSPECTOR_BLOCK_DATABASE_FILE_DISCOVERY
# =============================================================================


def collect_swift_files(root: Path) -> list[Path]:
    files: list[Path] = []

    for file_path in sorted(root.rglob("*.swift")):
        if "/build/" in str(file_path):
            continue

        if "/DerivedData/" in str(file_path):
            continue

        files.append(file_path)

    return files


# =============================================================================
# INSPECTOR_BLOCK_DATABASE_PERSISTENCE
# =============================================================================


def insert_symbols(
    connection: sqlite3.Connection,
    run_id: int,
    symbols: list[Symbol],
) -> None:
    placeholders = ", ".join(["?"] * 24)

    connection.executemany(
        """
        INSERT OR REPLACE INTO symbols(
            symbol_id,
            usr,
            parent_symbol_id,
            parent_usr,
            parent_kind,
            effective_owner_symbol_id,
            effective_owner_usr,
            effective_owner_kind,
            effective_owner_name,
            readable_owner_name,
            run_id,
            file_path,
            kind,
            access_level,
            name,
            typename,
            total_span_lines,
            declaration_lines,
            direct_child_count,
            nested_depth,
            nested_subtree_lines,
            attributes,
            annotated_decl,
            is_system
        )
        VALUES ({placeholders})
        """.format(placeholders=placeholders),
        [
            (
                symbol.symbol_id,
                symbol.usr,
                symbol.parent_symbol_id,
                symbol.parent_usr,
                symbol.parent_kind,
                symbol.effective_owner_symbol_id,
                symbol.effective_owner_usr,
                symbol.effective_owner_kind,
                symbol.effective_owner_name,
                persisted_owner_name(symbol),
                run_id,
                symbol.file_path,
                symbol.kind,
                symbol.access,
                symbol.name,
                symbol.typename,
                symbol.total_span_lines,
                symbol.declaration_lines,
                symbol.direct_child_count,
                symbol.nested_depth,
                symbol.nested_subtree_lines,
                symbol.attributes,
                symbol.annotated_decl,
                int(symbol.is_system),
            )
            for symbol in symbols
        ],
    )
