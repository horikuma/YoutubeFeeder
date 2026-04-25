## 2026/04/24

## 2026/04/23

## 2026/04/22

## 2026/04/19
- Source View の言語別コマンドを explorer context の専用サブメニュー配下へ整理し、SourceViewとPipelineの分離構造を文書化する。
  - 右クリックメニューの表示を簡潔にし、現状の表示系統と拡張方向を追跡できるようにするため。
- VSCode拡張の連結ビューをSourceViewAdapterへ集約し、言語追加を設定追加で拡張できる構造へ整理する。
  - 言語別ProviderとAdapterの重複を減らし、今後のファイル構成拡張を容易にするため。
- VSCode拡張にSwiftファイル連結ビューを追加し、TS/Swiftの連結処理をProviderとAdapterへ分離する。
  - 言語別のglobと表示ヘッダを分離し、連結ビューを拡張しやすくするため。
- VSCode拡張にtsconcat仮想ドキュメントでTypeScriptファイルをまとめて表示する機能を追加する。
  - エディタ上で複数のTypeScriptファイル内容を単一ビューとして確認できるようにするため。
- Issue実施のコミットメッセージ先頭にIssueToDo番号を付ける。
  - コミット履歴からIssueToDo単位の対応を追跡できる状態を保つため。
- issue-todoチェックにGitHub不調時のローカルfallback可否を追加する。
  - GitHub同期失敗時の作業継続条件を実装とルールで一致させるため。

## 2026/04/18
- UIテスト起動時は専用の一時FeedCacheディレクトリを必ず使う。
  - 常用アプリのキャッシュやチャンネル登録情報をfixture seedや削除処理から保護するため。
- 動画一覧画面の動画タイル通常クリックは動画を開く。
  - ユーザー指示により、チャンネル遷移ではなく動画オープンを主アクションにするため。
- チャンネル詳細画面は詳細だけを閉じる操作を持つ。
  - チャンネル一覧の右ペイン相当の表示を、一覧常時表示ではなく単独詳細として閉じられるようにするため。
- Macの動画タイルは通常クリックで動画を開き、メニューは右クリックで開く。
  - ユーザー指示により、左クリックを主アクション、右クリックを補助メニューに分離するため。
- チャンネル更新間隔の最近扱い境界を7日から10日に変更する。
  - ユーザー指示により、10日以内に公開されたチャンネルを短い更新間隔の対象にするため。
- manual refresh は snapshot freshness 判定をバイパスして全チャンネルを forced fetch 対象にする。
  - ユーザー操作による更新では最低1回ネットワーク再取得を保証し、lastCheckedAt による due_channels=0 を避けるため。
- Mac版のruntimeログはXcodeコンソールとプロジェクト配下logs/youtubefeeder-runtime.logへ同一行を出力する。
  - Cloudflare同期の責務境界とIF境界を、Xcode出力だけでなく後から参照できるファイルでも追跡するため。

## 2026/04/17

## 2026/04/16

## 2026/04/15

## 2026/04/14

## 2026/04/13

## 2026/04/12

## 2026/04/11
- YouTube videos詳細応答のcontentDetailsとduration欠落をdecode許容にする。
  - 実ログでduration欠落itemが1件混入しただけで検索更新全体が古い検索キャッシュへ戻っていたため。
- design-overview.mdの依存関係メモをUI構造、判断配置、データフローへ分ける。
  - 主要構造図と同じ責務分離で読み進められるようにするため。
- classDiagramをService/Store/Model関係確認の補助資料として扱う。
  - route/layout/UI orchestrationの主説明を静的クラス依存へ戻さないため。
- compositionを画面組み立てと判断の集約単位としてdesign-overview.mdへ明記する。
  - UIクラスやService/Storeと同列の静的クラス依存として誤読されることを避けるため。
- design-overview.mdの主要図をUI構造、判断配置、データフローへ分離する。
  - 主要クラス図が異なる関心事を1図に混在させ、設計意図を追いにくくしていたため。
- Git command は command-runner の git wrapper 経由で実行する。
  - Git 操作の入口を統一し、ルール文書と scripts の実行経路を一致させるため。
- 開発ルールの正本を docs/rules.md から AGENTS.md へ移動する。
  - ユーザー指示により rules.md を削除し、history 配下を除く参照先を AGENTS.md に統一するため。
- Issue実施では issue-todo の body file を直接編集せず、同役割ファイルを新規生成せず、working tree が空ならコミットをスキップする。
  - Issue ToDo 更新経路とコミット条件を明確に固定するため。
- issue-todo command は --get で次の未完了 ToDo を返し、--check で ToDo をチェック済みにする契約へ変更する。
  - Issue実施の対象選定と終了条件を command の JSON next に一本化するため。

## 2026/04/09
- Issue100では issue-todo-check の完全一致判定を維持し、issue-read --body-only の追加入力改行だけを除去して本文再利用を成立させる。
  - 安定名の llm-temp 本文ファイル再利用という設計意図を満たしつつ、Description の厳密一致契約も崩さない最小変更だから。

## 2026/04/08
- Python観測とSwiftLint観測は別系統として併存させる。
  - health-barometerの既存観測を維持しつつ、SwiftLintはbuild時の追加観測として導入するため。
- build確認でのSwiftLint観測は専用commandとして `swiftlint lint` を明記する。
  - 実行手順を固定し、観測値の出どころを verification skill だけで辿れるようにするため。
- build確認ではSwiftLint結果を判定条件に混ぜず観測値として別枠記録する。
  - Python観測を維持したままSwiftLintを並行導入し、既存のwarning/error判定を変えないため。
- basic GUI のホーム・チャンネル一覧・YouTube検索は composition wrapper 経由で組み立てる。
  - prewarm を含む screen assembly を BasicGUIComposition に集約し、公開契約を保ったまま差し替え単位を揃えるため。
- basic GUI の route switch と画面 presentation 選択を BasicGUIComposition へ移す。
  - ContentView と Browse 親 View から route / layout 判定を外し、basic GUI の組み立て責務を 1 箇所に寄せるため。
- basic GUI の route と layout の責務境界を BasicGUIComposition で固定する。
  - ContentView と各親 View に散っていた境界判定を pure logic として先に固定し、後続の composition 置換を追加推論なしで進めるため。
- `skills/commit.md` はコミット実行責務へ絞り、前段のチャット入力解釈と `chat-latest` の責務は別スキルへ分離する方針にした。
  - ToDo完了ごとのコミットでも使う後段タスクなので、ユーザー指示起点の万能ハブとして読める状態を解消するため。

## 2026/04/07
- metrics 文書の正本は JSON に置き、Markdown は renderer で生成する。
  - build・test・startup metrics を機械処理しやすい形式へ揃えつつ既存 Markdown 出力も維持するため。
- build と startup metrics は metrics-collect、full test metrics は metrics-test-collect で分離する。
  - startup metrics のために毎回 full test suite を要求しない構成へ寄せるため。
- セッション開始では、main最新化の直後にgit fetch --pruneとgit branch -dでローカルブランチを掃除する。
  - session-start skillの正規手順として、main最新化後のブランチ掃除を固定するため。
- Issue詳細化Descriptionでは、禁止事項を連番、ToDoを本文番号付きチェックボックス箇条書きとして扱う。
  - GitHub表示とissue-todo-checkの機械処理を同じ書式へ揃えるため。
- Issue DescriptionのToDo更新は、ローカルのissue-description-update本文ファイルをissue-todo-checkが更新し、その同一ファイルでremoteへ反映する。
  - Description更新手順を1本に固定し、ToDoチェック反映のばらつきとトークン消費を減らすため。
- Issue実施指示でblockerに当たった時は、以後のIssueToDoを中断して報告する。
  - IssueToDoを最後まで直列反復する規則に、停止条件をrules側で明示するため。
- Issue実施指示では、issue-executionの1件処理を未完了IssueToDoがなくなるまで直列反復する。
  - 1 ToDoずつのskill粒度は維持しつつ、ユーザー指示単位ではIssueToDoを最後まで完了させるため。
- Issue実施タスクのrules導線は、実際に使う表現として Issueを実施する を正本に残す。
  - rules上の参照語を過不足なく保ち、ユーザーが採用した表現に合わせるため。
- Issue実施タスクは skills/issue-execution.md を正本skillとし、rulesでは Issue実施 / Issueを実施する / 実施する の導線を同じskillへ向ける。
  - 詳細化済みIssueの1 ToDoごとの実施手順を、rulesの参照導線だけで一意に開ける状態にするため。
- docs/rules.mdのIssue実施タスク参照導線には、エイリアスとして Issueを実施する と 実施する を併記する。
  - rules参照時にIssue実施タスクの呼び方を固定し、表記揺れによる解釈差を避けるため。
- metrics scripts は固定 simulator 名ではなく、導入済み最新 runtime 上の優先 simulator を解決して使う。
  - Xcode / Simulator 更新で固定 destination が壊れても Issue 検証を継続できるようにするため。
- UI testのrefresh補助導線は維持しつつ、擬似Mac判定だけをAppInteractionPlatformから除去する。
  - test.remoteSearch.refreshは不安定なpull-to-refresh回避用であり、YOUTUBEFEEDER_UI_TEST_INTERACTION_PLATFORMによる擬似Mac分岐とは責務が異なるため。

## 2026/04/06
- 擬似Mac UIテストは停止し、Mac標準操作の確認は別Issueで実機系へ分離する。
  - iPhoneシミュレータ上の疑似分岐では実ランタイム差の検証が不安定で、Issue73では実装本体を優先して確定するため。
- FeedCacheのremote search cacheはReadServiceが読取り、WriteServiceが保存・削除を担う構成に固定する。
  - ユースケースServiceからRead/Write境界への依存方向を維持し、読取り層へ副作用を残さないため。

## 2026/04/05
- FeedCacheReadServiceは読取時にfeed snapshotとremote search cacheを変化させないことをテストで固定する。
  - Read層をpureに保ち、副作用はWriteService経由へ限定する完了条件を回帰から守るため。
- FeedCacheCoordinator は store や API 詳細を直接保持せず、Read/Write/RemoteSearch 系 service を合成して orchestration だけを担う。
  - persistence 詳細を service 側へ閉じ込め、Coordinator の責務を Task 管理と進行制御へ限定するため。
- FeedCacheReadService を副作用なしの read/整形層とし、FeedCacheCoordinator / HomeSystemStatusService / ChannelRegistryMaintenanceService の store 読み取りをここへ集約する。
  - 読み取り結果の整形を orchestration から分離し、Read 層の pure 性を維持するため。
- FeedCacheStore への書き込みは FeedCacheWriteService へ集約し、FeedCacheCoordinator / FeedChannelSyncService / ChannelRegistryMaintenanceService は Writer 経由で副作用を起こす。
  - store 書き込みの責務境界を単一化し、Coordinator からの直接書き込みを排除するため。
- FeedCacheCoordinator の store 呼び出しは、write を cacheThumbnail / persistBootstrap / performConsistencyMaintenance、read を loadSnapshot / loadVideos / countVideos / loadChannelBrowseItems として Read/Write 境界へ固定する。
  - Coordinator を進行制御へ限定し、後続の FeedCacheWriteService と FeedCacheReadService へ追加推論なしで移譲できるようにするため。
- Issue の ToDo を完了したコミットでは、focused verification 後かつ git add 前に IssueToDo をチェック済みに更新する。
  - ToDo 完了反映とコミット粒度を同じコミット境界で追跡できるようにするため。
- Issue Description の ToDo 完了反映は issue-todo-check command で 1 項目ずつ更新する。
  - Issue 実施中の完了反映を Issue Description 上のチェック状態と 1 対 1 で追跡できるようにするため。
- 登録チャンネルCSVの取込みはバックアップ復元ではなくチャンネル登録画面の一括追加として扱う。
  - 既存のJSONバックアップ責務を維持しつつ、YouTube登録チャンネルCSVを未登録Channel IDの追加入力源として接続するため。
- サムネイル候補順は maxresdefault, sddefault, hqdefault, mqdefault, default の順で固定する。
  - llm-temp での取得点検で高解像度から順に 200/404 を判定でき、Issue3 の禁止事項と整合するため。
- command例文はメタルール化せずusage直下へ実記載する。
  - Issue57ではrules総則より各skill本文だけで実行形を読める状態を正本とするため。
- skillsのcommand参照はcommit/verification/rule-creationまで具体例文付きへ揃える。
  - docs/rules.mdの共通原則とIssue57の復元方針をskills全体へ不足なく適用するため。
- rulesとskillsでusageに整合する具体command例文の併記を必須とする。
  - Git履歴748d7f0で確認できた具体例必須要件を6c73507以降のusage記法へ整合させて復元するため。
- docs/rules/*.md の導線を docs/rules.md の単一正本へ集約した。
  - ルール読取り時の参照先を 1 ファイルへ固定し、完全一致する導線文言の重複を解消するため。
- Issue詳細化 skill の Description ToDo を 3種固定へ更新した。
  - Issue53 で Issue詳細化ToDo・Issue外ToDo・IssueToDo と番号付き列挙を正本化する必要があったため。
- scripts の公開入口は command-runner.py のみに集約する。
  - scripts 直下 shell を廃止しつつ usage の複雑度を上げないため、repo root 解決と command 解決を command-runner.py 自身へ集約する必要があるため。
- command-runner.py の移動は、改名後編集の前にコミットを挟む。
  - Git 追跡中ファイルの改名後に同一ファイルを編集する場合は、改名と本文編集の間にコミットが必要なため。
- command 実装の _meta.json と Python 実装は skills 配下ではなく scripts/<group>/ 配下を正本とする。
  - scripts 直下 shell 入口、_meta.json、Python 実装の実配置を一致させることで、参照更新の範囲を局所化し、wrapper と実装の解決経路を同じ親ディレクトリ配下へ閉じ込められるため。
- Issue45で残存するrules task定義をskillsへ分離しdocs/rulesは導線のみへ統一した。
  - rules-session-startの分離パターンを残る12本へ適用し、ruleとskillの責務境界を揃えるため。

## 2026/04/04

## 2026/04/02
- ファイル名変更は Git追跡中なら git mv、未追跡なら mv とする。
  - git の履歴保持は追跡中ファイルでだけ成立し、未追跡ファイルでは通常のファイル名変更として扱う必要があるため。
- default 解決される option の説明は個別 rule に残さない。
  - usage から省いた option の既定値解決は skill 側の責務であり、個別 rule には実行時に追加指定が必要な情報だけを残すため。
- llm-cache で解決できる既定 option は rule の usage から除外する。
  - command usage は実行時に追加指定が必要な引数だけを残し、既定値解決は skill 側で担保する方針に統一するため。
- rules の command 補足は usage だけで確定しない情報に限定する。
  - usage で自明な説明や実装読解前提を残さず、command 実行方法だけを簡潔に読めるようにするため。
- rules の command 記法は usage 記法と置換値説明で統一する。
  - Issue作成ルールを基準に、他 rule でも実行可能形と置換値の意味を文書内で閉じるため。
- ルール生成ルール更新とコミットルール微調整は、どちらもrules系文書のcommand記述規約整備として同一コミットへまとめる。
  - 変更対象が rules 文書群に閉じており、同一のルール整備シーケンスとして履歴上も追いやすくするため。
- chat履歴のuser lineは既存分を含めて常に `- ` 始まりへ統一し、コミットルール側でも明示的に規定する。
  - 履歴形式の検証基準を文書と既存記録の両方で一致させ、後続の履歴追記で推論や揺れが生じないようにするため。
- issue-creationはrepo未指定時にissue-defaults cacheのrepoを参照し、Issue作成ルールはusage記法とIssue Descriptionファイル生成規則だけで判断できる形に整理する。
  - Issue作成時の入力解決とDescription扱いをルール本文だけで一意に判断できるようにし、環境変数やスクリプト実装読解への依存を減らすため。

## 2026/04/01
- rules の command 例は、そのまま実行できる形に一意に展開できる {variable} 記法で記述し、llm-cache は参照キー名だけを書く。
  - プロジェクト固有値の露出を避けつつ、後続スレッドの LLM が scripts と llm-temp の制約を推測なしで再現できるようにするため。

## 2026/03/31
- GitHub App 設定の正本は llm-cache/github-app.json とし、owner/title は repo から補完できるため config から除外する。
  - github-app.py と issue-defaults.py の参照条件を読めば、現行 user mode で必要なのは operationMode、appId、privateKeyPath、projectNumber、projectId までと一意に確定できるため。
- Issue詳細化では判定基準を先行 ToDo で確定し、評価語だけの ToDo を禁止する。
  - 新しいスレッドでも同じ Issue コメントと明示済み読取り対象だけで着手できるようにし、監査可能な ToDo 粒度を維持するため。

## 2026/03/30
- script 改名後の正本文書は現行の script 名参照へ同期する。
  - command 名統一後も rules と specs の正本が旧入口を指したままだと運用手順が食い違うため。
- scripts の shell wrapper は 8 行の最小入口に保ち、複雑な分岐を持ち込まない。
  - command 名変更や入力契約追加を進めても shell 層を肥大化させず、複雑な判定は共通実行基盤の Python 側へ閉じ込めるため。
- Description とコメントの Markdown 本文は command ごとの必須節を満たさなければ受け付けない。
  - ルールで固定済みの本文構造を scripts 側でも再確認し、内容不足の本文を GitHub へ送る前に止められるようにするため。
- タイトルやブランチ名のような短い識別子は direct arg として扱う。
  - llm-temp を長文 Markdown 本文に限定しつつ、短い入力は command 呼び出し時にそのまま渡せるようにして運用を重くしすぎないため。
- llm-temp ファイル強制は Markdown 契約として定義された入力にだけ適用する。
  - タイトルやブランチ名のような短い直接引数まで llm-temp へ押し込まず、長文 Markdown 本文だけを対象にできるようにするため。
- コメント本文も llm-temp 配下の固定命名 Markdown ファイル経由でだけ受け付ける。
  - 長文コメントでも入力源を追跡できるようにし、Description と同じ運用で整形と監査を揃えるため。
- Description 系本文は llm-temp 配下の固定命名 Markdown ファイル経由でだけ受け付ける。
  - 長文本文の出所を即座に追跡できるようにし、inline 引数や任意パス経由の更新を防ぐため。
- ルール遂行に必要な command 名はターゲット-タスク形式の新命名へ統一する。
  - 呼び出し対象と実施タスクが script 名から即座に判別でき、後段の入力契約やフォーマット強制を command ごとに掛けやすくするため。
- scripts が複数回使う操作は command ごとに専用 Python entry point を持つ構成にする。
  - 実際に呼ぶ入口単位で責務を固定し、共有 subcommand 依存を減らして後段の命名変更や入力契約強制を入れやすくするため。
- scripts の必須情報は各 command の `_meta.json` に `required_inputs` として固定する。
  - 必須入力の正本を command 定義へ寄せ、shell wrapper を肥大化させずに共通実行基盤で定義欠落だけを検出できる構造にするため。
- Issue詳細化のDescription正本を禁止事項とToDoに変更した。
  - Issue #38 で実施時の禁止事項をDescriptionへ残す必要が生じ、詳細化コメントとの同期規則も同時に必要になったため。
- Issue 詳細化コメントは、私の指示・その時点で行なった判断・最終的に最新になった ToDo を含み、ToDo は Issue / Issue詳細化 / Issue外に分け、Description には Issue の ToDo だけを反映する。
  - 詳細化の判断経路を失わずに保持しつつ、Description を実行用 ToDo に限定して管理境界を一意にするため。
- Issue の Description は最終的な ToDo だけを残し、詳細化の過程出力と確定本文は Issue コメントへ集約する。
  - Description を実施単位の一覧へ固定し、背景や判断経路はコメントへ分離した方が Issue 作成と Issue 詳細化の境界が一意になり、重複と矛盾を避けられるため。
- シーケンス開始とシーケンス終了のルールは削除し、終了時に残す追跡可能性と未完了時停止条件は Pull Request 作成・更新ルールへ集約する。
  - 開発シーケンス系ルールは形骸化しており、具体規則は個別タスクへ分解した方が一意に読めるため。終了時に残すべき具体項目は Pull Request 作成・更新の完了判定へ置く方が整合するため。
- 既存ファイル改名の git 運用規則は個別タスクではなく docs/rules.md の共通原則へ置く。
  - git mv 使用と改名後編集前コミットはレポート固有ではなく横断的な Git 制約であり、共通原則に置く方が一意に参照できるため。

## 2026/03/29
- レポート作成の再利用性を高めるため、docs/report の作成要件を独立ルールとして新設する。
  - 今回の要求では、暫定結論、目的、コスト観点、Appendix での指示全文と試行錯誤記録が必須であり、今後も再利用される判断軸だから。
- Issue 4 セッションの総括は、LLM クォーター最適化を主眼に置いたレポートとして docs/report に残す。
  - 一行目的から詳細化、実装、試行錯誤までを再利用可能な手順知として残し、次回以降の往復削減に使うため。
- Issue 4 TODO 5として、サムネイル件数と総容量の算出、および上限・下限の閾値判定を FeedCache の管理責務へ集約する。
  - 廃棄判断を呼び出し側へ分散させず、件数と容量の両方を同じ cache 管理ロジックで一貫して評価できるようにするため。
- Issue 4 TODO 4として、サムネイル廃棄は上限超過時に開始し、下限を下回るまで最終アクセス時刻の古い順に削除を継続する。
  - 上限超過時に1件だけ削除すると再超過が残りうるため、実装とテストが一致する低水位までの継続削除を定義した。
- サムネイル廃棄の第1段階は FeedCacheStore の eviction helper として実装し、上限件数または上限容量を超えた時は最終アクセス時刻が最も古い1件だけを削除して oldest-first の順序を確定する。
  - Issue 4 の第3ToDoは削除順の定義が主題であり、下限までの連続削除を先に混ぜると第4ToDoとの境界が曖昧になるため、まずは単発 eviction で削除順位だけを独立に固定する。
- `ThumbnailView` はローカル `thumbnailLocalFilename` を使う `AsyncImage` に `.task(id: filename)` を付け、view instance ごとに1回だけ FeedCacheStore へ参照通知して最終アクセス時刻を更新する。
  - Issue 4 の第2ToDoでは `AsyncImage` 生成時点をアプリ側で明示できる契機へ落とし込む必要があり、一覧ごとの個別実装へ散らさず ThumbnailView 1 箇所へ集約すると対象導線を漏れなく更新できるため。
- サムネイル参照の最終アクセス時刻は cached_videos / remote_search_videos の thumbnail_local_filename と同じ管理単位に REAL 列で保持し、既存DBは起動時 ALTER TABLE で後方互換 migration する。
  - Issue 4 の第1ToDoは保持先追加だけを独立に完了させる必要があり、更新契機や廃棄ロジックより先に永続化と既存DB互換を確保すると段階的コミットとテストが成立するため。
- `rules-commit.md` では、履歴更新 command を `chat` `decisions` `metrics` の各ファイルごとに明示し、完了条件でも対象ごとに分解して記述する方針にした。
  - `scripts/append-*` という総称のままだと、どの更新でどの command を成功させるべきかを LLM が補完する余地が残るため。対象ファイルと command 名を 1 対 1 で固定することで、完了条件を文面だけで一意に判断できるようにする。
- `rotate-history` skill では、`*-latest.md` の先頭行確認を外側で行わず、Python 実装内でローテート、空ファイル初期化、完了条件検証まで完結させる方針にした。
  - セッション開始で本文を読んで先頭行を確認すると `chat-latest.md` の内容量ぶんトークン消費が増えるため。`scripts/rotate-history` から呼ばれる Python 実装が最終状態を保証すれば、外側はコマンド実行だけで完了判定できる。
- `rules-commit.md` では、`docs/history/*-latest.md` 更新を本文だけでなくコミット定義と完了条件にも明記する方針にした。
  - `docs/history` という抽象語だけでは、`*-latest.md` 更新規則を移した事実が上位要約から読めず、移管意図が見えなくなるため。`*-latest.md` を要約部へ引き上げることで、責務境界と具体更新先を同時に読めるようにする。
- `rules-commit.md`、`rules-document-sync.md`、`rules.md` では、`docs/history` は `コミット`、それ以外の `docs/` は `文書同期` と一意に読める責務境界へ揃える方針にした。
  - 本文移管だけでは一覧と要約で責務が抽象化され、意図から外れて見えるため。上位説明と一覧の両方で境界を固定することで、どこで `history` を更新するかを推論なしで判断できるようにする。
- `rules-session-start.md` では、セッション開始の完了条件を満たした結果として差分が残る場合は、その差分をコミットする方針にした。
  - セッション開始の再適用でローテート差分が残るのに、完了条件へコミットが含まれていないと基準状態が未確定のまま次作業へ進めてしまうため。完了条件へ差分コミットを含めることで、セッション開始の終了状態を観測可能に固定する。
- `rules.md` では、`ユーザー指示の理解`、`Issue の詳細化`、`先行テストで期待固定`、`実装と健康度点検`、`検証` を独立タスクとして扱う方針にした。
  - 旧 `rules-run-development.md` にまとまっていた開発手順では、個別タスクの判断基準が単体文書で読めず、必要な規則だけを選んで読むことができなかったため。タスクごとに分離することで、読み込み範囲と判断責務を最小化できる。
- `rules-commit.md` を新設し、コミット粒度の規則と `docs/history` 更新規則を 1 ファイルで判断できる構成にする方針にした。
  - `コミット` タスク候補が存在していた一方で正本ルールが無く、`history` 更新規則も別文書に残っていたため。コミット時に必要な判断を単体完結させることで、履歴確定と当日履歴更新を同じ文脈で扱えるようにする。

## 2026/03/28
- 文書同期ルールの `chat-latest.md` では、ユーザー指示の直後の次行に、1段インデントで LLM の回答および操作の概要を1行記録する方針にした。
  - `chat-latest.md` だけではユーザー指示の記録しか残らず、応答側の判断や実施内容が追えないため。`decisions-latest.md` の理由行と同じ書式へ寄せることで、履歴内の書式差分も抑えられる。
- 文書同期ルールの `chat-latest.md` では、1行入力をユーザーの直接入力、改行を含む入力を貼り付けとみなし、改行以後は引用要約として同一行へ連結する方針にした。
  - ユーザーの運用として貼り付けは必ず改行を含む前提が明示されたため。入力の種別判定を改行有無へ固定することで、LLM が貼り付け判定を推測しなくて済む。
- 文書同期ルールの `docs/history` 章は、`*-latest.md` 共通制約とファイル固有規則へ分けて正規化する方針にした。
  - `chat-latest.md`、`metrics-latest.md`、`decisions-latest.md` に共通する更新位置や見出し形式の規則と、ファイル個別の差分が同じ階層に混在していたため。共通部と差分部を分けることで、適用範囲を一意に読めるようにする。
- 文書同期ルールの `docs/history` 章では、継続履歴の正本定義を目的、`-log.md` 非追記と `-log.md` 非読込を制約として分離する方針にした。
  - `-log.md` の役割説明と禁止事項が重複していたため。目的と制約を分離することで、何のための文書かと、何をしてはならないかを別軸で読めるようにする。
- `human-view` は残課題ありとしてルール正規化の適用対象外にし、完了条件側でも同じ例外を明示する方針にした。
  - `human-view` 章には人間向けの説明語が残っており、即座にゼロ推論化できないため。適用対象外であることを明示しないと、完了条件と矛盾する。
- `rules-pr-creation.md` では Pull Request の body に `Closes #(Issue番号)` を必須とし、GitHub の連携クローズ機能を使って Issue と紐付ける方針にした。
  - LLM が Issue を直接 close しない制約を維持しつつ、PR マージ時の close を GitHub 標準機能へ委譲するため。表現を固定することで、リンク方法の揺れも防げる。
- `rules-issue-creation.md` では、Issue に着手した後、実装開始前に `issue-(IssueNo)` 形式の作業ブランチを作成して checkout する方針にした。
  - Issue とブランチの対応関係を機械的に追跡できるようにするため。命名規則と checkout 条件を固定することで、着手状態の判断も一意になる。
- `rules-rule-creation.md` を追加し、ルール文書は1ファイルで完結し、他のルールファイルを参照しない方針にした。
  - ルール作成時に別ファイル参照を許すと、適用時に複数文書をまたいだ解釈が必要になるため。単体完結を必須にすることで、ルール文書自体の読解負荷を抑える。
- `rules.md` の共通原則では、目的タスク外の文書を先回りや参考目的で読まず、Git 操作は常に直列実行し、タスク規定が曖昧なら中断して報告する方針にした。
  - 先回り読込みと並列 Git 操作が、今回のセッションで誤読や競合の原因になったため。共通原則として先に禁止する方が再発防止になる。
- セッション開始ルールでは、ブランチ仕様を `main` へ checkout して最新化することへ限定し、履歴ローテートは `rules-session-start.md` にだけ置く方針にした。
  - `session main` のような別解釈が混ざると、セッション開始とシーケンス開始の境界が崩れるため。ローテート手順も同じくセッション開始だけの責務へ閉じる必要がある。

## 2026/03/27

## 2026/03/25
- rules コレクションの人間向け入口は、新しい正本を増やさず `docs/human-view/rules-overview.md` に overview として追加し、細かな規定は正本参照へ委ねる方針にした。
  - `human-view` に必要なのは判断基準の複製ではなく、正本へ戻りやすい読み順の翻訳であるため。開発セッションと開発シーケンスを上から追える導線に絞る方が、overview と正本の役割分担を崩しにくい。
- Issue と作業ブランチの対応は自由記述コメントに任せず、`scripts/register-issue-branch` を正規入口に固定する方針にした。
  - Issue #21 の要件は「記録すること」だけでなく「継続して追跡できること」も含むため。コメント文面を標準化し、重複記録も抑止できる入口を 1 つ持つ方が運用が崩れにくい。
- rules の再編は、既存 5 本を細分化しすぎるより、タスク単位で再命名した正本へ再配置する方針にした。
  - `rules` の読み分けコストを落としつつ、文書数の急増で入口判断が逆に難しくなることも避けたいため。まず「何の作業で読むか」がファイル名から分かる粒度へ揃える。
- 完了済みの rules 更新も、後付けで Issue を起票し、Issue ブランチを切ってから `dev` を `main` 基準へ戻し、Issue ブランチから `dev` へ Pull Request を作る形で追跡可能性を回復する方針にした。
  - すでに `dev` に積まれているコミットを捨てずに Issue 駆動へ復旧するには、現在の HEAD を保全するブランチを先に作り、`dev` 側だけを PR の base として整えるのが最も安全なため。
- 日付跨ぎ後のその日の最初の開発シーケンスでは、`*-latest.md` の過去日分を先に `*-log.md` へ移し、そのうえで当日分を `*-latest.md` に追記して運用を継続する方針にした。
  - 開始時点の履歴整理と当日バッファの更新が分離すると、`latest` に過去日と当日分が混在しやすくなるため。ローテーション直後に当日エントリを作る運用へ揃えた方が追跡しやすい。

## 2026/03/24
- Issue 詳細化は Description 全体の書き換えではなく、Description にはチェックボックス付き ToDo だけを追記し、詳細化本文は Issue コメントへ分離する方針に改めた。
  - 元の指示を崩さず残しつつ、実装上の正本となる整理結果だけをコメントで継ぎ足した方が、原文・ToDo・判断経緯を同時に追いやすいため。
- rules には Assignee 名、Project 名、既定 mode のようなプロダクト固有値を固定せず、GitHub 関連の既定値は secrets と local cache から解決する方針に改めた。
  - プロダクト固有値を rules へ埋め込むと、別環境や mode 切り替え時に rules 自体が破綻するため。運用ルールと環境固有設定を分離した方が再利用しやすい。
- `LLM所要時間` は履歴文書だけでなく GitHub Project の Number フィールドにも反映し、field が無ければ script で作成してから更新する方針にした。
  - 開発シーケンス単位の所要時間を Projects 上でも見られるようにすると、Issue 一覧から進行と工数を追いやすくなるため。手作業ではなく script 化して再現可能な経路へ寄せる。
- Issue コメントで blocker や確認事項の問答をしたタスクを完遂した場合は、最後に処置内容をコメントへ追記する方針にした。
  - 途中の問答だけが Issue に残ると、最終的に何を採用し何を破棄したかを後から追えなくなるため。完了時に処置結果を明示して、Issue 単体でも判断の終着点が分かる状態を保つ。
- GitHub 操作モードは secrets の `operationMode` で切り替え、本プロダクトは `user` モードで運用する方針にした。
  - User アカウント配下では repo 操作と Projects 操作の到達経路が一致しないため。`user` モードでは repo を GitHub App、Projects を `gh` に分離し、`organization` モードでは両方を GitHub App へ寄せる形で固定した方が再利用しやすい。
- Issue 詳細化中や ToDo 実施中に blocker が出た場合は、Issue コメントへ確認内容を書いて停止する方針にした。
  - 途中で黙って止まると、どこまで確認したかが履歴から追えなくなるため。Issue コメントへ残して停止すれば、再開時に同じ探索を繰り返しにくい。
- Pull Request も Issue と同様に Assignee と Project を設定し、ToDo は 1 ステップごとにコミットする方針にした。
  - Issue と PR で管理粒度がずれると、進行状態と変更履歴の対応が崩れやすいため。ToDo 単位でコミットを分けておけば、どの変更がどのステップに対応するかを後から辿りやすい。
- 開発シーケンスは開始時に `main` で `git pull --ff-only origin main` を実行し、最新を確認してから進める方針にした。
  - 前の作業ブランチやローカル遅延を引きずったまま着手すると、Issue 化や文書更新だけのタスクでも基準点がぶれやすいため。開始点を常に最新の `main` へ固定した方が、各シーケンスを独立して再現しやすい。
- GitHub Issue の既定 Assignee / Project は、厳密に解決した結果を `llm-cache/` 配下へ cache し、cache が無い時だけ取得し直す方針にした。
  - 毎回タイトルや owner を曖昧一致で探すと誤設定や取りこぼしの温床になるため。Assignee `horikuma` と Project `YoutubeFeeder` の解決結果を local cache として持てば、次回以降は再取得なしで同じ設定を再利用できる。
- 履歴の `*-latest.md` から `*-log.md` への移行は、開発シーケンス開始手順へ統合し、巨大な log を LLM が直接読まず local skill / script で処理する方針にした。
  - 日付跨ぎのたびに人手や LLM が log 本文を結合すると、トークン消費と混在事故の両方が増えるため。開始手順にローテーションを組み込み、処理本体は skill 化して局所化した方が安定する。
- チャット欄から始まる開発シーケンスでも、最初にユーザー指示を原文として Issue 化して詳細化し、その後は通常の Issue 駆動フローへ合流させる方針にした。
  - チャット起点の作業だけ追跡粒度が落ちると、原文、完了条件、履歴の対応関係が崩れるため。入口がチャットでも Issue へ正規化してから進める方が、以後のブランチ、コミット、PR を同じ基準で管理できる。
- 開発シーケンスの完了条件には、必要なコミット後に作業ブランチから `main` へ戻ることを含める方針にした。
  - 次の作業開始点を常に `main` に揃えておくことで、着手時の分岐判断とブランチ残置による混乱を減らせるため。

## 2026/03/23
- specs 文書は `docs/specs.md` を入口とし、本文は `docs/specs/` 配下の `specs-product.md`、`specs-architecture.md`、`specs-design.md` へ分ける方針にした。
  - rules と同じように入口と本文を分けた方が、参照順と責務境界を保ちやすく、仕様系文書の置き場判断も安定するため。
- metrics 文書は `docs/metrics/` 配下の個別文書として扱い、専用 index は作らない方針にした。
  - metrics は一覧よりも用途別の参照資料として直接読む場面が多く、index を増やすより `metrics-src.md` と `metrics-test.md` へ分けた方が軽く保てるため。
- Issue の実施タスクに ToDo がある場合は、ToDo を 1 つ終えるごとにコミットする運用を明文化する方針にした。
  - 後から履歴を見た時に、どの変更がどのタスクに対応するかを追いやすくしたいため。同一ファイルへ複数回触る場合でも、タスク単位で順次確定する方が混乱を減らせる。
- Issue の進行管理はラベルではなく GitHub Projects と Pull Request の関係で扱い、LLM は Issue を直接 close しない方針に改めた。
  - 進行ラベルは Projects の責務を重複させやすく、Issue の状態と運用規則が二重化するため。完了は PR 側の close 関係や人手運用へ寄せる方が GitHub 標準の流れに近い。
- Python 系の共有実行環境は `skills/github/.venv` のような局所配置ではなく、リポジトリ root の `.venv/` と `requirements.txt` に集約する方針にした。
  - GitHub skill 群が同じ依存を共有しているため、skill ごとに仮想環境を持つより root へ寄せた方が更新漏れと重複インストールを減らせる。
- `rules.md` 以外の rules 文書は `docs/rules/` 配下へ移し、`docs/` 直下には入口だけを残す方針にした。
  - 入口文書と個別ルール本文を物理配置でも分けた方が、索引と本文の責務が崩れにくく、文書追加時の置き場判断もしやすいため。
- `llm-temp/` は LLM 用の一時ファイル置き場として使い、ユーザーが後から処理経路を見直せるよう、LLM 側では自動削除しない方針にした。
  - セキュリティ上 `/tmp` のような共有領域を避けたいことに加え、途中生成物やログを残しておくこと自体が調査の助けになるため。
- GitHub skill の責務は、Issue 状態変更、コメント、PR 作成をそれぞれ独立した認証実装へ分散させず、既存の App 認証共有基盤の上に「Issue 操作」と「PR 作成」を載せる構成にした。
  - 再利用性は確保したいが、操作ごとに認証や設定解決を重複させると保守コストが増えるため。利用者には `scripts/` の薄い入口を見せ、内部では共有認証を使う方が責務分離と拡張性の両立になる。
- Issue 駆動の開発手順は、その都度の運用メモではなく `rules-process.md` の基本フローとして定義する方針にした。
  - Issue の `Todo` / `Inprogress` / `Done` 更新、ブランチ作成、途中コミット、PR 作成、実施不能時のコメント中断は、個別タスクの補足ではなく再利用すべき開発プロセスだから。毎回同じ判断で運用できるよう、rules に昇格させる。
- GitHub skill の責務は、一覧取得、Issue 読み取り、Issue 本文更新を別々の極小 skill へ砕かず、共有 App 認証モジュールと Issue 操作コマンド群へまとめる方針にした。
  - 再利用性のために認証処理は共有化したい一方で、操作ごとに skill 自体を細分化しすぎると入口が増えて保守しにくいため。利用者の入口は `scripts/` に残しつつ、`skills/github` 側は「一覧」と「Issue 操作」の 2 系統にとどめる構成が最も扱いやすい。
- Issue #5 の Description は、背景、目的、スコープ、進め方、実施タスク、完了条件、非対象を持つ形へ詳細化する方針にした。
  - Issue ドリブン開発へ切り替える論点では、タイトルだけでは着手条件も完了条件も読み取れないため。後から見た人や LLM が同じ基準で開発を継続できるよう、Description 自体を開発単位の入口として整える必要がある。
- GitHub Issue 取得 skill は、直接 REST を組み立てる shell ではなく、skill 内部で依存を閉じ込めた `PyGithub` ベースへ寄せる方針にした。
  - GitHub App 認証、installation token 取得、Issue 一覧取得の責務を Python 側へ集約した方が、API 契約の変化やページング処理に追随しやすく、`scripts` からは薄い入口を保ちやすいため。
- `tools`、`skills`、`scripts` だけを変更した場合は、アプリ本体の build / test を実施せず、対象ツールの構文確認と代表 1 経路の実行確認で検証する方針にした。
  - アプリ本体と無関係な変更まで毎回 Xcode build / test を要求すると検証コストが過剰になり、変更内容と検証内容の対応も崩れやすいため。tool 変更では tool 自身の契約に直結する確認へ絞る。
- rules 文書はプロダクト固有語を持ち込まず、プロダクト前提や端末前提は `architecture.md` へ寄せる方針にした。
  - rules は文書・フロー・tools の抽象ルールを扱い、プロダクト依存の設計判断や機能文脈を混ぜない方が、別種のプロダクトでも再利用できる判断基準として保ちやすいため。
- GitHub Issue 取得は `scripts/list-issues` から `skills/github/list-issues.sh` を呼ぶ薄いラッパー構成に統一する方針にした。
  - 利用者の入口を `scripts/` に固定しつつ、認証・JWT 発行・installation token 取得・Issue 取得の本体は `skills/` へ閉じ込めた方が、rules-skills の責務分離に沿って保守しやすいため。

## 2026/03/21
- `src-metrics.md` は正本ではなく参照資料として追加し、まずは更新規則を固定しない単発スナップショットとして扱う方針にした。
  - 今回の要求は「今この瞬間の規模と健康度を見たい」であり、定点観測の運用まで同時に決める必要はないため。正本へ入れると更新義務が重くなる一方、参照資料ならソース総行数、正本文書行数、barometer 結果、ファイル別行数の概観を柔らかく蓄積できる。
- スプラッシュのアプリ名は 2 行化させず、狭い横幅では縮小してでも `1 行` へ収める方針にした。
  - `iPhone 12` 幅で末尾の `r` だけが次行へ落ちると、起動直後の印象が崩れるため。中央配置と大きな文字は維持しつつ、`lineLimit(1)` と `minimumScaleFactor` で横幅へフィットさせる。
- `LLM所要時間` の終了時刻は、metrics 計測前ではなく原則 `コミット直前` に取る方針へ改めた。
  - source change では `scripts/collect_metrics.sh` が分単位の検証コストを持つため、その前に `finish` すると実態より極端に短い値が残りうるため。文書-only などコミットしない場合だけ、最終応答直前を例外の終了点とする。
- 動画 URL の共有は画面個別ではなく `VideoTile` 共通の長押しメニューへ載せ、YouTube検索、キャッシュ検索、チャンネル動画、動画一覧へ一括適用する方針にした。
  - 現在の動画系画面は `VideoTile` を共通利用しており、ここで share sheet を持てば機能差分を作らずに全経路へ広げられるため。画面ごとに分けると long press の契約が崩れやすい。
- 短尺動画マスクは `Shorts URL/title` だけでなく `durationSeconds < 240` も含む共通ポリシーとして復旧し、feed cache と remote search fallback の両方へ同じ基準を通す方針にした。
  - `4分未満` マスクが抜けると、feed 一覧では除外できても remote search 起点の channel fallback だけ短尺が混ざる、という経路差が生まれるため。判定を pure logic へ寄せ、保存前と表示前の両方で同じ基準を使う。
- 旧 `JSON` / legacy migration は runtime から撤去し、全設定リセットでは `SQLite` と旧 runtime file の両方を削除して、古い永続状態を再注入しない方針に改めた。
  - 今回は旧仕様データの互換維持が不要で、reset 後は「古いデータは存在しない」前提でよい。migration や legacy file cleanup を中途半端に残すと、再起動時や別経路で古い file が混ざり、原因追跡が難しくなるため。
- YouTube検索 split 右ペインで channel 動画が `1 件` に留まる場合は、単なる表示制限ではなく data source 不足とみなし、`routeSource = .remoteSearch` を文脈として channel-specific API fallback を実行する方針にした。
  - 実ログでは `channel_videos_open_complete videos="1"` の直前に `home_status_load_complete cached_videos="0"` が出ており、feed refresh 後もチャンネル cache が埋まっていなかった。UI の 20 件刻み表示を軽くしても根本解決にならず、remote search 起点に限った追加取得が必要だった。
- チャンネル動画一覧の merge では、feed cache と検索 cache に同じ `video_id` があっても fatal にせず、より新しい動画を優先して 1 件へ正規化する方針にした。
  - `Dictionary(uniqueKeysWithValues:)` のままだと、同一動画が複数経路へ保存された時点で `Duplicate values for key` でフリーズするため。ローカル正本を守るには、重複を例外ではなく整形対象として扱う必要がある。
- 全設定リセットでは `SQLite` の table だけでなく database file / `-wal` / `-shm` も削除し、旧永続状態を丸ごと捨てて再初期化する方針にした。
  - 今回は旧仕様データを残す必要がなく、リセット後は古いデータが存在しない前提でよい。登録チャンネルも含めた正本が `SQLite` へ集約されたため、file ごと消した方が再現性と整合性が高い。
- YouTube検索 split 右ペインのチャンネル動画は 1 件へ潰さず全件保持し、表示だけを `20 件ずつ` の段階追加へ寄せる方針にした。
  - 一覧を軽く見せたい要求はあるが、データ自体を切り捨てると検索から辿れるチャンネル動画の意味が変わるため。右ペインは全件取得し、初回 20 件と末尾到達時の追加表示で描画負荷だけを抑える。
- 動画、チャンネル、検索履歴、登録チャンネルの正本は `SQLite` へ寄せ、表示に直結する固定文字列も同一更新点で保存する方針にした。
  - `JSON` 永続化のままでは検索履歴横断の channel 集約や初期表示の一貫性を保ちにくいため。`publishedAt` の raw 値と `publishedAtText` のような表示値の重複は、同じ保存時点から生成される限り許容する。
- 旧 `UITest` fixture や legacy cache は、新しい display string 付き値型へ後方互換 decode させ、移行入力としては引き続き読める状態を保つ方針にした。
  - 正本を `SQLite` へ移しても、既存の `UITest.cache.json` や移行元 cache を即座に全廃すると検証と移行が不安定になるため。入力互換を残しつつ、保存先だけを `SQLite` へ統一する。
- YouTube検索のチャンネル動画集約では、既定キーワード用 `remote-search.json` も `remote-search-*.json` と同列に扱う方針にした。
  - split 詳細のチャンネル動画は検索キャッシュ全体から channelID で引き当てているため。既定キーワードだけ別ファイル名だと、検索結果は見えてもチャンネル内動画だけ 0 件になる再発条件が残る。
- YouTube検索画面の初回遷移待ちについて、snapshot prewarm だけでは足りない前提に立ち、ホーム表示中に hidden host で検索画面を事前描画する方針へ進めた。
  - ログ上では snapshot 読込は 0ms まで下がっていた一方、split 初期読込タスクの再開が約 2.3s 遅れており、ボトルネックが描画側に残っていたため。内容を軽くするのではなく、画面構築そのものを `prewarm` モードで一度踏ませる。
- YouTube検索画面の描画負荷を客観観測できるよう、`visible` / `prewarm` を区別した `screen_render_probe` と split 初期読込ログを追加する方針にした。
  - root、regular 左ペイン、split detail の描画到達点を記録し、次回は `screen_appear` から `screen_render_probe`、`remote_search_split_load_started` までの差分で改善有無を判断できるようにする。
- `LLM所要時間` の未測定が続かないよう、運用補助として `scripts/llm_elapsed.sh` を追加し、開始・終了の実測をコマンドで残す方針にした。
  - 手順だけを厳密化しても取りこぼしが続くため。通常運用では `start` / `finish` を必ず使い、`未測定` は移行期の例外に限定する。
- Human-View の主要クラス図では、表現差分を束ねる親 View を `[Variants Host]`、表現差分群そのものを `[Variants]` と表記する方針に改めた。
  - `ChannelBrowseView` や `RemoteKeywordSearchResultsView` は差分群を内包する親であり、`ChannelTile` のような共通表示核とは役割が異なるため。あわせて長い `compact / regular / split detail` の列挙はラベルから省略し、必要な説明は依存関係メモ側へ寄せる。
- `LLM所要時間` は、推測やコミット時刻流用ではなく、ユーザー送信直後の開始時刻と文書更新直前の終了時刻を実測し、その差分を四捨五入した `約x分` で記録する方針に改めた。
  - 体感時間や前後コミット時刻を混ぜると履歴の意味がぶれるため。測定漏れが起きた場合は推測で埋めず、未測定であることを明示する。
- human-view 固有に見えていた文書ルールは、`rules-document.md` の `Human-View ルール` 章へ集約し、画面識別子や図の簡略化方針も正本として管理する方針にした。
  - `gui.md` や `design-overview.md` の中にしか存在しない運用ルールがあると、翻訳資料の更新だけで判断基準が変わってしまうため。`画面A` のような識別子、章構成、Adaptive UI 詳細を図へ出しすぎない方針などは、文書運用の正本へサルベージしてから運用する。
- Browse 命名は、`ChannelBrowseView` のように機能語を主語にし、`InteractiveListView` のように SwiftUI 型は原則 `View` で終える方針にそろえた。
  - `ChannelBrowseListView` のように一部だけ `ListView` を含む名前や、`InteractiveListScreen` のように `View` で終わらない型名が混じると、機能責務と容器責務の読み分けがぶれやすいため。
- チャンネルタイルの共通核は `ChannelTile` へ戻し、遷移や選択の差分だけを `ChannelNavigationTile`、`ChannelSelectionTile` へ残す方針に改めた。
  - 機能的に共通な中心語は短く保ちたい一方で、操作差分まで同じ名前へ押し込むと責務がぼやけるため。`ChannelTile` を核にし、差分 wrapper だけを長めの操作語で表す構成が最も読みやすい。
- チャンネル一覧のタイルは、機能共通の表示核を `ChannelSummaryTile` として切り出し、遷移用と選択用の操作差分は別 wrapper へ分ける方針にした。
  - `ChannelNavigationTile` と `ChannelSelectionTile` だけを見ると、どちらも「チャンネルを表すタイル」であることが読み取りづらいため。Human-View では機能共通核だけを `ChannelSummaryTile [Shared UI Core]` として見せ、操作差分は図から省略する。
- YouTube 検索 split 詳細のチャンネル切替では、タイトル更新、古い動画タイルの退避、右ペイン読込開始を親 View で一括管理する方針にした。
  - 選択中チャンネル名だけを先に更新し、旧タイルが数秒残る状態は GUI 契約として不自然なため。表示本体側で個別に読み替えるより、選択遷移を 1 箇所へ集約した方が中間状態を抑えやすい。
- 文書体系では `rules-documents.md` を `rules-document.md` へ改名し、画面設計の共通基準は新しい正本 `rules-design.md` へ切り出す方針にした。
  - 文書名の単数化で参照名を安定させつつ、視覚設計ルールを `rules.md` や `spec.md` へ分散させずに管理したいため。内容は `iPhone` / `iPad` 向けとして `8pt` グリッド、Dynamic Type、Adaptive UI 前提へ調整する。
- health_barometer 整理後の文書同期では、`design.md` だけでなく `architecture.md` と `human-view/design-overview.md` も同じ責務分割単位へ合わせて更新する方針にした。
  - 詳細設計だけ更新すると、人間向けの俯瞰資料で古い構造が残り、次回の分割判断や指示出しがぶれやすいため。
- health_barometer の長関数や広すぎるファイルは、責務境界が既にある単位から順に分割し、`FeedCacheCoordinator` のような巨大型でもアクセス修飾を広げる大手術は避ける方針にした。
  - 数値だけを下げるために無理な分割を行うと、かえって依存関係や可視性が悪化して自爆しやすいため。今回は Browse の remote search view 群、FeedCache の値型群、YouTubeSearch 周辺 DTO / 補助ロジックを自然な境界で分け、残る巨大型は今後の設計変更時に改めて扱う。
- Mermaid を含む Markdown の検証は、外部 API ではなく Node.js `24.14.0` とローカル依存に固定した `mmdc` による SVG 描画で行う方針にした。
  - 文書変更の成否をネットワーク先の可用性へ委ねると再現性が落ちるため。版固定した Node.js と npm lock file を正本にすれば、同じリポジトリ状態から同じローカル検証結果を再現しやすい。
- プロダクト名変更後に Xcode の build が崩れた場合は、project-local `.DerivedData*` と `xcuserstate` を旧名生成物ごと破棄して再生成する方針にした。
  - `HelloWorld` 時代の build database、生成物、UI 状態が `YoutubeFeeder` へ改名後も残っていると、Xcode が旧 project 参照や locked DB を引きずり、コードに問題がなくても `BuildFailed` になりうるため。
- iOS deployment target は app / unit test / UI test すべて `16.0` にそろえ、実機署名は `YQA274TX99` の automatic signing を前提にする方針にした。
  - `26.2` のような現実離れした target は Xcode / SDK の差分に弱く、さらに `Neko.YoutubeFeeder` へ改名後の実機ビルドでは新 bundle identifier 用の provisioning が必要になるため。共通条件を `16.0` へそろえ、署名責務は Xcode の自動管理へ寄せた方が継続運用しやすい。
- プロダクト名、ターゲット名、バンドルID、スキーマ、文書見出し、リソース参照は `YoutubeFeeder` に統一し、リポジトリを clone した作業フォルダ名だけは `HelloWorld` のまま維持する方針にした。
  - アプリ内部と正本では旧名を残さず統一したい一方、作業フォルダ名まで変えると Codex 側の前提や履歴上の絶対パスへ余計な影響が広がるため。プロダクト名とワークスペース名を切り分けて扱う。
- 文書体系と文書運用の正本は、章構成を分けたまま `rules-documents.md` へ統合し、旧 `document-rules.md` / `document-operations.md` の二分割は解消する方針に改めた。
  - 文書の切り分け基準と運用手順は意味合いが異なるため章は分けて残しつつ、参照先は 1 つに絞った方が更新漏れや読取漏れを防ぎやすいため。
- 開発シーケンスの終盤では、文書更新へ入る直前に `rules.md` を再読してから更新する方針を追加した。
  - 長期間のスレッド継続やコンテキスト圧縮後でも、ルールの取りこぼしによるルール外更新を防ぐ最後の確認点が必要なため。

## 2026/03/20
- 常設ログは、起動完了、ホーム表示、ホームから YouTube検索への遷移、検索画面表示、snapshot 読込、再検索、通信開始/完了/失敗、右ペイン読込完了のような境界観測へ絞り、性能探索のために一時的に増やした詳細分解ログは削除する方針にした。
  - 実測で decode 問題の主因は特定でき、以後は日常運用で追いたい UI 操作、イベント、通信系タスクの境界さえ残れば十分になったため。Xcode コンソールと LLM の両方で扱いやすい流量を優先しつつ、単発トラブル時に再び追加しやすい観測点だけを常設に戻す。
- 性能比較用の `PerformanceProbeMode` とホーム上の切替 UI は撤去し、iPad の YouTube検索 split は比較前の標準構成へ戻す方針にした。
  - `A/B/C/D/E` による比較で、右ペイン読込や件数制限より起動前半の decode と split 初回構築が支配的だと分かり、恒常機能として保持する必要がなくなったため。比較用分岐が残ると実装と文書の読み筋を複雑にするので、当初の動線へ戻す。
- キャッシュを取り直す前提で、旧 JSON summary や旧 ISO8601 日付との互換 decode は削除し、現在の compact JSON と binary property list summary だけを正本として扱う方針にした。
  - 互換経路は一時移行のためだけに残していたが、今後の運用ではキャッシュ削除と再生成で十分に置き換えられるため。decode 分岐を減らして保存形式の前提を明確にした方が、保守性と観測の単純さを保ちやすい。
- 今回の性能トラブル探索は、後から再利用できる叩き台として `docs/report/` 配下へ個別報告書として残し、文書体系上は `参照資料` として扱う方針にした。
  - `chat-latest` や `decisions-latest` だけでは試行錯誤の全体像や外れ筋、実測値のまとまりが後から追いにくいため。正本の仕様や方針とは分離したまま、個別調査の過程と観測を体系化して保存できる置き場を明示する。
- summary の初回 decode をさらに落とすため、`cache-summary` と `remote-search-*-summary` の正本形式を JSON から binary property list へ切り替え、旧 JSON summary は fallback 読込だけ残す方針にした。
  - summary sidecar 導入後も、実機では検索キャッシュ summary の decode がまだ 1.5 秒級で残っていたため。summary 自体を 100 byte 級の binary plist に落とし、`PropertyListDecoder` で読むことで、ホーム表示前の鮮度確認をほぼゼロコスト化する。
- 起動性能対策は、ホーム表示に必要な件数・鮮度を summary sidecar で返しつつ、本体 cache も compact date 形式へ寄せる二段構えで進める方針にした。
  - 実機ログで起動遅延の主因が `cache.json` と `remote-search.json` の初回 JSON decode だと特定できたため。ホームが本体 decode を踏まないよう `cache-summary.json` と `remote-search-*-summary.json` を追加し、加えて本体も再保存時は軽い日付表現へ変えて、今後の full decode コストも下げる。
- 起動時の通常キャッシュ `snapshot_ms` も最終段まで切り分けるため、`FeedCacheStore.loadSnapshot` に directory 準備、file existence、`Data(contentsOf:)`、JSON decode、返却件数の分解ログを追加する方針にした。
  - 直近の実機ログでは `snapshot_ms` が約 2.5 秒と `search_cache_ms` を上回っており、起動時ボトルネックの主犯候補として残っていたため。検索キャッシュ側と同じ粒度で `feed_snapshot_store_*` を出せば、通常キャッシュの重さが I/O か decode か、あるいはファイル規模かを同じ物差しで比較できる。
- ホーム表示前の `search_cache_ms` をさらに割るため、`RemoteVideoSearchService.status` と `RemoteVideoSearchCacheStore.status` に、service 境界、file existence、`Data(contentsOf:)`、JSON decode、TTL 判定の各区間ログを追加する方針にした。
  - 直近の実機ログでは `home_status_load_complete` の約 3 秒の大半が検索キャッシュ状態取得に集中していた一方、snapshot や split 読込は十分速いことが見えていたため。ここで対策に入るより、まず `search_cache_ms` の塊を細かく割って、I/O・decode・actor hop のどれが支配的かを確信を持って特定することを優先する。
- iPad の YouTube検索遷移調査では、bootstrap 完了までの内訳、ホームのナビゲーション部品描画、G 画面の最初の結果表示、右ペイン detail の初回表示までを同じ系列で観測できるよう、起動と描画の分解ログを追加する方針にした。
  - 既存ログで snapshot 読込や `openChannelVideos` 自体は十分速いことが見え、残るボトルネック候補が bootstrap と SwiftUI の初回描画へ絞られてきたため。`bootstrap_channels_loaded`、`home_status_load_complete`、`home_navigation_section_appear`、`remote_search_first_result_appear`、`remote_search_split_detail_appear` を足し、データ処理と描画待ちを同じ Xcode コンソールで切り分けられるようにする。
- YouTube検索の iPad 遷移調査では、`FeedCacheCoordinator` と `SearchResultsViews` の MainActor 区間に広めの境界ログを追加し、snapshot 読込、presentation 適用、split 予約、channel 動画統合、`refreshUI` の各区間を ms 単位で観測する方針にした。
  - `FeedCacheCoordinator` 自体が `@MainActor` であり、右ペイン読込が速い一方で開始前に待たされるケースが見えていたため、通信やデータ量ではなく MainActor 側の待機を疑う材料が揃ってきた。まずは actor 境界を崩す前に、どの区間が MainActor 上で長いかをコンソールだけで読めるようにし、変更の当たりを付けやすくする。
- iPad の YouTube検索 split 遷移では、Apple の標準パスに寄せた比較用として `PerformanceProbeMode.E` を追加し、左ペインを `NavigationSplitView + List(selection:)` ベースへ切り替えられるようにした。
  - 右ペイン読込や件数制限を変えても体感差が乏しく、現行の `ScrollView + LazyVGrid + 手動選択` が `NavigationSplitView` の得意経路から外れている可能性を切り分けたかったため。標準寄せを probe mode に閉じ込めれば、普段の UI を維持したまま同一ログ系と UI test で比較できる。
- 性能調査用に、ホーム画面から切り替える `PerformanceProbeMode` を設け、`A/B/C/D` のラベルをそのまま runtime log と console log へ残す方針にした。
  - 実機ではビルド差し替えよりホームから即座に条件を変えられる方が比較しやすく、後からログを見返した時にもどの条件で採取したかを迷わないため。`A=標準`, `B=右ペイン遅延なし`, `C=初回検索表示件数20件`, `D=初回右ペイン自動読込なし` とし、各イベントへ `probe_mode` を添える。
- YouTube検索の遷移調査では、検索専用ログに加えて `[YoutubeFeeder] app.lifecycle.*` を追加し、起動から G 画面到達までを同じ系列で追う方針にした。
  - G 画面以降のログだけでは、スプラッシュまで、ホームまで、ホームから G 画面までのどこが長いかを判別しにくかったため。`app_launch`、`splash_shown`、`bootstrap_start / complete`、`home_shown`、`remote_search_tile_tapped`、`split_load_*` を同じプレフィックスへ揃えることで、実機コンソールだけでも前段の詰まりを切り分けやすくする。
- iPad の YouTube検索遷移計測は、Xcode コンソールの目視だけに頼らず、UI test から読める hidden runtime diagnostics へ区間イベントを記録する方針にした。
  - 実機前段のシミュレータ比較では、ホームタップ、G 画面表示、右ペイン初期読込の予約、開始、完了を ms で並べて見たいが、コンソールログだけだと機械比較しにくいため。runtime diagnostics にイベントを残せば、UI test から `home_tap_to_screen_ms` や `home_tap_to_split_loaded_ms` を JSON として取り出せ、実機テスト時にも同じ指標系へ合わせやすい。
- iPad の YouTube検索性能確認では、通常 fixture に加えて `heavy` fixture を UI test launch env で生成し、検索キャッシュ 100 件・選択チャンネル動画 200 件の比較を取る方針にした。
  - split 右ペインの初期読込がボトルネックかを切り分けるには、同じ導線でデータ量だけを増減させた相対比較が有効なため。静的 fixture を複数持つより、seed 時に重い検索キャッシュとチャンネル動画を合成する方が、保守しやすく比較条件も明示しやすい。
- iPad の YouTube検索画面では、左右 split の初期選択に伴う H 画面読込を遷移直後に同期させず、短い遅延付きで後続実行する方針にした。
  - G 画面遷移と同時に右ペインの `openChannelVideos` まで走らせると、左ペイン表示の成立とチャンネル動画統合・自動 refresh の初期処理が競合し、遷移体感が重くなりやすいため。まずは G 画面を即表示し、H 画面はプレースホルダを挟んでから読む方が、iPad での split 初期表示が軽く見えやすい。
- 実機自動再現のため、UI Test は `HELLOWORLD_UI_TEST_MODE=1` を維持したまま、`HELLOWORLD_UI_TEST_USE_MOCK=0` で live 経路へ入れる方針にした。
  - 既存 UI Test は初期導線や hidden marker に依存していたため、単純に `UI_TEST_MODE` を切ると自動遷移も失われ、実機で同じ手順を機械的に再現しにくい。UI test 用の起動経路は残しつつ、データだけ live に切り替えられる方が、実機再現と既存 UI test の両立がしやすい。
- `DecodingError` は `localizedDescription` ではなく `keyNotFound` / `valueNotFound` / `typeMismatch` と `codingPath` を要約してログへ出す方針にした。
  - 実機での `videos.list` 失敗は HTTP 200 のあとに decode で落ちており、単に "missing" とだけ出ても、どのフィールドを optional 化すべきか判断しづらいため。`codingPath` が見えれば、レスポンスのどの item のどの field が欠けたかをモデル定義に直接つなげて確認できる。
- `pull-to-refresh` は YouTube検索の実処理を直接抱えず、`FeedCacheCoordinator` が持つ managed task を trigger するだけの構成に改めた。
  - `refreshable` の async 処理は View のライフサイクルに従って cancel されうるため、通信処理そのものをその task にぶら下げると、画面再構成や離脱で `URLSession` まで中断されやすい。UI task は開始契機だけを担い、検索本体は coordinator 側の unstructured task で所有する方が、PullToRefresh の使い方としても自然で、途中中断に引きずられにくい。
- YouTube検索の managed task は、同一 `keyword + limit` の再実行時に再利用し、通常運用では一時的な task 診断ログを残さない方針にした。
  - トラブルシュート中は `caller_cancelled` 付きの詳細ログが有効だったが、常設すると流量が増え、日常の実機確認ではノイズになりやすいため。普段は開始・通信・失敗・完了の境界ログだけを残し、task 単位の詳細診断は必要時だけ再投入する方が運用しやすい。
- YouTube検索では `cancelled` を通常失敗と分けて扱い、`screen`、`coordinator`、`service`、`transport` の各層で中断を観測した地点をログへ残す方針にした。
  - 既存ログでは `refresh_failed message="cancelled"` だけが見え、通信前に止まったのか、URLSession が中断されたのか、画面離脱に伴うキャンセルなのかを切り分けにくかったため。責務境界ごとにキャンセル専用イベントを出し、`reason` と `stage` を添えることで、実機コンソールだけでも中断地点を追えるようにした。
- YouTube検索のキャンセルはユーザー向け `errorMessage` として表示せず、キャッシュが無い場合は `未取得`、キャッシュがあれば既存結果維持として扱う方針にした。
  - `Cancelled` は調査用には有用でも、利用者にとっては復旧手順や状態が伝わらないノイズになりやすいため。キャンセルは「失敗」ではなく「途中中断」として扱い、UI には生文言を出さず、必要な詳細は `[YoutubeFeeder]` ログで追う方が、体験と調査性の両方を保ちやすい。
- YouTube検索まわりの実機調査ログは、`[YoutubeFeeder]` 接頭辞付きの一行ログとして、開始・分岐・失敗・完了の境界イベントだけを Xcode コンソールへ出す方針にした。
  - 実機不具合の追跡には経路と失敗点がすぐ見えることが重要だが、検索処理は候補収集や詳細取得でイベント数が増えやすく、詳細を出しすぎるとログが流れて肝心な失敗箇所を見失いやすいため。URL 全体やレスポンス全量は出さず、キーワード・件数・経過時間・HTTP ステータス・切り詰めた応答プレビューに限定し、ログ量を抑えながら調査に必要な文脈だけ残す。
- YouTube検索のログ責務は `FeedCacheCoordinator`、`RemoteVideoSearchService`、`YouTubeSearchService` の境界ごとに分け、共通整形は `AppConsoleLogger` に集約する方針にした。
  - 画面側や呼び出し側で自由に `print` を散らすと、同じ検索でも粒度や書式が揺れやすく、実機コンソールで追った時に比較しづらくなるため。キャッシュ判定、リモート取得、YouTube API 通信という責務境界ごとに何を記録するかを固定し、プレフィックス・時刻・メタデータ整形・トリミング規則は共通ユーティリティへ集約した方が、運用と将来拡張の両方で扱いやすい。
- `rules.md` の責務分離は上位原則に絞り、`View` / `ViewModel` 粒度、依存方向、リソース閉じ込めのような設計粒度は `architecture.md` へ寄せる方針に改めた。
  - `rules.md` に実装寄りの責務配分まで書き込むと、上位方針と設計詳細の境界が曖昧になり、変更時にどこを正本として読むべきか迷いやすいため。UI と logic の大きな分離原則だけを `rules.md` に残し、具体的な層責務や構造の説明は `architecture.md` へ集めた方が、上から読んだ時の段階差が保ちやすい。
- 文書群の共通参照正本は `document-rules.md` へ昇格し、各文書冒頭では自身の定義文以外をこの文書と `document-operations.md` へのリンクへ集約する方針に改めた。
  - 文書ごとに「どの文書を参照するか」を個別に書き分ける運用では、少しずつ表現や参照先がずれやすく、最上位ルールとしての効力が弱くなるため。`document-rules.md` を `rules.md` から切り出した文書ルールの正本として扱い、一覧ではなく切り分け基準そのものを 1 か所に寄せた方が、判断基準がぶれにくい。
- `principles.md` は廃止し、責務分離、テスト原則、評価観点のように実際に開発判断へ使う内容は `rules.md` へ再統合する方針に改めた。
  - このプロジェクトでは `principles.md` を独立させても参照経路が増えるだけで、判断時に `rules.md` と往復しやすく、運用上の主文書として機能しにくかったため。守るべき基準として使う内容は `rules.md` へ集約し、文書群の役割や運用の共通説明だけを `document-*` に分けた方が、参照先の迷いが少ない。
- 文書群の役割定義と文書運用ルールは、それぞれ `document-roles.md` と `document-operations.md` へ分離し、各文書は自身の定義文の直後にその共通正本を参照する方針にした。
  - 同じ内容を複数文書へ書き分ける運用では、意味は同じでも表現だけが少しずつずれやすく、更新時にどこが本当の正本か曖昧になりやすいため。各文書に残すのは「その文書自身の定義」に絞り、共通ルールは 1 か所へ集約した方が、定義の境界と更新責任が明確になる。

## 2026/03/19
- `rules.md` はこのプロダクト固有の意思決定ルールに絞り、横展開可能な責務分離、テスト戦略、評価観点、文書設計原則は新設した `principles.md` へ分離する方針に改めた。
  - rules にプロダクト専用ルールと持ち運び可能な知見が同居すると、意思決定基準と知識ベースの読み方が混ざり、文書の用途が曖昧になるため。`rules = 守らないと壊れる基準`、`principles = 知っていると判断品質が上がる知識` と分けた方が、文書の意味付けが明確になる。
- `architecture.md` には構造を規定する内容だけを残し、具体クラス名、UI 操作トリガ、件数や順序の運用詳細は載せない方針に改めた。
  - architecture の粒度が実装詳細や操作詳細へ下がると、設計原則の文書ではなく仕様や詳細設計の写しになってしまうため。レイヤ構造、依存方向、データフローの形、責務の原則だけを残した方が、変更時にどの文書を直すべきか判断しやすい。
- 文書階層の説明は `文書の役割` に統一し、`rules.md` の history 運用は `共通ルール` と `ファイル固有ルール` を分けて記述する方針に改めた。
  - 同じ意味の節名が文書ごとに揺れると、役割の違いなのか単なる言い換えなのか判断しにくくなるため。共通部を先に、個別部を後に置く構成へ寄せた方が、history 系文書の固有ルールも読み分けやすい。
- Markdown 文書の本文は `だ・である` 体に統一し、11 項目以上の箇条書きはサブカテゴリへ分割する方針に改めた。
  - 文体や列挙粒度が章ごとに揺れると、上位文書ほど規約として読み取りにくくなるため。長い列挙は構造を見せた方が、どこに何が書いてあるかを後から追いやすい。
- 正本の文書階層を `rules -> spec -> architecture -> design` として整理し、採用方式のようなプロダクト依存事項は `architecture.md`、ファイル単位やテスト単位の責務は `design.md` へ置く方針に改めた。
  - 上位文書へ詳細が侵食すると、変更判断の粒度が崩れ、何をどこまで更新すべきかが曖昧になるため。文書ごとの責務を 1 段ずつはっきり分けた方が、仕様変更と設計変更を追いやすい。
- `docs/human-view/design.md` は、正本の `docs/design.md` と役割が衝突しないよう `docs/human-view/design-overview.md` へ改名する方針にした。
  - human-view 側は翻訳資料であり、正本の詳細設計文書と同名だと参照時に混乱しやすいため。人間向けの俯瞰資料であることが名前から分かる状態を優先する。
- YouTube 検索の再取得では、検索中表示の可否や split 初期選択などの状態遷移を `RemoteSearchPresentationState` と coordinator の logic で固定し、UI はその状態を写像する方針に改めた。
  - 「検索したか」「キャッシュへ反映されたか」「何を表示すべきか」が UI ジェスチャや一時 view state に混ざると、不具合切り分けとテスト観測点が崩れやすいため。検索結果の保存は logic test で、表示切替は UI test で、それぞれ責務に応じて固定する。
- YouTube 検索結果画面の再検索中は、下部チップを `再検索中` へ描き替えるのではなく、古い要約を隠して上部に進行表示を出す方針に改めた。
  - 実際の refresh UI は上方向の進行表現として知覚されるため、古い要約チップを残したまま下部だけ差し替えるよりも、進行中と要約を役割ごと分けた方が誤解が少ないため。前回結果の要約は検索完了後にだけ再表示する。
- YouTube検索結果画面の下部チップは、再検索中だけ前回サマリーを出さず `再検索中` の状態表示へ切り替える方針にした。
  - pull-to-refresh 中に前回の件数や更新時刻が残っていると、新しい検索が本当に走っているか判断しづらいため。既存チップを流用しつつ、検索中だけ役割を「要約」から「進行中表示」へ切り替える。
- `gui.md` の画面一覧には `画面A` のようなアルファベット識別子と目次ショートカットを付け、パーツ名は `下部結果チップ` ではなく `チップ` に統一する方針にした。
  - 人間が会話で変更指示する時は、正式名だけより短い識別子とリンク付き目次がある方が往復が少なくなるため。パーツ名も役割が一意なら短い方が言いやすく、指示の負担を下げやすい。
- 検索結果からチャンネル別動画一覧へ入った直後の自動 feed 更新は、pull-to-refresh と同系統の上部 `ProgressView` で通知する方針にした。
  - バックグラウンドで読み込みが走っていても、ユーザーからは待機状態か通信中かが判別しづらかったため。新しい専用 UI を増やすより、既存の更新表現に寄せた方が理解しやすい。
- README は情報量を増やさず、短い見出しと区切りだけで視認性を上げる方針にした。
  - このリポジトリの README は詳細説明書ではなく入口であり、内容を足すより既存情報を整理して読ませる方が目的に合うため。簡潔さは保ったまま、読み始めやすい体裁を優先する。
- human-view の参照資料名は、役割が直感的に読める `design.md` と `gui.md` へ短くリネームする方針にした。
  - 人間向け入口資料としては、`engineering-design.md` や `gui-reference.md` よりも短く即読できる名前の方が、参照時の負荷を下げやすいため。正本との関係は本文で補い、ファイル名は簡潔さを優先する。
- Adaptive UI 注記は、クラス外の note ではなく、対象 View クラスの枠内へ改行付きで入れる方針に改めた。
  - ユーザーが見たいのは「どの機能 View が Adaptive UI か」であり、注記の位置がクラス本体から離れると対応関係が弱くなるため。記号そのものより位置を優先し、枠内表示を第一にする。
- Markdown のファイルリンク表示は、パスを含めずファイル名のみを見せ、実際のリンク先だけを相対パスで解決する方針に改めた。
  - 参照時に必要なのは「何のファイルか」であり、表示上のパスは視認性を下げやすいため。リンクとしての正確さは保ったまま、見た目は最小限に揃える。
- `開発シーケンス` はユーザー指示からコミットまで、`開発セッション` は日次ローテーションで閉じる運用単位として定義し、docs-only でも各シーケンスをコミットで閉じる方針に改めた。
  - ドキュメント作業だけを未確定のまま積み残すと、どの指示がどこまで完了したかが曖昧になりやすいため。コミット粒度が細かくなっても、1 指示 1 完了の境界を明確にした方が履歴として追いやすい。
- `human-view/engineering-design.md` の Adaptive UI 注記は、GitHub の Mermaid でも安定して描画できる `note for ... "<<Adaptive UI>>"` 形式を使う方針に改めた。
  - 直前の separate-line annotation は GitHub 上で parse error になり、参照資料として成立しなかったため。人間向けの簡略化方針は維持しつつ、描画互換性を優先する。
- Markdown 内のファイルリンク表示は、リンク先の相対関係に引きずられず、`ファイル名[リポジトリ相対パス]` で統一する方針にした。
  - `../` や深いサブディレクトリ表記がそのまま見えると、閲覧時に実際の配置と表示上の経路が混ざって読みづらいため。表示は常に repo 基準へそろえ、リンク自体の解決だけを各文書位置に任せた方が分かりやすい。
- `human-view/engineering-design.md` の Adaptive UI 図示は、`CompactView` / `RegularView` の個別クラスを並べず、機能 View に `<<Adaptive UI>>` を注記して簡略化する方針にした。
  - 人間向けの設計資料では、表現差分クラスをすべて展開すると図の複雑性が上がり、機能責務の把握よりレイアウト差分の追跡に意識が引かれやすいため。Adaptive UI の存在は残しつつ、正本との対応関係を保ったまま読解コストを下げる。
- `human-view/gui-reference.md` の `画面遷移` は図中ラベルから `〜画面` を省略し、`画面一覧` の正式な `画面名` は維持する方針にした。
  - 遷移図では全ノードが画面であることが自明であり、接尾辞を毎回含めるより短いラベルの方が見通しが良いため。一方で、画面指示に使う正式名称は一覧側で保持した方が、会話上の呼び名を安定させやすい。

## 2026/03/18
- `docs/human-view/` を、人間向けの翻訳資料置き場として新設し、GUI 参照資料と UML 風設計資料をここへ集約する方針にした。
  - `spec.md`、`rules.md`、`architecture.md` が正本であることを配置から明確にしつつ、人間の開発者が最初に読む入口資料は保ちたかったため。正本ではないことを明示しながら、常時同期対象として扱う構成が最も誤読を減らしやすい。
- Adaptive UI の表現差分 View は、親が機能名、子が `CompactView` / `RegularView` と読める命名へ寄せ、GUI 資料では split 専用画面として露出しない方針にした。
  - `Split...View` という名前が資料や会話に出ると、同一機能の adaptive 差分ではなく別画面のように見えやすいため。実装上の分割は維持しつつ、親子関係と役割が名前から読める方が、機能設計と資料表現の整合を取りやすい。
- 動画タイルは `VideoTile`、単独画面のチャンネルタイルは `ChannelTile` へ改名し、全タイルの長押しは 0.5 秒で独自メニューを開く方式へ統一する方針にした。
  - SwiftUI の `contextMenu` では長押し時間を直接指定できないため。検索結果のように既定メニューが無い画面でも `未定義` を表示できるよう、タイル側で 0.5 秒長押しメニューを共通化した方が、今回の UI 要求と GUI 資料の整合を取りやすい。
- GUI 設計資料のパーツ名は、同一役割なら画面をまたいでも同名にそろえ、共通パーツ章は廃止して各画面の中で完結して読める形にする方針へ調整した。
  - 指示側が `LongPressVideoTile` の実装名を知らなくても、`動画タイル` や `空状態タイル` のような安定した呼び名で伝えられることが重要なため。資料を読む時に別章へ往復しなくてよい構成の方が、GUI 指示の参照表として使いやすい。
- 画面指示用の GUI 設計資料として `docs/gui-reference.md` を追加し、画面名、パーツ名、遷移、実装名を 1 か所へ整理する方針にした。
  - チャット上で GUI 修正を指示する時に、画面上の呼び名と実装上の呼び名がずれると指示コストが上がるため。`spec.md` を機能要件の正本に保ったまま、GUI 指示の参照資料を別に持つ方が継続運用しやすい。
- `metrics` 文書は docs-only 作業の不実測項目を残さず、実際に計測したコミットだけを記録する方針に改めた。
  - `metrics実測: 不要` のような項目まで履歴へ積むと、性能や検証コストの履歴としての純度が下がり、後から実測値だけを追いにくくなるため。docs-only の作業履歴は `chat` と `decisions` に残し、`metrics` は実測結果の正本に絞る。
- ルート案内用に `README.md` を追加し、`AGENTS.md` から `docs/rules.md` へ即座に辿れるリンクを置く方針にした。
  - このリポジトリでは公開向け紹介よりも、LLM 主導で何を作っているかと、どの文書を最初に読むべきかが早く伝わることの方が重要なため。短い README と最小限の入口リンクで、着手コストを下げる。
- ルート直下の運用文書は `docs/` へ集約し、日次履歴の `*-log.md` と `*-latest.md` は `docs/history/` へ分離する方針にした。
  - 正本ドキュメントと履歴バッファを階層で見分けられるようにしておくと、作業着手時に読む文書と日次記録の置き場が明確になり、今後の参照更新や自動化スクリプトの保守もしやすくなるため。
- 新規開発セッション開始時は、通常の実装プロセスへ入る前に `rules.md` の再確認と、必要なら `*-latest.md` から `*-log.md` への日次ローテーションを先に済ませる方針にした。
  - 当日バッファの初期化を着手直後の標準手順として明文化しておくと、古い `latest` を引きずったまま文書更新を始める事故を避けやすく、以後の `chat`、`decisions`、`metrics` の記録開始点も揃えやすいため。

## 2026/03/17
- 最終の全体検証は `collect_metrics.sh` を正本とし、`metrics-latest.md` と `test-metrics.md` を同じ全体 test 実行から同時更新する方針にした。
  - `collect_test_metrics.sh` と `collect_metrics.sh` を別々に全体実行すると、同じ suite を 2 度流して無駄な待ち時間が発生するため。部分集合確認は `collect_test_metrics.sh` に残し、最終の full run は 1 回に寄せる。
- 先に追加した failing test をその後の実装で通す `赤 -> 緑` は、retry 回数に数えない方針を明記した。
  - これは仕様固定のための正規プロセスであり、失敗に対するやり直し回数と混ぜると、実際の手戻り量を過大評価してしまうため。
- 分割ブラウズ UI の有効化条件は、アプリ独自の `landscape` 判定ではなく `horizontalSizeClass == .regular` を使う方針に改めた。
  - `iPad` の縦横による挙動差は Adaptive UI 側の責務として扱うため。アプリ側で `regular width && landscape` を固定すると、要求から外した向き依存ルールを実装が持ち続けてしまうため、幅クラスベースへ寄せる。
- `iPad 縦向き` と `iPad 横向き` を要求文書で直接規定するのをやめ、`単独画面` と `Adaptive UI による分割レイアウト` へ表現を寄せる方針にした。
  - `iPad` と `iPhone` の両対応は維持しつつ、縦横の振る舞いそのものを要求へ固定すると OS 側の adaptive behavior と競合しやすいため。要求では機能と体験を記述し、向き依存の細部は UI 基盤と実装側の責務へ戻す。
- YouTube 検索結果画面の chip 表示状態、段階表示件数、split 初期選択は `RemoteSearchPresentationState` として pure logic へ切り出し、UI テストはユーザー導線だけを残す方針にした。
  - `sleep` や `iPad` 専用の adaptive layout 確認を UI テストへ残し続けると、計測コストが高い割に OS 側責務まで再検証しやすいため。`AppLayout` と presentation state を unit test で固定し、UI では refresh、遷移、ユーザー操作による chip dismissal のような画面契約だけを観測する。
- テスト時間計測は、各テスト本体を変更せず、`XCTestObservation` で開始・終了イベントをログへ流し、`scripts/collect_test_metrics.sh` で `test-metrics.md` へ集約する方針にした。
  - テストコード自体へ個別の計測処理を埋め込むと、本来の検証内容まで触ってしまい保守が重くなるため。共通観測層でテスト ID と時刻だけを取り、後段スクリプトで `logic` / `ui` や領域別に整形する方が、変更の影響範囲を小さく保てる。
- metrics と decisions の当日文書は、同じ日付見出しの中でも新しい項目ほど上へ積み増す方針を明記することにした。
  - `chat` と同様に最新差分を先頭側で読めた方が、その日の運用判断とトークン節約の目的に合うため。`metrics` も `decisions` も、日付見出しの中で逆時系列を維持する。
- 文書運用は `metrics-log.md`、`decisions-log.md`、`chat-log.md` を履歴保持先とし、当日更新は対応する `*-latest.md` に分離する方針に改めた。
  - 履歴ファイルが無制限に伸びると、毎回の読み込みでトークン消費が増え、当日の差分確認もしづらくなるため。日次ローテーションで履歴を保ちながら、その日の作業対象だけを軽く保てる構成を優先する。
- `rules.md` は `開発プロセス` と `開発中の判断基準` を主軸に再構成し、段取りの規定と判断の規定を分けて読む方針にした。
  - 旧構成では `変更時の判断ルール` と `変更管理ルール` の両方に、順序と判断項目が混在しており、似た内容が別節へ散りやすかったため。プロセスを 1 周の流れとして明示し、各場面で参照する基準を別節へ寄せる方が、LLM と人の双方にとって追跡しやすい。

## 2026/03/16
- YouTube検索結果の `iPad 横向き` は、チャンネル一覧と同じく `NavigationSplitView` で左に検索結果、右にチャンネル動画を出す方針にした。
  - `iPad 縦向き = iPhone 同等` という既存仕様を崩さず、広い横幅だけで比較導線を強める方が整合的なため。先行試行では縦向き UI test が split 条件に合わず詰まったので、仕様とテスト条件を一致させた。
- 動画タイルの番号は右上バッジをやめ、右下の情報バッジを `No : 再生時間 再生数 (M/L)` へ統合する方針にした。
  - 再生数、再生時間、検索区分と番号を別々の場所へ出すより、1 か所にまとめた方が視線移動が少なく、UI test でも観測点を減らせるため。番号は動画一覧のローカル順序を示す用途なので 0 始まりにそろえる。
- YouTube 検索結果の再生数表示は `videos.list` の `statistics` を必須として取得する方針にした。
  - 検索結果タイルは右下へ再生数を常時出す仕様だが、詳細取得の `part` に `statistics` が含まれていないと `--回` のままになってしまうため。`search.list` の候補取得と `videos.list` の詳細取得を分ける構成は維持しつつ、詳細側で再生数を確実に埋める。
- `iPad` の 1 列リストは、複数列化ではなく readable width の制限で読みやすさを確保する方針にした。
  - Apple の `readableContentGuide` と WWDC の readability margins の考え方に合わせ、広い画面でも行長を抑えた方が視線移動が安定するため。今回は 1 列表示を保ったまま、リスト系画面の最大本文幅を `920pt` に制限する。
- チャンネル一覧の `Tips` タイルは、表示内容を unit test、存在と非操作契約を UI test で担保する方針にした。
  - 直近の検証では、件数や並び順の文言まで UI test へ載せると観測点の不安定さで試行が増えやすかったため。`Tips` タイル自体の存在は UI 層の契約として残し、サマリー文言は `ChannelBrowseTipsSummary` の pure logic として unit test で固定する。
- UI テストは画面でしか担保できない契約へ絞り、非同期表示内容の細部は unit test や marker ベースへ寄せる方針にした。
  - 直近の試行では、軽い UI 追加に対しても UI テストが過渡状態や非同期収束まで抱え込み、feature の欠陥より観測点の不安定さでリトライが増えたため。導線の破壊検知は UI test に残し、表示内容の細部はより安定した層へ下ろして、開発速度と開発精度の両立を優先する。
- 開発バロメタに `LLM試行回数` と `同一論点の再試行回数` を追加し、しきい値超過時は実装を止めて再判断する方針にした。
  - 実装上の問題ではなく、設計やテスト戦略の不整合で同じ論点のリトライが続くと、作業時間だけが伸びて精度も落ちやすいため。一定回数を超えたら自力で押し切らず、ユーザーへ状態を返して方針を立て直す方が安全である。
- 機能追加でも、不具合修正と同様に先行テストで仕様を固定してから実装する方針にした。
  - 実装後にテストを書く運用だと、既に出来上がったコードへ説明を合わせる形になりやすく、仕様競合や成立不能条件の発見が遅れやすいため。先に失敗テストで期待挙動を明示し、追加・削除を含む仕様変更ではテストも同時に更新することで、変更の正当性を早い段階で確認できるようにする。
- YouTube検索結果からチャンネルへ入る導線は、チャンネル名と選択動画 ID を route context で引き継ぎ、必要時だけ自動 feed 更新する方針にした。
  - 検索結果の動画タイルから入った直後にチャンネル名すら出ないと文脈が切れやすく、かといって毎回無条件で更新すると API 呼び出しが増えて操作も重くなりやすいため。検索時に取得済みのチャンネル名を初期表示へ使い、local feed cache が未作成か選択動画が欠けている時だけ更新して不足分を補う。
- build を `warning 0` まで含めて完了条件とし、project 全体の既定 actor 隔離は `MainActor` へ広げない方針にした。
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` を app target へ広く掛けると、UI 以外の model や parser、test まで main actor 隔離として扱われ、Swift 6 互換警告が雪だるま式に増えて保守性を落とすため。UI 主導の型だけを明示 `@MainActor` に戻し、あわせて `AppIntents` 未使用 target の metadata warning は弱リンクで抑えて、検証を warning-free に保つ。
- 不具合修正では、想定原因ごとの失敗テストを先に追加してから修正する方針にした。
  - 症状だけ見て直接直し始めると、真因を取り違えたまま別経路を壊しやすいため。原因仮説ごとに再現テストや非再現テストを置いてから直すことで、修正の狙いと回帰防止を同時に残せるようにする。
- スワイプ系 UI テストは、実ジェスチャーだけに依存せず、test support のダミー trigger でも同等イベントを起こせる方針にした。
  - pull-to-refresh や drag gesture は simulator で揺れやすく、バグ再現用の回帰テストまで不安定になると保守性が下がるため。ユーザー体験は実機や通常 UI テストで担保しつつ、機能回帰の検証には専用 trigger を併用できるようにした。
- 本アプリの基準アーキテクチャは、過剰な抽象化を避けた `MVVM + Clean Architecture` と明示する方針にした。
  - 現状の責務分割は概ねその方向に寄っていたが、規範が曖昧なままだと今後の変更で coordinator への責務逆流や View からの直接 I/O が再発しやすいため。基本モデルを明文化しつつ、protocol の量産までは求めない運用にした。
- `FeedCacheCoordinator` の依存は内部生成ではなく app layer の composition root から注入する方針に改めた。
  - coordinator が `Store` や `Service` を自前で new すると、Clean Architecture の依存方向が緩み、テスト差し替えや将来の分割も難しくなるため。まずは `AppDependencies` で live dependency を束ねる形へ寄せ、複雑度を増やさず境界だけ整える。
- 実装健康度は `scripts/health_barometer.sh` を正本の軽量点検として継続観測する方針にした。
  - 障害復旧の難化は機能単体の正しさだけでなく、責務越境、巨大ファイル、長大関数、状態公開量の肥大化を早期に見逃していたことが要因になりやすいため。数値しきい値を `rules.md` に置き、毎回同じ物差しで悪化を検知できるようにする。
- FeedCache まわりの広域責務は coordinator へ積み増さず、registry 保守、検索再取得、ホーム状態集約、固定パス / bootstrap / registry 永続化へ分割する方針にした。
  - coordinator が検索 API、ホーム状態、registry 入出力、リセット処理まで抱えると、障害原因の切り分けと局所修正が難しくなるため。MVVM を過剰に形式化するのではなく、意味のある service / store 単位へ責務を戻して更新容易性を保つ。

## 2026/03/15
- レガシー cache / bootstrap から channel registry を自動復旧する処理は撤廃し、channel registry を唯一の正本として扱う方針に改めた。
  - 旧形式データを実行時に救済し続けると、更新経路や削除経路まで複雑化しやすく、現行仕様の保守性を下げるため。復旧手段はバックアップ読込へ絞り、最新環境の単純さを優先した。
- ホームには destructive 操作として `全設定リセット` を追加し、この端末内の設定とキャッシュをまとめて破棄できるようにした。
  - レガシー由来の不整合を引きずるより、ユーザーが明示的に初期化してバックアップから戻せる方が運用しやすいため。バックアップファイルだけは残し、最悪でも復旧経路を失わないようにした。
- 実機の不具合調査は、物理 `iPhone 12 mini` の foreground 操作を維持したまま、ランタイムイベントを構造化ログでコンソールへ流す方針にした。
  - ユーザー自身が端末を操作する前提では、UI テストの marker だけでは途中経路を追い切れないため。更新ジェスチャー、フィード取得、整合性メンテナンス、UI 反映を stdout ベースで追えるようにし、LLM 側からリアルタイム解析できる経路を優先した。
- YouTube 検索結果は上書きではなく履歴マージとし、表示は 20 件ずつの段階読み込みにする方針にした。
  - 検索結果が増えても API クォータを無駄にせず再訪価値を保ちつつ、一度に大量描画して一覧体験を重くしないようにするため。保存責務は cache 側、表示責務は browse 側へ分けて伸ばしやすい形を優先した。
- 動画タイルの通常タップはチャンネル別動画一覧へ統一し、`YouTubeで開く` はチャンネル別動画一覧の長押しに限定する方針にした。
  - 一覧ごとにタップ結果がばらつくと操作感が崩れやすいため。まずは「動画からチャンネル文脈へ入る」を標準動作にそろえ、外部アプリ起動は意図の強い長押し操作へ寄せた。
- 動画タイル右下には、再生数と時間区分 `M` / `L` をデバッグ兼状態確認として常時表示する方針にした。
  - YouTube 検索が `medium` / `long` をマージしていることを目視確認しやすく、通常一覧でも再生時間から同じ区分を逆算して同じ見え方を保てるため。追加の画面や設定を増やさず、既存タイル内で観測可能性を高める。
- YouTube 検索画面は、画面表示時に自動取得せず、pull-to-refresh でだけ API 検索を走らせる方針に改めた。
  - 検索 API は feed 更新より明確にクォータ消費が重く、ホームから誤って開いただけで毎回消費するのは避けたかったため。画面遷移ではキャッシュだけを見せ、実検索のタイミングはユーザー操作へ委ねる。
- YouTube 検索は `medium` と `long` を別々に search し、`videos.list` でライブを除外してから 1 回分の結果へ統合する方針にした。
  - Shorts 寄りの動画を抑えつつ長尺の取りこぼしも減らしたかったため。search の取りこぼしを duration 分割で補い、最終的な表示責任は `videos.list` 側へ寄せることで、一覧用の正規化ポイントを 1 つにする。
- YouTube 検索 API キーは、リポジトリへ置かず ignored なローカル xcconfig から build 時に注入する方針にした。
  - API キーをソースや追跡ファイルへ含めると漏えい面が広がりやすいため。開発時の利便性は保ちつつ、コミット対象からは外し、配布物には build setting 経由で必要最小限だけ渡す。
- YouTube 検索 API のキーは、URL クエリではなく HTTP header で送る方針にした。
  - クエリ文字列はログや履歴へ残りやすく、意図せず露出しやすいため。header の方が取り回しが安全で、公式のベストプラクティスにも沿いやすい。
- ホームの `ゆっくり実況` 検索は、既存動画キャッシュ検索とは別に YouTube 検索 API を使う専用導線として追加する方針にした。
  - 既存キャッシュ検索だけでは登録チャンネル外の新着探索ができず、検索の意味がキャッシュ閲覧に閉じていたため。固定キーワードの導線は保ちつつ、検索元だけを分けて `キャッシュ検索` と `YouTube検索` の責務を明確にし、ホームでの操作感は揃える。
- YouTube 検索 API の結果は、通常キャッシュとは別ファイルで長めに保持し、同じ検索で毎回 API を叩かない方針にした。
  - ホームから何度か行き来するたびにネットワーク検索が走ると、応答時間も API 消費も不安定になりやすいため。固定キーワードの検索導線は即時性を優先し、明示的な再取得は pull-to-refresh に寄せる。
- ホームには押せるタイル群とは別に、非操作のシステム状況タイルを置く方針にした。
  - 導線を増やしすぎずに、現在の登録件数、動画キャッシュ量、検索キャッシュ状態、API 設定有無を把握できる方が運用上わかりやすいため。ボタン風の見た目を避け、情報表示であることを視覚的に分ける。
- ホームの検索導線は自由入力画面を増やさず、固定キーワードの即時検索タイルとして追加する方針にした。
  - 今回の目的は検索機能の導入そのものより、既存キャッシュを別の切り口で素早く見せることにあるため。まずは `ゆっくり実況` の固定検索で一覧導線を追加し、画面数と入力負荷を増やさず統一操作感を保つことを優先した。
- 監査で肥大化が目立った画面 / 更新処理は、機能を変えずに責務単位のファイル分割で整理する方針にした。
  - 変更要求が増えるたびに巨大ファイルへ追記していくと、影響範囲の見通しとレビュー効率が落ちやすいため。まずは画面本体、共有 UI 部品、更新実行サービスを分け、どの責務へ手を入れる変更かを読み取りやすくすることを優先した。
- チャンネル別動画一覧の下方向スワイプは、全体更新ではなく選択中チャンネルだけの強制更新に割り当てる方針にした。
  - チャンネルを見比べている最中は、他チャンネルまで巻き込んだ全体更新より、その場で見ている 1 チャンネルだけを即座に更新できる方が操作意図に合うため。ホーム画面の全体更新と役割を分け、統一操作感を保ちつつ無駄な更新負荷も避ける。
- バックアップ読込後の最新情報再取得は、ホーム画面の処理完了を待たせずバックグラウンドで進める方針に改めた。
  - 端末内に多数のチャンネルがあると、読込成功後も `処理中...` が長く残って操作不能に見えたため。読込完了と再取得開始を分け、まずユーザ操作を返すことを優先した。
- チャンネル削除は画面を増やさず、既存の一覧タイル長押しメニューへ載せる方針にした。
  - 一覧閲覧中の文脈でそのまま削除できた方が操作感が揃いやすく、ホームへ戻って別導線を探させる必要もないため。動画タイル側にも同じ長押しメニューを用意して、統一操作感を優先した。
- チャンネル一覧の正本はアプリ内 resource ではなく、ローカル registry のみとする方針に改めた。
  - チャンネル情報はユーザ固有の設定として扱う方が自然であり、バックアップ / 復元の単位も registry に揃えた方が実装と運用の整合が取りやすいため。現在の仕様説明やコードから、組み込みチャンネル前提は外した。
- 端末内バックアップは、追加チャンネルだけでなく、その時点で利用中の全チャンネル情報を保存する方針にした。
  - 将来アプリ内部の組み込みチャンネルリストを削除する過渡期でも、バックアップから利用中チャンネル群を戻せる必要があるため。復元時は全チャンネルをローカル registry 側へ保持し、組み込み定義が消えた後でも成立するようにした。
- `iCloud` を使う引き継ぎ仕様は当面撤回し、同じホーム導線のまま「この端末内のバックアップ / 復元」へ後退させた。
  - Personal Team では `iCloud` capability を使えず、通常ビルド自体が成立しなかったため。GUI の操作感はなるべく維持しつつ、他デバイス移動ではなく 1 デバイス内バックアップとして成立する範囲へ仕様を戻した。
- CLI 検証の `DerivedData` はリポジトリ直下ではなく `~/Library/Caches/Codex/HelloWorld/DerivedData` を使う方針にした。
  - このワークスペースは `Documents` 配下にあり、repo 直下へ build 生成物を置くと file provider 由来の拡張属性が app bundle に付いて codesign が失敗したため。Xcode の標準運用にも近い同期対象外のキャッシュ領域へ逃がして、検証フロー自体を安定させる。
- 開発統計と起動性能は、都度の印象ではなく `metrics-log.md` へ継続記録し、CLI から再取得できる形を正本とする。
  - build 時間や test 時間、起動所要時間は、体感だけでは劣化に気づきにくいため。コミット単位で履歴を持ち、UI テストの timeline と `xcodebuild` の実行結果から同じ方法で採り直せるようにして、設計の判断材料を残す。
- UI テストは、重複するホーム導線確認を 1 本のワークフローテストへまとめ、画面個別テストでは初期遷移指定を使う方針にした。
  - UI テストの主要な所要時間はアプリ起動回数に偏っていたため。確認項目を維持したまま起動回数を減らし、個別画面のテストは test support 側で直接その画面へ入れるようにして待ち時間を圧縮する。
- ホームの `チャンネル` 導線は別画面を増やさず、タイル上の `Menu` から並び順を選んで一覧へ入る方式にした。
  - 並び替え条件を増やすたびに画面を増設すると操作感が散りやすいため。既存導線の中で完結させ、今後 `指標 + 順序` の組み合わせが増えても同じ操作感で拡張できる形を優先した。
- チャンネル登録レジストリには `Channel ID` だけでなく登録日時も保持するようにした。
  - `チャンネル登録日時` を一覧の並び替え指標として使うには、登録時点の時刻を永続化して再利用できる必要があるため。後方互換を保って既存データも読める形にした。

## 2026/03/14
- Apple 推奨のデザインおよび実装パターンは、特別な理由がない限り標準を積極的に採用する方針とした。
  - UI やナビゲーションを独自方式で抱え込みすぎると、保守性、予測可能性、将来の拡張性が下がりやすいため。明確な利点がない限り、Apple 標準へ寄せることを基本方針とする。
- 一覧タイルの比率固定は、タイル全体へ `aspectRatio` を掛けるのではなく、外枠のベースレイヤーを `16:9` に固定し、その上へ画像や文字を `overlay` で載せる方式にした。
  - 一瞬だけ正しい比率で表示された後に縦へ伸びる挙動があり、内部コンテンツのレイアウト変化が高さ計算へ干渉している可能性が高かったため。外枠主導の寸法固定にすることで、見た目の安定性を優先した。
- 動画一覧とチャンネル一覧のサムネイル付きタイルは、多列グリッドではなく 1 列の中央寄せ表示に統一した。
  - タイルを敷き詰めるより、サムネイルの見え方と比率を優先した方が現在の用途に合っていたため。まずは一覧の視認性と寸法の一貫性を優先する。
- iPad 横向きのチャンネル閲覧 UI は、自前の `HStack` 分割ではなく `NavigationSplitView` を採用した。
  - SwiftUI の適応的な標準コンテナへ寄せることで、端末差分を独自実装で抱え込みすぎないようにするため。将来の保守と拡張を見据えて、Apple 標準の振る舞いを優先した。
- 上位方針と実装詳細を同じ文書へ統合する方針は撤回し、`rules.md` を上位原則、`architecture.md` を実装詳細として分離した。
  - `rules.md` には長期的に維持したい判断基準だけを残し、現状実装や機能詳細を入れすぎない方が、文書の役割が明確で継続運用しやすいため。
- 通常のプロジェクト文書ファイル名は小文字に統一し、`spec.md`、`architecture.md`、`todo.md` を採用した。
  - 一般的な Markdown 文書では小文字命名が多数派であり、リンク、参照、運用の一貫性を保ちやすいため。`README.md` のような慣例名だけを例外にする方針とした。
