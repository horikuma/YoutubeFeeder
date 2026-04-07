# Source Metrics Snapshot

この文書は、`2026-04-08` 時点のソース構成を把握するための単発スナップショットである。継続更新の規則はまだ定めず、現時点の規模感、偏り、健康度の入口を確認する用途に使う。

## 対象と前提

- 対象ソースは `YoutubeFeeder/` 配下の `Swift` ファイルとする。
- 対象ドキュメントは、当時の正本 `6` 文書とする。
- 健全性のバロメタは `scripts/metrics-health-check` の基準に従う。
- この文書の数値は、`2026-04-08 04:07:29 +0900` 時点のワークツリーから取得した。

## サマリー

| 項目 | 値 | 補足 |
| --- | ---: | --- |
| `Swift` ファイル数 | `48` | `YoutubeFeeder/` 配下のみ |
| ソース総行数 | `10,563` 行 | `Swift` のみ |
| 正本文書数 | `6` | `docs/` 直下の source of truth |
| 正本文書総行数 | `1,042` 行 | `rules` / `specs` 系 |
| 正本文書比率 | `9.9%` | `1,042 / 10,563` |
| 最大ファイル行数 | `803` 行 | `FeedCacheSQLiteDatabase.swift` |
| 最大関数行数 | `89` 行 | `createSchema` |
| 最大 top-level type 数 | `18` | `AppLogic.swift` |
| `ObservableObject surface` 超過 | `なし` | 現在の barometer では未検出 |

## 健全性バロメタ

### 現在のしきい値

| 指標 | WARN | FAIL |
| --- | ---: | ---: |
| `Swift` ファイル行数 | `500` 行以上 | `900` 行以上 |
| 関数行数 | `60` 行以上 | `80` 行以上 |
| `1` ファイル内の top-level type 数 | `12` 超 | `-` |
| `ObservableObject` / coordinator の `@Published` 状態量 | `8` 超 | `12` 超 |

### 現在の結果

- `Result: FAIL`
- hard failure は `1` 件
- file length の `WARN/FAIL` は `6` 件
- function length の `FAIL` は `1` 件
- top-level type count の `WARN` は `3` 件
- `ObservableObject surface` の超過は `0` 件

### 現在の主な引っかかり

| 種別 | 状態 | 対象 | 値 |
| --- | --- | --- | ---: |
| file length | `WARN` | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift` | `803` 行 |
| file length | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `545` 行 |
| file length | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchService.swift` | `544` 行 |
| file length | `WARN` | `YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift` | `541` 行 |
| file length | `WARN` | `YoutubeFeeder/Features/Browse/ChannelBrowseViews.swift` | `539` 行 |
| file length | `WARN` | `YoutubeFeeder/App/Support/AppTestSupport.swift` | `510` 行 |
| function length | `FAIL` | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift:createSchema` | `89` 行 |
| type count | `WARN` | `YoutubeFeeder/Shared/AppLogic.swift` | `18` 型 |
| type count | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `16` 型 |
| type count | `WARN` | `YoutubeFeeder/Features/Browse/BrowseComponents.swift` | `15` 型 |

## 観測メモ

- 現時点の hard failure は `FeedCacheSQLiteDatabase.swift:createSchema` の `89` 行だけで、schema 構築の長さが最大の健康度リスクとして残っている。
- file length は `FeedCache` 系だけでなく `ChannelBrowseViews.swift` も `539` 行で警告域へ入り、browse composition も監視対象に上がっている。
- `Shared/AppLogic.swift` は top-level type 数が `18` に増えており、共通ロジック集約の見直し余地が大きい。
- `BasicGUIComposition.swift` の追加で app root の composition 境界は見えやすくなった一方、正本文書は `1,042` 行でソース総行数比 `9.9%` に留まっている。

## Appendix A: ソース行数上位

| 順位 | ファイル | 行数 |
| ---: | --- | ---: |
| 1 | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift` | `803` |
| 2 | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `545` |
| 3 | `YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchService.swift` | `544` |
| 4 | `YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift` | `541` |
| 5 | `YoutubeFeeder/Features/Browse/ChannelBrowseViews.swift` | `539` |
| 6 | `YoutubeFeeder/App/Support/AppTestSupport.swift` | `510` |
| 7 | `YoutubeFeeder/Features/Browse/RemoteSearchResultsViews.swift` | `498` |
| 8 | `YoutubeFeeder/Features/Browse/BrowseComponents.swift` | `491` |
| 9 | `YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator+Refresh.swift` | `438` |
| 10 | `YoutubeFeeder/Shared/AppLogic.swift` | `420` |
| 11 | `YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator.swift` | `403` |
| 12 | `YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator+RemoteSearch.swift` | `392` |
| 13 | `YoutubeFeeder/Features/Home/HomeScreenView.swift` | `386` |
| 14 | `YoutubeFeeder/Features/FeedCache/FeedCacheStorageModels.swift` | `275` |
| 15 | `YoutubeFeeder/Features/Browse/RemoteSearchResultsContentViews.swift` | `269` |
| 16 | `YoutubeFeeder/Features/Home/ChannelRegistrationView.swift` | `250` |
| 17 | `YoutubeFeeder/Features/FeedCache/FeedCacheReadService.swift` | `222` |
| 18 | `YoutubeFeeder/Features/FeedCache/ChannelRegistryStore.swift` | `205` |
| 19 | `YoutubeFeeder/App/BasicGUIComposition.swift` | `194` |
| 20 | `YoutubeFeeder/Features/FeedCache/ChannelRegistryCSVImport.swift` | `192` |

## Appendix B: 正本文書の行数

| 文書 | 行数 |
| --- | ---: |
| `docs/specs/specs-product.md` | `464` |
| `docs/specs/specs-design.md` | `278` |
| `docs/specs/specs-architecture.md` | `147` |
| `docs/rules.md` | `75` |
| `docs/specs/specs-environment.md` | `48` |
| `docs/specs.md` | `30` |
