## 2026/03/23
- `skills/github/list-issues` を `PyGithub` ベースへ作り替え、`scripts/list-issues` の薄いラッパー経由で Issue を取得できる状態を維持せよ。あわせて、`tools` / `skills` / `scripts` だけを変更した時はアプリ本体の build / test を行わない旨をルールへ追加し、そのルールどおり tool の構文確認と代表経路の実行確認だけで検証せよ。(LLM所要時間: 未測定)
- rules 文書をプロダクト非依存に整理し、rules と architecture の役割分担、参照順、文書配置判断を見直せ。また、`skills/github/list-issues` を追加し、`scripts/list-issues` 経由で Issue を取得できるようにせよ。ローカル秘密情報の具体内容は記録しない。(LLM所要時間: 未測定)
