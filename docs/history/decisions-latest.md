## 2026/04/09
- Issue100では issue-todo-check の完全一致判定を維持し、issue-read --body-only の追加入力改行だけを除去して本文再利用を成立させる。
  - 安定名の llm-temp 本文ファイル再利用という設計意図を満たしつつ、Description の厳密一致契約も崩さない最小変更だから。
