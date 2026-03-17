# HelloWorld Architecture

この文書は、HelloWorld の実装構造、責務分担、データフロー、テスト配置をまとめた設計文書です。`rules.md` が上位方針を定め、`spec.md` が機能仕様を定め、本書はその 2 つを現在の実装へ落とし込むための詳細を扱います。

## 文書の役割

- [rules.md](rules.md)
  - 根幹普遍の方針、変更判断、文書運用、変更管理を定める。
- [spec.md](spec.md)
  - ユーザー向け機能と画面の振る舞いを定める。
- `architecture.md`
  - 現在の実装構造、責務境界、データフロー、テスト配置を定める。

## 現在のプロダクト構成

- アプリは YouTube チャンネル群の feed を取得し、ローカルキャッシュを維持しながら閲覧する iOS アプリである。
- 現在の主導線は `ホーム画面`、`チャンネル一覧`、`全動画一覧`、`チャンネル別動画一覧` で構成する。
- 起動時は `LaunchScreenView` を表示し、その裏で軽量 bootstrap を読み込んでホーム画面へ遷移する。
- ホーム画面はダッシュボードではなく、一覧画面への導線を担う。
- ホーム画面には操作タイルとは別に、非操作のシステム状況タイルを 1 枚置く。

## 採用アーキテクチャ

- 基本モデルは `MVVM + Clean Architecture` とする。
- `View`
  - SwiftUI 画面。
  - 一時的な UI 状態、アニメーション、選択、ダイアログ状態を持つ。
- `ViewModel / Coordinator`
  - 画面や機能単位の state と orchestration を担う。
  - 現在は `FeedCacheCoordinator` が maintenance 文脈を横断する view model として機能する。
- `UseCase / Service`
  - registry 更新、検索再取得、ホーム状態集約、チャンネル同期など、意味のある処理単位を担う。
- `Store / Infrastructure`
  - 永続化、キャッシュ、外部 API 通信、固定パス解決を担う。
- dependency graph の組み立ては `App` 層で行い、`ViewModel` 自身が `Store` や `Service` を new しない。

## ディレクトリ責務

### App

- [HelloWorld/App/HelloWorldApp.swift](HelloWorld/App/HelloWorldApp.swift)
  - アプリ起動入口。
- [HelloWorld/App/AppDependencies.swift](HelloWorld/App/AppDependencies.swift)
  - composition root。
  - `FeedCacheCoordinator` へ渡す live dependency を組み立てる。
- [HelloWorld/App/ContentView.swift](HelloWorld/App/ContentView.swift)
  - ルート画面。
  - `LaunchScreenView` からホーム画面へ遷移する。
  - `NavigationStack` と `MaintenanceRoute` を束ねる。
  - app layer で dependency graph を組み立て、view model へ注入する。
- [HelloWorld/App/AppLayout.swift](HelloWorld/App/AppLayout.swift)
  - `horizontalSizeClass` を主な基準として、単独画面と分割レイアウトの差分を吸収する。
- [HelloWorld/App/AppFormatting.swift](HelloWorld/App/AppFormatting.swift)
  - 日付などの共通 formatter。
- [HelloWorld/App/Support/AppTestSupport.swift](HelloWorld/App/Support/AppTestSupport.swift)
  - UI テスト用 launch mode、診断タイムライン、fixture seed、test marker。
  - UI テスト用の初期遷移指定。
  - 起動性能計測用の timeline marker。
  - 実機調査用のランタイムイベントログと hidden diagnostics marker。
- [Config/AppConfig.xcconfig](Config/AppConfig.xcconfig)
  - アプリ共通の build 設定。
  - optional include の `LocalSecrets.xcconfig` からローカル秘密情報を受ける。
  - `AppIntents` を使わない target でも warning-free build を維持するため、弱リンク設定を集約する。

### Features

- [HelloWorld/Features/Home/HomeScreenView.swift](HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面本体。
  - 手動更新と一覧画面への導線。
  - `Menu` ベースのチャンネル一覧ソート選択。
  - キャッシュ検索と YouTube 検索結果画面への導線。
  - チャンネル登録結果のフィードバック表示。
  - この端末内バックアップの書き出し / 読み戻し導線と結果表示。
  - 全設定リセットの確認 UI と結果表示。
  - 非操作のシステム状況タイル表示。
- [HelloWorld/Features/Home/ChannelRegistrationView.swift](HelloWorld/Features/Home/ChannelRegistrationView.swift)
  - チャンネル登録画面本体。
  - 入力、登録実行、登録結果フィードバックを担う。
- [HelloWorld/Features/Home/HomeUIComponents.swift](HelloWorld/Features/Home/HomeUIComponents.swift)
  - ホーム画面の表示部品。
- [HelloWorld/Features/Home/HomeRoutes.swift](HelloWorld/Features/Home/HomeRoutes.swift)
  - 一覧系画面への遷移定義。
  - チャンネル一覧には並び順 descriptor を渡す。
- [HelloWorld/Features/Browse/ChannelBrowseViews.swift](HelloWorld/Features/Browse/ChannelBrowseViews.swift)
  - チャンネル一覧、全動画一覧、分割チャンネル閲覧。
  - 分割チャンネル閲覧は `NavigationSplitView` を使う。
  - 選択された並び順 descriptor を一覧サブタイトルと並び順へ反映する。
  - チャンネル一覧の先頭には、非操作の `Tips` タイルを共通表示し、件数、並び順、基本操作を要約する。
  - 長押しメニューからチャンネル削除導線を出す。
- [HelloWorld/Features/Browse/SearchResultsViews.swift](HelloWorld/Features/Browse/SearchResultsViews.swift)
  - 固定キーワード検索結果一覧、YouTube 検索結果一覧。
  - 固定キーワード検索結果画面では、一時的な件数チップを下部へ重ねて表示する。
  - 下部チップは自動タイマーでは閉じず、ユーザー操作が始まるまで表示を維持する。
  - YouTube 検索結果は 20 件ずつの段階表示と下端到達での追加読込を行う。
  - 分割レイアウトの YouTube 検索結果は `NavigationSplitView` で左に検索結果、右に選択中チャンネルの動画一覧を出す。
  - YouTube 検索結果からチャンネル画面へ入る時は、チャンネル名と選択動画 ID を route context として引き継ぐ。
  - 再生数は `videos.list` の `statistics.viewCount` を使ってタイル右下へ表示する。
- [HelloWorld/Features/Browse/BrowseViews.swift](HelloWorld/Features/Browse/BrowseViews.swift)
  - チャンネル別動画一覧。
  - チャンネル別動画一覧の pull-to-refresh は、そのチャンネル限定の強制更新へ接続する。
  - YouTube 検索結果からの遷移時は、ローカル channel cache が未作成、または選択動画が local feed cache に無い場合に自動 feed 更新する。
  - 初回タイトルは maintenance item や local cache を待たず、route context で受けたチャンネル名を即時表示へ使える。
  - 一覧ごとにタイルの通し番号を 1 から振り直して表示する。
  - 実機調査時は、チャンネル別動画一覧の更新ジェスチャーと一覧再読込の完了をランタイムログへ流す。
- [HelloWorld/Features/Browse/BrowseComponents.swift](HelloWorld/Features/Browse/BrowseComponents.swift)
  - 一覧系共通コンテナ `InteractiveListScreen`。
  - タイル部品、サムネイル表示、戻るスワイプ modifier など、一覧画面から共有される表示部品を担う。
  - 動画タイル右下の `No : 再生時間 再生数 (M/L)` バッジを担い、動画番号を右上へ重複表示しない。
- [HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift](HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - UI と永続化の仲介。
  - ホーム画面 bootstrap、手動更新、一覧用データ読込、更新状態の管理。
  - チャンネル削除と整合性メンテナンスの起点。
  - 全設定リセット時の状態破棄とホーム状態の初期化。
  - 全体更新と単独チャンネル強制更新の両方を制御する。
  - チャンネル別動画一覧では、通常キャッシュと検索キャッシュをチャンネル単位でマージして返す。
  - 実機調査用に、単独チャンネル更新の開始/終了、フィード取得、整合性メンテナンス、UI 反映/保留を構造化ログで出力する。
- [HelloWorld/Features/FeedCache/FeedChannelSyncService.swift](HelloWorld/Features/FeedCache/FeedChannelSyncService.swift)
  - feed 取得、条件付き更新判定、store 反映を束ねる更新実行サービス。
  - coordinator からネットワーク / 永続化の細部を切り離し、更新 orchestration の責務を薄くする。
- [HelloWorld/Features/FeedCache/ChannelRegistryMaintenanceService.swift](HelloWorld/Features/FeedCache/ChannelRegistryMaintenanceService.swift)
  - チャンネル登録、削除、バックアップ入出力、全設定リセットの実処理を担う。
  - coordinator から registry と初期化まわりの変更責務を切り離す。
- [HelloWorld/Features/FeedCache/FeedCacheStore.swift](HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - ファイル永続化、snapshot 読込、thumbnail 保存。
  - チャンネル一覧描画用の集約データを返す。
  - 動画検索条件に一致する件数と一覧を返す。
  - 参照切れ動画と不要サムネイルの整合性メンテナンスを行う。
  - アプリ内キャッシュ一式の破棄を行う。
- [HelloWorld/Features/FeedCache/RemoteVideoSearchCacheStore.swift](HelloWorld/Features/FeedCache/RemoteVideoSearchCacheStore.swift)
  - YouTube 検索結果の端末内キャッシュを永続化する。
  - 検索キャッシュの鮮度判定と件数要約を返す。
  - 同一キーワードの検索履歴を append / merge し、クリア操作を担う。
  - 全検索履歴の一括削除を担う。
- [HelloWorld/Features/FeedCache/RemoteVideoSearchService.swift](HelloWorld/Features/FeedCache/RemoteVideoSearchService.swift)
  - YouTube 検索 API の再取得、端末内検索キャッシュの読込、TTL 判定、履歴クリアを束ねる。
- [HelloWorld/Features/FeedCache/HomeSystemStatusService.swift](HelloWorld/Features/FeedCache/HomeSystemStatusService.swift)
  - ホーム画面へ出すシステム状況を集約する。
- [HelloWorld/Features/FeedCache/FeedCachePaths.swift](HelloWorld/Features/FeedCache/FeedCachePaths.swift)
  - キャッシュ、bootstrap、registry、検索キャッシュ、thumbnail の固定パスを集約する。
- [HelloWorld/Features/FeedCache/FeedBootstrapStore.swift](HelloWorld/Features/FeedCache/FeedBootstrapStore.swift)
  - ホーム初期表示用 bootstrap の読込と整形を担う。
- [HelloWorld/Features/FeedCache/ChannelRegistryStore.swift](HelloWorld/Features/FeedCache/ChannelRegistryStore.swift)
  - channel registry と端末内バックアップ JSON の永続化責務を担う。
- [HelloWorld/Features/FeedCache/FeedCacheModels.swift](HelloWorld/Features/FeedCache/FeedCacheModels.swift)
  - キャッシュ用モデル、進捗モデル、検索結果モデルなど、I/O を持たない値型を集約する。

### Infrastructure

- [HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift](HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - YouTube feed の取得、更新判定、XML パース。
  - 条件付き取得用の `ETag` と `Last-Modified` を扱う。
  - `@handle`、チャンネル URL、動画 URL から `Channel ID` を解決する。
  - 登録直後のフィードバック用に最新動画要約の取得にも使う。
- [HelloWorld/Infrastructure/YouTube/YouTubeSearchService.swift](HelloWorld/Infrastructure/YouTube/YouTubeSearchService.swift)
  - YouTube Data API v3 の search endpoint を呼び出す。
  - API キー解決とレスポンスの表示用モデル変換を担う。
  - API キーは環境変数または `Info.plist` 経由の build setting 注入から受ける。
  - API キーは URL クエリへ載せず、HTTP header で渡す。
  - `medium` と `long` の 2 検索を束ね、`videos.list` でライブ除外と最終整形を行う。
  - `videos.list` は動画 ID を 50 件単位でまとめて呼び、ヒット件数ぶん 1 件ずつ API を叩かない。

### Shared

- [HelloWorld/Shared/AppLogic.swift](HelloWorld/Shared/AppLogic.swift)
  - `BackSwipePolicy`
  - `VideoOpenPolicy`
  - `FeedOrdering`
  - `ChannelBrowseSortDescriptor`
  - 画面から切り離せる pure logic を集約する。

### Resources

- [HelloWorld/Resources/TestFixtures/UITest.bootstrap.json](HelloWorld/Resources/TestFixtures/UITest.bootstrap.json)
  - UI テスト用 bootstrap。
- [HelloWorld/Resources/TestFixtures/UITest.cache.json](HelloWorld/Resources/TestFixtures/UITest.cache.json)
  - UI テスト用 cache。
- [scripts/stream_device_runtime_logs.sh](scripts/stream_device_runtime_logs.sh)
  - 物理 `iPhone 12 mini` に `HELLOWORLD_RUNTIME_LOGGING=1` 付きでアプリを foreground 起動し、stdout ベースのランタイムログをコンソールへ流す。
- [scripts/health_barometer.sh](scripts/health_barometer.sh)
  - Swift ファイル行数、関数行数、型数、`@Published` 数を集計し、責務越境と複雑度の早期検知に使う。

## データとキャッシュ構造

- キャッシュは永続データとして扱う。
- チャンネル一覧は `Channel ID` を主キーとして別ファイルに永続化し、これを唯一の正本とする。
- 各チャンネルには登録日時を保持し、一覧ソートの指標として再利用する。
- バックアップでは、現在登録されている全チャンネル情報を JSON として端末内の固定ファイルへ保存する。
- インポートではローカルのチャンネル設定をその JSON で置き換え、動画やサムネイルは転送しない。
- YouTube 検索結果は `remote-search-<keyword>.json` として別ファイル保存し、通常キャッシュと責務を分ける。
- 検索キャッシュは長めの TTL で扱い、通常の再訪では API 再取得を避ける。
- 検索画面表示時はキャッシュだけを読む。実検索は pull-to-refresh でだけ走らせ、API クォータ消費のタイミングをユーザーへ委ねる。
- YouTube 検索結果は同一キーワードで上書きせず、動画 ID 単位でマージしながら蓄積する。
- チャンネル別動画一覧は feed cache と検索 cache を channel ID 単位で突き合わせて統合表示する。
- ローカル秘密情報は `Config/LocalSecrets.xcconfig` に置き、`.gitignore` で追跡対象外にする。
- バックアップの固定パスは `~/Documents/HelloWorld/channel-registry.json` 相当とし、iPhone / Mac とも同じ JSON 形式を使う。
- チャンネル削除時は registry、channel state、video cache、thumbnail cache を一貫して整理する。
- 全設定リセット時は registry、channel state、video cache、bootstrap、検索履歴、thumbnail cache を一括削除し、`Documents` 側バックアップは残す。
- 通常の更新経路では、整合性メンテナンスを軽い定期処理として差し込む。
- バックアップ読込後の最新情報再取得は UI をブロックせず、バックグラウンド task で進める。
- 軽量 bootstrap と本体 cache を分ける。
  - bootstrap: ホーム画面を即時表示するための軽量情報
  - cache: チャンネル状態、動画メタデータ、サムネイル位置を含む本体
- UI は起動直後に本体 cache を読む前提にしない。
- thumbnail は表示高速化のためにローカル保存する。
- 一覧画面表示中は live update を止め、戻った時にまとめて反映する。

## 更新フロー

- ホーム画面の pull-to-refresh を手動更新の入口とする。
- チャンネル別動画一覧の pull-to-refresh は、条件付き取得ではなく `fetchLatestFeed` による単独チャンネルの強制更新へつなぐ。
- 更新は `1チャンネル = 更新確認 -> 必要なら本体取得 -> 必要なら新着動画のサムネイル取得` の単一パイプラインで処理する。
- 同時処理数は最大 `3` とする。
- 更新順は `latestPublishedAt` 降順、次に `lastSuccessAt` 降順、最後に `lastCheckedAt` 昇順とする。
- 更新確認には条件付き取得を使い、更新が無ければ本体取得を避ける。
- サムネイル取得は、その回に見つかった新着動画だけに行う。

## UI 実装方針

- `iPhone` と `iPad` は同一機能を提供し、差分は Adaptive UI に沿ったレイアウト表現へ閉じ込める。
- 機能ロジックは共通化し、レイアウト差は `AppLayout` で吸収する。
- 1 列リストは複数列化せず、Apple の `readableContentGuide` 相当の考え方で本文幅だけを制限する。
- 一覧画面の振る舞いは `InteractiveListScreen` に集約し、画面ごとの差異を作らない。
- 動画系一覧の番号表示は 0 始まりとし、右下の情報バッジへ統合する。
- 戻るスワイプの判定は `BackSwipePolicy` を使う。
- 動画を開く判定は `VideoOpenPolicy` を使う。
- チャンネル一覧の分割表示は SwiftUI の適応的コンテナを優先し、現在は `NavigationSplitView` を採用する。

## Concurrency と Build 検証

- project 全体の `SWIFT_DEFAULT_ACTOR_ISOLATION` は `MainActor` へ広げず、UI 起点で本当に必要な型だけを `@MainActor` とする。
- `FeedCacheCoordinator` や UI test support のような画面駆動の型は明示的に `@MainActor` を付け、永続化モデルや parser、store の値型は非 UI 文脈で再利用できる状態を保つ。
- build 検証は `error 0` だけでなく `warning 0` も成立条件に含める。

## 実装責務の要点

- [HelloWorld/App/ContentView.swift](HelloWorld/App/ContentView.swift)
  - ルート画面、起動画面からホーム画面への遷移、ルートレベルの navigation を担う。
- [HelloWorld/Features/Home/HomeScreenView.swift](HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面の表示、手動更新導線、一覧ソート選択、バックアップ、全設定リセットを担う。
- [HelloWorld/Features/Browse/ChannelBrowseViews.swift](HelloWorld/Features/Browse/ChannelBrowseViews.swift)
  - チャンネル一覧、全動画一覧、チャンネル削除導線を担う。
- [HelloWorld/Features/Browse/SearchResultsViews.swift](HelloWorld/Features/Browse/SearchResultsViews.swift)
  - キャッシュ検索と YouTube 検索結果画面、および件数チップを担う。
- [HelloWorld/Features/Browse/BrowseViews.swift](HelloWorld/Features/Browse/BrowseViews.swift)
  - チャンネル別動画一覧を担う。
- [HelloWorld/Features/Browse/BrowseComponents.swift](HelloWorld/Features/Browse/BrowseComponents.swift)
  - 一覧系 UI で共有される表示部品と共通レイアウトを担う。
- [HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift](HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - bootstrap 読込、手動更新フロー制御、一覧用 state 公開、live update 抑制、引き継ぎ後の再読込を担う。
- [HelloWorld/Features/FeedCache/FeedChannelSyncService.swift](HelloWorld/Features/FeedCache/FeedChannelSyncService.swift)
  - 個別チャンネルの同期実行と store 反映を担う。
- [HelloWorld/Features/FeedCache/ChannelRegistryMaintenanceService.swift](HelloWorld/Features/FeedCache/ChannelRegistryMaintenanceService.swift)
  - registry 更新、バックアップ入出力、全設定リセットを担う。
- [HelloWorld/Features/FeedCache/FeedCacheStore.swift](HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - cache.json、bootstrap、thumbnail、channel registry の読取利用と整合性メンテナンスを担う。
- [HelloWorld/Features/FeedCache/RemoteVideoSearchCacheStore.swift](HelloWorld/Features/FeedCache/RemoteVideoSearchCacheStore.swift)
  - 検索結果キャッシュの永続化、マージ、クリアを担う。
- [HelloWorld/Features/FeedCache/RemoteVideoSearchService.swift](HelloWorld/Features/FeedCache/RemoteVideoSearchService.swift)
  - 検索 API と検索キャッシュを束ねた再取得フローを担う。
- [HelloWorld/Features/FeedCache/HomeSystemStatusService.swift](HelloWorld/Features/FeedCache/HomeSystemStatusService.swift)
  - ホームのシステム状況集約を担う。
- [HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift](HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - 更新確認、本体取得、XML parser を担う。
- [HelloWorld/Infrastructure/YouTube/YouTubeSearchService.swift](HelloWorld/Infrastructure/YouTube/YouTubeSearchService.swift)
  - YouTube 検索 API 呼び出しを担う。
- [HelloWorld/Shared/AppLogic.swift](HelloWorld/Shared/AppLogic.swift)
  - スワイプ判定、長押し判定、一覧並び順、鮮度判定などの pure logic を担う。
  - `RemoteSearchPresentationState` で YouTube 検索結果画面の chip 可視状態、段階表示件数、split 初期選択を UI から切り離して扱う。

## テスト構造

### テスト対象と実行方針

- 継続運用のテストターゲットは `iPhone 12 mini` のみとする。
- 他機種での補助確認は任意であり、正本の回帰確認には含めない。
- UI テストは、重複する起動確認をワークフロー単位へまとめ、必要な画面は test support の初期遷移指定で直接開けるようにする。
- CLI からの `xcodebuild` と計測スクリプトは、build 生成物を同期対象ディレクトリの外へ出す。
  - `DerivedData` は `~/Library/Caches/Codex/HelloWorld/DerivedData` を使い、`Documents` 配下の file provider 属性が codesign を壊さないようにする。
- 基本コマンドは次を使う。

```bash
xcodebuild test \
  -project HelloWorld.xcodeproj \
  -scheme HelloWorld \
  -destination 'platform=iOS Simulator,name=iPhone 12 mini' \
  -derivedDataPath ~/Library/Caches/Codex/HelloWorld/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

### 現在あるテストの責務

#### Unit Test

- [HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift](HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift)
  - uploads playlist ID 変換、feed parser。
- [HelloWorldTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift](HelloWorldTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift)
  - channel registry の現行形式、バックアップ export / import。
- [HelloWorldTests/Unit/Storage/FeedCacheMaintenanceTests.swift](HelloWorldTests/Unit/Storage/FeedCacheMaintenanceTests.swift)
  - チャンネル削除、整合性メンテナンス、全設定リセット後のバックアップ復旧。
- [HelloWorldTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift](HelloWorldTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift)
  - YouTube 検索キャッシュの鮮度判定。
- [HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift](HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift)
  - 戻るスワイプ判定。
- [HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift](HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift)
  - 優先順、鮮度判定。
- [HelloWorldTests/Unit/Layout/AppLayoutTests.swift](HelloWorldTests/Unit/Layout/AppLayoutTests.swift)
  - size class に応じたレイアウト切替。
- [HelloWorldTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift](HelloWorldTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift)
  - `Tips` サマリー文言と、YouTube 検索結果画面の presentation state。
- [HelloWorldTests/Support/TestMetricsObserver.swift](HelloWorldTests/Support/TestMetricsObserver.swift)
  - unit test の開始時刻、終了時刻、所要時間を観測し、`xcodebuild` ログへ構造化イベントを書き出す。

#### UI Test

- [HelloWorldUITests/Home/HomeScreenUITests.swift](HelloWorldUITests/Home/HomeScreenUITests.swift)
  - ホーム画面表示
  - `チャンネル` / `動画` 導線
  - モック refresh 経路
  - 起動タイムライン
  - `metrics-latest.md` 更新用の起動性能 JSON 書き出し
- [HelloWorldUITests/Browse/BrowseScreenUITests.swift](HelloWorldUITests/Browse/BrowseScreenUITests.swift)
  - 全動画一覧遷移
  - 一覧の縦スクロール
  - チャンネル別動画一覧の pull-to-refresh が選択中チャンネルだけを更新すること
  - YouTube 検索結果で refresh 後に chip がユーザー操作で閉じること
  - YouTube 検索結果からチャンネル画面へ入り、自動 refresh が走ること
- [HelloWorldUITests/Support/UITestCaseSupport.swift](HelloWorldUITests/Support/UITestCaseSupport.swift)
  - app 起動、timeline 解析、共通 wait。
- [HelloWorldUITests/Support/UITestMetricsObserver.swift](HelloWorldUITests/Support/UITestMetricsObserver.swift)
  - UI test の開始時刻、終了時刻、所要時間を観測し、`xcodebuild` ログへ構造化イベントを書き出す。

## テスト運用詳細

- UI テストは `HELLOWORLD_UI_TEST_MODE=1` を使い、fixture を app support 配下へ seed して実行する。
- 自動更新経路を確認したいテストだけ `HELLOWORLD_UI_TEST_AUTO_REFRESH=1` を使う。
- UI テストでは実ネットワークを使わない。
- hidden button の直接タップより、起動環境変数や marker による観測を優先する。
- スワイプ系 UI テストでは、必要に応じて `UITestAsyncActionTrigger` のような専用 trigger で同等イベントを発火してよい。
- `AppLayout` や `RemoteSearchPresentationState` のように pure logic へ切り出せる判定は unit test で固定し、UI テストでは OS 任せの adaptive layout そのものを過剰に再検証しない。
- 実機の再現調査では `scripts/stream_device_runtime_logs.sh` を使い、物理 `iPhone 12 mini` の foreground 起動とコンソール接続を同時に行う。
- UI テスト用 identifier は tappable な本体要素に付ける。
- 画面が描画されたことを示す marker と、主要要素が見えることの両方を待つ。
- 性能しきい値は simulator の揺れを考慮して設定する。
- `scripts/collect_metrics.sh` は `xcodebuild build-for-testing` と `test-without-building` を分離して時間を採取し、UI テストが書き出した起動性能 JSON を `metrics-latest.md` へ集約する。
- `scripts/collect_test_metrics.sh` は unit test と UI test を分けて実行し、各テストケースの開始時刻、終了時刻、所要時間を `test-metrics.md` へ集約する。
- `test-metrics.md` には、`logic` / `ui` の大分類に加えて、`Parsing` や `Home` のような領域分類、テスト ID、概要、時刻、所要時間を出力する。
- `scripts/health_barometer.sh` は、実装健康度の警告点を定量確認するための軽量点検コマンドとして扱う。
- 同スクリプトは Xcode の Scheme post-action や Run Script からも呼び出せるよう、CLI だけで完結する前提で設計する。
