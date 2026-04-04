# Pull Request Creation Skill

この文書は、Pull Request作成・更新という 1 つのタスクだけを定義する。

## Pull Request作成・更新

- Pull Request作成・更新とは、GitHub Pull Request を新規作成し、または既存 Pull Request の title、body、assignee、base を更新して、開発シーケンスの完了条件を満たす状態へ整えるタスクである。
- この文書で使う usage 記法では、角括弧 `[...]` 内は省略可能部分を表す。
- この文書で使う usage 記法では、角括弧の外にある要素は必須であり、左から右の順にそのまま指定しなければならない。
- この文書で使う usage 記法では、山括弧 `<...>` 内は実行時に具体値へ置換して渡す値を表す。

## 実施内容

- タスク完了時は、merge 先が通常の `main` かセッション限定の main かを問わず、必ず Pull Request を作成しなければならない。
- rules や ToDo に command 例を書く場合は、次の usage で記載しなければならない。
  `./scripts/command-runner.py 'pull-request-creation' --head '<head_branch>' --title '<pull_request_title_text>' --body-file 'llm-temp/<date>-pull-request-creation-summary.md'`
    - `llm-temp/<date>-pull-request-creation-summary.md` は、Pull Request 本文ファイルである。
    - `<date>` は、`YYYYMMDD-HHMMSS` 形式でなければならない。
- `./scripts/command-runner.py 'pull-request-creation'` に渡す本文ファイルは `llm-temp/YYYYMMDD-HHMMSS-pull-request-creation-summary.md` 形式でなければならず、`Closes #{issue_number}` を含まなければならない。
- Pull Request を Project へ自動登録してはならない。
- Pull Request の body には、対応する Issue を GitHub の機能で連携クローズするため、`Closes #{issue_number}` を明記しなければならない。
- Pull Request の作成時は、Issue、ブランチ、コミット、Pull Request の対応関係が追跡できる状態にしなければならない。
- Pull Request 作成・更新に必要な項目が 1 つでも未完了なら、開発シーケンスを完了扱いにしてはならず、不足項目として列挙して停止しなければならない。
- GitHub Project に `LLM所要時間` の Number フィールドがある場合は、開発シーケンス終盤で実測した分数を対応する Issue 項目へ反映しなければならない。フィールドが無い場合は対応する skill / script で作成してから更新しなければならない。
- LLM は Issue を直接 close してはならない。

## 完了条件

- 対象タスクに対応する Pull Request が作成済みであること。
- Pull Request の base、assignee、関連付けが推測なしで解決されていること。
- Pull Request の body に `Closes #{issue_number}` が含まれ、対応 Issue と GitHub 上で連携されていること。
- Pull Request を起点に、Issue、ブランチ、コミットとの対応関係を追跡できること。
- Pull Request 作成・更新に必要な項目が未完了のまま、完了扱いにされていないこと。
- Project 自動登録禁止と Issue 直接 close 禁止が守られていること。

## 禁止事項

- Pull Request を作成せずに開発シーケンスを完了扱いにしてはならない。
- rules に Assignee 名、Project 名、固定モードのようなプロダクト固有値を持ち込んではならない。
- rules に `llm-cache` の値そのものや、文字列として送信されうる山括弧形式の置換記法を持ち込んではならない。
- Pull Request を Project へ自動登録してはならない。
- `Closes #{issue_number}` を使わずに、別表現だけで Issue 連携を済ませてはならない。
- Pull Request 作成・更新に必要な項目が未完了なのに、不足項目を列挙せず完了したと扱ってはならない。
- LLM が Issue を直接 close してはならない。
