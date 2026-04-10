#!/usr/bin/env python3

from __future__ import annotations

import argparse
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
STATE_DIR = REPO_ROOT / "llm-temp" / "llm-elapsed"
STATE_FILE = STATE_DIR / "current_start_epoch"
SESSION_FILE = STATE_DIR / "session_accumulated_seconds"


def round_minutes(elapsed_seconds: int) -> int:
    return (elapsed_seconds + 30) // 60


def read_int(path: Path) -> int:
    if not path.exists():
        return 0
    return int(path.read_text(encoding="utf-8").strip())


def write_int(path: Path, value: int) -> None:
    path.write_text(f"{value}\n", encoding="utf-8")


def clear_state() -> None:
    STATE_FILE.unlink(missing_ok=True)
    SESSION_FILE.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Track elapsed LLM minutes.")
    parser.add_argument("action", choices=("start", "finish", "status", "reset", "session-finish"))
    args = parser.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    now_epoch = int(time.time())

    if args.action == "start":
        if STATE_FILE.exists():
            raise SystemExit("LLM timer is already running.")
        write_int(STATE_FILE, now_epoch)
        if not SESSION_FILE.exists():
            write_int(SESSION_FILE, 0)
        print(f"LLM timer started: {now_epoch}")
        return 0

    if args.action == "finish":
        if not STATE_FILE.exists():
            print("(LLM所要時間: 約0分)")
            return 0
        start_epoch = read_int(STATE_FILE)
        elapsed_seconds = now_epoch - start_epoch
        write_int(SESSION_FILE, read_int(SESSION_FILE) + elapsed_seconds)
        elapsed_minutes = round_minutes(elapsed_seconds)
        print(f"(LLM所要時間: 約{elapsed_minutes}分)")
        STATE_FILE.unlink(missing_ok=True)
        return 0

    if args.action == "session-finish":
        session_seconds = read_int(SESSION_FILE)
        if STATE_FILE.exists():
            start_epoch = read_int(STATE_FILE)
            session_seconds += now_epoch - start_epoch
        elapsed_minutes = round_minutes(session_seconds)
        print(f"(LLMセッション所要時間: 約{elapsed_minutes}分)")
        clear_state()
        return 0

    if args.action == "status":
        session_seconds = read_int(SESSION_FILE)
        if not STATE_FILE.exists():
            if session_seconds == 0:
                print("LLM timer idle")
                return 0
            elapsed_minutes = round_minutes(session_seconds)
            print(f"LLM timer idle: session_total={session_seconds}s approx={elapsed_minutes}分")
            return 0
        start_epoch = read_int(STATE_FILE)
        current_seconds = now_epoch - start_epoch
        total_seconds = session_seconds + current_seconds
        elapsed_minutes = round_minutes(current_seconds)
        total_minutes = round_minutes(total_seconds)
        print(
            "LLM timer running: "
            f"start={start_epoch} elapsed={current_seconds}s approx={elapsed_minutes}分 "
            f"session_total={total_seconds}s session_approx={total_minutes}分"
        )
        return 0

    clear_state()
    print("LLM timer reset")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
