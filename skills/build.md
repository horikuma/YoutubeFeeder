# Build Skill

この文書は、YoutubeFeeder の build 実行という 1 つのタスクだけを定義する。

## Build

- build とは、`scripts` で定義された build コマンドを使って、`YoutubeFeeder` を `debug` または `release` のどちらか 1 つでビルドするタスクである。
- 開発中の build は `debug` と明示する。
- このタスクでは、mode の確定、対応する command の選択、実行結果の確認だけをこの文書で判断しなければならない。
- mode は必須であり、`debug` か `release` のどちらかを明示しなければならない。
- mode が未指定、曖昧、または両方指定された場合は、実行へ進まず不足分を確認しなければならない。

## 実施内容

- `debug` を指定する場合は、開発中の build として次の command を実行する。
  `./scripts/command-runner.py 'build-debug'`
- `release` を指定する場合は、次の command を実行する。
  `./scripts/command-runner.py 'build-release'`
- build 出力は、それぞれ `build/debug` または `build/release` を成果物の基準点として扱う。
- `xcodebuild` を直接呼び出してはならず、必ず `scripts` の build command を経由しなければならない。

## 完了条件

- `debug` または `release` のどちらか 1 つが明示されていること。
- 対応する build command が `scripts/command-runner.py` 経由で実行されていること。
- 実行結果が成功として確認できていること。

## 禁止事項

- mode を省略したまま build を開始してはならない。
- `debug` と `release` を同時に実行対象として扱ってはならない。
- `xcodebuild` を直接実行してはならない。
