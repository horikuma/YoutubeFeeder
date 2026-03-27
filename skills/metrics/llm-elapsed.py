#!/usr/bin/env python3

from __future__ import annotations

import argparse
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
STATE_DIR = REPO_ROOT / ".git" / "llm-elapsed"
STATE_FILE = STATE_DIR / "current_start_epoch"


def round_minutes(elapsed_seconds: int) -> int:
    return (elapsed_seconds + 30) // 60


def main() -> int:
    parser = argparse.ArgumentParser(description="Track elapsed LLM minutes.")
    parser.add_argument("action", choices=("start", "finish", "status", "reset"))
    args = parser.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    now_epoch = int(time.time())

    if args.action == "start":
        STATE_FILE.write_text(f"{now_epoch}\n", encoding="utf-8")
        print(f"LLM timer started: {now_epoch}")
        return 0

    if args.action == "finish":
        if not STATE_FILE.exists():
            raise SystemExit("LLM timer has not been started.")
        start_epoch = int(STATE_FILE.read_text(encoding="utf-8").strip())
        elapsed_minutes = round_minutes(now_epoch - start_epoch)
        print(f"(LLM所要時間: 約{elapsed_minutes}分)")
        STATE_FILE.unlink(missing_ok=True)
        return 0

    if args.action == "status":
        if not STATE_FILE.exists():
            print("LLM timer idle")
            return 0
        start_epoch = int(STATE_FILE.read_text(encoding="utf-8").strip())
        elapsed_seconds = now_epoch - start_epoch
        elapsed_minutes = round_minutes(elapsed_seconds)
        print(f"LLM timer running: start={start_epoch} elapsed={elapsed_seconds}s approx={elapsed_minutes}分")
        return 0

    STATE_FILE.unlink(missing_ok=True)
    print("LLM timer reset")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
