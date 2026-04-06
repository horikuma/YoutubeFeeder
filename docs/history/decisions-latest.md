## 2026/04/07
- UI testのrefresh補助導線は維持しつつ、擬似Mac判定だけをAppInteractionPlatformから除去する。
  - test.remoteSearch.refreshは不安定なpull-to-refresh回避用であり、YOUTUBEFEEDER_UI_TEST_INTERACTION_PLATFORMによる擬似Mac分岐とは責務が異なるため。
