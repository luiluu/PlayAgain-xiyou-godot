# 交付：cc/wukong-newsrc10（EB 角色旧账二）

- 车道／工作者：EB 角色旧账二（cc，悟空）；接 DW（`cc_wukong-newsrc10.md`），同分支。代码提交在工作树 competent-ishizaka-ae6e7c 做的，本交付单提交在另一会话工作树里接在 605d1a9c 上推的（那棵工作树要先 `git pull` 才跟得上）。
- 状态：可合并（①②③ 都交了；交回换源集成分支，不合 main）
- 基线：ce1fddf3。探针、量具、选测都显式设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】角色旧账二：SV 归一平滑、停用／隐藏角色、162 诛仙战斗图、人物图鉴跟 v0.62（dev.待定）

- **① SV 归一平滑**（`battle/battler_sprite.gd` `_apply_smooth`，O-待定·SV 归一平滑，`XBattlerSprite.SV_NORM_SMOOTH`）：照 v0.62 `Codex_MiraRavenMultiFrame` v1.06 applyVisual（`bitmap.smooth = !crispScaling || scale<1`，CrispScaling 默认开）：167 号以后有归一档的角色，归一缩放×SvPngFd 小于 1 时身体改 LINEAR，否则最近邻。量具 v0.62 实测正好 168、174、175、179 平滑（0.55～0.72 倍），其余（167、169～173、176～178 放大或原尺寸）不平滑。关掉开关回 v0.28（一律最近邻）。重跑逐张比 `xiyou_actor_sv_compare`：平滑四条差异清零。
- **② 没进出战栏的 5 名定性**（见下表）：不是漏实现，出战栏两边一致。顺带跟进同一批新源插件里重制没做的两处（O-待定·V029 隐藏角色，`XImportedBalance.V029_HIDE_ACTORS`）：人物图鉴目录、角色仓库列表滤掉 V029 隐藏的 7 名（仓库只滤显示，编号留着不丢）；读档时照 `B.migrateParty` 把停用角色挪出队伍与出战栏（`XImportedBalance.migrate_party`，`XState.from_dict` 调）。图鉴目录改成按行取角色（`XActorBook.row_ids`／`cur_id`），仓库取出改按编号删（列表滤过后行号不等于仓库下标）。
- **162 诛仙战斗图是空的（查出来的）**：原版 `guanxi7_1.png`、`小诛仙.png`、`characters/guanxi7_1 (1).png` 是扩展名 .png 的 JPEG，早年原样复制时导入失败留下 `valid=false` 的 `.import`；转换器后来转成真 PNG 了，但 Godot 认旧记录不重导，战斗里 162 没有身体贴图、脸图也空。`xiyou_export.py` 复制图时遇到 `valid=false` 的 `.import` 就删掉（记 issue `resetInvalidImport`），下次导入重做；专项查 generated/img 下没有坏导入。EB 工作树已删掉重导：162 逐张比几何与逐像素都对上（比对场景按内容读原版伪 PNG）。主工作区、集成树那 3 个 .import 由总装处理。
- **③ 零星清单**：DW 交付单末尾的候选（审查 40 P3-11、41 P3-4、42 P3-1～3、45 raven.gd 头注释）**全部已销账**（变更记录 4517、4562、dev.334、dev.336，审查 48 第 36 行）。另找真缺的，做了前 5 条：
  1. 人物图鉴状态页「光环独立栏」（v0.29，Star_ActorsBook drawAllContents）：有 `<CodexAura>` 技能的角色四栏「主动／被动／光环／其他」、栏宽 floor(932/4)、22 号行高 30、超出写「确认查看全部」，武器掌握接在最长一栏下（`status_ops`）。
  2. 技能详情类型「【光环】」（`skillTypeName`，`XActorBook.is_aura`）。
  3. 流萤 179 详情专属段（10622～10632＋全库 `<CodexLiuyingPassive:>`）与「未解锁」灰字（PREVIEW_ACTORS 加 179）。
  4. 流萤图鉴立绘：179 归一档登记 `[128,128,19,12,111,128]`（与战斗 inferProfile 量出的一致）＋图鉴 bookScale 0.8（v1.07，`XAppearance.BOOK_SCALE`，只作用于图鉴）；actor_book 立绘名改按参照记的战斗图名比（参照 `review_actor_book.js` 记的是 `battlerName()`，168、173～177 图鉴画逐帧图）。
  5. `xiyou_actor_p0`：参照 slice_d2 没有 179 时第②段 `d.actors[str(id)]` 脚本出错、测试停住不出结果（基线就这样）；改成跳过，oracle_row_179 两条照记挂，等整份同步。
  - actor_book 从 17/22（CV 重取参照后挂的 5 项：光环标签、主动列宽、新角色立绘、179 技能表、目录名单）到 26/26。

## ② 定性表

| 角色 | 原版为什么不在出战栏 | 重制 | 结论 |
| --- | --- | --- | --- |
| 141 女儿国王、146 苍龙破晓、152 徐凤年、161 胡桃、166 利姆露 | **数据开关（停用名单）**，不是解锁条件或事件：v0.62 `installImportedBalanceRuntime` `disabledActorIds`（10 人：141、143～146、152、157、160、161、166）；量具设 `_actors=[id]` 后调 `initializeBattleMembers`，包装先跑 `B.migrateParty`，停用的挪进仓库、出战栏清 0。另 `installIntegratedV029Runtime`（v0.30）`hiddenActors` 7 名（141、146、152、157、160、161、166）新局／读档从队伍和仓库移走，图鉴目录、仓库列表滤掉 | `XImportedBalance.DISABLED_ACTORS` 同 10 人，`add_actor` 拦（rules-newsrc1 已跟）；逐张比里重制也没让它们出战 | 出战栏一致，不是漏实现。缺的图鉴目录、仓库列表隐藏与读档迁移本单补上 |
| 143～145、157、160 | 同上停用（157、160 还隐藏） | 不在切片里（没导出），逐张比不量 | — |
| 162 诛仙 | 正常进栏（guanxi7_1，9×6 64px，×0.75，不平滑） | 外观本来就是普通侧视图；量不到是因为图导入坏了，身体没贴图 | 已修（见上），逐张比对上 |

## 优化登记

已直接写进 `03_再刷重制_Godot/00_设计/优化登记.md` 末尾两行（总装通知要求），编号待总装分配：
- O-待定·SV 归一平滑：`XBattlerSprite.SV_NORM_SMOOTH = false` 回 v0.28。
- O-待定·V029 隐藏角色：`XImportedBalance.V029_HIDE_ACTORS = false` 回 v0.28（图鉴、仓库列全部）。读档迁移没挂开关（照新源；停用角色本来就进不了队）。
`回退开关覆盖.py`：两条都认到、有回退支测试。

## 交接板

- 下一步：③ 剩下的真缺（下面「剩余清单」）；整份同步给 slice_d2 加 179 后 actor_p0 两条自然过。
- 用户试玩说明：米拉、云裳、谷雨、流萤的战斗图边缘变柔（跟 v0.62）；人物图鉴里女儿国王等 7 名停用角色不再出现，角色仓库也不列；有光环技能的角色图鉴状态页多一栏「光环」；流萤图鉴立绘小一些（×0.8）；诛仙战斗图能看到了（之前是空的）。
- 需要用户决定：无（两条 O-待定照「冻结后改动逐项跟进」默认开）。

## 剩余清单（③ 没做的真缺）

- v0.62 v1.08 进阶窗口：格子大于 64px 的 9×6 图（流萤）在进阶界面按图鉴同尺寸、平滑、脚底中线对齐 64px 格（`Window_ActorAdvancedStatus.update` 包装）；重制 actor_advanced 没跟（没逐行核，先列）。
- v1.06 `<CodexSVNativeSize>`：v0.62.12 数据里没有角色带这个标签，暂不用做。
- V029 读档把隐藏角色挪进 `_codexHiddenActors29`（记原位置）：重制只滤显示、编号留在仓库；以后要「恢复隐藏角色」再补。

## 验证

- 专项：xiyou_sv_smooth 144/144（开、关各一组：采样方式；画的那帧与源 PNG 逐像素比（alpha 全比、alpha≥20 比 RGB，fix_alpha_border 改过 alpha<20 的 RGB）；变大装备推到 ≥1 回最近邻；无坏 .import，守卫先挂后过已验）；xiyou_hidden_actors 24/24；xiyou_actor_book 26/26（改前 17/22）。
- 邻近（本机）：actor_book_review 6、actor_warehouse 26、appearance 34、autosave 10、imported_balance 233、pets 29、raven_visual 55、save_events 31、save_page 42、svpngfd 33、sve_visual 31、sequence_visual 70、actor_advanced 33、advance_reads 8、liuying 144、liuying2 188、liuying3 50，全过。actor_p0 改前基线就脚本出错停住（参照缺 179）。
- 逐张比工具场景重跑：平滑差异清零；162 几何与像素对上。
- 云端选测（15 个场景，--scenes 带 .tscn）：[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42295374006)，结果在回报里。
- `事件空绿扫描.py --check`：挂 5 条 m234 状态没量，同 newsrc9（克隆产物没有新地图 234 的状态探针，不是本单）。语法检查通过。没跑全量。

## 可回退

- 两个开关见上；162 的转换器守卫要撤就撤 cfa4db94 里 xiyou_export.py 那段（只删坏 .import，不改产物）。

## 可优化（流程／工具／效率）

- 已做：`xiyou_export.py` 遇到 valid=false 的 .import 自动删掉重导；`xiyou_sv_smooth` 里加了全 generated/img 坏导入扫描。
- 建议：`新建工作树.sh --补齐` 克隆 generated 时也扫一遍 `valid=false` 的 .import（这次三棵树都带着坏导入），归工具车道。

## EC′（接 EB，同分支；在工作树 priceless-hofstadter-fa63e4 做，generated／.godot 从 competent-ishizaka 克隆）

### 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】actor_p0 只在云端挂的 recruit_11 查清；179 切片参照在新源上补跑（dev.待定）

- **① recruit_11 的根**：大厅 Map004 有漩涡过场（`CodexWhisper.seen('rift1')` 为假时自动播，播完 `mark`），配置 `codexWhisperSeen` 存在测试目录的 options.json 里、不跟存档。本机 `user://test_xiyou_actor_p0/options.json` 留着上次运行记下的 rift1，所以不播；云端每次全新目录，过场占住地图 600 帧以上，测试等满 600 帧后照样调第一个招募公共事件 13，`run_common_event` 见地图忙直接返回 → 里德没进队。属于测试依赖残留状态（不是环境或工具差异）。复现：本机把测试目录挪开再跑，挂同一条；改后：测试开头删掉旧 options.json、按默认值重读、标记 rift1 已看（只验招募），并在每次调事件前加 `map_idle_before_<id>` 断言，地图还忙时明确记挂，不再算成「没招进来」。反向验证：去掉标记那行 → `map_idle_before_11 [13,600]` 与 recruit_11 一起挂。没加豁免。
- **③ 179 两条缺参照**：探针本来就有（`mv_oracle/slice_probe.cjs`，`xiyou_slice.json` 已含 179，dev 之前流萤第一期加的），缺的只是参照没在新源上重跑。在新源上 `XIYOU_PROBE_ACTORS=179 node slice_probe.cjs 2`（14 秒，1264 行伤害，0 错误）跑出 179，并进本分支 generated/oracle/slice_d2.json（本机与云端快照 refs/ci/generated/cc/wukong-newsrc10），actor_p0 本机 3680/3680。集成那边整份同步跑新源时会自然带上 179，不用另改探针。

### 验证（EC′）

- actor_p0 本机 3680/3680（179 并进参照后；只改测试时 3676/3678，剩两条 179）；清空测试目录连跑两次都过。
- 云端（actor_p0、actor_book、hidden_actors、sv_smooth，运行 42298148899，带并进 179 的快照）：4 个全过。

### 可优化

- 建议：别的在 Map004 起跑、用 `XSave.dir_override` 的测试也会吃同一个过场（首跑与再跑结果不同）；可以在测试公共初始化里统一标记 rift1，或让云端与本机一样每次清测试目录。归工具车道。

## EC′ ②（剩余清单前 5 条：做了 2 条，到接力线停下）

EB 剩余清单只有 3 条，其中 `<CodexSVNativeSize>`（数据里没人用）和 V029 隐藏角色暂存位置玩家看不到；按「冻结后改动盘点」补找玩家看得到的缺口后排序：

1. ✓ **进阶界面大图（v0.62 v1.08）**：`ui/actor_advanced.gd` `_v108`，O-待定·进阶界面大图（`XActorAdvancedScene.ADV_V108`，已登记）。登记了归一档、格宽大于 64（与档宽差不超过 1）的 9×6 战斗图，在进阶界面按图鉴同尺寸（归一缩放×bookScale，只缩小）显示、左上锚点、平滑、中线 w/10+32、脚底 w/10+64。流萤 179：0.4966 倍（原来 128px 格原尺寸，约老角色两倍大）。云裳包装照旧在外层。专项 xiyou_advance_v108 9/9（开、关两组；老角色 1 不动）；actor_advanced 33/33。
2. ✓ **宝宝路线号角商店全部角色免费（v0.62 installBabyAllActorsRuntime）**：新模块 `core/baby_all_actors.gd`（XBabyAllActors），O-待定·宝宝号角免费（`ENABLED`，已登记）。宝宝路线（开关 2496）下卖号角的店改列全部可用角色号角（停用、V029 隐藏、没名字的不列；已在队伍／仓库／背包、招募变量 ≥1、领过的不列）、价格 0、额外货币价清空（`XItemMarks.sell_rewards` 在免费店开着时返回去掉买入价的副本）、每次最多 1 支、领过记 `flags._codexBabyHornActors`；超强者视同开放（`XItemMarks.super_enabled`）。商店 `setup` 改商品表、`_exit_tree` 还原、`_trade` 记领取并从列表拿掉。新探针 `mv_oracle/baby_all_actors_probe.cjs`（真实 Scene_Shop.prepare 整条链，新源）→ `tests/fixtures/baby_all_actors_oracle.json`；专项 xiyou_baby_all_actors 36/36（商品表 137／133 行逐行一致、号角→角色 228 支全对、领取一次、关店还原、开关关掉回 v0.28）。
3. ○ 流萤头像、改版向导流萤三页、流萤技能说明按阶数生成（盘点 v0.62.06／08 行）：没逐项核是否已做，下一单先 rg 再做。
4. ○ 图鉴立绘逐张比量具（DW 建议：`real/actor_book_real.cjs`）。
5. ○ v0.62 神话／混沌神话词条概率随难度浮动（installAffixDifficultyRate，盘点 v0.62 行）：玩家看得到掉落，没核重制是否已跟。

### 验证（EC′ ②）

- 本机：advance_v108 9、actor_advanced 33、baby_all_actors 36、alien_workshop 45、imported_balance 233、item_marks 136、map132_shop 102、orb_shop 22、orb_shop_ui 27、shop_auto_close 10、shop_buy 8479、shop_stat_mode 11、shop_stock 56、super_acquire 31、weak_challenge 125、yunshang_shop 421 全过。lobby_shops 93/94：`case_e54p0_base_0-0` 挂，把 `XBabyAllActors.ENABLED` 默认关掉也一样挂（与本单无关，没查）。
- 云端（advance_v108、actor_advanced、baby_all_actors、shop_buy、item_marks、super_acquire、map132_shop、lobby_shops，运行 42300559977）：8 个全过；lobby_shops 云端也过，本机那条挂像是本机残留状态（同 recruit_11 那类），没深查。语法检查通过。

## 本分支提交（EB）

- 73dfc8ca v0.62 SV 归一平滑＋专项 xiyou_sv_smooth
- cfa4db94 162 诛仙坏导入：转换器守卫、专项扫描、逐张比按内容读图
- 8cba908b V029 隐藏角色、读档停用角色迁移、专项 xiyou_hidden_actors、优化登记两条
- 72955961 人物图鉴光环栏／光环标签／179 详情；actor_p0 不再停住
- 605d1a9c 流萤图鉴立绘档与 bookScale；actor_book 26/26
- d6707f23 交付单
- （本提交）原版 bug：高阶行封顶不压低（FIX_CAP_BASE）；交付单补云端结果

## ED（接 EC′ ②，同分支；在工作树 funny-poitras-4e3474 做，分支从 priceless-hofstadter 的 cc/wukong-newsrc10-ec 头 357980b3 续过来）

### 先核实（EC′ ② 剩余第 3 条）

- **流萤头像**：已有（generated/img/faces/Codex_Liuying_Faces.png 与新源逐字节相同，db faceName 对）。
- **改版向导流萤三页**：已有（大厅 Map004 EV71「改版向导」第 0 页 653 条指令与新源完全相同，走地图数据）。
- **说明按阶生成**：我做了一份，合集成分支 6caaac78 时发现界面车道已交 `XLiuyingHelp`（ui/liuying_help.gd，探针 liuying_help_probe，专项 xiyou_liuying_help 44/44），两份逐字同源（L.skillLines）。**保留集成那份**，删掉我的 `XLiuying.text_view`、liuying_text_probe.cjs、xiyou_liuying_text 与夹具、O-待定·流萤说明按阶（那份不设开关，照界面车道）。

### 变更记录草稿

## 2026-11-07 【cc·悟空·未经审查】神话／混沌神话词条概率随难度浮动；高阶行封顶不压低（修原版 bug）；图鉴两套 179／V029 合成一套（dev.待定）

- **神话词条概率随难度**（O-待定·词条难度浮动，`XAffixRate.ENABLED`）：照 v0.62.12 `installAffixDifficultyRateRuntime`（CodexAffixRate v1）。新模块 `core/affix_rate.gd`（XAffixRate）：整行都是 14／15 品质词条的行（`line_tier`），概率 ×路线倍率（按路线开关取第一个开着的：洪荒 2～5 按诅咒倍率、灭世 1.5、天灾 1、地狱 0.75、困难 0.55、普通 0.4、简单 0.3、宝宝 25），单行封顶 50%；M＝1 或普通行照原掷法。浮动后用 `r×100` 连续比较，按配置概率升序逐项减，都不中不出词条。`XGear.roll_item` 里掷一行词条那段抽成 `XGear.choose_affix`（原掷法逐字未改）。修行·详细页（`XGuide.detail_rows`）末尾加「高阶词条概率」一段。新探针 `mv_oracle/affix_rate_probe.cjs`（新源 68 例：13 种路线开关、6 档诅咒、7 件装备×7 条路线×21 个预掷随机数）→ `tests/fixtures/affix_rate_oracle.json`。
- **原版 bug 修了**（O-待定·高阶行封顶不压低，`XAffixRate.FIX_CAP_BASE`，Kyo 11-07「原版的bug要修」）：原版 min(配置×M, 50) 把配置高于 50% 的高阶行（落芸之力等 100% 行）在 M≠1 时压到 50%，灭世、洪荒、宝宝反而低于天灾的 100%；修成封顶取 max(50, 配置)，配置不超过 50% 的行不受影响。专项 xiyou_affix_rate 371/371（参照比对时修 bug 开关关；fixed.* 7 例 100% 行按修好后的概率、42 例普通行与原版一致；ENABLED 关掉灭世等于 M＝1 原掷法、修行页不加）。
- **图鉴冲突合并**（总装派）：集成分支与 EB 各做了一套 179 图鉴档与 V029 隐藏。合成一套：`actor_book.gd` 以集成版为底（`index_ids`／`actor_id`／`_aura_columns`／`is_aura_note`／`book_scale`），隐藏名单与开关统一用 `XImportedBalance.HIDDEN_ACTORS`／`V029_HIDE_ACTORS`（`is_hidden_actor`，角色仓库同一名单），去掉 actor_book 自己的 HIDDEN_ACTORS 常量；bookScale 表统一放 `XAppearance.BOOK_SCALE`（进阶界面大图也用），`XActorBook.book_scale` 读它，去掉 actor_book 的 BOOK_SCALE 常量。EB 的 `row_ids`／`row_count`／`cur_id`／`is_aura` 不再有。测试两边断言都留：xiyou_actor_book 的立绘比对新参照有 bitmap 时比实际画的图、旧参照只比战斗图名；V029 开关开、关两组改用 index_ids。

## 优化登记草稿

已写进 `03_再刷重制_Godot/00_设计/优化登记.md` 末尾，编号待总装分配（EB、EC′ 的四条早已在登记里）：

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·词条难度浮动 | `modes/xiyou/core/affix_rate.gd` `XAffixRate.ENABLED`；`XGear.choose_affix`、`XGuide.detail_rows` | v0.28 神话／混沌神话词条按装备配置概率掷，不分难度；v0.62 `installAffixDifficultyRateRuntime`（Kyo 2026-10-31 定）：整行都是 14／15 品质词条的行，概率 ×路线倍率（简单 0.3、普通 0.4、困难 0.55、地狱 0.75、天灾 1、灭世 1.5、洪荒 2～5 按诅咒、宝宝 25），单行封顶 50%；修行·详细页末尾加「高阶词条概率」一段 | 跟进新源（开关默认 true） | 换源后正式版的改动；参照 affix_rate_probe（新源：13 种路线开关、6 档诅咒、7 件装备×7 条路线×21 个预掷随机数），专项 xiyou_affix_rate | `XAffixRate.ENABLED = false` 回 v0.28（一律原掷法，修行页不加这段） | cc（悟空） | 跟进新源；编号待总装分配 |
| O-待定·高阶行封顶不压低 | `modes/xiyou/core/affix_rate.gd` `XAffixRate.FIX_CAP_BASE`（`pick`） | v0.62 `installAffixDifficultyRateRuntime` 原版：浮动后的概率一律 min(配置×M, 50)，配置本来就高于 50% 的高阶行（落芸之力等 100% 行）在 M≠1 时被压到 50%：地狱 75%→50%，灭世、洪荒、宝宝也只有 50%，反而低于天灾（M＝1 走原掷法，100%） | 修原版 bug（Kyo 2026-11-07「原版的bug不照搬，要修」）：封顶取 max(50, 配置)，即 min(配置×M, max(50, 配置))；配置不超过 50% 的行与原版完全一样 | 参照 affix_rate_probe（新源，开关关时逐例对上原版）；专项 xiyou_affix_rate fixed.*（7 例 100% 行按修好后的概率掷、42 例普通配置行与原版一致） | `XAffixRate.FIX_CAP_BASE = false` 照原版 | cc（悟空） | 修原版 bug；编号待总装分配 |

`回退开关覆盖.py` 两条都认到、有回退支测试。

### 交接板

- 用户试玩说明：神话／混沌神话词条按难度变：简单、普通更难出，灭世、洪荒更容易，宝宝路线高很多，单行最高 50%（本来就高于 50% 的行不会被压低）；修行·详细页末尾能看到当前倍率。
- 需要用户决定：无（两条 O-待定照默认开）。

### 验证（ED）

- 合并 6caaac78 后本机：actor_book 26、hidden_actors 24、affix_rate 371、liuying_help 44、actor_advanced 33、advance_v108 9、actor_warehouse 26，全过。语法检查通过（612 个 .gd）。工具回归通过（合并前）。
- 云端选测（合并前，[运行 42308091218](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42308091218)，提交 7032b5b4，基准 357980b3，143 个场景）：130 过、13 挂，查过都不是本单：
  - growth_help（8 条心钢／狂妄词条行）、gear_search（3 条战力排序）、equipment（affix_revert 参照缺）：本机把 gear.gd 换回 357980b3 原样、XAffixRate 关掉也一样挂（新源数据配 v0.28 旧参照；测试状态没开路线开关，M＝1 本来就不走新掷法）。
  - zhenqi 12 条 page.*：旧参照没有「修行·详细」detail（已知，同步后才有）。
  - help_card 4 条：10290、10293、10298、10358 成长行新源换了词，参照是旧的。
  - floor_run、floor_run_b／_c、event_compare（ce9039／ce9026）、floor_fortress029、item_bag、empress_draw、save_events：与本单改动的文件无关。
- `事件空绿扫描.py --check`：只挂 5 条 m234 状态没量（同 EB、EC′）。`探针登记检查.py`：新探针有夹具。没跑全量。

### 剩余清单

- 技能列表的自定义消耗文字（YEP_SkillCore `<Custom Cost Display>`）重制整个没画；流萤 3 阶起原版把燃烧那格清空。归界面车道。
- 图鉴立绘逐张比量具不归本车道。

### 本分支提交（ED）

- 7032b5b4 词条概率随难度（＋已删的说明按阶）
- d6707f23、94821d43 交付单；高阶行封顶不压低
- （本提交）合并 cc/newsrc-switch 6caaac78：图鉴合成一套，说明按阶留集成版
