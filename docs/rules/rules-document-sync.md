# Document Sync Rules

この文書は、文書同期タスクを単体で定義する完結文書である。

## 文書同期

- 文書同期とは、`docs/` 配下のうち `docs/rules/` を除く文書について、変更内容に応じた必要更新を反映し、正本、参照資料、履歴文書の整合を保つタスクである。

## 実施内容

- 文書を更新する時は、変更対象が属する章の規則だけを使って更新先を決めなければならない。
- `docs/rules/` 配下の文書は、このタスクの更新対象に含めてはならない。
- 正本、human-view、履歴文書、参照資料の役割を混在させてはならない。

## 配置判断

### `docs/specs/`

- ユーザー向け機能、画面遷移、操作、表示要件を更新する場合は `docs/specs/specs-product.md` を更新しなければならない。
- レイヤ構造、依存方向、データフロー、責務境界を更新する場合は `docs/specs/specs-architecture.md` を更新しなければならない。
- ファイル単位、型単位、テスト単位の責務や構成などの詳細設計を更新する場合は `docs/specs/specs-design.md` を更新しなければならない。
- ローカル開発環境、版固定、セットアップ、再現性を更新する場合は `docs/specs/specs-environment.md` を更新しなければならない。

### `docs/human-view/`

- `docs/human-view/` 配下の文書は、人間が短時間で把握するための参照資料としてだけ扱わなければならない。
- `docs/human-view/gui.md` は、人間が画面名、GUI パーツ名、画面遷移、指示に使う呼び名を把握する必要がある場合にだけ更新しなければならない。
- `docs/human-view/design-overview.md` は、人間が機能境界と依存方向を短時間で把握する UML 風俯瞰資料としてだけ更新しなければならない。
- `docs/human-view/` 配下の文書を正本の代用として扱ってはならない。

### `docs/history/`

- 履歴を継続的に蓄積する文書は `docs/history/chat-log.md`、`docs/history/metrics-log.md`、`docs/history/decisions-log.md` に限定しなければならない。
- 当日作業中の追記先は対応する `*-latest.md` に限定しなければならない。
- 当日中の更新は `*-latest.md` に対して行い、`*-log.md` へ直接追記してはならない。
- `*-latest.md` から `*-log.md` への移行は `scripts/rotate-history` を使って行わなければならない。
- `*-log.md` は通常の LLM 読込対象にしてはならない。
- `docs/history/chat-latest.md` と `docs/history/chat-log.md` では、同じ日付の中で新しい発言を上、古い発言を下に記録しなければならない。
- `docs/history/chat-latest.md` と `docs/history/chat-log.md` の各発言には、`(LLM所要時間: 約12分)` 形式の所要時間を併記しなければならない。
- `docs/history/chat-latest.md` と `docs/history/chat-log.md` に記録する文字列に個人情報、APIキー、トークン、絶対パス、ホームディレクトリが含まれる場合は、記録前に除去またはマスクしなければならない。
- `docs/history/metrics-latest.md` では、同じ日付見出しの中で新しいエントリを上、古いエントリを下に追加しなければならない。
- `scripts/collect-metrics` の既定出力先は `docs/history/metrics-latest.md` にしなければならない。
- 限定確認や部分集合の計測確認には `scripts/collect-test-metrics` を使わなければならない。
- 意識的な設計変更が行われた場合は `docs/history/decisions-latest.md` を更新し、同じ日付見出しの中で新しい決定を上、古い決定を下に追加しなければならない。
- `docs/history/decisions-latest.md` と `docs/history/decisions-log.md` の各決定は箇条書きで記述し、その直下の1段下げた行に理由を書かなければならない。
- `docs/history/` 配下の `*-log.md` と `*-latest.md` は、先頭行を日付見出しから始め、先頭の説明文を置いてはならない。
- 新しい日付見出しを追加する場合は、直前の日付見出しとの間に1行だけ空行を入れなければならない。
- 見出しと直後の列挙の間に空行を入れてはならない。

### `docs/metrics/`

- `docs/metrics/metrics-src.md` は、ソース総行数、正本文書行数、health barometer の観測結果、ファイル別行数概観を参照資料として残す場合にだけ更新しなければならない。
- `docs/metrics/metrics-test.md` は、テストごとの所要時間と分類を参照資料として残す場合にだけ更新しなければならない。
- `docs/metrics/` 配下へ正本ルールを書いてはならない。

### `docs/report/`

- `docs/report/` 配下は、個別の障害調査、性能探索、検証ログの整理結果を将来の再調査用参照資料として残す場合にだけ使わなければならない。
- `docs/report/` 配下を方針や仕様の正本として扱ってはならない。

## Markdown

- Markdown に `mermaid` または `plantuml` を含める場合は、コミット前にローカル環境で構文エラーなく描画できることを確認してから反映しなければならない。
- `mermaid` を含める Markdown を変更した場合は、`scripts/check-mermaid.mjs` によるローカル検証を使わなければならない。
- Markdown のファイルリンクは、表示テキストをファイル名のみにし、表示上にパスを含めてはならない。
- Markdown のリンク先は、各文書位置から実体ファイルへ辿れる相対パスで維持しなければならない。

## 完了条件

- 更新内容に応じた `docs/` 配下の必要文書が反映されていること。
- 正本、human-view、履歴文書、参照資料の役割が混在していないこと。
- `docs/rules/` を除く `docs/` 配下について、配置判断がこの文書だけで説明できること。

## 禁止事項

- `docs/rules/` 配下の文書を、このタスクの更新対象へ含めてはならない。
- 正本に書くべき内容を `docs/human-view/`、`docs/metrics/`、`docs/report/` へ書いてはならない。
- 当日更新を `*-log.md` へ直接追記してはならない。
- `*-latest.md` から `*-log.md` への移行を `scripts/rotate-history` 以外で行ってはならない。
- `docs/history/` 配下の `*-log.md` を通常の LLM 読込対象にしてはならない。
