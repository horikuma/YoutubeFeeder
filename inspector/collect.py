

#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DATABASE_PATH = Path(__file__).resolve().parent / "inspector.db"


@dataclass
class Symbol:
    symbol_id: str
    file_path: str
    kind: str
    access: str
    name: str
    typename: str
    line_count: int | None
    attributes: str


def main() -> None:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()

    connection = sqlite3.connect(DATABASE_PATH)
    try:
        initialize_database(connection)

        swift_files = collect_swift_files(root)

        run_id = create_run(connection, root)

        for file_path in swift_files:
            symbols = collect_symbols(file_path, root)
            insert_symbols(connection, run_id, symbols)

        connection.commit()
    finally:
        connection.close()

    print(f"Database updated: {DATABASE_PATH}")


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
            run_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            kind TEXT NOT NULL,
            access_level TEXT NOT NULL,
            name TEXT NOT NULL,
            typename TEXT NOT NULL,
            line_count INTEGER,
            attributes TEXT NOT NULL,
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


def create_run(connection: sqlite3.Connection, root: Path) -> int:
    cursor = connection.execute(
        "INSERT INTO runs(root_path) VALUES (?)",
        (str(root),),
    )

    return int(cursor.lastrowid)


def collect_swift_files(root: Path) -> list[Path]:
    files: list[Path] = []

    for file_path in sorted(root.rglob("*.swift")):
        if "/build/" in str(file_path):
            continue

        if "/DerivedData/" in str(file_path):
            continue

        files.append(file_path)

    return files


def collect_symbols(file_path: Path, root: Path) -> list[Symbol]:
    result = subprocess.run(
        ["sourcekitten", "structure", "--file", str(file_path)],
        capture_output=True,
        text=True,
        check=True,
    )

    payload = json.loads(result.stdout)

    symbols: list[Symbol] = []

    for node in walk_nodes(payload):
        kind = node.get("key.kind", "")

        if kind not in supported_kinds():
            continue

        relative_path = str(file_path.relative_to(root))

        name = node.get("key.name", "")
        access = node.get("key.accessibility", "")
        typename = node.get("key.typename", "")

        offset = node.get("key.offset")
        length = node.get("key.length")

        line_count = calculate_line_count(file_path, offset, length)

        attributes = ",".join(
            attribute.get("key.attribute", "")
            for attribute in node.get("key.attributes", [])
        )

        symbol_id = build_symbol_id(relative_path, kind, name)

        symbols.append(
            Symbol(
                symbol_id=symbol_id,
                file_path=relative_path,
                kind=kind,
                access=access,
                name=name,
                typename=typename,
                line_count=line_count,
                attributes=attributes,
            )
        )

    return symbols


def walk_nodes(node: dict) -> Iterable[dict]:
    yield node

    for child in node.get("key.substructure", []):
        yield from walk_nodes(child)


def supported_kinds() -> set[str]:
    return {
        "source.lang.swift.decl.function.method.instance",
        "source.lang.swift.decl.function.method.class",
        "source.lang.swift.decl.function.method.static",
        "source.lang.swift.decl.function.free",
        "source.lang.swift.decl.function.constructor",
        "source.lang.swift.decl.function.destructor",
        "source.lang.swift.decl.var.instance",
        "source.lang.swift.decl.var.static",
        "source.lang.swift.decl.var.class",
        "source.lang.swift.decl.class",
        "source.lang.swift.decl.struct",
        "source.lang.swift.decl.enum",
        "source.lang.swift.decl.protocol",
        "source.lang.swift.decl.extension",
    }


def calculate_line_count(
    file_path: Path,
    offset: int | None,
    length: int | None,
) -> int | None:
    if offset is None or length is None:
        return None

    content = file_path.read_text(encoding="utf-8")
    fragment = content[offset : offset + length]

    return fragment.count("\n") + 1


def build_symbol_id(
    relative_path: str,
    kind: str,
    name: str,
) -> str:
    digest = hashlib.sha1(
        f"{relative_path}:{kind}:{name}".encode("utf-8")
    ).hexdigest()

    return digest


def insert_symbols(
    connection: sqlite3.Connection,
    run_id: int,
    symbols: list[Symbol],
) -> None:
    connection.executemany(
        """
        INSERT OR REPLACE INTO symbols(
            symbol_id,
            run_id,
            file_path,
            kind,
            access_level,
            name,
            typename,
            line_count,
            attributes
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                symbol.symbol_id,
                run_id,
                symbol.file_path,
                symbol.kind,
                symbol.access,
                symbol.name,
                symbol.typename,
                symbol.line_count,
                symbol.attributes,
            )
            for symbol in symbols
        ],
    )


if __name__ == "__main__":
    main()