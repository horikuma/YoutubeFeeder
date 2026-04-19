# Issue Branch Switching Skill

この文書は、Issue ブランチ切り替えという 1 つのタスクだけを定義する。

## Issue ブランチ切り替え

- Issue ブランチ切り替えとは、対象 Issue の作業ブランチを `issue-<issue_number>` 形式で作成し、`main` を最新化した後、その作業ブランチへ切り替えるタスクである。
- このタスクでは、対象 Issue 番号の確定、同名ブランチの未存在確認、作業ブランチ作成、`main` の最新化、作業ブランチへの切り替え、完了確認までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- 着手時は、対象 Issue 番号を確定しなければならない。
- 対象 Issue 番号が確定できない場合は、処理を中断し、対象 Issue 番号が必要であることをユーザーへ報告しなければならない。
- 作成するブランチ名は `issue-<issue_number>` 形式でなければならない。
- ブランチ作成前に、次の usage で同名ブランチが存在しないことを確認しなければならない。
  `./scripts/command-runner.py 'git' branch --list <branch_name>`
  例: `./scripts/command-runner.py 'git' branch --list issue-147`
  - `<branch_name>` は、`issue-<issue_number>` 形式のブランチ名であり、省略してはならない。
- 同名ブランチ確認の出力が空でない場合は、既存ブランチを上書きせず、処理を中断して既存ブランチがあることをユーザーへ報告しなければならない。
- 作業ブランチ作成は、次の usage で実行しなければならない。
  `./scripts/command-runner.py 'git' branch <branch_name>`
  例: `./scripts/command-runner.py 'git' branch issue-147`
  - `<branch_name>` は、`issue-<issue_number>` 形式のブランチ名であり、省略してはならない。
- `main` の最新化では、次の command だけを使わなければならない。
  `./scripts/command-runner.py 'git-main-sync'`
  例: `./scripts/command-runner.py 'git-main-sync'`
  - この command の終了コード `0` だけを成功として扱わなければならない。
  - この command が失敗した場合は、手作業の追加 Git 操作で復旧せず、失敗したことをユーザーへ報告しなければならない。
- 作業ブランチへの切り替えは、次の usage で実行しなければならない。
  `./scripts/command-runner.py 'git' switch <branch_name>`
  例: `./scripts/command-runner.py 'git' switch issue-147`
  - `<branch_name>` は、`issue-<issue_number>` 形式のブランチ名であり、省略してはならない。
- 切り替え後は、次の usage で現在ブランチを確認しなければならない。
  `./scripts/command-runner.py 'git' status --short --branch`
  例: `./scripts/command-runner.py 'git' status --short --branch`
- 現在ブランチが作成した `issue-<issue_number>` でない場合は、処理を中断し、現在ブランチと期待ブランチをユーザーへ報告しなければならない。

## 完了条件

- 対象 Issue 番号が確定していること。
- `issue-<issue_number>` 形式の作業ブランチが作成されていること。
- `./scripts/command-runner.py 'git-main-sync'` が終了コード `0` で成功し、`main` が最新化されていること。
- `./scripts/command-runner.py 'git' switch <branch_name>` が成功し、現在ブランチが `issue-<issue_number>` であること。

## 禁止事項

- 対象 Issue 番号を推測してはならない。
- `issue-<issue_number>` 以外の形式で作業ブランチ名を作ってはならない。
- 同名ブランチが存在する場合に、上書き、削除、強制移動してはならない。
- `main` の最新化を `./scripts/command-runner.py 'git-main-sync'` 以外の checkout / fetch / reset / pull 手順で代替してはならない。
- Git command を `git <git_args>...` として直接実行してはならない。
- 作業ブランチへの切り替え完了を確認しないまま完了扱いしてはならない。
