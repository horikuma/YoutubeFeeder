# Issue Execution Skill

この文書は、Issue実施という 1 つのタスクだけを定義する。

## Issue実施

- Issue実施とは、詳細化済み Issue の `IssueToDo` から `scripts/command-runner.py 'issue-todo' --get` の `next` で示された未完了項目を 1 件だけ選び、その 1 件に必要な読取り、実装、focused verification、Issue 更新、コミットまでを 1 つのチェックポイントとして完了させるタスクである。
- このタスクでは、着手対象の確定、必要ファイルの読取り、変更、focused verification、`IssueToDo` 更新、コミット、停止判断までをこの文書だけで判断しなければならない。
- この文書でいう focused verification とは、その `IssueToDo` で変更したファイルと直接影響を受ける経路だけに限定した確認を指す。

## 実施内容


### 着手判断

- 着手時は、GitHub 上の対象 Issue の最新 Description を取得し、ローカルの 'llm-temp/issue-todo-<issue_number>.md' と同期させなければならない。
  - 取得は scripts/command-runner.py の対応コマンドを用いて行い、手動でのコピーや直接編集で同期してはならない。
  - 同期後の内容のみを基準として、以降の読取り・判断を行わなければならない。
  - 着手時の GitHub 取得または同期に失敗した場合は、その失敗を無視してローカル Markdown だけで着手してはならない。
  - ただし fallback としてローカル Markdown を使用できるのは、直前の Issue実施で `issue-todo --check` の出力 JSON に含まれる `sync.github_updated` が `true` であり、その後に 'llm-temp/issue-todo-<issue_number>.md' を直接編集しておらず、今回着手しようとする `IssueToDo` の前に少なくとも 1 件のチェック済み ToDo が存在する場合に限る。
  - 上記 fallback を使う場合でも、ローカル Markdown の `IssueToDo` から `issue-todo --get` で得られた `next` 1 件だけを対象とし、GitHub 同期失敗中の状態で次の `IssueToDo` へ連続して進んではならない。
- 着手時は、対象 Issue の Description と、その Issue の直近の詳細化コメントを読み、禁止事項、`IssueToDo`、読取り対象、更新対象、完了条件を確定しなければならない。
- 着手時は、次の usage で `./scripts/command-runner.py 'issue-todo' --get` を実行し、出力 JSON の `next` を確認しなければならない。
  `./scripts/command-runner.py 'issue-todo' --get --issue-number '<issue_number>' --todo-section 'IssueToDo' --body-file 'llm-temp/issue-todo-<issue_number>.md'`
  例: `./scripts/command-runner.py 'issue-todo' --get --issue-number '69' --todo-section 'IssueToDo' --body-file 'llm-temp/issue-todo-69.md'`
    - `<issue_number>` は、今回実施中の Issue 番号であり、省略してはならない。
    - `llm-temp/issue-todo-<issue_number>.md` は、現在の Issue Description と一致しているローカル Markdown、または上記 fallback 条件を満たしたローカル Markdown であり、省略してはならない。
    - 出力 JSON の `next` が `null` の場合は、未完了 `IssueToDo` が存在しない状態として扱い、実装、Issue 更新、コミットへ進んではならない。
    - 出力 JSON の `next` が object の場合は、その object の `todo_number` を今回着手する `IssueToDo` 番号として扱わなければならない。
    - fallback 中に `issue-todo --get` 自体が失敗した場合は、古い読取り結果や推測で対象 ToDo を選んではならず、blocker として停止しなければならない。
- `IssueToDo` が複数未完了でも、今回着手する対象は `issue-todo --get` の `next` で示された 1 件だけに固定し、同じ着手で 2 件以上を同時に進めてはならない。
- 今回着手する `IssueToDo` は、`issue-todo --get` の `next` で示された項目に列挙された読取り対象だけで、変更対象と判断基準が一意に確定できることを確認しなければならない。確定できない場合は blocker として停止しなければならない。
- 着手対象の `IssueToDo` に先行未完了の読取り ToDo がある場合は、その ToDo を飛ばして後続 ToDo へ進んではならない。

### 実行

- 実装前には、着手する `IssueToDo` の達成に必要なファイルだけを読み、関係のないコードや文書を追加で読んではならない。
- 実装中は、対象 ToDo に直接必要な変更だけを行い、後続 ToDo のための途中差分を同じ変更セットへ混在させてはならない。

### 検証

- focused verification は、変更が `tools`、`skills`、`scripts` だけに閉じる場合は対象ファイルの構文確認と代表的な 1 経路の確認に限定し、アプリ本体へ影響する場合は対応するテストと build 確認へ広げなければならない。

### 更新

- 今回の変更セットに必要な `docs/history/*-latest.md` 更新を、対応する `scripts/command-runner.py` の command だけで完了させなければならない。
- focused verification が完了した後、Git の staging 前かつ commit 前に、次の usage で対象 Issue の `IssueToDo` を 1 件だけチェック済みに更新しなければならない。
  `./scripts/command-runner.py 'issue-todo' --check --issue-number '<issue_number>' --todo-section 'IssueToDo' --todo-number '<todo_number>' --body-file 'llm-temp/issue-todo-<issue_number>.md'`
  例: `./scripts/command-runner.py 'issue-todo' --check --issue-number '69' --todo-section 'IssueToDo' --todo-number '7' --body-file 'llm-temp/issue-todo-69.md'`
    - `<issue_number>` は、今回実施中の Issue 番号であり、省略してはならない。
    - `<todo_number>` は、今回完了した `### IssueToDo` 配下で本文テキストとして書かれた ToDo 番号であり、省略してはならない。
    - `llm-temp/issue-todo-<issue_number>.md` は、現在の Issue Description と一致しているローカル Markdown、または上記 fallback 条件を満たしたローカル Markdown である。
    - `issue-todo --check` は、fallback を許可しない呼び出しでは、GitHub 反映に失敗した場合にローカル Markdown を元へ戻し、stdout JSON で `sync.github_updated = false` を返すものとして扱わなければならない。
    - `issue-todo --check` で GitHub 同期失敗時のローカル完了を許可する場合だけ、`--allow-local-fallback` を追加して実行してよい。`--allow-local-fallback` を付けてよいのは、着手時に GitHub 同期成功または上記 fallback 条件成立を確認済みであり、かつ今回着手した `IssueToDo` の前に少なくとも 1 件のチェック済み ToDo が存在する場合に限る。
    - `--allow-local-fallback` を付けない通常呼び出しで `sync.github_updated` が `false` の場合は、今回の `IssueToDo` は未更新のまま blocker として停止しなければならない。
    - `--allow-local-fallback` を付けた呼び出しで `sync.github_updated` が `true` の場合は、通常の `IssueToDo` 更新完了として扱う。
    - `--allow-local-fallback` を付けた呼び出しで `sync.github_updated` が `false` の場合は、ローカル Markdown だけが更新され GitHub は未反映の状態として扱う。この場合は今回の変更内容と未同期状態を報告して停止しなければならず、そのローカル更新を前提に次の `IssueToDo` 取得へ進んではならない。
    - `issue-todo --check` は、GitHub 反映に失敗しても stdout に JSON を出力し、終了コードだけが非 0 になる場合がある。この場合は stderr の有無だけで失敗と決め打ちせず、stdout JSON の `sync.github_updated` を確認しなければならない。

### コミット

- working treeが空の場合は、コミットをスキップしなければならない。
- コミットは、focused verification と `IssueToDo` 更新が完了した後に、今回完了した 1 件分の変更セットだけを対象として行わなければならない。
- `issue-todo --check` を `--allow-local-fallback` 付きで実行し、その出力 JSON の `sync.github_updated` が `false` でも、更新セクションの条件を満たして今回の `IssueToDo` をローカル完了扱いにできる場合に限り、その 1 件分の変更セットを commit してよい。

### 停止判断

- `IssueToDo` が完了条件を満たせない blocker に当たった場合は、変更を広げず、確認した内容と停止理由をユーザーへ報告して停止しなければならない。
- GitHub 同期失敗を伴う fallback で停止する場合は、`IssueToDo` のローカル更新有無、`sync.github_updated` の値、次の `IssueToDo` へ進まない理由を明示して報告しなければならない。
- コミット後に次の未完了 `IssueToDo` へ進むか、Issue実施を終了するかは、次の `./scripts/command-runner.py 'issue-todo' --get` の出力 JSON に含まれる `next` だけを根拠に判断しなければならない。

## 完了条件

- 詳細化済み Issue の `IssueToDo` から `scripts/command-runner.py 'issue-todo' --get` の `next` で示された 1 件だけを選び、その 1 件だけを処理していること。
- 着手した `IssueToDo` に必要な読取り対象だけを読んでいること。
- focused verification が、今回の変更範囲に応じた内容で完了していること。
- Git の staging 前かつ commit 前に、対応する `IssueToDo` が `scripts/command-runner.py 'issue-todo' --check` でチェック済みに更新されていること。
- コミットが、今回完了した 1 件分の変更セットだけで構成されていること。
- blocker がある場合は、変更を拡大せず停止していること。

## 禁止事項

- 2 件以上の `IssueToDo` を同じ着手でまとめて処理してはならない。
- 詳細化コメントや `IssueToDo` に書かれていない判断基準を、推測で補って実装してはならない。
- 先行未完了 ToDo を残したまま、後続 ToDo の変更へ進んではならない。
- focused verification 前に `IssueToDo` をチェック済みにしてはならない。
- `IssueToDo` 更新前に Git の staging や commit を行ってはならない。
- 今回の `IssueToDo` と無関係な差分や、後続 ToDo の途中差分を同じコミットへ混在させてはならない。
- `IssueToDo` の未完了項目の選定や Issue実施の終了条件を、`scripts/command-runner.py 'issue-todo' --get` の出力 JSON に含まれる `next` 以外から判断してはならない。
- 着手時の GitHub 同期に失敗した状態で、先行チェック済み ToDo が存在しない `IssueToDo` へ着手してはならない。
- `issue-todo --check` に `--allow-local-fallback` を付ける条件を満たしていないのに、その option を付けて実行してはならない。
