#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from datetime import date
from pathlib import Path


SECTION_PATTERN = re.compile(r"^## \d{4}/\d{2}/\d{2}$", re.MULTILINE)
DATE_PATTERN = re.compile(r"^\d{4}/\d{2}/\d{2}$")
DATE_PATTERN_DASH = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rotate old history sections from *-latest.md into *-log.md."
    )
    parser.add_argument(
        "--history-dir",
        default=str(Path(__file__).resolve().parents[2] / "docs" / "history"),
    )
    parser.add_argument("--today", default=date.today().strftime("%Y/%m/%d"))
    return parser.parse_args()


def normalize_today(raw_today: str) -> str:
    if DATE_PATTERN.fullmatch(raw_today):
        return raw_today
    if DATE_PATTERN_DASH.fullmatch(raw_today):
        return raw_today.replace("-", "/")
    raise SystemExit("--today must be YYYY/MM/DD or YYYY-MM-DD")


def split_sections(text: str) -> list[str]:
    stripped = text.strip()
    if not stripped:
        return []
    starts = [match.start() for match in SECTION_PATTERN.finditer(stripped)]
    if not starts:
        raise SystemExit("History file does not start with date headings")

    sections: list[str] = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(stripped)
        sections.append(stripped[start:end].strip())
    return sections


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def first_heading(sections: list[str]) -> str | None:
    if not sections:
        return None
    return sections[0].splitlines()[0].replace("## ", "", 1).strip()


def today_section(today: str) -> str:
    return f"## {today}"


def rotate_pair(history_dir: Path, stem: str, today: str) -> None:
    latest_path = history_dir / f"{stem}-latest.md"
    log_path = history_dir / f"{stem}-log.md"

    latest_sections = split_sections(read_text(latest_path))
    if not latest_sections:
        write_text(latest_path, today_section(today) + "\n")
        return
    if first_heading(latest_sections) == today:
        return

    keep_sections: list[str] = []
    rotate_sections: list[str] = []
    for section in latest_sections:
        heading = section.splitlines()[0].replace("## ", "", 1).strip()
        if heading == today:
            keep_sections.append(section)
        else:
            rotate_sections.append(section)

    if rotate_sections:
        log_sections = split_sections(read_text(log_path))
        merged_log = rotate_sections + log_sections
        write_text(log_path, "\n\n".join(merged_log).rstrip() + "\n")

    if keep_sections:
        write_text(latest_path, "\n\n".join(keep_sections).rstrip() + "\n")
    else:
        write_text(latest_path, today_section(today) + "\n")


def main() -> int:
    args = parse_args()
    history_dir = Path(args.history_dir).expanduser().resolve()
    today = normalize_today(args.today)
    for stem in ("chat", "metrics", "decisions"):
        rotate_pair(history_dir, stem, today)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
