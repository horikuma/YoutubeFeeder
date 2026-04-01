## 2026/04/02
- issue-creationはrepo未指定時にissue-defaults cacheのrepoを参照し、Issue作成ルールはusage記法とIssue Descriptionファイル生成規則だけで判断できる形に整理する。
  - Issue作成時の入力解決とDescription扱いをルール本文だけで一意に判断できるようにし、環境変数やスクリプト実装読解への依存を減らすため。

## 2026/04/01
- rules の command 例は、そのまま実行できる形に一意に展開できる {variable} 記法で記述し、llm-cache は参照キー名だけを書く。
  - プロジェクト固有値の露出を避けつつ、後続スレッドの LLM が scripts と llm-temp の制約を推測なしで再現できるようにするため。
