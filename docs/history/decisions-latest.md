## 2026/04/05
- command 実装の _meta.json と Python 実装は skills 配下ではなく scripts/<group>/ 配下を正本とする。
  - scripts 直下 shell 入口、_meta.json、Python 実装の実配置を一致させることで、参照更新の範囲を局所化し、wrapper と実装の解決経路を同じ親ディレクトリ配下へ閉じ込められるため。
- Issue45で残存するrules task定義をskillsへ分離しdocs/rulesは導線のみへ統一した。
  - rules-session-startの分離パターンを残る12本へ適用し、ruleとskillの責務境界を揃えるため。
