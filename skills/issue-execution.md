# Issue Execution Skill

この文書は、Issue実施という 1 つのタスクだけを定義する。

## Issue実施

- Issue実施とは、詳細化済み Issue の `IssueToDo` から未完了項目を 1 件だけ選び、その 1 件に必要な読取り、実装、focused verification、Issue 更新、コミットまでを 1 つのチェックポイントとして完了させるタスクである。
- このタスクでは、着手対象の確定、必要ファイルの読取り、変更、focused verification、`IssueToDo` 更新、コミット、停止判断までをこの文書だけで判断しなければならない。
- この文書でいう focused verification とは、その `IssueToDo` で変更したファイルと直接影響を受ける経路だけに限定した確認を指す。

## 実施内容

- 着手時は、対象 Issue の Description と、その Issue の直近の詳細化コメントを読み、禁止事項、`IssueToDo`、読取り対象、更新対象、完了条件を確定しなければならない。
- `IssueToDo` が複数未完了でも、今回着手する対象は 1 件だけに固定し、同じ着手で 2 件以上を同時に進めてはならない。
- 今回着手する `IssueToDo` は、その項目に列挙された読取り対象だけで、変更対象と判断基準が一意に確定するものを 1 件選ばなければならない。
- 着手対象の `IssueToDo` に先行未完了の読取り ToDo がある場合は、その ToDo を飛ばして後続 ToDo へ進んではならない。
- 実装前には、着手する `IssueToDo` の達成に必要なファイルだけを読み、関係のないコードや文書を追加で読んではならない。
- 実装中は、対象 ToDo に直接必要な変更だけを行い、後続 ToDo のための途中差分を同じ変更セットへ混在させてはならない。
- focused verification は、変更が `tools`、`skills`、`scripts` だけに閉じる場合は対象ファイルの構文確認と代表的な 1 経路の確認に限定し、アプリ本体へ影響する場合は対応するテストと build 確認へ広げなければならない。
- focused verification が完了した後、Git の staging 前かつ commit 前に、次の usage で対象 Issue の `IssueToDo` を 1 件だけチェック済みに更新しなければならない。
  `./scripts/command-runner.py 'issue-todo-check' --issue-number '<issue_number>' --todo-section 'IssueToDo' --todo-number '<todo_number>' --body-file 'llm-temp/issue-description-update-<summary>.md'`
  例: `./scripts/command-runner.py 'issue-todo-check' --issue-number '69' --todo-section 'IssueToDo' --todo-number '7' --body-file 'llm-temp/issue-description-update-current.md'`
    - `<issue_number>` は、今回実施中の Issue 番号であり、省略してはならない。
    - `<todo_number>` は、今回完了した `### IssueToDo` 配下の番号であり、省略してはならない。
    - `llm-temp/issue-description-update-<summary>.md` は、現在の Issue Description と一致しているローカル Markdown であり、更新後はそのまま GitHub へ反映される。
    - `<summary>` は、`.md` の前に入る空でない要約文字列であり、省略してはならない。
- コミットは、focused verification と `IssueToDo` 更新が完了した後に、今回完了した 1 件分の変更セットだけを対象として行わなければならない。
- コミット前には、今回の変更セットに必要な `docs/history/*-latest.md` 更新を、対応する `scripts/command-runner.py` の command だけで完了させなければならない。
- `IssueToDo` が完了条件を満たせない blocker に当たった場合は、変更を広げず、確認した内容と停止理由をユーザーへ報告して停止しなければならない。

## 完了条件

- 詳細化済み Issue の未完了 `IssueToDo` から 1 件だけを選び、その 1 件だけを処理していること。
- 着手した `IssueToDo` に必要な読取り対象だけを読んでいること。
- focused verification が、今回の変更範囲に応じた内容で完了していること。
- Git の staging 前かつ commit 前に、対応する `IssueToDo` が `scripts/command-runner.py 'issue-todo-check'` でチェック済みに更新されていること。
- コミットが、今回完了した 1 件分の変更セットだけで構成されていること。
- blocker がある場合は、変更を拡大せず停止していること。

## 禁止事項

- 2 件以上の `IssueToDo` を同じ着手でまとめて処理してはならない。
- 詳細化コメントや `IssueToDo` に書かれていない判断基準を、推測で補って実装してはならない。
- 先行未完了 ToDo を残したまま、後続 ToDo の変更へ進んではならない。
- focused verification 前に `IssueToDo` をチェック済みにしてはならない。
- `IssueToDo` 更新前に Git の staging や commit を行ってはならない。
- 今回の `IssueToDo` と無関係な差分や、後続 ToDo の途中差分を同じコミットへ混在させてはならない。
