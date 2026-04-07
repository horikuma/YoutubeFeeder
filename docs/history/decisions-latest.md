## 2026/04/08
- basic GUI の route switch と画面 presentation 選択を BasicGUIComposition へ移す。
  - ContentView と Browse 親 View から route / layout 判定を外し、basic GUI の組み立て責務を 1 箇所に寄せるため。
- basic GUI の route と layout の責務境界を BasicGUIComposition で固定する。
  - ContentView と各親 View に散っていた境界判定を pure logic として先に固定し、後続の composition 置換を追加推論なしで進めるため。
- `skills/commit.md` はコミット実行責務へ絞り、前段のチャット入力解釈と `chat-latest` の責務は別スキルへ分離する方針にした。
  - ToDo完了ごとのコミットでも使う後段タスクなので、ユーザー指示起点の万能ハブとして読める状態を解消するため。
