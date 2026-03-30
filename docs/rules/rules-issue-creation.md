# Issue Creation Rules

この文書は、Issue作成・更新タスクを単体で定義する完結文書である。

## Issue作成・更新

- Issue作成・更新とは、GitHub Issue を新規作成し、または起票直後の Issue を、以後の詳細化へ進めるための最小初期状態へ整えるタスクである。

## 実施内容

- チャット欄から着手したタスクでは、作業開始前にユーザー指示を原文として残した Issue を作成しなければならない。
- Issue の既定 Assignee と Project 一覧は `llm-cache/` 配下の local cache を正本として参照しなければならない。必要項目が無い時は処理を中断し、ユーザーへ確認しなければならない。推測で補完してはならない。
- Issue の Assignee と Project の既定値は rules へ直書きしてはならず、`llm-cache/` と secrets から解決しなければならない。
- GitHub 操作モードは secrets の `operationMode` で解決しなければならない。rules に固定モードを書いてはならない。
- `user` モードでは、Issue の repo 操作は GitHub App で行わなければならず、Projects 操作は `gh` で行わなければならない。
- `organization` モードでは、Issue の repo 操作も Projects 操作も GitHub App で行わなければならない。
- チャット欄から作成した Issue は、元の指示を `原文` として残したうえで、description にはチェックボックス付き ToDo だけを記載しなければならない。
- Issue作成では、背景、目的、スコープ、実施タスク、完了条件、非対象などの詳細化本文を追加してはならない。
- Issue作成の時点では、description に以後の詳細化へ入るための最小 ToDo だけを残せばよい。

## 完了条件

- チャット起点タスクで必要な Issue が作成済みであること。
- 対象 Issue に、元のユーザー指示が `原文` として残っていること。
- 対象 Issue の description に、チェックボックス付き ToDo 以外が記載されていないこと。
- Assignee、Project、操作モードに必要な外部情報を推測なしで解決できていること。

## 禁止事項

- Issue なしでチャット起点タスクへ着手してはならない。
- Issue の Assignee、Project、操作モード、その他の外部メタデータを推測で補完してはならない。
- rules に Assignee 名、Project 名、固定モードのようなプロダクト固有値を持ち込んではならない。
- description に背景、目的、スコープ、実施タスク、完了条件の詳細本文を書いてはならない。
- 詳細化本文、タイトル具体化、作業ブランチ準備を、Issue作成タスクへ混在させてはならない。
- Issue ラベルだけで進行状態を管理してはならない。
