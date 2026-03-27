# Project Rules

- [開発セッション開始 rules-session-start.md](./rules/rules-session-start.md)
- [開発シーケンス開始 rules-sequence-start.md](./rules/rules-sequence-start.md)
- [開発シーケンス終了 rules-sequence-end.md](./rules/rules-sequence-end.md)
- [スキル作成 rules-skill-creation.md](./rules/rules-skill-creation.md)

## タスク候補

- `ユーザー指示の理解`
  - 指示、関連コード、関連文書を読んで変更対象と影響範囲を確定するタスク。
- `Issue の用意`
  - チャット起点指示を Issue 化し、原文を残した Description を作るタスク。
- `Issue の詳細化`
  - Description の ToDo と Issue コメントの詳細化本文を整えるタスク。
- `作業ブランチの準備`
  - 対象 Issue 用ブランチを作り、必要なら Issue に対応ブランチを記録するタスク。
  - GitHub App の API 使用法で引っかかっている。
- `スキル作成`
  - `skills`、`scripts`、必要な補助実装を追加し、再利用可能な入口として成立させるタスク。
- `先行テストで期待固定`
  - 実装前に失敗するべきテストを追加し、期待を固定するタスク。
- `実装と健康度点検`
  - 実装を進めつつ、責務境界・複雑度・状態管理を点検するタスク。
- `検証`
  - 変更内容に応じたテストと build 確認を実施するタスク。
- `文書同期`
  - 正本、human-view、履歴文書の必要更新を反映するタスク。
- `コミット`
  - 完了条件を満たした変更セットを 1 単位として確定するタスク。
- `Pull Request の作成`
  - base を決め、PR を作成し、Assignee 等を設定するタスク。
- `LLM 所要時間の反映`
  - Project の Number フィールドへ所要時間を反映するタスク。
- `ブロッカー記録と停止`
  - 続行不能時に Issue コメントへ状況を書き残して止めるタスク。
