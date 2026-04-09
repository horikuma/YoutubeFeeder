# Session End Skill

この文書は、開発セッション終了という 1 つのタスクだけを定義する。

## タスク定義

- セッション終了とは、作業完了後の基準状態を整えるタスクである。
- ブランチに関しては、現在の作業ブランチから `main` へ checkout し、その `main` を最新化した後、`git branch -d` で fully merged な local branch を掃除することだけを目的とする。
- セッション終了におけるブランチ解釈は上記のみとし、`main` 以外を終了時の基準ブランチとして扱ってはならない。
- merged な local branch 掃除では、次の command だけを正規手順として使わなければならない。
  `git branch -d <branch_name>`
  例: `git branch -d issue-80`
  - `<branch_name>` は、`main` 以外の local branch のうち、`git branch -d` で削除できる fully merged branch 名でなければならない。
- セッション終了タスクは、次の 3 条件を満たした時だけ完了とみなす。

## 完了条件

- `main` へ checkout したうえで、その `main` が最新化されていること。
- `main` の最新化後に、`git branch -d` で削除できる `main` 以外の local branch の掃除が完了していること。
- 上記 2 条件の結果として、終了時の基準ブランチが `main` になっていること。

## 禁止事項

- 上記 2 条件以外の作業を、この文書の対象へ含めてはならない。
- `main` 以外のブランチを、セッション終了時の基準ブランチとして扱ってはならない。
- `git branch -D` や、`git branch -d` で削除できない local branch の強制削除をセッション終了へ含めてはならない。
- ローカルブランチ掃除で、`git branch -d` 以外の方法を正規手順として扱ってはならない。
