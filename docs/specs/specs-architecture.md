# SPECS_ARCHITECTURE_RULES

## INDEX

- [ARCH-BASE] プロダクト前提
- [ARCH-MODEL] 採用アーキテクチャ
- [ARCH-LAYER] レイヤ責務と依存方向
- [ARCH-VIEW] View責務
- [ARCH-VIEWMODEL] ViewModel責務
- [ARCH-COORD] Coordinator責務
- [ARCH-SERVICE] Service/UseCase責務
- [ARCH-STORE] Store/Infrastructure責務
- [ARCH-SHARED] Shared責務
- [ARCH-FLOW] データフロー
- [ARCH-CONSTRAINT] 禁止事項

---

## RULES

### [ARCH-BASE]

- [ARCH-BASE-001][platform][ios] 本プロダクトは iOS アプリでなければならない
- [ARCH-BASE-002][performance] 起動性能と操作中の軽さを損なってはならない
- [ARCH-BASE-003][cache][source_of_truth] ローカルキャッシュを正本としなければならない
- [ARCH-BASE-004][ui][adaptive] iPhone と iPad は同一機能を提供しなければならない
- [ARCH-BASE-005][startup] 起動直後は軽量データのみで画面を成立させなければならない

---

### [ARCH-MODEL]

- [ARCH-MODEL-001][architecture] MVVM + Clean Architecture を採用しなければならない
- [ARCH-MODEL-002][abstraction] 標準フレームワークで表現可能な責務は独自抽象化してはならない
- [ARCH-MODEL-003][justification] 標準から外れる場合は理由を説明できなければならない
- [ARCH-MODEL-004][layering] 意味のある単位で分割しなければならない
- [ARCH-MODEL-005][anti-pattern] 薄い中継層や形式的な分割を増やしてはならない

---

### [ARCH-LAYER]

- [ARCH-LAYER-001][dependency] 依存方向は View → ViewModel → Coordinator → Service → Store を守らなければならない
- [ARCH-LAYER-002][dependency][forbidden] 依存方向を逆転させてはならない
- [ARCH-LAYER-003][separation] UIとI/Oは分離しなければならない

---

### [ARCH-VIEW]

- [ARCH-VIEW-001][view][responsibility] Viewは表示と入力のみを担わなければならない
- [ARCH-VIEW-002][view][forbidden] Viewは外部通信を持ってはならない
- [ARCH-VIEW-003][view][forbidden] Viewは永続化処理を持ってはならない
- [ARCH-VIEW-004][view][forbidden] Viewは非同期制御を持ってはならない
- [ARCH-VIEW-005][view][allowed] Viewは表示用状態のみを保持してよい

---

### [ARCH-VIEWMODEL]

- [ARCH-VIEWMODEL-001][viewmodel] ViewModelは画面単位の状態を管理しなければならない
- [ARCH-VIEWMODEL-002][viewmodel] ViewModelは非同期処理の起点でなければならない
- [ARCH-VIEWMODEL-003][viewmodel] ViewModelは副作用の起点でなければならない
- [ARCH-VIEWMODEL-004][viewmodel][forbidden] ViewModelは低レイヤ詳細を持ってはならない
- [ARCH-VIEWMODEL-005][viewmodel][scope] ViewModelは1画面責務に限定しなければならない

---

### [ARCH-COORD]

- [ARCH-COORD-001][coordinator] Coordinatorは複数画面で共有される状態のみを持たなければならない
- [ARCH-COORD-002][coordinator][forbidden] Coordinatorは画面固有状態を持ってはならない
- [ARCH-COORD-003][coordinator] CoordinatorはServiceの入口でなければならない

---

### [ARCH-SERVICE]

- [ARCH-SERVICE-001][service] ServiceはUI非依存のロジックを持たなければならない
- [ARCH-SERVICE-002][service] Serviceは状態遷移と処理を担わなければならない
- [ARCH-SERVICE-003][service][forbidden] ServiceはUI状態を持ってはならない

---

### [ARCH-STORE]

- [ARCH-STORE-001][store] Storeは永続化と外部接続のみを担わなければならない
- [ARCH-STORE-002][store] 外部API通信はStoreまたはInfrastructureに閉じ込めなければならない
- [ARCH-STORE-003][store][forbidden] 上位レイヤが直接外部I/Oを持ってはならない

---

### [ARCH-SHARED]

- [ARCH-SHARED-001][shared] Sharedには画面非依存ロジックのみを置かなければならない
- [ARCH-SHARED-002][shared][forbidden] Sharedに画面固有状態を置いてはならない

---

### [ARCH-FLOW]

- [ARCH-FLOW-001][startup] 初期表示と重い処理は分離しなければならない
- [ARCH-FLOW-002][update] 更新処理は単一パイプラインで実行しなければならない
- [ARCH-FLOW-003][update][forbidden] UIが更新ロジックを決定してはならない
- [ARCH-FLOW-004][search] 外部検索はキャッシュと再取得を分離しなければならない
- [ARCH-FLOW-005][search] 検索結果は正規化されなければならない

---

### [ARCH-CONSTRAINT]

- [ARCH-CONSTRAINT-001][forbidden] UI層に副作用を持たせてはならない
- [ARCH-CONSTRAINT-002][forbidden] 依存方向を曖昧にしてはならない
- [ARCH-CONSTRAINT-003][forbidden] 循環依存を作ってはならない
- [ARCH-CONSTRAINT-004][forbidden] 責務境界を越えた状態保持をしてはならない
- [ARCH-CONSTRAINT-005][forbidden] 同一責務を複数箇所に分散させてはならない