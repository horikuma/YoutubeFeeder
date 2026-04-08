# On Output Hook Skill

この文書は、出力完了時フックという 1 つの処理だけを定義する。

## 出力完了時フック

- 出力完了時フックとは、応答本文の生成が完了した後、出力を確定する直前に必ず実行しなければならない共通後処理である。
- この処理では、終了時タイムスタンプ記録だけをこの文書で判断しなければならない。

## 実施内容

- 応答を確定する直前は、次の usage で `./scripts/command-runner.py 'metrics-llm-elapsed' finish` を実行しなければならない。
  `./scripts/command-runner.py 'metrics-llm-elapsed' finish`
  例: `./scripts/command-runner.py 'metrics-llm-elapsed' finish`
- この command の出力は、`LLM所要時間` の終了時記録として扱わなければならない。

## 完了条件

- `./scripts/command-runner.py 'metrics-llm-elapsed' finish` が成功していること。

## 禁止事項

- 終了時タイムスタンプ記録を行わずに応答を終了してはならない。
- 応答の確定後に `./scripts/command-runner.py 'metrics-llm-elapsed' finish` を実行してはならない。
