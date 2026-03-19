# HelloWorld Document Operations

この文書は、HelloWorld の文書運用ルールを定める正本である。文書構成、更新判断、履歴管理、Markdown 記述の共通ルールを扱う。

文書群全体の役割分担は [document-roles.md](./document-roles.md) を参照する。

## 共通原則

- `rules.md` は追記メモ置き場として扱わず、章ごとの役割が読んで辿れる構造を維持する。
- `rules.md` を更新する時は、関連する既存節へ統合し、重複、矛盾、末尾だけの場当たり的な追記を避ける。
- 実装と文書にずれが出た場合は、どちらが正しいか確認してから揃える。
- 一時的な事情や現状の実装詳細を、恒久ルールとして `rules.md` に固定してはならない。
- 通常のプロジェクト文書ファイル名は `lowercase-kebab-case.md` または `lowercase.md` に統一する。
- `README.md` や `CONTRIBUTING.md` のような広く定着した慣例名だけは例外として大文字を許容する。
- `docs/human-view/` 配下は、人間向けの翻訳資料と図表資料を置く領域とし、配置だけで正本と区別できる状態を維持する。

## 変更時の更新対象

- 横展開可能な開発原則、責務分離の一般論、テスト戦略の一般論、評価指標を変更したら [principles.md](./principles.md) を見直す。
- 機能を変更したら [spec.md](./spec.md) を見直す。
- 採用アーキテクチャ、責務境界、データフロー、テスト方針を変更したら [architecture.md](./architecture.md) を見直す。
- ファイル単位や型単位の責務、詳細設計、テストの配置を変更したら [design.md](./design.md) を見直す。
- GUI の見た目、パーツ名、画面遷移、画面ごとの指示に使う呼び名を変更したら [gui.md](./human-view/gui.md) を見直す。
- 人間向けの設計図や依存関係の見え方が変わる変更では [design-overview.md](./human-view/design-overview.md) を見直す。
- 上位方針や変更判断の基準を変更したら [rules.md](./rules.md) を見直す。
- 検証コストや性能観測の更新では [metrics-latest.md](./history/metrics-latest.md) を更新し、日次履歴は [metrics-log.md](./history/metrics-log.md) で保持する。

## 人間向け参照資料のルール

- [gui.md](./human-view/gui.md) の `画面遷移` では、全ノードが画面であることを前提に、図中ラベルの `〜画面` は省略して短く保つ。
- [gui.md](./human-view/gui.md) の `画面一覧` の `画面名` は、指示に使う正式名として `〜画面` を含めた表記を維持する。
- [gui.md](./human-view/gui.md) の `画面一覧` には、各画面見出しへ飛べる目次を置き、各画面に `画面A`、`画面B` のようなアルファベット識別子を付与して短い指示名としても使えるようにする。
- [design-overview.md](./human-view/design-overview.md) の Adaptive UI 表現では、`CompactView` / `RegularView` の個別クラスを図へ並べず、親となる機能 View クラスの枠内へ改行付きの注記を入れて、表現差分を内包する設計であることを示す。
- `docs/human-view/` 配下の資料は、人間の参照性を優先して複雑さを抑えてよいが、簡略化によって正本との関係が読めなくならないよう、どの正本の翻訳かを明示したまま運用する。

## Markdown ルール

- Markdown に `mermaid` または `plantuml` を含める場合は、コミット前に構文エラーなく描画できることを確認してから反映する。
- Markdown のファイルリンクは、表示テキストをファイル名のみとし、表示上にパスを含めない。
- Markdown のリンク先自体は、各文書位置から実体ファイルへ辿れる相対パスで維持する。

## 履歴文書の共通ルール

- 履歴を継続的に蓄積する文書は `history/chat-log.md`、`history/metrics-log.md`、`history/decisions-log.md` とし、当日作業中の追記先は対応する `*-latest.md` とする。
- 当日中の更新は原則として対応する `*-latest.md` に対して行い、履歴文書 `*-log.md` へその場で追記しない。
- 日付が変わった後で最初に対象文書を更新する時は、前日までの `*-latest.md` の内容を対応する `*-log.md` の先頭へ挿入してから `*-latest.md` を空にし、その当日分の運用を開始する。
- `*-latest.md` はトークン消費を抑えるための当日分バッファとして扱い、履歴の正本は `*-log.md` とする。
- [chat-log.md](./history/chat-log.md)、[chat-latest.md](./history/chat-latest.md)、[metrics-log.md](./history/metrics-log.md)、[metrics-latest.md](./history/metrics-latest.md)、[decisions-log.md](./history/decisions-log.md)、[decisions-latest.md](./history/decisions-latest.md) は、先頭行を日付見出しから始め、先頭の説明文を置かない。
- 新しい日付見出しを追加する場合は、直前の日付見出しとの間に 1 行だけ空行を入れる。
- 見出しと直後の列挙の間には空行を入れない。

## history/chat-log.md / history/chat-latest.md

### 基本運用

- [chat-latest.md](./history/chat-latest.md) は当日作業中の追記先とし、ユーザー発言が追加されたら都度反映する。
- [chat-log.md](./history/chat-log.md) は日次ローテーション後の履歴保持先とする。
- 同じ日付の中では、新しい発言ほど上、古い発言ほど下になるように追記する。

### 記録内容

- 各発言には、`ユーザー指示のタイムスタンプ` から `コミット直前またはドキュメント更新時のタイムスタンプ` までの経過時間を `（直前のLLM所要時間: 約11m52s）` のような形式で併記する。
- 所要時間は、画面表示上の印象値ではなく、記録対象のユーザー発話時刻と文書更新時刻の差分を基準に算出する。
- 所要時間は厳密一致を要求しないが、現在の作業規模と明らかにずれた粒度や古い値を流用してはならない。
- 基本的にはユーザー発言をそのまま記録する。
- ただし、明らかな変換ミスや誤字は、意味を変えない範囲で修正してよい。
- `chatlog.md` や `Chatlog.md` のような旧名や揺れを受け取った場合でも、現在の運用名である `history/chat-log.md` または `history/chat-latest.md` に読み替えて扱う。

### 除外と保護

- 個人情報、API キー、トークン、絶対パスやホームディレクトリを含む文字列は、記録前に除去またはマスクする。
- [chat-log.md](./history/chat-log.md) は、LLM や Codex をどのように使って構築したかを後から振り返るための履歴として扱う。

## history/metrics-log.md / history/metrics-latest.md

- 計測値の当日更新は [metrics-latest.md](./history/metrics-latest.md) に対して行う。
- [metrics-log.md](./history/metrics-log.md) は日次ローテーション後の履歴保持先とする。
- 同じ日付見出しの中では、新しいエントリほど上、古いエントリほど下になるように追加する。
- 1 つの metrics ブロックと次の見出しの間には、1 行だけ空行を入れる。
- 各エントリは metrics を実測したコミット単位で追加し、計測値と再試行回数を一貫した形式で残す。
- `scripts/collect_metrics.sh` の既定出力先は [metrics-latest.md](./history/metrics-latest.md) とし、日中の追記が履歴ファイルへ直接流れ込まないようにする。
- 最終の全体検証では `scripts/collect_metrics.sh` を正本とし、同スクリプトが [test-metrics.md](./test-metrics.md) も同時更新する前提で運用する。
- `scripts/collect_test_metrics.sh` は、修正ループ中の logic 1 件 / UI 1 件のような限定確認や、部分集合の計測確認にだけ使う。
- [metrics-log.md](./history/metrics-log.md) は、検証コストや起動性能の履歴を後から参照するための正本として扱う。

## history/decisions-log.md / history/decisions-latest.md

- 意識的な設計変更が行われた際は、当日分の [decisions-latest.md](./history/decisions-latest.md) を更新する。
- 日付見出しの下へ、新しい決定ほど上に追加する。
- 各決定は箇条書きで記述し、その直下の 1 段下げた行に理由を書く。
- [decisions-log.md](./history/decisions-log.md) は日次ローテーション後の履歴保持先とする。
- [decisions-log.md](./history/decisions-log.md) は、なぜその設計判断を選んだかを後から振り返るための履歴として扱う。
