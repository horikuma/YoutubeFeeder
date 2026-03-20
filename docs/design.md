# HelloWorld Design

この文書は、HelloWorld の詳細設計を記述する正本である。ここでは、ファイル単位、型単位、テスト単位の責務を扱う。

文書群の役割分担と文書の切り分け基準は [document-rules.md](./document-rules.md)、文書運用ルールは [document-operations.md](./document-operations.md) を参照する。

## 実装単位の責務

### App

- [HelloWorldApp.swift](../HelloWorld/App/HelloWorldApp.swift)
  - アプリ起動入口。
  - app launch の lifecycle ログ開始。
- [AppDependencies.swift](../HelloWorld/App/AppDependencies.swift)
  - composition root。
  - live dependency の組み立て。
- [ContentView.swift](../HelloWorld/App/ContentView.swift)
  - ルート画面。
  - `LaunchScreenView` からホーム画面への遷移。
  - `NavigationStack` と route の束ね。
  - bootstrap 開始完了と maintenance enter の lifecycle ログ。
- [AppLayout.swift](../HelloWorld/App/AppLayout.swift)
  - `horizontalSizeClass` を主基準とする Adaptive UI 判定。
  - 単独画面と分割レイアウトの差分吸収。
- [AppConsoleLogger.swift](../HelloWorld/App/AppConsoleLogger.swift)
  - Xcode コンソール向けの 1 行ランタイムログ。
  - `[YoutubeFeeder]` 接頭辞、キーワード短縮、レスポンス preview の整形。
  - `app.lifecycle` と `youtube.search` の境界ログを共通整形する。
- [AppFormatting.swift](../HelloWorld/App/AppFormatting.swift)
  - 日付や数値の共通 formatter。
- [AppTestSupport.swift](../HelloWorld/App/Support/AppTestSupport.swift)
  - launch mode、fixture seed、timeline、test marker。
  - UI テスト用初期遷移指定。
  - mock / live を切り替える UI テスト launch mode。
  - 実機調査用 diagnostics。
  - YouTube検索 split 計測用 runtime diagnostics と `heavy` fixture seed。

### Features/Home

- [HomeScreenView.swift](../HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面本体。
  - 手動更新、検索導線、バックアップ、全設定リセット、システム状況表示。
  - YouTube検索タイル選択の runtime diagnostics 記録。
  - ホーム表示と YouTube検索タイル選択の lifecycle ログ。
- [ChannelRegistrationView.swift](../HelloWorld/Features/Home/ChannelRegistrationView.swift)
  - チャンネル登録画面。
  - 入力、解決、登録、結果表示。
- [HomeUIComponents.swift](../HelloWorld/Features/Home/HomeUIComponents.swift)
  - ホーム画面の表示部品。
  - splash 表示の lifecycle ログ。
- [HomeRoutes.swift](../HelloWorld/Features/Home/HomeRoutes.swift)
  - 一覧系画面への遷移定義。

### Features/Browse

- [ChannelBrowseViews.swift](../HelloWorld/Features/Browse/ChannelBrowseViews.swift)
  - チャンネル一覧、全動画一覧、分割チャンネル閲覧。
  - `Tips` タイル、並び順反映、削除導線。
- [SearchResultsViews.swift](../HelloWorld/Features/Browse/SearchResultsViews.swift)
  - 固定キーワード検索結果と YouTube 検索結果。
  - 下部チップ、上部進行表示、検索結果の UI 写像。
  - 画面出入り、snapshot 読込、再検索開始完了の境界ログ。
  - `refreshable` は trigger のみを担い、検索本体は coordinator の managed task へ委譲する。
  - iPad split では初期右ペイン読込を短く遅延させ、遷移直後はプレースホルダを表示する。
  - iPad split の初期右ペイン読込について、予約・開始・完了を runtime diagnostics へ記録する。
- [BrowseViews.swift](../HelloWorld/Features/Browse/BrowseViews.swift)
  - チャンネル別動画一覧。
  - 自動 feed 更新時の上部進行表示。
- [BrowseComponents.swift](../HelloWorld/Features/Browse/BrowseComponents.swift)
  - 一覧系共通コンテナ `InteractiveListScreen`。
  - `ChannelTile`、`ChannelSelectionTile`、`VideoTile`、戻るスワイプ modifier。

### Features/FeedCache

- [FeedCacheCoordinator.swift](../HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - UI と永続化の仲介。
  - bootstrap 読込、一覧データ読込、手動更新、単独チャンネル更新、検索結果読込。
  - YouTube 検索の snapshot hit / miss、refresh failure fallback、cancel fallback の境界ログ。
  - YouTube 検索の managed task の生成、再利用管理。
- [FeedChannelSyncService.swift](../HelloWorld/Features/FeedCache/FeedChannelSyncService.swift)
  - feed 取得、更新判定、store 反映を束ねる更新実行サービス。
- [ChannelRegistryMaintenanceService.swift](../HelloWorld/Features/FeedCache/ChannelRegistryMaintenanceService.swift)
  - チャンネル登録、削除、バックアップ入出力、全設定リセット。
- [FeedCacheStore.swift](../HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - cache、snapshot、thumbnail、整合性メンテナンス。
- [RemoteVideoSearchCacheStore.swift](../HelloWorld/Features/FeedCache/RemoteVideoSearchCacheStore.swift)
  - YouTube 検索結果キャッシュの保存、鮮度判定、履歴クリア。
- [RemoteVideoSearchService.swift](../HelloWorld/Features/FeedCache/RemoteVideoSearchService.swift)
  - YouTube 検索の再取得、TTL 判定、検索キャッシュ統合。
  - 検索キャッシュ反映完了と remote refresh cancellation のログ。
- [HomeSystemStatusService.swift](../HelloWorld/Features/FeedCache/HomeSystemStatusService.swift)
  - ホーム画面へ出すシステム状況の集約。
- [FeedCachePaths.swift](../HelloWorld/Features/FeedCache/FeedCachePaths.swift)
  - bootstrap、cache、registry、search cache、thumbnail の固定パス集約。
- [FeedBootstrapStore.swift](../HelloWorld/Features/FeedCache/FeedBootstrapStore.swift)
  - bootstrap の読込と整形。
- [ChannelRegistryStore.swift](../HelloWorld/Features/FeedCache/ChannelRegistryStore.swift)
  - registry と端末内バックアップ JSON の永続化。
- [FeedCacheModels.swift](../HelloWorld/Features/FeedCache/FeedCacheModels.swift)
  - キャッシュ用モデル、進捗モデル、検索結果モデルなどの値型。

### Infrastructure

- [YouTubeFeed.swift](../HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - feed 取得、更新判定、XML パース、URL / handle 解決。
- [YouTubeSearchService.swift](../HelloWorld/Infrastructure/YouTube/YouTubeSearchService.swift)
  - YouTube Data API v3 search / videos.list 呼び出し。
  - API キー解決、レスポンス変換、詳細補完、ライブ除外。
  - 検索開始、HTTP 応答、transport cancellation、decode failure、完了件数のログ。

### Shared

- [AppLogic.swift](../HelloWorld/Shared/AppLogic.swift)
  - `BackSwipePolicy`
  - `VideoOpenPolicy`
  - `FeedOrdering`
  - `ChannelBrowseSortDescriptor`
  - `RemoteSearchPresentationState`
  - 画面非依存の pure logic。

## 画面と状態の詳細設計

- `FeedCacheCoordinator` は複数画面から使う状態を公開するが、検索中表示やチップ可視状態のような画面局所の UI 状態は `SearchResultsViews.swift` と `RemoteSearchPresentationState` に閉じ込める。
- `RemoteSearchPresentationState` は YouTube 検索結果画面の段階表示件数、refresh 状態、split 初期選択を pure logic として持つ。
- `AppLayout` は機能差分を持たず、画面表現の差だけを返す。
- `InteractiveListScreen` は一覧系画面のタイトル、余白、背景、pull-to-refresh、戻るスワイプの共通コンテナとして使う。

## テスト配置

### Unit Test

- [YouTubeFeedParserTests.swift](../HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift)
  - feed parser、uploads playlist ID 変換。
- [ChannelRegistrySnapshotTests.swift](../HelloWorldTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift)
  - channel registry の export / import。
- [FeedCacheMaintenanceTests.swift](../HelloWorldTests/Unit/Storage/FeedCacheMaintenanceTests.swift)
  - チャンネル削除、整合性メンテナンス、全設定リセット。
- [RemoteVideoSearchCacheStoreTests.swift](../HelloWorldTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift)
  - 検索キャッシュの鮮度判定。
- [FeedCacheCoordinatorRemoteSearchTests.swift](../HelloWorldTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift)
  - 強制再検索がキャッシュへ保存され、次回読込へ反映されること。
  - 呼び出し元 task が cancel されても managed task 側で検索完了まで進むこと。
- [BackSwipePolicyTests.swift](../HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift)
  - 戻るスワイプ判定。
- [FeedOrderingTests.swift](../HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift)
  - 優先順、鮮度判定。
- [AppLayoutTests.swift](../HelloWorldTests/Unit/Layout/AppLayoutTests.swift)
  - Adaptive UI のレイアウト切替。
- [AppConsoleLoggerTests.swift](../HelloWorldTests/Unit/Formatting/AppConsoleLoggerTests.swift)
  - キーワード短縮、レスポンス preview、decoding error 要約の整形。
- [RemoteSearchErrorPolicyTests.swift](../HelloWorldTests/Unit/Policies/RemoteSearchErrorPolicyTests.swift)
  - キャンセル判定とユーザー向け文言抑制。
- [ChannelBrowseTipsSummaryTests.swift](../HelloWorldTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift)
  - `Tips` サマリー文言と YouTube 検索結果の presentation state。

### UI Test

- [HomeScreenUITests.swift](../HelloWorldUITests/Home/HomeScreenUITests.swift)
  - ホーム画面表示、導線、モック refresh、起動タイムライン。
  - iPad の YouTube検索遷移について、baseline / heavy fixture の split 計測。
  - 起動区間と YouTube検索 split 区間をまとめた metrics JSON の出力。
- [BrowseScreenUITests.swift](../HelloWorldUITests/Browse/BrowseScreenUITests.swift)
  - 一覧導線、チャンネル別動画一覧更新、YouTube 検索結果 refresh state、検索結果からのチャンネル遷移。
  - 実機向け live YouTube 検索 refresh の再現導線。
- [UITestCaseSupport.swift](../HelloWorldUITests/Support/UITestCaseSupport.swift)
  - app 起動、timeline 解析、共通 wait。
  - runtime diagnostics の解析と区間 ms 変換。

## Test Support と Fixture

- [UITest.bootstrap.json](../HelloWorld/Resources/TestFixtures/UITest.bootstrap.json)
  - UI テスト用 bootstrap。
- [UITest.cache.json](../HelloWorld/Resources/TestFixtures/UITest.cache.json)
  - UI テスト用 cache。
- `HELLOWORLD_UI_TEST_REMOTE_SEARCH_FIXTURE`
  - `baseline` / `heavy` を切り替え、YouTube検索 split 計測用の重め検索キャッシュを seed できる。
- [stream_device_runtime_logs.sh](../scripts/stream_device_runtime_logs.sh)
  - 実機ランタイムログの取得。
- [health_barometer.sh](../scripts/health_barometer.sh)
  - 行数、関数長、型数、`@Published` 数の軽量点検。
