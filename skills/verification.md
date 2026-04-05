# Verification Skill

この文書は、検証という 1 つのタスクだけを定義する。

## 検証

- 検証とは、変更内容に応じたテストと build 確認を実施し、変更結果が要求どおりに成立していることを確認するタスクである。
- このタスクでは、検証対象の選定、テスト実行、build 確認、再確認の絞込み、最終全体確認までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- 検証では、変更内容に応じたテストと build 確認を行い、`error 0` かつ `warning 0` を確認しなければならない。
- 検証が最初の 1 回で通らなかった場合は、修正ループ中の再確認を関連テストと影響が及ぶはずのテストへ限定し、それらが通った後で最後に全体テストを実行しなければならない。
- 最終の全体テストでは、次の usage で `./scripts/command-runner.py 'metrics-collect'` を使って build 時間、全体 test 時間、起動性能、`docs/metrics/metrics-test.md` を同じ 1 回の全体実行から取得しなければならない。
  `./scripts/command-runner.py 'metrics-collect' --label '<label>'[ --change-kind '<change_kind>'][ --manual-retries '<manual_retries>'][ --auto-retry-limit '<auto_retry_limit>']`
    - `<label>` は、計測結果へ残すラベルであり、省略してはならない。
- 最終の全体テスト規定を書く時は、前項の usage に加えて、例えば `./scripts/command-runner.py 'metrics-collect' --label 'Issue57 verification' --change-kind 'docs'` のような具体的な command 例文も記載しなければならない。
- 最終の全体テストを、別スクリプトで重複実行してはならない。
- `tools`、`skills`、`scripts` だけを変更した場合は、アプリ本体の build や test は実施せず、対象ツールの構文確認と代表的な 1 経路の実行確認で検証しなければならない。
- 機能追加、不具合対応、設計変更を含む場合は、変更内容に対応するテストと build 確認を省略してはならない。

## 完了条件

- 変更内容に応じたテストと build 確認が完了していること。
- 最終確認で `error 0` かつ `warning 0` を確認していること。
- 再確認が必要な場合は、関連テストへの限定確認と最終全体確認を順に実施していること。
- `tools`、`skills`、`scripts` だけの変更では、対象ツールの構文確認と代表実行確認が完了していること。

## 禁止事項

- 変更内容に対応する検証を省略したまま完了扱いにしてはならない。
- 修正ループ中に毎回全体テストを重複実行してはならない。
- `scripts/command-runner.py 'metrics-collect'` を使うべき最終全体確認を別手段で代替してはならない。
- `tools`、`skills`、`scripts` だけの変更なのに、慣習でアプリ本体の build や test を要求してはならない。
