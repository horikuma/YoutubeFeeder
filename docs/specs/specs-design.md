# YoutubeFeeder Design

この文書は、YoutubeFeeder の詳細設計を記述する正本である。ここでは、ファイル単位、型単位、テスト単位の責務を扱う。

文書群の役割分担と文書運用ルールは [rules-update-documents.md](../rules/rules-update-documents.md) を参照する。

## 実装単位の責務

### Project Settings

- [project.pbxproj](../../YoutubeFeeder.xcodeproj/project.pbxproj)
  - shared build settings と target build settings の正本。
  - iOS deployment target は `16.0` を維持する。
  - app / unit test / UI test の bundle identifier は `Neko.YoutubeFeeder` 系へ統一する。
  - 実機向け署名は `YQA274TX99` の automatic signing を前提にする。
  - プロダクト名変更後に Xcode 側の build が不安定になった場合は、旧名の project-local `.DerivedData*` と `xcuserstate` を破棄して再生成する。
- [package.json](../../package.json)
  - 文書検証用 Node.js 依存の正本。
  - Mermaid ローカル検証の CLI 版固定。
- [package-lock.json](../../package-lock.json)
  - Mermaid ローカル検証の npm lock file。
- [check-mermaid.mjs](../../scripts/check-mermaid.mjs)
  - Markdown から Mermaid ブロックを抽出し、ローカルで SVG 描画して検証する。

### App

- [YoutubeFeederApp.swift](../../YoutubeFeeder/App/YoutubeFeederApp.swift)
  - アプリ起動入口。
  - app launch の lifecycle ログ開始。
- [AppDependencies.swift](../../YoutubeFeeder/App/AppDependencies.swift)
  - composition root。
  - live dependency の組み立て。
  - プレイリスト閲覧で使う use case と YouTube playlist service の組み立てを、検索系 dependency と分けて扱う。
- [ContentView.swift](../../YoutubeFeeder/App/ContentView.swift)
  - ルート画面。
  - `LaunchScreenView` からホーム画面への遷移。
  - `NavigationStack` と route の束ね。
  - bootstrap 開始完了と maintenance enter の lifecycle ログ。
- [AppLayout.swift](../../YoutubeFeeder/App/AppLayout.swift)
  - `horizontalSizeClass` を主基準とする Adaptive UI 判定。
  - 単独画面と分割レイアウトの差分吸収。
- [AppConsoleLogger.swift](../../YoutubeFeeder/App/AppConsoleLogger.swift)
  - Xcode コンソール向けの 1 行ランタイムログ。
  - `[YoutubeFeeder]` 接頭辞、キーワード短縮、レスポンス preview の整形。
  - `app.lifecycle` と `youtube.search` の境界ログを共通整形する。
- [AppFormatting.swift](../../YoutubeFeeder/App/AppFormatting.swift)
  - 日付や数値の共通 formatter。
- [AppTestSupport.swift](../../YoutubeFeeder/App/Support/AppTestSupport.swift)
  - launch mode、fixture seed、timeline、test marker。
  - UI テスト用初期遷移指定。
  - mock / live を切り替える UI テスト launch mode。
  - 実機調査用 diagnostics。
  - YouTube検索 split 計測用 runtime diagnostics と `heavy` fixture seed。

### Features/Home

- [HomeScreenView.swift](../../YoutubeFeeder/Features/Home/HomeScreenView.swift)
  - ホーム画面本体。
  - 検索導線、バックアップ、全設定リセット、システム状況表示の UI 写像。
  - 手動更新、起動時 refresh、scheduler 起動、YouTube検索 prewarm、export / import / reset の実行開始は `HomeScreenViewModel` へ渡す。
  - View は `NavigationLink`、`Menu`、confirmation dialog、feedback card、hidden prewarm host の表示責務だけを持つ。
- [HomeScreenViewModel.swift](../../YoutubeFeeder/Features/Home/HomeScreenViewModel.swift)
  - ホーム画面の feature-local ViewModel。
  - 起動時の全チャンネル refresh、壁時計 scheduler 起動、YouTube検索 snapshot prewarm、hidden host mount、export / import / reset、event log を担う。
  - `FeedCacheCoordinator` の共有入口を呼び、ファイル形式、API 通信、永続化詳細を持たない。
- [HomeScreenLogic.swift](../../YoutubeFeeder/Features/Home/HomeScreenLogic.swift)
  - ホーム画面固有の pure logic。
  - channel sort、transfer feedback、reset feedback、confirm reset、処理中 state を担う。
  - I/O、logger、task 起動を持たない。
- [ChannelRegistrationView.swift](../../YoutubeFeeder/Features/Home/ChannelRegistrationView.swift)
  - チャンネル登録画面。
  - 入力、解決、登録、結果表示。
- [ChannelRegistrationLogic.swift](../../YoutubeFeeder/Features/Home/ChannelRegistrationLogic.swift)
  - チャンネル登録画面固有の pure logic。
  - submit / CSV import の入力状態、feedback、error、import presentation state を担う。
- [HomeUIComponents.swift](../../YoutubeFeeder/Features/Home/HomeUIComponents.swift)
  - ホーム画面の表示部品。
  - splash 表示の lifecycle ログ。
  - splash のアプリ名は 1 行固定とし、狭い横幅では縮小して改行させない。
- [HomeRoutes.swift](../../YoutubeFeeder/Features/Home/HomeRoutes.swift)
  - 一覧系画面への遷移定義。

### Features/Browse

- [ChannelBrowseViews.swift](../../YoutubeFeeder/Features/Browse/ChannelBrowseViews.swift)
  - `ChannelBrowseView`、全動画一覧、分割チャンネル閲覧。
  - `Tips` タイル、並び順反映、削除導線の UI 写像。
  - 分割レイアウトでは、選択、読込、paging、playlist 表示、削除実行、refresh 起動を `ChannelBrowseViewModel` へ渡す。
  - チャンネルタイルの削除メニューは `openTileMenu(item:)` 相当の共通アクションへ寄せ、`iPhone` / `iPad` の長押しと `Mac` の左クリックは UI アダプタ差分として扱う。
- [ChannelBrowseViewModel.swift](../../YoutubeFeeder/Features/Browse/ChannelBrowseViewModel.swift)
  - チャンネル一覧画面の feature-local ViewModel。
  - split detail 選択、初回選択、動画読込、playlist 表示、playlist 動画読込、paging、削除実行、refresh 起動、event log を担う。
  - View へ公開する state は `ChannelBrowseLogic` を正本にし、Coordinator には service / use case 入口として依存する。
- [ChannelBrowseLogic.swift](../../YoutubeFeeder/Features/Browse/ChannelBrowseLogic.swift)
  - チャンネル一覧画面固有の pure logic。
  - item 一覧、選択 channel、削除確認、動画配列、playlist 配列、display mode、selected playlist、Tips summary を担う。
  - I/O、logger、task 起動、Coordinator 呼び出しを持たない。
- [SearchResultsViews.swift](../../YoutubeFeeder/Features/Browse/SearchResultsViews.swift)
  - 固定キーワード検索結果と共通チップ UI。
  - ローカルキャッシュ検索結果の UI 写像。
- [KeywordSearchLogic.swift](../../YoutubeFeeder/Features/Browse/KeywordSearchLogic.swift)
  - ローカルキャッシュ検索結果画面固有の pure logic。
  - 検索結果 state の保持と差し替えだけを担う。
- [RemoteSearchResultsViews.swift](../../YoutubeFeeder/Features/Browse/RemoteSearchResultsViews.swift)
  - YouTube 検索結果画面本体。
  - `RemoteSearchResultsViewModel` を保持し、result、presentation state、split state の表示写像を担う。
  - root render probe、refresh chip、toolbar、safe area chip、gesture、animation、prewarm / visible の表示差分を担う。
  - snapshot 読込、再検索、split 初期読込予約、split paging、画面出入りの event log は ViewModel へ渡す。
- [RemoteSearchResultsViewModel.swift](../../YoutubeFeeder/Features/Browse/RemoteSearchResultsViewModel.swift)
  - YouTube 検索結果画面の feature-local ViewModel。
  - snapshot 読込、refresh、clear history、chip dismiss、visible paging、split 初期選択、split 遅延読込、split refresh、split paging、event log を担う。
  - `FeedCacheCoordinator` の managed task / snapshot / refresh 入口を呼び、検索 API や永続化詳細を持たない。
- [RemoteSearchLogic.swift](../../YoutubeFeeder/Features/Browse/RemoteSearchLogic.swift)
  - YouTube 検索結果画面固有の pure logic。
  - `RemoteSearchPresentationState`、chip mode、visible count、split context、split videos、split visible count、split loading state を担う。
  - split 初期選択は `routeSource = .remoteSearch` を含む `ChannelVideosRouteContext` を返し、後続の自動 refresh / fallback 判定へ文脈を引き渡す。
- [RemoteSearchResultsContentViews.swift](../../YoutubeFeeder/Features/Browse/RemoteSearchResultsContentViews.swift)
  - YouTube 検索結果の compact / regular / split detail の表示責務。
  - regular 左ペインと split detail の描画到達点を render probe で観測する。
  - split 詳細の表示本体は持つが、チャンネル切替に伴う状態遷移や読込開始は ViewModel へ委譲する。
  - remote search 起点でチャンネル一覧へ遷移する時は、`ChannelVideosRouteContext.routeSource = .remoteSearch` を必ず引き継ぐ。
- [BrowseViews.swift](../../YoutubeFeeder/Features/Browse/BrowseViews.swift)
  - チャンネル別動画一覧。
  - 単独チャンネル更新は `refreshFeed()` 相当のドメインアクションへ束ね、UI からはジェスチャー種別を持ち込まない。
  - 自動 feed 更新時の上部進行表示。
- [VideoListLogic.swift](../../YoutubeFeeder/Features/Browse/VideoListLogic.swift)
  - 全動画一覧画面固有の pure logic。
  - 動画配列、automatic refresh 表示 state、削除確認、削除 feedback を担う。
- [BrowseComponents.swift](../../YoutubeFeeder/Features/Browse/BrowseComponents.swift)
  - 一覧系共通コンテナ `InteractiveListView`。
  - `ChannelTile` を機能共通核とし、`ChannelNavigationTile` と `ChannelSelectionTile` へ操作差分を分離する。
  - `VideoTile`、戻るスワイプ modifier。
  - `VideoTile` のメニュー操作は共通 menu model と UI アダプタへ分離し、`iPhone` / `iPad` は長押し、`Mac` は左クリックで同一メニューアクションへ到達させる。
  - `VideoTile` のメニューに `共有` を持ち、動画 URL を `UIActivityViewController` へ渡す共通 share sheet を提供する。

### Features/FeedCache

- [FeedCacheCoordinator.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator.swift)
  - ViewModel と永続化 / service / use case の共有入口。
  - bootstrap 読込、一覧データ読込、手動更新、単独チャンネル更新、検索結果読込。
  - 更新アクションは `FeedRefreshAction` のようなドメイン単位で受け、UI イベント種別には依存しない。
  - 特定 View の presentation mode、visible count、split 遅延選択、playlist paging cursor、prewarm host mount state を持たない。
  - ChannelRefresh の全チャンネルリフレッシュ入口、短周期リフレッシュ入口、実行中判定、実行中トリガーのドロップを担う。
  - ChannelRefresh の実行中判定は、起動時、手動操作、毎時00分、毎時10/20/30/40/50分で共通の単一状態として扱う。
  - YouTube 検索の snapshot hit / miss、refresh failure fallback、cancel fallback の境界ログ。
  - YouTube 検索の managed task の生成、再利用管理。
  - feed cache と検索 cache の動画を合流する際は、`video_id` 重複で落とさず、より新しい `publishedAt` / `fetchedAt` を優先して 1 件へ正規化する。
  - remote search 起点のチャンネル動画表示では、feed refresh 後も動画が `1 件以下` の場合に限って YouTube Data API の channel search fallback を実行し、右ペインが単一動画で止まらないようにする。
  - プレイリスト閲覧の入口は専用 use case へ委譲し、検索系 cache や remote search の state へ流用しない。
  - `FeedCacheStore` への直接 mutation を持たず、FeedCache 系の副作用は `FeedCacheWriteService` または副作用専用 service へ委譲する。
- [ChannelRefreshWallClockScheduler.swift](../../YoutubeFeeder/Features/FeedCache/ChannelRefreshWallClockScheduler.swift)
  - 毎時 00 / 10 / 20 / 30 / 40 / 50 分の壁時計発火を計算する。
  - 00 分は全チャンネルリフレッシュ、10 / 20 / 30 / 40 / 50 分は短周期リフレッシュとして発火種別を返す。
  - feed 取得、キャッシュ反映、整合性メンテナンス、UI 反映を直接持たず、`FeedCacheCoordinator` の ChannelRefresh 入口を呼ぶだけに留める。
- [FeedCacheCoordinator+Refresh.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator+Refresh.swift)
  - ChannelRefresh の 1 回分の更新実行を担う。
  - 全チャンネルリフレッシュと短周期リフレッシュの対象チャンネルを受け取り、feed 取得、キャッシュ反映、整合性メンテナンス、UI 反映までを 1 回で完了させる。
  - 内部ループ、sleep による自己継続、完了後の自己再起動を持たない。
- [FeedChannelSyncService.swift](../../YoutubeFeeder/Features/FeedCache/FeedChannelSyncService.swift)
  - feed 取得、更新判定、store 反映を束ねる更新実行サービス。
  - 依存先は `FeedCacheWriteService` と外部 feed service に限定し、`FeedCacheReadService` との相互依存を作らない。
- [ChannelRegistryMaintenanceService.swift](../../YoutubeFeeder/Features/FeedCache/ChannelRegistryMaintenanceService.swift)
  - チャンネル登録、削除、バックアップ入出力、全設定リセット。
  - 読取りが必要な場合だけ `FeedCacheReadService` を参照し、保存・削除・整合性メンテナンスは `FeedCacheWriteService` 経由に限定する。
- [FeedCacheReadService.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheReadService.swift)
  - FeedCache 系の読取り、検索結果のマージ、表示用の並べ替えを担う。
  - store 書込み、thumbnail 保存、検索キャッシュ保存のような副作用を持たない。
  - `Read` / `Write` 分離を理由に、動画・チャンネル・検索履歴のようなデータ軸で `FeedCacheReadService` と `FeedCacheWriteService` の共通 superclass を導入してはならない。
- [FeedCacheWriteService.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheWriteService.swift)
  - FeedCache 系の保存、削除、bootstrap 永続化、整合性メンテナンス、thumbnail 反映の単一入口を担う。
  - `FeedCacheCoordinator`、`FeedChannelSyncService`、`ChannelRegistryMaintenanceService` からの書込み要求を受けても、`FeedCacheReadService` への逆依存を作らない。
- [FeedCacheStore.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift)
  - cache、snapshot、thumbnail、整合性メンテナンス。
  - ホーム表示に必要な件数・更新時刻・thumbnail 合計サイズの集約窓口。
  - 動画・チャンネルの正本は `SQLite` に保存し、表示用文字列も同一更新点で生成して row に保持する。
  - 一覧問い合わせでは、`Shorts URL/title` に加えて `durationSeconds < 240` も短尺判定へ含め、表示対象から除外する。
  - 全設定リセットでは `SQLite` 正本を table 単位で空にするだけでなく、database file / `-wal` / `-shm` も削除して完全再初期化する。
  - 全設定リセットでは、旧 runtime が使っていた `cache.json`、`cache-summary.plist`、`channel-registry.json`、`remote-search*.json`、`remote-search*.plist` も同時に削除し、reset 後に古い file が再注入されないようにする。
- [FeedCacheSQLiteDatabase.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift)
  - 動画、チャンネル、検索履歴、登録チャンネルをまとめて保持する `SQLite` 永続層。
  - 検索結果のチャンネル別集約問い合わせを担う。
  - runtime では旧 `JSON` 永続物の migration を持たず、正本は `SQLite` のみを扱う。
- [RemoteVideoSearchCacheStore.swift](../../YoutubeFeeder/Features/FeedCache/RemoteVideoSearchCacheStore.swift)
  - YouTube 検索結果キャッシュの保存、鮮度判定、履歴クリア。
  - チャンネル別の動画集約では `SQLite` 上の検索結果履歴全体を `channel_id` で問い合わせ、既定キーワード分も merge 対象へ含める。
  - 同じ `video_id` が検索履歴側で再入しても、重複 key fatal にせず後勝ちで 1 件へ正規化する。
- [RemoteVideoSearchService.swift](../../YoutubeFeeder/Features/FeedCache/RemoteVideoSearchService.swift)
  - YouTube 検索の再取得、TTL 判定、検索キャッシュ統合。
  - 検索キャッシュ反映完了と remote refresh cancellation のログ。
  - channelID 単位の動画一覧 fallback 取得と、その結果の検索キャッシュ保存。
  - remote search 系の保存前フィルタでも `durationSeconds < 240` を短尺として除外し、feed cache 側の短尺マスクと基準をそろえる。
- [HomeSystemStatusService.swift](../../YoutubeFeeder/Features/FeedCache/HomeSystemStatusService.swift)
  - ホーム画面へ出すシステム状況の集約。
  - summary を優先し、必要時だけ本体 snapshot を読む。
- [FeedCachePaths.swift](../../YoutubeFeeder/Features/FeedCache/FeedCachePaths.swift)
  - bootstrap、cache、cache summary、registry、search cache、search cache summary、thumbnail の固定パス集約。
- [FeedCachePersistenceCoders.swift](../../YoutubeFeeder/Features/FeedCache/FeedCachePersistenceCoders.swift)
  - cache 永続化用の compact encoder / decoder。
  - summary 永続化用の binary property list encoder / decoder。
- [FeedBootstrapStore.swift](../../YoutubeFeeder/Features/FeedCache/FeedBootstrapStore.swift)
  - bootstrap の読込と整形。
- [ChannelRegistryStore.swift](../../YoutubeFeeder/Features/FeedCache/ChannelRegistryStore.swift)
  - 登録チャンネルの `SQLite` 永続化と、端末内バックアップ `JSON` の入出力。
- [FeedCacheStorageModels.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheStorageModels.swift)
  - cache snapshot と永続化対象の値型。
- [FeedCacheProgressModels.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheProgressModels.swift)
  - 進捗表示、ホーム集約、検索キャッシュ状態の値型。
- [FeedCacheChannelModels.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheChannelModels.swift)
  - チャンネル保守、登録 / 削除 / バックアップ feedback の値型。
  - プレイリスト一覧やプレイリスト内動画の表示用値型を追加する場合は、Browse 専用の軽量 state として閉じ込める。
- [ChannelPlaylistBrowseService.swift](../../YoutubeFeeder/Features/FeedCache/ChannelPlaylistBrowseService.swift)
  - Infrastructure のプレイリスト結果を Browse 表示用モデルへ変換する use case。
  - 検索機能、検索 cache、remote search の読み書きには依存しない。
- [RemoteSearchModels.swift](../../YoutubeFeeder/Features/FeedCache/RemoteSearchModels.swift)
  - YouTube 検索結果、検索キャッシュ、動画 query の値型。

### Infrastructure

- [YouTubeFeed.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift)
  - feed 取得、更新判定、XML パース、URL / handle 解決。
- [YouTubePlaylistModels.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubePlaylistModels.swift)
  - プレイリスト一覧 item とプレイリスト内動画 page の公開モデル。
- [YouTubePlaylistResponses.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubePlaylistResponses.swift)
  - プレイリスト一覧取得とプレイリスト内動画取得に必要な response DTO。
- [YouTubePlaylistService.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubePlaylistService.swift)
  - プレイリスト一覧、プレイリスト内動画 page、連続再生 URL を扱う service。
  - search endpoint を使わず、playlist 専用の通信と decode に閉じ込める。
- [YouTubeSearchService.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchService.swift)
  - YouTube Data API v3 search / videos.list 呼び出し。
  - API キー解決、HTTP / decode error handling、検索 orchestration。
  - 検索開始、HTTP 応答、transport cancellation、decode failure、完了件数のログ。
- [YouTubeSearchModels.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchModels.swift)
  - YouTube 検索の公開モデルとエラー型。
- [YouTubeSearchProcessing.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchProcessing.swift)
  - candidate merge、詳細結果整列、mock 応答の補助ロジック。
- [YouTubeSearchListResponse.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchListResponse.swift)
  - search endpoint の decode DTO。
- [YouTubeVideoListResponse.swift](../../YoutubeFeeder/Infrastructure/YouTube/YouTubeVideoListResponse.swift)
  - videos endpoint の decode DTO、duration parse、decoder 設定。

### Shared

- [AppLogic.swift](../../YoutubeFeeder/Shared/AppLogic.swift)
  - `BackSwipePolicy`
  - `VideoOpenPolicy`
  - `FeedOrdering`
  - `ChannelBrowseSortDescriptor`
  - `ChannelRefreshSchedulePolicy`
  - `ChannelRefreshWallClockPolicy`
  - 画面非依存の pure logic と共有 policy。
  - feature-local ViewModel / Logic から再利用される、画面に閉じない判定だけを置く。
  - 画面固有の presentation state、selected item、paging cursor、feedback state を置かない。
  - `ChannelRefreshSchedulePolicy` は 10 日以内 10 分、それ以外 1 時間の対象選定ロジックを担う。
  - `ChannelRefreshWallClockPolicy` は壁時計時刻から全チャンネルリフレッシュまたは短周期リフレッシュの発火種別を判定する。

## 画面と状態の詳細設計

- `FeedCacheCoordinator` は複数画面から使う状態を公開するが、検索中表示やチップ可視状態のような画面固有 presentation state は feature-local ViewModel / Logic に閉じる。
- 画面単位の非同期 orchestration、状態分岐、副作用起動、event log は対象画面の ViewModel に置く。
- View は render、binding、animation、dialog、表示写像、render probe、描画到達の観測を担う。
- Pure logic は feature-local に置き、I/O、logger、`Task.sleep`、`MainActor.run`、副作用起動を持たない。
- `RemoteSearchPresentationState` は YouTube 検索結果画面の段階表示件数、refresh 状態、split 初期選択の正本を持つ feature-local pure logic とする。
- `RemoteSearchPresentationState` の split 初期選択は `routeSource = .remoteSearch` を含む `ChannelVideosRouteContext` を返し、後続の自動 refresh / fallback 判定へ文脈を引き渡す。
- アクションは `refreshFeed()` や `openTileMenu(item:)` のようなドメイン単位で定義し、UI イベント単位の共通入口を作らない。
- UI はドメインアクションを呼び出すアダプタとして扱い、プラットフォーム差分は UI 層で吸収してアクション層へ持ち込まない。
- YouTube 検索 split 右ペインのチャンネル動画一覧は、初回 20 件を表示し、末尾到達で 20 件ずつ継ぎ足して全件表示する。
- YouTube 検索 split 詳細の `channel title` と動画タイルは、選択変更時に同じ state transition で切り替わるようにし、片方だけ先に更新される状態を残してはならない。
- YouTube 検索 split 右ペインで feed refresh 後も `1 件以下` に留まる時は、検索結果由来のチャンネルであるとみなし、channel-specific API fallback の取得結果を追加して一覧を復元する。
- 短尺動画マスクは `ShortVideoMaskPolicy` へ集約し、`Shorts URL/title` と `durationSeconds < 240` の両方を同じ基準で扱う。
- `AppLayout` は機能差分を持たず、画面表現の差だけを返す。
- `InteractiveListView` は一覧系画面のタイトル、余白、背景、pull-to-refresh、戻るスワイプの共通コンテナとして使う。
- `InteractiveListView` の更新 UI は gesture や command の違いを持たず、現在画面の refresh action を command 層へ登録するアダプタとして振る舞う。
- チャンネル一覧のタイルでは、`channel title`、件数、最新投稿日、サムネイルの表示責務を `ChannelTile` へ集約し、遷移か選択かという操作モデルの差は外側の wrapper で表現する。
- `VideoTile` は画面ごとの差分があっても共有や削除の action 定義は共通で持ち、YouTube検索、チャンネル動画、動画一覧、キャッシュ検索のどこからでも同じ share sheet と menu action を開ける。

## 変更時の責務照合

- 画面の見た目、layout、animation、dialog、render probe を変える場合は、対象 `View` / 表示部品を変更する。
- 画面単位の async、refresh、prewarm、paging、split selection、delete / export / import / reset、event log を変える場合は、対象画面の `ViewModel` を変更する。
- 画面固有の状態遷移、選択保持、表示件数、feedback state、chip mode を変える場合は、対象 feature の `Logic` を変更する。
- 複数画面で共有する refresh state、manual refresh count、home system status、remote search managed task、service / use case 入口を変える場合は、`FeedCacheCoordinator` または関連 extension を変更する。
- 永続化、キャッシュ保存、削除、整合性メンテナンス、外部 API 通信を変える場合は、`Service / Use Case`、`Store`、`Infrastructure` を変更する。
- `Shared/AppLogic.swift` へ追加してよいのは、複数 feature から再利用でき、画面 state を持たない pure policy だけとする。
- 局所的な修正でも、View に非同期処理を戻したり、Coordinator に画面固有 cursor を置いたり、Shared に feature-local state を戻したりしない。

## 命名規則

- 画面や表示部品の型名は、SwiftUI の `View` 型であることが読めるよう、原則として `View` で終える。
- 機能単位の親 View は、`ChannelBrowseView` のように `対象 + 機能` を先に表し、`List`、`Pane`、`Screen` のような実装都合の容器語は、その責務が名前に不可欠な場合だけ使う。
- Adaptive UI の派生 View は、親機能名を保ったまま `CompactView`、`RegularView`、`SplitDetailView` のように末尾で差分を表す。
- 共通の機能核を表す表示部品は、`ChannelTile` のように短い機能名を優先し、遷移・選択・編集などの操作差分は `ChannelNavigationTile`、`ChannelSelectionTile` のように別 wrapper で表す。
- 同じ役割を持つ型は、画面をまたいでも同じ語を使う。逆に、同じ語を使う型は機能上の中心責務が一致している状態を保つ。

## テスト配置

### Unit Test

- [YouTubeFeedParserTests.swift](../../YoutubeFeederTests/Unit/Parsing/YouTubeFeedParserTests.swift)
  - feed parser、uploads playlist ID 変換。
- [ChannelRegistrySnapshotTests.swift](../../YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift)
  - channel registry の export / import。
- [FeedCacheMaintenanceTests.swift](../../YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift)
  - チャンネル削除、整合性メンテナンス、全設定リセット。
- [RemoteVideoSearchCacheStoreTests.swift](../../YoutubeFeederTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift)
  - 検索キャッシュの鮮度判定。
- [FeedCacheCoordinatorRemoteSearchTests.swift](../../YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift)
  - 強制再検索がキャッシュへ保存され、次回読込へ反映されること。
  - 呼び出し元 task が cancel されても managed task 側で検索完了まで進むこと。
  - feed cache と検索 cache に同一 `video_id` があっても、`loadVideosForChannel` が fatal せず 1 件へ正規化すること。
- [BackSwipePolicyTests.swift](../../YoutubeFeederTests/Unit/Policies/BackSwipePolicyTests.swift)
  - 戻るスワイプ判定。
- [VideoSharePolicyTests.swift](../../YoutubeFeederTests/Unit/Policies/VideoSharePolicyTests.swift)
  - 共有対象 URL の有無判定。
- [FeedOrderingTests.swift](../../YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift)
  - 優先順、鮮度判定。
- [AppLayoutTests.swift](../../YoutubeFeederTests/Unit/Layout/AppLayoutTests.swift)
  - Adaptive UI のレイアウト切替。
- [AppConsoleLoggerTests.swift](../../YoutubeFeederTests/Unit/Formatting/AppConsoleLoggerTests.swift)
  - キーワード短縮、レスポンス preview、decoding error 要約の整形。
- [RemoteSearchErrorPolicyTests.swift](../../YoutubeFeederTests/Unit/Policies/RemoteSearchErrorPolicyTests.swift)
  - キャンセル判定とユーザー向け文言抑制。
- [ChannelBrowseTipsSummaryTests.swift](../../YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift)
  - `Tips` サマリー文言と YouTube 検索結果の presentation state。

### UI Test

- [HomeScreenUITests.swift](../../YoutubeFeederUITests/Home/HomeScreenUITests.swift)
  - アプリ起動成功、初期ホーム画面表示、クラッシュしないことの確認だけを担う起動健全性 smoke test。
  - 画面文言、レイアウト、詳細遷移、分岐網羅、ビジュアル品質は検証しない。
  - 各テストは単一責務に保ち、最小本数へ抑える。
- [UITestCaseSupport.swift](../../YoutubeFeederUITests/Support/UITestCaseSupport.swift)
  - app 起動とホーム画面待機の共通補助。
  - GUI テストをブラックボックスの起動確認として保つための最小補助だけを持つ。

## Test Support と Fixture

- [UITest.bootstrap.json](../../YoutubeFeeder/Resources/TestFixtures/UITest.bootstrap.json)
  - UI テスト用 bootstrap。
- [UITest.cache.json](../../YoutubeFeeder/Resources/TestFixtures/UITest.cache.json)
  - UI テスト用 cache。
- `YOUTUBEFEEDER_UI_TEST_REMOTE_SEARCH_FIXTURE`
  - `baseline` / `heavy` を切り替え、YouTube検索 split 計測用の重め検索キャッシュを seed できる。
- [device-runtime-log-stream](../../scripts/device-runtime-log-stream)
  - 実機ランタイムログの取得。
- [metrics-health-check](../../scripts/metrics-health-check)
  - 行数、関数長、型数、`@Published` 数の軽量点検。
