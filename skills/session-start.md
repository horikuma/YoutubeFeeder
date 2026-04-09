# Session Start Skill

この文書は、開発セッション開始という 1 つのタスクだけを定義する。

## タスク定義

- セッション開始とは、作業開始前の基準状態を整えるタスクである。
- ブランチに関しては、`./scripts/command-runner.py 'git-main-sync'` で `main` を最新化した後、`git fetch --prune` で remote-tracking branch を掃除することだけを目的とする。
- セッション開始におけるブランチ解釈は上記のみとし、他ブランチを session main とみなす等の別解釈を含めてはならない。
- `main` の最新化では、次の command だけを正規手順として使わなければならない。
  `./scripts/command-runner.py 'git-main-sync'`
  例: `./scripts/command-runner.py 'git-main-sync'`
  - この command は、`main` への checkout、`origin/main` の fetch、`main` と `origin/main` の共通祖先 commit 判定、必要時の reset、`pull --ff-only` を決定論的に実行する。
  - 終了コード `0` は成功である。
  - 終了コード `10` は worktree が dirty で checkout / reset が安全に行えない失敗である。
  - 終了コード `11` は `main` への checkout または `refs/heads/main` 解決に失敗したことを表す。
  - 終了コード `12` は `origin main` の fetch に失敗したことを表す。
  - 終了コード `13` は `refs/remotes/origin/main` を解決できず、remote-tracking ref が存在しないことを表す。
  - 終了コード `14` は `main` と `origin/main` の共通祖先 commit を解決できないことを表す。
  - 終了コード `15` は共通祖先 commit への reset に失敗したことを表す。
  - 終了コード `16` は reset 後または通常経路での `pull --ff-only origin main` に失敗したことを表す。
  - LLM は、この command の成功可否と失敗モードを終了コードで判定し、手作業の追加 Git 操作で原因推定してはならない。
- remote-tracking branch 掃除では、次の command だけを正規手順として使わなければならない。
  `git fetch --prune`
  例: `git fetch --prune`
  - `--prune` は、remote に存在しなくなった remote-tracking branch を掃除する目的で使わなければならない。
- セッション開始タスクは、次の 4 条件を満たした時だけ完了とみなす。

## 完了条件

- `./scripts/command-runner.py 'git-main-sync'` が終了コード `0` で成功し、その結果として `main` が最新化されていること。
- `main` の最新化直後に、`git fetch --prune` が成功していること。
- `./scripts/command-runner.py 'history-rotate'` が成功終了し、その成功により次を保証していること。
  `./scripts/command-runner.py 'history-rotate'`
  例: `./scripts/command-runner.py 'history-rotate'`
  - 本日以外の日付見出しを含む内容は、対応する `*-log.md` へ掃き出されていること。
  - `*-latest.md` の 1 行目が本日の日付見出しであること。
- 上記 3 条件を満たした結果として差分が残る場合は、その差分をコミットしていること。

## 禁止事項

- 上記 3 条件以外の作業を、この文書の対象へ含めてはならない。
- セッション開始タスクが未完了のまま、以後の開発タスクへ進んではならない。
- `main` 以外のブランチを、セッション開始時の基準ブランチとして扱ってはならない。
- merged な local branch の削除や、`git branch -d` / `git branch -D` による local branch 操作をセッション開始へ含めてはならない。
- `main` の最新化を、`./scripts/command-runner.py 'git-main-sync'` 以外の checkout / fetch / reset / pull 手順で代替してはならない。
- `*-latest.md` および `*-log.md` の本文を、完了判定のために直接読み込んではならない。
- `*-log.md` を直接読み込んではならない。
- 履歴移動を手作業や別経路で行ってはならず、`./scripts/command-runner.py 'history-rotate'` を使わなければならない。
- 履歴移動後の差分確認が必要な場合は、`git` コマンドを通して確認しなければならない。
