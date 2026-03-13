# Architecture

## App
- `HelloWorld/App`: アプリ起動、ルート画面、レイアウト、表示共通設定

## Features
- `HelloWorld/Features/Home`: ホーム画面とその表示部品
- `HelloWorld/Features/Browse`: チャンネル一覧、動画一覧、戻るスワイプなど一覧系UI
- `HelloWorld/Features/FeedCache`: キャッシュ進捗、永続化モデル、ストア、更新オーケストレーション

## Infrastructure
- `HelloWorld/Infrastructure/YouTube`: YouTube feed 取得と XML パース

## Shared
- `HelloWorld/Shared`: UI ルールや並び順などの pure logic

## Resources
- `HelloWorld/Resources`: チャンネル一覧や UI テスト用 fixture

## Tests
- `HelloWorldTests/Unit/Parsing`: resource / parser / service の単体テスト
- `HelloWorldTests/Unit/Policies`: ジェスチャや入力ポリシーの単体テスト
- `HelloWorldTests/Unit/Ordering`: 並び順や freshness 判定の単体テスト
- `HelloWorldUITests/Home`: ホーム画面の UI テスト
- `HelloWorldUITests/Browse`: 一覧画面の UI テスト
- `HelloWorldUITests/Support`: UI テスト共通ヘルパ
