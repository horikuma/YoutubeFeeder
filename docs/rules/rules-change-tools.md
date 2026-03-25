# Tool Change Rules

この文書を、このリポジトリで `tools`、`skills`、`scripts` または GitHub skill を変更する時に参照する正本として扱わなければならない。ここへ記述してよい内容は、各ディレクトリの責務、配置規則、命名規則、更新判断、動作確認の原則だけに限定し、それ以外を混在させてはならない。

rules コレクション全体の役割分担を判断する場合に限って [rules.md](../rules.md) を参照しなければならず、文書体系と履歴運用を判断する場合に限って [rules-update-documents.md](./rules-update-documents.md) を参照しなければならない。開発フローを判断する場合に限って [rules-run-development.md](./rules-run-development.md) を参照しなければならず、それ以外の論点ではこれらを参照してはならない。

## この文書の位置付け

- `rules-change-tools.md` では、`tools`、`skills`、`scripts` に関するルールだけを定義しなければならない。これに該当しない内容を記述してはならない。
- shell、Python、C 系言語のような言語単位の原則を判断する場合は [rules-change-languages.md](./rules-change-languages.md) を正本として参照しなければならず、この文書へ重複して書いてはならない。
- skills 自体の実装詳細や個別コマンド仕様を定義する場合は、対応するディレクトリ配下の文書へ置かなければならない。この文書へ実装本文を集約してはならない。

## ディレクトリの役割

- temporary 的なユーティリティや開発補助スクリプトを置く場合は [../tools](../tools) を使わなければならない。再利用対象の実装本体をここへ置いてはならない。
- LLM 向けに整理した再利用可能な実装本体を置く場合は [../skills](../skills) を使わなければならない。temporary な退避先として流用してはならない。
- ユーザーや LLM が skills の深さを意識せず使う入口を置く場合は [../scripts](../scripts) を使わなければならない。実装本体をここへ置いてはならない。
- `scripts` は skills の入口を揃えるための導線として保たなければならず、業務ロジックや状態管理を持ち込んではならない。
- `tools` は保守対象であっても、`skills` や `scripts` より一時利用や運用補助を優先する配置として扱わなければならない。公開入口の正規配置先として扱ってはならない。

## 配置規則

- `skills` は用途ごとのサブディレクトリで分類しなければならず、同一用途の実装は同じ配下へ集約しなければならない。用途が同じ実装を分散配置してはならない。
- `skills` のサブディレクトリごとに、公開するコマンド群を集約した `_meta.json` を 1 つだけ置かなければならない。複数置いてはならない。
- `scripts` はリポジトリ直下の入口として置かなければならず、対応する skills の呼び出しだけを行わなければならない。独自実装を追加してはならない。
- `scripts` から skills を呼ぶ時は、リポジトリ root 基準またはスクリプト自身の位置から相対解決し、呼び出し先の実体パスをハードコードしすぎない。
- `skills` 内で必要になる補助ファイルは、可能な限り同じ skill ディレクトリ配下へ閉じ込める。
- Python 系の共有実行環境や依存定義は、言語単位ルールとして [rules-change-languages.md](./rules-change-languages.md) に従い、skill ごとの局所配置へ分散させすぎない。
- `tools` には skills の公開入口を重複して置かず、temporary な補助や移行用の機械処理へ責務を限定する。

## 命名規則

- `skills` 配下のシェルスクリプト名は `lowercase-kebab-case.sh` を基本にしなければならない。特段の理由なく別の命名規則を採用してはならない。
- `scripts` 配下のラッパー名は拡張子なしの `lowercase-kebab-case` を基本にしなければならない。
- `scripts` のラッパー名を付ける時は、利用者が何をしたいかで判断できる動詞中心の名前を優先しなければならない。
- Python などの補助実装も、`skills` 配下では呼び出し元の skill 名と対応づく `lowercase-kebab-case.py` を基本にしなければならない。
- Python から直接 import しにくい事情がある場合でも、公開ファイル名ではアンダースコアを増やさず、kebab-case を前提に構成を工夫する。
- 一時ユーティリティであっても、`tools` 配下の名前は用途が識別できる具体名にする。

## 実装原則

- `skills` は再利用対象として、引数、環境変数、終了コードの契約を明確に保たなければならない。暗黙動作へ依存してはならない。
- `_meta.json` には、そのサブディレクトリ配下で公開する commands を集約し、同一ドメインの skill ごとに分散定義しない。
- `scripts` は `bash skills/... "$@"` 相当の薄いラッパーに留め、追加の分岐や変換を増やさない。
- shell wrapper の分岐禁止や互換性方針は [rules-change-languages.md](./rules-change-languages.md) に従う。
- 認証情報や秘密情報は `scripts` や `skills` に埋め込まず、ignore 対象の JSON 設定やリポジトリ外ファイルから受け取る。
- 外部サービスの認証設定は、shell の `eval` で環境変数を展開せず、ignore 対象の JSON を読み込む実装へ統一する。
- GitHub 関連の secrets には `operationMode` を持たせなければならず、`user` または `organization` のどちらで動くかを設定ファイル側で切り替えられるようにしなければならない。
- GitHub 関連の secrets は mode 判定に必要な最小情報だけを持たなければならず、Issue の既定 Assignee / Project と Pull Request の既定 Assignee は `llm-cache/` 配下の local cache を正本として管理しなければならない。secrets 側へ重複保持してはならない。
- rules 文書へ Assignee 名や Project 名のようなプロダクト固有値を固定してはならず、GitHub skill / script は secrets と `llm-cache/` から既定値を解決しなければならない。Pull Request の Project 登録を既定動作にしてはならない。
- 仮想環境や依存実行系の吸収が必要な場合は、`skills` 側で処理するか、`scripts` から最小限の形で委譲しなければならない。`scripts` 側へ複雑な吸収ロジックを持ち込んではならない。
- `skills` の複雑度が上がった場合は、プロダクトコードのように内部レイヤを過剰分割する前に、skill 単位または command 単位への分割を優先する。
- LLM が補助ファイルや一時ファイルを生成する場合は、`llm-temp/` を使い、不要になっても自動削除しない。
- GitHub の Assignee / Project のように毎回の曖昧一致を避けたい外部メタデータは、`llm-cache/` 配下の local cache を正本として保持しなければならない。必要項目が無い時は補完して進めてはならず、停止してユーザーへ確認しなければならない。
- GitHub skill は `user` モードでは repo 操作を GitHub App、Projects 操作を `gh` へ振り分け、`organization` モードでは repo 操作も Projects 操作も GitHub App へ寄せる。
- GitHub Project の custom field を扱う skill / script も、同じ mode 解決に従って field の作成と item 値更新を行う。
- GitHub skill / script は、開発セッション開始時に現在の main ブランチ名と現在の mode を開発セッション情報として出力し、以後の branch base と API 経路判断に使う。
- GitHub skill / script は、同じ開発セッション内の後続シーケンスで session main の問い合わせを繰り返さず、`llm-cache/session-context.json` に保持された値を参照して Issue / Pull Request の base を決める。
- Issue に対応する作業ブランチを作成した後は、そのブランチ名を対象 Issue のコメントへ記録できる経路を維持しなければならない。正規入口は [skills/github/register-issue-branch.sh](../../skills/github/register-issue-branch.sh) と [scripts/register-issue-branch](../../scripts/register-issue-branch) に限定し、Issue とブランチの対応が GitHub 上から追えない状態にしてはならない。
- `history/*-latest.md` から `history/*-log.md` への移行のように大きな履歴文書を扱う処理は、local skill / script として実装しなければならない。LLM が巨大な log 本文を直接読んで編集してはならない。
- 履歴ローテーションの正規入口は [skills/history/rotate-history.sh](../../skills/history/rotate-history.sh) と [scripts/rotate-history](../../scripts/rotate-history) とし、`tools` 配下の一時スクリプトを開発プロセスの正規手順にしてはならない。
- 履歴ローテーション skill / script は、`*-latest.md` 全体を無条件に空にするのではなく、過去日分だけを `*-log.md` へ移し、当日分があれば `*-latest.md` に残す契約で実装する。
- 特定の外部サービスへ接続する skill は、対象サービスの現行 API を前提にしなければならず、旧 API や場当たり的なフォールバック経路を持ち込んではならない。
- `skills` と `scripts` の利用例や動作確認コマンドは、ワークスペース root から実行できる相対パス基準で記述しなければならない。
- `tools`、`skills`、`scripts` のいずれでも、リポジトリに残す必要のない生成物はコミットしない。

## 更新判断

- 一時利用から再利用対象へ昇格した処理は、`tools` から `skills` と `scripts` へ移さなければならない。`tools` に置いたまま正規運用してはならない。
- 利用者に公開する入口を追加または変更した時は、`scripts` とこの文書を更新しなければならない。
- `skills` の分類、命名規則、責務境界を変更した時は、この文書を更新しなければならない。
- 文書で定めた構成と実際のディレクトリ構成がずれた場合は、どちらを正とするか確認してから揃えなければならない。確認せず片側だけを変更してはならない。

## 動作確認

- `skills` や `scripts` を追加または変更した時は、少なくとも構文確認と代表的な 1 経路の実行確認を行う。
- `scripts` の動作確認では、利用者が実際に呼ぶ入口を優先して検証する。
- temporary な `tools` であっても、開発プロセスに組み込むものは最低限の構文確認を行わなければならない。未確認のまま組み込んではならない。
