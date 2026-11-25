# 交付：luiluu/t518

- 车道／工作者：T518 T013 2G 宝珠新表（cc，Opus＋medium，P8）
- 状态：进行中

## 变更记录草稿

## 2026-11-25 【cc·T518·未经审查】天启篇宝珠新表：18 族、五阶 3/5/6/8/10%、属性 1/2/3/5/6%，读时换表，原作旧宝珠不再给（dev.待定）

- 依据：T013 第二期 2G（T513 拆卡稿 §2G）；养成线稿 v0.3 第三节第 1 条（数值、补水风、旧宝珠不再掉、老档「镶着的不动，效果按新表读」）；D141 丙（九线不让，数照稿）。不量数（D141 丙）。
- 新模块 `XTianqiOrbs`（`modes/xiyou/core/tianqi_orbs.gd`），只认天启篇存档（`XTianqi.active`），回退开关 `XTianqiOrbs.TABLE`（false＝整个回原表）。
- **读时换表、存档不改写**：镶嵌／取下照旧按物品原备注写进装备实例（`XOrbs.apply` 不改），天启篇读装备时（`XTianqiGear.stat_list` 末尾 → `XTianqiOrbs.views`）带新宝珠的装备换成浅拷贝视图：带「族:阶」标记的特性换新表值，`yep.elementAmplify` 减去孔里新宝珠原备注那份、加上新表那份。特性、能力倍率、元素增幅（`XDamage.own_bonus`）、伤害加成总账 orb 桶（`XTianqiLedger.orb_amplify` 读视图上的 `_tq_orb_amp`）、属性 +30% 封顶都跟着新表。
- **新表**：元素族（锋刃物理、八元素、水、风、春泽治疗）本系伤害 3/5/6/8/10%；其余百分比行（属性族每行、元素族附带的攻防）1/2/3/5/6%。同族一个人只算阶最高 3 颗，**元素增幅也算进上限**（原表只限特性；稿「同族最多算 3 颗，所以一个人本系最多 +30%」）。
- **水、风两族**（第 16、17 族，镶武器孔，不进共鸣套）：表外物品号段 **3301～3310**（水「沧澜」3301～3305、风「啸风」3306～3310，五阶），按寒霜／雷霆同阶物品复制、备注照新表写；只在天启篇存档读得到（`XDB.rec` 挂点）；神秘珠鉴定 18 族等概率；宝珠坊分解照阶给残片。
- **原作 91 颗旧宝珠天启篇不再给**：鉴定不出（`legacyShare` 0）；怪物掉落去掉旧宝珠行（`battle_logic.drop_chances` 末尾，全表只有 535 掉 2052）；地图事件给的（13～30 层守层者 18 张图首胜、Map132 节日礼）换成同值宝珠残片（＝宝珠坊分解它的残片数×颗数），守层者提示「窃取了N个宝珠：名字！」换成「窃取了M枚宝珠残片！」（`XDB.map` 读图挂点，接在 T236 之后）。已经在背包、镶在装备上的照旧能用、能分解。
- **显示**：宝珠物品说明（备注 `<pos>` 行、description 第二行）换新表数（`<Augment>` 镶嵌行不动）；宝珠坊说明读新表；插槽页（`XGearDetail.socket_rows`）每颗新宝珠下补一行新表效果。光耀度（T164）只管固定加值，新宝珠全是百分比行，光耀行照旧不出、读数不受影响（专项 xiyou_tianqi_gem_power 59/59）。
- 西游档零改动：配置、物品、地图、掉落、装备读数都是原对象（专项「二、西游档」逐项核）；`发行空壳.py check` 过。
- 测试：新专项 `xiyou_tianqi_orbs` 42/42（含回退开关 TABLE＝false、存读档原文仍是原表数、取下回到镶前、同族上限连元素增幅、鉴定 200 枚无旧宝珠、Map064/132/155 无旧宝珠赠送）；`xiyou_tianqi_guardian_gift` 开头关 `XTianqiOrbs.TABLE`（它核 T236 照原版给的那几颗，T518 换残片由新专项核），180/180。
- 玩家可见：天启篇宝珠数值改成新表（本系伤害最高 +10%／颗、一人本系最多 +30%）；新增水「沧澜」、风「啸风」两族宝珠；守层者首胜改给宝珠残片，旧宝珠不再获得。

## 交接板

- 下一步：2H 宝珠共鸣十套小功能（取代 `POOL_ORB` 的 +g；水、风两族目前不在任何套里，2H 定）；2I 神秘珠来源（守层者／副本首领都掉，先对 T236 与本单的残片，别重复给）。
- 用户试玩说明：天启篇存档镶着的宝珠数值变小（按新表），宝珠坊鉴定可能出水、风两族；守层者首胜给宝珠残片。
- 需要用户决定：无（见回执「异议」两条口径，按默认做了，可回退）。
- 物品号段登记：天启篇表外物品 3301～3310＝宝珠水、风两族（XTianqiOrbs.NEW_FIRST～NEW_LAST）。仓里没有集中的号段表，已知占用：3101～3105 元素转换书（XTianqiElements）、3201～3219 功法（XTianqiSecrets）、3301～3310 本单。

## 进度账

- 部件 9（数值总账与养成）：T013 二三期 2G +0.15（拆卡稿折合），依据：宝珠新表实装＋专项。

## 可优化（流程／工具／效率）

- 建议：仓里没有表外号段登记表（各模块自己在头注释里写），新加号段只能 grep 防撞。建议总装或文档车道在 `00_设计/` 建一张「表外号段登记」（预计省每次查重十几分钟、避免撞号；文档车道 Sonnet＋medium）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XOrbs.config` | 31 处（`git grep -nE 'XOrbs\.config\(\|[^.[:alnum:]_]config\(\)' -- modes/xiyou/core/orbs.gd modes/xiyou/ui/orb_shop.gd` 本文件 28＋外部 3） | 调用方 31 处逐处结论：西游档返回原表同一对象（零改动）；天启篇返回加了两族的副本，读族数、物品、阶的地方（spec、slot_of、can_attach、identify、possible、refund、active_sets、cap_drops、orb_shop）都按 18 族走；sets 不变，新族不进套；legacyShare 0 只影响 identify／possible |
| `XTianqiGear.stat_list` | 4 处（`git grep -nE 'stat_list\(' -- 'modes/*.gd'`） | 调用方 4 处逐处结论：actor.stat_equips（特性、元素增幅、总账）、_param_plus（params 与原件同一数组，effective_params 缓存按实例号＋params 身份，不受影响）、开战状态标签（只读 meta／note，视图浅拷贝原样）；西游档 views 原样返回 |
| `XTianqiLedger.orb_amplify` | 3 处（`git grep -nE 'orb_amplify\(' -- 'modes/*.gd'`） | 调用方 3 处逐处结论：总账 orb 桶读视图（带 _tq_orb_amp）→ 新表；系别法宝 _efabao_clean_yep 读原件（不带标记）→ 原表那份，随后 views 减原表加新表，两步相消 |
| `XDB.rec`（Items 3301～3310、宝珠物品视图）／`XDB.map` | 全工程 | 只在天启篇且 TABLE 开时进挂点；西游档 3301～3310 返回 {}、宝珠物品返回原记录同一对象、地图不改 |
| `XBattleLogic.drop_chances` | 3 处（`git grep -nE 'drop_chances\(' -- 'modes/*.gd'`） | 调用方 3 处逐处结论：只去掉天启篇的旧宝珠物品行（kind 1 且在 legacyRefund），装备行、其余物品行原样；西游档原样 |
| `XGearDetail.socket_rows`、宝珠坊 `desc` | 各 3 处以内 | 天启篇新宝珠多一行效果文字／读新表；西游档不变（专项 xy_socket_row_plain） |

## 验证

- `python3 07_开发环境/语法检查.py`：1240 个 .gd，0 个问题。
- `python3 07_开发环境/发行空壳.py check`：87 个脚本，853 个函数都有（退出 0）。
- 本地选测（并行测试.py，23 个场景全过）：xiyou_tianqi_orbs 42/42、xiyou_orbs 63/63、xiyou_orb_shop 22/22、xiyou_orb_shop_ui 27/27、xiyou_orb_ui 39/39、xiyou_tianqi_gem_power 59/59、xiyou_tianqi_guardian_gift 180/180（改测试后重跑）、xiyou_tianqi_ledger 83/83、xiyou_tianqi_ledger_p3 44/44、xiyou_tianqi_save 82/82、xiyou_review_fixes 16/16、xiyou_inlay_book 19/19、xiyou_gear_detail 56/56、xiyou_determinism 372/372、xiyou_battle_drop 19/19、xiyou_tianqi_drop 102/102、xiyou_map132_shop 102/102、xiyou_floor30_gifts 30/30、xiyou_tianqi_nine_off 19/19、xiyou_item_marks 136/136、xiyou_tianqi_gear 36/36、xiyou_tianqi_equip_roundtrip 7/7、xiyou_race_battle 653/653。
- 反向验证（手做）：去掉 stat_list 里的 views 一行，新专项 38/42（tq_view_values、tq_all_traits、tq_ledger_orb_bucket、tq_roundtrip_view 挂），还原后 42/42。
- 云端选测：待写
- 截图：没拍（显示改动只有文字行，专项逐字核；文字待小A 审）。

## 本分支提交

- 待写
