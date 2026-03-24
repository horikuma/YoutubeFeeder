# Project Rules

この文書は、このリポジトリにおける rules コレクション全体の最上位入口である。ここでは、各 rules 文書の役割、開発タスクごとの参照順、コレクション全体に共通する運用原則だけを定義する。

## この文書の役割

- `rules.md` は、rules コレクション全体の索引とし、個別ルール本文の置き場として肥大化させない。
- この文書には、rules コレクション全体に共通する運用原則、各 rules 文書の責務、開発着手時の参照順だけを残す。
- 文書運用、開発フロー、tools / skills / scripts の具体ルールは、対応する個別文書へ委譲する。

## rules コレクション

- [rules-document.md](./rules/rules-document.md)
  - 文書体系、文書の切り分け、履歴文書、Markdown、human-view の運用を扱う。
- [rules-process.md](./rules/rules-process.md)
  - 開発シーケンス、テスト、検証、完了条件、健康度観測のフローを扱う。
- [rules-skills.md](./rules/rules-skills.md)
  - `tools`、`skills`、`scripts` の責務と運用ルールを扱う。

## タスク別の参照順

- 新しい開発シーケンスを始める前は、まずこの文書を読み、続いて [rules-document.md](./rules/rules-document.md) と [rules-process.md](./rules/rules-process.md) を読む。
- 機能追加や画面仕様変更に着手する前は、[rules-process.md](./rules/rules-process.md) を読み、続いて [specs.md](./specs.md)、必要なら [specs-product.md](./specs/specs-product.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) を読む。
- 不具合修正や調査に着手する前は、[rules-process.md](./rules/rules-process.md) を読み、続いて影響範囲に応じて [specs.md](./specs.md)、[specs-product.md](./specs/specs-product.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) を読む。
- 設計整理や責務分割に着手する前は、[rules-process.md](./rules/rules-process.md) を読み、続いて [specs.md](./specs.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) を読む。
- 開発環境、版固定、ローカル検証手順の変更へ着手する前は、[rules-process.md](./rules/rules-process.md) を読み、続いて [specs.md](./specs.md) と [specs-environment.md](./specs/specs-environment.md) を読む。
- 文書更新に着手する前は、[rules-document.md](./rules/rules-document.md) を読み、どの文書へ置くべきかの判断基準を確認する。
- `tools`、`skills`、`scripts` に関わる変更へ着手する前は、[rules-skills.md](./rules/rules-skills.md) を追加で読む。
- 開発シーケンスの終盤で文書更新へ入る前は、この文書を再読し、役割分担を崩す更新を混ぜていないことを確認する。

## rules コレクションの運用原則

- 人と LLM のどちらが変更しても、同じ判断基準で継続開発できる状態を保つ。
- 人間向け参照資料を含め、正本と翻訳資料の同期を崩さない。
- 文書群の再編で役割が変わった時は、まずこの文書の役割定義を更新し、その後に個別文書を更新する。
