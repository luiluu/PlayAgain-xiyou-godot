# 交付：cc/tianqi-seed-fix

- 车道／工作者：C 规则·机制／cc（天启篇读档重掷修复，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·读档重掷修复·未经审查】天启篇重铸、异化词条、抽角色候选改存档派生随机（dev.待定）

- 经济返修「同类盘点」里剩下的读档重掷处一次堵上（七印两处已由 cc/tianqi-qiyin-endgame 修）：装备重铸、锁词条重铸、异化词条兜底（`XTianqiAlienGear.create`／`attach` 不传随机流时）、异化重抽、通关抽角色候选。
- 种子＝存档种子 `orb_seed`（随存档；更老的档由存档内容算出）派生＋对象标识＋该对象随存档的次数：重铸、锁词条重铸、异化重抽用装备的随机身份 `tq_seed_id`（入包登记时由本档种子＋本档内唯一的 `instanceId` 派生、写在装备上随物品走、永不重编；老件读档时按固定顺序一次性补号）＋装备上的 `tq_rng_n`；异化兜底用异化账本 `sequence`；候选用第几次抽（`flags.tianqi.draws`）。存进星辰仓库再取出（`instanceId`、异化 uid 会重编）不换流；复制装备的路径（魔冠重发、云裳发货、仓库原版复制）复制品去掉旧号，重新登记或读档补号时另拿新号。同一次操作读档后结果相同，不同次、不同装备各自独立；老档缺计数字段当 0 补上。
- 公共入口在 `XTianqi.save_stream`／`save_roll`／`on_register`／`assign_all`／`before_renumber`／`seed_id`／`item_roll`（`modes/xiyou/core/tianqi.gd`），开关 `XTianqi.SEED_FROM_SAVE`（O-待定-1），关掉回到全局随机、不写计数字段。
- 天启篇存档新装备掷天启篇词条（掉落、商店、事件都经 `XTianqiAffixRoll.apply`）不传随机流时，改由 `orb_seed`＋`flags.tianqi.affix_roll_n`（每掷一件 +1、随存档）派生：打出掉落后读档再打同一场，词条一样。测试磁带、深渊商人的本轮种子照旧优先。开关 `XTianqiAffixRoll.SEED_FROM_SAVE`（O-待定-2）。西游档不进这条分支，装备流、对照不变。
- 西游档不变（全部只在天启篇路径上；魔冠、云裳、仓库三处只多去掉一个天启篇字段，西游装备上本来没有）。掉哪几件仍由运行时战斗奖励流决定（整局既有设计，不在本单）。
- 玩家可见：天启篇里重铸、异化重抽、通关抽角色候选、新装备的天启篇词条，先存档再掷、读档再掷，出来的还是同一个结果。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi.gd` `XTianqi.SEED_FROM_SAVE`（`save_stream`、`save_roll`、`seed_id`、`item_roll`、`draw_offer`）；`modes/xiyou/core/tianqi_reforge.gd`（`reforge`、`reforge_locked` 兜底）；`modes/xiyou/core/tianqi_alien_gear.gd`（`attach` 兜底、`reroll`）；入包分配与读档补号：`xstate.gd` `register_gear`、`from_dict` 末尾，`star_warehouse.gd` `withdraw_gear`；复制路径去号：`demon_crown.gd` `_grant`、`yunshang_orders.gd` `grant_spec`、`warehouse.gd` `deposit`；`tests/xiyou_tianqi_seed_fix.gd` | 天启篇重铸、锁词条重铸、异化兜底选词条、异化重抽用全局 `randf`，抽角色候选首次抽用 `randomize()`，都能先存档再掷、不满意读档重掷 | 改由存档种子＋对象标识＋随存档的次数派生，读档后同一次操作结果相同 | cc/tianqi-econ-fix 交付单「同类盘点」；协调派单 cc/tianqi-seed-fix | `XTianqi.SEED_FROM_SAVE = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_affix_roll.gd` `XTianqiAffixRoll.SEED_FROM_SAVE`（`_default_rng`、`apply`）；`tests/xiyou_tianqi_affix_seed.gd` | 天启篇存档新装备掷天启篇词条不传 rng 时走运行时装备流（`XState.random_master`，不随存档），打出掉落后读档再打词条会换 | 改由 `orb_seed`＋`flags.tianqi.affix_roll_n` 派生；只管天启篇存档 | gpt 甲档核 cc/tianqi-seed-fix | `XTianqiAffixRoll.SEED_FROM_SAVE = false` | gpt | 保留 |

## 改了什么

| 处 | 原来 | 现在（种子 key） | 计数 |
| --- | --- | --- | --- |
| `tianqi_reforge.gd` `reforge` 兜底 | `randf()` | `XTianqi.item_roll(s, item, "reforge")` → 种子 `derive(tq_seed_id, reforge\|n)`（返修一前是 `instanceId`） | 装备上 `tq_rng_n`，每次重铸 +1（与金钱重构的 `tq_reforges` 分开：那个只在金钱重构开着时涨，不能当随机计数） |
| `tianqi_reforge.gd` `reforge_locked` 兜底 | `randf()` | `reforge_lock\|n`（同一个 `tq_seed_id`） | 同一个 `tq_rng_n` |
| `tianqi_alien_gear.gd` `attach` 兜底（`create` 不给 rng、不指定词条时） | `randf()` | `alien_attach\|<账本 sequence>` | 异化账本 `sequence`（本来每打一件 +1、随存档） |
| `tianqi_alien_gear.gd` `reroll` 的 `pending.next` | `randf()`（`XAlienation.force_roll` 测试钩子照旧优先） | `item_roll(s, i, "alien_reroll")`（返修一前是异化 uid＋账本 `tq_reroll_n`） | 装备上的 `tq_rng_n` |
| `tianqi_affix_roll.gd` `apply` 不传 rng 时（返修二） | `XGear.roll(s)`（运行时装备流） | `XTianqi.save_stream(s, "affix_roll\|n")` | `flags.tianqi.affix_roll_n` |
| `tianqi.gd` `draw_offer` 不传 rng 时 | `rng.randomize()` | `offer\|<draws>` | `flags.tianqi.draws`（本来随存档，每收一位 +1） |

掉落路径（`XTianqiAlienGear` 战斗奖励里的 `create`）照旧传战斗奖励流，不走兜底，不受影响；刻印（`engrave`）指定词条，不随机。

## 漏网清单（rg `randf(`、`randi(`、`randomize(`、`fresh_seed(`、`RandomNumberGenerator.new()`、`pick_random(`、`.shuffle()`；`modes/xiyou/core/tianqi*.gd` 与引用天启篇的 ui／map／battle 脚本）

| 文件:行 | 用途 | 影响玩家可得结果 | 处理 |
| --- | --- | --- | --- |
| `core/tianqi_qiyin.gd:74`（`next_seed` 里 `fresh_seed`） | 七印存档派生的回退路径（O-427 关掉时） | 只在开关关着时 | 已修（qiyin-endgame），不动 |
| `core/tianqi_qiyin_dragon_run.gd:267` | 招募候选：`RandomNumberGenerator.new()` 后用存档派生种子 | 否（已派生） | 不动 |
| `core/tianqi_drop.gd:249` | 掉落账种子 `randi()`，只在 `SEED_FROM_SAVE`（掉落）关着时 | 只在开关关着时 | 已修（econ-fix），不动 |
| `core/tianqi_affix_roll.gd:65` | 新装备掷天启篇词条的兜底 `XGear.roll(s)` → 装备流（`XState.random_master`，运行时、不随存档） | 是 | 首轮没修；gpt 甲档认定同样可读档重掷，返修二只在天启篇存档修掉（O-待定-2），西游档照旧 |
| `core/tianqi_qiyin_show.gd:309` | 展示动画抖动，固定种子 | 否（纯表现） | 不修 |
| `map/tianqi_table.gd:56` | 方桌裂纹形状，固定种子 0x7A61 | 否（纯表现） | 不修 |
| `battle/battler_sprite.gd:100、741` | 战斗精灵呼吸相位、视觉抖动 | 否（纯表现） | 不修 |
| `map/mv_event.gd:28` | 地图 NPC 随机走动 | 否（纯表现，原版同样） | 不修 |
| `battle/battle_logic.gd:56、3460` | 没有存档时（测试夹具）现开战斗随机 | 否（正式战斗走 `reserve_battle_random`） | 不修 |

天启篇界面脚本（`ui/alien_workshop.gd` 等）里没有直接取随机的地方。

## 交接板

- 下一步：gpt 复核 cc/tianqi-seed-fix 返修三（644ba74f5）。
- 用户试玩说明：天启篇重铸、异化重抽、通关抽角色候选、新装备天启篇词条读档再掷结果不变。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 核查返修（gpt 甲档）

gpt 认可：五处正常存读档复现成立；重铸无预览取消、直接付费落定；异化重抽放弃不退石不退计数；draws 推进时机对；流独立于战斗和全局流。返修两项，分开提交：

| 问题 | 修法 | 测试（断言） |
| --- | --- | --- |
| P2 `item_roll`／`reroll_roll` 拿可重编的 `instanceId`／异化 uid 当随机身份：`XStarWarehouse.withdraw_gear` 取出时删 `instanceId` 重新登记、重分异化 uid，读档后存进再取出星辰仓库就换了流 | 返修一 f10073d43：`XTianqi.seed_id` 第一次掷时给装备分配 `tq_seed_id`（`derive(orb_seed, tq_seed_id\|seed_id_n)`，本档计数 `flags.tianqi.seed_id_n` 单调），写在装备字典上、永不重编；`item_roll` 的流只看 `tq_seed_id`＋`tq_rng_n`（不再掺当前存档的种子，换存档、进出仓库都一样）；重抽改走同一个 `item_roll`，删掉 `reroll_roll` 和账本 `tq_reroll_n` | `xiyou_tianqi_seed_fix`：`star_renumbered`（取出后 instanceId、异化 uid 确实变了）、`star_reforge_same`、`star_reroll_same`、`star_sid_kept`、`wh_reforge_same`（普通仓库存→存档→读档→取出）、`sid_assigned`、`sid_unique` |
| 同上，核号在各路径下保留、不被复制成两件同号 | 逐条核：普通仓库存取、星辰仓库存取、存读档都是整件字典搬运，号跟着走；异化刻印／重抽、异化隐藏还原、专武前缀还原、宝石插槽 `XGearUpgrade.apply`（副本算完 merge 回原件）都是原地改；吸取视图、装备预览、小猫剑视图是临时副本不进背包；商店卖出、掉落生成、商人进货都是新建（还没掷过，没有号）。**合法复制路径三处**：魔冠账本重发 `XDemonCrown._grant`、云裳发货 `XYunshangOrders.grant_spec`、仓库原版复制（`XWarehouse.o_reserved_no_dup` 关时吞噬占着的武器多存一份）——复制品去掉 `tq_seed_id`，要用时另拿新号 | `yun_copy_no_sid`、`yun_copy_new_sid`、`crown_copy_no_sid`、`dup_reserved`、`dup_copy_no_sid` |
| 漏网 `tianqi_affix_roll.gd:65`：新装备词条兜底走运行时装备流 | 返修二 cf1cad1a2：只在天启篇存档（`apply` 原有的 `on(s)` 门）把兜底换成 `XTianqi.save_stream(s, affix_roll\|n)`，`n`＝`flags.tianqi.affix_roll_n`，每掷一件 +1。`XGear.roll_fn`（深渊商人本轮种子）、`roll_seq`／`force_roll`（测试磁带）照旧优先。没动 `XGear.create`／`roll_item` 签名，西游档不进这条分支 | 新专项 `xiyou_tianqi_affix_seed` 18 条：`create_same`／`create_varies`／`prefix`／`counter`（存→生成→读→再生成）；`battle_same`（存→打出掉落→读→再打同一场：战斗流钉成固定种子，只让装备流随读档变，掉的是同几件且词条一样）；`legacy_init`（存档去掉 `affix_roll_n`）；`off_differs`、`battle_off_differs`、`off_no_counter`（开关关回运行时流）；`roll_fn_first`；`plain_untouched`（西游档） |

断言数：`xiyou_tianqi_seed_fix` 37→56，新 `xiyou_tianqi_affix_seed` 18，全部通过。
反向验证（`反向验证.py`）：返修一 6 处（流改回按 instanceId、随机身份每次重分、重抽改回按异化 uid、云裳／魔冠／仓库复制不去号），返修二 4 处（兜底改回运行时装备流、计数不推进、开关关时仍派生、不让 roll_fn 优先）各改坏一次，专项全部失败，咬得住；源文件按备份还原。

### 第二轮（gpt 复核 f10073d43／cf1cad1a2）

gpt 认可：复制品去号、异化重抽计数推进、`affix_roll_n` 随档保存、西游档零影响。返修三 644ba74f5：

| 问题 | 修法 | 测试（断言） |
| --- | --- | --- |
| P2 `seed_id`：`tq_seed_id` 到首次掷才按全档 `seed_id_n` 分配，号绑的是「第几件先被洗」：A、B 都没号时，直接洗 A 得 0 号，读档后先洗 B 再洗 A，A 得 1 号、流变了；没掷过的装备跨存档搬也能挑分配档。原仓库用例保持了同样的首次洗装备顺序，盖住了问题 | 号改为 `derive(orb_seed, "tq_seed_id\|" + instanceId)`，只取决于这件装备（`instanceId` 本档内唯一、读档不变），去掉 `seed_id_n`。**入包即分配**：收拢到 `XState.register_gear` 一个入口（天启篇里掉落、商店、商人、七印揭开、事件赠送、魔冠／云裳复制品都经它，rg `register_gear(` 共 15 处调用；其余直接 `s.gear.append` 的都是已登记的件：卸下的装备、`XAlienation.create`／`XTianqiAlienGear.create` 内部已登记的异化件）。**老件补号**：`XState.from_dict` 末尾和 `XTianqi.start_new_game` 调 `assign_all`，遍历顺序写死在注释里：背包 `s.gear` → 身上（角色号从小到大）→ 各仓库（仓库名排序，类别按 `XWarehouse.CATEGORIES`）；已有号不动，新号撞了已有号（只有原版仓库复制那种同 `instanceId` 的复制品会撞）按这个顺序加后缀。读档时 `register_gear` 早于 flags 读入，不会抢先分配。**星辰仓库老件**：`withdraw_gear` 在删 `instanceId` 之前 `before_renumber`，用旧 `instanceId`＋整件内容派生，与取出顺序无关。`seed_id` 仍留兜底（没经登记的装备先整档补一遍再取） | `xiyou_tianqi_seed_fix`：`ord_ids_on_register`、`ord_new_gear_has_id`（`gain_gear` 真实入包）、`ord_legacy_all_assigned`、`ord_legacy_ids_stable`（老档去号读两次号一样）、`ord_b_then_a_same`（先洗 B 再洗 A＝直接洗 A）、`ord_lazy_b_then_a_same`（两件都没号也一样）、`ord_star_order_free`、`ord_twin_distinct`（同 instanceId 两件读档各有号、已有号不动、两次读档一样）；复制品断言改为 `yun_copy_own_sid`、`crown_copy_own_sid`（登记时拿到与原件不同的新号） |
| 测试缺口：`battle_same` 钉死 `lg.random`，没证明真实战斗 | `xiyou_tianqi_affix_seed` 补 `_real_battle`：走真实入口（`setup` 里 `reserve_battle_random` 取战斗流 → `rewards` → `grant`），不钉 `lg.random`。**查清的层次**：掉哪几件（敌人掉落、天启篇通用掉落）由战斗奖励流决定，它的根 `XState.random_master` 只在运行时、不进存档，读档后现开一条，所以读档再打同一场**掉落件本身会不同**——这是整局既有口径（招牌掉落另走存档里的掉落账 `tianqi_drop.store`，读档一样；econ-fix 已注明），不是词条流的问题，本单不硬凑。词条这层已抗读档：实测不钉根时两次读档掉的是不同底子（1340、1117 号武器），词条却完全一样（同为第 n 件掷词条） | `real_master_not_saved`（开过战斗流后存档文本里没有根）、`real_same_root_same`（同一个根经正式的调试回放入口 `restore_runtime_random` 放回，真实结算整场掉落连同词条完全一样）、`real_root_fresh_each_load`（每次读档根不同）；不钉根的两次结果只打 INFO 记录，不断言相等 |

断言数：`xiyou_tianqi_seed_fix` 56→64，`xiyou_tianqi_affix_seed` 18→22，全部通过。
反向验证（`反向验证.py`，专项 `xiyou_tianqi_seed_fix`）：首次掷才按计数分配（gpt 指出的旧写法）、入包不分配、读档不补号、撞号不加后缀、星辰老件按取出次数 5 处各改坏一次，全部咬住。另：只改 `seed_id` 末尾兜底分支那一刀没咬住——兜底前先整档 `assign_all`，按 instanceId 派生，兜底分支只给不在任何容器里的装备用，测试走不到，属预期；`real_*` 三条是查层次用的，不对词条修复本身做反向。

说明：随机身份换存档也不变，是有意的——星辰仓库跨存档，若流掺当前存档种子，同一件在 A、B 两档各能掷出一条，多一条分支可挑。

## 验证

- 新专项 `xiyou_tianqi_seed_fix`（真实 `XSave.save`→`XSave.load_slot` 写盘读档）37/37：每处「存→掷→读→再掷相同」（`rf_reload_same`、`al_create_same`、`al_reroll_same`、`of_same`、`of_second_same`）；连掷不全相同、读档后前缀可复现（`rf_runs_differ`、`rf_prefix_same`、`rf_continues`、`al_create_varies`、`al_reroll_varies`、`al_reroll_prefix`、`rf_items_independent`、`of_draws_independent`）；老档去掉计数字段写回存档文件再读能补上（`rf_legacy_*`、`al_legacy_*`），去掉 `orbSeed` 也可复现（`rf_no_orb_same`、`of_no_orb_same`）；开关关掉两次读档结果不同、不写计数（`rf_off_*`、`al_off_*`、`of_off_differs`）；`force_roll` 测试钩子照旧优先。本机连同 `xiyou_tianqi_reforge`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_party` 全部通过。
- 反向验证（`反向验证.py`，专项 `xiyou_tianqi_seed_fix`）：8 处各改坏一次（重铸／锁词条重铸回到 randf、装备计数不推进、异化兜底回到 randf、重抽计数不推进、重抽回到 randf、候选回到 randomize、开关关时仍派生）全部让专项失败，咬得住；源文件按备份还原。
- 语法检查：0 个问题（返修后重跑）。工具回归 `工具回归.py` 全部通过（首轮、返修后各一次）。
- 返修本机专项：`xiyou_tianqi_seed_fix` 56/56、`xiyou_tianqi_affix_seed` 18/18，连同 `xiyou_tianqi_affix_roll`、`xiyou_tianqi_drop`、`xiyou_star_warehouse`、`xiyou_tianqi_reforge`、`xiyou_tianqi_alien_gear` 全部通过。
- 返修三选测：合 main 后 `云端选测.py run`（提交 a735aaf34，基准 c9302d704，改了 `xstate.gd` 所以面广），489 个场景全部通过；本机 `xiyou_tianqi_seed_fix` 64/64、`xiyou_tianqi_affix_seed` 22/22；语法检查、工具回归通过。
- 返修选测：`云端选测.py run`（提交 cf1cad1a2，基准 6ae0b0469），65 个场景全部通过。
- 首轮选测：合 main 后 `云端选测.py run`（提交 6ae0b0469），471 个场景、16 片全部通过（基准 3b7033b56，名单含 main 新合进的改动，比 `选测.py main --list` 的 54 个多）。不需要 `--oracle`（新机制，没碰原版移植逻辑）。

## 待交叉核查

- 返修三只复核 644ba74f5（`core/tianqi.gd` `seeds_on`／`on_register`／`before_renumber`／`all_gear`／`assign_all`／`seed_id`、`start_new_game` 一行；`core/xstate.gd` `register_gear`、`from_dict` 各一行；`core/star_warehouse.gd` 一行；两个测试）。
- 返修一、二已复核：f10073d43（`core/tianqi.gd` `seed_id`／`item_roll`、`core/tianqi_alien_gear.gd` `reroll`、`demon_crown.gd`／`yunshang_orders.gd`／`warehouse.gd` 各一行、测试）和 cf1cad1a2（`core/tianqi_affix_roll.gd` `_default_rng`、新专项 `xiyou_tianqi_affix_seed`）。
- 首轮甲档（存档、装备随机流）：`core/tianqi.gd`（`SEED_FROM_SAVE`、`save_stream`、`save_roll`、`item_roll`、`draw_offer`）、`core/tianqi_reforge.gd` 两处兜底、`core/tianqi_alien_gear.gd`（`attach` 兜底、`reroll`、`reroll_roll`）、`tests/xiyou_tianqi_seed_fix.gd`。
- 重点：老档缺计数字段；`tq_rng_n` 写在装备字典上会不会影响别处按字典比较装备（先例：金钱重构的 `tq_reforges`、`tq_buy_price` 也写在装备字典上；本单 rg 没找到按 hash／JSON 比较装备内容的地方，`targets` 等用 `is_same` 认引用）。

## 本分支提交

- a735aaf34 合并 main
- 644ba74f5 返修三：随机身份入包即分配、老件读档按固定顺序补号
- cf1cad1a2 返修二：天启篇新装备掷词条改存档派生（O-待定-2）
- f10073d43 返修一：装备随机身份 tq_seed_id 随物品走、永不重编
- 6ae0b0469 合并 main
- 1d4096a5c 天启篇读档重掷修复：重铸、锁词条重铸、异化兜底／重抽、抽角色候选改存档派生随机
