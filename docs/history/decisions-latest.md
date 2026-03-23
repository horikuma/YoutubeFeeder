## 2026/03/23
- rules 文書はプロダクト固有語を持ち込まず、プロダクト前提や端末前提は `architecture.md` へ寄せる方針にした。
  - rules は文書・フロー・tools の抽象ルールを扱い、プロダクト依存の設計判断や機能文脈を混ぜない方が、別種のプロダクトでも再利用できる判断基準として保ちやすいため。
- GitHub Issue 取得は `scripts/list-issues` から `skills/github/list-issues.sh` を呼ぶ薄いラッパー構成に統一する方針にした。
  - 利用者の入口を `scripts/` に固定しつつ、認証・JWT 発行・installation token 取得・Issue 取得の本体は `skills/` へ閉じ込めた方が、rules-skills の責務分離に沿って保守しやすいため。
