# HelloWorld Document Roles

この文書は、HelloWorld の文書群の役割分担と境界を定める正本である。各文書は冒頭で自身の定義を述べた上で、本書を参照して全体の位置付けを揃える。

文書運用ルールは [document-operations.md](./document-operations.md) を参照する。

## 正本

- [rules.md](./rules.md)
  - このプロダクト固有の意思決定ルール、優先順位、開発プロセスを記述する。
- [principles.md](./principles.md)
  - プロジェクト横断で再利用できる開発原則、テスト原則、責務分離、評価観点を記述する。
- [spec.md](./spec.md)
  - ユーザー向け機能、画面遷移、操作、表示要件を記述する。
- [architecture.md](./architecture.md)
  - プロダクトに依存する採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を記述する。
- [design.md](./design.md)
  - ファイル単位、型単位、テスト単位の責務や構成など、詳細設計を記述する。

## 参照資料

- [gui.md](./human-view/gui.md)
  - 画面名、GUI パーツ名、画面遷移、指示に使う呼び名を、人間向けの参照資料として整理して記述する。
- [design-overview.md](./human-view/design-overview.md)
  - クラス図やレイヤ図などの UML 風設計資料を、人間向けの参照資料として整理して記述する。

## 境界ルール

- `rules.md` へ実装詳細や画面単位の仕様を集約してはならない。
- `rules.md` へ横展開可能な一般原則を集約してはならず、再利用前提の内容は `principles.md` へ置く。
- 文書の内容が詳細化しすぎた場合は、上位方針を残して詳細を `spec.md`、`architecture.md`、`design.md` へ移す。
- `docs/human-view/` 配下の文書は正本ではないため、仕様や責務の最終判断根拠にしてはならない。
- `docs/human-view/` 配下の文書は、人間の開発者にとっての第一入口として、関連する正本変更と同じ変更セットで必ず同期する。
