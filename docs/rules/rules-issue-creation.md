# Issue Creation Rules

この文書は、Issue作成・更新タスクを単体で定義する完結文書である。

## Issue作成・更新

- Issue作成・更新とは、GitHub Issue を新規作成し、または起票直後の Issue を、以後の詳細化へ進めるための最小初期状態へ整えるタスクである。

## 実施内容

- チャット欄から着手したタスクでは、作業開始前にユーザー指示を原文として残した Issue を作成しなければならない。
- Issue の既定 Assignee と Project 一覧は `llm-cache/issue-defaults.json` を正本として参照しなければならない。必要項目が無い時は処理を中断し、ユーザーへ確認しなければならない。推測で補完してはならない。
- Issue の Assignee と Project の既定値は rules へ直書きしてはならず、`llm-cache/issue-defaults.json` の `assignee.login`、`project.owner`、`project.title` と `llm-cache/github-app.json` の `operationMode` から解決しなければならない。
- GitHub 操作モードは `llm-cache/github-app.json` の `operationMode` で解決しなければならない。rules に固定モードや `llm-cache` の値を書いてはならない。
- `user` モードでは、Issue の repo 操作は GitHub App で行わなければならず、Projects 操作は `gh` で行わなければならない。
- `organization` モードでは、Issue の repo 操作も Projects 操作も GitHub App で行わなければならない。
- rules や Issue の ToDo に command 例を書く場合は、`./scripts/issue-creation --repo {repo_slug} --title '{issue_title_text}' --body-file llm-temp/YYYYMMDD-HHMMSS-issue-creation-summary.md` のように、そのまま実行できる形へ一意に展開できる形で記載しなければならない。
- `./scripts/issue-creation` に渡す本文ファイルは `llm-temp/YYYYMMDD-HHMMSS-issue-creation-summary.md` 形式でなければならず、山括弧による置換記法のような文字列そのものとして送信されうる表記を rules に残してはならない。
- チャット欄から作成した Issue は、元の指示を `原文` として残したうえで、description にはチェックボックス付き ToDo だけを記載しなければならない。
- Issue作成では、背景、目的、スコープ、実施タスク、完了条件、非対象などの詳細化本文を追加してはならない。
- Issue作成の時点では、description に以後の詳細化へ入るための最小 ToDo だけを残せばよい。

## 完了条件

- チャット起点タスクで必要な Issue が作成済みであること。
- 対象 Issue に、元のユーザー指示が `原文` として残っていること。
- 対象 Issue の description に、チェックボックス付き ToDo 以外が記載されていないこと。
- Assignee、Project、操作モードに必要な外部情報を推測なしで解決できていること。
- rules に Issue作成 command 例を書く場合は、`./scripts/issue-creation` の必須引数、本文ファイル名規則、`llm-cache` の参照キー名だけで一意に展開できること。

## 禁止事項

- Issue なしでチャット起点タスクへ着手してはならない。
- Issue の Assignee、Project、操作モード、その他の外部メタデータを推測で補完してはならない。
- rules に Assignee 名、Project 名、固定モードのようなプロダクト固有値を持ち込んではならない。
- rules に `llm-cache` の値そのものや、文字列として送信されうる山括弧形式の置換記法を持ち込んではならない。
- description に背景、目的、スコープ、実施タスク、完了条件の詳細本文を書いてはならない。
- 詳細化本文、タイトル具体化、作業ブランチ準備を、Issue作成タスクへ混在させてはならない。
- Issue ラベルだけで進行状態を管理してはならない。
