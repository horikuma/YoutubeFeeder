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