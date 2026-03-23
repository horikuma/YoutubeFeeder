# YoutubeFeeder Rules

この文書は、YoutubeFeeder の rules コレクション全体に対する最上位の入口である。ここでは、各 rules 文書の役割、参照順序、抽象度の境界だけを定義する。

## この文書の役割

- `rules.md` は、rules コレクション全体の索引とし、個別ルール本文の置き場として肥大化させない。
- この文書には、プロダクト固有の抽象方針、各 rules 文書の責務、読む順序だけを残す。
- 文書運用、開発フロー、tools / skills / scripts の具体ルールは、対応する個別文書へ委譲する。

## rules コレクション

- [rules-document.md](./rules-document.md)
  - 文書体系、文書の切り分け、履歴文書、Markdown、human-view の運用を扱う。
- [rules-process.md](./rules-process.md)
  - 開発シーケンス、テスト、検証、完了条件、健康度観測のフローを扱う。
- [rules-skills.md](./rules-skills.md)
  - `tools`、`skills`、`scripts` の責務と運用ルールを扱う。

## 参照順序

- 新規の開発着手時は、まずこの文書を読み、続いて [rules-document.md](./rules-document.md) と [rules-process.md](./rules-process.md) を読む。
- `tools`、`skills`、`scripts` に関わる変更や確認がある場合だけ、追加で [rules-skills.md](./rules-skills.md) を読む。
- 個別ルールを更新する時は、この文書の役割定義と矛盾しないことを確認する。

## このプロダクトで守る抽象方針

- 人と LLM のどちらが変更しても、同じ判断基準で継続開発できる状態を保つ。
- 起動性能、操作中の軽さ、ローカルキャッシュを正本とする閲覧体験を長期的に損なわない。
- `iPhone` と `iPad` の機能差分を作らず、差分は Adaptive UI に沿った表現差分へ閉じ込める。
- 人間向け参照資料を含め、正本と翻訳資料の同期を崩さない。

## 抽象度の境界

- `rules.md` へ、実装詳細、画面単位の仕様、日次運用手順、個別コマンド運用を集約してはならない。
- 開発手順が主題の内容は [rules-process.md](./rules-process.md) へ置く。
- 文書の配置、更新対象、履歴、human-view、Markdown 記法が主題の内容は [rules-document.md](./rules-document.md) へ置く。
- `tools`、`skills`、`scripts` の配置、命名、更新判断が主題の内容は [rules-skills.md](./rules-skills.md) へ置く。
- 文書群の再編で役割が変わった時は、まずこの文書の役割定義を更新し、その後に個別文書を更新する。
