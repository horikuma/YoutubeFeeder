# Pull Request Creation Rules

この文書は、Pull Request作成・更新タスクを単体で定義する完結文書である。

## Pull Request作成・更新

- Pull Request作成・更新とは、GitHub Pull Request を新規作成し、または既存 Pull Request の title、body、assignee、base を更新して、開発シーケンスの完了条件を満たす状態へ整えるタスクである。

## 実施内容

- タスク完了時は、merge 先が通常の `main` かセッション限定の main かを問わず、必ず Pull Request を作成しなければならない。
- Pull Request の既定 Assignee は `llm-cache/` 配下の local cache を正本として参照しなければならない。必要項目が無い時は処理を中断し、ユーザーへ確認しなければならない。推測で補完してはならない。
- Pull Request の Assignee は rules へ直書きしてはならず、`llm-cache/` と secrets から解決しなければならない。
- Pull Request の base は `llm-cache/session-context.json` に保持された session main を参照して決めなければならない。
- GitHub 操作モードは secrets の `operationMode` で解決しなければならない。rules に固定モードを書いてはならない。
- `user` モードでは、Pull Request の repo 操作は GitHub App で行わなければならず、Projects 操作は `gh` で行わなければならない。
- `organization` モードでは、Pull Request の repo 操作も Projects 操作も GitHub App で行わなければならない。
- Pull Request の Assignee は `llm-cache/` と secrets から解決した値で設定しなければならない。
- Pull Request を Project へ自動登録してはならない。
- Pull Request の body には、対応する Issue を GitHub の機能で連携クローズするため、`Closes #(Issue番号)` を明記しなければならない。
- Pull Request の作成時は、Issue、ブランチ、コミット、Pull Request の対応関係が追跡できる状態にしなければならない。
- GitHub Project に `LLM所要時間` の Number フィールドがある場合は、開発シーケンス終盤で実測した分数を対応する Issue 項目へ反映しなければならない。フィールドが無い場合は対応する skill / script で作成してから更新しなければならない。
- LLM は Issue を直接 close してはならない。

## 完了条件

- 対象タスクに対応する Pull Request が作成済みであること。
- Pull Request の base、assignee、関連付けが推測なしで解決されていること。
- Pull Request の body に `Closes #(Issue番号)` が含まれ、対応 Issue と GitHub 上で連携されていること。
- Pull Request を起点に、Issue、ブランチ、コミットとの対応関係を追跡できること。
- Project 自動登録禁止と Issue 直接 close 禁止が守られていること。

## 禁止事項

- Pull Request を作成せずに開発シーケンスを完了扱いにしてはならない。
- Pull Request の Assignee、base、操作モード、その他の外部メタデータを推測で補完してはならない。
- rules に Assignee 名、Project 名、固定モードのようなプロダクト固有値を持ち込んではならない。
- Pull Request を Project へ自動登録してはならない。
- `Closes #(Issue番号)` を使わずに、別表現だけで Issue 連携を済ませてはならない。
- LLM が Issue を直接 close してはならない。
