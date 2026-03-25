# Skills Rules

この文書は、このリポジトリ直下の `tools`、`skills`、`scripts` に関する運用ルールを定める正本である。ここでは、各ディレクトリの責務、配置規則、命名規則、更新判断、動作確認の原則を扱う。

上位方針と rules コレクション全体の役割分担は [rules.md](../rules.md)、文書体系と履歴運用は [rules-document.md](./rules-document.md)、開発フローは [rules-process.md](./rules-process.md) を参照する。

## この文書の位置付け

- `rules-skills.md` は、`tools`、`skills`、`scripts` に関するルールだけを扱う。
- shell、Python、C 系言語のような言語単位の原則は [rules-domain.md](./rules-domain.md) を正本とし、この文書へ重複して書かない。
- skills 自体の実装詳細や個別コマンド仕様は、必要に応じて対応するディレクトリ配下の文書へ置き、この文書へ実装本文を集約しない。

## ディレクトリの役割

- [../tools](../tools) は、temporary 的なユーティリティや開発補助スクリプトを置く。
- [../skills](../skills) は、LLM 向けに整理した再利用可能な実装本体を置く。
- [../scripts](../scripts) は、ユーザーや LLM が skills の深さを意識せず使うための薄いラッパー層を置く。
- `scripts` は skills の入口を揃えるための導線であり、業務ロジックや状態管理を持ち込まない。
- `tools` は保守対象ではあるが、`skills` や `scripts` よりも一時利用や運用補助を優先した配置として扱う。

## 配置規則

- `skills` は用途ごとのサブディレクトリで分類し、同一用途の実装は同じ配下へ集約する。
- `skills` のサブディレクトリごとに、公開するコマンド群を集約した `_meta.json` を 1 つだけ置く。
- `scripts` はリポジトリ直下の入口として置き、対応する skills の呼び出しだけを行う。
- `scripts` から skills を呼ぶ時は、リポジトリ root 基準またはスクリプト自身の位置から相対解決し、呼び出し先の実体パスをハードコードしすぎない。
- `skills` 内で必要になる補助ファイルは、可能な限り同じ skill ディレクトリ配下へ閉じ込める。
- Python 系の共有実行環境や依存定義は、言語単位ルールとして [rules-domain.md](./rules-domain.md) に従い、skill ごとの局所配置へ分散させすぎない。
- `tools` には skills の公開入口を重複して置かず、temporary な補助や移行用の機械処理へ責務を限定する。

## 命名規則

- `skills` 配下のシェルスクリプト名は `lowercase-kebab-case.sh` を基本とする。
- `scripts` 配下のラッパー名は拡張子なしの `lowercase-kebab-case` を基本とする。
- `scripts` のラッパー名は、利用者が何をしたいかで判断できる動詞中心の名前を優先する。
- Python などの補助実装も、`skills` 配下では呼び出し元の skill 名と対応づく `lowercase-kebab-case.py` を基本とする。
- Python から直接 import しにくい事情がある場合でも、公開ファイル名ではアンダースコアを増やさず、kebab-case を前提に構成を工夫する。
- 一時ユーティリティであっても、`tools` 配下の名前は用途が識別できる具体名にする。

## 実装原則

- `skills` は再利用対象として、引数、環境変数、終了コードの契約を明確に保つ。
- `_meta.json` には、そのサブディレクトリ配下で公開する commands を集約し、同一ドメインの skill ごとに分散定義しない。
- `scripts` は `bash skills/... "$@"` 相当の薄いラッパーに留め、追加の分岐や変換を増やさない。
- shell wrapper の分岐禁止や互換性方針は [rules-domain.md](./rules-domain.md) に従う。
- 認証情報や秘密情報は `scripts` や `skills` に埋め込まず、ignore 対象の JSON 設定やリポジトリ外ファイルから受け取る。
- 外部サービスの認証設定は、shell の `eval` で環境変数を展開せず、ignore 対象の JSON を読み込む実装へ統一する。
- GitHub 関連の secrets には `operationMode` を持たせ、`user` または `organization` のどちらで動くかを設定ファイル側で切り替えられるようにする。
- GitHub 関連の secrets は mode 判定に必要な最小情報だけを持ち、既定 Assignee と既定 Projects は `llm-cache/` 配下の local cache を正本として管理する。
- rules 文書には Assignee 名や Project 名のようなプロダクト固有値を固定せず、GitHub skill / script は secrets と `llm-cache/` から既定値を解決する。
- 仮想環境や依存実行系の吸収が必要な場合は、`skills` 側で処理するか、`scripts` から最小限の形で委譲する。
- `skills` の複雑度が上がった場合は、プロダクトコードのように内部レイヤを過剰分割する前に、skill 単位または command 単位への分割を優先する。
- LLM が補助ファイルや一時ファイルを生成する場合は、`llm-temp/` を使い、不要になっても自動削除しない。
- GitHub の Assignee / Project のように毎回の曖昧一致を避けたい外部メタデータは、`llm-cache/` 配下の local cache を正本として保持し、必要項目が無い時は補完せず停止してユーザーへ確認する。
- GitHub skill は `user` モードでは repo 操作を GitHub App、Projects 操作を `gh` へ振り分け、`organization` モードでは repo 操作も Projects 操作も GitHub App へ寄せる。
- GitHub Project の custom field を扱う skill / script も、同じ mode 解決に従って field の作成と item 値更新を行う。
- GitHub skill / script は、開発セッション開始時に現在の main ブランチ名と現在の mode を開発セッション情報として出力し、以後の branch base と API 経路判断に使う。
- GitHub skill / script は、同じ開発セッション内の後続シーケンスで session main の問い合わせを繰り返さず、`llm-cache/session-context.json` に保持された値を参照して Issue / Pull Request の base を決める。
- `history/*-latest.md` から `history/*-log.md` への移行のように大きな履歴文書を扱う処理は、LLM が巨大な log 本文を直接読んで編集せず、local skill / script として実装する。
- 履歴ローテーションの正規入口は [skills/history/rotate-history.sh](../../skills/history/rotate-history.sh) と [scripts/rotate-history](../../scripts/rotate-history) とし、`tools` 配下の一時スクリプトを開発プロセスの正規手順にしてはならない。
- 履歴ローテーション skill / script は、`*-latest.md` 全体を無条件に空にするのではなく、過去日分だけを `*-log.md` へ移し、当日分があれば `*-latest.md` に残す契約で実装する。
- 特定の外部サービスへ接続する skill は、対象サービスの現行 API を前提にし、旧 API や場当たり的なフォールバック経路を持ち込まない。
- `skills` と `scripts` の利用例や動作確認コマンドは、ワークスペース root から実行できる相対パス基準で記述する。
- `tools`、`skills`、`scripts` のいずれでも、リポジトリに残す必要のない生成物はコミットしない。

## 更新判断

- 一時利用から再利用対象へ昇格した処理は、`tools` から `skills` と `scripts` へ移す。
- 利用者に公開する入口を追加または変更した時は、`scripts` とこの文書を更新する。
- `skills` の分類、命名規則、責務境界を変更した時は、この文書を更新する。
- 文書で定めた構成と実際のディレクトリ構成がずれた場合は、どちらを正とするか確認してから揃える。

## 動作確認

- `skills` や `scripts` を追加または変更した時は、少なくとも構文確認と代表的な 1 経路の実行確認を行う。
- `scripts` の動作確認では、利用者が実際に呼ぶ入口を優先して検証する。
- temporary な `tools` であっても、開発プロセスに組み込むものは最低限の構文確認を行う。
