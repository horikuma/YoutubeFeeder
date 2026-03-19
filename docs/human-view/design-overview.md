# HelloWorld Design Overview

この文書は、人間のエンジニア向けに `rules.md`、`spec.md`、`architecture.md`、`design.md` の内容を UML 風に読み替えた設計資料である。正本ではなく、関連する正本文書を人間が俯瞰しやすい形へ翻訳した `human-view` 文書として継続管理する。

文書群全体での役割分担は [document-roles.md](../document-roles.md)、文書運用ルールは [document-operations.md](../document-operations.md) を参照する。GUI の人間向け参照は [gui.md](./gui.md)、正本は [rules.md](../rules.md)、[spec.md](../spec.md)、[architecture.md](../architecture.md)、[design.md](../design.md) である。

## レイヤ構成

```mermaid
flowchart LR
    View["SwiftUI View"] --> Coordinator["Coordinator / UI Orchestration"]
    Coordinator --> Service["Service / Use Case"]
    Service --> Store["Store"]
    Service --> Infra["Infrastructure"]
    Store --> Files["Local Files / Cache / Registry"]
    Infra --> YouTube["YouTube API / Feed"]
```

## 主要クラス図

```mermaid
classDiagram
    class ContentView
    class AppLayout
    class FeedCacheCoordinator
    class ChannelBrowseListView["ChannelBrowseListView<br/>[Adaptive UI]"]
    class ChannelVideosView
    class AllVideosView
    class KeywordSearchResultsView
    class RemoteKeywordSearchResultsView["RemoteKeywordSearchResultsView<br/>[Adaptive UI]"]
    class InteractiveListScreen
    class ChannelTile
    class ChannelSelectionTile
    class VideoTile
    class FeedCacheStore
    class ChannelRegistryMaintenanceService
    class RemoteVideoSearchService
    class RemoteVideoSearchCacheStore
    class YouTubeFeed
    class YouTubeSearchService
    class RemoteSearchPresentationState

    ContentView --> AppLayout : computes
    ContentView --> FeedCacheCoordinator : owns
    ContentView --> ChannelBrowseListView
    ContentView --> AllVideosView
    ContentView --> KeywordSearchResultsView
    ContentView --> RemoteKeywordSearchResultsView

    ChannelBrowseListView --> FeedCacheCoordinator
    ChannelVideosView --> FeedCacheCoordinator
    AllVideosView --> FeedCacheCoordinator
    KeywordSearchResultsView --> FeedCacheCoordinator
    RemoteKeywordSearchResultsView --> FeedCacheCoordinator

    ChannelBrowseListView --> InteractiveListScreen
    RemoteKeywordSearchResultsView --> InteractiveListScreen
    AllVideosView --> InteractiveListScreen
    KeywordSearchResultsView --> InteractiveListScreen
    ChannelVideosView --> VideoTile
    AllVideosView --> VideoTile
    KeywordSearchResultsView --> VideoTile
    RemoteKeywordSearchResultsView --> VideoTile
    ChannelBrowseListView --> ChannelTile
    ChannelBrowseListView --> ChannelSelectionTile

    FeedCacheCoordinator --> FeedCacheStore
    FeedCacheCoordinator --> ChannelRegistryMaintenanceService
    FeedCacheCoordinator --> RemoteVideoSearchService
    RemoteVideoSearchService --> RemoteVideoSearchCacheStore
    RemoteVideoSearchService --> YouTubeSearchService
    FeedCacheCoordinator --> YouTubeFeed

    RemoteKeywordSearchResultsView --> RemoteSearchPresentationState : uses
```

## 主要シーケンス

### ホームからチャンネル別動画一覧を開く

```mermaid
sequenceDiagram
    actor User
    participant Home as HomeScreenView
    participant Browse as ChannelBrowseListView
    participant Coord as FeedCacheCoordinator
    participant Store as FeedCacheStore

    User->>Home: チャンネル一覧を開く
    Home->>Browse: navigate
    Browse->>Coord: loadChannelBrowseItems()
    Coord->>Store: read channel registry + cache
    Store-->>Coord: ChannelBrowseItem[]
    Coord-->>Browse: items
    User->>Browse: チャンネルを選択
    Browse->>Coord: openChannelVideos(context)
    Coord->>Store: load cached videos
    Store-->>Coord: CachedVideo[]
    Coord-->>Browse: videos
```

### YouTube検索の更新と表示

```mermaid
sequenceDiagram
    actor User
    participant View as RemoteKeywordSearchResultsView
    participant State as RemoteSearchPresentationState
    participant Coord as FeedCacheCoordinator
    participant Search as RemoteVideoSearchService
    participant Cache as RemoteVideoSearchCacheStore
    participant API as YouTubeSearchService

    User->>View: pull-to-refresh
    View->>Coord: searchRemoteVideos(keyword, forceRefresh: true)
    Coord->>Search: searchRemoteVideos()
    Search->>API: request
    API-->>Search: remote results
    Search->>Cache: merge and persist
    Cache-->>Search: snapshot
    Search-->>Coord: VideoSearchResult
    Coord-->>View: result
    View->>State: build(result, usesSplitChannelBrowser)
    State-->>View: visibleCount / chip / default selection
```

## 依存関係メモ

- `View` は I/O を直接持たず、`FeedCacheCoordinator` 経由で状態と操作を受ける。
- `AppLayout` は adaptive 判定を持つが、機能差分は持たない。
- クラス枠内に `[Adaptive UI]` を付けた View は、内部に `CompactView` / `RegularView` の表現差分を持つが、資料上は 1 つの機能 View として扱う。
- `RemoteSearchPresentationState` は YouTube 検索結果の UI 状態を pure logic として切り出す。
- 正本を更新した時は、本書のクラス図、シーケンス図も同じ変更セットで同期する。
