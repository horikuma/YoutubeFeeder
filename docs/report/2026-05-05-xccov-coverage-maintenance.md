# 2026-05-05 xccov カバレッジ運用レポート

## 暫定結論

今後の維持対象は `YoutubeFeeder.app` のカバレッジ値を目標値として据えるのがよい。今回の確認では、`YoutubeFeederTests.xctest` は 99.15% まで到達し、`YoutubeFeeder.app` は 52.20% だった。主な課題は、アプリ本体のカバレッジを継続的に上げていくための追跡軸を一本化することと、`xcodebuild test` の出力先を repo 配下へ安定して寄せることだった。

最も効いたのは、`xcrun xccov` を `scripts/command-runner.py` 経由で呼べるようにして、`xcodebuild test` の結果 bundle から coverage をそのまま抜けるようにしたことだ。加えて、`xcodebuild` の既定 derived data を `build/xcodebuild` に寄せたことで、`~/Library/Developer/Xcode/DerivedData` への漏れを断てた。

## 目的

このレポートは、本スレッドで行ったツール選定、環境構築、実行手順、現時点の結果を、後から同じ経路を再現できる形で残すためのものである。運用の目標は `YoutubeFeeder.app` のカバレッジを継続観測し、今後のメンテナンスでその値を上げることにある。

主目的は、`YoutubeFeeder.app` の coverage を今後の目標値として監視できるようにすること。副目的は、`xcodebuild` / `xccov` の実行経路を repo 配下にそろえ、失敗時のログ追跡を容易にすること。

## 実施の流れ

1. `xcrun xccov` の存在と用法を確認し、`scripts/xccov` を追加して `scripts/command-runner.py 'xccov'` から呼べるようにした。
2. `build-debug` を実行し、`build/debug` へ derived data を固定できることを確認した。
3. `xcodebuild test` の coverage 付き実行を試し、最初は `DerivedData` の既定先や test runner 通信で失敗した。
4. `scripts/xcode-build/xcodebuild.py` を修正し、`-derivedDataPath` 未指定時は `build/xcodebuild` を使うようにした。
5. 再度 `xcodebuild test` を走らせ、`build/xcodebuild/Logs/Test/*.xcresult` に結果 bundle を作成した。
6. その結果 bundle に対して `./scripts/command-runner.py 'xccov' view --report --only-targets ...` を実行し、coverage を取得した。

## 評価

### ツール選定

- 実行入口は `scripts/command-runner.py` に集約した。
- coverage 抽出は `xcrun xccov` をそのまま使い、薄いラッパーを `scripts/xccov/xccov.py` に置いた。
- test 実行は `scripts/xcode-build/xcodebuild.py` を介して `xcodebuild` を呼んだ。

### 環境構築

- build の出力先は `build/debug` と `build/release` に固定した。
- test の output も `build/xcodebuild` に寄せた。
- coverage の観測対象は、最終的には `build/xcodebuild/Logs/Test/Test-YoutubeFeeder-2026.05.05_07-19-54-+0900.xcresult` を使った。

### 手順

- `build-debug` を先に通す。
- `xcodebuild test -enableCodeCoverage YES -only-testing:YoutubeFeederTests -skip-testing:YoutubeFeederUITests` を実行する。
- `xccov view --report --only-targets` で `.xcresult` を読む。
- ログは `logs/coverage-check.log` を SoT とする。

### 現時点の結果

- `build-debug`: 成功
- `xcodebuild test`: 成功
- `xccov view --report --only-targets`: 成功
- `YoutubeFeeder.app`: 52.20%
- `YoutubeFeederTests.xctest`: 99.15%
- `YoutubeFeederUITests.xctest`: 0.00%

## 今後の改善

1. `YoutubeFeeder.app` の 52.20% を継続的な目標値として扱い、今後の変更で下げないようにする。
   - 現在の 52.20% は、主に純ロジック層（Browse / Policy / Logger 等）に偏っており、FeedCache / SQLite / ネットワーク層のカバレッジは低い。
   - 今後は FeedCache 系を最優先対象としてカバレッジを引き上げる。
2. coverage を見るときは、`YoutubeFeederTests.xctest` の高い値に引っ張られず、`YoutubeFeeder.app` を主指標として扱う。
3. `build/xcodebuild` と `logs/` の二層で、再実行時に同じログ系列を追える形を保つ。
4. test runner 通信失敗が出たときは、coverage 値そのものと環境要因を分けて判定する。

## Appendix A. ユーザー指示全文

> YoutubeFeeder.appの値を目標値と据え、今後継続的にメンテしていく。という方針を示し、本スレッドで行ったツール選定、環境構築、手順、現時点の結果、その他一般的に必要と思われる内容を、レポートとして出力せよ。コミットするな。

## Appendix B. LLM 出力の概要

- `xcrun xccov` を `scripts/command-runner.py` から呼べるようにした。
- `xcodebuild` の derived data を repo 配下の `build/xcodebuild` に寄せた。
- `build-debug` と coverage 付き `xcodebuild test` を実行し、`xccov` で coverage を取得した。
- 最終結果として、`YoutubeFeeder.app` を今後の継続観測対象に据える方針を明文化した。

## Appendix C. 試行錯誤と削減したいループ

- 最初は `DerivedData` の漏れを疑ったが、ログで `build/xcodebuild` に出力が寄っていることを確認して、その仮説は退けた。
- その後、`testmanagerd` との通信失敗が残ったため、環境の書き込み先と test runner の失敗を分けて扱う必要があった。
- coverage の確認では、`YoutubeFeederTests.xctest` の高い値に引っ張られず、`YoutubeFeeder.app` を主指標に固定すると議論がぶれにくい。
