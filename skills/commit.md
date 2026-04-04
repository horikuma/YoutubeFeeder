# Commit Skill

この文書は、コミットという 1 つのタスクだけを定義する。

## コミット

- コミットとは、その時点で完了条件を満たした変更セットを 1 単位として確定し、対応する `docs/history/*-latest.md` の更新を含む履歴と対応関係が追跡できる状態へ整えるタスクである。
- このタスクでは、コミット対象の確定、対応する `docs/history/*-latest.md` の更新、Git の staging、commit message、完了確認までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- コミット対象は、その時点で完了条件を満たした変更セット全体にしなければならない。
- 未完了の別タスクの差分、関連のない差分、後続タスクで使う途中差分を同じコミットへ混在させてはならない。
- Issue に実施タスクの ToDo がある場合は、ToDo を 1 つ完了するごとに対応する変更をコミットし、変更とタスクの対応関係が履歴から追える状態を保たなければならない。
- ToDo が複数ある場合でも、複数ステップを 1 つのコミットへまとめてはならない。
- 意味のある変更がまとまるたびにコミットし、途中経過が再現できる粒度で履歴を残さなければならない。
- コミット前には、変更セットに応じて必要な検証と、対応する `docs/history/*-latest.md` 更新が完了していることを確認しなければならない。
- ソースコード変更を含む場合は、ユーザーから明示的に停止されていない限り、必要な検証、対応する `docs/history/*-latest.md` 更新、計測記録を終えてからコミットしなければならない。
- ドキュメントだけを変更した場合も、ユーザーから明示的に停止されていない限り、その変更セットに必要な `docs/history/*-latest.md` 更新を終えてからコミットしなければならない。
- 細かいコミットが積み上がること自体は許容し、未確定の複数シーケンスを 1 つの大きなコミットへまとめることより、各変更セットをコミットで確定することを優先しなければならない。
- コミットメッセージは日本語で記述しなければならない。
- Git の staging は `git add <path>...` で行わなければならない。
- Git の commit は `git commit -m '<message>'` で行わなければならない。
- `<message>` は、日本語で記述した commit message でなければならない。
- Issue 駆動で進めたタスクは、Issue、ブランチ、コミット、Pull Request の対応関係が追跡できる状態を壊してはならない。

## `docs/history/`

### 目的

- `docs/history/chat-log.md`、`docs/history/metrics-log.md`、`docs/history/decisions-log.md` は、継続履歴の正本として扱わなければならない。
- 対応する `*-latest.md` は、当日分だけを保持する作業中バッファとして扱わなければならない。

### 制約

- 追記は `*-latest.md` に対してだけ行わなければならない。
- `docs/history/*-latest.md` の更新は、LLM の本文読込みや直接編集で行ってはならず、対応する `scripts/history-chat-append`、`scripts/history-decision-append`、`scripts/history-metrics-append` を通して行わなければならない。
- `*-log.md` は追記対象にも LLM 読込対象にもしてはならない。
- `*-latest.md` へ新しい項目を追加する場合は、対応する `scripts/history-*-append` が対象の日付見出し行の次行へ挿入しなければならない。
- `*-latest.md` は、先頭行を日付見出しから始め、先頭の説明文を置いてはならない。
- 見出しと直後の列挙の間に空行を入れてはならない。
- 箇条書きの項目同士の間に空行を入れてはならない。
- 記録する文字列に個人情報、APIキー、トークン、絶対パス、ホームディレクトリが含まれる場合は、除去しなければならない。

### ファイル固有規則

#### `docs/history/chat-latest.md`

- ユーザー指示は、次の例外を除き、変更せずそのまま記録しなければならない。
- LLM の回答および操作の概要は、ユーザー指示行の直後の次行に、行頭から1段だけインデントを下げて1行で記録しなければならない。
- `docs/history/chat-latest.md` への追記は `scripts/history-chat-append` の成功で完了とし、LLM が本文を読んで追記位置を判断してはならない。
- `docs/history/chat-latest.md` へ追記する場合は、次の usage で実行しなければならない。
  `./scripts/history-chat-append --user-line '<user_line>' --assistant-line '<assistant_line>'[ --today '<today>']`
    - `<user_line>` は、1行のユーザー指示であり、先頭を `- ` で始めなければならない。
    - `<assistant_line>` は、1行の LLM 応答概要であり、先頭を `  - ` で始めなければならない。
    - `<today>` は、省略時は当日値が使われ、指定する場合は `YYYY/MM/DD` または `YYYY-MM-DD` 形式でなければならない。
- 制約である「記録する文字列に個人情報、APIキー、トークン、絶対パス、ホームディレクトリが含まれる場合は、除去しなければならない。」は、この節の規則より上位に適用しなければならない。
- 1行の入力は、ユーザーが直接入力した指示として扱わなければならない。
- ユーザーが貼り付ける入力は、必ず改行を含むものとして扱わなければならない。
- 入力に最初の改行が現れた場合は、改行より前の1行目をユーザー指示としてそのまま残し、最初の改行以後の全文を引用として扱わなければならない。
- 引用として扱う部分は、そのまま記録してはならず、LLM が概要説明へ圧縮しなければならない。
- 圧縮した引用部分は、`[引用要約: ...]` の形式で、引用であることが分かる形にし、改行より前の1行目の末尾へ同じ行で連結しなければならない。

#### `docs/history/metrics-latest.md`

- `docs/history/metrics-latest.md` 全体の計測更新には、次の usage で `./scripts/metrics-collect` を使わなければならない。
  `./scripts/metrics-collect --label '<label>'[ --change-kind '<change_kind>'][ --manual-retries '<manual_retries>'][ --auto-retry-limit '<auto_retry_limit>']`
    - `<label>` は、計測結果へ残すラベルであり、省略してはならない。
- 限定確認や部分集合の計測確認には、次の usage で `./scripts/metrics-test-collect` を使わなければならない。
  `./scripts/metrics-test-collect[ --logic-only-testing '<logic_only_testing>'][ --ui-only-testing '<ui_only_testing>']`
- `./scripts/metrics-collect` または `./scripts/metrics-test-collect` が出力しない計測行を追加する場合は、次の usage で `./scripts/history-metrics-append` を使わなければならない。
  `./scripts/history-metrics-append --metric-line '<metric_line>'[ --today '<today>']`
    - `<metric_line>` は、1行の計測結果であり、先頭を `- ` で始めなければならない。
    - `<today>` は、省略時は当日値が使われ、指定する場合は `YYYY/MM/DD` または `YYYY-MM-DD` 形式でなければならない。

#### `docs/history/decisions-latest.md`

- 設計変更が行われた場合は `docs/history/decisions-latest.md` に追記しなければならない。
- `docs/history/decisions-latest.md` の新しい決定を追加する場合は、`scripts/history-decision-append` を使い、その成功により対象の日付見出し行の次行へ、その決定内容の箇条書き行を挿入しなければならない。
- 各決定の理由は、`scripts/history-decision-append` により、その決定内容の箇条書き行の直後の次行に、行頭から1段だけインデントを下げて記述しなければならない。
- `docs/history/decisions-latest.md` へ追記する場合は、次の usage で実行しなければならない。
  `./scripts/history-decision-append --decision-line '<decision_line>' --reason-line '<reason_line>'[ --today '<today>']`
    - `<decision_line>` は、1行の決定事項であり、先頭を `- ` で始めなければならない。
    - `<reason_line>` は、1行の理由であり、先頭を `  - ` で始めなければならない。
    - `<today>` は、省略時は当日値が使われ、指定する場合は `YYYY/MM/DD` または `YYYY-MM-DD` 形式でなければならない。
- 理由行の次行ではインデントを行頭へ戻し、空行を挿入せず、次の決定がある場合は次の箇条書き項目を記述しなければならない。

## 完了条件

- コミット対象が、その時点で完了条件を満たした変更セットだけで構成されていること。
- 必要な検証と、対応する `docs/history/*-latest.md` 更新が完了したうえでコミットされていること。
- `docs/history/chat-latest.md` の更新が必要な場合は、この文書の規則どおり `scripts/history-chat-append` が成功し、その結果が `docs/history/chat-latest.md` に反映されていること。
- `docs/history/decisions-latest.md` の更新が必要な場合は、この文書の規則どおり `scripts/history-decision-append` が成功し、その結果が `docs/history/decisions-latest.md` に反映されていること。
- `docs/history/metrics-latest.md` の更新が必要な場合は、この文書の規則どおり `scripts/metrics-collect`、`scripts/metrics-test-collect`、`scripts/history-metrics-append` のうち今回実行すべき command が成功し、その結果が `docs/history/metrics-latest.md` に反映されていること。
- コミットメッセージが日本語で記述されていること。
- 変更と作業単位の対応関係が履歴から追跡できること。

## 禁止事項

- 未完了の変更を含む差分を見切り発車でコミットしてはならない。
- 関連のない複数タスクの差分を 1 つのコミットへまとめてはならない。
- `docs/history/*-log.md` を直接更新してはならない。
- `docs/history/*-latest.md` の本文を読んで追記位置を判断したり、LLM が直接編集したりしてはならない。
- `docs/history/*-latest.md` の更新が必要なのに省略したままコミットしてはならない。
- この文書で規定した usage 以外の形で `scripts/history-chat-append`、`scripts/history-decision-append`、`scripts/history-metrics-append`、`scripts/metrics-collect`、`scripts/metrics-test-collect` を使ってはならない。
- 英語や空文、変更内容と対応しない文言でコミットメッセージを書いてはならない。
