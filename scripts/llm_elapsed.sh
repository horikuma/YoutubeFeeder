#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/llm_elapsed.sh start
  scripts/llm_elapsed.sh finish
  scripts/llm_elapsed.sh status
  scripts/llm_elapsed.sh reset
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_dir="$repo_root/.git/llm_elapsed"
state_file="$state_dir/current_start_epoch"

mkdir -p "$state_dir"

now_epoch() {
  date +%s
}

round_minutes() {
  local elapsed_seconds="$1"
  echo $(((elapsed_seconds + 30) / 60))
}

case "${1:-}" in
  start)
    start_epoch="$(now_epoch)"
    printf '%s\n' "$start_epoch" > "$state_file"
    printf 'LLM timer started: %s\n' "$start_epoch"
    ;;
  finish)
    if [[ ! -f "$state_file" ]]; then
      echo "LLM timer has not been started." >&2
      exit 1
    fi
    start_epoch="$(cat "$state_file")"
    end_epoch="$(now_epoch)"
    elapsed_seconds=$((end_epoch - start_epoch))
    elapsed_minutes="$(round_minutes "$elapsed_seconds")"
    printf '(LLM所要時間: 約%s分)\n' "$elapsed_minutes"
    rm -f "$state_file"
    ;;
  status)
    if [[ ! -f "$state_file" ]]; then
      echo "LLM timer idle"
      exit 0
    fi
    start_epoch="$(cat "$state_file")"
    elapsed_seconds="$(( $(now_epoch) - start_epoch ))"
    elapsed_minutes="$(round_minutes "$elapsed_seconds")"
    printf 'LLM timer running: start=%s elapsed=%ss approx=%s分\n' \
      "$start_epoch" "$elapsed_seconds" "$elapsed_minutes"
    ;;
  reset)
    rm -f "$state_file"
    echo "LLM timer reset"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
