# Session Start Rules

この文書は、開発セッション開始時に LLM が読むための制約文書である。正本は [rules.md](../rules.md)、[rules-document.md](./rules-document.md)、[rules-process.md](./rules-process.md) であり、この文書は開始時に必要な制約だけを集約した作業用要約とする。

## この文書の使い方

- この文書は `開発セッション開始時に何を確認し、何を実施し、何を停止条件とするか` だけを扱う。
- この文書を読んでも、ここに書かれた開始処理を自動実行したものとみなしてはならない。各項目は、実際の開発セッション開始時に個別に実施する。
- 判断に迷った場合は、この文書ではなく正本へ戻る。
- `[COMMON_CANDIDATE]` が付いた項目は、将来的に他の LLM 向け文書へ分割または共通化する候補である。現時点ではこの文書内に保持する。

## セッション開始時の必須制約

- [COMMON_CANDIDATE] セッション開始時は、最初に [rules.md](../rules.md) を読み、その後に [rules-document.md](./rules-document.md) と [rules-process.md](./rules-process.md) を読むこと。
- [COMMON_CANDIDATE] 着手前に、ユーザー指示、関連コード、関連文書を確認し、変更対象と影響範囲を把握すること。
- [COMMON_CANDIDATE] タスク種別に応じて追加文書を読むこと。
  - 機能追加や画面仕様変更では [specs.md](../specs.md)、必要に応じて [specs-product.md](../specs/specs-product.md)、[specs-architecture.md](../specs/specs-architecture.md)、[specs-design.md](../specs/specs-design.md) を読む。
  - 不具合修正や調査では [specs.md](../specs.md) を起点に、影響範囲に応じて [specs-product.md](../specs/specs-product.md)、[specs-architecture.md](../specs/specs-architecture.md)、[specs-design.md](../specs/specs-design.md) を読む。
  - 設計整理や責務分割では [specs.md](../specs.md)、[specs-architecture.md](../specs/specs-architecture.md)、[specs-design.md](../specs/specs-design.md) を読む。
  - 開発環境やローカル検証手順の変更では [specs.md](../specs.md) と [specs-environment.md](../specs/specs-environment.md) を読む。
  - 文書更新では [rules-document.md](./rules-document.md) を再確認し、配置先の判断基準を確認する。
  - `tools`、`skills`、`scripts` に関わる変更では [rules-skills.md](./rules-skills.md) も追加で読む。
- [COMMON_CANDIDATE] 開発セッション開始時は、`main` ブランチ上にいることを確認してから作業へ入ること。
- [COMMON_CANDIDATE] `main` 上で `git pull --ff-only origin main` により fast-forward で最新化できることを確認してから作業へ入ること。
- [COMMON_CANDIDATE] 日付跨ぎ、または過去日の内容が `docs/history/*-latest.md` に残っている場合は、対応する skill / script を使って `*-log.md` へローテーションしてから当日分の運用を開始すること。
- [COMMON_CANDIDATE] 履歴ローテーションでは、巨大な log を手作業や直接結合で更新せず、既定の skill / script を使うこと。
- [COMMON_CANDIDATE] チャット欄から開始した開発セッションは、作業開始前にユーザー指示を原文として残した Issue を作成し、その後は Issue 駆動で進めること。
- Issue 起点タスクでは、実装前に対象 Issue の Description を読み、作業単位、完了条件、非対象を確認すること。
- チャット起点 Issue の詳細化では、Description にはチェックボックス付き ToDo のみを追記し、背景、目的、スコープ、実施タスク、完了条件は Issue コメントで詳細化すること。
- Issue 詳細化中に blocker が見つかった場合は、Issue コメントへ理由、確認内容、現在状況を残して停止すること。
- rules に反する指示や、プロダクト固有値を rules へ持ち込む指示を受けた場合は、Issue コメントへ内容を記録して停止し、次の指示を待つこと。
- [COMMON_CANDIDATE] Issue に着手したら、実装開始前に対応する作業ブランチを作成すること。
- [COMMON_CANDIDATE] 一時ファイルが必要な場合は `temp-llm/` を使い、共有領域や `/tmp` へ安易に退避しないこと。
- [COMMON_CANDIDATE] `temp-llm/` 配下の一時ファイルは痕跡として扱い、LLM 判断で自動削除しないこと。

## セッション開始時の禁止事項

- この文書だけを根拠に、正本未確認のまま実装へ進んではならない。
- `main` で最新化できていない状態のまま、新しい開発セッションを始めてはならない。
- 過去日の `*-latest.md` を残したまま、当日分の履歴追記を始めてはならない。
- チャット起点タスクで、Issue を作らずにそのまま実装へ進んではならない。
- rules と矛盾する指示を受けた時に、独断で解釈して続行してはならない。
- 一時ファイルを `/tmp` などの共有領域へ退避してはならない。

## 開始完了の判定

- セッション開始処理は、必要な rules / specs を読み、`main` の最新化確認が済み、必要なら履歴ローテーションが完了し、必要なら Issue と作業ブランチの準備が終わった時点で完了とみなす。
- ここまで完了して初めて、先行テスト、実装、検証、文書同期へ進んでよい。
