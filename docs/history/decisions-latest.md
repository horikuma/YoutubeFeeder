## 2026/04/06
- FeedCacheのremote search cacheはReadServiceが読取り、WriteServiceが保存・削除を担う構成に固定する。
  - ユースケースServiceからRead/Write境界への依存方向を維持し、読取り層へ副作用を残さないため。
