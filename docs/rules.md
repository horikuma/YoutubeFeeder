# Project Rules

## 共通原則

- 文書読込みは、現在の目的タスクを完了するために必要なファイルだけに限定しなければならない。
- LLM は、読んだ文書の記載内容だけで判断しなければならず、推測、補完、慣習、文脈、先回りで意味を追加してはならない。
- タスク規定が曖昧で、タスク遂行に推論を要すると判明した場合は、処理を中断し、その旨をユーザーへ報告しなければならない。
- Git 操作は、同一リポジトリ内で常に 1 操作ずつ直列に実行しなければならない。
- Git 追跡中の既存ファイルの改名は、履歴を保持するため `git mv` を使わなければならない。
- Git 未追跡ファイルのファイル名変更は `mv` を使わなければならない。
- Git 追跡中の既存ファイルを改名した後に同じファイルへ本文編集を加える場合は、改名と本文編集の間にコミットを挟まなければならない。

## タスク

- [セッション開始 rules-session-start.md](./rules/rules-session-start.md)
- [ユーザー指示の理解 rules-user-instruction-understanding.md](./rules/rules-user-instruction-understanding.md)
- [Issue の詳細化 rules-issue-detailing.md](./rules/rules-issue-detailing.md)
- [先行テストで期待固定 rules-test-expectation-freeze.md](./rules/rules-test-expectation-freeze.md)
- [実装と健康度点検 rules-implementation-and-health.md](./rules/rules-implementation-and-health.md)
- [検証 rules-verification.md](./rules/rules-verification.md)
- [Issue作成・更新 rules-issue-creation.md](./rules/rules-issue-creation.md)
- [Pull Request作成・更新 rules-pr-creation.md](./rules/rules-pr-creation.md)
- [コミット rules-commit.md](./rules/rules-commit.md)
- [文書同期 rules-document-sync.md](./rules/rules-document-sync.md)
- [レポート作成・更新 rules-report-creation.md](./rules/rules-report-creation.md)
- [スキル作成・更新 rules-skill-creation.md](./rules/rules-skill-creation.md)
- [ルール作成・更新 rules-rule-creation.md](./rules/rules-rule-creation.md)
