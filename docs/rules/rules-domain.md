# Domain Rules

この文書は、実装言語や shell wrapper のような言語単位のルールを集約する正本である。ここでは、プロダクト固有の責務分割や画面仕様ではなく、組織横断で再利用する原理原則だけを扱う。

上位方針と rules コレクション全体の役割分担は [rules.md](../rules.md)、開発フローは [rules-process.md](./rules-process.md)、`tools`、`skills`、`scripts` の配置規則は [rules-skills.md](./rules-skills.md) を参照する。

## この文書の位置付け

- `rules-domain.md` は、shell、Python、C 系言語の実装原則、formatter / lint、複雑度しきい値のような言語単位ルールだけを扱う。
- この文書には、特定プロダクトの責務分割、画面仕様、データフロー、個別ディレクトリ構成を持ち込まない。
- プロダクトコード固有の責務分割は `specs` 側へ置き、言語をまたいで再利用できる制約だけを本書へ置く。
- `skills` の内部整理はプロダクトコードの内部設計とは分けて扱い、探索の幅を残すために本書の中でも別枠の緩い制約を使う。
- 言語単位のルールを更新してもプロダクト仕様が変わらない場合は、`specs` を過剰に更新対象へ広げない。

## 配置判断

- shell wrapper の責務、分岐禁止、環境変数やパス解決の扱いは本書へ置く。
- Python や C 系言語の複雑度しきい値、formatter / lint のような実装言語ルールは本書へ置く。
- `skills` をどの粒度で分割するかのような、言語横断で再利用する制約は本書へ置く。
- `tools`、`skills`、`scripts` のディレクトリ責務や配置規則は [rules-skills.md](./rules-skills.md) へ置く。
- プロダクトコードの責務分割、データフロー、レイヤ境界は `specs` 側へ置く。

## shell ルール

- Mac では `zsh`、Linux では `bash`、Windows では `PowerShell` を標準 shell として扱う。
- shell script は、パス解決、環境変数受け渡し、実行系の起動だけを担う薄い wrapper とする。
- shell script に業務ロジック、状態管理、`if` / `case` / `while` / `for` を使った分岐処理を持ち込まない。
- 条件分岐や複雑な判定が必要になった時点で、shell に留めず Python の実装本体へ移す。
- `zsh` と `bash` をまたぐ wrapper は、`bash` で作成しても `bash` 専用構文へ寄せすぎず、Mac / Linux の互換性を優先する。
- `zsh` と `bash` をまたぐ wrapper では、配列依存、`[[ ... ]]` の多用、process substitution のような互換性を崩しやすい記法を避け、POSIX に近い書き方を優先する。
- wrapper は引数をそのまま実装本体へ透過し、引数の意味変換や暗黙補完を増やさない。
- shell を追加または変更した時は、少なくとも `bash -n` で構文確認する。

## Python ルール

- shell wrapper の実体は原則として Python に置く。
- Python の共有実行環境はリポジトリ root の `.venv/` を正本とし、共有依存定義はリポジトリ root の `requirements.txt` へ集約する。
- 依存が増えた場合は、局所 requirements を増やす前に root の `requirements.txt` へ集約できないかを先に検討する。
- Python の構文確認と lint の最低ラインは `py_compile` とし、変更した Python ファイルに対して `python -m py_compile` を実行して確認する。
- Python の product code は、1 ファイル `500` 行未満を原則とし、`800` 行以上は分割なしに進めてはならない。
- Python の product code は、1 関数 `60` 行未満を原則とし、`90` 行以上は分割または責務移譲なしに進めてはならない。
- Python の product code は、1 ファイル内の主要型や主要責務が `10` を超える場合、責務の混在を疑って分割を検討する。

## C 系言語ルール

- C 系言語の formatter は `clang-format` を正本とし、リポジトリ root の `.clang-format` を適用する。
- `clang-format` の適用対象は、C、C++、header を含む実装語全体とする。
- C 系 product code は、1 ファイル `800` 行未満を原則とし、`1200` 行以上は分割なしに進めてはならない。
- C 系 product code は、1 関数 `80` 行未満を原則とし、`120` 行以上は分割または責務移譲なしに進めてはならない。
- C 系 product code は、1 ファイル内の主要型や主要責務が `12` を超える場合、責務の混在を疑って見直す。

## skills の実装制約

- `skills` はプロダクトコードと同じ内部レイヤ分割を無理に模倣せず、公開する skill や command の機能単位で分割する。
- `skills` は探索や試行の余地を残すため、プロダクトコードより緩い複雑度しきい値を使う。
- `skills` の複雑度が上がった場合は、まず内部構造を細分化するより先に、skill 単位または command 単位へ分割できないかを確認する。
- `skills` の Python 実装は、1 ファイル `800` 行未満を原則とし、`1200` 行以上は分割なしに進めてはならない。
- `skills` の Python 実装は、1 関数 `100` 行未満を原則とし、`140` 行以上は分割または補助関数への抽出なしに進めてはならない。
- `skills` の shell wrapper は product code と同様に薄い wrapper とし、分岐や実装本体を持ち込まない。
- `skills` の分割判断は `specs` の内部責務ではなく、利用者に公開する機能境界と再利用単位を基準に行う。

## 更新判断

- 実装言語ごとの formatter / lint / 複雑度しきい値を変えた時は、本書を更新する。
- shell wrapper の責務や互換性方針を変えた時は、本書を更新する。
- `skills` の複雑度や分割方針を変えた時は、本書と [rules-skills.md](./rules-skills.md) の責務分担を確認する。