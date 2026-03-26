# Project Rules

この文書を rules コレクション全体の最上位入口として扱わなければならない。ここへ記述してよい内容は、タスク別に分割した各 rules 文書の役割、開発タスクごとの参照順、コレクション全体に共通する運用原則だけに限定し、それ以外の具体ルールをここへ混在させてはならない。

## この文書の役割

- `rules.md` は rules コレクション全体の索引として維持しなければならず、個別ルール本文の置き場として肥大化させてはならない。
- この文書へ残してよい内容は、rules コレクション全体に共通する運用原則、各 rules 文書の責務、開発着手時の参照順だけとし、それ以外の詳細本文を追記してはならない。
- 文書運用、開発フロー、言語単位、tools / skills / scripts の具体ルールを更新する場合は、対応する個別文書へ記述しなければならず、該当しない個別文書を参照してはならない。

## rules コレクション

- [rules-update-documents.md](./rules/rules-update-documents.md)
  - 文書更新、文書配置、履歴文書、Markdown、human-view の運用を判断する必要がある場合にだけ参照しなければならず、それ以外の論点では参照してはならない。
- [rules-run-development.md](./rules/rules-run-development.md)
  - 開発シーケンス、Issue 駆動、検証、完了条件、健康度観測を判断する必要がある場合にだけ参照しなければならず、それ以外の論点では参照してはならない。
- [rules-change-languages.md](./rules/rules-change-languages.md)
  - shell、Python、C 系言語、複雑度しきい値のような言語単位ルールを判断する必要がある場合にだけ参照しなければならず、それ以外の論点では参照してはならない。
- [rules-change-tools.md](./rules/rules-change-tools.md)
  - `tools`、`skills`、`scripts` と GitHub skill 運用を判断する必要がある場合にだけ参照しなければならず、それ以外の論点では参照してはならない。
- [rules-change-visual-design.md](./rules/rules-change-visual-design.md)
  - 視覚設計、余白、文字組み、色の使い方を判断する必要がある場合にだけ参照しなければならず、それ以外の論点では参照してはならない。

## タスク別の参照順

- 新しい開発シーケンスを始める前は、まずこの文書を読み、続いて [rules-update-documents.md](./rules/rules-update-documents.md) と [rules-run-development.md](./rules/rules-run-development.md) を読まなければならない。この順序に該当しない参照省略をしてはならない。
- 機能追加や画面仕様変更に着手する前は、[rules-run-development.md](./rules/rules-run-development.md) を読み、続いて [specs.md](./specs.md) を読み、さらに必要な変更が画面導線・アーキテクチャ・詳細設計へ及ぶ場合に限って [specs-product.md](./specs/specs-product.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) を読まなければならない。影響しない specs を慣習的に参照してはならない。
- 不具合修正や調査に着手する前は、[rules-run-development.md](./rules/rules-run-development.md) を読み、続いて影響範囲に応じて [specs.md](./specs.md)、[specs-product.md](./specs/specs-product.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) のうち必要なものだけを読まなければならない。影響範囲に該当しない specs を参照してはならない。
- 設計整理や責務分割に着手する前は、[rules-run-development.md](./rules/rules-run-development.md) を読み、続いて [specs.md](./specs.md)、[specs-architecture.md](./specs/specs-architecture.md)、[specs-design.md](./specs/specs-design.md) を読まなければならない。画面導線の変更を伴わない限り [specs-product.md](./specs/specs-product.md) を参照してはならない。
- 開発環境、版固定、ローカル検証手順の変更へ着手する前は、[rules-run-development.md](./rules/rules-run-development.md) を読み、続いて [specs.md](./specs.md) と [specs-environment.md](./specs/specs-environment.md) を読まなければならない。環境変更に無関係な specs を参照してはならない。
- 文書更新に着手する前は、[rules-update-documents.md](./rules/rules-update-documents.md) を読んでどの文書へ置くべきかの判断基準を確認しなければならない。配置判断に関係しない rules を代用してはならない。
- 実装言語、formatter / lint、shell wrapper の変更へ着手する前は、[rules-change-languages.md](./rules/rules-change-languages.md) を追加で読まなければならない。言語単位の変更に該当しない場合は参照してはならない。
- `tools`、`skills`、`scripts` に関わる変更へ着手する前は、[rules-change-tools.md](./rules/rules-change-tools.md) を追加で読まなければならない。これらに関わらない変更では参照してはならない。
- 画面の見た目、余白、色、文字組みの変更へ着手する前は、[rules-change-visual-design.md](./rules/rules-change-visual-design.md) を追加で読まなければならない。視覚設計の変更に該当しない場合は参照してはならない。
- 開発シーケンスの終盤で文書更新へ入る前は、この文書を再読し、役割分担を崩す更新を混ぜていないことを確認しなければならない。再確認を省略して文書更新へ進んではならない。

## rules コレクションの運用原則

- 人と LLM のどちらが変更しても同じ判断基準で継続開発できる状態を保たなければならず、暗黙知に依存する記述を放置してはならない。
- 単一選択ルールとして、LLM は各タスクの開始時に該当する rules を 1 つだけ選択しなければならず、複数の rules が関係し得る場合でも最も直接関係する 1 つに限定しなければならない。選択されなかった rules は、そのタスクでは参照してはならない。
- 人間向け参照資料を含め、正本と翻訳資料の同期を保たなければならず、片側だけを更新してはならない。
- 文書群の再編で役割が変わった時は、まずこの文書の役割定義を更新し、その後に個別文書を更新しなければならない。順序を逆にしてはならない。
