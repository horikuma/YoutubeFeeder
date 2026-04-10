# YoutubeFeeder Development Environment

この文書は、YoutubeFeeder の開発環境仕様に関する正本である。ここでは、開発に必要なローカルツール、版固定、セットアップ手順、再現性を守るための運用を扱う。

## 基本方針

- 開発環境で追加するツールは、リポジトリ内の版固定ファイルと lock file を正本として再現できる状態で導入する。
- 一時的に手元だけで入れたグローバルツールを前提にせず、リポジトリ内のスクリプトから同じ版のツールを呼び出せる状態を維持する。
- 文書検証に外部 API を使わず、ローカル実行だけで成功可否を再現できるようにする。

## Node.js

- Mermaid のローカル検証は Node.js `24.14.0` を前提にする。
- Node.js の版固定は [.node-version](../../.node-version) と [package.json](../../package.json) の `engines.node` で行う。
- package manager は `npm` を使い、版固定は [package-lock.json](../../package-lock.json) を正本とする。

## セットアップ

1. Node.js `24.14.0` を導入する。
2. リポジトリルートで `npm install` を実行する。
3. Mermaid を含む Markdown を変更したら `npm run check:mermaid` を実行する。

## Mermaid ローカル検証

- Mermaid の検証は [check-mermaid.mjs](../../scripts/check-mermaid.mjs) を正本とする。
- `npm run check:mermaid` は `docs/` 配下と [README.md](../../README.md) から Mermaid ブロックを抽出し、`mmdc` でローカル SVG レンダリングを行う。
- 失敗時は `ファイル:開始行` を出力し、そのブロックだけを直せる状態を保つ。
- Mermaid の検証に必要な CLI と browser runtime は、[package-lock.json](../../package-lock.json) に固定したローカル依存から取得する。

## LLM 所要時間の補助コマンド

- `LLM所要時間` の開始・終了時刻は、手入力ではなく [metrics-llm-elapsed](../../scripts/metrics-llm-elapsed) を使って記録する。
- ユーザー指示を受けた直後に `scripts/metrics-llm-elapsed start` を実行し、`chat-latest.md` などを更新する直前に `scripts/metrics-llm-elapsed finish` を実行して、その出力をそのまま履歴へ貼り付ける。
- 途中確認が必要なら `scripts/metrics-llm-elapsed status` を使い、取り直しが必要なら `scripts/metrics-llm-elapsed reset` で現在の測定を破棄してから再開する。
- session-end でセッション累計分数を Issue へ反映する時は、`scripts/metrics-llm-elapsed session-finish` を使ってその時点までのセッション累計を取得し、反映後は次セッションへ累積状態を持ち越さない。
- 状態ファイルはリポジトリの `.git/llm-elapsed/` 配下へ保存し、Git 管理対象には含めない。
- GitHub Projects に `LLM所要時間` の Number フィールドを使う場合は、Pull Request 作成時ではなく session-end 実行時に、[project-field-set](../../scripts/project-field-set) を使って対象 Issue の project item へそのセッション累計分数を反映する。
- session-end で `LLM所要時間` を Issue へ反映した後は、次セッション開始時に前セッション分を再加算しないよう、反映済みの累積状態を持ち越さない。
- [project-field-set](../../scripts/project-field-set) は、フィールドが未作成なら `LLM所要時間` の Number フィールドを作成し、その後に値を更新する。

## iOS 計測 Simulator

- [metrics-collect](../../scripts/metrics/collect-metrics.py)、[collect-test-metrics](../../scripts/metrics/collect-test-metrics.py)、[test-matrix](../../scripts/metrics/test-matrix.py) は、利用可能な iOS Simulator のうち `iPhone 17` を優先し、未導入環境では `iPhone 12 mini` へフォールバックしなければならない。
- 上記 scripts は、固定 OS 名ではなく、その時点でインストール済みの最新 runtime に属する対象 simulator を解決して使わなければならない。
- [metrics-collect](../../scripts/metrics/collect-metrics.py) の startup metrics は、`YoutubeFeederUITests/Home/HomeScreenUITests.swift` の `testHomeStartupMetrics` だけを実行する最小 UI test 経路から取得しなければならない。

## 更新ルール

- Mermaid 検証用の Node.js 版や依存を更新する場合は、[.node-version](../../.node-version)、[package.json](../../package.json)、[package-lock.json](../../package-lock.json)、この文書を同じ変更セットで更新する。
- セットアップ手順や検証コマンドを変えた場合は、[README.md](../../README.md) と必要な運用文書を同時に同期する。
