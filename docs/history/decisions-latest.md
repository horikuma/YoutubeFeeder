## 2026/04/10
- main最新化は git-main-sync へ集約し、ahead / diverged 時は origin/main との共通祖先 commit へ戻してから pull --ff-only する。
  - LLM が手作業の Git 分岐解釈へ逃げず、終了コードだけで成功可否と失敗モードを判定できるようにするため。
- セッション開始から merged ブランチ削除責務を外し、終了時の main 最新化とローカルブランチ掃除は session-end skill へ分離する。
  - 開始時の基準状態整備と終了時の後片付けを分離し、どの skill がどの Git 操作を担うかを曖昧にしないため。
