# HelloWorld Metrics

この文書は、コミット単位で観測した開発統計と起動性能の履歴を残す正本です。各エントリは、そのエントリ自体を含むコミットに対応します。

更新は `./scripts/collect_metrics.sh --label '<変更概要>' --manual-retries <回数>` を使う。Xcode から取得したい場合も、Scheme の post-action や Run Script から同じコマンドを呼ぶことを前提とする。

## 2026/03/15

### 動画URLからチャンネル登録できるようにする

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.878s`
- test-without-building: `70.683s`
- 検証合計時間: `73.561s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `639ms`
- スプラッシュ表示からホーム表示まで: `272ms`
- 起動からホーム表示まで: `911ms`
- 起動から bootstrap 読込完了まで: `706ms`
- 起動からホーム遷移開始まで: `987ms`

### 起動と検証の統計基盤を追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.933s`
- test-without-building: `69.836s`
- 検証合計時間: `73.769s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `476ms`
- スプラッシュ表示からホーム表示まで: `132ms`
- 起動からホーム表示まで: `608ms`
- 起動から bootstrap 読込完了まで: `533ms`
- 起動からホーム遷移開始まで: `626ms`
