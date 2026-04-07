#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from datetime import date
from pathlib import Path


DATE_PATTERN = re.compile(r"^\d{4}/\d{2}/\d{2}$")
DATE_PATTERN_DASH = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SECTION_PATTERN = re.compile(r"^## \d{4}/\d{2}/\d{2}$", re.MULTILINE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Append validated entries into history latest files.")
    parser.add_argument("kind", choices=("chat", "decision", "metric"))
    parser.add_argument(
        "--history-dir",
        default=str(Path(__file__).resolve().parents[2] / "docs" / "history"),
    )
    parser.add_argument("--today", default=date.today().strftime("%Y/%m/%d"))
    parser.add_argument("--user-line")
    parser.add_argument("--assistant-line")
    parser.add_argument("--decision-line")
    parser.add_argument("--reason-line")
    parser.add_argument("--metric-line")
    return parser.parse_args()


def normalize_today(raw_today: str) -> str:
    if DATE_PATTERN.fullmatch(raw_today):
        return raw_today
    if DATE_PATTERN_DASH.fullmatch(raw_today):
        return raw_today.replace("-", "/")
    raise SystemExit("--today must be YYYY/MM/DD or YYYY-MM-DD")


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


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


def heading_of(section: str) -> str:
    return section.splitlines()[0].replace("## ", "", 1).strip()


def render_sections(sections: list[str]) -> str:
    return "\n\n".join(sections).rstrip() + "\n"


def ensure_today_first(sections: list[str], today: str) -> list[str]:
    today_heading = f"## {today}"
    if not sections:
        return [today_heading]
    if heading_of(sections[0]) == today:
        return sections
    return [today_heading, *sections]


def validate_no_secrets(line: str) -> None:
    banned_fragments = ("/Users/", "/home/", "sk-", "AIza", "ghp_")
    for fragment in banned_fragments:
        if fragment in line:
            raise SystemExit(f"History line contains banned fragment: {fragment}")


def validate_chat_lines(user_line: str, assistant_line: str) -> list[str]:
    if not user_line or not assistant_line:
        raise SystemExit("chat history requires --user-line and --assistant-line")
    if "\n" in user_line or "\n" in assistant_line:
        raise SystemExit("chat history lines must be single-line")
    if not assistant_line.startswith("  - "):
        raise SystemExit("--assistant-line must start with two spaces, hyphen, and space")
    if user_line.startswith(" ") or assistant_line.startswith("   "):
        raise SystemExit("chat history indentation is invalid")
    validate_no_secrets(user_line)
    validate_no_secrets(assistant_line)
    return [user_line, assistant_line]


def validate_decision_lines(decision_line: str, reason_line: str) -> list[str]:
    if not decision_line or not reason_line:
        raise SystemExit("decision history requires --decision-line and --reason-line")
    if "\n" in decision_line or "\n" in reason_line:
        raise SystemExit("decision history lines must be single-line")
    if not decision_line.startswith("- "):
        raise SystemExit("--decision-line must start with hyphen and space")
    if not reason_line.startswith("  - "):
        raise SystemExit("--reason-line must start with two spaces, hyphen, and space")
    validate_no_secrets(decision_line)
    validate_no_secrets(reason_line)
    return [decision_line, reason_line]


def validate_metric_line(metric_line: str) -> list[str]:
    if not metric_line:
        raise SystemExit("metric history requires --metric-line")
    if "\n" in metric_line:
        raise SystemExit("metric history line must be single-line")
    if not metric_line.startswith("- "):
        raise SystemExit("--metric-line must start with hyphen and space")
    validate_no_secrets(metric_line)
    return [metric_line]


def build_entry(args: argparse.Namespace) -> list[str]:
    if args.kind == "chat":
        return validate_chat_lines(args.user_line, args.assistant_line)
    if args.kind == "decision":
        return validate_decision_lines(args.decision_line, args.reason_line)
    return validate_metric_line(args.metric_line)


def target_path(history_dir: Path, kind: str) -> Path:
    if kind == "chat":
        return history_dir / "chat-latest.md"
    if kind == "decision":
        return history_dir / "decisions-latest.md"
    return history_dir / "metrics-latest.md"


def append_entry(latest_path: Path, today: str, entry_lines: list[str]) -> None:
    sections = ensure_today_first(split_sections(read_text(latest_path)), today)
    updated_sections: list[str] = []

    for index, section in enumerate(sections):
        if index == 0 and heading_of(section) == today:
            lines = section.splitlines()
            heading = lines[0]
            body = lines[1:]
            updated_sections.append("\n".join([heading, *entry_lines, *body]).strip())
        else:
            updated_sections.append(section)

    write_text(latest_path, render_sections(updated_sections))


def validate_latest(kind: str, latest_path: Path, today: str) -> None:
    sections = split_sections(read_text(latest_path))
    if not sections:
        raise SystemExit(f"{latest_path.name} is empty")
    if heading_of(sections[0]) != today:
        raise SystemExit(f"{latest_path.name} does not start with today's heading")

    today_lines = sections[0].splitlines()[1:]
    for line in today_lines:
        if not line:
            if kind == "metric":
                continue
            raise SystemExit(f"{latest_path.name} contains empty lines in today's section")
        validate_no_secrets(line)

    if kind == "chat":
        if len(today_lines) % 2 != 0:
            raise SystemExit("chat latest must contain pairs of user and assistant lines")
        for index in range(0, len(today_lines), 2):
            if today_lines[index].startswith(" "):
                raise SystemExit("chat user line must not be indented")
            if not today_lines[index + 1].startswith("  - "):
                raise SystemExit("chat assistant line must start with two spaces, hyphen, and space")
    elif kind == "decision":
        if len(today_lines) % 2 != 0:
            raise SystemExit("decisions latest must contain pairs of decision and reason lines")
        for index in range(0, len(today_lines), 2):
            if not today_lines[index].startswith("- "):
                raise SystemExit("decision line must start with hyphen and space")
            if not today_lines[index + 1].startswith("  - "):
                raise SystemExit("decision reason must start with two spaces, hyphen, and space")
    else:
        for line in today_lines:
            if not line:
                continue
            if line.startswith("### "):
                validate_no_secrets(line)
                continue
            if not line.startswith("- "):
                raise SystemExit("metrics latest lines must start with hyphen and space or metrics entry headings")


def main() -> int:
    args = parse_args()
    history_dir = Path(args.history_dir).expanduser().resolve()
    today = normalize_today(args.today)
    latest_path = target_path(history_dir, args.kind)
    entry_lines = build_entry(args)
    append_entry(latest_path, today, entry_lines)
    validate_latest(args.kind, latest_path, today)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
