# Verification Skill

この文書は、検証という 1 つのタスクだけを定義する。

## 検証

- 検証とは、変更内容に応じたテストと build 確認を実施し、変更結果が要求どおりに成立していることを確認するタスクである。
- このタスクでは、検証対象の選定、テスト実行、build 確認、再確認の絞込み、最終全体確認までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- 検証では、変更内容に応じたテストと build 確認を行い、アプリ本体の build 確認には `scripts/xcode-build` 配下で定義された次の command のいずれかを使わなければならない。
  `./scripts/command-runner.py 'build-debug'`
  例: `./scripts/command-runner.py 'build-debug'`
  `./scripts/command-runner.py 'build-release'`
  例: `./scripts/command-runner.py 'build-release'`
  - 開発中の build 確認では `build-debug` を使わなければならない。
  - リリース相当または Issue 実施の最終確認では `build-release` を使わなければならない。
  - `xcodebuild` を直接呼び出してよいのは `scripts/xcode-build` 配下の command 実装だけであり、LLM は直接 `xcodebuild` を実行してはならない。
- アプリ本体に対する build 確認を行う場合は、build 時のチェック項目として build 結果、`warning 0`、`error 0` に加えて SwiftLint 実行結果を並べて記録しなければならない。
- SwiftLint 実行結果は観測値として扱い、build 成否や `warning 0` / `error 0` の判定へ混ぜてはならず、報告だけを行わなければならない。
- SwiftLint 観測を行う場合は、次の command を実行し、その標準出力または標準エラーへ出た違反内容をそのまま観測結果として扱わなければならない。
  `swiftlint lint`
  例: `swiftlint lint`
- 契約ログを追加した場合は、起点、終点、正常パス、異常パスが 1 つの代表経路で連続して観測できることを確認し、欠けている系列があればその系列を補うまで検証を終えてはならない。
- 自動更新や待機を含む変更を検証する場合は、開始直後の経路と一定時間経過後の経路の両方を観測し、最初から動かない場合と途中から止まる場合を分けて確認しなければならない。
- 検証が最初の 1 回で通らなかった場合は、修正ループ中の再確認を関連テストと影響が及ぶはずのテストへ限定し、それらが通った後で最後に全体テストを実行しなければならない。
- 最終の全体テストでは、`scripts/xcode-build` 配下で定義された次の command を使わなければならない。
  `./scripts/command-runner.py 'xcodebuild-test'`
  例: `./scripts/command-runner.py 'xcodebuild-test'`
  - build と test を分離する必要がある場合だけ、`xcodebuild-build-for-testing` と `xcodebuild-test-without-building` を順に使わなければならない。
- `tools`、`skills`、`scripts` だけを変更した場合は、アプリ本体の build や test は実施せず、対象ツールの構文確認と代表的な 1 経路の実行確認で検証しなければならない。
- 機能追加、不具合対応、設計変更を含む場合は、変更内容に対応するテストと、`scripts/xcode-build` 配下 command による build 確認を省略してはならない。

## 完了条件

- 変更内容に応じたテストと、`scripts/xcode-build` 配下 command による build 確認が完了していること。
- 最終確認で `error 0` かつ `warning 0` を確認していること。
- build 確認を行った場合は、SwiftLint 実行結果が観測値として記録または報告されていること。
- 再確認が必要な場合は、関連テストへの限定確認と最終全体確認を順に実施していること。
- `tools`、`skills`、`scripts` だけの変更では、対象ツールの構文確認と代表実行確認が完了していること。

## 禁止事項

- 変更内容に対応する検証を省略したまま完了扱いにしてはならない。
- 修正ループ中に毎回全体テストを重複実行してはならない。
- `tools`、`skills`、`scripts` だけの変更なのに、慣習でアプリ本体の build や test を要求してはならない。
- SwiftLint の違反件数だけで build 失敗、`warning 0` 未達、`error 0` 未達を判定してはならない。
