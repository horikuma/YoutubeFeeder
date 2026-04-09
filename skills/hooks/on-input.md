# On Input Hook Skill

この文書は、入力受信時フックという 1 つの処理だけを定義する。

## 入力受信時フック

- 入力受信時フックとは、ユーザーからチャット入力を受け取った直後に、以後の全タスクより先に実行しなければならない共通前処理である。
- この処理では、開始時タイムスタンプ記録、`docs/history/chat-latest.md` へ追記するための user 用内容テキスト確定、その追記完了までをこの文書だけで判断しなければならない。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- ユーザーからチャット入力を受け取った直後は、他の処理を始める前に、次の usage で `./scripts/command-runner.py 'metrics-llm-elapsed' start` を実行しなければならない。
  `./scripts/command-runner.py 'metrics-llm-elapsed' start`
  例: `./scripts/command-runner.py 'metrics-llm-elapsed' start`
- チャット入力は、その後続タスクで参照する正本の 1 行 `user_text` へ確定しなければならない。
- 1 行の入力は、ユーザーが直接入力した指示として扱わなければならない。
- 入力に最初の改行が現れた場合は、改行より前の 1 行目をユーザー指示としてそのまま残し、最初の改行以後の全文を引用として扱わなければならない。
- 最初の改行以後以外を引用として扱うことを禁止する。
- 引用として扱う部分は、そのまま記録や再掲に使ってはならず、LLM が概要説明へ圧縮しなければならない。
- 圧縮した引用部分は、`[引用要約: ...]` の形式で、引用であることが分かる形にし、改行より前の 1 行目の末尾へ同じ行で連結する前提で扱わなければならない。
- `user_text` は、箇条書き記号を含まない 1 行のユーザー指示内容として確定しなければならない。
- `docs/history/chat-latest.md` への追記は、次の usage で `./scripts/command-runner.py 'history-chat-append'` を使わなければならない。
  `./scripts/command-runner.py 'history-chat-append' --role 'user' --text '<user_text>'[ --today '<today>']`
  例: `./scripts/command-runner.py 'history-chat-append' --role 'user' --text 'セッションを開始せよ。'`
  - `<user_text>` は、この文書で確定した 1 行のユーザー指示内容であり、省略してはならない。
  - `<today>` は、省略時は当日値が使われ、指定する場合は `YYYY/MM/DD` または `YYYY-MM-DD` 形式でなければならない。
- `docs/history/chat-latest.md` への追記は `./scripts/command-runner.py 'history-chat-append'` の成功で完了とし、LLM が本文を読んで追記位置を判断してはならない。
- 記録する文字列に個人情報、API キー、トークン、絶対パス、ホームディレクトリが含まれる場合は、除去しなければならない。

## 完了条件

- `./scripts/command-runner.py 'metrics-llm-elapsed' start` が成功していること。
- 後続タスクで参照する `user_text` が 1 行へ確定していること。
- `./scripts/command-runner.py 'history-chat-append'` が成功し、その結果が `docs/history/chat-latest.md` に反映されていること。

## 禁止事項

- この処理を、ユーザー指示の理解より後ろへ回してはならない。
- `docs/history/chat-latest.md` の本文を読んで追記位置を判断したり、LLM が直接編集したりしてはならない。
- 開始時タイムスタンプ記録を省略したまま後続タスクへ進んではならない。
- `user_text` を確定しないまま `docs/history/chat-latest.md` へ追記してはならない。
