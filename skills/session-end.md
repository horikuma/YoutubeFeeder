# Session End Skill

この文書は、開発セッション終了という 1 つのタスクだけを定義する。

## タスク定義

- セッション終了とは、ブランチを `git-main-sync` で最新化するタスクである。
- 次の command だけを正規手順として使わなければならない。
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

## 完了条件

- `./scripts/command-runner.py 'git-main-sync'` が終了コード `0` で成功し、その戻り値により `main` が最新化されていること。

## 禁止事項

- `main` 以外のブランチを、セッション終了時の基準ブランチとして扱ってはならない。
- `main` の最新化を、`./scripts/command-runner.py 'git-main-sync'` 以外の checkout / fetch / reset / pull 手順で代替してはならない。
