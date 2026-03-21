# Performance Troubleshooting Report 2026-03-20

この文書は、2026-03-20 に実施した YouTube 検索まわりの処理負荷トラブル探索を、再利用可能な調査記録として整理した参照資料である。正本の方針や責務定義は [rules.md](../rules.md)、[architecture.md](../architecture.md)、[design.md](../design.md) を参照する。

## Summary

- 起動時の重さの主犯は、`FeedCacheStore.loadSnapshot` と `RemoteVideoSearchCacheStore.status` が `@MainActor` 上で実行される初回 JSON decode だった。
- iPad の YouTube 検索画面展開の重さは、当初疑った `右ペイン初期読込` や `YouTube 通信` ではなく、起動前半のキャッシュ decode と、その後に残る `SwiftUI split 初回構築` 寄りの問題だった。
- 実施した対策のうち当たりだったものは、`refreshable` からの検索処理切り離し、起動/描画/キャッシュ decode の分解ログ、ホーム用 summary sidecar、summary の binary property list 化である。
- 外れだったものは、`右ペイン遅延なし`, `左ペイン件数削減`, `右ペイン初回読込なし`, `NavigationSplitView + List(selection:)` への標準寄せだけでの解決期待だった。
- 最終状態では、起動側は秒級の decode を解消できた。残件は、YouTube 検索画面展開時に残る軽い引っかかりで、ログ上は `SwiftUI split 初回構築/描画` が本命候補として残った。

## 対象症状

### 1. YouTube 検索失敗と Cancelled 表示

- 実機で YouTube 検索が失敗しているように見え、キャッシュが空の時に `Cancelled` タイルが表示された。
- 当初は YouTube API 失敗に見えたが、ログ追加後は `refreshable` 由来の task cancellation が主因であることが分かった。

### 2. iPad の YouTube 検索画面展開の引っかかり

- ホームの `YouTube検索` タイルをタップして G 画面へ遷移する時、iPad では右ペイン H 画面が同時に組み立てられ、体感上かなりカクついた。
- `右ペインでチャンネル動画を一気に読んでいるからではないか` が初期仮説だった。

### 3. 起動自体も遅い

- ログを広げると、スプラッシュ表示まで、ホーム表示までの区間も長かった。
- YouTube 検索画面展開の違和感と、起動時 decode の重さが混ざって体感されている可能性が生じた。

## 調査の前提

### 対象コードの責務

- [FeedCacheCoordinator.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/FeedCache/FeedCacheCoordinator.swift)
  - 画面から見たキャッシュ協調、YouTube 検索、split 右ペイン読込の入口。
- [SearchResultsViews.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/Browse/SearchResultsViews.swift)
  - YouTube 検索画面の左ペイン/右ペイン構築、split 初期選択、`refreshable`。
- [FeedCacheStore.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/FeedCache/FeedCacheStore.swift)
  - 通常キャッシュ `cache.json` の読込/保存。
- [RemoteVideoSearchCacheStore.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/FeedCache/RemoteVideoSearchCacheStore.swift)
  - 検索キャッシュ `remote-search*.json` の読込/保存/鮮度確認。
- [HomeSystemStatusService.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/FeedCache/HomeSystemStatusService.swift)
  - ホーム画面へ出す `cached_videos`、`search cache status`、`thumbnail bytes` などの集約。

### 観測ポリシー

- Xcode コンソールは `[YoutubeFeeder]` プレフィックスの一行ログへ統一した。
- `app.lifecycle.*` と `youtube.search.*` を併用し、起動、ホーム、G 画面、右ペイン、通信、decode を同じ系列で追えるようにした。
- 調査中はログ量を一時的に増やし、解決後に常設ログだけを残す運用とした。

## 変遷

### Phase 1. refreshable cancellation の切り分け

#### 仮説

- `PullToRefresh` の設計が不安定で、通信処理まで巻き込んでいるのではないか。

#### 観測

- `request_start` 直後に `http_cancelled reason="urlsession_cancelled"` が出るケースがあった。
- `refreshable` task は `cancelled="true"` になる一方、managed task 化後は通信完走できた。

#### 結論

- `refreshable` 自体が壊れているのではなく、`UI task の寿命` と `YouTube 検索本体の寿命` を直結していたのが問題だった。
- `refreshable` は trigger のみ、検索本体は coordinator 側 managed task へ移すのが当たりだった。

### Phase 2. iPhone の decode failure 切り分け

#### 仮説

- YouTube API の `videos.list` 応答に対して `Decodable` が厳しすぎるのではないか。

#### 観測

- `search` は HTTP 200 で成功していたが、`videos` バッチで `decode_failure` が発生するログが出た。
- その後、`codingPath` を出すようにして、どの field が欠けたか追えるようにした。

#### 結論

- `refreshable` 問題とは別に、YouTube 応答の decode failure が一部実機で発生しうることを確認した。
- ただし今回の主系列では、これは常時再現ではなく、性能問題の本丸ではなかった。

### Phase 3. iPad split 初期読込が犯人か

#### 仮説

- G 画面遷移と同時に H 画面読込まで走り、それが引っかかりの主因ではないか。

#### 実施

- `openChannelVideos` の開始/完了を計測。
- H 画面初期読込を短い遅延つきへ変更。
- probe mode で `右ペイン遅延なし`, `左ペイン件数20件`, `右ペイン自動読込なし` を比較。

#### 観測

- ある時点の実機ログでは `delay_ms="150"` に対して `split_load_started` が約 1.8 秒後に実行されていた。
- しかし右ペイン本体は `19ms` で完了していた。
- `B` `C` `D` を切り替えても体感はほぼ同じだった。

#### 結論

- `右ペインの実データ読込` は主犯ではなかった。
- 重いのは「右ペイン開始前の何か」であり、データ量や自動 refresh の有無では説明できなかった。

### Phase 4. 標準寄せ split で直るか

#### 仮説

- 現行の `ScrollView + LazyVGrid + 手動選択` が `NavigationSplitView` の得意経路から外れているのではないか。

#### 実施

- `PerformanceProbeMode.E` を追加し、`NavigationSplitView + List(selection:)` の標準寄せ比較を実装。

#### 観測

- シミュレータでは `A` より `E` がわずかに遅い結果も出た。
- 実機では `split_load_started` までの待ちが `A` より明確に短くなった一方、体感差は決定的ではなかった。

#### 結論

- 標準寄せだけでの根治はできなかった。
- ただし `右ペイン開始までの待ち` の一部には効いており、split 構造の寄与は完全には白ではない。

### Phase 5. MainActor 詰まりの切り分け

#### 仮説

- `FeedCacheCoordinator` か周辺が `@MainActor` 上で重い処理をしているのではないか。

#### 実施

- `bootstrap`, `snapshot`, `presentation`, `split load`, `channel merge` の各境界に `main_thread` 付きログを追加。

#### 観測

- `FeedCacheCoordinator` は実際に `@MainActor` だった。
- しかし YouTube 検索画面遷移後の処理は極小だった。
  - `snapshot coordinator`: `1ms`
  - `presentation apply`: `0ms`
  - `channel merge`: `2ms`
  - `openChannelVideos`: `5ms`
- 一方 `bootstrap` は `main_thread="true"` で数秒級だった。

#### 結論

- `MainActor 化そのものが怪しい` という仮説は半分当たり。
- ただし主犯は G/H 遷移そのものではなく、起動時 bootstrap 側へ移った。

### Phase 6. 起動時 decode の分解

#### 仮説

- 起動前半の重さは通常キャッシュと検索キャッシュの JSON decode ではないか。

#### 実施

- `FeedCacheStore.loadSnapshot` を `directory -> file exists -> read -> decode` に分解。
- `RemoteVideoSearchCacheStore.status` を `service -> file exists -> read -> decode -> ttl` に分解。

#### 観測

- 実機の重い時点では:
  - `cache.json` `bytes="101733"` `decode_ms="3274"`
  - `remote-search.json` `bytes="72085"` `decode_ms="917"`
  - `read_ms` はどちらも 0 か 1ms
- 同一ファイルでも直後の再 decode は一桁 ms に落ちた。

#### 結論

- 主犯は `I/O` ではなく `初回 JSON decode`。
- しかも `main_thread="true"` なので、体感上の詰まりに直結していた。

## 仮説と検証

### 当たりだった仮説

#### 1. UI task と検索本体の寿命分離が必要

- 症状:
  - `Cancelled` タイル
  - `urlsession_cancelled`
- 検証:
  - managed task 化後、`refreshable` の caller が cancel されても検索完走。
- 結果:
  - 当たり。

#### 2. 起動時の主犯はキャッシュ decode

- 症状:
  - `bootstrap_complete` が数秒級
- 検証:
  - `feed_snapshot_store_complete decode_ms="3274"`
  - `search_cache_status_store_complete decode_ms="917"`
- 結果:
  - 当たり。

#### 3. ホームで必要なのは summary であり、本体 decode は不要

- 症状:
  - ホームの表示に本体 cache 全 decode を使っていた。
- 検証:
  - `cache-summary` / `remote-search-summary` を導入後、起動区間が大幅短縮。
- 結果:
  - 大当たり。

### 半分当たりだった仮説

#### 1. split UI の構造が悪い

- 症状:
  - iPad で検索画面展開が引っかかる。
- 検証:
  - `PerformanceProbeMode.E` で標準寄せ。
- 結果:
  - 完全な解決ではないが、`split_load_started` の待ち短縮には寄与した。

#### 2. MainActor が詰まっている

- 症状:
  - 遷移前に待たされる。
- 検証:
  - `main_thread="true"` ログ。
- 結果:
  - 当たり。ただし犯人は G/H 遷移後ではなく起動前半だった。

### 外れだった仮説

#### 1. 右ペインの実読込が重い

- 観測:
  - `openChannelVideos` は `5ms` 前後
  - `channel_videos_open_complete` は `6-25ms`
- 結果:
  - 外れ。

#### 2. YouTube 検索結果 100 件が左ペインで重すぎる

- 観測:
  - `visible_count=20` へ下げても体感差は決定的ではなかった。
- 結果:
  - 主要因ではない。

#### 3. Debug ビルド特有の重さ

- 観測:
  - Release にしても実機体感は大差なかった。
- 結果:
  - 主因ではない。

## 実装した対策

### 1. YouTube 検索本体の managed task 化

- 変更:
  - `refreshable` は trigger のみ。
  - coordinator が検索本体 task を所有。
- 効果:
  - cancellation に引きずられなくなった。

### 2. 起動・描画・split の観測基盤

- 変更:
  - `[YoutubeFeeder] app.lifecycle.*`
  - runtime diagnostics
  - probe mode `A/B/C/D/E`
- 効果:
  - 体感を区間 ms に落として比較できるようになった。

### 3. 通常キャッシュ/検索キャッシュ decode の分解ログ

- 変更:
  - `feed_snapshot_store_*`
  - `search_cache_status_*`
- 効果:
  - `read` と `decode` を分離し、decode が主犯だと特定できた。

### 4. summary sidecar 導入

- 変更:
  - `cache-summary.json`
  - `remote-search-*-summary.json`
  - ホームは summary 優先
- 効果:
  - ホーム表示前に本体 `cache.json` と `remote-search.json` を decode しなくて済むようになった。

### 5. compact persistence と互換 decode

- 変更:
  - [FeedCachePersistenceCoders.swift](/Users/ak/Documents/Codex/HelloWorld/YoutubeFeeder/Features/FeedCache/FeedCachePersistenceCoders.swift)
  - 本体 cache は `secondsSince1970` で再保存
  - 旧 ISO8601 形式は互換 decode
- 効果:
  - 今後の full decode コストも下げられる土台になった。

### 6. summary の binary property list 化

- 変更:
  - summary 正本を JSON から binary plist へ変更
  - 旧 JSON summary は fallback 読込
- 効果:
  - 実測で summary は `107 bytes`, `decode_ms=0-1`

## 実測値

### 重かった時期の代表値

- 起動側
  - `feed_snapshot_store_complete bytes="101733" decode_ms="3274" videos="122"`
  - `search_cache_status_store_complete bytes="72085" decode_ms="917" videos="94"`
  - `home_status_load_complete elapsed_ms="4311" snapshot_ms="3303" search_cache_ms="923"`
- iPad G/H 展開
  - `screen_appear -> split_load_completed` が体感上明確に引っかかった
  - ただし `channel_videos_open_complete elapsed_ms="6"` のように右ペイン本体は軽かった

### summary sidecar 導入後

- シミュレータ baseline
  - `app_launch_to_home_ms=690`
  - `app_launch_to_splash_ms=545`
  - `home_tap_to_split_loaded_ms=401`
- 実機途中段階
  - `search_cache_status_store_complete ... mode="summary" decode_ms="1489"`
  - summary 導入だけでは decode の残り火があった

### binary plist summary 化後

- シミュレータ
  - `search_cache_status_store_complete bytes="107" decode_ms="0" mode="summary"`
  - `app_launch_to_home_ms=752`
- 実機
  - `search_cache_status_store_complete bytes="107" decode_ms="1" read_ms="2" mode="summary"`
  - `home_status_load_complete elapsed_ms="22"`
  - `bootstrap_complete elapsed_ms="24"`

### 現在の残件に関わる値

- 実機の YouTube 検索画面展開
  - `screen_appear -> snapshot_hit`: 約 `94ms`
  - `screen_appear -> first_result_appear`: 約 `134ms`
  - `screen_appear -> split_load_completed`: 約 `274ms`
  - `channel_videos_open_complete elapsed_ms="23"`

## 現時点の結論

- 起動時の重大な体感悪化は、通常キャッシュと検索キャッシュの初回 decode に起因しており、この系統は概ね解消できた。
- YouTube 検索画面展開の大きな詰まりも改善したが、軽い引っかかりは残っている。
- 残件はデータ取得やキャッシュ decode ではなく、`NavigationSplitView` を含む SwiftUI の初回構築/描画が本命候補である。

## 残課題

- iPad の検索画面展開で残る軽い引っかかりの解消
- split 遷移のアニメーション/レイアウトの観測強化
- 必要なら、G 画面だけさらに単ペイン寄りへ寄せた比較

## 今後の叩き台

- まず `データ取得` と `UI 構築` をログで分ける。
- 秒級の `decode_ms` が出たら、`read` と `decode` を即分離する。
- ホームのような `件数/鮮度だけ欲しい` 導線では、詳細本体の decode をさせない。
- summary が重い時は、形式そのものを疑う。
- `debug/release` 差は早めに確認するが、数値で主因を見てから最適化へ入る。

## Appendix

### A. 主要コミット

- `ca40ad6` YouTube検索の調査ログを整備する
- `b418364` YouTube検索キャンセルの追跡ログを強化する
- `4c16bb4` YouTube検索の更新処理をmanaged taskへ移す
- `4194b50` iPad検索画面の初期split読込を遅延する
- `6db9e9d` iPad検索遷移の計測基盤を追加する
- `e4f3dd6` 起動区間の調査ログを追加する
- `364e98b` 性能測定モード切り替えを追加する
- `d513527` 標準寄せsplitの比較モードを追加する
- `920b731` MainActor調査ログを広げる
- `c837b8a` 起動と描画の分解ログを追加する
- `3f2e5ba` 検索キャッシュ状態の分解ログを追加する
- `3194581` 通常キャッシュ読込の分解ログを追加する
- `b3fc4bf` 起動時キャッシュ読込を軽量化する
- `d6e386b` サマリー読込を高速形式へ切り替える

### B. 代表的な外れ筋

- `右ペインを遅延すれば直る`
- `右ペイン自動読込を切れば直る`
- `左ペイン件数を 20 件へ落とせば直る`
- `Debug だから遅いだけ`
- `YouTube API 通信が遅い`

### C. 代表ログ断片

- 重い `cache.json`
  - `feed_snapshot_store_complete bytes="101733" decode_ms="3274" read_ms="1" videos="122"`
- 重い `remote-search.json`
  - `search_cache_status_store_complete bytes="72085" decode_ms="917" mode="full" videos="94"`
- summary binary 化後
  - `search_cache_status_store_complete bytes="107" decode_ms="1" mode="summary" videos="93"`
- 現在の展開残件
  - `screen_snapshot_load_complete elapsed_ms="10"`
  - `remote_search_first_result_appear`
  - `remote_search_split_load_completed elapsed_ms="23"`
