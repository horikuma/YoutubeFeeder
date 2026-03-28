# Issue Creation Rules

この文書は、Issue作成・更新タスクを単体で定義する完結文書である。

## Issue作成・更新

- Issue作成・更新とは、GitHub Issue を新規作成し、または既存 Issue の title、description、comment を更新して、実装前の正本として利用可能な状態へ整えるタスクである。

## 実施内容

- チャット欄から着手したタスクでは、作業開始前にユーザー指示を原文として残した Issue を作成しなければならない。
- Issue の既定 Assignee と Project 一覧は `llm-cache/` 配下の local cache を正本として参照しなければならない。必要項目が無い時は処理を中断し、ユーザーへ確認しなければならない。推測で補完してはならない。
- Issue の Assignee と Project の既定値は rules へ直書きしてはならず、`llm-cache/` と secrets から解決しなければならない。
- GitHub 操作モードは secrets の `operationMode` で解決しなければならない。rules に固定モードを書いてはならない。
- `user` モードでは、Issue の repo 操作は GitHub App で行わなければならず、Projects 操作は `gh` で行わなければならない。
- `organization` モードでは、Issue の repo 操作も Projects 操作も GitHub App で行わなければならない。
- チャット欄から作成した Issue は、元の指示を `原文` として残したうえで、description にはチェックボックス付き ToDo のみを追記しなければならない。
- 背景、目的、スコープ、実施タスク、完了条件、非対象などの詳細化本文は Issue comment で追記し、その comment 以後の整理結果を実装上の正本として扱わなければならない。
- `Issue-x を詳細化せよ` と指示された場合は、元の指示を残したまま、description にはチェックボックス付き ToDo だけを追記しなければならない。
- Issue を詳細化する時は、title も内容に見合う具体度へ更新し、一覧から見て作業対象が判別できる状態にしなければならない。
- Issue に着手した後、実装開始前に `issue-(IssueNo)` 形式の作業ブランチを作成し、そのブランチへ checkout しなければならない。
- 作成した作業ブランチ名は対象 Issue の comment へ記録しなければならない。記録時は `scripts/register-issue-branch` を正規入口として使わなければならない。
- blocker が見つかった場合は、Issue comment に理由、確認した内容、現在の状況を書き残して停止しなければならない。
- blocker や確認事項を経てタスクを完遂した場合は、最終的にどの問題をどう処置したかを Issue comment へ追記し、Issue 上から判断経路を追える状態にしなければならない。

## 完了条件

- チャット起点タスクで必要な Issue が作成済みであること。
- 対象 Issue の title、description、comment が、実装前の正本として利用できる状態に整理されていること。
- Assignee、Project、操作モードに必要な外部情報を推測なしで解決できていること。
- 実装開始前に `issue-(IssueNo)` 形式の作業ブランチが作成され、そのブランチへ checkout されていること。
- Issue と作業ブランチの対応関係が GitHub 上から追跡できること。

## 禁止事項

- Issue なしでチャット起点タスクへ着手してはならない。
- Issue の Assignee、Project、操作モード、その他の外部メタデータを推測で補完してはならない。
- rules に Assignee 名、Project 名、固定モードのようなプロダクト固有値を持ち込んではならない。
- description に背景、目的、スコープ、実施タスク、完了条件の詳細本文を書いてはならない。
- `scripts/register-issue-branch` 以外の経路で、表記揺れしたブランチ記録 comment を残してはならない。
- Issue ラベルだけで進行状態を管理してはならない。
