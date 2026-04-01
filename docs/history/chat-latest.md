## 2026/04/02
- 従来のルールで必要だった、ルール中でスクリプトの実装や、usageで自明な内容が残留していないかを調査し、削除せよ。
  - rule creation を基準に、usageだけで確定する説明や不要な実装参照を rules 群から削除した。
- Issue #44 の残り TODO として、rules 内に残っていた command 記法を usage 記法へ統一する。
  - user instruction understanding、issue detailing、PR creation、skill creation、verification の各 rule を usage 記法へ整理し、置換値説明を追加した。
- ルール生成ルール更新と、コミットルール微調整を、併せてコミットせよ。
  - ルール生成ルールへusage記法ベースのcommand記述規則を追加し、コミットルールではchat user lineの既存行縛りを外す微調整を加えた変更を同一コミット対象として整理した。
- コミットせよ。
  - コミットルールにchat user lineの `- ` 必須規則を追加し、既存のchat履歴を遡って同形式へ是正した。
- コミットせよ。
  - Issue作成ルールの明確化とissue-creationのrepo解決元変更およびbody任意化の差分をコミット対象として確定した。

## 2026/04/01
- よし完璧だ、では実行せよ。
  - docs/rules の関連文書へ、scripts の command 例を一意に展開できる形で記述すること、llm-cache は参照キー名だけを書くこと、山括弧形式の置換記法を残さないことを追加した。
