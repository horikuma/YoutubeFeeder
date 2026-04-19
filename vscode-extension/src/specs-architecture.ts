/**
# VSCode拡張 アーキテクチャ（ビューア統合）

## 概要

本ドキュメントは「仮想ドキュメントビューア（TS / Swift 連結表示）」を既存の拡張アーキテクチャへどのように統合するかを示す。

基本方針：

> 仮想ドキュメントは「独立機構」ではなく **Adapterの実装として扱う**

---

## レイヤ構造

```
[Command]
   ↓
[Provider（VSCode API境界）]
   ↓
[Adapter（データ生成）]
   ↓
[Pipeline（renderer / diff / apply）]
```

---

## 1. Provider層（インフラ）

### 役割
- VSCode API と内部ロジックの橋渡し
- URIリクエストをデータ取得に変換
- 最終的な文字列をVSCodeへ返却

### ファイル構成
```
infrastructure/
  tsDocumentProvider.ts
  swiftDocumentProvider.ts
```

### 挙動
```
URI → Provider
     → Adapter
     → lines[]
     → string結合
     → VSCodeエディタ
```

Providerは必ず薄く保つこと。

---

## 2. Adapter層（拡張ポイントの中核）

### 役割
- 行ベースデータの生成
- データ取得元の抽象化（固定 / ファイル / フィルタ等）

### 既存
- fixedAdapter（テスト用固定データ）

### 新規
```
adapter/
  fileConcatAdapter.ts      （共通ロジック）
  tsConcatAdapter.ts        （TS用）
  swiftConcatAdapter.ts     （Swift用）
```

### 挙動
```
入力: workspace
 ↓
ファイル探索（glob）
 ↓
ファイル読み込み
 ↓
行変換
 ↓
出力: string[]
```

---

## 3. Pipeline層（既存）

### 役割
- 行データの変換と描画
- 差分適用およびビューポート制御

### 構成
- renderer
- diff
- apply
- viewport
- updateController

### 状態
現状、concat providerからは直接使用していないが：

> 将来的には大規模データの仮想化表示に接続可能

---

## 4. Command層

### 役割
- ユーザー操作の起点

### コマンド
```
extension.openTsConcat
extension.openSwiftConcat
```

### フロー
```
Command
  → URIを開く
  → Provider発火
```

---

## 設計判断

### 1. Adapterベースとした理由

concatビューの本質は：

> 「どのように行データを生成するか」

これはAdapterの責務と完全に一致する。

---

### 2. Providerを薄くする理由

VSCode API とロジックの結合を避けるため。

ロジックはすべてAdapterに集約する。

---

### 3. TS / Swiftを分離する理由

差分は以下のみ：

- globパス
- ヘッダコメント形式

条件分岐を避けるため分離する。

---

## Swift対応

### 問題
Swiftファイルをそのまま連結すると構文ノイズが出る可能性がある。

### 解決
安全なコメントヘッダを使用：

```
// ===== /path/to/file =====
```

ファイル内容自体は変換しない。

---

## 将来拡張

想定されるAdapter：

```
diffAdapter
filteredAdapter
metricsAdapter
rangeAdapter
```

すべて同一パイプラインに接続可能。

---

## まとめ（設計原則）

> Provider = 境界
> Adapter = 可変点
> Pipeline = 描画

この分離により、拡張性と保守性を維持する。

*/
/**
# VSCode拡張 アーキテクチャ（SourceView / Pipeline 分離版）

## 概要

本ドキュメントは、現状の実装に基づき、以下2系統の表示構造を整理する。

1. SourceView（仮想ドキュメント表示）
2. Pipeline（Decoration描画）

両者は独立して存在するが、共通の「Adapter」概念を中心に構成される。

---

## 全体構造

```
[VSCode UI]
   ↓
[Command / extension.ts]
   ↓
[Provider（TextDocumentContentProvider）]
   ↓
[SourceViewAdapter]
   ↓
[filesystem]

（別系統）
Command → pipeline.ts → adapter.ts → renderer → diff → apply
```

---

## レイヤ構造

```
[Command]
   ↓
[Provider（VSCode API境界）]
   ↓
[Adapter（データ生成）]
   ↓
[表示層]
   ├ TextDocument（SourceView）
   └ Decoration（Pipeline）
```

---

## 1. Command層

### ファイル
```
src/extension.ts
```

### 役割
- コマンド登録
- UIイベント入口（右クリック / コマンドパレット）
- URI生成
- Provider起動

### 特徴
- ロジックは持たない（オーケストレーションのみ）

---

## 2. Provider層（仮想ドキュメント）

### クラス
```
SourceViewProvider
```

### 役割
- URI解析（path / key）
- Adapter呼び出し
- string生成

### フロー
```
URI → Provider
     → Adapter
     → string
     → VSCode表示
```

### 特徴
- VSCode API境界
- Adapterへの唯一の入口

---

## 3. Adapter層（中核）

### 3.1 SourceViewAdapter

### ファイル
```
src/adapter/sourceViewAdapter.ts
```

### 役割
- ファイル探索（glob）
- ファイル読み込み
- 行配列生成

### フロー
```
rootPath
  ↓
workspace相対変換
  ↓
glob生成
  ↓
findFiles
  ↓
sort（安定化）
  ↓
readFile
  ↓
split
  ↓
string[]
```

### 特徴
- I/O + 変換を内包
- 全量取得モデル
- 同期的処理（awaitベース）

---

### 3.2 SOURCE_VIEW_CONFIGS

### 役割
- 言語ごとの差分吸収

```
ts / swift / c
```

### 内容
- extensions
- headerフォーマット

### 特徴
> 言語差分を「コードではなくデータ」で表現

---

### 3.3 Pipeline用Adapter（旧系）

```
src/adapter.ts
```

### 役割
- 範囲指定取得

```
getLines(start, end)
```

### 特徴
- 仮想化表示前提
- SourceViewとは別モデル

---

## 4. 表示層

### 4.1 SourceView（仮想ドキュメント）

### 特徴
- 全量表示
- TextDocumentとして表示
- 編集不可（仮想）

---

### 4.2 Pipeline（Decoration）

### 構成
```
pipeline.ts
renderer.ts
diff.ts
apply.ts
viewport.ts
updateController.ts
```

### フロー
```
viewport
 → adapter
 → render
 → diff
 → apply
```

### 特徴
- 部分表示（viewport）
- 差分更新
- 大規模データ向け

---

## 5. 現状の特徴

### ① 表示系が2系統存在

| 系統 | 表示方式 |
|------|---------|
| SourceView | TextDocument |
| Pipeline | Decoration |

---

### ② Adapterが2種類存在

| 用途 | Adapter |
|------|--------|
| SourceView | SourceViewAdapter |
| Pipeline | createAdapter |

---

### ③ データモデル差

| 系統 | モデル |
|------|------|
| SourceView | 全量配列 |
| Pipeline | 範囲取得 |

---

### ④ I/O戦略

```
全ファイル読み込み → メモリ展開
```

---

### ⑤ 安定性対策

- パスをworkspace相対へ変換
- ファイル順序ソート

---

## 6. 設計原則

> Command = 起点
> Provider = 境界
> Adapter = 可変点
> 表示 = 戦略（複数可）

---

## 7. 今後の拡張方向

### Adapter拡張

```
filterAdapter
layerAdapter
symbolIndexAdapter
```

---

### 表示拡張

```
仮想ビュー（軽量）
差分ビュー
構造ビュー
```

---

## まとめ

本アーキテクチャは：

> 「Adapter中心のデータ生成」と「複数表示戦略の分離」により
> 拡張可能な観測系ツールを構成している

*/