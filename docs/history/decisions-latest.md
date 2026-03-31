## 2026/03/31
- GitHub App 設定の正本は llm-cache/github-app.json とし、owner/title は repo から補完できるため config から除外する。
  - github-app.py と issue-defaults.py の参照条件を読めば、現行 user mode で必要なのは operationMode、appId、privateKeyPath、projectNumber、projectId までと一意に確定できるため。
- Issue詳細化では判定基準を先行 ToDo で確定し、評価語だけの ToDo を禁止する。
  - 新しいスレッドでも同じ Issue コメントと明示済み読取り対象だけで着手できるようにし、監査可能な ToDo 粒度を維持するため。
