## 2026/04/07
### Issue75 verification
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 17,OS=26.4`
- build-for-testing: `11.472s`
- test-without-building: `143.382s`
- 検証合計時間: `154.854s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `464ms`
- スプラッシュ表示からホーム表示まで: `166ms`
- 起動からホーム表示まで: `630ms`
- 起動から bootstrap 読込完了まで: `546ms`
- 起動からホーム遷移開始まで: `627ms`

- Issue75 focused verification blocked: iOS 26.4 runtime unavailable and Mac Catalyst test target requires macOS 26.4 while host is macOS 26.3.1
