## 2026/03/30
Issue38のTODOを実施せよ。[引用要約: ToDo7としてタイトルやブランチ名はllm-tempではなく引数で渡す方針を固定するよう指示。]
  - `issue-creation` の `--title`、`pull-request-creation` の `--head` / `--title`、`issue-branch-register` の `--branch` を direct arg として metadata に固定した。
Issue38のTODOを実施せよ。[引用要約: ToDo6としてMarkdownで規定できる入力だけをllm-temp対象にするよう指示。]
  - Description/コメント本文の llm-temp 契約に `content_format: markdown` を必須化し、Markdown 契約として定義した入力だけが llm-temp 対象になるよう明示した。
Issue38のTODOを実施せよ。[引用要約: ToDo5としてコメント本文をllm-tempの固定命名Markdownへ限定するよう指示。]
  - `issue-comment-create` は `--body-file` のみを受け付け、`llm-temp/YYYYMMDD-HHMMSS-コマンド名-概要.md` 以外のコメント入力を拒否するようにした。
Issue38のTODOを実施せよ。[引用要約: ToDo4としてDescription本文をllm-tempの固定命名Markdownへ限定するよう指示。]
  - `issue-creation` / `issue-description-update` / `pull-request-creation` は `--body-file` のみを受け付け、`llm-temp/YYYYMMDD-HHMMSS-コマンド名-概要.md` 以外を拒否するようにした。
Issue38のTODOを実施せよ。[引用要約: ToDo3として新しいcommand名へ揃えるよう指示。]
  - user-facing script 名と `_meta.json` の command 名を `issue-*` / `history-*` / `metrics-*` などの最終命名へ揃え、新命名の入口で help と構文確認が通ることを確認した。
Issue38のTODOを実施せよ。[引用要約: ToDo2としてscriptsごとに個別操作前提のentry point設計を進めるよう指示。]
  - `get-issue` / `comment-issue` / `update-issue-body` と履歴追記3種に専用 Python entry point を追加し、実際に呼ぶ scripts ごとに個別入口を持つ構成へ移した。
Issue38のTODOを実施せよ。[引用要約: scriptsのみの制約を緩め、ToDo1として各scriptの必須情報固定を進めるよう指示。]
  - Issue #38 の禁止事項を skills の command 定義と共通実行基盤まで許可する形へ更新し、各 command の必須入力を `_meta.json` の `required_inputs` として正本化した。共通実行基盤でも定義欠落を検出できるようにした。
では、Issue38のTODOを実施せよ。[引用要約: TODO1項目毎にコミットし、Issue詳細化ルールを更新し、禁止事項にscripts以外を変更しないを追加した上で実行するよう指示。]
  - Issue詳細化ルールを更新し、Issue #38 のDescriptionと詳細化コメントを禁止事項+ToDoへ同期した。実施時のToDo単位コミット規則は既存ルールにあるため新設せず、ToDo実装の前提を整えた。
では、未コミットをコミットせよ。
  - Issue 詳細化ルールに、詳細化コメントの必須項目、3分類 ToDo、Description へ反映する範囲を追加し、この差分だけをコミット対象として整えた。
コミットせよ。
  - Issue 作成と Issue 詳細化の境界を見直し、Description は最終 ToDo だけを残し、詳細化の過程出力と確定本文は Issue コメントへ集約するルールへ整理した。
コミットせよ。
  - シーケンス開始とシーケンス終了のルールを削除し、終了時に残すべき追跡可能性と未完了時停止条件を Pull Request 作成・更新ルールへ集約する差分をコミット対象として整えた。
chat-logを新しい参照に変更し、コミットせよ。 [引用要約: 今回のみ例外として chat-log 直接更新を許可し、旧レポート参照の修正とコミットを指示した。]
  - chat-log の旧レポート参照を新命名へ修正し、改名規則を共通原則へ移したルール更新と docs/report の git mv 改名をコミット対象として整えた。
.gitignoreのコミットしプッシュせよ。
  - .gitignore の差分を確認し、履歴更新後にコミットと push を実施。
