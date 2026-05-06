# Inspector

## Purpose

Inspector は YoutubeFeeder コードベース向けの軽量構造解析パイプラインである。

目的は完全な semantic compilation や IDE 相当の index を構築することではない。
主目的は以下。

- 構造複雑性の観測
- 責務集中の検出
- fragmentation の検出
- 安定した graph identity の提供
- LLM 探索コストの削減
- 長期 semi-agent 開発支援

このシステムは、完全な semantic correctness よりも以下を優先する。

- 高速反復
- 人間が読めるメトリクス
- 段階的拡張性
- snapshot の決定論性
- 運用コストの低さ

---

# Architecture

Inspector は 2 段階構成である。

```text
collect.py
    ↓
SQLite database
    ↓
view.py
```

`collect.py` は高コストな抽出処理を担当する。

`view.py` は低コストな分析クエリを担当する。

この責務分離は意図的なものである。

collector は低頻度実行前提なので、ある程度重くても許容する。
一方 viewer は、人間および LLM が試行錯誤し続けられるよう、極めて高速である必要がある。

---

# Design Philosophy

## Snapshot-oriented analysis

database は repository 構造の snapshot として扱う。

Inspector は continuously synchronized な IDE index として振る舞うことを目的としていない。

これにより実装複雑性を大きく削減できる。

想定 workflow は以下。

```text
collect
→ inspect
→ refactor
→ collect
→ compare
```

---

## Graph-oriented structure

database schema は graph analysis を見据えて設計されている。

現在の schema には既に以下が含まれる。

- stable symbol identity
- parent-child relationship
- declaration metadata
- fragmentation information
- responsibility density signal

collector を作り直さなくても graph query を段階的に追加できる構造を目指している。

---

## Human-readable metrics first

Inspector は抽象的な "quality score" を算出しない。

代わりに以下を露出する。

- hotspots
- symbol density
- fragmentation
- parent fanout
- extension spread
- missing identity information

これらは、人間が視覚的に解釈可能であることを重視している。

architecture 判断は探索的であることが多いため、単一 metric に過剰依存しない。
metric は探索補助として扱い、人間の判断を完全には置き換えない。

---

## Cost-aware analysis

システムは非対称コストを前提として設計されている。

```text
collect = expensive
view    = cheap
```

これは明示的な設計制約である。

高コスト semantic extraction は snapshot 生成へ集約する。
低コスト analysis は高速反復へ最適化する。

これにより以下を実用化する。

- 繰り返し inspection
- LLM-assisted development
- architecture cleanup
- 長期 refactor campaign

---

# Collector Design

## Source extraction

collector は現在以下へ依存している。

- SourceKitten structure
- SourceKit cursor info

structure tree から取得する情報:

- declaration
- nesting
- offset
- length
- accessibility
- attribute

cursor info は主に USR 抽出へ利用する。

---

## Symbol identity

symbol identity は最重要設計制約の 1 つである。

単純な name-based identity は不十分。

理由:

- overload が存在する
- extension が存在する
- nested type が存在する
- 同名 symbol が複数 file に存在しうる

そのため collector は以下を優先する。

```text
USR
```

これを canonical stable identity として扱う。

fallback identity は以下。

```text
relative_path + kind + name
```

これを SHA1 hash 化して利用する。

これにより SourceKit が USR を返せない場合でも database を継続利用できる。

---

## Parent tracking

collector は以下を保存する。

- parent_symbol_id
- parent_usr

これにより以下が可能になる。

- ownership graph analysis
- nesting analysis
- extension grouping
- fanout analysis
- 将来的な callgraph integration

traversal system は parent context を明示的に伝搬する。

---

## Annotated declarations

collector は可能な場合、以下を保存する。

```text
key.annotated_decl
```

これにより以下を改善する。

- overload visibility
- generic readability
- debugging
- 将来的な semantic grouping

これは厳密 parser 用というより inspection readability 向け情報である。

---

## File content caching

line-count extraction は当初、symbol ごとに file を再読込していた。

現在は:

```text
1 file read
→ many symbol calculations
```

へ変更し、抽出コストを削減している。

---

# Database Design

現在は SQLite を利用している。

理由:

- setup cost が低い
- portability が高い
- analytical performance が既に十分
- operational complexity が低い

現在の dataset 規模は小さいため、多くの analytical query はほぼ瞬時に実行できる。

一方で architecture は将来的に以下へ移行可能な構造を維持する。

- DuckDB
- graph database
- vector indexing

---

# Viewer Design

viewer は procedural traversal ではなく、以下中心で構成する。

- GROUP BY
- COUNT
- DISTINCT
- ORDER BY
- aggregation-style analysis

これにより実装複雑性を大きく削減できる。

viewer は exploratory analysis 支援を目的とする。

新しい view は原則として:

```sql
SELECT ...
```

として追加し、大規模 procedural logic を避ける。

---

# Current Views

## HOTSPOTS

line count が大きい symbol を検出する。

用途:

- oversized responsibility 検出
- logic concentration 検出
- refactor candidate 検出

---

## SYMBOL KINDS

declaration type 分布を観測する。

用途:

- architecture style 観測
- extension-heavy structure 検出
- protocol usage 観測
- model density 観測

---

## LARGEST FILES

symbol count が大きい file を検出する。

これは単純 file size metric ではない。

より近い概念は:

```text
architectural surface area
```

である。

---

## EXTENSION FRAGMENTATION

多数 file に分散した type を検出する。

用途:

- extension sprawl 検出
- hidden ownership 検出
- navigation cost 観測
- LLM exploration complexity 観測

---

## PARENT FANOUT

child 数が多い symbol を検出する。

用途:

- oversized coordinator 検出
- large namespace 検出
- responsibility concentration 検出
- decomposition target 検出

---

## MISSING USR

stable SourceKit identity を持たない symbol を検出する。

用途:

- collector validation
- graph integrity validation
- future migration safety

---

# Intended Future Direction

将来的な拡張候補:

- callgraph extraction
- reference graph extraction
- import dependency analysis
- architectural layering analysis
- SCC / cycle detection
- graph centrality analysis
- semantic clustering
- historical snapshot diffing
- vector search
- LLM-assisted graph traversal

現在の architecture は、これらを段階的追加できるよう設計している。

---

# Non-Goals

Inspector は現在以下を目的としない。

- IDE indexing の代替
- 完全 semantic correctness
- 完全 Swift semantic parser
- compile-time validation
- static analyzer の代替
- language server

本システムの目的は architecture observation と iterative refactoring 支援である。