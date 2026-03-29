## 2026/03/29
- `python3 -m py_compile skills/history/append-history.py skills/history/rotate-latest.py`、`bash -n scripts/append-chat-history scripts/append-decision-history scripts/append-metrics-history scripts/rotate-history`、tempdir での `append-*` と `rotate-history` 実行確認を継続して利用した。
- `python3 -m py_compile skills/history/rotate-latest.py` を実行し、構文確認は成功した。
- `scripts/rotate-history --history-dir <tempdir> --today 2026/03/29` を実行し、後段に古い見出しが残る `latest` の掃き出しと空 `latest` の当日見出し初期化を確認した。
