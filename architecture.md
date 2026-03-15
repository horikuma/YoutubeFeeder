# HelloWorld Architecture

この文書は、HelloWorld の実装構造、責務分担、データフロー、テスト配置をまとめた設計文書です。`rules.md` が上位方針を定め、`spec.md` が機能仕様を定め、本書はその 2 つを現在の実装へ落とし込むための詳細を扱います。

## 文書の役割

- [rules.md](rules.md)
  - 根幹普遍の方針、変更判断、文書運用、変更管理を定める。
- [spec.md](spec.md)
  - ユーザー向け機能と画面の振る舞いを定める。
- `architecture.md`
  - 現在の実装構造、責務境界、データフロー、テスト配置を定める。

## 現在のプロダクト構成

- アプリは YouTube チャンネル群の feed を取得し、ローカルキャッシュを維持しながら閲覧する iOS アプリである。
- 現在の主導線は `ホーム画面`、`チャンネル一覧`、`全動画一覧`、`チャンネル別動画一覧` で構成する。
- 起動時は `LaunchScreenView` を表示し、その裏で軽量 bootstrap を読み込んでホーム画面へ遷移する。
- ホーム画面はダッシュボードではなく、一覧画面への導線を担う。

## ディレクトリ責務

### App

- [HelloWorld/App/HelloWorldApp.swift](HelloWorld/App/HelloWorldApp.swift)
  - アプリ起動入口。
- [HelloWorld/App/ContentView.swift](HelloWorld/App/ContentView.swift)
  - ルート画面。
  - `LaunchScreenView` からホーム画面へ遷移する。
  - `NavigationStack` と `MaintenanceRoute` を束ねる。
- [HelloWorld/App/AppLayout.swift](HelloWorld/App/AppLayout.swift)
  - size class を基準に `iPhone` と `iPad` のレイアウト差分を吸収する。
- [HelloWorld/App/AppFormatting.swift](HelloWorld/App/AppFormatting.swift)
  - 日付などの共通 formatter。
- [HelloWorld/App/Support/AppTestSupport.swift](HelloWorld/App/Support/AppTestSupport.swift)
  - UI テスト用 launch mode、診断タイムライン、fixture seed、test marker。
  - UI テスト用の初期遷移指定。
  - 起動性能計測用の timeline marker。

### Features

- [HelloWorld/Features/Home/HomeScreenView.swift](HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面本体。
  - 手動更新と一覧画面への導線。
  - `Menu` ベースのチャンネル一覧ソート選択。
  - チャンネル登録画面への導線。
  - チャンネル登録結果のフィードバック表示。
  - iCloud への環境引き継ぎ導線と結果表示。
  - 転送先 backend の切替 UI。
- [HelloWorld/Features/Home/HomeUIComponents.swift](HelloWorld/Features/Home/HomeUIComponents.swift)
  - ホーム画面の表示部品。
- [HelloWorld/Features/Home/HomeRoutes.swift](HelloWorld/Features/Home/HomeRoutes.swift)
  - 一覧系画面への遷移定義。
  - チャンネル一覧には並び順 descriptor を渡す。
- [HelloWorld/Features/Browse/BrowseViews.swift](HelloWorld/Features/Browse/BrowseViews.swift)
  - チャンネル一覧、全動画一覧、チャンネル別動画一覧。
  - 一覧系共通コンテナ `InteractiveListScreen`。
  - iPad 横向きのチャンネル閲覧は `NavigationSplitView` を使う。
  - 選択された並び順 descriptor を一覧サブタイトルと並び順へ反映する。
- [HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift](HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - UI と永続化の仲介。
  - ホーム画面 bootstrap、手動更新、一覧用データ読込、更新状態の管理。
- [HelloWorld/Features/FeedCache/FeedCacheStore.swift](HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - ファイル永続化、snapshot 読込、thumbnail 保存。
  - チャンネル一覧描画用の集約データを返す。
- [HelloWorld/Features/FeedCache/FeedCacheModels.swift](HelloWorld/Features/FeedCache/FeedCacheModels.swift)
  - キャッシュ用モデルと進捗モデル。
  - チャンネル登録日時を含む registry 永続化モデル。
  - iCloud 転送用ドキュメントと固定ファイルパス。
  - `iCloud Drive` と `ローカルDocuments` の転送 backend 定義。

### Infrastructure

- [HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift](HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - YouTube feed の取得、更新判定、XML パース。
  - 条件付き取得用の `ETag` と `Last-Modified` を扱う。
  - `@handle`、チャンネル URL、動画 URL から `Channel ID` を解決する。
  - 登録直後のフィードバック用に最新動画要約の取得にも使う。

### Shared

- [HelloWorld/Shared/AppLogic.swift](HelloWorld/Shared/AppLogic.swift)
  - `BackSwipePolicy`
  - `VideoOpenPolicy`
  - `FeedOrdering`
  - `ChannelBrowseSortDescriptor`
  - 画面から切り離せる pure logic を集約する。

### Resources

- [HelloWorld/Resources/Channels.txt](HelloWorld/Resources/Channels.txt)
  - チャンネル ID 一覧。
- [HelloWorld/Resources/TestFixtures/UITest.bootstrap.json](HelloWorld/Resources/TestFixtures/UITest.bootstrap.json)
  - UI テスト用 bootstrap。
- [HelloWorld/Resources/TestFixtures/UITest.cache.json](HelloWorld/Resources/TestFixtures/UITest.cache.json)
  - UI テスト用 cache。

## データとキャッシュ構造

- キャッシュは永続データとして扱う。
- ユーザー追加チャンネルは `Channel ID` を主キーとして別ファイルに永続化する。
- ユーザー追加チャンネルには登録日時を保持し、一覧ソートの指標として再利用する。
- 環境引き継ぎでは、ユーザー追加チャンネルと登録日時だけを JSON として iCloud Drive の固定ファイルへ保存する。
- インポートではローカルのカスタムチャンネル設定をその JSON で置き換え、動画やサムネイルは転送しない。
- Mac Catalyst では `ローカルDocuments` を既定 backend とし、LLM から制御しやすい固定パス `~/Documents/HelloWorld/channel-registry.json` を使って確認できるようにする。
- 軽量 bootstrap と本体 cache を分ける。
  - bootstrap: ホーム画面を即時表示するための軽量情報
  - cache: チャンネル状態、動画メタデータ、サムネイル位置を含む本体
- UI は起動直後に本体 cache を読む前提にしない。
- thumbnail は表示高速化のためにローカル保存する。
- 一覧画面表示中は live update を止め、戻った時にまとめて反映する。

## 更新フロー

- ホーム画面の pull-to-refresh を手動更新の入口とする。
- 更新は `1チャンネル = 更新確認 -> 必要なら本体取得 -> 必要なら新着動画のサムネイル取得` の単一パイプラインで処理する。
- 同時処理数は最大 `3` とする。
- 更新順は `latestPublishedAt` 降順、次に `lastSuccessAt` 降順、最後に `lastCheckedAt` 昇順とする。
- 更新確認には条件付き取得を使い、更新が無ければ本体取得を避ける。
- サムネイル取得は、その回に見つかった新着動画だけに行う。

## UI 実装方針

- `iPhone` の見た目と操作感を基準とし、`iPad` は広い画面に合わせて余白と列数だけ調整する。
- 機能ロジックは共通化し、端末差は `AppLayout` で吸収する。
- `iPad 縦向き` は原則として `iPhone` と同じ操作モデルを維持する。
- 一覧画面の振る舞いは `InteractiveListScreen` に集約し、画面ごとの差異を作らない。
- 戻るスワイプの判定は `BackSwipePolicy` を使う。
- 動画を開く判定は `VideoOpenPolicy` を使う。
- チャンネル一覧の分割表示は SwiftUI の適応的コンテナを優先し、現在は `NavigationSplitView` を採用する。

## 実装責務の要点

- [HelloWorld/App/ContentView.swift](HelloWorld/App/ContentView.swift)
  - ルート画面、起動画面からホーム画面への遷移、ルートレベルの navigation を担う。
- [HelloWorld/Features/Home/HomeScreenView.swift](HelloWorld/Features/Home/HomeScreenView.swift)
  - ホーム画面の表示、手動更新導線、一覧ソート選択、環境引き継ぎを担う。
- [HelloWorld/Features/Browse/BrowseViews.swift](HelloWorld/Features/Browse/BrowseViews.swift)
  - 一覧系 UI、共通挙動、並び順表示を担う。
- [HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift](HelloWorld/Features/FeedCache/FeedCacheCoordinator.swift)
  - bootstrap 読込、手動更新フロー制御、一覧用 state 公開、live update 抑制、引き継ぎ後の再読込を担う。
- [HelloWorld/Features/FeedCache/FeedCacheStore.swift](HelloWorld/Features/FeedCache/FeedCacheStore.swift)
  - cache.json、bootstrap、thumbnail、channel registry の読取利用を担う。
- [HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift](HelloWorld/Infrastructure/YouTube/YouTubeFeed.swift)
  - 更新確認、本体取得、XML parser を担う。
- [HelloWorld/Shared/AppLogic.swift](HelloWorld/Shared/AppLogic.swift)
  - スワイプ判定、長押し判定、一覧並び順、鮮度判定などの pure logic を担う。

## テスト構造

### テスト対象と実行方針

- 継続運用のテストターゲットは `iPhone 12 mini` のみとする。
- 他機種での補助確認は任意であり、正本の回帰確認には含めない。
- UI テストは、重複する起動確認をワークフロー単位へまとめ、必要な画面は test support の初期遷移指定で直接開けるようにする。
- 基本コマンドは次を使う。

```bash
xcodebuild test \
  -project HelloWorld.xcodeproj \
  -scheme HelloWorld \
  -destination 'platform=iOS Simulator,name=iPhone 12 mini' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

### 現在あるテストの責務

#### Unit Test

- [HelloWorldTests/Unit/Parsing/ChannelResourceTests.swift](HelloWorldTests/Unit/Parsing/ChannelResourceTests.swift)
  - チャンネル ID resource 読込。
- [HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift](HelloWorldTests/Unit/Parsing/YouTubeFeedParserTests.swift)
  - uploads playlist ID 変換、feed parser。
- [HelloWorldTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift](HelloWorldTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift)
  - channel registry の後方互換と引き継ぎドキュメントの decode。
- [HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift](HelloWorldTests/Unit/Policies/BackSwipePolicyTests.swift)
  - 戻るスワイプ判定。
- [HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift](HelloWorldTests/Unit/Ordering/FeedOrderingTests.swift)
  - 優先順、鮮度判定。
- [HelloWorldTests/Unit/Layout/AppLayoutTests.swift](HelloWorldTests/Unit/Layout/AppLayoutTests.swift)
  - size class に応じたレイアウト切替。

#### UI Test

- [HelloWorldUITests/Home/HomeScreenUITests.swift](HelloWorldUITests/Home/HomeScreenUITests.swift)
  - ホーム画面表示
  - `チャンネル` / `動画` 導線
  - モック refresh 経路
  - 起動タイムライン
  - `metrics.md` 更新用の起動性能 JSON 書き出し
- [HelloWorldUITests/Browse/BrowseScreenUITests.swift](HelloWorldUITests/Browse/BrowseScreenUITests.swift)
  - 全動画一覧遷移
  - 一覧の縦スクロール
- [HelloWorldUITests/Support/UITestCaseSupport.swift](HelloWorldUITests/Support/UITestCaseSupport.swift)
  - app 起動、timeline 解析、共通 wait。

## テスト運用詳細

- UI テストは `HELLOWORLD_UI_TEST_MODE=1` を使い、fixture を app support 配下へ seed して実行する。
- 自動更新経路を確認したいテストだけ `HELLOWORLD_UI_TEST_AUTO_REFRESH=1` を使う。
- UI テストでは実ネットワークを使わない。
- hidden button の直接タップより、起動環境変数や marker による観測を優先する。
- UI テスト用 identifier は tappable な本体要素に付ける。
- 画面が描画されたことを示す marker と、主要要素が見えることの両方を待つ。
- 性能しきい値は simulator の揺れを考慮して設定する。
- `scripts/collect_metrics.sh` は `xcodebuild build-for-testing` と `test-without-building` を分離して時間を採取し、UI テストが書き出した起動性能 JSON を `metrics.md` へ集約する。
- 同スクリプトは Xcode の Scheme post-action や Run Script からも呼び出せるよう、CLI だけで完結する前提で設計する。
