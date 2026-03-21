# YoutubeFeeder Development Environment

この文書は、YoutubeFeeder の開発環境に関する参照資料である。ここでは、開発に必要なローカルツール、版固定、セットアップ手順、再現性を守るための運用を扱う。

## 基本方針

- 開発環境で追加するツールは、リポジトリ内の版固定ファイルと lock file を正本として再現できる状態で導入する。
- 一時的に手元だけで入れたグローバルツールを前提にせず、リポジトリ内のスクリプトから同じ版のツールを呼び出せる状態を維持する。
- 文書検証に外部 API を使わず、ローカル実行だけで成功可否を再現できるようにする。

## Node.js

- Mermaid のローカル検証は Node.js `24.14.0` を前提にする。
- Node.js の版固定は [.node-version](../.node-version) と [package.json](../package.json) の `engines.node` で行う。
- package manager は `npm` を使い、版固定は [package-lock.json](../package-lock.json) を正本とする。

## セットアップ

1. Node.js `24.14.0` を導入する。
2. リポジトリルートで `npm install` を実行する。
3. Mermaid を含む Markdown を変更したら `npm run check:mermaid` を実行する。

## Mermaid ローカル検証

- Mermaid の検証は [check_mermaid.mjs](../scripts/check_mermaid.mjs) を正本とする。
- `npm run check:mermaid` は `docs/` 配下と [README.md](../README.md) から Mermaid ブロックを抽出し、`mmdc` でローカル SVG レンダリングを行う。
- 失敗時は `ファイル:開始行` を出力し、そのブロックだけを直せる状態を保つ。
- Mermaid の検証に必要な CLI と browser runtime は、[package-lock.json](../package-lock.json) に固定したローカル依存から取得する。

## LLM 所要時間の補助コマンド

- `LLM所要時間` の開始・終了時刻は、手入力ではなく [llm_elapsed.sh](../scripts/llm_elapsed.sh) を使って記録する。
- ユーザー指示を受けた直後に `scripts/llm_elapsed.sh start` を実行し、`chat-latest.md` などを更新する直前に `scripts/llm_elapsed.sh finish` を実行して、その出力をそのまま履歴へ貼り付ける。
- 途中確認が必要なら `scripts/llm_elapsed.sh status` を使い、取り直しが必要なら `scripts/llm_elapsed.sh reset` で現在の測定を破棄してから再開する。
- 状態ファイルはリポジトリの `.git/llm_elapsed/` 配下へ保存し、Git 管理対象には含めない。

## 更新ルール

- Mermaid 検証用の Node.js 版や依存を更新する場合は、[.node-version](../.node-version)、[package.json](../package.json)、[package-lock.json](../package-lock.json)、この文書を同じ変更セットで更新する。
- セットアップ手順や検証コマンドを変えた場合は、[README.md](../README.md) と必要な運用文書を同時に同期する。
