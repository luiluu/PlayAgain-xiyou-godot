# 交付：luiluu/t518

- 车道／工作者：T518 T013 2G 宝珠新表（cc，Opus＋medium，P8；首轮＋小A 初审退回后返修）
- 状态：可合并

## 变更记录草稿

## 2026-11-26 【cc·T518·未经审查】天启篇宝珠新表：18 族、五阶 3/5/6/8/10%、属性 1/2/3/5/6%、特性 22 行小表 1/3/6/10/15%，同族与同属性各只算 3 颗，读时换表，原作旧宝珠不再给（dev.待定）

- 依据：T013 第二期 2G（T513 拆卡稿 §2G）；养成线稿 v0.3 第三节第 1 条；D141 丙（不量数，数照稿）；D290＝预算稿 v0.16 第九节全按推荐（九.5 宝珠算一条线、九.6 同属性取阶最高 3 颗＋回复闪避暴击命中另排小表、九.7甲 长生入回复额度）；**Kyo 11-26 事项81** 定小表一～五阶 1/3/6/10/15%（预算稿 v0.16 第 83、169 行已回写，原九.6「五阶每颗 3%」已被改）。
- 新模块 `XTianqiOrbs`（`modes/xiyou/core/tianqi_orbs.gd`），只认天启篇存档（`XTianqi.active`）。回退开关：`TABLE`（整个回原表）、`SMALL_ON`（特性 22 行回属性排）、`ATTR_CAP`（不限同属性跨族）、`CAT_SWORD_X2`（小猫持剑不翻宝珠）。
- **读时换表、存档不改写**：镶嵌／取下照旧按物品原备注写进装备实例，天启篇读装备时（`XTianqiGear.stat_list` 末尾 → `XTianqiOrbs.views`）带新宝珠的装备换成视图：宝珠特性按新表给数，`yep.elementAmplify` 减去孔里新宝珠原备注那份、加上新表那份。特性、能力倍率、元素增幅、伤害加成总账 orb 桶、属性 +30% 封顶都跟着新表。
- **新表**：元素族本系伤害 3/5/6/8/10%；属性行（含元素族附带的攻防）1/2/3/5/6%；**特性 22 行**（长生 每回合生命回复、藏气 每回合法力回复、流风 物理闪避、灵慧 魔法闪避、鹰眼 命中与暴击）另排 **1/3/6/10/15%**（Kyo 11-26 事项81 已定）。同一项 3 颗封顶 45%；长生三颗五阶＝45%，入九.7甲 回复额度。
- **上限**：① 同族全身只算阶最高 3 颗；② **同一项属性跨族全身只算阶最高 3 颗**（九.6；如烈焰、寒霜、厚土、雷霆四颗都带魔攻，只算 3 颗）；同阶按装备靠前。超上限的那几行在视图里直接不给（不再靠下游按对象身份剔——特效吸取、技能重构的深拷贝视图会认不出，首轮这里能漏出原表 +30%，核查 P1-2）。
- **小猫（178）持剑翻倍**：照原版，剑上宝珠的新表值也 ×2，但翻倍后一项属性的宝珠合计仍不超过 3 颗五阶值（本系 30%、属性 18%、小表 45%），超的从翻倍那份扣（Kyo 11-26 事项81 已定：照原版翻倍、封顶照算）。首轮这里少扣了一倍原表值（核查 P1-3）。剑视图带 `_xcat_sword` 标记（`XCat.sword_view`）。
- **水、风两族**（第 16、17 族，镶武器孔，不进共鸣套）：表外物品号段 **3301～3310**（水「沧澜」3301～3305、风「啸风」3306～3310）。神秘珠鉴定 18 族等概率；宝珠坊分解照阶给残片。
- **原作 91 颗旧宝珠天启篇不再给**：鉴定不出；怪物掉落（含 `<Enemy Drops>`）去掉旧宝珠行；地图事件给的（13～30 层守层者首胜、Map132）换成同值宝珠残片，提示换成「获得了M枚宝珠残片！」。已在背包、镶着的照旧能用、能分解。
- **显示**：宝珠物品说明、插槽页、宝珠坊说明读新表；**装备说明卡与装备战力**也按新表（`XHelpCard` 走 `XTianqiOrbs.card_view`）；宝珠说明与宝珠坊首页写「全身同类、同项属性各只算最高3颗」；宝珠坊天启篇文案按 18 类、不提原作宝珠（西游档原样）。光耀度（T164）只管固定加值，新宝珠全是百分比行，光耀行照旧不出。
- `XItemMarks.is_orb_item` 改读 `XOrbs.config()`，天启篇认得水风两族。`stat_list` 先滤普通坐骑再换宝珠视图，坐骑不占名额。
- 西游档零改动；`发行空壳.py check` 过。
- 玩家可见：天启篇宝珠数值改成新表（本系伤害最高 +10%／颗、一人本系最多 +30%；每回合回复、闪避、暴击、命中每颗最多 +15%、一项最多 +45%）；同一项属性全身只算 3 颗；新增水、风两族宝珠；守层者首胜改给宝珠残片。

## 交接板

- 下一步：宝珠全角色矩阵（九.5，角色 × 层段、同种子有它没它）本单没量，要开量数卡；矩阵齐之前属性那份合用封顶不拆（现状就是不拆）。2H 宝珠共鸣十套小功能（水、风两族目前不在任何套里）；2I 神秘珠来源。
- 用户试玩说明：天启篇存档镶着的宝珠数值变小（按新表），四颗以上同一项属性的宝珠只算 3 颗；宝珠坊鉴定可能出水、风两族；守层者首胜给宝珠残片。
- 需要用户决定：无。原「协调默认口径待 Kyo 确认」两条 Kyo 11-26 事项81 已定：① 特性 22 小表一～五阶 1/3/6/10/15%（本轮已改）；② 小猫持剑照原版翻倍、翻倍后封顶照算（已是）。开关 `SMALL_ON`、`CAT_SWORD_X2` 照旧可回退。
- 物品号段登记：天启篇表外物品 3301～3310＝宝珠水、风两族（XTianqiOrbs.NEW_FIRST～NEW_LAST）。已知占用：3101～3105 元素转换书（XTianqiElements）、3201～3219 功法（XTianqiSecrets）、3301～3310 本单。

## 宝珠可达表（九.5／九.6，交给矩阵卡排除未开放格）

数从 `CodexOrbs.bands`、本模块新表算出（不含掉率）。阶的上限跟层段走：副本首领神秘珠与残片换神秘珠都按已到达的最高层段开。

| 层段 | 能出的阶 | 最高阶 | 本系伤害／颗 | 属性行／颗 | 特性 22 行／颗 | 一人本系上限 | 一项属性上限 | 一项特性 22 上限 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1～6 层 | 一、二阶 | 二阶 | 5% | 2% | 3% | 15% | 6% | 9% |
| 7～12 层 | 一～三阶 | 三阶 | 6% | 3% | 6% | 18% | 9% | 18% |
| 13～18 层 | 二～四阶 | 四阶 | 8% | 5% | 10% | 24% | 15% | 30% |
| 19～25 层 | 三～五阶 | 五阶 | 10% | 6% | 15% | 30% | 18% | 45% |
| 26 层起 | 四、五阶 | 五阶 | 10% | 6% | 15% | 30% | 18% | 45% |

- 「上限」＝三颗最高阶，要凑得出三颗：元素族（含水、风）、鹰眼、灵慧只镶武器孔，武器孔装备是武器、副手、神武三类（每件 0～3 孔，一件同族一颗），**一人本系 +30% 要三件都带武器孔**；玄甲、长生、藏气、流风镶防具孔（每件 0～2 孔）。
- 小猫持剑：剑上的宝珠翻倍，但合计照上表封顶。
- **没核**：每个角色有没有副手、神武栏（决定本系能不能凑满三颗）；属性 +30% 合用封顶（`XTianqiLedger.param_cap`）照旧在，没拆。

## 宝珠全角色矩阵（九.5）

- **没做**。九.5 要在试验分支上逐格（角色 × 层段）同种子有它没它实打，本单量数口径是「不量数」（D141 丙），两边冲突，按派单「未齐不拆属性顶」处理：属性合用封顶不拆，矩阵另开量数卡（建议 Opus＋medium，按上面可达表排除未开放格；元素珠、属性珠过线分开报，宝珠算一条线）。

## 进度账

- 部件 9（数值总账与养成）：T013 二三期 2G +0.15（拆卡稿折合），依据：宝珠新表实装＋专项（矩阵未量，见上）。

## 可优化（流程／工具／效率）

- 建议：仓里没有表外号段登记表（各模块自己在头注释里写），新加号段只能 grep 防撞。建议文档车道在 `00_设计/` 建一张「表外号段登记」（Sonnet＋medium）。
- 发行空壳「照搬关着时的返回」只看函数体前 8 行，`stat_list` 这种逐步加视图的函数再加一步就会掉出 8 行、报错。可以改成找最后一个「if not …: return 参数」（本单先把坐骑过滤压成一行绕过）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XOrbs.config` | 31 处（`git grep -nE 'XOrbs\.config\(\|[^.[:alnum:]_]config\(\)' -- modes/xiyou/core/orbs.gd modes/xiyou/ui/orb_shop.gd` 本文件 28＋外部 3）＋本轮 `item_marks.gd` 2 处 | 调用方逐处结论：西游档返回原表同一对象（零改动）；天启篇返回加了两族的副本，spec、slot_of、can_attach、identify、possible、refund、active_sets、cap_drops、orb_shop、item_marks 都按 18 族走；sets 不变；legacyShare 0 只影响 identify／possible／宝珠坊文案 |
| `XTianqiGear.stat_list` | 4 处（`git grep -nE 'stat_list\(' -- 'modes/*.gd'`） | 调用方 4 处逐处结论：actor.stat_equips（特性、元素增幅、总账）、_param_plus、开战状态标签（只读 meta／note）；本轮改成先滤普通坐骑再换宝珠视图，坐骑上的宝珠不占名额；西游档、TABLE 关时原样返回 |
| `XCat.sword_view` | 2 处（`git grep -nE 'sword_view\(' -- 'modes/*.gd'`） | 调用方逐处结论：只多一个 `_xcat_sword` 键（值 2），西游档没人读它；天启篇 XTianqiOrbs.views 据此按两倍扣原表 |
| `XHelpCard.detail_rows`／`_content` | 全部装备说明卡 | 调用方逐处结论：多套一层 `XTianqiOrbs.card_view`，西游档与没有新宝珠的物品原样返回；已是视图的（带 `_tq_orb_amp`）不重复换 |
| `XItemMarks.is_orb_item`／`_orb_filtered` | 7 处（含定义 2 行）（`git grep -nE 'is_orb_item\(\|_orb_filtered\(' -- 'modes/*.gd'`） | 调用方逐处结论：改读 `XOrbs.config()`，西游档同原表；天启篇多认 3301～3310（商店没上架，不改行为） |
| `XTianqiLedger.orb_amplify` | 3 处（`git grep -nE 'orb_amplify\(' -- 'modes/*.gd'`） | 调用方逐处结论：总账 orb 桶读视图上的 `_tq_orb_amp`（＝封顶后实际给的）；系别法宝读原件，随后 views 减原表加新表，两步相消 |
| `XDB.rec`（Items 3301～3310、宝珠物品视图）／`XDB.map` | 全工程 | 只在天启篇且 TABLE 开时进挂点；西游档原样 |
| `XBattleLogic.drop_chances` | 3 处（`git grep -nE 'drop_chances\(' -- 'modes/*.gd'`） | 调用方逐处结论：只去掉天启篇的旧宝珠物品行（含 34、35 号稀有怪 `<Enemy Drops>` 的旧宝珠 56、57，过滤在末尾全覆盖）；西游档原样 |
| `XGearDetail.socket_rows`、宝珠坊 `desc`／首页／鉴定页／分布页 | 各 3 处以内 | 天启篇读新表、18 类、不提原作宝珠；西游档原文不变（xiyou_orb_shop 22/22、xiyou_orb_shop_ui 27/27） |

## 验证

- `python3 07_开发环境/语法检查.py`：1245 个 .gd，0 个问题。
- `python3 07_开发环境/发行空壳.py check`：87 个脚本，856 个函数都有。
- 本地选测（并行测试.py，32 个场景全过）：xiyou_tianqi_orbs 56/56、xiyou_affix_absorb 45/45、xiyou_cat 1033/1033、xiyou_cat_help 35/35、xiyou_cat_trial 54/54、xiyou_gear_detail 56/56、xiyou_help_card 1075/1075、xiyou_help_card_sections 35/35、xiyou_item_marks 136/136、xiyou_orb_shop 22/22、xiyou_orb_shop_ui 27/27、xiyou_orb_ui 39/39、xiyou_orbs 63/63、xiyou_power 139/139、xiyou_tianqi_gear 36/36、xiyou_tianqi_gear2 51/51、xiyou_tianqi_gear_params 38/38、xiyou_tianqi_gem_power 59/59、xiyou_tianqi_guardian_gift 180/180、xiyou_tianqi_ledger 83/83、xiyou_tianqi_ledger_p3 44/44、xiyou_tianqi_save 82/82、xiyou_review_fixes 16/16、xiyou_inlay_book 19/19、xiyou_determinism 372/372、xiyou_battle_drop 19/19、xiyou_tianqi_drop 102/102、xiyou_map132_shop 102/102、xiyou_floor30_gifts 30/30、xiyou_tianqi_nine_off 19/19、xiyou_tianqi_equip_roundtrip 7/7、xiyou_race_battle 653/653。
- 专项新增：tq_cap_skip、tq_cap_deep_copy（深拷贝视图里第 4 颗也不给）、tq_attr_cap_cross／others／off（跨族 3 颗、别的行照给、开关）、tq_small_table／hrg_45（原 hrg_9）／item_text／off、tq_cat_mark／x2／x2_capped／x2_off、tq_card_view、tq_cap_text。
- 反向验证（手做）：把「超上限直接不给」改回「留原对象」，新专项 52/56（tq_cap_skip、tq_cap_deep_copy、tq_attr_cap_cross、tq_small_hrg_9 挂），还原后 56/56。
- 坐骑先滤（P2-3）没写专项，靠 xiyou_tianqi_gear／gear2／gear_params 原有坐骑用例。
- 云端选测：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45876580654 （提交 4bbd270b0，687 个场景 16 片）：686 过、1 挂——`xiyou_fabao_rework` 112/113，首跑挂 ev.xiyou_1433_orig、重跑挂 ev.xiyou_1434_orig（西游档抽奖期望的蒙特卡洛断言，两次挂不同格，测的是 T494 抽奖公共事件、本单宝珠视图在西游档不进），本机复跑 113/113。判为与本单无关的随机波动，没改那份测试（不是本单独占文件）；建议出这个测试的车道把抽样钉种子或放宽阈值。
- **本轮（小表改 1/3/6/10/15%，提交 3c9d2eace）**：语法检查 1245 个 .gd 0 问题；发行空壳 check 87 脚本 856 函数都有；本地选测 9 场景全过（xiyou_tianqi_orbs 56/56，另 xiyou_orb_shop、xiyou_orb_shop_ui、xiyou_orb_ui、xiyou_cat、xiyou_help_card、xiyou_gear_detail、xiyou_tianqi_ledger、xiyou_tianqi_gear）；云端选测 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45899334068 （687 个场景 16 片）全过。
- 截图：没拍（显示改动只有文字行，专项逐字核；文字待小A 审）。

## 本分支提交

- 5d42fb791 WIP: T518 天启篇宝珠新表（首轮）
- 246113053 T518 交付单；T236 专项核原版赠送时关宝珠新表
- f4e8a2aff 合并 github/main 进 luiluu/t518
- 4bbd270b0 T518 返修（核查 P1-1～P1-3、P2 三条、P3 四条）
- 819cdc998 T518 交付单：返修收口、可达表、云端选测结果
- 3c9d2eace T518 特性 22 小表改 1/3/6/10/15%（Kyo 11-26 事项81）
