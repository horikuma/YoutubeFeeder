# YoutubeFeeder Document Rules

この文書は、YoutubeFeeder の文書群に関する上位ルールを定める正本である。ここでは、文書体系、文書の切り分け基準、参照資料の位置付け、文書運用、履歴管理、Markdown 記述の共通ルールを扱う。

## 文書体系

### 正本

- [rules.md](./rules.md)
  - YoutubeFeeder の最上位方針として、意思決定ルール、優先順位、開発プロセス、開発原則を記述する。
- [spec.md](./spec.md)
  - ユーザー向け機能、画面遷移、操作、表示要件を記述する。
- [architecture.md](./architecture.md)
  - 採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を記述する。
- [design.md](./design.md)
  - ファイル単位、型単位、テスト単位の責務や構成など、詳細設計を記述する。
- [rules-design.md](./rules-design.md)
  - 画面設計、余白、文字組み、色の使い方など、`iPhone` / `iPad` 向けの視覚設計ルールを記述する。

### 参照資料

- [gui.md](./human-view/gui.md)
  - 画面名、GUI パーツ名、画面遷移、指示に使う呼び名を、人間向けの参照資料として整理して記述する。
- [design-overview.md](./human-view/design-overview.md)
  - クラス図やレイヤ図などの UML 風設計資料を、人間向けの参照資料として整理して記述する。
- [development-environment.md](./development-environment.md)
  - ローカル開発に必要なツール、版固定、セットアップ手順、再現性を守る運用を記述する。
- `docs/report/` 配下
  - 個別の障害調査、性能探索、検証ログの整理結果を、将来の再調査に使う参照資料として記述する。

## 文書の切り分け基準

- `rules.md` へ実装詳細や画面単位の仕様を集約してはならない。
- クラス名や型名が出る内容は、原則として `design.md` へ置く。
- 画面の見た目や視覚的一貫性の基準は、仕様や詳細設計へ散らさず `rules-design.md` へ置く。
- ユーザー操作や画面導線に依存する内容は、原則として `spec.md` へ置く。
- 変更しても全体構造が変わらない運用詳細は、`rules.md` または `spec.md` へ置く。
- レイヤ構造、依存方向、データフローの形、責務の原則を規定する内容は、`architecture.md` へ置く。
- 文書の内容が詳細化しすぎた場合は、上位方針を残して詳細を `spec.md`、`architecture.md`、`design.md` へ移す。

## 人間向け参照資料の位置付け

- `docs/human-view/` 配下の文書は正本ではないため、仕様や責務の最終判断根拠にしてはならない。
- `docs/human-view/` 配下の文書は、人間の開発者にとっての第一入口として、関連する正本変更と同じ変更セットで必ず同期する。
- `docs/report/` 配下の文書は正本ではないため、個別調査の観測結果や仮説、比較結果を残す用途に限定し、方針や仕様の最終判断根拠にしてはならない。
- `docs/human-view/` 配下にしか存在しない設計、仕様、方針、呼称ルールを放置してはならない。判断基準として意味を持つ内容を見つけた場合は、対応する正本文書へ先にサルベージしてから `human-view` 側を整える。

## 文書運用

### 開発着手時の文書運用

- 新規開発セッションを開始する時は、まず [rules.md](./rules.md) と [rules-document.md](./rules-document.md) を読み直して現在の運用を確認する。
- 日付が変わっている場合は、`history/chat-latest.md`、`history/decisions-latest.md`、`history/metrics-latest.md` の前日分を対応する `*-log.md` の先頭へ移してから、当日分の `*-latest.md` を新しい日付見出しで開始する。
- 新規開発セッション開始時の準備を文書更新として実施した場合は、その開始指示を `history/chat-latest.md` に反映してから当日の開発へ入る。

### 共通原則

- `rules.md` は追記メモ置き場として扱わず、章ごとの役割が読んで辿れる構造を維持する。
- `rules.md` を更新する時は、関連する既存節へ統合し、重複、矛盾、末尾だけの場当たり的な追記を避ける。
- 実装と文書にずれが出た場合は、どちらが正しいか確認してから揃える。
- 一時的な事情や現状の実装詳細を、恒久ルールとして `rules.md` に固定してはならない。
- 通常のプロジェクト文書ファイル名は `lowercase-kebab-case.md` または `lowercase.md` に統一する。
- `README.md` や `CONTRIBUTING.md` のような広く定着した慣例名だけは例外として大文字を許容する。
- `docs/human-view/` 配下は、人間向けの翻訳資料と図表資料を置く領域とし、配置だけで正本と区別できる状態を維持する。
- `docs/report/` 配下は、障害調査や性能探索の報告書を置く領域とし、日々の履歴バッファとは混ぜず、1 件ごとに独立した Markdown として残す。

### 変更時の更新対象

- 機能を変更したら [spec.md](./spec.md) を見直す。
- 採用アーキテクチャ、責務境界、データフロー、テスト方針を変更したら [architecture.md](./architecture.md) を見直す。
- ファイル単位や型単位の責務、詳細設計、テストの配置を変更したら [design.md](./design.md) を見直す。
- GUI の見た目、パーツ名、画面遷移、画面ごとの指示に使う呼び名を変更したら [gui.md](./human-view/gui.md) を見直す。
- 人間向けの設計図や依存関係の見え方が変わる変更では [design-overview.md](./human-view/design-overview.md) を見直す。
- 上位方針や変更判断の基準を変更したら [rules.md](./rules.md) を見直す。
- 余白、文字組み、色の使い方、視覚的一貫性の基準を変更したら [rules-design.md](./rules-design.md) を見直す。
- 検証コストや性能観測の更新では [metrics-latest.md](./history/metrics-latest.md) を更新し、日次履歴は [metrics-log.md](./history/metrics-log.md) で保持する。

## Human-View ルール

### 共通原則

- `docs/human-view/` 配下の文書は、人間の指示容易性と俯瞰性を高めるための翻訳資料として扱う。
- 人間が最初に読む資料であることを前提に、正本より読みやすく簡略化してよいが、簡略化によって正本に存在しない判断基準を追加してはならない。
- 機能仕様、設計方針、命名方針、GUI 呼称ルールのように判断へ影響する内容は、`human-view` にだけ置かず、対応する正本文書へ先に反映する。
- `human-view` の各文書冒頭では、どの正本文書の翻訳かを明示し、読者が必要に応じて正本へ戻れる状態を保つ。
- `human-view` は「人間が指示しやすい粒度」を優先し、実装上の private helper、補助 DTO、内部 wrapper、細かな状態型までは原則として露出しない。

### gui.md

- [gui.md](./human-view/gui.md) は、人間が画面変更を依頼する時の第一入口として、画面名、画面遷移、主な GUI パーツ、操作と遷移、長押しメニュー、指示用呼称を記述する。
- `画面遷移` では、全ノードが画面であることを前提に、図中ラベルの `〜画面` は省略して短く保つ。
- `画面一覧` の各画面は、`画面A`、`画面B` のようなアルファベット識別子を持ち、見出し・目次・指示用短縮名で一貫して使う。
- `画面一覧` の `画面名` は、指示に使う正式名として `〜画面` を含めた表記を維持する。
- 各画面の章構成は、少なくとも `画面名`、`実装`、必要なら `画面識別`、`主な GUI パーツ`、`操作と遷移`、必要なら `長押しメニュー` を持つ。
- `主な GUI パーツ` は、実装上の全 subview を列挙するのではなく、人間が変更指示に使う部品だけを表に載せる。
- 同じ役割の GUI パーツは画面をまたいでも同じ呼び名を使い、1 画面内で重複しない場合は短い呼び名を優先する。
- `gui.md` にしか存在しないパーツ呼称ルールや識別子運用を見つけた場合は、必要に応じて `spec.md` または本書へ先に反映する。

### design-overview.md

- [design-overview.md](./human-view/design-overview.md) は、人間が機能境界と依存方向を短時間で把握するための UML 風俯瞰資料として扱う。
- 章構成は、少なくとも `レイヤ構成`、`主要クラス図`、`主要シーケンス`、`依存関係メモ` を持つ。
- `主要クラス図` は、正本の詳細設計をそのまま展開せず、機能 View、主要 coordinator / service / store、指示に使う共通 UI 部品だけを載せる。
- Adaptive UI の細かな実装差分は `CompactView` / `RegularView` / `SplitDetailView` の個別クラスとして列挙せず、親となる機能 View の枠内注記で表す。
- 機能共通の表示核だけを見せたい場合は、`[Shared UI Core]` のような注記を使って明示し、遷移や選択などの操作差分 wrapper は図から省略してよい。
- `主要シーケンス` は、機能導線の理解に必要な主要経路だけを扱い、分岐や補助処理を過剰に詰め込まない。
- 図や注記の簡略化に使うルールは、`design-overview.md` にだけ閉じず、本書のような正本へ規定してから適用する。

### Markdown ルール

- Markdown に `mermaid` または `plantuml` を含める場合は、コミット前にローカル環境で構文エラーなく描画できることを確認してから反映する。
- `mermaid` を含める Markdown を変更した場合は、外部 API ではなく [check_mermaid.mjs](../scripts/check_mermaid.mjs) によるローカル検証を使う。
- Markdown のファイルリンクは、表示テキストをファイル名のみとし、表示上にパスを含めない。
- Markdown のリンク先自体は、各文書位置から実体ファイルへ辿れる相対パスで維持する。

## 履歴文書の運用

### 共通ルール

- 履歴を継続的に蓄積する文書は `history/chat-log.md`、`history/metrics-log.md`、`history/decisions-log.md` とし、当日作業中の追記先は対応する `*-latest.md` とする。
- 当日中の更新は原則として対応する `*-latest.md` に対して行い、履歴文書 `*-log.md` へその場で追記しない。
- 日付が変わった後で最初に対象文書を更新する時は、前日までの `*-latest.md` の内容を対応する `*-log.md` の先頭へ挿入してから `*-latest.md` を空にし、その当日分の運用を開始する。
- `*-latest.md` はトークン消費を抑えるための当日分バッファとして扱い、履歴の正本は `*-log.md` とする。
- [chat-log.md](./history/chat-log.md)、[chat-latest.md](./history/chat-latest.md)、[metrics-log.md](./history/metrics-log.md)、[metrics-latest.md](./history/metrics-latest.md)、[decisions-log.md](./history/decisions-log.md)、[decisions-latest.md](./history/decisions-latest.md) は、先頭行を日付見出しから始め、先頭の説明文を置かない。
- 新しい日付見出しを追加する場合は、直前の日付見出しとの間に 1 行だけ空行を入れる。
- 見出しと直後の列挙の間には空行を入れない。

### history/chat-log.md / history/chat-latest.md

#### 基本運用

- [chat-latest.md](./history/chat-latest.md) は当日作業中の追記先とし、ユーザー発言が追加されたら都度反映する。
- [chat-log.md](./history/chat-log.md) は日次ローテーション後の履歴保持先とする。
- 同じ日付の中では、新しい発言ほど上、古い発言ほど下になるように追記する。

#### 記録内容

- 各発言には、`ユーザー指示のタイムスタンプ` から `コミット直前またはドキュメント更新時のタイムスタンプ` までの経過時間を `(LLM所要時間: 約11m52s)` のような形式で併記する。
- 所要時間は、画面表示上の印象値ではなく、記録対象のユーザー発話時刻と文書更新時刻の差分を基準に算出する。
- 所要時間は厳密一致を要求しないが、現在の作業規模と明らかにずれた粒度や古い値を流用してはならない。
- 基本的にはユーザー発言をそのまま記録する。
- ただし、明らかな変換ミスや誤字は、意味を変えない範囲で修正してよい。
- `chatlog.md` や `Chatlog.md` のような旧名や揺れを受け取った場合でも、現在の運用名である `history/chat-log.md` または `history/chat-latest.md` に読み替えて扱う。

#### 除外と保護

- 個人情報、API キー、トークン、絶対パスやホームディレクトリを含む文字列は、記録前に除去またはマスクする。
- [chat-log.md](./history/chat-log.md) は、LLM や Codex をどのように使って構築したかを後から振り返るための履歴として扱う。

### history/metrics-log.md / history/metrics-latest.md

- 計測値の当日更新は [metrics-latest.md](./history/metrics-latest.md) に対して行う。
- [metrics-log.md](./history/metrics-log.md) は日次ローテーション後の履歴保持先とする。
- 同じ日付見出しの中では、新しいエントリほど上、古いエントリほど下になるように追加する。
- 1 つの metrics ブロックと次の見出しの間には、1 行だけ空行を入れる。
- 各エントリは metrics を実測したコミット単位で追加し、計測値と再試行回数を一貫した形式で残す。
- `scripts/collect_metrics.sh` の既定出力先は [metrics-latest.md](./history/metrics-latest.md) とし、日中の追記が履歴ファイルへ直接流れ込まないようにする。
- 最終の全体検証では `scripts/collect_metrics.sh` を正本とし、同スクリプトが [test-metrics.md](./test-metrics.md) も同時更新する前提で運用する。
- `scripts/collect_test_metrics.sh` は、修正ループ中の logic 1 件 / UI 1 件のような限定確認や、部分集合の計測確認にだけ使う。
- [metrics-log.md](./history/metrics-log.md) は、検証コストや起動性能の履歴を後から参照するための正本として扱う。

### history/decisions-log.md / history/decisions-latest.md

- 意識的な設計変更が行われた際は、当日分の [decisions-latest.md](./history/decisions-latest.md) を更新する。
- 日付見出しの下へ、新しい決定ほど上に追加する。
- 各決定は箇条書きで記述し、その直下の 1 段下げた行に理由を書く。
- [decisions-log.md](./history/decisions-log.md) は日次ローテーション後の履歴保持先とする。
- [decisions-log.md](./history/decisions-log.md) は、なぜその設計判断を選んだかを後から振り返るための履歴として扱う。
