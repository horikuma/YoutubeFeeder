# SPECS_RULES

## INDEX

- [RULE-RETRY] 試行回数制約
- [RULE-ROLE] 人間とLLMの役割分担
- [RULE-DESIGN] ルール設計思想
- [RULE-CONSTRAINT] 運用制約

---

## RULES

### [RULE-RETRY]

- [RULE-RETRY-001][retry] 試行回数制約はコスト制御のために存在しなければならない
- [RULE-RETRY-002][retry] 試行回数は 3回 または 4回 を上限としなければならない
- [RULE-RETRY-003][retry] 試行回数制約は品質ではなくコスト制御として扱わなければならない
- [RULE-RETRY-004][retry][forbidden] 無制限の再試行を許容してはならない
- [RULE-RETRY-005][retry][forbidden] 試行→修正→再試行のループを前提に設計してはならない

---

### [RULE-ROLE]

- [RULE-ROLE-001][llm] LLM はルールを逐次適用しなければならない
- [RULE-ROLE-002][llm] LLM は違反を検出しなければならない
- [RULE-ROLE-003][llm] LLM は試行回数制約を厳格に守らなければならない

- [RULE-ROLE-004][human] 人間はルールを逐次適用してはならない
- [RULE-ROLE-005][human] 人間は違反検出後に修正しなければならない
- [RULE-ROLE-006][human] 人間は構造理解をルール遵守より優先しなければならない

---

### [RULE-DESIGN]

- [RULE-DESIGN-001][design] ルールはLLMに適用させる前提で設計しなければならない
- [RULE-DESIGN-002][design] 人間は逸脱検知後の修正に集中しなければならない
- [RULE-DESIGN-003][design] ルールは逐次制約ではなく検出センサーとして扱わなければならない
- [RULE-DESIGN-004][design] ルールは実運用上の制約に基づいて定義しなければならない

---

### [RULE-CONSTRAINT]

- [RULE-CONSTRAINT-001][constraint] LLMは機械的制約適用に強い前提で設計しなければならない
- [RULE-CONSTRAINT-002][constraint] 人間は意味理解と優先順位判断に強い前提で設計しなければならない
- [RULE-CONSTRAINT-003][constraint][forbidden] 人間に全ルールの常時適用を要求してはならない