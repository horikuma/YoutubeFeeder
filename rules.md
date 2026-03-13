# HelloWorld Rules

この文書は、このプロジェクトを継続開発するための正本です。人が読んでも LLM が読んでも判断に迷わないよう、設計方針、責務分担、テスト方針、運用上の前提を 1 か所にまとめています。`ARCHITECTURE.md` の内容もこの文書に統合しています。今後の開発では、構成や運用を変えたらまずこの文書を更新してください。

## 目的

- YouTube チャンネル群の feed を取得し、キャッシュを維持し、ホーム画面と一覧画面から閲覧できる iOS アプリを開発する。
- 体感速度を重視し、起動直後は軽量キャッシュだけでホーム画面へ入る。
- ネットワーク取得と UI 表示を分離し、画面操作中の負荷を抑える。
- 将来の並び替え、検索、フィルタ追加に耐えられるよう、UI とロジック、ロジックと永続化を分離する。

## 現在のプロダクト方針

- メンテナンス画面という呼称は使わず、`ホーム画面` と呼ぶ。
- 起動直後は `LaunchScreenView` を最速で表示し、その裏で前回終了時の軽量キャッシュを読み込んでホーム画面へ遷移する。
- ホーム画面はキャッシュ進捗の確認と導線の役割を持つ。
- 一覧系画面は次の 3 つに限定する。
  - チャンネル一覧
  - 全動画一覧
  - チャンネル別動画一覧
- 動画を開く操作は通常タップではなく `1秒長押し` とする。
- 動画表示は長尺動画を前提とし、Shorts は除外する。

## アーキテクチャ方針

- `App` はアプリ入口、ルート遷移、共通レイアウト、共通表示設定だけを持つ。
- `Features` はユーザー機能単位で画面とユースケースを持つ。
- `Infrastructure` は外部サービスとの通信やフォーマット変換を持つ。
- `Shared` は pure logic を置く。UI からもストアからも再利用できるものだけを置く。
- `Resources` は静的リソースとテスト fixture を置く。
- キャッシュ層は UI から直接ファイルアクセスさせず、必ず coordinator と store を経由する。
- UI は表示責務に集中し、並び順、スワイプ判定、鮮度判定のようなルールを埋め込まない。
- テストしやすさを優先し、観測可能な state は `@Published` または UI テスト用 marker として外から見える形にする。

## ディレクトリ責務

### App

- [HelloWorld/App/HelloWorldApp.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/App/HelloWorldApp.swift)
  - アプリ起動入口。
- [HelloWorld/App/ContentView.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/App/ContentView.swift)
  - ルート画面。
  - `LaunchScreenView` からホーム画面へ遷移する。
  - `NavigationStack` と `MaintenanceRoute` を束ねる。
- [HelloWorld/App/AppLayout.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/App/AppLayout.swift)
  - `iPhone` と `iPad` のレイアウト差分を吸収する。
- [HelloWorld/App/AppFormatting.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/App/AppFormatting.swift)
  - 日付などの共通 formatter。
- [HelloWorld/App/Support/AppTestSupport.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/App/Support/AppTestSupport.swift)
  - UI テスト用 launch mode、診断タイムライン、fixture seed、test marker。

### Features

- [HelloWorld/Features/Home/HomeScreenView.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面本体。
  - 進捗表示、手動更新、一覧画面への導線。
- [HelloWorld/Features/Home/HomeUIComponents.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/Home/HomeUIComponents.swift)
  - ホーム画面の表示部品。
- [HelloWorld/Features/Home/HomeRoutes.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/Home/HomeRoutes.swift)
  - 一覧系画面への遷移定義。
- [HelloWorld/Features/Browse/BrowseViews.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/Browse/BrowseViews.swift)
  - チャンネル一覧、全動画一覧、チャンネル別動画一覧。
  - 一覧系共通コンテナ `InteractiveListScreen`。
  - 動画タイル、チャンネルタイル、戻るスワイプ適用。
- [HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - UI と永続化の仲介。
  - ホーム画面 bootstrap、手動更新、進捗公開、一覧用データ読込。
- [HelloWorld/Features/FeedCache/FeedCacheStore.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - ファイル永続化、snapshot 読込、thumbnail 保存。
- [HelloWorld/Features/FeedCache/FeedCacheModels.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Features/FeedCache/FeedCacheModels.swift)
  - キャッシュ用モデルと進捗モデル。

### Infrastructure

- [HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - YouTube feed の取得、更新判定、XML パース。
  - 条件付き取得用の `ETag` と `Last-Modified` を扱う。

### Shared

- [HelloWorld/Shared/AppLogic.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Shared/AppLogic.swift)
  - `BackSwipePolicy`
  - `VideoOpenPolicy`
  - `FeedOrdering`
  - 画面から切り離せるルールはここへ集約する。

### Resources

- [HelloWorld/Resources/Channels.txt](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Resources/Channels.txt)
  - チャンネル ID 一覧。
- [HelloWorld/Resources/TestFixtures/UITest.bootstrap.json](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Resources/TestFixtures/UITest.bootstrap.json)
  - UI テスト用 bootstrap。
- [HelloWorld/Resources/TestFixtures/UITest.cache.json](/Users/ak/Documents/Codex/HelloWorld/HelloWorld/Resources/TestFixtures/UITest.cache.json)
  - UI テスト用 cache。

## データとキャッシュ方針

- キャッシュはアプリ終了後も再利用できる永続データとして扱う。
- 軽量 bootstrap と本体 cache を分ける。
  - bootstrap: ホーム画面を即時表示するための軽量情報
  - cache: チャンネル状態、動画メタデータ、サムネイル位置を含む本体
- UI は起動直後に本体 cache を読む前提にしない。まず bootstrap で描画し、その後必要な場面で本体を読む。
- 動画メタデータは将来の検索、並び替え、絞り込みに使える形で保持する。
- thumbnail は表示高速化のためにローカル保存する。
- キャッシュ更新中でも、一覧画面表示中は live update を止める。戻った時に最新状態をまとめて反映する。

## 更新フロー方針

- ホーム画面の pull-to-refresh を手動更新の入口とする。
- 更新は 3 段階で進める。
  1. フィード更新確認
  2. 更新チャンネル取得
  3. サムネイル取得
- 最大並走数は次の通り。
  - 段階1: 毎秒 3 コール
  - 段階2: 毎秒 1 コール
  - 段階3: 毎秒 1 コール
- つまり理論上の上限は `3 + 1 + 1 = 5` コール並走相当とみなす。
- 更新順は、最新動画投稿日が新しいチャンネルほど先にする。
- 更新確認には条件付き取得を使い、更新が無ければ本体取得を避ける。
- ホーム画面には各段階の進捗を分けて表示する。

## UI 方針

- `iPhone` の見た目と操作感を基準とし、`iPad` は広い画面に合わせて余白と列数だけ調整する。
- 機能ロジックは共通化し、端末差は `AppLayout` で吸収する。
- 一覧画面の振る舞いは `InteractiveListScreen` に集約し、画面ごとの差異を作らない。
- 戻る操作は左端からの右スワイプを使う。
- 戻るスワイプの判定ルールは UI に直接書かず、`BackSwipePolicy` を使う。
- 動画を開く判定は `VideoOpenPolicy` を使う。
- 一覧タイルの見た目は大きいヒーロータイルを維持する。
- サムネイルが無い時も UI が崩れないことを優先する。

## 変更時の判断ルール

- 新しい機能を追加するとき、まず `どこが表示責務で、どこがルールで、どこが永続化か` を分ける。
- 画面固有に見える処理でも、2 画面以上で共有しそうなら最初から共通コンテナまたは `Shared` へ寄せる。
- テストのためだけの分岐は `AppLaunchMode` 配下へ閉じ込める。
- UI テストのための観測点は、実機 UI に影響しない小さい marker で実装する。
- ネットワークやファイル I/O を View に直接書かない。
- actor 警告や main actor 隔離に関わるモデルは、UI モデルと永続化モデルを混同しない。

## テスト方針

- テストは `unit test` と `UI test` を分ける。
- 単純なルール、並び順、parser、resource 読込は unit test で担保する。
- 画面遷移、縦スクロール、ホーム画面の進捗表示、モック更新経路は UI test で担保する。
- UI テストではネットワークを使わない。
- UI テストでは `HELLOWORLD_UI_TEST_MODE=1` を使い、fixture を seed して実行する。
- 必要に応じて `HELLOWORLD_UI_TEST_AUTO_REFRESH=1` で自動 refresh を動かす。
- UI テストは機能確認を主目的とし、性能は緩い閾値で劣化検知する。
- タイムライン診断は `StartupDiagnostics` を使う。
- test fixture を変えたら、依存する UI テストの識別子と期待値も必ず見直す。

## テスト対象と実行方針

- 継続運用のテストターゲットは `iPhone 12 mini` のみとする。
- 他機種での補助確認は任意であり、正本の回帰確認には含めない。
- 基本コマンドは次を使う。

```bash
xcodebuild test \
  -project /Users/ak/Documents/Codex/HelloWorld/HelloWorld.xcodeproj \
  -scheme HelloWorld \
  -destination 'platform=iOS Simulator,name=iPhone 12 mini' \
  -derivedDataPath /Users/ak/Documents/Codex/HelloWorld/.DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

- 利用可能な simulator の UUID を使う場合も、対象機種は `iPhone 12 mini` に固定する。
- 補助スクリプトはこの方針に従う。

## 現在あるテストの責務

### Unit Test

- [HelloWorldTests/Unit/Parsing/ChannelResourceTests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldTests/Unit/Parsing/ChannelResourceTests.swift)
  - チャンネル ID resource 読込。
- [HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift)
  - uploads playlist ID 変換、feed parser。
- [HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift)
  - 戻るスワイプ判定。
- [HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift)
  - 優先順、鮮度判定。

### UI Test

- [HelloWorldUITests/Home/HomeScreenUITests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldUITests/Home/HomeScreenUITests.swift)
  - ホーム画面表示
  - 段階進捗表示
  - モック refresh 経路
  - 起動タイムライン
- [HelloWorldUITests/Browse/BrowseScreenUITests.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldUITests/Browse/BrowseScreenUITests.swift)
  - 全動画一覧遷移
  - チャンネル一覧遷移
  - チャンネル別動画一覧遷移
  - 一覧の縦スクロール
- [HelloWorldUITests/Support/UITestCaseSupport.swift](/Users/ak/Documents/Codex/HelloWorld/HelloWorldUITests/Support/UITestCaseSupport.swift)
  - app 起動、timeline 解析、共通 wait。

## UI テスト安定化ルール

- hidden button の直接タップより、起動環境変数や marker による観測を優先する。
- UI テスト用 identifier は tappable な本体要素に付ける。
- 画面が描画されたことを示す marker と、主要要素が見えることの両方を待つ。
- 性能しきい値は simulator の揺れを考慮して設定する。
- 不安定さが出たら、まず機能 failure と観測 failure を分離する。

## ドキュメント運用ルール

- 構成変更、画面追加、責務移動、テスト戦略変更があったら、この文書を更新する。
- `ARCHITECTURE.md` は案内用であり、正本はこの `rules.md` とする。
- 人向けの説明と LLM 向けの判断材料を分けず、同じ記述で両方が理解できる粒度にする。
- 実装と文書にずれが出た場合は、コードではなく文書を後追いで直すのではなく、どちらが正しいか確認してから揃える。
