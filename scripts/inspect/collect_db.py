#!/usr/bin/env python3
"""Write collect.db from SourceKit dataset rows."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from sourcekit_client.collect_data import CollectDataset


class CollectDbExportError(RuntimeError):
    pass


class CollectDbConstraintError(CollectDbExportError):
    def __init__(self, table: str, column: str, reason: str) -> None:
        super().__init__(f"collect.db export failed for {table}.{column}: {reason}")
        self.table = table
        self.column = column
        self.reason = reason


def _load_schema(schema_path: Path) -> str:
    return schema_path.read_text(encoding="utf-8")


def _execute_insert(
    cursor: sqlite3.Cursor,
    sql: str,
    values: tuple[object, ...],
    *,
    table: str,
    column: str,
) -> None:
    try:
        cursor.execute(sql, values)
    except sqlite3.IntegrityError as error:
        raise CollectDbConstraintError(table, column, str(error)) from error


def write_collect_db(datasets: list[CollectDataset], collect_db_path: Path, schema_path: Path) -> None:
    collect_db_path.parent.mkdir(parents=True, exist_ok=True)
    if collect_db_path.exists():
        collect_db_path.unlink()

    try:
        with sqlite3.connect(collect_db_path) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.executescript(_load_schema(schema_path))
            cursor = connection.cursor()

            for dataset in datasets:
                _execute_insert(
                    cursor,
                    "INSERT OR IGNORE INTO files(path) VALUES (?)",
                    (str(dataset.source_file),),
                    table="files",
                    column="path",
                )
                cursor.execute("SELECT id FROM files WHERE path = ?", (str(dataset.source_file),))
                file_id_row = cursor.fetchone()
                if file_id_row is None:
                    raise CollectDbExportError(f"missing file row for {dataset.source_file}")
                file_id = file_id_row[0]

                _execute_insert(
                    cursor,
                    "INSERT INTO translation_units(file_id, compile_directory, compile_command) VALUES (?, ?, ?)",
                    (file_id, dataset.compile_directory, dataset.compile_command),
                    table="translation_units",
                    column="compile_command",
                )
                tu_id = cursor.lastrowid

                for row in dataset.functions:
                    _execute_insert(
                        cursor,
                        "INSERT INTO functions(usr, name, file_id, line, column, is_definition) "
                        "VALUES (?, ?, ?, ?, ?, ?) "
                        "ON CONFLICT(usr) DO UPDATE SET "
                        "name = CASE "
                        "WHEN excluded.is_definition = 1 AND functions.is_definition = 0 THEN excluded.name "
                        "ELSE functions.name END, "
                        "file_id = CASE "
                        "WHEN excluded.is_definition = 1 AND functions.is_definition = 0 THEN excluded.file_id "
                        "ELSE functions.file_id END, "
                        "line = CASE "
                        "WHEN excluded.is_definition = 1 AND functions.is_definition = 0 THEN excluded.line "
                        "ELSE functions.line END, "
                        "column = CASE "
                        "WHEN excluded.is_definition = 1 AND functions.is_definition = 0 THEN excluded.column "
                        "ELSE functions.column END, "
                        "is_definition = MAX(functions.is_definition, excluded.is_definition)",
                        (row.usr, row.name, file_id, row.line, row.column, row.is_definition),
                        table="functions",
                        column="usr",
                    )

                for row in dataset.globals:
                    _execute_insert(
                        cursor,
                        "INSERT OR IGNORE INTO globals("
                        "usr, name, type, storage_class, file_id, line, column, first_seen_tu_id"
                        ") "
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        (
                            row.usr,
                            row.name,
                            row.type,
                            row.storage_class,
                            file_id,
                            row.line,
                            row.column,
                            tu_id if row.first_seen_tu_id is None else row.first_seen_tu_id,
                        ),
                        table="globals",
                        column="usr",
                    )

                for row in dataset.call_edges:
                    _execute_insert(
                        cursor,
                        "INSERT INTO call_edges("
                        "caller_usr, callee_usr, argument_summary, file_id, line, column, tu_id"
                        ") "
                        "VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (
                            row.caller_usr,
                            row.callee_usr,
                            row.argument_summary,
                            file_id,
                            row.line,
                            row.column,
                            row.tu_id if row.tu_id is not None else tu_id,
                        ),
                        table="call_edges",
                        column="caller_usr",
                    )

            connection.commit()
    except sqlite3.Error as error:
        raise CollectDbExportError(str(error)) from error
