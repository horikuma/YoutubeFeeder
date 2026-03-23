## 2026/03/23
- GitHub Issue 取得 skill は、直接 REST を組み立てる shell ではなく、skill 内部で依存を閉じ込めた `PyGithub` ベースへ寄せる方針にした。
  - GitHub App 認証、installation token 取得、Issue 一覧取得の責務を Python 側へ集約した方が、API 契約の変化やページング処理に追随しやすく、`scripts` からは薄い入口を保ちやすいため。
- `tools`、`skills`、`scripts` だけを変更した場合は、アプリ本体の build / test を実施せず、対象ツールの構文確認と代表 1 経路の実行確認で検証する方針にした。
  - アプリ本体と無関係な変更まで毎回 Xcode build / test を要求すると検証コストが過剰になり、変更内容と検証内容の対応も崩れやすいため。tool 変更では tool 自身の契約に直結する確認へ絞る。
- rules 文書はプロダクト固有語を持ち込まず、プロダクト前提や端末前提は `architecture.md` へ寄せる方針にした。
  - rules は文書・フロー・tools の抽象ルールを扱い、プロダクト依存の設計判断や機能文脈を混ぜない方が、別種のプロダクトでも再利用できる判断基準として保ちやすいため。
- GitHub Issue 取得は `scripts/list-issues` から `skills/github/list-issues.sh` を呼ぶ薄いラッパー構成に統一する方針にした。
  - 利用者の入口を `scripts/` に固定しつつ、認証・JWT 発行・installation token 取得・Issue 取得の本体は `skills/` へ閉じ込めた方が、rules-skills の責務分離に沿って保守しやすいため。
