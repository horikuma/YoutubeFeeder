# Project Rules

## 共通原則

- 文書読込みは、現在の目的タスクを完了するために必要なファイルだけに限定しなければならない。
- LLM は、読んだ文書の記載内容だけで判断しなければならず、推測、補完、慣習、文脈、先回りで意味を追加してはならない。
- タスク規定が曖昧で、タスク遂行に推論を要すると判明した場合は、処理を中断し、その旨をユーザーへ報告しなければならない。
- Git 操作は、同一リポジトリ内で常に 1 操作ずつ直列に実行しなければならない。
- Git command を実行する時は、次の usage で `./scripts/command-runner.py 'git'` を経由しなければならない。
  `./scripts/command-runner.py 'git' <git_args>...`
  例: `./scripts/command-runner.py 'git' status --short`
  - `<git_args>...` は、通常の `git` command へ渡す subcommand と option である。
  - `./scripts/command-runner.py 'git-main-sync'` のように、別の Git 専用 wrapper command が明示されている場合は、その command を使わなければならない。
  - Git command を `git <git_args>...` として直接実行してはならない。
- Git 追跡中の既存ファイルの改名は、履歴を保持するため次の usage で `./scripts/command-runner.py 'git'` を使わなければならない。
  `./scripts/command-runner.py 'git' mv <old_path> <new_path>`
  例: `./scripts/command-runner.py 'git' mv docs/old.md docs/new.md`
  - `<old_path>` は、Git 追跡中の既存ファイルパスである。
  - `<new_path>` は、変更後のファイルパスである。
- Git 未追跡ファイルのファイル名変更は `mv` を使わなければならない。
- Git 追跡中の既存ファイルを改名した後に同じファイルへ本文編集を加える場合は、改名と本文編集の間にコミットを挟まなければならない。
- チャット入力を受け取った直後、および応答を出力完了する直前には、対応するフック処理を必ず実行しなければならない。
- フック処理は、通常のタスクより優先され、スキップしてはならない。
- フック処理の具体的手順は `skills/hooks/*.md` に定義された内容に従わなければならない。

## フック処理

### 入力受信時フック

- ユーザーからチャット入力を受け取った直後は、最初の処理として `skills/hooks/on-input.md` を開いて実行しなければならない。
- この処理は、ユーザー指示の理解よりも前に必ず実行しなければならない。
- この処理では、user 用内容テキストの確定と chat 履歴追記を行わなければならない。

### 出力完了時フック

- 応答の生成が完了した後、出力を確定する直前に `skills/hooks/on-output.md` を開いて実行しなければならない。
- この処理を実行せずに応答を終了してはならない。
- この処理では、assistant 用内容テキストの確定、chat 履歴追記、終了時タイムスタンプ記録を行わなければならない。

## タスク

- 各タスクの具体的手順は、この章で指定する対応 `skills/*.md` を開いて従わなければならない。
- この文書では、各タスクの参照導線だけを定義し、具体的手順を重複記載してはならない。

### セッション開始

- セッション開始を行う時は、`skills/session-start.md` を開かなければならない。

### セッション終了

- セッション終了を行う時は、`skills/session-end.md` を開かなければならない。

### ユーザー指示の理解

- ユーザー指示の理解を行う時は、`skills/user-instruction-understanding.md` を開かなければならない。
- チャット入力でユーザー指示を受けた後は、以後のタスクを始める前に、最初のアクションとしてユーザー指示の理解を行わなければならない。

### Issue の詳細化

- Issue の詳細化を行う時は、`skills/issue-detailing.md` を開かなければならない。

### Issue実施

- Issueを実施する時は、`skills/issue-execution.md` を開かなければならない。
- Issueを実施する指示を受けた時は、`skills/issue-execution.md` が規定する `scripts/command-runner.py 'issue-todo' --get` の `next` で示された `IssueToDo` を 1 件だけ処理する手順を 1 回で終わらせてはならず、blocker がない限り、`next` が `null` になるまで同じ手順を直列に繰り返して最後まで完了させなければならない。
- Issueを実施する指示を受けた時に、いずれかの `IssueToDo` が完了条件を満たせない blocker に当たった場合は、その時点で以後の `IssueToDo` への進行を中断し、blocker の内容をユーザーへ報告しなければならない。

### 先行テストで期待固定

- 先行テストで期待固定を行う時は、`skills/test-expectation-freeze.md` を開かなければならない。

### 実装と健康度点検

- 実装と健康度点検を行う時は、`skills/implementation-and-health.md` を開かなければならない。

### 検証

- 検証を行う時は、`skills/verification.md` を開かなければならない。

### Issue作成・更新

- Issue作成・更新を行う時は、`skills/issue-creation.md` を開かなければならない。

### Pull Request作成・更新

- Pull Request作成・更新を行う時は、`skills/pr-creation.md` を開かなければならない。

### コミット

- コミットを行う時は、`skills/commit.md` を開かなければならない。

### 文書同期

- 文書同期を行う時は、`skills/document-sync.md` を開かなければならない。

### レポート作成・更新

- レポート作成・更新を行う時は、`skills/report-creation.md` を開かなければならない。

### スキル作成

- スキル作成を行う時は、`skills/skill-creation.md` を開かなければならない。

### ルール作成・更新

- ルール作成・更新を行う時は、`skills/rule-creation.md` を開かなければならない。
