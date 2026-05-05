# SPECS_PRODUCT_RULES

## INDEX

- [PROD-PURPOSE] 目的
- [PROD-PLATFORM] 対象プラットフォーム
- [PROD-STARTUP] 起動
- [PROD-HOME] ホーム画面
- [PROD-REGISTER] チャンネル登録
- [PROD-BACKUP] バックアップ
- [PROD-RESET] 全設定リセット
- [PROD-CHANNEL-LIST] チャンネル一覧
- [PROD-CHANNEL-VIDEOS] チャンネル別動画一覧
- [PROD-VIDEO-LIST] 動画一覧
- [PROD-KEYWORD-SEARCH] 固定キーワード検索
- [PROD-REMOTE-SEARCH] YouTube検索
- [PROD-PLAYBACK] 動画再生
- [PROD-DELETE] チャンネル削除
- [PROD-CACHE] キャッシュ
- [PROD-REFRESH] 更新
- [PROD-UI] UI
- [PROD-NONFUNCTIONAL] 非機能
- [PROD-DOCS] 仕様運用

## RULES

### [PROD-PURPOSE]

- [PROD-PURPOSE-001][purpose] 登録済みYouTubeチャンネルのfeedを取得し、ローカルキャッシュとして保持しなければならない
- [PROD-PURPOSE-002][purpose][ui] ホーム画面、チャンネル一覧、動画一覧から最新動画を確認できなければならない
- [PROD-PURPOSE-003][performance] 起動直後に最低限の画面を速く表示しなければならない
- [PROD-PURPOSE-004][separation] feed取得とUI表示を分離しなければならない
- [PROD-PURPOSE-005][cache] 取得済みデータを再利用し、毎回フル取得してはならない

### [PROD-PLATFORM]

- [PROD-PLATFORM-001][platform] iOSアプリでなければならない
- [PROD-PLATFORM-002][platform][iphone] iPhoneを主設計対象としなければならない
- [PROD-PLATFORM-003][platform][ipad] iPadでも同一機能を提供しなければならない
- [PROD-PLATFORM-004][platform][mac] Macでは標準クリック操作とメニュー操作で同一機能へ到達できなければならない
- [PROD-PLATFORM-005][ui] GUIは共有振る舞いと端末差分を区別しなければならない

### [PROD-STARTUP]

- [PROD-STARTUP-001][startup] アプリ起動時は最初にLaunchScreenViewを表示しなければならない
- [PROD-STARTUP-002][startup][performance] 起動直後は重い処理を行ってはならない
- [PROD-STARTUP-003][startup][cache] 起動直後は軽量キャッシュのみを読み込まなければならない
- [PROD-STARTUP-004][startup] 軽量キャッシュ読込完了後にホーム画面へ遷移しなければならない
- [PROD-STARTUP-005][startup][forbidden] 起動時に本体キャッシュ全読込を自動開始してはならない
- [PROD-STARTUP-006][startup][forbidden] 起動時にfeed更新を自動開始してはならない
- [PROD-STARTUP-007][diagnostics] 起動時の診断タイムラインを取得できなければならない

### [PROD-HOME]

- [PROD-HOME-001][home][navigation] ホーム画面はチャンネル導線を提供しなければならない
- [PROD-HOME-002][home][navigation] ホーム画面は動画導線を提供しなければならない
- [PROD-HOME-003][home][navigation] ホーム画面はキャッシュ検索導線を提供しなければならない
- [PROD-HOME-004][home][navigation] ホーム画面はYouTube検索導線を提供しなければならない
- [PROD-HOME-005][home][navigation] ホーム画面はチャンネル登録導線を提供しなければならない
- [PROD-HOME-006][home][backup] ホーム画面はバックアップ導線を提供しなければならない
- [PROD-HOME-007][home][reset] ホーム画面は全設定リセット導線を提供しなければならない
- [PROD-HOME-008][home][status] ホーム画面はシステム状況タイルを表示しなければならない
- [PROD-HOME-009][home][refresh] ホーム画面はpull-to-refreshによる手動更新を提供しなければならない
- [PROD-HOME-010][home][refresh] 手動更新はrefreshFeed相当のドメインアクションとして共有しなければならない
- [PROD-HOME-011][home][mac] MacではRefreshコマンドを手動更新のUIアダプタとして割り当てなければならない
- [PROD-HOME-012][home][status] システム状況は非操作タイルとして表示しなければならない

### [PROD-REGISTER]

- [PROD-REGISTER-001][register] ホーム画面からチャンネル登録を開けなければならない
- [PROD-REGISTER-002][register][input] 入力はChannel ID、@handle、チャンネルURL、動画URLを受け付けなければならない
- [PROD-REGISTER-003][register][video_url] 動画URL入力時は投稿元チャンネルを登録しなければならない
- [PROD-REGISTER-004][register][resolve] @handleやURLは登録前にChannel IDへ解決しなければならない
- [PROD-REGISTER-005][register][identity] 永続化主キーは解決後のChannel IDでなければならない
- [PROD-REGISTER-006][register][dedupe] 既存Channel IDは重複登録してはならない
- [PROD-REGISTER-007][register] 追加チャンネルはチャンネル一覧と更新対象に含まれなければならない
- [PROD-REGISTER-008][register][feedback] 登録結果は新規登録か既登録かを明示しなければならない
- [PROD-REGISTER-009][register][feedback] 解決後のチャンネル名、Channel ID、最新動画、公開日、保持動画件数を可能な範囲で返さなければならない
- [PROD-REGISTER-010][register][error] 最新動画取得失敗時も登録成否と失敗理由を区別しなければならない

### [PROD-BACKUP]

- [PROD-BACKUP-001][backup] ホーム画面からチャンネル設定を固定ファイルへ書き出せなければならない
- [PROD-BACKUP-002][backup] ホーム画面から固定ファイルを読み込んでチャンネル設定を復元できなければならない
- [PROD-BACKUP-003][backup][scope] バックアップは1デバイス内の復元を目的としなければならない
- [PROD-BACKUP-004][backup][format] バックアップ形式はJSONでなければならない
- [PROD-BACKUP-005][backup][scope] 書き出し対象はチャンネル設定に限らなければならない
- [PROD-BACKUP-006][backup][forbidden] サムネイルや動画キャッシュ本体をバックアップに含めてはならない
- [PROD-BACKUP-007][backup] 現在登録されている全チャンネル情報を保存対象としなければならない
- [PROD-BACKUP-008][backup][performance] 読み込みでホーム画面の処理中表示を長時間引き延ばしてはならない
- [PROD-BACKUP-009][backup][refresh] 読み込み後は最新動画情報の再取得をバックグラウンドで開始しなければならない
- [PROD-BACKUP-010][backup][path] 固定ファイルパスはDocuments/YoutubeFeeder/channel-registry.json相当でなければならない
- [PROD-BACKUP-011][backup][error] バックアップファイル不在時は失敗理由を明確に返さなければならない

### [PROD-RESET]

- [PROD-RESET-001][reset] ホーム画面から端末内設定とキャッシュをまとめて削除できなければならない
- [PROD-RESET-002][reset][scope] 削除対象はchannel registry、動画キャッシュ、bootstrap、検索履歴、サムネイルでなければならない
- [PROD-RESET-003][reset][forbidden] Documents/YoutubeFeeder/channel-registry.jsonのバックアップファイルを削除してはならない
- [PROD-RESET-004][reset][ui] 実行前に確認UIを表示しなければならない
- [PROD-RESET-005][reset][feedback] 実行後は削除件数を画面上で返さなければならない
- [PROD-RESET-006][reset][recovery] リセット後でもバックアップ読込で復旧できなければならない

### [PROD-CHANNEL-LIST]

- [PROD-CHANNEL-LIST-001][channel_list][navigation] チャンネルタイルからチャンネル一覧へ遷移しなければならない
- [PROD-CHANNEL-LIST-002][channel_list][sort] ホームのチャンネル導線では指標と昇順/降順を選べなければならない
- [PROD-CHANNEL-LIST-003][channel_list][sort] 初期選択は動画投稿日時の降順でなければならない
- [PROD-CHANNEL-LIST-004][channel_list][sort] 指標は動画投稿日時とチャンネル登録日時を提供しなければならない
- [PROD-CHANNEL-LIST-005][channel_list][sort] キャッシュ済みチャンネルは選択した並び順で表示しなければならない
- [PROD-CHANNEL-LIST-006][channel_list][tips] 一覧先頭にTipsタイルを表示しなければならない
- [PROD-CHANNEL-LIST-007][channel_list][navigation] チャンネル選択でチャンネル動画一覧へ進めなければならない
- [PROD-CHANNEL-LIST-008][playlist] 選択チャンネルのプレイリスト一覧へ切り替えられなければならない
- [PROD-CHANNEL-LIST-009][playlist] プレイリスト一覧は選択チャンネルのプレイリストを表示しなければならない
- [PROD-CHANNEL-LIST-010][playlist][thumbnail] プレイリストカード画像は先頭動画サムネイルを使用しなければならない
- [PROD-CHANNEL-LIST-011][playlist][sort] プレイリスト一覧の動画は初期表示で投稿日時の新しい順に並べなければならない
- [PROD-CHANNEL-LIST-012][playlist] プレイリストタイル通常タップ/クリックでプレイリスト内動画一覧を表示しなければならない
- [PROD-CHANNEL-LIST-013][playlist][sort] プレイリスト内動画一覧では投稿日時の新旧順を切り替えられなければならない
- [PROD-CHANNEL-LIST-014][playlist][menu] プレイリストタイルのメニュー起動はopenTileMenu相当の共通アクションでなければならない
- [PROD-CHANNEL-LIST-015][playlist][menu] iPhone/iPadでは長押し、Macでは右クリックで同じプレイリストメニューへ到達しなければならない
- [PROD-CHANNEL-LIST-016][playlist][playback] プレイリストメニューは連続再生導線を表示しなければならない
- [PROD-CHANNEL-LIST-017][playlist][forbidden] プレイリスト閲覧と連続再生は検索機能に依存してはならない
- [PROD-CHANNEL-LIST-018][adaptive] 分割レイアウトではチャンネル一覧と選択チャンネル動画一覧を同時表示してよい
- [PROD-CHANNEL-LIST-019][adaptive] 分割レイアウトでは選択中チャンネル更新時に右ペインも最新キャッシュへ追随しなければならない
- [PROD-CHANNEL-LIST-020][adaptive] 分割レイアウトでは初回選択チャンネルの動画一覧を自動読込しなければならない
- [PROD-CHANNEL-LIST-021][menu] チャンネルタイルメニュー起動はopenTileMenu相当の共通アクションでなければならない
- [PROD-CHANNEL-LIST-022][menu] iPhone/iPadでは長押し、Macでは右クリックで同じチャンネルメニューへ到達しなければならない
- [PROD-CHANNEL-LIST-023][mac] Macのチャンネル一覧では左クリックで詳細表示へ進まなければならない

### [PROD-CHANNEL-VIDEOS]

- [PROD-CHANNEL-VIDEOS-001][channel_videos] 選択チャンネルのキャッシュ済み動画を新しい順に最大50件表示しなければならない
- [PROD-CHANNEL-VIDEOS-002][shorts][forbidden] Shortsを表示してはならない
- [PROD-CHANNEL-VIDEOS-003][shorts] 4分未満の動画はShortsとして除外しなければならない
- [PROD-CHANNEL-VIDEOS-004][layout] 単独画面では独立画面として表示しなければならない
- [PROD-CHANNEL-VIDEOS-005][layout] 分割レイアウトでは内容表示領域として表示しなければならない
- [PROD-CHANNEL-VIDEOS-006][refresh] pull-to-refresh時は選択中1チャンネルだけを強制更新しなければならない
- [PROD-CHANNEL-VIDEOS-007][refresh] 更新アクションはrefreshFeed相当のドメインアクションを共有しなければならない
- [PROD-CHANNEL-VIDEOS-008][refresh] プラットフォーム差分はUI層だけで吸収しなければならない
- [PROD-CHANNEL-VIDEOS-009][remote_search] YouTube検索結果から遷移した場合、必要なら当該チャンネルのfeedを自動強制更新しなければならない
- [PROD-CHANNEL-VIDEOS-010][loading] 自動feed更新中は読み込み中UIを表示しなければならない
- [PROD-CHANNEL-VIDEOS-011][remote_search] 検索由来チャンネル名をfeed更新完了前に初期タイトルへ反映しなければならない
- [PROD-CHANNEL-VIDEOS-012][merge] feed更新のたびに置換せず既存キャッシュへappend/mergeしなければならない
- [PROD-CHANNEL-VIDEOS-013][tile] 動画タイルには画面内通し番号を1から表示しなければならない
- [PROD-CHANNEL-VIDEOS-014][tile] 右上番号バッジはチャンネル一覧画面と同じ書式でなければならない
- [PROD-CHANNEL-VIDEOS-015][tile] 右下は丸めた分数+再生数でなければならない
- [PROD-CHANNEL-VIDEOS-016][tile][forbidden] 再生時間区分の(M)/(L)を表示してはならない
- [PROD-CHANNEL-VIDEOS-017][menu] この画面でだけ動画タイルメニューからYouTubeで開くを選べなければならない
- [PROD-CHANNEL-VIDEOS-018][share] 動画タイルメニューから共有を選ぶと動画URLを共有シートへ渡せなければならない
- [PROD-CHANNEL-VIDEOS-019][diagnostics] pull-to-refreshから一覧反映までの経路を時系列ログとして出力できなければならない
- [PROD-CHANNEL-VIDEOS-020][diagnostics] 分割レイアウトでは右ペイン再読込を時系列ログで観測できなければならない

### [PROD-VIDEO-LIST]

- [PROD-VIDEO-LIST-001][video_list] キャッシュ済み動画を新しい順に最大50件表示しなければならない
- [PROD-VIDEO-LIST-002][shorts][forbidden] Shortsを表示してはならない
- [PROD-VIDEO-LIST-003][shorts] 4分未満の動画はShortsとして除外しなければならない
- [PROD-VIDEO-LIST-004][ui] 見た目は大きいヒーロータイルでなければならない
- [PROD-VIDEO-LIST-005][scroll] 縦スクロール可能でなければならない
- [PROD-VIDEO-LIST-006][performance] 表示中のlive反映でスクロールや操作感を阻害してはならない
- [PROD-VIDEO-LIST-007][tap] 動画タイル通常タップで動画を開かなければならない
- [PROD-VIDEO-LIST-008][menu] 動画タイルメニューで共有とチャンネル削除を選べなければならない
- [PROD-VIDEO-LIST-009][tile] 動画タイルには画面内通し番号を1から表示しなければならない
- [PROD-VIDEO-LIST-010][tile] 右上番号バッジはチャンネル一覧画面と同じ書式でなければならない
- [PROD-VIDEO-LIST-011][tile] 右下は丸めた分数+再生数でなければならない
- [PROD-VIDEO-LIST-012][tile][forbidden] 再生時間区分の(M)/(L)を表示してはならない

### [PROD-KEYWORD-SEARCH]

- [PROD-KEYWORD-SEARCH-001][keyword_search] ホーム画面のキャッシュ検索タイルから遷移しなければならない
- [PROD-KEYWORD-SEARCH-002][keyword_search] キーワードは固定で「ゆっくり実況」でなければならない
- [PROD-KEYWORD-SEARCH-003][keyword_search] 現在キャッシュから一致動画を新しい順に最大20件表示しなければならない
- [PROD-KEYWORD-SEARCH-004][shorts][forbidden] Shortsを表示してはならない
- [PROD-KEYWORD-SEARCH-005][shorts] 4分未満の動画はShortsとして除外しなければならない
- [PROD-KEYWORD-SEARCH-006][chip] 検索結果件数を示す一時チップを画面下部に表示しなければならない
- [PROD-KEYWORD-SEARCH-007][chip][forbidden] チップを自動タイマーで消してはならない
- [PROD-KEYWORD-SEARCH-008][chip] チップはユーザー操作開始まで維持しなければならない
- [PROD-KEYWORD-SEARCH-009][navigation] 動画タイル通常タップでチャンネル別動画一覧へ遷移しなければならない
- [PROD-KEYWORD-SEARCH-010][share] 動画タイルメニューで共有を選べなければならない
- [PROD-KEYWORD-SEARCH-011][tile] 動画タイルには画面内通し番号を1から表示しなければならない
- [PROD-KEYWORD-SEARCH-012][tile] 右上番号バッジはチャンネル一覧画面と同じ書式でなければならない
- [PROD-KEYWORD-SEARCH-013][tile] 右下は丸めた分数+再生数でなければならない
- [PROD-KEYWORD-SEARCH-014][tile][forbidden] 再生時間区分の(M)/(L)を表示してはならない

### [PROD-REMOTE-SEARCH]

- [PROD-REMOTE-SEARCH-001][remote_search] ホーム画面のYouTube検索タイルから遷移しなければならない
- [PROD-REMOTE-SEARCH-002][remote_search] キーワードは固定で「ゆっくり実況」でなければならない
- [PROD-REMOTE-SEARCH-003][remote_search][forbidden] 画面表示時に自動検索してはならない
- [PROD-REMOTE-SEARCH-004][remote_search] pull-to-refresh時だけYouTube検索APIを実行しなければならない
- [PROD-REMOTE-SEARCH-005][refresh] 再取得アクションはrefreshFeed相当のドメインアクションを共有しなければならない
- [PROD-REMOTE-SEARCH-006][mac] MacではRefreshコマンドから同じ再取得へ到達できなければならない
- [PROD-REMOTE-SEARCH-007][cache] 画面表示時は前回検索キャッシュがあればそれだけを表示しなければならない
- [PROD-REMOTE-SEARCH-008][empty] キャッシュがなければ未取得状態を表示しなければならない
- [PROD-REMOTE-SEARCH-009][result] API結果から新しい順に最大100件表示しなければならない
- [PROD-REMOTE-SEARCH-010][api] 1回の検索ではvideoDuration=mediumとlongの2検索を行わなければならない
- [PROD-REMOTE-SEARCH-011][api] 2検索の結果を統合しなければならない
- [PROD-REMOTE-SEARCH-012][shorts] チャンネル動画取得や履歴マージでも4分未満動画を混ぜてはならない
- [PROD-REMOTE-SEARCH-013][api] 2検索の結果はvideos.listで補完しなければならない
- [PROD-REMOTE-SEARCH-014][api] ライブ動画を除外して1回分の検索結果として保存しなければならない
- [PROD-REMOTE-SEARCH-015][api] videos.listは動画IDを50件単位で問い合わせなければならない
- [PROD-REMOTE-SEARCH-016][api][forbidden] 50件ヒット時に50回コールしてはならない
- [PROD-REMOTE-SEARCH-017][api] videos.list詳細取得ではstatisticsを含めなければならない
- [PROD-REMOTE-SEARCH-018][cache] 検索結果は端末内キャッシュへ保存しなければならない
- [PROD-REMOTE-SEARCH-019][cache][forbidden] 短時間の再訪で毎回API再取得してはならない
- [PROD-REMOTE-SEARCH-020][refresh] 明示的な再取得はpull-to-refresh時のみ許可しなければならない
- [PROD-REMOTE-SEARCH-021][error] APIキー未設定や検索失敗時は理由を画面上へ返さなければならない
- [PROD-REMOTE-SEARCH-022][error][forbidden] 失敗時に空画面のままにしてはならない
- [PROD-REMOTE-SEARCH-023][history] 検索履歴はキーワードごとに過去結果へ順次マージしなければならない
- [PROD-REMOTE-SEARCH-024][history] 検索履歴は任意タイミングでクリアできなければならない
- [PROD-REMOTE-SEARCH-025][chip] 最終更新時刻、結果件数、検索元を示すチップを表示しなければならない
- [PROD-REMOTE-SEARCH-026][loading] 再検索中は上部に進行中表示を出さなければならない
- [PROD-REMOTE-SEARCH-027][loading][forbidden] 再検索中に古い下部チップ要約を見せてはならない
- [PROD-REMOTE-SEARCH-028][chip][forbidden] チップを自動タイマーで消してはならない
- [PROD-REMOTE-SEARCH-029][chip] チップはユーザー操作開始まで維持しなければならない
- [PROD-REMOTE-SEARCH-030][paging] 検索結果は初回20件を表示し、下端到達で追加読込しなければならない
- [PROD-REMOTE-SEARCH-031][layout] 単独画面では動画タイル通常タップでチャンネル別動画一覧へ遷移しなければならない
- [PROD-REMOTE-SEARCH-032][layout] 分割レイアウトでは検索結果一覧と選択チャンネル動画一覧を同時表示しなければならない
- [PROD-REMOTE-SEARCH-033][layout] 分割レイアウトでは動画タップで内容表示側だけを更新しなければならない
- [PROD-REMOTE-SEARCH-034][paging] 分割内容表示側は初回20件を表示し、末尾到達で20件ずつ追加しなければならない
- [PROD-REMOTE-SEARCH-035][share] 検索結果一覧と分割内容表示側の両方で動画タイル共有を選べなければならない
- [PROD-REMOTE-SEARCH-036][navigation] 検索結果からチャンネル別動画一覧へ遷移する場合、検索結果のチャンネル名を初期表示へ引き継がなければならない
- [PROD-REMOTE-SEARCH-037][tile] 動画タイルには画面内通し番号を1から表示しなければならない
- [PROD-REMOTE-SEARCH-038][tile] 右上番号バッジはチャンネル一覧画面と同じ書式でなければならない
- [PROD-REMOTE-SEARCH-039][tile] 右下は丸めた分数+再生数でなければならない
- [PROD-REMOTE-SEARCH-040][tile][forbidden] 再生時間区分(M)/(L)を表示してはならない
- [PROD-REMOTE-SEARCH-041][layout][forbidden] 広い画面でも動画タイルを複数列表示してはならない
- [PROD-REMOTE-SEARCH-042][layout] 広い画面では本文幅だけを読みやすい範囲へ制限しなければならない

### [PROD-PLAYBACK]

- [PROD-PLAYBACK-001][playback][forbidden] 動画タイル通常タップで動画を開いてはならない
- [PROD-PLAYBACK-002][playback][mac] Macではチャンネル別動画一覧の動画タイル左クリックでYouTubeで開くを実行しなければならない
- [PROD-PLAYBACK-003][playback][mac] Macでは右クリックで動画タイルメニューを開けなければならない
- [PROD-PLAYBACK-004][playback][mac][forbidden] Macのチャンネル別動画一覧メニューにYouTubeで開くを含めてはならない
- [PROD-PLAYBACK-005][playback] YouTubeで開くはチャンネル別動画一覧の動画タイル左クリックでのみ実行できなければならない
- [PROD-PLAYBACK-006][playback] 可能ならyoutube://watch?v=<videoID>を開かなければならない
- [PROD-PLAYBACK-007][playback] YouTubeアプリが開けない場合はWeb URLにフォールバックしなければならない

### [PROD-DELETE]

- [PROD-DELETE-001][delete] チャンネル削除はチャンネルタイルまたは動画タイルメニューから行えなければならない
- [PROD-DELETE-002][delete][ui] 削除時は確認ダイアログを表示しなければならない
- [PROD-DELETE-003][delete][maintenance] 削除後は該当チャンネルの動画キャッシュと不要サムネイルを整理しなければならない
- [PROD-DELETE-004][maintenance] 整合性メンテナンスはチャンネル削除時には即時に動かなければならない
- [PROD-DELETE-005][maintenance] 通常更新フローでは軽い定期処理として自然に動かなければならない
- [PROD-DELETE-006][maintenance][forbidden] 参照切れのチャンネル状態、動画、サムネイルを残してはならない

### [PROD-CACHE]

- [PROD-CACHE-001][cache][channel] チャンネルキャッシュはチャンネルID、チャンネル名、最終取得時刻、最終確認時刻、最新動画投稿日、動画件数、エラー状態、ETag、Last-Modifiedを保持しなければならない
- [PROD-CACHE-002][cache][video] 動画キャッシュはID、タイトル、チャンネル名、投稿日、動画URL、サムネイルURL、ローカルサムネイル名、検索用文字列を保持しなければならない
- [PROD-CACHE-003][cache][video] 動画キャッシュは再生時間秒数と再生数を保持しなければならない
- [PROD-CACHE-004][cache][search] 固定キーワード「ゆっくり実況」のYouTube検索結果キャッシュを保持しなければならない
- [PROD-CACHE-005][cache][persistence] キャッシュはアプリ終了後も再利用可能でなければならない
- [PROD-CACHE-006][cache] bootstrapと本体キャッシュは別ファイルに保存しなければならない
- [PROD-CACHE-007][cache] チャンネル一覧はアプリ終了後も再利用可能でなければならない
- [PROD-CACHE-008][thumbnail] サムネイルはローカルファイルとして保存しなければならない
- [PROD-CACHE-009][startup] アプリ再起動時はbootstrapを優先して使わなければならない
- [PROD-CACHE-010][remote_search] YouTube検索結果キャッシュは本体キャッシュとは別ファイルで保持しなければならない

### [PROD-REFRESH]

- [PROD-REFRESH-001][diagnostics] 実機調査時は通常操作しながらランタイムログをリアルタイム取得できなければならない
- [PROD-REFRESH-002][diagnostics] ランタイムログは更新ジェスチャー、単独チャンネル更新、feed取得結果、整合性メンテナンス結果、UI反映または保留を含まなければならない
- [PROD-REFRESH-003][diagnostics] ランタイムログは物理iPhone 12 miniのコンソール接続から取得できなければならない
- [PROD-REFRESH-004][channel_refresh] ChannelRefresh更新処理は単発で開始し完了後に必ず終了しなければならない
- [PROD-REFRESH-005][channel_refresh][forbidden] ChannelRefreshは内部ループ、sleep自己継続、自己再起動を持ってはならない
- [PROD-REFRESH-006][channel_refresh] 更新種別は全チャンネルリフレッシュと短周期リフレッシュの2種類だけでなければならない
- [PROD-REFRESH-007][channel_refresh] 全チャンネルリフレッシュは全登録チャンネルを対象にしなければならない
- [PROD-REFRESH-008][channel_refresh] 短周期リフレッシュは直近10日以内に更新されたチャンネルを対象にしなければならない
- [PROD-REFRESH-009][channel_refresh][startup] 起動時のホーム成立後自動更新は全チャンネルリフレッシュを1回だけ起動しなければならない
- [PROD-REFRESH-010][channel_refresh][manual] ホームpull-to-refreshとMac Refreshは全チャンネルリフレッシュを起動しなければならない
- [PROD-REFRESH-011][channel_refresh][schedule] 毎時00分は全チャンネルリフレッシュを起動しなければならない
- [PROD-REFRESH-012][channel_refresh][schedule] 毎時10/20/30/40/50分は短周期リフレッシュを起動しなければならない
- [PROD-REFRESH-013][channel_refresh][schedule] 毎時00分は全チャンネルリフレッシュを優先し、短周期リフレッシュを同時起動してはならない
- [PROD-REFRESH-014][channel_refresh][concurrency] ChannelRefresh実行中に発火したトリガーは待機せずドロップしなければならない
- [PROD-REFRESH-015][channel_refresh][forbidden] ドロップしたトリガーを完了後に再実行してはならない
- [PROD-REFRESH-016][manual_refresh] 手動更新はチャンネル一覧を優先順に並べなければならない
- [PROD-REFRESH-017][manual_refresh][concurrency] 手動更新は最大3チャンネルまで同時処理しなければならない
- [PROD-REFRESH-018][manual_refresh] 各チャンネルは更新確認、必要時本体取得、新着サムネイル取得の順に処理しなければならない
- [PROD-REFRESH-019][manual_refresh][concurrency] 同時ネットワークリクエスト数は最大3を超えてはならない
- [PROD-REFRESH-020][ordering] チャンネル処理順は更新日時降順でなければならない
- [PROD-REFRESH-021][ordering] latestPublishedAt、lastSuccessAt、lastCheckedAtの順で優先判定しなければならない
- [PROD-REFRESH-022][conditional_get] 更新確認ではETagとLast-Modifiedを使用しなければならない
- [PROD-REFRESH-023][conditional_get] 304 Not Modified時は本体取得してはならない
- [PROD-REFRESH-024][conditional_get] 条件付き取得が効かない場合でも通常取得へフォールバックしなければならない
- [PROD-REFRESH-025][thumbnail] サムネイル取得対象はその回の本体取得で新しく見つかった動画だけでなければならない
- [PROD-REFRESH-026][thumbnail][forbidden] 既存動画のサムネイルを再取得してはならない
- [PROD-REFRESH-027][thumbnail][forbidden] ローカル保存済みサムネイルを再ダウンロードしてはならない
- [PROD-REFRESH-028][live_update][forbidden] 一覧画面表示中は@Publishedによるlive updateを止めなければならない
- [PROD-REFRESH-029][live_update][forbidden] バックグラウンド更新で一覧をその場再描画してはならない
- [PROD-REFRESH-030][live_update] 一覧画面から戻った時点で最新状態を再読込しなければならない

### [PROD-UI]

- [PROD-UI-001][ui] GUI仕様は共有振る舞いとAdaptive UI差分を区別しなければならない
- [PROD-UI-002][ui] 機能ロジックは共有しなければならない
- [PROD-UI-003][ui] 差分は原則レイアウトと遷移表現に限定しなければならない
- [PROD-UI-004][ui] UIはドメインアクションを呼び出すアダプタでなければならない
- [PROD-UI-005][ui] プラットフォーム差分をアクション層へ持ち込んではならない
- [PROD-UI-006][ui] 背景はsystemGroupedBackgroundでなければならない
- [PROD-UI-007][ui] 一覧タイルは大きいヒーロータイルを維持しなければならない
- [PROD-UI-008][thumbnail] サムネイル未取得時もレイアウトを崩してはならない
- [PROD-UI-009][layout] 動画一覧画面は全端末で単独画面でなければならない
- [PROD-UI-010][single_layout] 一覧画面は1画面1主題でなければならない
- [PROD-UI-011][split_layout] ホームからチャンネルを開いた時は必要に応じて左右分割チャンネル閲覧UIを使わなければならない
- [PROD-UI-012][split_layout] ホームからYouTube検索を開いた時は必要に応じて左右分割UIを使わなければならない
- [PROD-UI-013][split_layout] チャンネル分割の左は一覧、右は選択中チャンネル動画一覧でなければならない
- [PROD-UI-014][split_layout] YouTube検索分割の左は検索結果一覧、右は選択中チャンネル動画一覧でなければならない
- [PROD-UI-015][split_layout] 初期表示時は左側先頭チャンネルを選択状態にしなければならない
- [PROD-UI-016][split_layout] 左側選択変更時は右側動画一覧だけを更新しなければならない
- [PROD-UI-017][split_layout][forbidden] 動画画面を分割レイアウトにしてはならない
- [PROD-UI-018][launch] 起動画面はYoutubeFeederの文字を表示しなければならない
- [PROD-UI-019][launch] 起動画面は極力軽くなければならない
- [PROD-UI-020][home] ホーム画面先頭にホームを表示しなければならない
- [PROD-UI-021][home] チャンネルタイルに現在の並び順を表示しなければならない
- [PROD-UI-022][home] バックアップ結果や失敗理由はホーム画面のフィードバックカードとして表示しなければならない
- [PROD-UI-023][channel_list] チャンネル一覧タイトルは「チャンネル一覧」でなければならない
- [PROD-UI-024][channel_list] サブタイトルは選択中並び順に追従しなければならない
- [PROD-UI-025][channel_list] Tipsタイルは登録件数、並び順、基本操作ヒントを表示しなければならない
- [PROD-UI-026][channel_videos] チャンネル別動画一覧タイトルはチャンネル名でなければならない
- [PROD-UI-027][channel_videos] サブタイトルは「このチャンネルの動画を新しい順に表示」でなければならない
- [PROD-UI-028][video_list] 動画一覧タイトルは「動画一覧」でなければならない
- [PROD-UI-029][video_list] サブタイトルは「キャッシュ済み動画を新しい順に表示」でなければならない
- [PROD-UI-030][back_swipe] 一覧画面は左端からの右スワイプで戻れなければならない
- [PROD-UI-031][back_swipe] 戻る判定はBackSwipePolicyに従わなければならない
- [PROD-UI-032][scroll] 戻る操作は縦スクロールを極力阻害してはならない

### [PROD-NONFUNCTIONAL]

- [PROD-NONFUNCTIONAL-001][performance] 起動直後は軽量キャッシュのみを読み、ホーム到達を優先しなければならない
- [PROD-NONFUNCTIONAL-002][performance][forbidden] 起動直後にネットワーク更新を自動実行してはならない
- [PROD-NONFUNCTIONAL-003][usability] 一覧スクロール中に更新反映で固まりにくくしなければならない
- [PROD-NONFUNCTIONAL-004][usability] 動画を誤タップで開きにくくしなければならない
- [PROD-NONFUNCTIONAL-005][usability] 戻るスワイプと縦スクロールの衝突を最小化しなければならない
- [PROD-NONFUNCTIONAL-006][persistence] キャッシュはアプリ終了後も残らなければならない
- [PROD-NONFUNCTIONAL-007][persistence] サムネイルは再利用できなければならない
- [PROD-NONFUNCTIONAL-008][extensibility] 将来の検索、並び替え、フィルタ追加を前提にデータ構造を設計しなければならない
- [PROD-NONFUNCTIONAL-009][testability] ネットワークを使わないUIテストができなければならない
- [PROD-NONFUNCTIONAL-010][testability] モック起動時にfixtureをseedできなければならない
- [PROD-NONFUNCTIONAL-011][observability] 起動や更新の観測点をaccessibility identifierまたはdiagnostics timelineで読めなければならない

### [PROD-DOCS]

- [PROD-DOCS-001][docs] この文書にはユーザーから見える振る舞い、キャッシュ更新、画面要件、非機能要件を記載しなければならない
- [PROD-DOCS-002][docs] 実装責務や開発ルール全体の入口はAGENTS.mdに置かなければならない
- [PROD-DOCS-003][docs] 仕様変更時は仕様文書とrulesコレクションを確認しなければならない
- [PROD-DOCS-004][docs][forbidden] 振る舞いと開発ルールの間に矛盾を残してはならない