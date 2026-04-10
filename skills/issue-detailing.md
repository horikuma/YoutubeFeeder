# Issue Detailing Skill

この文書は、Issue の詳細化という 1 つのタスクだけを定義する。

## Issue の詳細化

- Issue の詳細化とは、対象 Issue の Description を最終的な禁止事項と ToDo だけが残る状態へ整え、詳細化の過程出力と確定本文を Issue コメントへ集約し、作業ブランチ準備を含む実装前の正本として利用できる状態へ整えるタスクである。
- このタスクでは、対象 Issue の読取り、Description の禁止事項と ToDo の整理、Issue コメント本文の整理、タイトル更新、作業ブランチ準備、blocker 時の停止までをこの文書だけで判断しなければならない。
- この文書でいう推論とは、読んだ文書、Issue、コード、設定、ユーザー指示だけでは一意に確定していない具体的事項を、LLM が補完して決めることを指す。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- Issue の詳細化を始める時は、対象 Issue の現在のタイトル、Description、既存コメントを読み、未整理の指示と既存の整理結果を区別しなければならない。
- Issue の読取りと更新の rules を定義または更新する時は、次の usage で記述しなければならない。
  `./scripts/command-runner.py 'issue-read' --issue-number '<issue_number>'[ --body-only]`
  例: `./scripts/command-runner.py 'issue-read' --issue-number '57' --body-only`
  `./scripts/command-runner.py 'issue-description-update' --issue-number '<issue_number>' --body-file 'llm-temp/issue-description-update-<issue_number>.md'[ --title '<title>']`
  例: `./scripts/command-runner.py 'issue-description-update' --issue-number '57' --body-file 'llm-temp/issue-description-update-57.md' --title 'Git履歴からサルベージして command 例文必須要件を rules / skills へ復元する'`
    - `llm-temp/issue-description-update-<issue_number>.md` は、Description 更新本文ファイルである。
  `./scripts/command-runner.py 'issue-comment-create' --issue-number '<issue_number>' --body-file 'llm-temp/issue-comment-create-<issue_number>.md'`
  例: `./scripts/command-runner.py 'issue-comment-create' --issue-number '57' --body-file 'llm-temp/issue-comment-create-57.md'`
    - `llm-temp/issue-comment-create-<issue_number>.md` は、Issue comment 本文ファイルである。
  `./scripts/command-runner.py 'issue-branch-register' --issue-number '<issue_number>'[ --branch '<branch_name>']`
  例: `./scripts/command-runner.py 'issue-branch-register' --issue-number '57' --branch 'issue-57'`
- チャット欄から作成した Issue の元のユーザー指示は、Description ではなく Issue コメントで参照できる状態へ移さなければならない。
- Description には、禁止事項と `Issue詳細化ToDo`、`Issue外ToDo`、`IssueToDo` だけを記載しなければならない。
- Description の禁止事項は、チェックボックスを付けない番号付き箇条書きで記載しなければならない。
- Description の 3 種の ToDo は、チェックボックス付き箇条書きで記載し、各 ToDo の番号は GitHub の自動連番に依存せず本文テキストとして表現しなければならない。
- 背景、目的、スコープ、実施タスク、完了条件、非対象、補足説明は、Issue コメントで整理しなければならない。
- `Issue-x を詳細化せよ` と指示された場合も、Description は禁止事項と ToDo だけへ整えなければならない。
- Issue コメントへ追加した詳細化本文は、そのコメント以後の実装上の正本として扱わなければならない。
- 詳細化で Issue コメントを追加または更新する時は、少なくとも `私の指示` の原文、`その時点で行なった判断`、`最終的に最新になった禁止事項`、`最終的に最新になった ToDo` の 4 点を含めなければならない。
- `最終的に最新になった禁止事項` は、Description に残す禁止事項の正本として記載しなければならない。
- `最終的に最新になった ToDo` は、少なくとも `Issue の ToDo`、`Issue詳細化の ToDo`、`Issue外 ToDo` に分けて記載しなければならない。
- Description の `## ToDo` 配下には、`### Issue詳細化ToDo`、`### Issue外ToDo`、`### IssueToDo` をこの順で記載しなければならない。
- Description の `### Issue詳細化ToDo`、`### Issue外ToDo`、`### IssueToDo` は、アイテムが空の場合でも見出しを省略してはならない。
- `Issue の ToDo` は、新しいスレッドへ切り替わっても、同じ Issue コメントとそこに列挙した読取り対象だけを使えば、追加推論なしで着手できる粒度にしなければならない。
- `Issue の ToDo` に command 例を含める場合は、usage 記法、各置換値の説明、具体的な command 例文を使い、文字列そのものとして送信されうる未説明の置換記法を残してはならない。
- `Issue の ToDo` に、`必要な`、`適切な`、`整理する` のように、判定基準を別途補完しなければ実施内容が確定しない評価語を、その判定基準を先行 ToDo または同一 ToDo 内の観測可能条件として明示しないまま残してはならない。
- ある ToDo の実施内容を確定するために特定のファイル、Issue コメント、コード箇所、設定値の読取りが必要な場合は、その読取り対象を先に確定する ToDo を、後続の変更 ToDo より前へ置かなければならない。
- 先行 ToDo で読取り対象を確定した場合は、その読取り対象だけを使えば後続 ToDo の判断基準が一意に確定する状態にしなければならない。
- Description には、直近の詳細化コメントで `最終的に最新になった禁止事項` と `最終的に最新になった ToDo` として確定した内容を反映しなければならない。
- Description へ反映するのは、直近の詳細化コメントで確定した禁止事項、`Issue詳細化の ToDo`、`Issue外 ToDo`、`Issue の ToDo` に限定しなければならない。
- 詳細化の途中で生じた整理メモ、判断過程、補足説明は、Description へ残さず Issue コメントへ記録しなければならない。
- 詳細化の途中で推論の余地がある箇所をユーザーへ返す時は、各曖昧点に連番を付け、個別に収束できる形で列挙しなければならない。
- Issue を詳細化する時は、タイトルも内容に見合う具体度へ更新し、一覧から対象作業が判別できる状態へしなければならない。
- 実装開始前に `issue-(IssueNo)` 形式の作業ブランチを作成し、そのブランチへ checkout しなければならない。
- 作成した作業ブランチ名は対象 Issue の comment へ記録しなければならない。記録時は `scripts/command-runner.py 'issue-branch-register'` を正規入口として使わなければならない。
- `./scripts/command-runner.py 'issue-description-update'` と `./scripts/command-runner.py 'issue-comment-create'` に渡す本文ファイルは、それぞれ `llm-temp/issue-description-update-<issue_number>.md`、`llm-temp/issue-comment-create-<issue_number>.md` 形式でなければならない。
- チャット起点で作成した Issue は、詳細化が完了した時点で通常の Issue 起点タスクと同じ扱いにしなければならない。
- Issue の詳細化中に blocker が見つかった場合は、その時点で Issue コメントへ理由、確認した内容、現在の状況を書き残して停止しなければならない。

## 完了条件

- Description に、禁止事項と `Issue詳細化ToDo`、`Issue外ToDo`、`IssueToDo` だけが残っていること。
- Description の禁止事項が、直近の詳細化コメントで確定した `最終的に最新になった禁止事項` と一致していること。
- Description の ToDo が、直近の詳細化コメントで確定した `最終的に最新になった ToDo` と一致していること。
- Description の `Issue詳細化ToDo`、`Issue外ToDo`、`IssueToDo` が、直近の詳細化コメントで確定した `Issue詳細化の ToDo`、`Issue外 ToDo`、`Issue の ToDo` とそれぞれ一致していること。
- Description の禁止事項が、チェックボックスを付けない番号付き箇条書きで記載されていること。
- Description の 3 種の ToDo が、チェックボックス付き箇条書きで記載され、各 ToDo の番号が本文テキストとして表現されていること。
- `Issue の ToDo` が、同じ Issue コメントとそこに列挙した読取り対象だけで、追加推論なしに着手できる粒度になっていること。
- `Issue の ToDo` に command 例がある場合は、usage、必要な補足、具体的な command 例文だけで実行方法を確定できること。
- 後続 ToDo の判断基準が、対応する先行 ToDo または同一 ToDo 内で観測可能な条件として確定していること。
- 背景、目的、スコープ、実施タスク、完了条件、非対象が Issue コメントで整理されていること。
- 対象 Issue のタイトルが、一覧から作業内容を判別できる具体度になっていること。
- 実装開始前に `issue-(IssueNo)` 形式の作業ブランチが作成され、そのブランチへ checkout されていること。
- Issue と作業ブランチの対応関係が GitHub 上から追跡できること。
- blocker がある場合は、Issue コメントへ理由、確認内容、現在の状況を書き残したうえで停止していること。

## 禁止事項

- Description へ、禁止事項と ToDo 以外の背景説明、目的説明、詳細手順、整理メモを残してはならない。
- 直近の詳細化コメントで確定した禁止事項と ToDo を Description へ反映しないまま放置してはならない。
- Description の `## ToDo` 配下で、`Issue詳細化ToDo`、`Issue外ToDo`、`IssueToDo` 以外の区分を正本として残してはならない。
- Description の禁止事項と ToDo を、番号付き箇条書き以外の形式で残してはならない。
- 元のユーザー指示を失わせたり、参照できない状態にしてはならない。
- 詳細化本文を Issue コメントではない別の場所へ分散してはならない。
- 先行 ToDo で確定していない判定基準を、後続 ToDo の実施時に補完してはならない。
- `Issue の ToDo` に、判定基準が未記載の評価語や、読取り対象が未記載のままでは具体的行動が確定しない表現を残してはならない。
- `Issue の ToDo` に、具体例なしの command 記述、説明なしの置換記法、`llm-cache` の値そのものを含む command 例を残してはならない。
- `scripts/command-runner.py 'issue-branch-register'` 以外の経路で、表記揺れしたブランチ記録 comment を残してはならない。
- blocker を記録しないまま詳細化や後続作業を続けてはならない。
