# YoutubeFeeder

LLM ドリブンな iOS アプリ開発の実験プロジェクトである。

## Core Concept

本プロジェクトは以下を統合した開発モデルを検証することを目的とする。

- specs（仕様）を最小単位のルール集合として定義する
- LLM がルールを参照しながら実装を行う
- 参照経路をログとして記録する
- ログを分析し、設計とルールを改善する

この一連の流れを通じて、

> **Specification-Driven LLM Development（SDL）**

と呼ぶ開発プロセスの成立性を検証する。

## Overview

このアプリは公開を目的としない。
LLM と人が協調して以下を回せるかを試すための実験環境である。

- 設計（specs）
- 実装（LLM）
- 実行（アプリ）
- 観測（ログ）
- 分析（SQLite / DuckDB）

機能としては以下を備える。

- YouTube チャンネル登録
- チャンネル一覧・動画一覧の閲覧
- 固定キーワード検索
- YouTube 検索
- ローカルキャッシュ運用
- 端末内バックアップ
- 全設定リセット

## Architecture of Process

本プロジェクトの開発フローは以下のように定義される。

1. ユーザー指示を構造化する（user-instruction-understanding）
2. specs から拘束条件を抽出する（LOOKUP）
3. ルールID集合として制約を適用する
4. 実装・修正を行う
5. 参照ログを記録する
6. ログを分析し、specs を改善する

この構造により、

- 探索（柔軟性）
- 制約（安定性）
- 観測（可視化）
- 改善（進化）
- 収束（コスト制御）

を同時に成立させることを狙う。

## Documents

- 開発ルール: [AGENTS.md](./AGENTS.md)
- 仕様文書:
  - [specs.md](./docs/specs.md)
  - [specs-product.md](./docs/specs/specs-product.md)
  - [specs-architecture.md](./docs/specs/specs-architecture.md)
  - [specs-design.md](./docs/specs/specs-design.md)
  - [specs-environment.md](./docs/specs/specs-environment.md)
- 人間向け入口資料:
  - [gui.md](./docs/human-view/gui.md)
  - [design-overview.md](./docs/human-view/design-overview.md)
  - [rules-overview.md](./docs/human-view/rules-overview.md)

## Positioning

本プロジェクトは以下の交差点に位置する。

- Spec-driven development
- Rule / Policy based system
- LLM orchestration
- Observability-driven development

単一の既存手法に従うものではなく、それらを統合した実験的アプローチである。