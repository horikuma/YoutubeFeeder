# Document Rules

この文書を、このリポジトリの文書群に関する上位ルールの正本として扱わなければならない。ここへ記述してよい内容は、文書体系、文書更新時の配置判断、参照資料の位置付け、文書運用、履歴文書、Markdown 記述の共通ルールだけに限定し、それ以外を混在させてはならない。

rules コレクション全体の役割分担を判断する場合に限って [rules.md](../rules.md) を参照しなければならず、開発フローを判断する場合に限って [rules-process.md](./rules-process.md) を参照しなければならない。それ以外の論点ではこれらを参照してはならない。

## 文書体系

### 正本

- [rules.md](../rules.md)
  - rules コレクション全体の入口と参照順序を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [rules-document.md](./rules-document.md)
  - 文書体系、文書の切り分け、履歴文書、Markdown、human-view の運用を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [rules-process.md](./rules-process.md)
  - 開発シーケンス、テスト、検証、完了条件、健全性観測を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [rules-domain.md](./rules-domain.md)
  - shell、Python、C 系言語、`skills` の複雑度しきい値など、言語単位の原理原則を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [rules-skills.md](./rules-skills.md)
  - `tools`、`skills`、`scripts` の責務と運用ルールを判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [specs.md](../specs.md)
  - specs コレクション全体の入口と参照順序を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [specs-product.md](../specs/specs-product.md)
  - ユーザー向け機能、画面遷移、操作、表示要件を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [specs-architecture.md](../specs/specs-architecture.md)
  - 採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [specs-design.md](../specs/specs-design.md)
  - ファイル単位、型単位、テスト単位の責務や構成など、詳細設計を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [specs-environment.md](../specs/specs-environment.md)
  - ローカル開発に必要なツール、版固定、セットアップ手順、再現性を判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。
- [rules-design.md](./rules-design.md)
  - 画面設計、余白、文字組み、色の使い方など、視覚設計ルールを判断する場合に限って参照しなければならず、それ以外の論点では参照してはならない。

### 参照資料

- [gui.md](../human-view/gui.md)
  - 人間が画面名、GUI パーツ名、画面遷移、指示に使う呼び名を把握する必要がある場合に限って参照しなければならない。正本の代用として扱ってはならない。
- [design-overview.md](../human-view/design-overview.md)
  - 人間がクラス図やレイヤ図などの UML 風俯瞰資料を必要とする場合に限って参照しなければならない。正本の代用として扱ってはならない。
- [metrics-src.md](../metrics/metrics-src.md)
  - ソース総行数、正本文書行数、health barometer の観測結果、ファイル別の行数概観を参照資料として残す場合に限って更新または参照しなければならない。正本ルールをここへ記述してはならない。
- [metrics-test.md](../metrics/metrics-test.md)
  - テストごとの所要時間と分類を参照資料として残す場合に限って更新または参照しなければならない。正本ルールをここへ記述してはならない。
- `docs/report/` 配下
  - 個別の障害調査、性能探索、検証ログの整理結果を将来の再調査用参照資料として残す場合に限って使わなければならない。方針や仕様の正本として扱ってはならない。

## 文書更新時の配置判断

- `rules.md` へ実装詳細や画面単位の仕様を集約してはならない。
- `rules.md` へ個別運用フローや directory 運用の本文を集約してはならない。
- 開発フロー、完了条件、検証手順、健全性観測を更新する場合は [rules-process.md](./rules-process.md) へ記述しなければならない。ここへ直接書いてはならない。
- 言語単位の formatter / lint、shell wrapper、複雑度しきい値を更新する場合は [rules-domain.md](./rules-domain.md) へ記述しなければならない。ここへ直接書いてはならない。
- `tools`、`skills`、`scripts` の責務や配置規則を更新する場合は [rules-skills.md](./rules-skills.md) へ記述しなければならない。ここへ直接書いてはならない。
- クラス名や型名が出る内容を更新する場合は、原則として [specs-design.md](../specs/specs-design.md) へ記述しなければならない。ここへ直接書いてはならない。
- 画面の見た目や視覚的一貫性の基準を更新する場合は、仕様や詳細設計へ散らさず [rules-design.md](./rules-design.md) へ記述しなければならない。
- ユーザー操作や画面導線に依存する内容を更新する場合は、原則として [specs-product.md](../specs/specs-product.md) へ記述しなければならない。ここへ直接書いてはならない。
- 変更しても全体構造が変わらない実装運用の詳細を更新する場合は、主題に応じて [rules-process.md](./rules-process.md) または [specs-product.md](../specs/specs-product.md) へ記述しなければならない。該当しない文書へ書いてはならない。
- レイヤ構造、依存方向、データフローの形、責務の原則を規定する内容を更新する場合は、[specs-architecture.md](../specs/specs-architecture.md) へ記述しなければならない。ここへ直接書いてはならない。
- 開発環境、版固定、ローカル検証手順、再現性の確保方法を更新する場合は、[specs-environment.md](../specs/specs-environment.md) へ記述しなければならない。ここへ直接書いてはならない。
- 文書の内容が詳細化しすぎた場合は、上位方針を残して詳細を対応する正本文書へ移さなければならない。上位文書を詳細で肥大化させてはならない。

## 人間向け参照資料の位置付け

- `docs/human-view/` 配下の文書は正本ではないため、仕様や責務の最終判断根拠にしてはならない。
- `docs/human-view/` 配下の文書は、人間の開発者にとっての第一入口として、関連する正本変更と同じ変更セットで同期しなければならない。片側だけを更新してはならない。
- `docs/report/` 配下の文書は正本ではないため、個別調査の観測結果や仮説、比較結果を残す用途に限定し、方針や仕様の最終判断根拠にしてはならない。
- `docs/human-view/` 配下にしか存在しない設計、仕様、方針、呼称ルールを放置してはならない。判断基準として意味を持つ内容を見つけた場合は、対応する正本文書へ先にサルベージしてから `human-view` 側を整える。

## 文書運用

### 共通原則

- `rules.md` は追記メモ置き場として扱わず、章ごとの役割が読んで辿れる構造を維持する。
- `rules.md` を更新する時は、関連する既存節へ統合し、重複、矛盾、末尾だけの場当たり的な追記を避ける。
- 実装と文書にずれが出た場合は、どちらが正しいか確認してから揃える。
- 一時的な事情や現状の実装詳細を、恒久ルールとして rules 文書へ固定してはならない。
- 通常のプロジェクト文書ファイル名は `lowercase-kebab-case.md` または `lowercase.md` に統一する。
- `README.md` や `CONTRIBUTING.md` のような広く定着した慣例名だけは例外として大文字を許容する。
- `docs/human-view/` 配下は、人間向けの翻訳資料と図表資料だけを置く領域として維持しなければならない。配置だけで正本と区別できない状態にしてはならない。
- `docs/report/` 配下は、障害調査や性能探索の報告書だけを置く領域として維持しなければならない。日々の履歴バッファと混在させてはならず、1 件ごとに独立した Markdown として残さなければならない。

### 変更時の更新対象

- 上位方針や rules コレクションの役割分担を変更したら [rules.md](../rules.md) を見直す。
- 文書体系、履歴、Markdown、human-view のルールを変更したら [rules-document.md](./rules-document.md) を見直す。
- 開発フロー、検証、完了条件、健全性観測を変更したら [rules-process.md](./rules-process.md) を見直す。
- 言語単位の formatter / lint、shell wrapper、複雑度しきい値を変更したら [rules-domain.md](./rules-domain.md) を見直す。
- `tools`、`skills`、`scripts` の責務や配置規則を変更したら [rules-skills.md](./rules-skills.md) を見直す。
- specs コレクション全体の役割分担を変更したら [specs.md](../specs.md) を見直す。
- 機能を変更したら [specs-product.md](../specs/specs-product.md) を見直す。
- 採用アーキテクチャ、責務境界、データフロー、テスト方針を変更したら [specs-architecture.md](../specs/specs-architecture.md) を見直す。
- ファイル単位や型単位の責務、詳細設計、テストの配置を変更したら [specs-design.md](../specs/specs-design.md) を見直す。
- 開発環境、版固定、ローカル検証手順を変更したら [specs-environment.md](../specs/specs-environment.md) を見直す。
- GUI の見た目、パーツ名、画面遷移、画面ごとの指示に使う呼び名を変更したら [gui.md](../human-view/gui.md) を見直す。
- 人間向けの設計図や依存関係の見え方が変わる変更では [design-overview.md](../human-view/design-overview.md) を見直す。
- 余白、文字組み、色の使い方、視覚的一貫性の基準を変更したら [rules-design.md](./rules-design.md) を見直す。
- 検証コストや性能観測の更新では [metrics-latest.md](../history/metrics-latest.md) を更新し、日次履歴は [metrics-log.md](../history/metrics-log.md) で保持する。
- metrics の参照資料を置く場合は `docs/metrics/` 配下へ置かなければならず、用途別の個別文書として扱わなければならない。metrics 専用の index 文書を作ってはならない。

## Human-View ルール

### 共通原則

- `docs/human-view/` 配下の文書は、人間の指示容易性と俯瞰性を高めるための翻訳資料として扱わなければならない。正本として扱ってはならない。
- 人間が最初に読む資料であることを前提に、正本より読みやすく簡略化してよいが、簡略化によって正本に存在しない判断基準を追加してはならない。
- 機能仕様、設計方針、命名方針、GUI 呼称ルールのように判断へ影響する内容は、`human-view` にだけ置かず、対応する正本文書へ先に反映する。
- `human-view` の各文書冒頭では、どの正本文書の翻訳かを明示し、読者が必要に応じて正本へ戻れる状態を保つ。
- `human-view` は「人間が指示しやすい粒度」を優先し、実装上の private helper、補助 DTO、内部 wrapper、細かな状態型までは原則として露出しない。

### gui.md

- [gui.md](../human-view/gui.md) は、人間が画面変更を依頼する時の第一入口として維持しなければならず、画面名、画面遷移、主な GUI パーツ、操作と遷移、長押しメニュー、指示用呼称を記述しなければならない。これ以外の正本判断をここへ閉じ込めてはならない。
- `画面遷移` では、全ノードが画面であることを前提に、図中ラベルの `〜画面` は省略して短く保つ。
- `画面一覧` の各画面は、`画面A`、`画面B` のようなアルファベット識別子を持ち、見出し・目次・指示用短縮名で一貫して使う。
- `画面一覧` の `画面名` は、指示に使う正式名として `〜画面` を含めた表記を維持する。
- 各画面の章構成は、少なくとも `画面名`、`実装`、必要なら `画面識別`、`主な GUI パーツ`、`操作と遷移`、必要なら `長押しメニュー` を持つ。
- `主な GUI パーツ` は、実装上の全 subview を列挙するのではなく、人間が変更指示に使う部品だけを表に載せる。
- 同じ役割の GUI パーツは画面をまたいでも同じ呼び名を使い、1 画面内で重複しない場合は短い呼び名を優先する。
- `gui.md` にしか存在しないパーツ呼称ルールや識別子運用を見つけた場合は、必要に応じて [specs-product.md](../specs/specs-product.md) または本書へ先に反映する。

### design-overview.md

- [design-overview.md](../human-view/design-overview.md) は、人間が機能境界と依存方向を短時間で把握するための UML 風俯瞰資料として扱わなければならない。正本の代用として扱ってはならない。
- 章構成は、少なくとも `レイヤ構成`、`主要クラス図`、`主要シーケンス`、`依存関係メモ` を持つ。
- `主要クラス図` は、正本の詳細設計をそのまま展開せず、機能 View、主要 coordinator / service / store、指示に使う共通 UI 部品だけを載せる。
- レスポンシブな表現差分は個別実装名を列挙しすぎず、親となる機能 View の枠内へ、`[Variants Host]` のような「表現差分を束ねる親」であることが分かる注記を入れて表す。
- 機能共通の表示核だけを見せたい場合は、`[Shared UI Core]` のような注記を使って明示し、遷移や選択などの操作差分 wrapper は図から省略してよい。
- `主要シーケンス` には、機能導線の理解に必要な主要経路だけを記述しなければならず、分岐や補助処理を過剰に詰め込んではならない。
- 図や注記の簡略化に使うルールは、`design-overview.md` にだけ閉じず、本書のような正本へ規定してから適用する。

## Markdown ルール

- Markdown に `mermaid` または `plantuml` を含める場合は、コミット前にローカル環境で構文エラーなく描画できることを確認してから反映する。
- `mermaid` を含める Markdown を変更した場合は、外部 API ではなく [check-mermaid.mjs](../scripts/check-mermaid.mjs) によるローカル検証を使う。
- Markdown のファイルリンクは、表示テキストをファイル名のみとし、表示上にパスを含めない。
- Markdown のリンク先自体は、各文書位置から実体ファイルへ辿れる相対パスで維持する。

## 履歴文書の運用

### 共通ルール

- 履歴を継続的に蓄積する文書は `history/chat-log.md`、`history/metrics-log.md`、`history/decisions-log.md` に限定しなければならず、当日作業中の追記先は対応する `*-latest.md` にしなければならない。別名の正本を増やしてはならない。
- 当日中の更新は原則として対応する `*-latest.md` に対して行い、履歴文書 `*-log.md` へその場で追記しない。
- 日付が変わった後で最初の開発シーケンスを始める時は、前日までの `*-latest.md` の内容を対応する `*-log.md` の先頭へ挿入し、当日分がすでに `*-latest.md` に存在する場合はその当日分だけを残して運用を継続する。
- `*-latest.md` はトークン消費を抑えるための当日分バッファとして扱わなければならず、履歴の正本は `*-log.md` にしなければならない。役割を逆転させてはならない。
- `*-log.md` は原則として LLM の通常読込対象にしてはならず、当日作業では `*-latest.md` を優先して扱わなければならない。
- `*-latest.md` から `*-log.md` への移行は、巨大な log を人手や LLM が直接結合せず、[scripts/rotate-history](../../scripts/rotate-history) のような対応する local skill / script を使って行う。
- `*-log.md` はクォータ消費が大きいため、通常の開発では LLM が本文を読んで原因調査や結合作業をしてはならず、必要な場合はユーザーが明示的に許可した最小範囲だけを読む。
- [chat-log.md](../history/chat-log.md)、[chat-latest.md](../history/chat-latest.md)、[metrics-log.md](../history/metrics-log.md)、[metrics-latest.md](../history/metrics-latest.md)、[decisions-log.md](../history/decisions-log.md)、[decisions-latest.md](../history/decisions-latest.md) は、先頭行を日付見出しから始め、先頭の説明文を置かない。
- 新しい日付見出しを追加する場合は、直前の日付見出しとの間に 1 行だけ空行を入れる。
- 見出しと直後の列挙の間には空行を入れない。

### history/chat-log.md / history/chat-latest.md

- [chat-latest.md](../history/chat-latest.md) は当日作業中の追記先として扱わなければならず、ユーザー発言が追加されたら都度反映しなければならない。
- [chat-log.md](../history/chat-log.md) は日次ローテーション後の履歴保持先として扱わなければならない。
- 同じ日付の中では、新しい発言ほど上、古い発言ほど下になるように追記する。
- 各発言には、`(LLM所要時間: 約12分)` の形式で所要時間を併記する。
- 所要時間の測定手順、記録基準、例外条件は [rules-process.md](./rules-process.md) の開発フローに従う。
- 基本的にはユーザー発言をそのまま記録する。
- ただし、明らかな変換ミスや誤字は、意味を変えない範囲で修正してよい。
- `chatlog.md` や `Chatlog.md` のような旧名や揺れを受け取った場合でも、現在の運用名である `history/chat-log.md` または `history/chat-latest.md` に読み替えて扱わなければならない。旧名のまま新規運用してはならない。
- 個人情報、API キー、トークン、絶対パスやホームディレクトリを含む文字列は、記録前に除去またはマスクする。
- [chat-log.md](../history/chat-log.md) は、LLM や Codex をどのように使って構築したかを後から振り返るための履歴として扱わなければならない。

### history/metrics-log.md / history/metrics-latest.md

- 計測値の当日更新は [metrics-latest.md](../history/metrics-latest.md) に対して行う。
- [metrics-log.md](../history/metrics-log.md) は日次ローテーション後の履歴保持先として扱わなければならない。
- 同じ日付見出しの中では、新しいエントリほど上、古いエントリほど下になるように追加する。
- 1 つの metrics ブロックと次の見出しの間には、1 行だけ空行を入れる。
- 各エントリは metrics を実測したコミット単位で追加し、計測値と再試行回数を一貫した形式で残す。
- `scripts/collect-metrics.sh` の既定出力先は [metrics-latest.md](../history/metrics-latest.md) にしなければならず、日中の追記が履歴ファイルへ直接流れ込まないようにしなければならない。
- 最終の全体検証では `scripts/collect-metrics.sh` を正本として扱わなければならず、同スクリプトが [metrics-test.md](../metrics/metrics-test.md) も同時更新する前提で運用しなければならない。別の手段を正本として扱ってはならない。
- `scripts/collect-test-metrics.sh` は、修正ループ中の logic 1 件 / UI 1 件のような限定確認や、部分集合の計測確認にだけ使う。
- [metrics-log.md](../history/metrics-log.md) は、検証コストや起動性能の履歴を後から参照するための正本として扱わなければならない。

### history/decisions-log.md / history/decisions-latest.md

- 意識的な設計変更が行われた際は、当日分の [decisions-latest.md](../history/decisions-latest.md) を更新する。
- 日付見出しの下へ、新しい決定ほど上に追加する。
- 各決定は箇条書きで記述し、その直下の 1 段下げた行に理由を書く。
- [decisions-log.md](../history/decisions-log.md) は日次ローテーション後の履歴保持先として扱わなければならない。
- [decisions-log.md](../history/decisions-log.md) は、なぜその設計判断を選んだかを後から振り返るための履歴として扱わなければならない。
