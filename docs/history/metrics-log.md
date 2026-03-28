## 2026/03/27

## 2026/03/25
### issue21でrules再編とGitHub運用入口を更新する
- 種別: tool
- 計測: `python3 -m py_compile skills/github/pull-request.py skills/github/register-issue-branch.py`
- 理由: `docs`、`skills`、`scripts` の変更のみのため、対象ツールの構文確認で検証する

### issue22起票とrules更新の追跡経路を復旧する
- 種別: source
- 計測: `skip`
- 理由: `docs` と GitHub 運用の変更のみのため、アプリ本体の build / test は実施しない

## 2026/03/24
### github操作のmode切替とissue-pr運用の統一
- 種別: source
- 計測: `skip`
- 理由: `tools` / `skills` / `scripts` / `docs` の変更のみのため、アプリ本体の build / test は実施しない

### main最新化とgithub既定値cache・履歴ローテーションを追加する
- 種別: source
- 計測: `skip`
- 理由: `tools` / `skills` / `scripts` / `docs` の変更のみのため、アプリ本体の build / test は実施しない

## 2026/03/23
### issue9実施のためのspecsとmetrics再編
- 種別: source
- 計測: `skip`
- 理由: `tools` / `scripts` / `docs` の変更のみのため、アプリ本体の build / test は実施しない

### issue7実施のためのrules再配置とgithub skill整理
- 種別: source
- 計測: `skip`
- 理由: `tools` / `skills` / `scripts` / `docs` の変更のみのため、アプリ本体の build / test は実施しない

### issue駆動フロー追加とgithub skill拡張
- 種別: source
- 計測: `skip`
- 理由: `tools` / `skills` / `scripts` / `docs` の変更のみのため、アプリ本体の build / test は実施しない

### issue更新skill追加とissue5詳細化
- 種別: source
- 計測: `skip`
- 理由: `tools` / `skills` / `scripts` と外部 Issue 更新のみの変更のため、アプリ本体の build / test は実施しない

### rules整理とissue取得skill追加
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.294s`
- test-without-building: `138.535s`
- 検証合計時間: `141.829s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `413ms`
- スプラッシュ表示からホーム表示まで: `126ms`
- 起動からホーム表示まで: `539ms`
- 起動から bootstrap 読込完了まで: `476ms`
- 起動からホーム遷移開始まで: `548ms`

## 2026/03/21
### スプラッシュのアプリ名を1行で収める
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.540s`
- test-without-building: `132.783s`
- 検証合計時間: `136.323s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `412ms`
- スプラッシュ表示からホーム表示まで: `121ms`
- 起動からホーム表示まで: `533ms`
- 起動から bootstrap 読込完了まで: `477ms`
- 起動からホーム遷移開始まで: `544ms`

### 動画タイルの長押し共有を全画面へ追加する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.611s`
- test-without-building: `138.732s`
- 検証合計時間: `143.343s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `404ms`
- スプラッシュ表示からホーム表示まで: `117ms`
- 起動からホーム表示まで: `521ms`
- 起動から bootstrap 読込完了まで: `467ms`
- 起動からホーム遷移開始まで: `532ms`

### 4分未満の短尺動画マスクを復旧する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.153s`
- test-without-building: `134.783s`
- 検証合計時間: `138.936s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `429ms`
- スプラッシュ表示からホーム表示まで: `130ms`
- 起動からホーム表示まで: `559ms`
- 起動から bootstrap 読込完了まで: `494ms`
- 起動からホーム遷移開始まで: `597ms`

### remote search起点のチャンネル動画1件化を修正しlegacy runtimeを撤去する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `5.166s`
- test-without-building: `151.192s`
- 検証合計時間: `156.358s`
- 手修正後の再試行回数: `3`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `411ms`
- スプラッシュ表示からホーム表示まで: `122ms`
- 起動からホーム表示まで: `533ms`
- 起動から bootstrap 読込完了まで: `475ms`
- 起動からホーム遷移開始まで: `544ms`

### 重複動画IDクラッシュを防ぎ全設定リセットでSQLiteを完全再初期化する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.912s`
- test-without-building: `130.839s`
- 検証合計時間: `135.751s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `429ms`
- スプラッシュ表示からホーム表示まで: `132ms`
- 起動からホーム表示まで: `561ms`
- 起動から bootstrap 読込完了まで: `501ms`
- 起動からホーム遷移開始まで: `573ms`

### YouTube検索split右ペインの全件段階表示とSQLite永続化へ移行
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `5.056s`
- test-without-building: `129.858s`
- 検証合計時間: `134.914s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `445ms`
- スプラッシュ表示からホーム表示まで: `137ms`
- 起動からホーム表示まで: `582ms`
- 起動から bootstrap 読込完了まで: `515ms`
- 起動からホーム遷移開始まで: `593ms`

### YouTube検索既定キャッシュのチャンネル動画参照漏れを修正する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.653s`
- test-without-building: `129.754s`
- 検証合計時間: `133.407s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `442ms`
- スプラッシュ表示からホーム表示まで: `136ms`
- 起動からホーム表示まで: `578ms`
- 起動から bootstrap 読込完了まで: `512ms`
- 起動からホーム遷移開始まで: `589ms`

### YouTube検索画面の描画をhidden hostでprewarmする
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.735s`
- test-without-building: `134.512s`
- 検証合計時間: `138.247s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `397ms`
- スプラッシュ表示からホーム表示まで: `133ms`
- 起動からホーム表示まで: `530ms`
- 起動から bootstrap 読込完了まで: `473ms`
- 起動からホーム遷移開始まで: `543ms`

### YouTube検索画面の初回遷移をホーム側prewarmで軽くする
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.485s`
- test-without-building: `132.058s`
- 検証合計時間: `135.543s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `407ms`
- スプラッシュ表示からホーム表示まで: `132ms`
- 起動からホーム表示まで: `539ms`
- 起動から bootstrap 読込完了まで: `484ms`
- 起動からホーム遷移開始まで: `573ms`

### LLM所要時間の記録を安定化する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `6.224s`
- test-without-building: `135.263s`
- 検証合計時間: `141.487s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `449ms`
- スプラッシュ表示からホーム表示まで: `147ms`
- 起動からホーム表示まで: `596ms`
- 起動から bootstrap 読込完了まで: `530ms`
- 起動からホーム遷移開始まで: `634ms`

### チャンネルタイルの機能核と操作差分を分離する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.469s`
- test-without-building: `132.562s`
- 検証合計時間: `136.031s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `407ms`
- スプラッシュ表示からホーム表示まで: `118ms`
- 起動からホーム表示まで: `525ms`
- 起動から bootstrap 読込完了まで: `468ms`
- 起動からホーム遷移開始まで: `562ms`

### YouTube検索split詳細のチャンネル表示ずれを解消
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.959s`
- test-without-building: `134.008s`
- 検証合計時間: `136.967s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `385ms`
- スプラッシュ表示からホーム表示まで: `118ms`
- 起動からホーム表示まで: `503ms`
- 起動から bootstrap 読込完了まで: `451ms`
- 起動からホーム遷移開始まで: `538ms`

### health_barometerの警告を責務に沿って整理
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.178s`
- test-without-building: `132.229s`
- 検証合計時間: `136.407s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `397ms`
- スプラッシュ表示からホーム表示まで: `127ms`
- 起動からホーム表示まで: `524ms`
- 起動から bootstrap 読込完了まで: `467ms`
- 起動からホーム遷移開始まで: `560ms`

### Mermaid検証をローカル実行へ移行
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.147s`
- test-without-building: `133.862s`
- 検証合計時間: `137.009s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `481ms`
- スプラッシュ表示からホーム表示まで: `166ms`
- 起動からホーム表示まで: `647ms`
- 起動から bootstrap 読込完了まで: `565ms`
- 起動からホーム遷移開始まで: `696ms`

### 改名後のXcodeビルドと実機署名条件を整理
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `6.333s`
- test-without-building: `140.866s`
- 検証合計時間: `147.199s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `407ms`
- スプラッシュ表示からホーム表示まで: `121ms`
- 起動からホーム表示まで: `528ms`
- 起動から bootstrap 読込完了まで: `473ms`
- 起動からホーム遷移開始まで: `564ms`

### HelloWorldをYoutubeFeederへ改名
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.018s`
- test-without-building: `128.965s`
- 検証合計時間: `131.983s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `401ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `524ms`
- 起動から bootstrap 読込完了まで: `470ms`
- 起動からホーム遷移開始まで: `540ms`

## 2026/03/19
### 検索再取得の責務をdomainへ戻す
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `5.324s`
- test-without-building: `117.382s`
- 検証合計時間: `122.706s`
- 手修正後の再試行回数: `8`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `420ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `543ms`
- 起動から bootstrap 読込完了まで: `486ms`
- 起動からホーム遷移開始まで: `582ms`

### YouTube検索チップ表示とGUI参照を整理
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.920s`
- test-without-building: `117.428s`
- 検証合計時間: `122.348s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `427ms`
- スプラッシュ表示からホーム表示まで: `134ms`
- 起動からホーム表示まで: `561ms`
- 起動から bootstrap 読込完了まで: `498ms`
- 起動からホーム遷移開始まで: `600ms`

### 検索経由の自動読込を上部スピナーで通知
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.915s`
- test-without-building: `117.127s`
- 検証合計時間: `122.042s`
- 手修正後の再試行回数: `5`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `435ms`
- スプラッシュ表示からホーム表示まで: `127ms`
- 起動からホーム表示まで: `562ms`
- 起動から bootstrap 読込完了まで: `501ms`
- 起動からホーム遷移開始まで: `603ms`

## 2026/03/18
### AdaptiveUI命名をCompactRegularへ整理
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.448s`
- test-without-building: `99.057s`
- 検証合計時間: `101.505s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `410ms`
- スプラッシュ表示からホーム表示まで: `122ms`
- 起動からホーム表示まで: `532ms`
- 起動から bootstrap 読込完了まで: `477ms`
- 起動からホーム遷移開始まで: `567ms`

### 動画タイル長押しメニュー統一
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.193s`
- test-without-building: `98.718s`
- 検証合計時間: `100.911s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `454ms`
- スプラッシュ表示からホーム表示まで: `130ms`
- 起動からホーム表示まで: `584ms`
- 起動から bootstrap 読込完了まで: `521ms`
- 起動からホーム遷移開始まで: `623ms`

## 2026/03/17
### 計測スクリプトを単一の全体実行へ統合する
- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `1.793s`
- test-without-building: `96.488s`
- 検証合計時間: `98.281s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `417ms`
- スプラッシュ表示からホーム表示まで: `119ms`
- 起動からホーム表示まで: `536ms`
- 起動から bootstrap 読込完了まで: `481ms`
- 起動からホーム遷移開始まで: `573ms`

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

## 2026/03/15
### 検索キャッシュの全削除漏れを修正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `20.5s`
- test-without-building: `64.5s`
- 検証合計時間: `84.928s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `442ms`
- スプラッシュ表示からホーム表示まで: `142ms`
- 起動からホーム表示まで: `584ms`
- 起動から bootstrap 読込完了まで: `510ms`
- 起動からホーム遷移開始まで: `633ms`

### 全設定リセット導線でレガシー依存を整理する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `21.3s`
- test-without-building: `65.4s`
- 検証合計時間: `88.931s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `491ms`
- スプラッシュ表示からホーム表示まで: `172ms`
- 起動からホーム表示まで: `663ms`
- 起動から bootstrap 読込完了まで: `587ms`
- 起動からホーム遷移開始まで: `710ms`

### チャンネル更新時にregistry欠落を自動回復する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `20.0s`
- test-without-building: `63.4s`
- 検証合計時間: `83.458s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `479ms`
- スプラッシュ表示からホーム表示まで: `125ms`
- 起動からホーム表示まで: `604ms`
- 起動から bootstrap 読込完了まで: `543ms`
- 起動からホーム遷移開始まで: `648ms`

### 実機のリアルタイム更新ログを取得できるようにする

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `20.0s`
- test-without-building: `63.6s`
- 検証合計時間: `83.627s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `460ms`
- スプラッシュ表示からホーム表示まで: `137ms`
- 起動からホーム表示まで: `597ms`
- 起動から bootstrap 読込完了まで: `535ms`
- 起動からホーム遷移開始まで: `637ms`

### チャンネル更新時の一覧反映を修正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `17.1s`
- test-without-building: `66.2s`
- 検証合計時間: `83.347s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `453ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `576ms`
- 起動から bootstrap 読込完了まで: `515ms`
- 起動からホーム遷移開始まで: `618ms`

### 検索履歴と動画タイル表示を拡張する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.117s`
- test-without-building: `83.765s`
- 検証合計時間: `86.882s`
- 手修正後の再試行回数: `4`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `448ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `571ms`
- 起動から bootstrap 読込完了まで: `511ms`
- 起動からホーム遷移開始まで: `612ms`

### YouTube検索を明示更新型の100件収集へ改める

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.253s`
- test-without-building: `90.130s`
- 検証合計時間: `94.383s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `481ms`
- スプラッシュ表示からホーム表示まで: `140ms`
- 起動からホーム表示まで: `621ms`
- 起動から bootstrap 読込完了まで: `559ms`
- 起動からホーム遷移開始まで: `660ms`

### APIキーの管理方法を安全な構成へ改める

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `1.060s`
- test-without-building: `91.313s`
- 検証合計時間: `92.373s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `427ms`
- スプラッシュ表示からホーム表示まで: `129ms`
- 起動からホーム表示まで: `556ms`
- 起動から bootstrap 読込完了まで: `499ms`
- 起動からホーム遷移開始まで: `567ms`

### YouTube検索タイルとシステム情報タイルを追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.341s`
- test-without-building: `88.460s`
- 検証合計時間: `91.801s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `458ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `581ms`
- 起動から bootstrap 読込完了まで: `521ms`
- 起動からホーム遷移開始まで: `624ms`

### 固定キーワード検索導線を追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.102s`
- test-without-building: `87.466s`
- 検証合計時間: `91.568s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `621ms`
- スプラッシュ表示からホーム表示まで: `124ms`
- 起動からホーム表示まで: `745ms`
- 起動から bootstrap 読込完了まで: `685ms`
- 起動からホーム遷移開始まで: `805ms`

### 設計監査に合わせて責務境界を整理する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.274s`
- test-without-building: `77.664s`
- 検証合計時間: `80.938s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `441ms`
- スプラッシュ表示からホーム表示まで: `107ms`
- 起動からホーム表示まで: `548ms`
- 起動から bootstrap 読込完了まで: `498ms`
- 起動からホーム遷移開始まで: `557ms`

### チャンネル詳細の下スワイプを単独更新に割り当てる

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.802s`
- test-without-building: `77.807s`
- 検証合計時間: `81.609s`
- 手修正後の再試行回数: `3`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `452ms`
- スプラッシュ表示からホーム表示まで: `108ms`
- 起動からホーム表示まで: `560ms`
- 起動から bootstrap 読込完了まで: `510ms`
- 起動からホーム遷移開始まで: `597ms`

### 削除後の一覧復元とバックアップ読込を安定化する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.874s`
- test-without-building: `64.914s`
- 検証合計時間: `67.788s`
- 手修正後の再試行回数: `4`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `458ms`
- スプラッシュ表示からホーム表示まで: `120ms`
- 起動からホーム表示まで: `578ms`
- 起動から bootstrap 読込完了まで: `520ms`
- 起動からホーム遷移開始まで: `588ms`

### チャンネル削除と整合性メンテナンスを追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `2.264s`
- test-without-building: `66.536s`
- 検証合計時間: `68.800s`
- 手修正後の再試行回数: `3`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `453ms`
- スプラッシュ表示からホーム表示まで: `109ms`
- 起動からホーム表示まで: `562ms`
- 起動から bootstrap 読込完了まで: `510ms`
- 起動からホーム遷移開始まで: `607ms`

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

## 2026/03/16

### YouTube検索の2ペイン化と動画タイル情報表示を再調整する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.070s`
- test-without-building: `144.931s`
- 検証合計時間: `149.001s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `414ms`
- スプラッシュ表示からホーム表示まで: `129ms`
- 起動からホーム表示まで: `543ms`
- 起動から bootstrap 読込完了まで: `486ms`
- 起動からホーム遷移開始まで: `579ms`

### YouTube検索の再生数表示とiPadのreadable widthを是正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `5.308s`
- test-without-building: `121.441s`
- 検証合計時間: `126.749s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `435ms`
- スプラッシュ表示からホーム表示まで: `133ms`
- 起動からホーム表示まで: `568ms`
- 起動から bootstrap 読込完了まで: `509ms`
- 起動からホーム遷移開始まで: `608ms`

### チャンネル一覧の先頭にTipsタイルを追加する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.485s`
- test-without-building: `102.516s`
- 検証合計時間: `107.001s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `426ms`
- スプラッシュ表示からホーム表示まで: `125ms`
- 起動からホーム表示まで: `551ms`
- 起動から bootstrap 読込完了まで: `494ms`
- 起動からホーム遷移開始まで: `592ms`

### YouTube検索からのチャンネル遷移で必要時だけ自動更新し下部チップを操作まで維持する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.028s`
- test-without-building: `113.961s`
- 検証合計時間: `116.989s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `409ms`
- スプラッシュ表示からホーム表示まで: `122ms`
- 起動からホーム表示まで: `531ms`
- 起動から bootstrap 読込完了まで: `477ms`
- 起動からホーム遷移開始まで: `566ms`

### warningゼロのビルド検証とactor隔離設定を是正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `1.926s`
- test-without-building: `95.869s`
- 検証合計時間: `97.795s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `415ms`
- スプラッシュ表示からホーム表示まで: `123ms`
- 起動からホーム表示まで: `538ms`
- 起動から bootstrap 読込完了まで: `480ms`
- 起動からホーム遷移開始まで: `576ms`

### YouTube検索の更新をダミー発火付きUIテストで修正する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `4.231s`
- test-without-building: `93.950s`
- 検証合計時間: `98.181s`
- 手修正後の再試行回数: `1`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `449ms`
- スプラッシュ表示からホーム表示まで: `148ms`
- 起動からホーム表示まで: `597ms`
- 起動から bootstrap 読込完了まで: `519ms`
- 起動からホーム遷移開始まで: `658ms`

### MVVMとClean Architectureの依存方向を明文化して依存注入へ寄せる

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.892s`
- test-without-building: `90.993s`
- 検証合計時間: `94.885s`
- 手修正後の再試行回数: `0`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `430ms`
- スプラッシュ表示からホーム表示まで: `125ms`
- 起動からホーム表示まで: `555ms`
- 起動から bootstrap 読込完了まで: `496ms`
- 起動からホーム遷移開始まで: `593ms`

### 実装健康度バロメタを導入して責務境界を再整理する

- 種別: source
- 実行環境: `platform=iOS Simulator,name=iPhone 12 mini`
- build-for-testing: `3.947s`
- test-without-building: `95.403s`
- 検証合計時間: `99.350s`
- 手修正後の再試行回数: `2`
- 同一コマンド内の自動再試行回数: `0`
- 起動からスプラッシュ表示まで: `437ms`
- スプラッシュ表示からホーム表示まで: `126ms`
- 起動からホーム表示まで: `563ms`
- 起動から bootstrap 読込完了まで: `502ms`
- 起動からホーム遷移開始まで: `601ms`
