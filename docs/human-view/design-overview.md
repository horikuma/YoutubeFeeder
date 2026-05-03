# YoutubeFeeder Design Overview

この文書は、人間のエンジニア向けに `AGENTS.md`、`specs-product.md`、`specs-architecture.md`、`specs-design.md` の内容を UML 風に読み替えた設計資料である。正本ではなく、関連する正本文書を人間が俯瞰しやすい形へ翻訳した `human-view` 文書として継続管理する。

文書群の役割分担は [AGENTS.md](../../AGENTS.md) と [specs.md](../specs.md) を参照する。

## レイヤ構成

```mermaid
flowchart LR
    View["SwiftUI View"] --> ViewModel["Feature ViewModel / Screen Orchestration"]
    ViewModel --> Coordinator["FeedCacheCoordinator / Shared Entry"]
    Coordinator --> Read["Read Service"]
    Coordinator --> Write["Write Service"]
    Coordinator --> Domain["Domain Service"]
    Read --> Store["Store"]
    Write --> Store
    Domain --> Store
    Domain --> Infra["Infrastructure"]
    Store --> Files["Local Files / Cache / Registry"]
    Infra --> YouTube["YouTube API / Feed"]
```

## 主要構造図

### UI構造図（Viewツリー）

対象は `ContentView`、basic GUI の root / screen、各 SwiftUI View、共通 UI 部品の親子関係である。Coordinator、Service、Store、composition / pure logic の判断単位は含めない。

```mermaid
flowchart TD
    ContentView["ContentView"] --> Root["BasicGUIRootView"]
    Root --> HomeScreen["BasicGUIHomeScreen"]
    Root --> ChannelBrowseScreen["BasicGUIChannelBrowseScreen"]
    Root --> AllVideos["AllVideosView"]
    Root --> KeywordSearch["KeywordSearchResultsView"]
    Root --> RemoteSearchScreen["BasicGUIRemoteSearchScreen"]

    HomeScreen --> HomeView["HomeScreenView"]
    ChannelBrowseScreen --> ChannelBrowse["ChannelBrowseView"]
    RemoteSearchScreen --> RemoteSearch["RemoteKeywordSearchResultsView"]

    ChannelBrowse --> ChannelList["InteractiveListView"]
    ChannelBrowse --> ChannelTile["ChannelTile"]
    ChannelBrowse --> ChannelVideos["ChannelVideosView"]
    AllVideos --> AllVideosList["InteractiveListView"]
    KeywordSearch --> KeywordSearchList["InteractiveListView"]
    ChannelVideos --> ChannelVideoTile["VideoTile"]
    AllVideos --> AllVideoTile["VideoTile"]
    KeywordSearch --> KeywordVideoTile["VideoTile"]

    RemoteSearch --> RemoteSearchList["InteractiveListView"]
    RemoteSearch --> RemoteCompact["RemoteKeywordSearchResultsCompactView"]
    RemoteSearch --> RemoteRegular["RemoteKeywordSearchResultsRegularView"]
    RemoteRegular --> RemoteSplitDetail["RemoteKeywordSearchResultsSplitDetailView"]
    RemoteCompact --> RemoteCompactTile["VideoTile"]
    RemoteRegular --> RemoteRegularTile["VideoTile"]
    RemoteSplitDetail --> RemoteSplitTile["VideoTile"]
```

### 判断配置図（composition / pure logic）

対象は route / layout / presentation の決定位置である。SwiftUI View の親子関係、ViewModel から Coordinator、Service、Store へのデータフローは含めない。

composition は画面組み立てと判断の集約単位であり、UI クラスではない。View / Service / Store と同列の静的クラス依存として扱わず、どこで route、layout、presentation が決まるかを示す概念として扱う。

```mermaid
flowchart TD
    ContentView["ContentView"] --> AppLayout["AppLayout"]
    AppLayout --> LayoutBranching["BasicGUILayoutBranching"]
    RouteAssembly["BasicGUIRouteAssembly"] --> RootComposition["BasicGUIRootView"]
    LayoutBranching --> ChannelBrowseScreen["BasicGUIChannelBrowseScreen"]
    LayoutBranching --> RemoteSearchScreen["BasicGUIRemoteSearchScreen"]
    LayoutBranching --> BrowsePresentation["BasicGUIBrowsePresentation"]
    HomeViewModel["HomeScreenViewModel"] --> HomeLogic["HomeScreenLogic"]
    ChannelBrowseViewModel["ChannelBrowseViewModel"] --> ChannelBrowseLogic["ChannelBrowseLogic"]
    RemoteSearchViewModel["RemoteSearchResultsViewModel"] --> RemoteSearchState["RemoteSearchPresentationState"]
    BrowsePresentation --> Compact["compact presentation"]
    BrowsePresentation --> Regular["regular presentation"]
    BrowsePresentation --> SplitDetail["split detail presentation"]
```

### データフロー図（View -> ViewModel -> Coordinator -> Service -> Store / Infrastructure）

対象は View から画面単位の ViewModel、`FeedCacheCoordinator` を経由して Service、Store、Infrastructure へ至る呼び出し関係とデータの流れである。View ツリー、route / layout / presentation の判断配置は含めない。

```mermaid
flowchart TD
    BrowseViews["Browse / Search Views"] --> BrowseViewModels["Browse Feature ViewModels"]
    HomeView["HomeScreenView"] --> HomeViewModel["HomeScreenViewModel"]
    BrowseViewModels --> Coordinator["FeedCacheCoordinator"]
    HomeViewModel --> Coordinator

    Coordinator --> Read["FeedCacheReadService"]
    Coordinator --> Write["FeedCacheWriteService"]
    Coordinator --> Sync["FeedChannelSyncService"]
    Coordinator --> RegistryMaintenance["ChannelRegistryMaintenanceService"]
    Coordinator --> RemoteSearch["RemoteVideoSearchService"]
    Coordinator --> HomeStatus["HomeSystemStatusService"]

    Read --> Store["FeedCacheStore"]
    Read --> RemoteSearch
    Write --> Store
    Sync --> Write
    RegistryMaintenance --> Read
    RegistryMaintenance --> Write
    RegistryMaintenance --> YouTubeFeed["YouTubeFeed"]
    RemoteSearch --> RemoteSearchCache["RemoteVideoSearchCacheStore"]
    RemoteSearch --> YouTubeSearch["YouTubeSearchService"]
    YouTubeSearch --> SearchModels["YouTubeSearchModels"]
    YouTubeSearch --> SearchListResponse["YouTubeSearchListResponse"]
    YouTubeSearch --> VideoListResponse["YouTubeVideoListResponse"]
    YouTubeSearch --> SearchProcessing["YouTubeSearchProcessing"]
```

### classDiagram の扱い

`classDiagram` は Service / Store / Model の関係を確認する補助資料としてだけ使う。route / layout / UI orchestration は判断配置図で扱い、`classDiagram` を主説明にしない。

## 主要シーケンス

### ホームからチャンネル別動画一覧を開く

```mermaid
sequenceDiagram
    actor User
    participant Home as HomeScreenView
    participant Browse as ChannelBrowseView
    participant BrowseVM as ChannelBrowseViewModel
    participant Coord as FeedCacheCoordinator
    participant Read as FeedCacheReadService
    participant Store as FeedCacheStore

    User->>Home: チャンネル一覧を開く
    Home->>Browse: navigate
    Browse->>BrowseVM: loadChannelBrowseItems()
    BrowseVM->>Coord: loadChannelBrowseItems()
    Coord->>Read: loadChannelBrowseItems()
    Read->>Store: read channel registry + cache
    Store-->>Coord: ChannelBrowseItem[]
    Coord-->>BrowseVM: ChannelBrowseItem[]
    BrowseVM-->>Browse: items
    User->>Browse: チャンネルを選択
    Browse->>BrowseVM: selectChannel(context)
    BrowseVM->>Coord: openChannelVideos(context)
    Coord->>Read: loadMergedVideosForChannel()
    Read->>Store: load cached videos
    Store-->>Coord: CachedVideo[]
    Coord-->>BrowseVM: CachedVideo[]
    BrowseVM-->>Browse: videos
```

### YouTube検索の更新と表示

```mermaid
sequenceDiagram
    actor User
    participant View as RemoteKeywordSearchResultsView
    participant VM as RemoteSearchResultsViewModel
    participant Logic as RemoteSearchPresentationState
    participant Coord as FeedCacheCoordinator
    participant Search as RemoteVideoSearchService
    participant Cache as RemoteVideoSearchCacheStore
    participant API as YouTubeSearchService

    User->>View: pull-to-refresh / Refresh command
    View->>VM: refresh(keyword, forceRefresh: true)
    VM->>Coord: searchRemoteVideos(keyword, forceRefresh: true)
    Coord->>Search: searchRemoteVideos()
    Search->>API: request
    API-->>Search: remote results
    Search->>Cache: merge and persist
    Cache-->>Search: snapshot
    Search-->>Coord: VideoSearchResult
    Coord-->>VM: result
    VM->>Logic: build(result, usesSplitChannelBrowser)
    Logic-->>VM: visibleCount / chip / default selection
    VM-->>View: presentation state
```

## 依存関係メモ

### UI構造メモ

- `ContentView` は launch 直後の入口として `BasicGUIRootView` を表示する。
- `BasicGUIRootView` は home、browse、all videos、keyword search、remote search の各 screen を束ねる。
- `InteractiveListView` は一覧系画面の共通コンテナとして使う。
- `VideoTile` と `ChannelTile` は一覧内の共通表示部品として使う。
- `HomeScreenView` は hidden host の表示枠を持つ。prewarm の開始、snapshot 読込、mounting state は `HomeScreenViewModel` が担う。

### 判断配置メモ

- `BasicGUIRouteAssembly` は basic GUI の route mapping を担う。
- `AppLayout` は regular 幅かどうかを基準に layout 判定を返す。
- `BasicGUILayoutBranching` は `AppLayout` の判定を browse 系 screen 向けの分岐へ写し替える。
- `BasicGUIBrowsePresentation` は browse 系画面の compact / regular / split detail presentation を決める。
- `HomeScreenLogic`、`ChannelBrowseLogic`、`RemoteSearchPresentationState` は feature-local pure logic として、画面固有の表示状態と状態遷移をまとめる。
- `RemoteSearchPresentationState` は YouTube 検索結果の visibleCount、chip 状態、split 初期選択を pure logic としてまとめる。
- `View` は `iPhone` / `iPad` / `Mac` の操作差分を UI 層で吸収する。

### データフローメモ

- `View` は I/O、画面単位の async、状態分岐、副作用起動、event log を直接持たず、UI trigger を ViewModel へ渡す。
- `View` は binding、animation、dialog、render probe、描画到達の観測、platform ごとの見た目の違いを UI 層で扱う。
- `ViewModel` は `refreshFeed()`、paging、split selection、prewarm、delete、export / import / reset、event log など、画面単位の非同期 orchestration と副作用起動を担う。
- `FeedCacheCoordinator` は複数画面で共有される状態と service / use case 入口を担い、読取り・書込み・同期・検索・ホーム状況集計を専用 service へ委譲する。
- `FeedCacheCoordinator` は画面固有の visible count、chip mode、selected split context、playlist paging cursor、prewarm host mounting state を持たない。
- `FeedCacheReadService` はキャッシュ読取り、動画検索、チャンネル動画マージをまとめる。
- `FeedCacheWriteService` はキャッシュ保存、サムネイル保存、bootstrap 永続化、整合性メンテナンスの入口を担う。
- `RemoteKeywordSearchResultsView` は `RemoteSearchResultsViewModel` の state を表示へ写像し、compact / regular / split detail の表示本体は別 View へ分けて扱う。
- `YouTubeSearchService` は API 呼び出しと error handling を担い、公開 model、decode DTO、結果整列 helper は別ファイルへ分けて扱う。

## 変更時の読み方

- 見た目、layout、animation、dialog、render probe、描画観測を変える場合は View を変更する。
- 画面単位の async、refresh、prewarm、paging、split selection、delete、export / import / reset、event log を変える場合は対象画面の ViewModel を変更する。
- 画面固有の選択、visible count、chip、feedback、presentation state の純粋な遷移を変える場合は feature-local Logic を変更する。
- 複数画面で共有する refresh progress、manual refresh count、home system status、remote search managed task、service / use case 入口を変える場合は `FeedCacheCoordinator` または関連 extension を変更する。
- 永続化、cache、registry maintenance、外部 API、feed 取得を変える場合は Service、Use Case、Store、Infrastructure を変更する。
- 局所修正でも、View へ非同期処理を戻さず、Coordinator へ画面固有 cursor を寄せず、Shared へ feature-local state を戻さない。

### 同期メモ

- 正本を更新した時は、本書の主要構造図、主要シーケンスも同じ変更セットで同期する。
