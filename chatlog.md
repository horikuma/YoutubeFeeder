## 2026/03/13

- ここまでの私の発言を、省略やまとめることなく、そのまま chatlog.md に出力せよ。見出しは ## 2026/03/13 とし、その下に箇条書きとせよ。この時、古いものほど下へ、新しい発言ほど上になるように配置すること。
- 大いに問題があったが、表示されただけで満足だ。コミットしよう。テスト計画はまた明日考える。
- buildfailedが出た。
- 一旦テストは打ち切って、機能をiPadデザインにも対応する。iPhoneはそのままで良い。iPad向きに調整せよ。UIとロジックは切り離し、機能的な部分は共有可能にせよ。
- ではテストを実行せよ。
- [DRAFT] としてコミットせよ。
- ここまでをコミットした上で、UIテストを追加せよ。エミュレータでなく実機テストで遠隔操作でも良い。ただしテストする時はネットワークを経由せずに、ダミーデータを読み込んで実行するように。またその時書くタイミングのタイムスタンプもとり、処理負荷が悪化したのを検知できるようにせよ。スタブ等は任せる。
- ここまでの機能がデグレしていないかをテストできるよう、単体テスト機能を追加して。エミュレータ状でテストデータを入れて操作テストとかできるか？
- 結構、コミットして。
- チャンネル一覧は縦スクロールする、動画一覧は、チャンネル選択でとんでも、メンテナンスの動画からとんでも、縦スクロールしない。これを元に、チャンネルいちらんの振る舞いを動画にも適用して。
- 動画いちらん、チャンネルいちらん、ともにたてすワイプが機能しなくなっている。
- チャンネル一覧から動画いちらんへ飛んだ先のがめんで、縦スクロールが機能しなくなっていた。こういった画面毎の差が出るとテストが厳しいので、構成を見直しアイテム一覧表示がめんの振る舞いを各所に分散しないようリファクタして。
- 今度はアイテムの長押し判定が優先されて、動画が表示されてしまうようだ。動画表示自体は１秒静止状態でタップ、をトリガーにしよう。完全に不動は難しいので、適当なウェイトを設定して。
- 今度は縦スクロールができなくなった。タップから最初の移動量のベクトルを見て、上下が多いか左右がおおいkあで、いっしゅんウェイトを入れて判断を分岐してくれ。
- 左スワイプと判断した時は、上下スクロール動作を止めたい。滑るような違和感がある。
- スワイプの操作に違和感がある。特に動画やチャンネルのあいこんに指がかかっているトスワイプが効いていないのではないか。どこを触っていてもスワイプならスワイプで、左側で下がめんに戻りたい。
- 多少良くなった。この辺りの追求は別途やるとしてコミットしよう。
- アプリの操作で非常に固まりやすい。キャッシュ取得動作が操作に影響している可能性はないか？チャンネルいちらんや動画一覧を表示している時、リアルタイム更新は走らせない。キャッシュ取得はあくまでバックグラウンドで走らせ、一度戻って再表示した時にさいしんの情報に更新すれば良い。また左スワイプで下の画面に戻れないが、重いからなのか機能がないのかはんだんできない。
- 起動が重い問題は棚上げしよう。TODOとしてアプリの開発でのちに着手できるよう、残してコミットしてくれ。アプリ画面に出す必要はない。プロジェクトから参照できれば良い。
- 対策を反映しよう。まずHelloWorldは最速で表示する、それ以外のことは何をしない。次にHelloWorldを表示している間に、メンテがめんの前回終了時のキャッシュを読み込み、メンテがめんだけ最速で表示する。メンテがめんの下の方のチャンネル情報３つ並んでいるのは削除する。ひとまずここまでだ。
- HelloWorldの表示に１０秒、そこからメンテナンス画面への遷移に３０秒ほどかかる。アプリが大きすぎるのか？それとも最初からキャッシュを読み込もうとしているのか？このレスポンスの悪さは看過できないので、調査して仮説を出して。
- # AGENTS.md instructions for /Users/ak/Documents/Codex
  
  <INSTRUCTIONS>
  ## Skills
  A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.
  ### Available skills
  - openai-docs: Use when the user asks how to build with OpenAI products or APIs and needs up-to-date official documentation with citations, help choosing the latest model for a use case, or explicit GPT-5.4 upgrade and prompt-upgrade guidance; prioritize OpenAI docs MCP tools, use bundled references only as helper context, and restrict any fallback browsing to official OpenAI domains. (file: /Users/ak/.codex/skills/.system/openai-docs/SKILL.md)
  - skill-creator: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations. (file: /Users/ak/.codex/skills/.system/skill-creator/SKILL.md)
  - skill-installer: Install Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. Use when a user asks to list installable skills, install a curated skill, or install a skill from another repo (including private repos). (file: /Users/ak/.codex/skills/.system/skill-installer/SKILL.md)
  ### How to use skills
  - Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
  - Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
  - Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
  - How to use a skill (progressive disclosure):
    1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
    2) When `SKILL.md` references relative paths (e.g., `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
    3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
    4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
    5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
  - Coordination and sequencing:
    - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
    - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
  - Context hygiene:
    - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
    - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
    - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
  - Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.
  </INSTRUCTIONS><environment_context>
    <cwd>/Users/ak/Documents/Codex</cwd>
    <shell>zsh</shell>
    <current_date>2026-03-12</current_date>
    <timezone>Asia/Tokyo</timezone>
  </environment_context>
  HelloWorldの表示に１０秒、そこからメンテナンス画面への遷移に３０秒ほどかかる。アプリが大きすぎるのか？それとも最初からキャッシュを読み込もうとしているのか？このレスポンスの悪さは看過できないので、調査して仮説を出して。
- コミットしよう。
- チャンネル情報の取得と、動画情報を取得を分離せよ。チャンネル情報を取得した際、先頭の３つだけ優先し、残りは後回しとすることで、見た目状の速度をあげよ。メンテナンスのチャンネルをタップした時、動画投稿が最新じゅんのチャンネル一覧を並べ、動画いちらんと同じように見れるようにせよ。またその画面からさらにチャンネルにタップした時、そのチャンネルの動画一覧を表示されるようにせよ。戻る時は左スワイプだ。
- コミットせよ。
- ２で良い。
- む、ギットリポジトリを作成せよ。さっきまでのコミットしじはどこに何をコミットしてたんだ？
- 初回のキャッシュ進捗が１０秒感覚になったのが反映されていないように見える。
- ここまででコミット。
- チャンネル更新チェックしたタイミングを記録し、その日１回目は、１０秒おきにこうしんして。この時、Feed取得プロセスで軽減化可能な余地があるなら適用して。例えばフィード取得前に更新有無がわかるなら取得しないなど。フィードはもっともさいきんの動画投稿が新しいものほど上に持ってきて、最新フィードを取得する実効性をあげよう。フィード尾が更新されているかどうかの判定は１時間おきに走らせる。ここまででGO。
- コミットして。
- 起動から操作できるようになるまで１分ほどかかる。起動シーケンスを見直し、操作自体はもっと早く始められるようにしてほしい。
- でざいんに関しては、最初に出した動画一覧が良かったので、見た目だけ復活させてほしい。２つか３つ前のコミット。また動画一覧に表示するのは動画だけで、ショートは除外する。
- ここまでをコミット。
- メンテナンス画面を整理する。チャンネルタップでチャンネルいちらん、その中のチャンネルタップでそのチャンネルの動画いちらん、はOK、戻る時、左上のぼたんではなく左スワイプで戻るようにする。当初、メンテナンス画面と、スワイプで動画いちらんとしていたが、この動画一覧は廃止する。メンテナンスがめんの動画アイテムをタップした時に、チャンネルをタップした時と同様に動画一覧が表示されるようにする。サムネイルアイコンは削除する。現在処理中、最終更新はボタンではなくし、さらに下のチャンネル状態を削除し、直見た目はチャンネル状態っぽい感じで現在の最新のキャッシュの状態をリアルタイムで表示する。
- さらに最短で表示するHelloWorld画面を作成し、その後メンテナンス画面へ遷移するようにせよ。こうすることで、起動時に何が原因で遅くなっているのかを特定する。
- ではこのキャッシュを活用できるよう、IFを整備しよう。フィードは前回取得時から更新があったっ時だけ取得、のような仕組みはあるか？
- このキャッシュはアプリを終了しても再利用可能か？
- 一度がめんから離れて、フィードを収集しキャッシュする仕組みを構築したい。起動するたびにフィードを取得するとアクセスエラーをもらいかねないので、1分に1チャンネルずつ取得し、そのキャッシュを整形して表示する形にする。一旦画面への出力は取りやめ、今何チャンネル中なんチャンネルのデータをキャッシュできているかの進捗がわかる形にしたい。このキャッシュは、今後、例えば登校日毎に並び替えるとか、キーワードで検索するとか、そういった活用を視野に入れた形であるべきだ。サムネイルについても同様で、速やかな表示や切り替えのため、付随する登校日などの情報と主にキャッシュに格納しておくべきだ。
- ここまででコミット。
- 次のリソースはYoutubeのチャンネルリストだ。これをリソースとして格納し、先頭のチャンネルのFEEDを取得し、投稿動画を新しい順に、先ほどと同じようにタイルに並べスクロールできるようにして。
  
  UC-HNwUxGklhKSe67EitgqgA
  UC-SN2rH5TZR_tka1YYXiqfA
  UC-bzak-AVb3kTUSsijWc2AQ
  UC-gQn9jShG7v1VrmVnwSedA
  UC-hYwh8GAMtEigRrAs97llw
  UC-j8gtFtLrwwwf1Pm3eLH7g
  UC-lFtrLtDob9zaYnXiu4AhQ
  UC08BWOux8OI84Zg5O8lzPLw
  UC0_ddviJmfisHD328CAKmTg
  UC1c7O4ia4J5Nj9K_ORda5wQ
  UC1ly3VDPq4AUuHBH8TONflA
  UC1ndqbfEtUU1jLuJjtLHFaw
  UC1pACXxUjIWNDuU-kY1OX0Q
  UC1s9QtoAUdt6u4klNFePCUA
  UC2-hRIDWzqAnTjOxdLDmhCA
  UC29mFGKxSkn0lrj03_xyrHg
  UC2Dn71tJWdu8UqJrJRekU9Q
  UC2_cZnRexvOg610J_dCAU4A
  UC2iP2LTmYFt93BBiPJpvbYQ
  UC2y8vv0IggdNyacSaMbOhdA
  UC32Qg0Ul1iKjOeLljIukCgg
  UC3F9cSBfQgFi1mPk-4MDCpw
  UC3LRStk1bqBLO6G3ew5D3dg
  UC3N8OBsgZXASU5e-tx4V52w
  UC3UXwChdzkI6AYyl6Awz5FQ
  UC3ZCP-qRTElNqgAfcVKJoYw
  UC3m9tdQ8yaq-QT6YjBmZO6A
  UC3pv8JPwMuhOFxgltvOdseQ
  UC3qkYG76kOpatHg2fA9IVEw
  UC3rL9euQ5_DhEE6V0Ru3pVw
  UC3xKqMw5a2-m-qJD8_HNOZw
  UC47JHB4Zff94MF4hm3aVE9A
  UC4Ci-5e1VbaI6jasLk15f1w
  UC4YwPX5-38lsN_rlzSgd5kw
  UC4ZIJCbH0InZipbtfZ0EbEA
  UC4oe7bF2OxWDQ46cvMA-O-w
  UC4ttAsWGA-OlHGO1XqpaU-w
  UC5SGd77DKbofS1Nt6X4qing
  UC5g9AiIGLT-Oj7JB2VG8KhQ
  UC6PCItg9uP2KoF5VuPz5Tgg
  UC7FASG5OCgEZbSVYlUyD9kQ
  UC7lDs3vwZWK5ZsmF7CCH5fA
  UC83iM8HhI9XpQTPchgfpEUw
  UC8UfBPvfCgIuyXUMD3_nlXQ
  UC8YIJIC9dsyGj6AGnRLHb-A
  UC8j5V5VPjFN_N6Bd3WlmFOg
  UC8rk-fIWJXYlSF8tkfG9wWg
  UC9OsdkcBLD1oYBa0nV7RLjw
  UC9WcU6ao75P7XDJDU9fJe-g
  UC9X1CPqnYVoxZJ87YJPk5jQ
  UC9_ARnPYygGKBKjpXZFHUYQ
  UC9cqEx0-vQfpAGjJWzs6tWA
  UCA9NXBnvYhUZa034uKxSfFg
  UCAIvAQj1HZ1vqfd0-bX7qUg
  UCALykZ2-0_pD0Me_CMuRYwA
  UCAgjo0a3BiRxTm3Vb1ouS8Q
  UCB8WpG3HJiQaqOqtckSvnpQ
  UCBJ8mClj_dkRg2sl1ZgNreQ
  UCBevyiJ2ierZY-0yZhfLrmQ
  UCBsDUkVnC5I19zJfwxJ3jpg
  UCCTTsJP8fmNPCNBp0FL6P0A
  UCCVo4RiUo_PKCwjRUOkEucg
  UCCYFpYLQ5vaU6s_1Q9qcqag
  UCCYzHff8Ke8RaSarIBY1Iaw
  UCCjKb609zS52PnoCD0AKaCw
  UCClaSgb7vRBip-h5ZWZBsjA
  UCCqezurZNanR0X-hsdJWC2w
  UCD9AcHQPY0bEEaqGBOFQK-A
  UCDdK92AMBi98ERjM_EAOqPg
  UCDxRFmW4XBSAeThWn6tW6Ug
  UCE5AIl72HiGN7lNlaOhG9DA
  UCE6Ji384jD3atZIi4zk_55Q
  UCEUEaNVvgEO54n_PO901NnA
  UCEjA5F8lg5ntTbS7WDeRDFA
  UCEtMUhBV4czxLyty1tPfncA
  UCFGZ2Xt8YXNYJPk4yz_m2aw
  UCFIFAinqRitrg-WJIoerl8A
  UCF_r7hd-AaGUHSg7cuxlYcw
  UCFqcA5NXnq6AxK9QXA5rBBA
  UCFwTwTlvHVlgfuLBy1yHKMw
  UCG5-oZs-bmRZ_lSJrft_SiA
  UCGfP7cNOoGjO604RMImNEmQ
  UCGhm_lUTLgigbV7txVMmVLQ
  UCGtJeud3GXC2dERJy_IYEYQ
  UCGy8afFGPsRVtp66IBW6wxQ
  UCHhX74aJW9Swvnmdyg3WSRw
  UCI6VcuZUQ25rkXjP2NXuX1Q
  UCIQcfKjUl9NrYwQ_n-jaDHg
  UCITDLUTzq49FDtczQxAGyNg
  UCIdXlL0nxqqj0gVQLvPJJ7Q
  UCIgzloQ_KfcUN_AcvlxtDdg
  UCIm9HvG5HjeP2WcDIlrfGdg
  UCIr_W70tfZB8_Qca6F-gVSQ
  UCIxm83mFj8YhMGGakyl70sA
  UCJRT7XMWzY18GUB7k4K6Ugw
  UCK-0srt5hdY5m6Zos_NlJZg
  UCKJIaHqmUeVtYw3fTuLoDyw
  UCKganSH2rLo-AfX7YYZKZsA
  UCKxdYdnF8TjLsitBD3q3SVQ
  UCKzJFdi57J53Vr_BkTfN3uQ
  UCLCiHQ7EbH0kVmgq6ckrIXw
  UCLU_0tdwCHwjNMB-8iOAn0A
  UCLreIXyMtLaFtVYvg2dCbLQ
  UCLuxVNVlHTw1G1ykU-IYl5Q
  UCMJba5wv-6V6LvjSqCBp4rg
  UCMKkVPREwLxSDiOgEpVbeSA
  UCMOQvJh9lzxXDrppLnoZfAg
  UCMShgp5bR93gC9w8LBGdUAg
  UCMXrvnAyu5CrkKn2Hg1zNaQ
  UCMa2m0yXI7DI3MQ7-_rgRFA
  UCN-XJleleZE6MpuFGwgGIYA
  UCNFvMJxONsveMLS5_mkT5mg
  UCNN1Pls8bVOq7GhXNjXFlaw
  UCNW4VNfIKVatvBUwkROi7Yw
  UCNq0N_Rf2K8aLCXDTbrpLOw
  UCNxqz1TLwoKlnzaaGvsXwrQ
  UCOZJmE5thZBJNqIRP9mPMyg
  UCOjkVJQcjtWnpf0-1ft4brA
  UCOl0Rfe3Erum2cP74y7Eayw
  UCOosmZVNQJTQZmQjb7U_dKg
  UCPC08oKLvtwsEY67PLA8H6A
  UCPtelbF64DDW84-PzMcaS2A
  UCQ3Kgx1G1NkELoJ8tJ3uelg
  UCQ6u9aSYlE2Xrsws6Y00q1w
  UCQJdJ1u4ZM8Gz5my60y2ihA
  UCQSOs-diyd9muuqyiQfQ6vA
  UCQdtc5FRtc3IFS-dBhJnh8w
  UCQlQ538VcDlJAtZce8eCBqg
  UCQwRiPM8h_h9qAbKz8DQjFw
  UCR03kYv9xRCo9PHHRrIQscA
  UCR8W1IpHamM9tkHBEOS2cJg
  UCRa07c47CSfHHC7DbXMgbuQ
  UCRfxI01xPgzql7ZBS6WlebQ
  UCRm6tFJUc87PVpT5_EUB0Fg
  UCRm9N4AyaIzZ57bIZDiL8Qw
  UCS4KsbGyXg5YZxuYLhSXAKQ
  UCS5_QHGrlkdxwLCTaDdb4Nw
  UCSFcuf1pH63EFMK_G_MgxmQ
  UCSu-wH1wxjWVOgkXLpxdXdA
  UCTPo6NkiTNSbw3Menq_ViAw
  UCTUIH2IZyXF_NY4NnUHWBWQ
  UCUHc3Lgl_qoHqa1LgQ0er5Q
  UCUXnzh8HLzWoNbZyml4RKIw
  UCUbcbQbIfExkS4f_1HcQhfg
  UCUeqr_RC4LCJ8YGnfkAz5fw
  UCUikVLLJoQ7IDgBUZ9gUyzQ
  UCUjAAAcU9AALM9gRfTRAGyQ
  UCUuzKU2spQS2TOl74vzZrCA
  UCV8gEA4XEycdFx-myEpokLg
  UCVHT2xzy2axhiy463O6ZW-Q
  UCVUOqvMUHCs-WK6aqe62eJw
  UCVV8sCxdCyh3Nj6ouiFsUIg
  UCWCMEp-hLupAhgic_CmJjzw
  UCWCxyiaOuX-hIj-JJwUJyng
  UCWSAyy4rCuDUSYgxb7Dlnsw
  UCW_zbCW817z8_r27OY37Prg
  UCWg36YevLpwEMH2-X2KXtTQ
  UCWvq4kcdNI1r1jZKFw9TiUA
  UCX3O5OScqnv2E2aNK2bVxsA
  UCX7_tpSQi0dpxVlqyLBUvFg
  UCXIkr0SRTnZO4_QpZozvCCA
  UCY8oNKLo_fahTAkaamPwkPg
  UCYO_jab_esuFRV4b17AJtAw
  UCZETDuSFN1YhdfGosk_Vopg
  UCZIKVdr2k-EBLD3_6CCEOmg
  UCZcs1uE4fCIW-TKpz_b369A
  UC_8tGPupP39mzUnKmqmvUwg
  UC_LGF_gy_xvy996ACrg-Ybw
  UC_Qo3RX1r8cA7-hOJ6mhBIg
  UC_RI0mEpzbLvcL4cEk0fcIQ
  UC_Tf2_BtB3J5vtbw5a52wWw
  UC_pW4lR7YQVumLHuDFf88-Q
  UCb50QhvLANqjt3uSNDmyaRA
  UCbNycyGQrscpF1TD9xJ8Gig
  UCbm4am8_SVwPjlolj-77HqQ
  UCbqmSf9p46D7kmil-dZwEqw
  UCc-zkez5pPugQtsUjvZoM5w
  UCcLWyYVS3ysazvYjN7pKXuw
  UCcbEB9vBio2zZgTFjQKO9MA
  UCcpvJL_hRzbTPf9R0ZsHKJQ
  UCd0hscDvJvzRbo8Rk7JPQMA
  UCdFHH7man05PesWEagw-5ew
  UCdSu3tgroULNBpkyWkEzCYw
  UCdgpfQ5snGKcP-eqoVXI0pw
  UCeNxksejRYO0Nx5YCAllndQ
  UCeWn2Gp8RNWJ4rAMCDeV22g
  UCegTiCPkk38r7O7mLkHC_dA
  UCeiPG_9ABa8ramugu05N6KQ
  UCf-yFaupn_sC6Ym06Mu9ECg
  UCf1LjZlQuZjHXSN8CkgU00Q
  UCfinanJHgu7a__WILI0JL3w
  UCg37m92iGLR8Etgj29ycVXQ
  UCg8-S2k0d-5SnO3EbYSBRIg
  UCgFwjSQxcJKUaAFFxHo8OFA
  UCgTi7NKTrmgk-IFOAF8cOVw
  UCgq2CFR0HjGDh_SXSZk-5_A
  UCgrFaska7Nhokdzfa3B2a4A
  UCgrUyRFiHhV607Orhriau6w
  UChNSKxCJvNl3sObTUjKW5bg
  UChZq4u4FLSnIXpA2qtQLAwA
  UChqXaa0lfp9CLLBVA8T8XHA
  UCi0SnChv06KjxJyfglYAIBw
  UCiXICu8P5xQS82ynszzxqXQ
  UCix0FiTnFT7y7iKrGgyJUIg
  UCjQ_VN_sm68MbCCEVlbg7lg
  UCjqFnXnJmtoNep47o35x9SA
  UCkC_RNODWGBIt5Btd0t9hoQ
  UCkErGuLAlIVJfR80XzEezLg
  UCkheMWm0P78NjSVnqE7dXeA
  UCkmFNgB2lYI97GSp4J77z3g
  UCkmKS5Y_x9oeaLAgO8nlu2g
  UClDiWdXLmXZ1PtydggZPUSg
  UClEs3K07vWe0jW15p6idzLA
  UClNimiTUV4r0gvVUQ_BAZrQ
  UCmMeCaTaTxVlnUzRToICgGg
  UCmqgWqJIFo96tESRTWXH9Gw
  UCnD8lnh7ZN-cDUAHZvrdGJg
  UCnPHTzOV76tZN2ESl-WsoMw
  UCnidLP54yk3erG3fr-aOTWg
  UCnncDXzPY4ZpLhW2EkajYTg
  UCo03K8jHrd_tuciZQdoNwJg
  UCoSe79mPM75RO1vhEKdjsSQ
  UCojRF-b4D0R5JFZYa9iJfKw
  UCok6ceh1NySAnlsYXJN7Elw
  UCpFtzCKIr52VXGhn-8aijTw
  UCpjr0rKkVdtNjr6iuTtLNMg
  UCq7bP9mSX4okIw40PcZPn5g
  UCqCZV9jL18Kc4ZJoVrXK-Yg
  UCqTPc0Z0jNBtdtVCuxj1SZg
  UCqUKs1Y7G1l_CUpPdxByFkg
  UCqWsa-Nf6jIWTH4SYopxJPA
  UCq_NpFkLNLRFlJRWwNDTrMg
  UCqpS0m6GFceBNbRNL6frWQg
  UCqzebzc9N19X3MVFnuFYtRw
  UCrk5vWC3HZY_Gjsx9oDfzDQ
  UCsRsQ4M4ieo4xRl191Itp-Q
  UCsXVk37bltHxD1rDPwtNM8Q
  UCsc8cbVHUhKMFMbEXKzMCOw
  UCt-ZAa8qVu6ZI1DISg5zIiQ
  UCt4LjoWsPOLYiJ-fDXJUbZg
  UCt702xY6zetymBOV6VKhc4w
  UCtCQi1yJVRhwF0vxRrOjkaA
  UCtOTdRRBAYK9m5_Omvopbww
  UCt_sDyMnC7lTsLbOKMprKdg
  UCtcvjE455r6bCcGMCVRn9ZQ
  UCtcy2SGib0HXmD96dyNNIDA
  UCteZIp8QWc8YSf74Wgdlpsg
  UCtx8p9BDVYF11Xl-ln73JAw
  UCu4D3Dt9B6oWqtAt-fi1TRQ
  UCu8Jtlcv4Q2P4VeGwwiPnTg
  UCu8PfIMdpEaMbzQUUtq7muA
  UCuUzGY9N9kx34aAkjGVApbA
  UCvJHmvs7J53XCDMGYY1jEMQ
  UCvNu7xvIEmAdyNOKEjyp2ww
  UCvourQ1VKarLqfjGcS9dUJQ
  UCw4Ty20l1DccGCQ2HWiEcgw
  UCwCo0RkZcGhdBjtRfTCSZJw
  UCwZen9iWd7Jd1RlmoOgJ7rA
  UCxAveLoU1Uj5w1NjaBV6VIw
  UCxRDq83WEskvWsku1qhAk9A
  UCxRfEdXUr2q0KUkJnr2L8Zg
  UCxU-e9agrB7wrIAq51bdqVA
  UCxVdMf7eOmuMaY5_X5vZFuA
  UCyxrucdyEIpZrTW2H7rkBnw
  UCz05CgTYlDSOIJlZgOYz6nA
  UCzAxQCoeJrmYkHr0cHfD0Nw
  UCzSU4Vjk2VBJFHPvB5SJxHA
  UCzY-9DwuDh7_Wrxu5jEo8fw
  UCzpXbC_6o4_JmO4EGJbBd2w
  UCztxG-vPh1Jg9FIlCwmMlgQ
- 今はHelloWorldが画面中央に表示されている。これをタイル状にして、上からじゅんに20個並べて、フリックでスクロール操作できるようにしたい。表示は1〜20でそれ以外の機能は現時点ではいらない。
- コミットして。
- .git ignoreを整備して。
- 適当なメッセージでコミットして。日本語で。
- これはすでにiPhoneアプリとしてビルドして実行できるようになってる？
- Codex配下のHelloWorldプロジェクトを読み込んで。
