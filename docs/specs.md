# Project Specs

この文書は、このリポジトリにおける specs コレクション全体の最上位入口である。ここでは、仕様系文書の役割、参照順、コレクション全体での責務分担だけを定義する。

上位の文書運用ルールは [rules.md](./rules.md) と [rules-document.md](./rules/rules-document.md) を参照する。

## specs コレクション

- [specs-product.md](./specs/specs-product.md)
  - ユーザー向け機能、画面遷移、操作、表示要件を扱う。
- [specs-architecture.md](./specs/specs-architecture.md)
  - 採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を扱う。
- [specs-design.md](./specs/specs-design.md)
  - ファイル単位、型単位、テスト単位の責務や構成など、詳細設計を扱う。
- [specs-environment.md](./specs/specs-environment.md)
  - ローカル開発に必要なツール、版固定、セットアップ手順、再現性を守る運用を扱う。

## タスク別の参照順

- 機能追加や画面仕様変更に着手する前は、まず [specs-product.md](./specs/specs-product.md) を読む。
- 設計整理や責務分割、不具合の構造的な調査に着手する前は、[specs-architecture.md](./specs/specs-architecture.md) を読む。
- 実装箇所や型単位の責務、テスト配置を調べる時は、[specs-design.md](./specs/specs-design.md) を読む。
- 開発環境、ツール版固定、ローカル検証手順を確認する時は、[specs-environment.md](./specs/specs-environment.md) を読む。

## specs コレクションの運用原則

- `specs.md` は specs コレクションの索引とし、仕様本文そのものを肥大化させない。
- 機能仕様、設計方針、詳細設計はそれぞれ対応する個別文書へ置き、入口文書へ混在させない。
- 開発環境の版固定や再現手順は、機能仕様や設計方針へ混在させず [specs-environment.md](./specs/specs-environment.md) へ置く。
- specs コレクションの再編で役割が変わった時は、まずこの文書の役割定義を更新し、その後に個別文書を更新する。
