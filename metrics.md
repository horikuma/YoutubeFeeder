# HelloWorld Metrics

この文書は、コミット単位で観測した開発統計と起動性能の履歴を残す正本です。各エントリは、そのエントリ自体を含むコミットに対応します。

更新は `./scripts/collect_metrics.sh --label '<変更概要>' --manual-retries <回数>` を使う。Xcode から取得したい場合も、Scheme の post-action や Run Script から同じコマンドを呼ぶことを前提とする。

## 2026/03/15

### 組み込みチャンネル定義を廃止する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.177s`
- test-without-building: `68.827s`
- 検証合計時間: `73.004s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `479ms`
- スプラッシュ表示からホーム表示まで: `147ms`
- 起動からホーム表示まで: `626ms`
- 起動から bootstrap 読込完了まで: `555ms`
- 起動からホーム遷移開始まで: `700ms`

### 全チャンネルをバックアップ対象に広げる

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.979s`
- test-without-building: `71.807s`
- 検証合計時間: `75.786s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `497ms`
- スプラッシュ表示からホーム表示まで: `113ms`
- 起動からホーム表示まで: `610ms`
- 起動から bootstrap 読込完了まで: `555ms`
- 起動からホーム遷移開始まで: `679ms`

### 端末内バックアップへ仕様を後退させる

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.174s`
- test-without-building: `67.211s`
- 検証合計時間: `71.385s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `443ms`
- スプラッシュ表示からホーム表示まで: `108ms`
- 起動からホーム表示まで: `551ms`
- 起動から bootstrap 読込完了まで: `498ms`
- 起動からホーム遷移開始まで: `561ms`

### 検証用DerivedDataを同期対象外へ移す

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `6.292s`
- test-without-building: `68.462s`
- 検証合計時間: `74.754s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `479ms`
- スプラッシュ表示からホーム表示まで: `115ms`
- 起動からホーム表示まで: `594ms`
- 起動から bootstrap 読込完了まで: `537ms`
- 起動からホーム遷移開始まで: `636ms`

### iCloud保存の設定漏れを修正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.609s`
- test-without-building: `69.159s`
- 検証合計時間: `71.768s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `456ms`
- スプラッシュ表示からホーム表示まで: `115ms`
- 起動からホーム表示まで: `571ms`
- 起動から bootstrap 読込完了まで: `511ms`
- 起動からホーム遷移開始まで: `582ms`

### Mac検証用ローカル転送とiCloud切替を追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.010s`
- test-without-building: `73.400s`
- 検証合計時間: `76.410s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `656ms`
- スプラッシュ表示からホーム表示まで: `270ms`
- 起動からホーム表示まで: `926ms`
- 起動から bootstrap 読込完了まで: `737ms`
- 起動からホーム遷移開始まで: `1007ms`

### iCloudでチャンネル設定を引き継げるようにする

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `5.540s`
- test-without-building: `69.289s`
- 検証合計時間: `74.829s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `460ms`
- スプラッシュ表示からホーム表示まで: `112ms`
- 起動からホーム表示まで: `572ms`
- 起動から bootstrap 読込完了まで: `515ms`
- 起動からホーム遷移開始まで: `583ms`

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
