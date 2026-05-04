# プレイリストサムネイル参照制約違反レポート

## 暫定結論

今回もっとも効いたのは、後続指摘で `サムネイルの参照はデータストア経由` という既存制約に照合し直したことである。これにより、画像未表示の直接原因だけでなく、直前修正が View 層から remote URL を直接 `AsyncImage` へ渡し、Store / SQLite の参照更新経路を迂回していたことを特定できた。

主な課題は、最初の不具合対応時に「画像が表示されない」現象を表示層で解消する方向へ短絡し、サムネイル参照・保存・最終アクセス時刻更新の既存データ契約へ戻らなかったことである。次回は、画像やキャッシュの不具合では、`View` の表示修正へ進む前に、`FeedCacheWriteService`、`FeedCacheStore`、`FeedCacheSQLiteDatabase` のどの契約が破れているかを先に固定する必要がある。

改善対象の主コストは LLM の試行錯誤ループである。副目的として、実装修正後の巻き戻しや追加調査にかかる時間コストも削減する。

## 目的

このレポートは、プレイリスト一覧カードの画像未表示とインデックスずれの調査中に、サムネイル参照をデータストア経由とする制約へ違反する変更を入れた経緯を記録するための参照資料である。

対象範囲は次の通りである。

- プレイリスト一覧カードの画像未表示を調査した流れ。
- `ThumbnailView` へ remote URL の直接 `AsyncImage` 表示を追加した判断経路。
- その判断が、サムネイル参照時の Store / SQLite 経路と衝突した理由。
- 次回同種の不具合対応で削減すべき確認漏れとループ。

この文書は仕様や設計の正本ではない。正本は `docs/specs/` と実装側の Store / Service 境界である。

## 実施の流れ

### 1. 画面上の不具合を受け取った

ユーザーは、スクリーンショットを添えて次の 2 点を指摘した。

- プレイリスト一覧カードに画像が表示されていない。
- プレイリスト一覧カードのインデックスが `2` から始まっている。

この時点で、表示要件に関係するため `docs/specs/specs-product.md` を読み、プレイリストカード画像は「プレイリストの先頭動画のサムネイルを使用する」と確認した。

### 2. 番号ずれは二重加算として特定した

`ChannelBrowseViews.swift` のプレイリスト一覧では、`ForEach(Array(playlistsForSelectedChannel.enumerated()))` から `index: offset + 1` を渡していた。

一方、当時の `PlaylistTileIndexBadge` は `Text("\(index + 1)")` と表示していた。呼び出し側と表示側で 2 回加算していたため、先頭が `2` になっていた。

この原因分析は、表示上の単純な off-by-one として成立していた。

### 3. 画像未表示の原因をプレイリストIDと動画IDの混同として見た

`ChannelBrowseViewModel.playlistPreviewVideo(for:)` は、プレイリストカードを `ThumbnailView` に渡すため、`PlaylistBrowseItem` から疑似 `CachedVideo` を組み立てていた。

その疑似 `CachedVideo` では、`id` に `item.playlistID` を入れ、`thumbnailRemoteURL` には `item.firstVideoThumbnailURL ?? item.thumbnailURL` を入れていた。

既存の `FeedCacheStore.cacheThumbnail(for video: CachedVideo)` は、`video.thumbnailRemoteURL` ではなく `video.id` を動画 ID として `YouTubeThumbnailCandidates.urls(for:)` を作る。プレイリスト ID を動画 ID として扱うため、サムネイル取得候補が外れる。

ここまでの原因分析は妥当だった。

### 4. 違反した分岐点

分岐点は、上記の原因を見た後に、データ契約側を直さず `ThumbnailView` の表示分岐を増やしたことである。

直前変更では、ローカルファイル名がない場合に `video.thumbnailRemoteURL` を取り出し、View 層で `AsyncImage(url: remoteURL)` を直接生成する経路を追加した。

この判断は、次の既存契約から外れる。

- `View` は I/O を直接持たず、外部通信、永続化、複雑な判定は内側の層へ委譲する。
- `FeedCacheWriteService` は thumbnail 反映の単一入口である。
- `FeedCacheStore` は cache、snapshot、thumbnail、整合性メンテナンスを担う。
- `FeedCacheSQLiteDatabase` は thumbnail の `thumbnail_last_accessed_at` を保持・更新する。
- 過去の Issue 4 詳細化では、`AsyncImage` 生成時点をサムネイル参照とみなす定義が採用されている。

つまり、remote URL の直接表示は「一時的に画像が見える」可能性はあるが、サムネイル参照として Store / SQLite に記録されない。参照時刻更新、ローカルファイル正本、廃棄候補管理の経路から外れる。

## 評価

### 成立した点

- インデックスが `2` から始まる原因は、呼び出し側 `offset + 1` とバッジ側 `index + 1` の二重加算として特定できた。
- 画像未表示の直接原因も、プレイリスト用疑似 `CachedVideo.id` が動画 ID ではなく playlist ID であることと、`FeedCacheStore.cacheThumbnail(for:)` が `video.id` から候補URLを生成していることとして特定できた。
- 後続調査により、直前変更が Store / SQLite の参照更新経路を迂回していることを明確化できた。

### 問題だった点

- 原因分析後、`thumbnailRemoteURL` を View に直接表示させる方向へ進んだ。
- `docs/specs/specs-architecture.md` と `docs/specs/specs-design.md` の責務境界を、修正直前に再照合しなかった。
- `recordThumbnailReference(filename:)` と `updateThumbnailLastAccessedAt(filename:)` の既存経路を、修正案の評価軸に入れなかった。
- プレイリストサムネイルの「先頭動画サムネイル」という仕様を、Store に渡すデータ契約ではなく View の表示入力として解釈した。
- 関連テストは ChannelBrowseLogic に寄り、サムネイル参照が Store 経由になることを固定していなかった。

## 今後の改善

同種の不具合では、次の順で確認する。

1. 画像表示の不具合でも、まず表示層ではなく `CachedVideo` の `id`、`thumbnailRemoteURL`、`thumbnailLocalFilename` の契約を確認する。
2. `ThumbnailView` を変更する前に、`FeedCacheWriteService.cacheThumbnail` と `FeedCacheStore.cacheThumbnail` の入力契約に合っているか確認する。
3. ローカルファイル名がない画像表示を扱う場合は、remote URL を直接 `AsyncImage` へ渡してよいかではなく、Store がどうローカル保存し、どう参照時刻を更新するかを先に決める。
4. `AsyncImage` 生成時点を参照とみなす既存定義に照合し、生成される全経路が `recordThumbnailReference` 相当の観測に入るか確認する。
5. テストは、表示結果だけでなく、プレイリストプレビュー画像が Store / SQLite のサムネイル参照経路へ入る契約を固定する。

次回削減すべきループは、表示上の症状から UI 層へ直接パッチを入れ、その後に責務境界違反として再調査する流れである。画像、キャッシュ、ファイル、外部 URL が関わる場合は、先に Store 境界を確認することで、このループを削減できる。

## Appendix A. ユーザー指示全文

### 1. 不具合調査と解決指示

> この画面を見ると、プレイリスト一覧にのカードに画像が表示されていない。またインデックスが2からスタートしている。原因を調査し、解凍せよ。

添付スクリーンショットには、チャンネル一覧の右ペインでプレイリスト一覧カードが表示され、カードの背景がグラデーションのみで画像が出ておらず、右上バッジが `2` と `3` から始まる状態が示されていた。

### 2. 制約違反の調査指示

> 修正するな。コミットするな。サムネイルの参照はデータストア経由とする制約があるはずだが、それに違反した経緯を調査せよ。謝罪するな。

### 3. レポート作成指示

> 今回の経緯をレポートとして出力せよ。

## Appendix B. LLM 出力の概要

### 1. 不具合調査フェーズ

- 入力フックとユーザー指示理解を実施した。
- 表示要件に関係するため `docs/specs/specs-product.md` を読んだ。
- プレイリストカード画像は先頭動画サムネイルを使用する仕様と確認した。
- `ChannelBrowseViews.swift`、`ChannelBrowseViewModel.swift`、`BrowseComponents.swift` を読み、プレイリストカードの構成とサムネイル表示経路を調査した。

### 2. 実装フェーズ

- `PlaylistTileIndexBadge` の `index + 1` を問題として特定した。
- `PlaylistBrowseTile` を新規ファイルへ切り出し、番号表示を `index` そのものへ変更した。
- `ThumbnailView` に `thumbnailRemoteURL` を直接 `AsyncImage` へ渡す分岐を追加した。
- この時点で、サムネイル参照を Store / SQLite に記録する経路を通すかどうかの評価を抜かした。

### 3. 検証フェーズ

- `build-debug` は成功した。
- `ChannelBrowseLogicTests` は成功した。
- `swiftlint lint` は今回未変更の既存箇所で違反を報告した。
- `metrics-collect` と `metrics-test-collect` は、この環境の iOS Simulator destination 制約により失敗した。

### 4. 制約違反調査フェーズ

- ユーザーから、修正・コミット禁止、謝罪禁止、制約違反の経緯調査を指示された。
- `docs/specs/specs-architecture.md`、`docs/specs/specs-design.md`、`FeedCacheStore`、`FeedCacheSQLiteDatabase`、過去レポートを読み直した。
- remote URL 直接表示が、Store / SQLite の `thumbnail_last_accessed_at` 更新経路を迂回していると整理した。

## Appendix C. 試行錯誤と削減対象

### ループ 1. 画像未表示を UI 表示問題として扱った

原因は、プレイリストIDと動画IDの混同により Store のサムネイル取得候補が成立しないことだった。ここで Store 側のデータ契約へ戻るべきだったが、View 側で remote URL を直接表示する分岐を追加した。

次回は、`CachedVideo.id` が本当に動画 ID か、`thumbnailRemoteURL` が保存経路で使われるか、`thumbnailLocalFilename` が参照更新へつながるかを先に確認する。

### ループ 2. 「表示されること」と「参照されたこと」を混同した

remote `AsyncImage` を作れば画像は表示されうる。しかし、このプロジェクトでは `AsyncImage` 生成時点をサムネイル参照とみなし、Store / SQLite へ最終アクセス時刻を記録する流れがある。表示だけでは参照管理の契約を満たさない。

次回は、画像表示の受け入れ条件に `thumbnail_last_accessed_at` 更新またはそれに相当する Store 経由の観測を含める。

### ループ 3. 関連テストの選択が表示ロジック寄りだった

実行した関連テストは ChannelBrowseLogic であり、プレイリストプレビュー画像の Store 経由参照を固定していなかった。そのため、責務境界違反を検出できなかった。

次回は、サムネイル関連の変更では `FeedCacheMaintenanceTests` など Store / SQLite の契約テストを先に候補へ入れる。

## Appendix D. 参照した主な根拠

- [specs-product.md](../specs/specs-product.md): プレイリストカード画像は、プレイリストの先頭動画のサムネイルを使用する。
- [specs-architecture.md](../specs/specs-architecture.md): View は I/O を直接持たず、依存方向は `View -> ViewModel -> Coordinator -> Service / Use Case -> Store or Infrastructure` を原則とする。
- [specs-design.md](../specs/specs-design.md): `FeedCacheWriteService` は thumbnail 反映の単一入口、`FeedCacheStore` は thumbnail と整合性メンテナンスを担う。
- [2026-03-29-issue4-session-report.md](2026-03-29-issue4-session-report.md): `AsyncImage` 生成時点を参照とみなす定義が採用されている。
- [BrowseComponents.swift](../../YoutubeFeeder/Features/Browse/BrowseComponents.swift): `ThumbnailView` がローカル filename 参照時に `recordThumbnailReference` を呼ぶ。
- [FeedCacheStore.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift): `recordThumbnailReference` と `cacheThumbnail` の Store 側実装。
- [FeedCacheSQLiteDatabase.swift](../../YoutubeFeeder/Features/FeedCache/FeedCacheSQLiteDatabase.swift): `thumbnail_last_accessed_at` を SQLite に更新する実装。
