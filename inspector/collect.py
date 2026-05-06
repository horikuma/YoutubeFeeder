#!/usr/bin/env python3

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

DATABASE_PATH = Path(__file__).resolve().parent / "inspector.db"


def initialize_database(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            root_path TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS raw_sourcekitten (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """
    )


def create_run(
    connection: sqlite3.Connection,
    root: Path,
) -> int:
    cursor = connection.execute(
        "INSERT INTO runs(root_path) VALUES (?)",
        (str(root),),
    )

    return int(cursor.lastrowid)


def collect_swift_files(root: Path) -> list[Path]:
    return sorted(root.rglob("*.swift"))


def collect_sourcekitten_payload(
    file_path: Path,
) -> dict:
    result = subprocess.run(
        ["sourcekitten", "structure", "--file", str(file_path)],
        capture_output=True,
        text=True,
        check=True,
    )

    return json.loads(result.stdout)


def insert_payload(
    connection: sqlite3.Connection,
    run_id: int,
    root: Path,
    file_path: Path,
    payload: dict,
) -> None:
    relative_path = str(file_path.relative_to(root))

    connection.execute(
        """
        INSERT INTO raw_sourcekitten(
            run_id,
            file_path,
            payload_json
        )
        VALUES (?, ?, ?)
        """,
        (
            run_id,
            relative_path,
            json.dumps(payload, ensure_ascii=False),
        ),
    )


def main() -> None:
    root = (
        Path(sys.argv[1]).resolve()
        if len(sys.argv) > 1
        else Path.cwd()
    )

    connection = sqlite3.connect(DATABASE_PATH)

    try:
        initialize_database(connection)

        run_id = create_run(connection, root)

        swift_files = collect_swift_files(root)

        for file_path in swift_files:
            payload = collect_sourcekitten_payload(file_path)

            insert_payload(
                connection,
                run_id,
                root,
                file_path,
                payload,
            )

        connection.commit()
    finally:
        connection.close()

    print(f"Database updated: {DATABASE_PATH}")


if __name__ == "__main__":
    main()
