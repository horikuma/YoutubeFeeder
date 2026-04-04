# Issue Creation Skill

この文書は、Issue作成という 1 つのタスクだけを定義する。

## Issue作成

- Issue作成とは、GitHub Issue を新規作成するタスクである。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- GitHub Issue を 1 件新規作成しなければならない。
  `./scripts/issue-creation --title '<title>' --body-file 'llm-temp/<date>-issue-creation-description.md'`
    - `<title>` がユーザ指示に存在しない場合は、処理を中断しなければならない。
    - `llm-temp/<date>-issue-creation-description.md` は、Issue Description ファイルとして常に生成し、指定しなければならない。
    - ユーザが Issue Description を出力せよと指示した場合は、その指示内容を Issue Description として `llm-temp/<date>-issue-creation-description.md` へ出力しなければならない。
    - ユーザが Issue Description を出力せよと指示していない場合は、空ファイルを `llm-temp/<date>-issue-creation-description.md` に生成しなければならない。
    - `<date>` は、`YYYYMMDD-HHMMSS` 形式でなければならない。

## 完了条件

- `./scripts/issue-creation` の戻り値が 0 であれば、このルールで要求される要件を満たしたものとみなす。

## 禁止事項

- `./scripts/issue-creation` のスクリプト仕様を読み込んではならない。
- `./scripts/issue-creation` は、このルール中で指定された使用方法だけを用いなければならない。
