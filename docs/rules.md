# Project Rules

## 共通原則

- 文書読込みは、現在の目的タスクを完了するために必要なファイルだけに限定しなければならない。
- LLM は、読んだ文書の記載内容だけで判断しなければならず、推測、補完、慣習、文脈、先回りで意味を追加してはならない。
- タスク規定が曖昧で、タスク遂行に推論を要すると判明した場合は、処理を中断し、その旨をユーザーへ報告しなければならない。
- Git 操作は、同一リポジトリ内で常に 1 操作ずつ直列に実行しなければならない。

## タスク

- [セッション開始 rules-session-start.md](./rules/rules-session-start.md)
- [シーケンス開始 rules-sequence-start.md](./rules/rules-sequence-start.md)
- [シーケンス終了 rules-sequence-end.md](./rules/rules-sequence-end.md)
- [Issue作成・更新 rules-issue-creation.md](./rules/rules-issue-creation.md)
- [Pull Request作成・更新 rules-pr-creation.md](./rules/rules-pr-creation.md)
- [コミット rules-commit.md](./rules/rules-commit.md)
- [文書同期 rules-document-sync.md](./rules/rules-document-sync.md)
- [スキル作成・更新 rules-skill-creation.md](./rules/rules-skill-creation.md)
- [ルール作成・更新 rules-rule-creation.md](./rules/rules-rule-creation.md)

## タスク候補

- `ユーザー指示の理解`
  - 指示、関連コード、関連文書を読んで変更対象と影響範囲を確定するタスク。
- `Issue の詳細化`
  - Description の ToDo と Issue コメントの詳細化本文を整えるタスク。
- `先行テストで期待固定`
  - 実装前に失敗するべきテストを追加し、期待を固定するタスク。
- `実装と健康度点検`
  - 実装を進めつつ、責務境界・複雑度・状態管理を点検するタスク。
- `検証`
  - 変更内容に応じたテストと build 確認を実施するタスク。
- `文書同期`
  - 正本、human-view、履歴文書以外の必要更新を反映するタスク。
- `コミット`
  - 完了条件を満たした変更セットを 1 単位として確定するタスク。
- `LLM 所要時間の反映`
  - Project の Number フィールドへ所要時間を反映するタスク。
- `ブロッカー記録と停止`
  - 続行不能時に Issue コメントへ状況を書き残して止めるタスク。
