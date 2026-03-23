## 2026/03/23
- Issue #5 に従って実施せよ。Issue を `Todo` から `Inprogress` に上げ、ブランチを作成し、進捗ごとに変更があればコミットせよ。完了したら Pull Request を発行し、Issue を `Done` にせよ。実施不能なら Issue コメントで理由と状況を説明して中断せよ。さらに、このプロセスをルールへ追加せよ。(LLM所要時間: 未測定)
- issue #5 を読み込み、Description を詳細化して書き込めるよう、GitHub skill を「読む / 更新する」まで拡張せよ。責務は細かく砕きすぎず、共有 App 認証モジュールと Issue 読み書きコマンド群にまとめ、`scripts/` ラッパー経由で使えるようにせよ。tools-only 変更のため、アプリ本体の build / test は行わず、tool の構文確認と代表経路実行で検証せよ。(LLM所要時間: 未測定)
- `skills/github/list-issues` を `PyGithub` ベースへ作り替え、`scripts/list-issues` の薄いラッパー経由で Issue を取得できる状態を維持せよ。あわせて、`tools` / `skills` / `scripts` だけを変更した時はアプリ本体の build / test を行わない旨をルールへ追加し、そのルールどおり tool の構文確認と代表経路の実行確認だけで検証せよ。(LLM所要時間: 未測定)
- rules 文書をプロダクト非依存に整理し、rules と architecture の役割分担、参照順、文書配置判断を見直せ。また、`skills/github/list-issues` を追加し、`scripts/list-issues` 経由で Issue を取得できるようにせよ。ローカル秘密情報の具体内容は記録しない。(LLM所要時間: 未測定)
