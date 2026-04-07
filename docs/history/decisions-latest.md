## 2026/04/07
- Issue実施タスクは skills/issue-execution.md を正本skillとし、rulesでは Issue実施 / Issueを実施する / 実施する の導線を同じskillへ向ける。
  - 詳細化済みIssueの1 ToDoごとの実施手順を、rulesの参照導線だけで一意に開ける状態にするため。
- docs/rules.mdのIssue実施タスク参照導線には、エイリアスとして Issueを実施する と 実施する を併記する。
  - rules参照時にIssue実施タスクの呼び方を固定し、表記揺れによる解釈差を避けるため。
- metrics scripts は固定 simulator 名ではなく、導入済み最新 runtime 上の優先 simulator を解決して使う。
  - Xcode / Simulator 更新で固定 destination が壊れても Issue 検証を継続できるようにするため。
- UI testのrefresh補助導線は維持しつつ、擬似Mac判定だけをAppInteractionPlatformから除去する。
  - test.remoteSearch.refreshは不安定なpull-to-refresh回避用であり、YOUTUBEFEEDER_UI_TEST_INTERACTION_PLATFORMによる擬似Mac分岐とは責務が異なるため。
