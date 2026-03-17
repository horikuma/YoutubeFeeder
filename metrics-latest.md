## 2026/03/17
### Adaptive UIへ分割条件を委譲する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `1.707s`
- test-without-building: `96.450s`
- 検証合計時間: `98.157s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `403ms`
- スプラッシュ表示からホーム表示まで: `120ms`
- 起動からホーム表示まで: `523ms`
- 起動から bootstrap 読込完了まで: `466ms`
- 起動からホーム遷移開始まで: `561ms`

### UIテスト責務を見直して検証コストを調整する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.917s`
- test-without-building: `99.181s`
- 検証合計時間: `102.098s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `417ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `540ms`
- 起動から bootstrap 読込完了まで: `483ms`
- 起動からホーム遷移開始まで: `550ms`

### テスト別計測を出力する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.325s`
- test-without-building: `104.477s`
- 検証合計時間: `107.802s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `417ms`
- スプラッシュ表示からホーム表示まで: `125ms`
- 起動からホーム表示まで: `542ms`
- 起動から bootstrap 読込完了まで: `484ms`
- 起動からホーム遷移開始まで: `581ms`

### metrics と decisions の追記順と docs-only 時の metrics 不要条件を rules へ反映する
- 種別: docs
- 実行環境: なし
- metrics実測: `不要`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 実測不要理由: `rules.md` と当日文書ログの運用整理のみで、ソースコード修正を含まないため

### rules.md を開発プロセス軸と判断基準軸で再構築する
- 種別: docs
- 実行環境: なし
- metrics実測: `不要`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 実測不要理由: `rules.md` と当日文書ログの再構成のみで、ソースコード変更や検証前提の変更を含まないため

### ドキュメント管理を `*-log.md` / `*-latest.md` 運用へ移行する
- 種別: docs
- 実行環境: なし
- metrics実測: `不要`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 実測不要理由: `rules.md`、`spec.md`、`architecture.md`、`scripts/collect_metrics.sh` と文書管理ファイル群の更新のみで、ソースコード修正を含まないため
