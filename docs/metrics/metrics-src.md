# Source Metrics Snapshot

この文書は、`2026-03-21` 時点のソース構成を把握するための単発スナップショットである。継続更新の規則はまだ定めず、現時点の規模感、偏り、健康度の入口を確認する用途に使う。

## 対象と前提

- 対象ソースは `YoutubeFeeder/` 配下の `Swift` ファイルとする。
- 対象ドキュメントは、当時の正本 `6` 文書とする。
- 健全性のバロメタは `scripts/health-barometer.sh` の基準に従う。
- この文書の数値は、`2026-03-21 17:14:55 +0900` 時点のワークツリーから取得した。

## サマリー

| 項目 | 値 | 補足 |
| --- | ---: | --- |
| `Swift` ファイル数 | `40` | `YoutubeFeeder/` 配下のみ |
| ソース総行数 | `9,233` 行 | `Swift` のみ |
| 正本文書数 | `6` | `docs/` 直下の source of truth |
| 正本文書総行数 | `1,173` 行 | `rules` / `spec` / `architecture` / `design` 系 |
| 正本文書比率 | `12.7%` | `1,173 / 9,233` |
| 最大ファイル行数 | `1,235` 行 | `FeedCacheCoordinator.swift` |
| 最大関数行数 | `87` 行 | `createSchema` |
| 最大 top-level type 数 | `16` | `YouTubeFeed.swift` |
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
- hard failure は `2` 件
- file length の `WARN/FAIL` は `6` 件
- function length の `FAIL` は `1` 件
- top-level type count の `WARN` は `3` 件
- `ObservableObject surface` の超過は `0` 件

### 現在の主な引っかかり

| 種別 | 状態 | 対象 | 値 |
| --- | --- | --- | ---: |
| file length | `FAIL` | `YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator.swift` | `1,235` 行 |
| file length | `WARN` | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift` | `700` 行 |
| file length | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `548` 行 |
| file length | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchService.swift` | `544` 行 |
| file length | `WARN` | `YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift` | `524` 行 |
| file length | `WARN` | `YoutubeFeeder/App/Support/AppTestSupport.swift` | `510` 行 |
| function length | `FAIL` | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift:createSchema` | `87` 行 |
| type count | `WARN` | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `16` 型 |
| type count | `WARN` | `YoutubeFeeder/Features/Browse/BrowseComponents.swift` | `14` 型 |
| type count | `WARN` | `YoutubeFeeder/Shared/AppLogic.swift` | `13` 型 |

## 観測メモ

- 現時点の最大リスクは、`FeedCacheCoordinator` の巨大化と `FeedCacheSQLiteDatabase` の schema 構築関数の長さである。
- `SQLite` 移行後の `FeedCache` 周辺に行数が寄っており、永続化、集約、起動補助の責務が密集している。
- `Browse` 系は分割が進んでいるが、`BrowseComponents.swift` の top-level type 数はまだ多い。
- 正本文書は `1,173` 行で、ソース総行数比では `12.7%` に留まる。規模の俯瞰用としては足りているが、実装密度の高い領域ほど詳細設計文書への追記余地がある。

## Appendix A: ソース行数上位

| 順位 | ファイル | 行数 |
| ---: | --- | ---: |
| 1 | `YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator.swift` | `1,235` |
| 2 | `YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift` | `700` |
| 3 | `YoutubeFeeder/Infrastructure/YouTube/YouTubeFeed.swift` | `548` |
| 4 | `YoutubeFeeder/Infrastructure/YouTube/YouTubeSearchService.swift` | `544` |
| 5 | `YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift` | `524` |
| 6 | `YoutubeFeeder/App/Support/AppTestSupport.swift` | `510` |
| 7 | `YoutubeFeeder/Features/Browse/ChannelBrowseViews.swift` | `495` |
| 8 | `YoutubeFeeder/Features/Browse/RemoteSearchResultsViews.swift` | `488` |
| 9 | `YoutubeFeeder/Features/Browse/BrowseComponents.swift` | `416` |
| 10 | `YoutubeFeeder/Features/Home/HomeScreenView.swift` | `383` |
| 11 | `YoutubeFeeder/Shared/AppLogic.swift` | `323` |
| 12 | `YoutubeFeeder/Features/FeedCache/FeedCacheStorageModels.swift` | `268` |
| 13 | `YoutubeFeeder/Features/Browse/RemoteSearchResultsContentViews.swift` | `265` |
| 14 | `YoutubeFeeder/Features/FeedCache/ChannelRegistryStore.swift` | `205` |
| 15 | `YoutubeFeeder/Features/Browse/BrowseViews.swift` | `176` |
| 16 | `YoutubeFeeder/Features/Browse/SearchResultsViews.swift` | `171` |
| 17 | `YoutubeFeeder/Features/FeedCache/FeedCacheChannelModels.swift` | `155` |
| 18 | `YoutubeFeeder/Features/FeedCache/RemoteVideoSearchService.swift` | `152` |
| 19 | `YoutubeFeeder/Features/Home/HomeUIComponents.swift` | `141` |
| 20 | `YoutubeFeeder/Features/Home/ChannelRegistrationView.swift` | `140` |

## Appendix B: 正本文書の行数

| 文書 | 行数 |
| --- | ---: |
| `docs/specs/specs-product.md` | `459` |
| `docs/specs/specs-design.md` | `260` |
| `docs/rules/rules-document.md` | `173` |
| `docs/specs/specs-architecture.md` | `141` |
| `docs/rules.md` | `114` |
| `docs/rules/rules-design.md` | `26` |
