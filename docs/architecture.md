# HelloWorld Architecture

この文書は、HelloWorld の採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を定める設計文書である。`rules.md` が上位方針、`spec.md` が要求仕様と機能仕様、`design.md` が詳細設計を担い、本書はその中間として「このプロダクトでどう設計するか」を扱う。

## 文書の役割

- [rules.md](./rules.md)
  - 上位方針、変更判断、文書運用、開発プロセスを定める。
- [spec.md](./spec.md)
  - ユーザーに見える要求仕様と機能仕様を定める。
- [architecture.md](./architecture.md)
  - 採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を定める。
- [design.md](./design.md)
  - ファイル単位、型単位、テスト単位の責務や構成など、詳細設計を定める。
- [gui.md](./human-view/gui.md)
  - GUI を人間向けに参照しやすく整理した資料。
- [design-overview.md](./human-view/design-overview.md)
  - 設計全体を人間向けに俯瞰しやすく整理した資料。

## プロダクト前提

- 本プロダクトは Swift / SwiftUI で実装する iOS アプリである。
- `iPhone` と `iPad` は同一機能を提供し、差分は Adaptive UI に沿ったレイアウト表現へ閉じ込める。
- 起動性能と操作中の軽さを優先し、起動直後は軽量 bootstrap を使ってホーム画面へ遷移する。
- 外部連携は YouTube feed と YouTube Data API を中心に構成し、ローカルキャッシュを正本として閲覧体験を安定させる。

## 採用アーキテクチャ

- 現在の基本モデルは `MVVM + Clean Architecture` とする。
- `View`
  - SwiftUI の画面と表示部品を担う。
  - 一時的な UI 状態、選択状態、アニメーション、ダイアログ状態を持ってよい。
- `Coordinator / ViewModel`
  - 画面や機能単位の state と orchestration を担う。
  - 現在は `FeedCacheCoordinator` が maintenance 文脈を横断する coordinator として機能する。
- `Service / Use Case`
  - registry 更新、検索再取得、ホーム状態集約、チャンネル同期など、意味のある処理単位を担う。
- `Store / Infrastructure`
  - 永続化、固定パス、キャッシュ、外部 API 通信を担う。
- 標準フレームワークや Apple 推奨パターンで十分に表現できる責務は、独自抽象よりそちらを優先する。
- 独自実装や標準から外れた方式を選ぶ場合は、必要性と理由を説明できる状態を保つ。

## レイヤ責務と依存方向

- 依存方向は `View -> Coordinator / ViewModel -> Service / Use Case -> Store or Infrastructure` を原則とする。
- `View` は I/O を直接持たず、外部通信、永続化、複雑な判定は内側の層へ委譲する。
- `Coordinator / ViewModel` は UI と永続化の仲介を担うが、ファイル形式や API 呼び出しの細部を抱え込まない。
- `Service / Use Case` は UI 文脈から独立して成立する判定、状態遷移、マージ、更新フローを持つ。
- `Store / Infrastructure` はデータの保存、読込、問い合わせ、外部接続の詳細を閉じ込める。
- `Shared` には画面から切り離せる pure logic を置き、複数画面から再利用できる状態を保つ。
- 画面導線から起動される機能でも、UI と無関係に成立すべき判定や状態遷移は domain / logic 側へ置き、UI はその状態の写像として組み立てる。

## モジュール境界

### App

- composition root、ルート遷移、Adaptive UI 判定、起動時 dependency graph の組み立てを担う。
- テスト支援用の launch mode、timeline、diagnostics marker も app 層に置く。

### Features

- `Home`
  - ホーム画面、チャンネル登録、バックアップ、全設定リセット、検索導線を担う。
- `Browse`
  - チャンネル一覧、動画一覧、検索結果一覧、チャンネル別動画一覧を担う。
- `FeedCache`
  - coordinator、更新 orchestration、registry 保守、検索キャッシュ、bootstrap 読込、ホーム状態集約を担う。

### Infrastructure

- YouTube feed、YouTube search API、URL / handle 解決など、外部接続の責務を担う。

### Shared

- 戻るスワイプ判定、一覧並び順、検索結果の presentation state など、画面非依存の pure logic を担う。

## 主要データフロー

### 起動

- 起動時は `LaunchScreenView` を表示し、その裏で bootstrap だけを読み込む。
- 本体キャッシュの全読込や feed 更新は起動時に自動開始しない。
- bootstrap 読込完了後にホーム画面へ遷移し、重い処理を初期表示の後ろへ追い出す。

### ホーム画面の手動更新

- ホーム画面の pull-to-refresh を唯一の全体手動更新入口とする。
- 更新順は `latestPublishedAt`、`lastSuccessAt`、`lastCheckedAt` を基準に決める。
- 更新は `更新確認 -> 必要なら本体取得 -> 必要なら新着動画のサムネイル取得` の単一パイプラインで処理する。
- 同時処理数は最大 `3` とする。

### チャンネル別動画一覧

- チャンネル別動画一覧の pull-to-refresh は、そのチャンネル限定の強制更新へ接続する。
- YouTube 検索結果から遷移した場合は、検索時のチャンネル名を route context として引き継ぎ、初回タイトルへ即時反映する。
- ローカル feed キャッシュが未作成、または選択動画が local cache に存在しない場合だけ、自動 feed 更新を行う。
- 自動 feed 更新中は、pull-to-refresh と同系統の上部進行表示でユーザーへ通知する。

### YouTube検索

- 画面表示時は検索キャッシュだけを読み、実検索は pull-to-refresh の明示操作でのみ行う。
- 検索は `medium` と `long` の 2 経路を束ね、`videos.list` で詳細補完とライブ除外を行う。
- 検索結果はキーワード単位で別キャッシュへ保存し、同一キーワードの履歴は動画 ID 単位でマージする。
- 再検索中の表示状態、段階表示件数、split 初期選択などの状態遷移は `RemoteSearchPresentationState` で保持し、UI はその写像を表示する。
- 再検索中は下部チップの古い要約を隠し、進行中表示を上部へ出す。

## データとキャッシュの境界

- bootstrap と本体キャッシュは分ける。
- channel registry はチャンネル設定の唯一の正本として別保存する。
- YouTube 検索結果キャッシュは通常の動画キャッシュと別ファイルで保持する。
- バックアップはチャンネル設定だけを対象とし、動画キャッシュやサムネイルは含めない。
- チャンネル削除や全設定リセットでは、registry、channel state、video cache、search cache、thumbnail cache の整合性を同じ責務境界で保つ。

## Adaptive UI 方針

- 機能差分とレイアウト差分を分け、機能は共通、表現差分だけを Adaptive UI へ閉じ込める。
- 幅の広い環境では `NavigationSplitView` を使い、単独画面レイアウトと分割レイアウトを切り替える。
- 検索結果や一覧の表示件数、読み込み、チップ表示などの機能契約は端末サイズで変えない。
- 1 列リストは複数列化せず、本文幅だけを読みやすい範囲へ制限する。

## テストアーキテクチャ

- `unit test`
  - parser、並び順、状態遷移、キャッシュ更新、検索結果マージなど、UI 非依存の契約を担保する。
- `UI test`
  - 画面遷移、主要導線、主要フィードバック、画面層でしか観測できない契約を担保する。
- UI から起動される機能でも、まず domain / logic 側でテスト固定し、そのうえで UI を写像として確認する。
- 実ジェスチャーが不安定な導線では、test support の trigger や marker により、同じ機能契約を安定して観測できるようにする。

## Concurrency と Build

- 画面駆動の型だけを `@MainActor` とし、永続化モデルや parser、store は UI 文脈へ固定しない。
- build 検証は `error 0` に加えて `warning 0` を成立条件とする。
- 計測は `scripts/collect_metrics.sh` を正本とし、同一の全体実行から build、test、起動性能を取得する。
