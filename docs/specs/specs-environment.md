# SPECS_ENVIRONMENT_RULES

## INDEX

- [ENV-NODE] Node環境
- [ENV-PM] パッケージ管理
- [ENV-MERMAID] Mermaid検証
- [ENV-PATH] ファイルパスと配置
- [ENV-EXECUTION] 実行ルール
- [ENV-CONSTRAINT] 禁止事項

---

## RULES

### [ENV-NODE]

- [ENV-NODE-001][node] Node.js のバージョンは 24.14.0 を使用しなければならない
- [ENV-NODE-002][node] Node.js の版固定は .node-version と package.json の engines.node で管理しなければならない
- [ENV-NODE-003][node][forbidden] Node.js のバージョンを環境ごとに変えてはならない

---

### [ENV-PM]

- [ENV-PM-001][package-manager] パッケージマネージャは npm を使用しなければならない
- [ENV-PM-002][package-manager] 依存関係の正本は package-lock.json としなければならない
- [ENV-PM-003][package-manager][forbidden] ロックファイルを無視して依存解決してはならない

---

### [ENV-MERMAID]

- [ENV-MERMAID-001][mermaid] Mermaid のローカル検証を必須としなければならない
- [ENV-MERMAID-002][mermaid] Mermaid 検証は check-mermaid.mjs を正本としなければならない
- [ENV-MERMAID-003][mermaid][forbidden] Mermaid 検証に外部APIを使用してはならない
- [ENV-MERMAID-004][mermaid] Markdown変更時は npm run check:mermaid を実行しなければならない
- [ENV-MERMAID-005][mermaid] Mermaid検証対象は docs/ 配下および README.md としなければならない
- [ENV-MERMAID-006][mermaid] 検証失敗時は「ファイル:開始行」を出力し、そのブロック単位で修正しなければならない

---

### [ENV-PATH]

- [ENV-PATH-001][path] プロジェクト内のツールスクリプトは scripts/ 配下に配置しなければならない
- [ENV-PATH-002][path] 一時ファイルは llm-temp/ 配下に配置しなければならない
- [ENV-PATH-003][path][forbidden] 一時生成物を永続ディレクトリへ配置してはならない

---

### [ENV-EXECUTION]

- [ENV-EXECUTION-001][execution] コマンド実行は scripts/command-runner.py 経由で行わなければならない
- [ENV-EXECUTION-002][execution] 実行結果はログとして取得できなければならない
- [ENV-EXECUTION-003][execution][forbidden] 直接コマンド実行で状態を不透明にしてはならない

---

### [ENV-CONSTRAINT]

- [ENV-CONSTRAINT-001][forbidden] 環境依存の設定をローカルに埋め込んではならない
- [ENV-CONSTRAINT-002][forbidden] 再現性のない実行手順を許容してはならない
- [ENV-CONSTRAINT-003][forbidden] 検証手順を省略してはならない