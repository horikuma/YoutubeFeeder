# YoutubeFeeder Architecture

この文書は、YoutubeFeeder の採用アーキテクチャ、責務境界、依存方向、データフロー、テスト方針を定める設計文書である。本書は「このプロダクトでどう設計するか」を扱う。

文書群の役割分担と文書運用ルールは [rules-update-documents.md](../rules/rules-update-documents.md) を参照する。

## プロダクト前提

- 本プロダクトは Swift / SwiftUI で実装する iOS アプリである。
- 起動性能、操作中の軽さ、ローカルキャッシュを正本とする閲覧体験を長期的に損なわない。
- `iPhone` と `iPad` は同一機能を提供し、差分は Adaptive UI に沿ったレイアウト表現へ閉じ込める。
- 起動性能と操作中の軽さを優先し、起動直後は軽量な初期データだけで最初の画面を成立させる。
- 外部連携は YouTube feed と YouTube Data API を中心に構成し、ローカルキャッシュを正本として閲覧体験を安定させる。

## 採用アーキテクチャ

- 現在の基本モデルは `MVVM + Clean Architecture` とする。
- `View`
  - SwiftUI の画面と表示部品を担う。
  - 表示上の一時状態、binding、animation、dialog、render probe、描画到達の観測だけを持つ。
  - 画面単位の非同期 orchestration、状態分岐、副作用起動、event log を持たない。
- `ViewModel`
  - 画面単位の state、非同期 orchestration、状態分岐、副作用起動、event log を担う。
  - 対象画面と同じ feature 配下に置き、View からは UI trigger と表示写像だけを受ける。
- `Coordinator`
  - 複数画面から共有される state と service / use case 入口を担う。
  - 特定 View の presentation mode、paging cursor、遅延選択、画面固有 orchestration を持たない。
- `Service / Use Case`
  - 機能単位で意味のある処理のまとまりを担う。
- `Store / Infrastructure`
  - 永続化、固定パス、キャッシュ、外部 API 通信を担う。
- 標準フレームワークや Apple 推奨パターンで十分に表現できる責務は、独自抽象よりそちらを優先する。
- 独自実装や標準から外れた方式を選ぶ場合は、必要性と理由を説明できる状態を保つ。
- MVVM を守るためだけの protocol 分割、値の受け渡しラッパー、薄い中継層は増やさず、`pure logic`、`store`、`external service` へ意味のある単位で分割する。

## レイヤ責務と依存方向

- 依存方向は `View -> ViewModel -> Coordinator -> Service / Use Case -> Store or Infrastructure` を原則とする。
- `View` は I/O を直接持たず、外部通信、永続化、複雑な判定は内側の層へ委譲する。
- `View` は表示上の一時状態、アニメーション状態、入力途中値、フォーカス状態、ダイアログ状態を持ってよいが、複数 View 間で共有される状態、永続化される状態、非同期結果に依存する状態は PureLogic 側の正本として扱う。
- `View` や表示部品の命名では、機能を先に、操作差分を後ろに置き、共通核と wrapper の関係が名前から読める状態を保つ。
- `ViewModel` は UI と Coordinator の仲介を担うが、ファイル形式や API 呼び出しの細部を抱え込まない。
- `ViewModel` は `1 画面の orchestration` に責務を寄せ、画面描画専用の細かな値変換や単純な表示状態まで過剰に抱え込まない。
- `Coordinator` は UI と永続化の共有入口を担うが、画面固有の presentation state を集約しない。
- `ViewModel` / `Coordinator` の健全性改善では、警告を消すためだけに private 状態や内部 helper を外へ公開せず、まず値型、表示部品、DTO、純粋補助ロジックの順に外出しする。
- `Service / Use Case` は UI 文脈から独立して成立する判定、状態遷移、マージ、更新フローを持つ。
- `Service / Use Case` を `Read` / `Write` で分ける場合は、依存方向と副作用境界を固定するための分解として扱い、同じデータを扱うことだけを根拠に共通 superclass や抽象親型へ再統合してはならない。
- `Store / Infrastructure` はデータの保存、読込、問い合わせ、外部接続の詳細を閉じ込める。
- 固定パス、永続ファイル、検索キャッシュ、秘密情報解決のような `スコープの広いリソース` は、専用の `Paths` / `Store` / `Service` 型へ閉じ込め、View や汎用 model ファイルへ散らしてはならない。
- ホームのように `件数` や `鮮度` だけが欲しい導線では、動画配列を含む大きい永続本体を毎回 decode せず、summary 用の軽量永続物から先に読む。
- 動画・チャンネル・検索履歴の正本は `SQLite` に寄せ、表示に直接使う固定文字列は row 側へ保持してよい。ただし raw 値と表示値の重複は同一更新点から生成されることを前提にする。
- `Shared` には複数 feature から再利用できる画面非依存 pure logic だけを置く。
- 画面固有 pure logic は、対象画面と同じ feature 配下へ置く。
- 画面導線から起動される機能でも、UI と無関係に成立すべき判定や状態遷移は domain / logic 側へ置き、UI はその状態の写像として組み立てる。

## 画面責務の固定配置

- 画面単位の `async task`、`refresh`、`prewarm`、`paging`、`split selection`、`delete / export / import / reset` の実行開始は、対象画面の ViewModel に固定する。
- View は gesture、button、menu、refresh command の UI trigger を ViewModel へ渡すだけにする。
- View は render probe、描画到達、表示用 binding、animation、dialog、UI 部品の組み立てを担う。
- event log は ViewModel に置く。
- rendering observation は View に置く。
- PureLogic は I/O、logger、`Task.sleep`、`MainActor.run`、副作用起動を持たない。
- Coordinator は複数画面で共有される refresh progress、manual refresh count、home system status、remote search managed task、service / use case 入口を持ってよい。
- Coordinator は特定画面の visible count、chip mode、selected split context、playlist paging cursor、prewarm host mounting state を持たない。
- 局所変更で迷う場合は、まず `View`、`ViewModel`、`feature-local Logic`、`Coordinator`、`Service / Use Case` の順に責務を照合する。

## モジュール境界

### App

- composition root、ルート遷移、Adaptive UI 判定、起動時 dependency graph の組み立てを担う。
- テスト支援用の launch mode、timeline、diagnostics marker も app 層に置く。

### Features

- `Home`
  - ホーム画面と、その周辺の設定系機能を担う。
  - 起動時 refresh、scheduler 起動、YouTube 検索 prewarm、export / import / reset の画面 orchestration は `HomeScreenViewModel` に置く。
  - ホーム画面固有の pure logic は `Home` feature 配下へ置く。
- `Browse`
  - 一覧表示、検索結果表示、詳細表示などの閲覧機能を担う。
  - ローカルキャッシュ検索と YouTube 検索は同じ feature に置くが、検索 state の orchestration と compact / regular / split detail の表示責務は別ファイルへ分けて保つ。
  - YouTube 検索の snapshot 読込、refresh、split 遅延選択、paging、event log は `RemoteSearchResultsViewModel` に置く。
  - チャンネル一覧の split detail 選択、playlist 表示、paging、削除実行、refresh 起動、event log は `ChannelBrowseViewModel` に置く。
  - Browse 画面固有の pure logic は `Browse` feature 配下へ置く。
  - プレイリスト閲覧は、`View -> ViewModel -> Coordinator -> Playlist Use Case -> Infrastructure` の経路で扱い、検索機能や検索結果キャッシュへ依存しない。
- `FeedCache`
  - データ更新、キャッシュ保守、初期表示用データ、状態集約を担う。
  - 値型は storage / progress / channel / remote search のように意味単位で分け、巨大な model ファイルへ再集約しない。
  - `FeedCacheCoordinator` から見た service 依存は `ユースケースService -> ReadService / WriteService` に固定し、`ReadService <-> WriteService` や `ユースケースService` 同士の循環依存を作ってはならない。
  - `FeedCacheReadService` は読取り、検索結果のマージ、表示用の整形だけを担い、保存・削除・整合性メンテナンス・thumbnail 反映のような副作用を持たない。
  - `FeedCacheWriteService` は FeedCache 系の保存、削除、bootstrap 永続化、整合性メンテナンス、thumbnail 反映の単一入口として扱い、書込み境界を coordinator や他 service へ分散させてはならない。
  - `Read` / `Write` 分解後も、両者を動画・チャンネル・検索履歴などデータ種別ごとの共通 superclass で束ねて依存方向を曖昧にしてはならない。

### Infrastructure

- YouTube feed、YouTube search API、URL / handle 解決など、外部接続の責務を担う。
- YouTube search は service 本体、公開 model、API response DTO、結果整列や mock 応答の補助ロジックを分け、通信 orchestration と decode 詳細を 1 ファイルへ混在させない。
- プレイリスト一覧取得、プレイリスト内動画取得、連続再生 URL 生成は、YouTube search API とは別の service / DTO 群へ閉じ込める。

### Shared

- 複数 feature で再利用する画面非依存の pure logic と共有 policy を担う。
- 画面固有の presentation state や feature-local state を置かない。

## 主要データフロー

### 起動

- 起動時は最小限の初期表示を先に成立させ、その裏で軽量な初期データだけを読み込む。
- 重いキャッシュ全体読込や外部更新は、初期表示の成立と切り分ける。
- 初期表示に必要な状態がそろった後で、次の画面へ遷移する。

### 更新フロー

- 明示的な更新要求は、鮮度確認、必要時の本体取得、キャッシュ反映、付随リソース更新の順に単一パイプラインで処理する。
- 更新対象の選定や優先順は UI ではなく内側の層で決定する。
- 全体更新と部分更新は入口が異なっても、内部では同じ責務分離に従う。
- ChannelRefresh のスケジューラは、壁時計に同期した発火と、更新実行中に発火したトリガーをドロップする判定だけを担う。
- ChannelRefresh のスケジューラは、feed 取得、キャッシュ反映、整合性メンテナンス、UI 反映を直接実行しない。
- ChannelRefresh の更新処理は、対象選定、feed 取得、キャッシュ反映、整合性メンテナンス、UI 反映を 1 回の有限処理として実行し、完了後に自分自身を再起動しない。
- 全チャンネルリフレッシュと短周期リフレッシュは、起動元が異なっても同じ更新処理の入口へ集約し、対象選定だけを種別ごとに分ける。

### 詳細表示と局所更新

- 一覧から詳細へ渡る文脈情報は route context として保持し、表示に必要な最小情報を即時反映できる形にする。
- 局所更新は、表示対象に必要なデータが不足している場合だけ起動し、不要な全体更新へ広げない。
- 進行状態の判定は domain / logic 側で持ち、UI はその状態を写像する。

### 外部検索

- 外部検索は、既存キャッシュの読込と明示的な再取得を分離する。
- 検索結果は複数の取得経路を統合し、詳細補完と不要データ除外を経て 1 つの結果集合へ正規化する。
- 検索結果キャッシュは通常の閲覧キャッシュと分離し、履歴更新やマージ規則は内側の層で決定する。
- 表示件数や進行状態のような presentation state は UI 部品ではなく feature-local logic / ViewModel 側で保持し、UI はその写像を表示する。
- YouTube 検索画面では、snapshot 読込、明示 refresh、split 初期選択、split 遅延読込、split paging、event log を ViewModel が束ねる。
- YouTube 検索結果の compact / regular / split detail View は表示写像と render observation に閉じる。

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
- 体感性能を比較したい導線では、UI test から読める hidden diagnostics を使い、同じ操作区間の elapsed ms を fixture 差分つきで取得できる状態を保つ。

## Concurrency と Build

- 画面駆動の型だけを `@MainActor` とし、永続化モデルや parser、store は UI 文脈へ固定しない。
- 起動直後の MainActor を長時間塞ぐ file decode は避け、ホームの初期表示に不要な大きい cache decode を挟まない。
- build 検証は `error 0` に加えて `warning 0` を成立条件とする。
- 計測は `scripts/metrics-collect` を build と起動性能の正本、`scripts/metrics-test-collect` を test 所要時間の正本とし、起動性能はホーム初期表示直後だけを通る最小 UI test 経路から取得する。

## Observability

- 実機調査で必要なランタイムログは、Xcode コンソールへ `[YoutubeFeeder]` を先頭に付けた 1 行ログとして出力する。
- ログは `app launch`、`splash / home 表示`、`検索開始`、`キャッシュ hit / miss`、`外部 API 要求の開始 / 完了`、`キャッシュ反映`、`失敗時の fallback` のような境界イベントへ絞り、動画単位や item 単位の大量出力は避ける。
- 画面イベントログは ViewModel に置き、render probe や描画到達の観測は View に置く。
- API キー、完全な request URL、巨大な response body は出力せず、失敗時も本文は短い preview に切り詰める。
- キャンセルは通信失敗と分けて記録し、`画面`, `coordinator`, `service`, `transport` のどこで中断を観測したか追える形にする。
- キャンセルはユーザー向け失敗文言へそのまま出さず、必要な情報は調査ログで追う。
- `pull-to-refresh` は UI task そのものを検索処理の所有者にせず、実取得は内側の managed task へ委譲して View の再構成や離脱に引きずられにくくする。
- iPad split のように複数ペインが同時に組み上がる導線では、ホーム操作、画面表示、詳細読込開始・完了の境界を runtime diagnostics と console lifecycle log の両方に残し、コンソール目視と UI test の両方で同じ指標系を見られるようにする。
