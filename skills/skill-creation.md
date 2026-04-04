# Skill Creation Skill

この文書は、スキル作成という 1 つのタスクだけを定義する。

## スキル作成

- スキル作成とは、このリポジトリで再利用可能な command 実装を `scripts` 配下へ置き、`scripts/command-runner.py` から安定して呼び出せる状態にするタスクである。
- このタスクでは、`scripts` 配下の command 実装の配置、命名、分割、`scripts/command-runner.py`、Python 実装、検証、更新判断までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- `tools` は一時利用や運用補助に限定し、再利用対象の command 実装本体は `scripts` 配下へ置く。
- 利用者や LLM が呼ぶ入口は `scripts/command-runner.py` に集約し、実装本体は `scripts/<group>/` 配下へまとめる。
- `scripts/<group>/` は用途ごとのサブディレクトリで分類し、同一用途の実装を分散配置しない。
- `scripts/<group>/` ごとに、公開する command 群を集約した `_meta.json` を 1 つだけ置く。
- `_meta.json` は実行に必須の宣言ファイルであり、公開 command を実行するために必要な情報を定義する唯一の正本としなければならない。
- `_meta.json` には各 command の名前、エントリポイントとして対応する Python ファイル、引数仕様を必須で記述しなければならない。
- `_meta.json` を更新する時は、実行時に必要な command 名、対応する `scripts` 入口、呼び出される Python 実装、必要な引数や契約のような必須情報を同時に更新しなければならない。
- `scripts` や `_meta.json` を rules で説明する場合は、usage 記法と、usage だけでは確定しない `_meta.json` や `llm-cache` のキー名だけを記述しなければならない。
- `llm-cache` などで解決できる既定値を持つ option を rules の usage へ残すか削るかの判断はルール文書側の責務であり、skill 実装側の責務としては既定値解決だけを整えなければならない。
- command 実装内で必要になる補助ファイルは、可能な限り同じ `scripts/<group>/` 配下へ閉じ込める。
- `scripts/<group>/` 配下の実装は Python と `_meta.json` のみに限定し、shell で再ラップしない。
- 一時利用から再利用対象へ昇格した処理は、`tools` に留めず `scripts/<group>/` と `scripts/command-runner.py` から呼び出せる状態へ移す。

## 設計原則

- `scripts/<group>/` 配下の command 実装は再利用対象として、引数、環境変数、終了コードの契約を明確に保つ。
- `scripts/<group>/` を分割する時は、プロダクトコードの内部レイヤ分割を模倣せず、公開する command の機能単位で分割する。
- `scripts/<group>/` の複雑度が上がった場合は、内部構造を過剰に細分化する前に、group 単位または command 単位へ分割できないかを確認する。
- `scripts/<group>/` の分割判断は `specs` の内部責務ではなく、利用者に公開する機能境界と再利用単位を基準に行う。
- 認証情報や秘密情報は `scripts` に埋め込まず、ignore 対象の設定ファイルやリポジトリ外ファイルから受け取る。
- リポジトリに残す必要のない生成物はコミットしない。

## 命名規則

- `scripts` の名前は、利用者が何をしたいかで判断できる動詞中心の名前を優先する。
- Python などの補助実装も、`scripts/<group>/` 配下では command 名または group 名と対応づく `lowercase-kebab-case.py` を基本とする。
- Python から直接 import しにくい事情がある場合でも、公開ファイル名ではアンダースコアを増やさず、kebab-case を前提に構成を工夫する。

## Command Runner ルール

- 目的は、`scripts/command-runner.py` を唯一の公開入口として固定し、実装本体を必ず `scripts/<group>/` 配下の Python へ集約することである。
- `scripts/command-runner.py` は唯一の実行入口とし、`scripts/<group>/` 配下の Python 実装を `_meta.json` 経由で起動しなければならない。
- `scripts/command-runner.py` は自分自身の配置から repo root を解決し、利用者へ `--repo-root` の指定を要求してはならない。
- `scripts` は `_meta.json` を読み取り、command 名から対応する Python エントリポイントを決定する唯一の解決機構として動作しなければならない。
- `scripts` はこの解決に失敗した場合、フォールバックや推測を行わず処理を即時中断し、エラー内容を利用者へ返さなければならない。
- `scripts/command-runner.py` は引数をそのまま Python 実装本体へ透過し、引数の意味変換や暗黙補完を増やしてはならない。
- 条件分岐や複雑な判定が必要になった時点で、`scripts/command-runner.py` に留めず `scripts/<group>/` 配下の Python 実装本体へ移さなければならない。
- LLM は `scripts/command-runner.py` に業務ロジック、状態管理、ループ、再試行、フォールバック、文字列整形、JSON 組み立て、設定ファイル解釈、出力整形、サブコマンド選択、エラー分類を実装してはならない。
- `scripts` は `_meta.json` に定義されていない command の推測、補完、動的解決を行ってはならない。
- LLM は rules や Issue コメントに command 例を書く時、usage 記法と各置換値の説明を使わなければならず、説明なしの置換記法を残してはならない。

## Python と言語横断ルール

- `scripts/<group>/` 配下の実装本体は Python のみとし、理由なく他言語へ分散させない。
- `scripts/<group>/` 配下の Python 実装は直接実行する運用を許可せず、必ず `scripts/command-runner.py` から起動しなければならない。
- Python 実装も command 名の解決およびエントリポイントの決定において `_meta.json` だけを唯一の情報源として扱い、`_meta.json` に定義されていない command の推測、補完、動的解決を行ってはならない。
- Python の共有実行環境はリポジトリ root の `.venv/` を正本として扱い、共有依存定義はリポジトリ root の `requirements.txt` へ集約する。
- 依存が増えた場合は、局所 requirements を増やす前に root の `requirements.txt` へ集約できないかを先に検討する。
- Python の構文確認と lint の最低ラインは `py_compile` とし、変更した Python ファイルに対して `python -m py_compile` を実行して確認する。
- `scripts/<group>/` 配下の Python 実装は、1 ファイル `800` 行未満を原則とし、`1200` 行以上は分割なしに進めない。
- `scripts/<group>/` 配下の Python 実装は、1 関数 `100` 行未満を原則とし、`140` 行以上は分割または補助関数への抽出なしに進めない。
- `scripts/<group>/` 配下では、探索や試行の余地を残すため、プロダクトコードより緩い複雑度しきい値を使い、product code と同一しきい値を機械的に適用しない。

## 検証

- `scripts/command-runner.py` または `scripts/<group>/` 配下実装を追加または変更した時は、少なくとも構文確認と代表的な 1 経路の実行確認を行う。
- `scripts` の動作確認では、利用者が実際に呼ぶ `scripts/command-runner.py` 入口を優先して検証する。
- 変更した Python ファイルに対しては、`python -m py_compile` による構文確認を必ず実施する。
- 開発プロセスに組み込む `tools` を変更した場合も、最低限の構文確認を行う。

## 完了条件

- `skills/*.md`、`scripts/command-runner.py`、`scripts/<group>/` 配下実装の責務分担が守られていること。
- 入口の命名、配置、契約がこの文書のルールに沿っていること。
- 必要な Python の検証が完了していること。
- 追加または変更した skill が、代表的な 1 経路で利用可能であること。

## 禁止事項

- この文書から他の `.md` 文書を参照して判断してはならない。
- `scripts/command-runner.py` に実装本体や複雑な分岐を持ち込んではならない。
- `scripts/<group>/` 配下で shell による再ラップをしてはならない。
- `scripts/command-runner.py` 以外の `scripts` 直下入口を追加してはならない。
- `scripts/command-runner.py` を経由せず、`scripts/<group>/` 配下の Python を直接実行する入口を作ってはならない。
- `_meta.json` に実行時に必要な情報を欠いたまま追加や更新をしてはならない。
- `scripts` および Python 実装で、`_meta.json` に定義されていない command を推測や補完で解決してはならない。
- `scripts` および Python 実装で、`_meta.json` を使わずに command 名やエントリポイントを決定してはならない。
- `scripts` は未定義 command や不整合を検出した時に、別 command へのフォールバック、近似一致、既定値補完で処理を継続してはならない。
- `tools` を再利用対象の正規配置先として扱ってはならない。
- `scripts` の公開入口を `tools` に重複配置してはならない。
- `scripts/<group>/` 配下へ Python 以外の実装本体を置いてはならない。
- `scripts/<group>/` に product code と同じ内部レイヤ分割や複雑度しきい値を機械的に適用してはならない。
- 未検証の `scripts` を開発プロセスへ組み込んではならない。
