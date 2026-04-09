## 2026/04/09
- issue100 todo3 verification: issue-read --body-only now matches remote body and reuses llm-temp/issue-todo-check-current.md without manual newline adjustment
- issue100 todo1 verification: issue-read --body-only adds one trailing newline beyond remote body while issue-todo-check requires exact match
- Issue98 ToDo4確認: chat-latest はローカル残存、ignore 成立、git ls-files では未追跡化を確認。
- Issue98 ToDo3確認: git rm --cached 実行後も docs/history/chat-latest.md のファイル実体は残存。
- Issue98 ToDo2確認: .gitignore 追加後、git check-ignore -v --no-index で docs/history/chat-latest.md の ignore 成立を確認。
- Issue98 ToDo1確認: docs/history/chat-latest.md は .gitignore 未登録かつ Git 管理中。
