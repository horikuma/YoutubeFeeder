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
- [ユーザー指示の理解 rules-user-instruction-understanding.md](./rules/rules-user-instruction-understanding.md)
- [Issue の詳細化 rules-issue-detailing.md](./rules/rules-issue-detailing.md)
- [先行テストで期待固定 rules-test-expectation-freeze.md](./rules/rules-test-expectation-freeze.md)
- [実装と健康度点検 rules-implementation-and-health.md](./rules/rules-implementation-and-health.md)
- [検証 rules-verification.md](./rules/rules-verification.md)
- [Issue作成・更新 rules-issue-creation.md](./rules/rules-issue-creation.md)
- [Pull Request作成・更新 rules-pr-creation.md](./rules/rules-pr-creation.md)
- [コミット rules-commit.md](./rules/rules-commit.md)
- [文書同期 rules-document-sync.md](./rules/rules-document-sync.md)
- [スキル作成・更新 rules-skill-creation.md](./rules/rules-skill-creation.md)
- [ルール作成・更新 rules-rule-creation.md](./rules/rules-rule-creation.md)

## タスク候補

- `Issue の詳細化`
  - Description の ToDo と Issue コメントの詳細化本文を整えるタスク。
- `先行テストで期待固定`
  - 実装前に失敗するべきテストを追加し、期待を固定するタスク。
- `実装と健康度点検`
  - 実装を進めつつ、責務境界・複雑度・状態管理を点検するタスク。
- `検証`
  - 変更内容に応じたテストと build 確認を実施するタスク。
- `コミット`
  - 完了条件を満たした変更セットを 1 単位として確定し、`docs/history/` 更新を反映するタスク。
- `文書同期`
  - `docs/history/` を除く正本、human-view、参照資料の必要更新を反映するタスク。
