# SPECS_ENTRY_RULES

## INDEX

- [ENTRY-COLLECTION] specsコレクション構成
- [ENTRY-ORDER] 参照順
- [ENTRY-PRINCIPLE] 運用原則
- [ENTRY-CONSTRAINT] 禁止事項

---

## LOOKUP

- [LOOKUP-CLASSIFY-001][lookup] ユーザー指示は「機能」「画面」「型」「レイヤ」「環境」のいずれかに分類しなければならない
- [LOOKUP-CLASSIFY-002][lookup] 分類に応じて参照対象の specs 文書を次のように決定しなければならない
  - 機能 / 画面 → specs-product.md
  - レイヤ → specs-architecture.md
  - 型 / ファイル / テスト → specs-design.md
  - 環境 / 実行 / 検証 → specs-environment.md

- [LOOKUP-SECTION-001][lookup] 参照対象文書では INDEX のセクション単位で探索しなければならない
- [LOOKUP-SECTION-002][lookup] セクションは「変更対象に直接対応するもの」のみ選択しなければならない
- [LOOKUP-SECTION-003][lookup][forbidden] 文書全体を通読してはならない

- [LOOKUP-RULE-001][lookup] セクション内では ID付きルール（PROD-XXX-YYY / ARCH-XXX-YYY 等）単位で抽出しなければならない
- [LOOKUP-RULE-002][lookup] 抽出対象は「〜しなければならない」「〜してはならない」の行に限定しなければならない
- [LOOKUP-RULE-003][lookup][forbidden] 背景説明、例示、補足説明を含めてはならない

- [LOOKUP-OUTPUT-001][lookup] 抽出結果はルールIDの集合として保持しなければならない
- [LOOKUP-OUTPUT-002][lookup] 後続処理ではルールIDに基づいて拘束を適用しなければならない

---

## RULES

### [ENTRY-COLLECTION]

- [ENTRY-COLLECTION-001][collection] specs は product / architecture / design / environment の4文書で構成しなければならない
- [ENTRY-COLLECTION-002][collection] 各文書は役割ごとに分離しなければならない
- [ENTRY-COLLECTION-003][collection] specs.md はコレクションの入口として扱わなければならない

---

### [ENTRY-ORDER]

- [ENTRY-ORDER-001][order] 機能追加や画面仕様変更時は product を最初に参照しなければならない
- [ENTRY-ORDER-002][order] 設計整理や責務分割時は architecture を参照しなければならない
- [ENTRY-ORDER-003][order] 実装箇所や型責務確認時は design を参照しなければならない
- [ENTRY-ORDER-004][order] 環境や検証手順確認時は environment を参照しなければならない

---

### [ENTRY-PRINCIPLE]

- [ENTRY-PRINCIPLE-001][principle] specs.md は索引としてのみ機能させなければならない
- [ENTRY-PRINCIPLE-002][principle] 仕様本文を specs.md に記載してはならない
- [ENTRY-PRINCIPLE-003][principle] 機能仕様・設計・詳細設計は対応文書へ分離しなければならない
- [ENTRY-PRINCIPLE-004][principle] 環境仕様は environment 文書へ分離しなければならない

---

### [ENTRY-CONSTRAINT]

- [ENTRY-CONSTRAINT-001][forbidden] specs.md に詳細仕様を混在させてはならない
- [ENTRY-CONSTRAINT-002][forbidden] 文書間で役割の重複を作ってはならない
- [ENTRY-CONSTRAINT-003][constraint] コレクション再編時は specs.md の役割定義を最初に更新しなければならない