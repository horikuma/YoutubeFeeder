# Session End Skill

この文書は、開発セッション終了という 1 つのタスクだけを定義する。

## タスク定義

- セッション終了とは、作業完了後の基準状態を整え、Issue 駆動で進めた作業ではそのセッション累計の `LLM所要時間` を対象 Issue へ反映するタスクである。
- ブランチに関しては、`./scripts/command-runner.py 'git-main-sync'` で `main` を最新化した後、Squash マージ済みの local branch の掃除を script 側へ委ねることだけを目的とする。
- セッション終了におけるブランチ解釈は上記のみとし、`main` 以外を終了時の基準ブランチとして扱ってはならない。
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
- Issue 駆動で進めた作業の `LLM所要時間` 反映では、次の command だけを正規手順として使わなければならない。
  `./scripts/command-runner.py 'metrics-llm-elapsed' session-finish`
  例: `./scripts/command-runner.py 'metrics-llm-elapsed' session-finish`
  - この command は、その時点までのセッション累計 `LLM所要時間` を分単位で出力し、反映後に次セッションへ不要な累積を持ち越さないよう内部状態を消去する。
  `./scripts/command-runner.py 'project-field-set' --issue-number '<issue_number>' --value '<minutes>'`
  例: `./scripts/command-runner.py 'project-field-set' --issue-number '103' --value '12'`
  - `<issue_number>` は、そのセッションで対応する Issue 番号であり、省略してはならない。
  - `<minutes>` は、直前の `./scripts/command-runner.py 'metrics-llm-elapsed' session-finish` が出力した、そのセッション開始から session-end 実行時点までの累計 `LLM所要時間` 分数であり、省略してはならない。
- セッション終了タスクは、次の 3 条件を満たした時だけ完了とみなす。

## 完了条件

- `./scripts/command-runner.py 'git-main-sync'` が終了コード `0` で成功し、その結果として `main` が最新化され、Squash マージ済みの local branch の掃除も完了していること。
- Issue 駆動で進めた作業では、`./scripts/command-runner.py 'metrics-llm-elapsed' session-finish` と `./scripts/command-runner.py 'project-field-set' --issue-number '<issue_number>' --value '<minutes>'` が成功し、対象 Issue へそのセッション累計の `LLM所要時間` が反映されていること。
- 上記 2 条件の結果として、終了時の基準ブランチが `main` になっており、次セッションへ不要な `LLM所要時間` 累積を持ち越さない状態になっていること。

## 禁止事項

- 上記 2 条件以外の作業を、この文書の対象へ含めてはならない。
- `main` 以外のブランチを、セッション終了時の基準ブランチとして扱ってはならない。
- `main` の最新化を、`./scripts/command-runner.py 'git-main-sync'` 以外の checkout / fetch / reset / pull 手順で代替してはならない。
- Squash マージ済みでない local branch の `./scripts/command-runner.py 'git' branch -D` を、セッション終了へ含めてはならない。
- ローカルブランチ掃除で、`./scripts/command-runner.py 'git' branch -D` 以外の方法を正規手順として扱ってはならない。
- `LLM所要時間` の Issue 反映を、`./scripts/command-runner.py 'project-field-set'` 以外の経路で正規手順として扱ってはならない。
- session-end で `LLM所要時間` を Issue へ反映する前に、`./scripts/command-runner.py 'metrics-llm-elapsed' session-finish` を使わずに累計分数を確定してはならない。
- `LLM所要時間` の Issue 反映を session-end で行うべきケースで、Pull Request 作成時の反映へ置き換えてはならない。
