# SPECS_DESIGN_RULES

## INDEX

- [DESIGN-PROJECT] Project設定
- [DESIGN-APP] App層
- [DESIGN-HOME] Home機能
- [DESIGN-BROWSE] Browse機能
- [DESIGN-FEEDCACHE] FeedCache機能
- [DESIGN-INFRA] Infrastructure
- [DESIGN-SHARED] Shared
- [DESIGN-STATE] 状態管理
- [DESIGN-ACTION] アクション設計
- [DESIGN-NAMING] 命名規則
- [DESIGN-TEST] テスト配置
- [DESIGN-CONSTRAINT] 禁止事項

---

## RULES

### [DESIGN-PROJECT]

- [DESIGN-PROJECT-001][build] iOS deployment target は 16.0 を維持しなければならない
- [DESIGN-PROJECT-002][bundle] bundle identifier は統一しなければならない
- [DESIGN-PROJECT-003][signing] 自動署名を前提としなければならない
- [DESIGN-PROJECT-004][rebuild] ビルド不整合時は DerivedData を再生成しなければならない

---

### [DESIGN-APP]

- [DESIGN-APP-001][app] Appはcomposition rootでなければならない
- [DESIGN-APP-002][app] dependencyはAppで組み立てなければならない
- [DESIGN-APP-003][app] ルート遷移はApp層で管理しなければならない
- [DESIGN-APP-004][app][forbidden] 下位層で依存生成してはならない

---

### [DESIGN-HOME]

- [DESIGN-HOME-001][home] ホームの非同期処理はViewModelに置かなければならない
- [DESIGN-HOME-002][home] UIはViewに限定しなければならない
- [DESIGN-HOME-003][home] pure logicはfeature配下に置かなければならない
- [DESIGN-HOME-004][home][forbidden] Viewが処理を持ってはならない

---

### [DESIGN-BROWSE]

- [DESIGN-BROWSE-001][browse] 一覧と詳細は責務分離しなければならない
- [DESIGN-BROWSE-002][browse] split状態はViewModelで管理しなければならない
- [DESIGN-BROWSE-003][browse] UIは表示写像に限定しなければならない
- [DESIGN-BROWSE-004][browse] 検索と閲覧は分離しなければならない
- [DESIGN-BROWSE-005][browse][forbidden] UIに状態遷移を持たせてはならない

---

### [DESIGN-FEEDCACHE]

- [DESIGN-FEEDCACHE-001][feedcache] Coordinatorは入口としてのみ機能しなければならない
- [DESIGN-FEEDCACHE-002][feedcache] ReadとWriteは分離しなければならない
- [DESIGN-FEEDCACHE-003][feedcache] 書き込みはWriteService経由でなければならない
- [DESIGN-FEEDCACHE-004][feedcache][forbidden] ReadとWriteの循環依存を作ってはならない
- [DESIGN-FEEDCACHE-005][feedcache] 更新処理は単一責務で完結しなければならない
- [DESIGN-FEEDCACHE-006][feedcache][forbidden] 内部ループで更新を継続してはならない

---

### [DESIGN-INFRA]

- [DESIGN-INFRA-001][infra] 外部通信はInfrastructureに閉じ込めなければならない
- [DESIGN-INFRA-002][infra] API処理と整形は分離しなければならない
- [DESIGN-INFRA-003][infra][forbidden] UI層から直接APIを呼んではならない

---

### [DESIGN-SHARED]

- [DESIGN-SHARED-001][shared] Sharedはpure logicのみを持たなければならない
- [DESIGN-SHARED-002][shared][forbidden] Sharedに状態を持たせてはならない
- [DESIGN-SHARED-003][shared] 再利用可能なポリシーのみ配置しなければならない

---

### [DESIGN-STATE]

- [DESIGN-STATE-001][state] 画面状態はViewModelに集約しなければならない
- [DESIGN-STATE-002][state] presentation stateはfeature内に閉じなければならない
- [DESIGN-STATE-003][state][forbidden] 状態を複数層に分散してはならない

---

### [DESIGN-ACTION]

- [DESIGN-ACTION-001][action] アクションはドメイン単位で定義しなければならない
- [DESIGN-ACTION-002][action] UIイベントはアダプタとして扱わなければならない
- [DESIGN-ACTION-003][action][forbidden] UIイベント単位の共通処理を作ってはならない

---

### [DESIGN-NAMING]

- [DESIGN-NAMING-001][naming] ViewはViewで終わらなければならない
- [DESIGN-NAMING-002][naming] 機能名を先に置かなければならない
- [DESIGN-NAMING-003][naming] 操作差分は後置しなければならない
- [DESIGN-NAMING-004][naming] 同一責務は同一命名でなければならない

---

### [DESIGN-TEST]

- [DESIGN-TEST-001][test] UI非依存ロジックはunit testで検証しなければならない
- [DESIGN-TEST-002][test] UI依存部分はUI testで検証しなければならない
- [DESIGN-TEST-003][test] ロジックを先に固定しなければならない
- [DESIGN-TEST-004][test][forbidden] UIから直接ロジックを検証してはならない

---

### [DESIGN-CONSTRAINT]

- [DESIGN-CONSTRAINT-001][forbidden] Viewに非同期処理を戻してはならない
- [DESIGN-CONSTRAINT-002][forbidden] Coordinatorに画面状態を持たせてはならない
- [DESIGN-CONSTRAINT-003][forbidden] Sharedにfeature依存を持たせてはならない
- [DESIGN-CONSTRAINT-004][forbidden] 責務境界をまたぐ変更を行ってはならない