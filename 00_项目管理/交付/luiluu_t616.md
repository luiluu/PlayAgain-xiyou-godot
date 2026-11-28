# 交付：luiluu/t616

- 车道／工作者：T616 玩家反馈「头顶放进仓库再取出就消失，读档也找不回」（cc，Opus＋high，P8）
- 状态：可合并

## 结论（根因）

跟 T548（天启篇头顶层数窗口）和防 SL 的存读档封存都**无关**；是魔冠「"头顶"」7940 自己的**成长账本**写法，原版 `installNativeDemonCrownRuntime.js` 第 181～187 行同样写法（原版缺陷，照「原版 bug 要修」改，带回退开关）。

1. 头顶的成长、掉落、失去记在存档目录旁的独立账本 `crown_progress_v1.json`（发行版封存为 `.ksv`），**不随读档回滚**；每次存档（`before_save`）、读档（`after_load`）都按账本「重放」：账本里 `removed: true` 的那件从背包／身上删掉。
2. 存进方桌仓库：`XWarehouse.deposit` → `XState.lose_gear(rec)` → `XDemonCrown.lost`，把这件记成 `removed`（和卖掉一样，原版是 `$gameParty.loseItem` 被包装当成失去）。
3. 从仓库取出：`XWarehouse.withdraw` 只把实例放回背包，**账本不改**，`removed` 还在。
4. 下一次重放（存档时、读档时）按 `removed` 把它删掉 → 「取出来就消失了」。
5. 读存仓库之前的档：那份档里它在背包／身上，但账本已经是 `removed`，读档重放照样删 → 「回档都没用」。

代码位置：`modes/xiyou/core/warehouse.gd` `deposit`（改前第 150 行 `s.lose_gear(rec)`）、`modes/xiyou/core/xstate.gd:836`（`lose_gear` 调 `XDemonCrown.lost`）、`modes/xiyou/core/demon_crown.gd` `lost`／`replay`／`_remove`。西游档、启封档都一样（账本不分档）。

**云裳天衣（带 `_yunUid`，同样用存档外账本）有同类问题但轻一些**：账本是按序号的日志，存仓库记一条 `remove`；同一局里取出不会被删，只有**读存仓库之前的档**时这条 `remove` 重放、把背包里那件删掉。一起修了。

## 玩家的头顶还能不能找回（验收 2）

账本里每件头顶都按编号留着整件底稿（词条、品质）和成长 `bonus`，存仓库只是多了一个 `removed: true`，**数据没丢**。装上修复后：

- **还在仓库里的**（存了没取出）：读档时自动撤销 `removed`，取出后存档读档都在（专项 `heal.wh_back`、`heal.persists`）。
- **取出后消失、但某份存档里它还在背包／身上的**（例如存仓库之前存的档，且那份档之后没有被覆盖）：读那份档时自动撤销 `removed`、成长原样（口径 A，Kyo／项目经理 11-28 定；专项 `heal.bag_back`、`heal.identical`、`heal.grows`）。玩家说「回档都没用」——读档时被删的只是内存里那份，只要读完没再存盖那一格，存档文件里还有。
- **哪份存档里都没有了的**（取出后又存档盖掉了所有旧档）：读档修复不了，因为账本分不清它是存过仓库还是真卖掉。账本里底稿和成长还在，可以手工恢复：拿到玩家的账本和存档后，把账本本档那条 `items` 里修复前写的 `removed: true`（没有 `lost` 标记的）改回 `false`，再从存档 `flags._codexCrownKnown` 里去掉这几个编号，读档时重放就按底稿＋成长重新发到背包。分不清哪几件是卖掉的，按玩家说的数量和词条对。**没做成工具**（要动玩家存档和账本，等玩家真发来再做，避免扩大改动）。
- 修复版第一次读档时把账本原样复制一份 `crown_progress_v1.json.t616bak`（发行版 `….ksv.t616bak`，云裳的同理 `yunshang_orders_v1.json.t616bak`），只备一次、之后不覆盖（专项 `heal.backup_made`、`heal.backup_once`）。

## 改了什么

- `modes/xiyou/core/warehouse.gd` `deposit`：带头顶编号或云裳编号的装备，对应开关开着时 `lose_gear(rec, false)`（拿出背包，不记账本）。
- `modes/xiyou/core/demon_crown.gd`（开关 `WAREHOUSE_KEEP`，默认 true）：
  - `_find` 也找方桌仓库里的那件（新 `stored(s)`）：重放把账本成长盖到仓库那件上；`_remove` 真失去的那件在仓库里也拿掉（仓库占用跟着减）。
  - `lost` 写 `removed` 时带 `lost: true`：修复后的真失去（卖出、分解、吞噬、喂法宝…）读更早的档照旧删除，防 SL 口径不变。
  - 修复前写下、没有 `lost` 标记的 `removed`：`replay` 不再据此删除；`_heal`（读档、存档时，在收编和重放之前）把指向本档里还在的那件（背包、身上、仓库）的撤销成 `removed: false`，撤销前 `backup_once`。
  - `after_load` 开头 `backup_once`。
- `modes/xiyou/core/yunshang_orders.gd`（开关 `WAREHOUSE_KEEP`，默认 true）：`lost` 的 `remove` 带 `src: "lose"`；读档重放时，修复前写下（没有 `src`）、不是进阶消耗、指向**背包里**那件的 `remove` 以存档为准保留（穿着的仍归 O-472 `KEEP_WORN_ON_LOAD`）；`after_load` 重放前 `backup_once`。
- 测试：新增 `tests/xiyou_warehouse_crown`（西游档、启封档各一遍，真写盘真读档）；`xiyou_yunshang_shop` 的 p8.lose 方桌仓库拆成 `warehouse`（开关关掉照原版比卖出）和 `warehouse_keep`（开着比按底子扣）；`xiyou_yunshang_gear_load` 的 `newer_remove_bag` 改用带 `src: "lose"` 的修复后写法（照旧删），另加 `legacy_remove_bag`（修复前写法，保留）和 `switch_off.legacy_bag_removed`。

## 验收（卡上 5 条）

1. ✓ 复现与根因：见上「结论」。专项 `repro.*` 在开关关掉（＝修复前）时真跑出玩家现象：存仓库后账本记 `removed`（`repro.a_marked_removed`）、取出后一存档就没了（`repro.gone_after_save`）、读存仓库之前的档也没了（`repro.old_save_gone`）、仓库里取出的那件存档后也没了（`repro.c_gone_after_save`）。身上卸下的（打过 3～5 场胜仗、有成长）和刷出的（成长 0）都覆盖。
2. ✓ 数据在、能找回：见上「玩家的头顶还能不能找回」。读档自动修复覆盖「还在仓库里」「某份存档里还在」两种；「哪份存档里都没了」写清了手工办法，没做工具。
3. ✓ 修复：存仓库→取出→存档→读档，两件都在背包、整件一字不差（成长、词条、孔位、特性倍率都比了，`fresh.*.identical`；只排除底子模板的 `equipment` 词条池定义，它本来就由存档瘦身不存、读档按模板补，普通装备也一样）；账本没记 `removed`；再穿上打一场照常成长（`fresh.grows_again`）。放在仓库里存读、账本成长变了照样盖到仓库那件上（`stored.*`）。
4. ✓ 顺查：
   - 普通武器、防具：存取存读不受影响（`other.weapon.back`、`other.armor.back`），本来就没有这个问题（只有带存档外账本的才有）。
   - 带成长／账本的：头顶（修）、云裳天衣（同类，修）。存仓库会碰到存档外账本的入口只有 `XState.lose_gear` 里 `record` 的两支（头顶 `XDemonCrown.lost`、云裳 `XYunshangOrders.lost`）；心之钢／利维坦、狂妄／无我锻造（`growth_forge.gd`）、法宝（`magic_weapon.gd`）不读写文件，阶数、等级在装备实例上随存档走；异化配置（`XAlienation.ledger(s)`）在存档里。存档目录旁的其它文件（星级仓库、`global.json`、洪荒称号、瘦身日志）都不记「失去」。所以别的装备存仓库不受影响（`xiyou_alien_*`、`xiyou_star_warehouse`、`other.*` 照过）。
   - 星级仓库（跨存档）：原来就是 `lose_gear(rec, false)` 不记账本，没这个问题。
   - 另发现（没改，写在「可优化」）：头顶存进**星级仓库**再在**另一个存档**取出，那份档的账本档案里没有这个编号，之后不涨成长（成长值保留）。跟本单的丢东西无关。
5. ✓ 西游档、启封档都回归，见「验证」；动账本前先备份（`backup_once`）；测试全在 `user://test_*` 临时目录，没碰真实存档。

## 风险（防 SL 那半）

- **账本放存档外本来就是防 SL**：成长不能靠读档回滚、同一场重打不重掷掉落、卖掉的读旧档拿不回来。修复后：
  - 刷成长：**不能**。成长值只认账本（重放把账本的 `bonus` 盖到实例上，撤销 `removed` 也不改成长）；遭遇序号与开战掷点没动（`xiyou_demon_crown` 106/106、`xiyou_demon_crown_compact` 48/48、`xiyou_demon_crown_floor` 116/116 照过）。
  - 复制头顶：**同一份存档里不会**。存仓库不记账本后，仓库内容只在存档里，跟别的装备一样；账本每个编号一件，重放只在「哪里都找不到、又没在本档建过」时才发（`heal.no_conjure`：修复后存的档里没有那件就不凭空发）。
  - 唯一放松：修复前（0.04.09 之前）写下的 `removed`，读到一份它还在背包／身上的旧档会保留——这里面也包括**修复前真卖掉**的头顶：读卖之前的档，头顶回来，但卖的钱随旧档一起回滚，等于普通读档，不算刷（Kyo 定 A 时已认）。修复后卖掉的带 `lost` 标记，照旧不能靠读档拿回（`sold.bag_removed`、`sold.wh_removed`）。
  - 云裳同理；另有一处我想到的边角：修复前「领取天衣→卖掉」，再读领取之前的档，账本重放先发后删，A 口径下那件会保留（领取不能重来，订单已清，钱随档回滚），仍是一件，不算复制。
- 分不清是不是真卖掉的那批（修复前的 `removed` 且哪份档里都没有），自动修复不了，只能手工（见上）。
- 头顶在多个存档格里都有同一件（玩家复制过存档文件）：每份档各自读档各自保留，跟普通装备复制存档文件一样；同一份档里不会出两件。

## 验证

- 本机专项（`并行测试.py --full`，无头，各测试独立临时 HOME；`XTestMode unlocked=false enabled=false` 见 `xiyou_warehouse_crown` 日志）：36 个场景全过——
  `xiyou_warehouse_crown` 153/153（新）、`xiyou_demon_crown` 106/106、`xiyou_demon_crown_compact` 48/48、`xiyou_demon_crown_floor` 116/116、`xiyou_yunshang` 1675/1675、`xiyou_yunshang_shop` 458/458、`xiyou_yunshang_gear_load` 148/148、`xiyou_yunshang_wraps` 214/214、`xiyou_warehouse` 32/32、`xiyou_star_warehouse` 99/99、`xiyou_item_marks` 136/136、`xiyou_shop_multi_sell` 95/95、`xiyou_shop_buy` 8479/8479、`xiyou_shop_stock` 56/56、`xiyou_merchant29` 140/140、`xiyou_save_seal` 127/127、`xiyou_save_slim` 126/126、`xiyou_save_cold_load` 27/27、`xiyou_tianqi_save` 82/82、`xiyou_tianqi_seed_fix` 77/77、`xiyou_tianqi_random` 75/75、`xiyou_tianqi_gear2` 51/51、`xiyou_tianqi_money` 82/82、`xiyou_tianqi_gongfa_shop` 42/42、`xiyou_alien_affix` 2184/2184、`xiyou_alien_config` 95/95、`xiyou_alien_hide` 77/77、`xiyou_elemental_king` 1107/1107、`xiyou_honghuang_reward` 311/311、`xiyou_fest_reward` 56/56、`xiyou_baby_all_actors` 36/36、`xiyou_review20_fix` 4/4、`xiyou_script_gaps` 73/73、`xiyou_ui_skin_card_n` 99/99、`xiyou_ui_skin_card_o` 126/126、`xiyou_ui_skin_shop` 124/124。
- 改前跑同一批（先改代码、后改测试那一刻）：`xiyou_yunshang_gear_load` 3 条、`xiyou_yunshang_shop` 4 条按原版口径断言「存仓库记 remove」失败，与预期一致，已按开关两态改测试；其余照过。
- `语法检查.py`：1288 个 .gd 0 问题；`发行空壳.py check` 退出码 0（89 个脚本 880 个函数，本单没动天启篇脚本）。
- 云端选测：通过，28 个场景 6 片（最长一片 3.1 分钟），基准 964e8f1208，提交 60c83087eb（之后只加交付单），https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46131578655（`gh run watch` 前台等完，conclusion success）。推产物时提示「上次 --补齐 时总装正在合并，没刷新参照」：本单没动转换产物和参照，不影响。

## 优化登记草稿

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/warehouse.gd` `deposit`；`modes/xiyou/core/demon_crown.gd` `XDemonCrown.WAREHOUSE_KEEP`（`lost`、`replay`、`_find`、`_remove`、`_heal`、`after_load`）；`modes/xiyou/core/yunshang_orders.gd` `XYunshangOrders.WAREHOUSE_KEEP`（`lost`、`remove_uid`、`after_load`） | 存进方桌仓库走 loseItem，头顶／云裳天衣在存档外账本里记成失去；头顶取出后下一次存读档被删、读存仓库之前的档也被删，天衣读存仓库之前的档被删 | 存仓库不记账本，重放认仓库里的头顶；修复后的真失去带标记，读旧档照旧删；修复前误记的失去，读档时这件在本档里就以存档为准保留并撤销（口径 A），首读前备份账本一次 | 玩家反馈 0.04.08（Kyo 11-28 转）；口径 A 项目经理 11-28 定 | `XDemonCrown.WAREHOUSE_KEEP`、`XYunshangOrders.WAREHOUSE_KEEP` 分别设 `false` | cc（T616） | 保留 |

## 变更记录草稿

## 2026-11-28 【cc·T616·未经审查】头顶存进仓库再取出就消失、读档也找不回（dev.待定）

- 玩家反馈 0.04.08：头顶（魔冠 7940）存进方桌仓库再取出，下一次存档／读档就没了，读存仓库之前的档也没用。根因：头顶的成长账本在存档外、不随读档回滚，存仓库被当成「失去」记了 removed，取出不改账本，重放按 removed 删除（原版同样写法）。云裳天衣同类（读存仓库之前的档被删）。
- 修：存仓库不再记账本；重放认仓库里的头顶（成长照盖，真卖掉的照删）；修复后的真失去带标记、读旧档照旧删；修复前误记的，读档时这件在本档里就保留并撤销（口径 A）；修复版第一次读档前把两份账本各备份一次（`.t616bak`）。
- 回退 `XDemonCrown.WAREHOUSE_KEEP`、`XYunshangOrders.WAREHOUSE_KEEP` 设 false；专项 `xiyou_warehouse_crown`（西游档、启封档）、`xiyou_yunshang_shop`、`xiyou_yunshang_gear_load`。
- 玩家可见：头顶、云裳天衣存进仓库再取出不再消失；之前被误删的，只要哪份存档里它还在（背包、身上或仓库），读那份档就回来了。

## 交接板

- 下一步：O-待定 合并时换号。玩家若发来账本和存档、要找回「哪份档里都没了」的头顶，按本交付单「玩家的头顶还能不能找回」第三条手工恢复（要先认清哪几件是存过仓库的）。
- 用户试玩说明：头顶、云裳天衣存进方桌仓库再取出，存档读档都还在；之前取出就消失的，读一份它还在背包／身上／仓库里的旧档就回来了。
- 需要用户决定：无（口径 A 已定）

## 进度账

- 无（玩家反馈修复，不动完成度）

## 可优化（流程／工具／效率）

- 建议：头顶存进星级仓库（跨存档）再在另一个存档取出，那份档的头顶账本档案里没有这个编号，之后穿着不涨成长（成长值保留、不丢东西）。要不要让跨档取出时把这一件收编进新档案（或干脆不让头顶进星级仓库），属于玩法口径，建议总装问 Kyo 后另派；预计改动小（`XStarWarehouse.withdraw_gear` 后调一次收编）。
- 建议：存档外账本（头顶、云裳）将来再加「失去」类写法时，写上来源（本单起头顶带 `lost`、云裳带 `src`），免得再出现分不清存仓库还是卖掉的旧记录。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XWarehouse.deposit` | 非测试 1 处（`git grep -nE 'XWarehouse\.deposit' -- '*.gd' ':!*/tests/*'`：`ui/warehouse.gd:278` 存仓库画面） | 调用方 1 处逐处结论：只改「带头顶／云裳编号的那件记不记账本」，返回值、仓库占用、满了不放都不变；普通装备 `lose_gear(rec, false)` 与 `true` 行为相同（`record` 只影响这两种），`xiyou_warehouse` 32/32 照过 |
| `XDemonCrown.lost` | 非测试 1 处（`xstate.gd:836` `lose_gear`） | 调用方 1 处逐处结论：开关开着时多写一个 `lost: true`，返回值不变；卖出、分解、吞噬、喂法宝等真失去照旧记 removed 并当场删（`sold.marked`） |
| `XDemonCrown.before_save`／`after_load` | 非测试 3 处（`git grep -nE 'XDemonCrown\.(before_save|after_load)' -- '*.gd' ':!*/tests/*'`：`xsave.gd:40`、`:142`、`:365`） | 调用方 3 处逐处结论：在原来的收编、重放之前多一步 `_heal`（只在有修复前误记、且这件在本档时写一次账本），`after_load` 先备份一次；没有头顶的档 `_idle` 照旧直接返回，不建账本、不备份 |
| `XDemonCrown.replay`／`_find`／`_remove` | 文件内（`git grep -nE '_find|_remove|replay' -- '*demon_crown.gd'`） | 调用方逐处结论：`_find` 多找仓库（只在背包身上找不到时），`_grant` 因此能给仓库那件盖成长而不重发；`_remove` 多从仓库拿掉（只对带 `lost` 的真失去，修复前的由 `replay` 跳过）；开关关掉三处与改前逐字同 |
| `XYunshangOrders.remove_uid` | 1 处（`yunshang_orders.gd` `replay`） | 调用方 1 处逐处结论：新可选参数 `legacy`（日志没有 `src`）；只在读档重放、开关开着、不是进阶消耗、不是穿着的时候保留；进阶消耗的照旧删（`advance.*` 照过），穿着的照旧归 O-472 |
| `XYunshangOrders.lost`／`after_load` | 各 1 处（`xstate.gd:839`、`xsave.gd:364`） | 调用方逐处结论：`lost` 多写 `src: "lose"`；`after_load` 重放前备份一次；返回值与出错处理不变 |

## 截图

- 无（不涉及画面；结论全由专项断言核对）

## 本分支提交

- 见 `git log main..luiluu/t616`
