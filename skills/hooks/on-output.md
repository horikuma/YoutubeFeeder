# On Output Hook Skill

この文書は、出力完了時フックという 1 つの処理だけを定義する。

## 出力完了時フック

- 出力完了時フックとは、応答本文の生成が完了した後、出力を確定する直前に必ず実行しなければならない共通後処理である。
- この処理では、`docs/history/chat-latest.md` へ追記するための assistant 用内容テキスト確定、履歴追記、終了時タイムスタンプ記録だけをこの文書で判断しなければならない。

## 実施内容

- 応答本文は、出力を確定する直前に、箇条書き記号を含まない 1 行 `assistant_text` へ確定しなければならない。
- 応答に最初の改行が現れた場合は、改行より前の 1 行目を応答内容としてそのまま残し、最初の改行以後の全文を引用として扱わなければならない。
- 引用として扱う部分は、そのまま記録や再掲に使ってはならず、LLM が概要説明へ圧縮しなければならない。
- 圧縮した引用部分は、`[引用要約: ...]` の形式で、引用であることが分かる形にし、改行より前の 1 行目の末尾へ同じ行で連結する前提で扱わなければならない。
- `docs/history/chat-latest.md` への追記は、次の usage で `./scripts/command-runner.py 'history-chat-append'` を使わなければならない。
  `./scripts/command-runner.py 'history-chat-append' --role 'assistant' --text '<assistant_text>'[ --today '<today>']`
  例: `./scripts/command-runner.py 'history-chat-append' --role 'assistant' --text 'Issue #96 の詳細化を更新しました。'`
  - `<assistant_text>` は、この文書で確定した 1 行の応答内容であり、省略してはならない。
  - `<today>` は、省略時は当日値が使われ、指定する場合は `YYYY/MM/DD` または `YYYY-MM-DD` 形式でなければならない。
- 応答を確定する直前は、その後に次の usage で `./scripts/command-runner.py 'metrics-llm-elapsed' finish` を実行しなければならない。
  `./scripts/command-runner.py 'metrics-llm-elapsed' finish`
  例: `./scripts/command-runner.py 'metrics-llm-elapsed' finish`
- この command の出力は、`LLM所要時間` の終了時記録として扱わなければならない。

## 完了条件

- `assistant_text` が 1 行へ確定していること。
- `./scripts/command-runner.py 'history-chat-append'` が成功し、その結果が `docs/history/chat-latest.md` に反映されていること。
- `./scripts/command-runner.py 'metrics-llm-elapsed' finish` が成功していること。

## 禁止事項

- `assistant_text` を確定しないまま `docs/history/chat-latest.md` へ追記してはならない。
- `./scripts/command-runner.py 'history-chat-append'` を実行せずに応答を終了してはならない。
- 終了時タイムスタンプ記録を行わずに応答を終了してはならない。
- 応答の確定後に `./scripts/command-runner.py 'metrics-llm-elapsed' finish` を実行してはならない。
