# HelloWorld Architecture

この文書は、HelloWorld の採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を定める設計文書である。本書は「このプロダクトでどう設計するか」を扱う。

文書群の役割分担と文書の切り分け基準は [document-rules.md](./document-rules.md)、文書運用ルールは [document-operations.md](./document-operations.md) を参照する。

## プロダクト前提

- 本プロダクトは Swift / SwiftUI で実装する iOS アプリである。
- `iPhone` と `iPad` は同一機能を提供し、差分は Adaptive UI に沿ったレイアウト表現へ閉じ込める。
- 起動性能と操作中の軽さを優先し、起動直後は軽量な初期データだけで最初の画面を成立させる。
- 外部連携は YouTube feed と YouTube Data API を中心に構成し、ローカルキャッシュを正本として閲覧体験を安定させる。

## 採用アーキテクチャ

- 現在の基本モデルは `MVVM + Clean Architecture` とする。
- `View`
  - SwiftUI の画面と表示部品を担う。
  - 一時的な UI 状態、選択状態、アニメーション、ダイアログ状態を持ってよい。
- `Coordinator / ViewModel`
  - 画面や機能単位の state と orchestration を担う。
- `Service / Use Case`
  - 機能単位で意味のある処理のまとまりを担う。
- `Store / Infrastructure`
  - 永続化、固定パス、キャッシュ、外部 API 通信を担う。
- 標準フレームワークや Apple 推奨パターンで十分に表現できる責務は、独自抽象よりそちらを優先する。
- 独自実装や標準から外れた方式を選ぶ場合は、必要性と理由を説明できる状態を保つ。
- MVVM を守るためだけの protocol 分割、値の受け渡しラッパー、薄い中継層は増やさず、`pure logic`、`store`、`external service` へ意味のある単位で分割する。

## レイヤ責務と依存方向

- 依存方向は `View -> Coordinator / ViewModel -> Service / Use Case -> Store or Infrastructure` を原則とする。
- `View` は I/O を直接持たず、外部通信、永続化、複雑な判定は内側の層へ委譲する。
- `View` は一時的な UI 状態、アニメーション状態、選択状態、ダイアログ状態を持ってよく、MVVM を理由にそれらを機械的に `ViewModel` へ押し上げてはならない。
- `Coordinator / ViewModel` は UI と永続化の仲介を担うが、ファイル形式や API 呼び出しの細部を抱え込まない。
- `Coordinator / ViewModel` は `1 画面` もしくは `1 機能の orchestration` に責務を寄せ、画面描画専用の細かな値変換や単純な表示状態まで過剰に抱え込まない。
- `Service / Use Case` は UI 文脈から独立して成立する判定、状態遷移、マージ、更新フローを持つ。
- `Store / Infrastructure` はデータの保存、読込、問い合わせ、外部接続の詳細を閉じ込める。
- 固定パス、永続ファイル、検索キャッシュ、秘密情報解決のような `スコープの広いリソース` は、専用の `Paths` / `Store` / `Service` 型へ閉じ込め、View や汎用 model ファイルへ散らしてはならない。
- `Shared` には画面から切り離せる pure logic を置き、複数画面から再利用できる状態を保つ。
- 画面導線から起動される機能でも、UI と無関係に成立すべき判定や状態遷移は domain / logic 側へ置き、UI はその状態の写像として組み立てる。

## モジュール境界

### App

- composition root、ルート遷移、Adaptive UI 判定、起動時 dependency graph の組み立てを担う。
- テスト支援用の launch mode、timeline、diagnostics marker も app 層に置く。

### Features

- `Home`
  - ホーム画面と、その周辺の設定系機能を担う。
- `Browse`
  - 一覧表示、検索結果表示、詳細表示などの閲覧機能を担う。
- `FeedCache`
  - データ更新、キャッシュ保守、初期表示用データ、状態集約を担う。

### Infrastructure

- YouTube feed、YouTube search API、URL / handle 解決など、外部接続の責務を担う。

### Shared

- 画面非依存の pure logic と共有状態モデルを担う。

## 主要データフロー

### 起動

- 起動時は最小限の初期表示を先に成立させ、その裏で軽量な初期データだけを読み込む。
- 重いキャッシュ全体読込や外部更新は、初期表示の成立と切り分ける。
- 初期表示に必要な状態がそろった後で、次の画面へ遷移する。

### 更新フロー

- 明示的な更新要求は、鮮度確認、必要時の本体取得、キャッシュ反映、付随リソース更新の順に単一パイプラインで処理する。
- 更新対象の選定や優先順は UI ではなく内側の層で決定する。
- 全体更新と部分更新は入口が異なっても、内部では同じ責務分離に従う。

### 詳細表示と局所更新

- 一覧から詳細へ渡る文脈情報は route context として保持し、表示に必要な最小情報を即時反映できる形にする。
- 局所更新は、表示対象に必要なデータが不足している場合だけ起動し、不要な全体更新へ広げない。
- 進行状態の判定は domain / logic 側で持ち、UI はその状態を写像する。

### 外部検索

- 外部検索は、既存キャッシュの読込と明示的な再取得を分離する。
- 検索結果は複数の取得経路を統合し、詳細補完と不要データ除外を経て 1 つの結果集合へ正規化する。
- 検索結果キャッシュは通常の閲覧キャッシュと分離し、履歴更新やマージ規則は内側の層で決定する。
- 表示件数や進行状態のような presentation state は UI 部品ではなく logic 側で保持し、UI はその写像を表示する。

## データとキャッシュの境界

- bootstrap と本体キャッシュは分ける。
- channel registry はチャンネル設定の唯一の正本として別保存する。
- YouTube 検索結果キャッシュは通常の動画キャッシュと別ファイルで保持する。
- バックアップはチャンネル設定だけを対象とし、動画キャッシュやサムネイルは含めない。
- チャンネル削除や全設定リセットでは、registry、channel state、video cache、search cache、thumbnail cache の整合性を同じ責務境界で保つ。

## Adaptive UI 方針

- 機能差分とレイアウト差分を分け、機能は共通、表現差分だけを Adaptive UI へ閉じ込める。
- 幅の広い環境では標準的な分割ナビゲーション構成を使い、単独画面レイアウトと分割レイアウトを切り替える。
- 機能契約やデータ契約は端末サイズで変えず、差分はレイアウト表現へ閉じ込める。
- 1 列リストは複数列化せず、本文幅だけを読みやすい範囲へ制限する。

## テストアーキテクチャ

- `unit test`
  - UI 非依存の契約を担保する。
- `UI test`
  - 画面層でしか観測できない契約を担保する。
- UI から起動される機能でも、まず domain / logic 側でテスト固定し、そのうえで UI を写像として確認する。
- 観測が不安定になりやすい導線では、test support によって同じ機能契約を安定して観測できるようにする。

## Concurrency と Build

- 画面駆動の型だけを `@MainActor` とし、永続化モデルや parser、store は UI 文脈へ固定しない。
- build 検証は `error 0` に加えて `warning 0` を成立条件とする。
- 計測は `scripts/collect_metrics.sh` を正本とし、同一の全体実行から build、test、起動性能を取得する。

## Observability

- 実機調査で必要なランタイムログは、Xcode コンソールへ `[YoutubeFeeder]` を先頭に付けた 1 行ログとして出力する。
- ログは `検索開始`、`キャッシュ hit / miss`、`外部 API 要求の開始 / 完了`、`キャッシュ反映`、`失敗時の fallback` のような境界イベントへ絞り、動画単位や item 単位の大量出力は避ける。
- API キー、完全な request URL、巨大な response body は出力せず、失敗時も本文は短い preview に切り詰める。
- キャンセルは通信失敗と分けて記録し、`画面`, `coordinator`, `service`, `transport` のどこで中断を観測したか追える形にする。
- キャンセルはユーザー向け失敗文言へそのまま出さず、必要な情報は調査ログで追う。
