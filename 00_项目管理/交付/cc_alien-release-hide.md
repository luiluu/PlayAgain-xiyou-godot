# 交付：cc/alien-release-hide

- 车道／工作者：C 规则·界面（快车道）／cc（车道 C）
- 状态：可合并
- 总装三十八补：分支改为 cc/alien-release-hide-fix，先合了 cc/rift2-canglong-fix（item_marks.gd 号角过滤冲突：保留 horn_id_disabled，再接 XAlienHide.filter_goods）；顺带 cc/o-pending-register1 剩下的两处探针注释换号（heartsteel O-150、tusu O-148），这两份探针会重量。按慢车道合。

## 变更记录草稿

## 2026-11-11 【cc·车道C·未经审查】发行整包隐藏深渊异化：补全 O-283 物品侧，加发行开关（dev.待定）

Kyo 11-11「新整包里异化相关装备和词条都不开放」。正式 v0.58 `installAlienationHide` 原来只跟了遭遇、奖励、工坊三件（O-283），这次照原版补全另外几件，并加发行开关：

- 开关：`XAlienBattle.hidden()`＝`HIDDEN_V058`（O-283，开发版默认 false，不变）或 `RELEASE_HIDE`（O-待定·异化发行隐藏，默认 true）且发行构建（`ReleaseEntry.is_release`）。开发版、测试照旧开着异化；发行包里隐藏。以后开放发补丁把 `RELEASE_HIDE` 改 false。
- 新文件 `modes/xiyou/core/alien_hide.gd`（XAlienHide）管物品侧，六件：异化能量 2872、异化石 2873、深渊残刃 3980、残杖 3981、残甲 7980、残环 7981。
  - 得到：`XState.gain_item`／`gain_gear` 数量为正时挡下（掉落、事件、商店、合成都经这两个口；减少照常）。
  - 看见：物品列表（`XItemMarks.apply_list`）、装备列表（`XItemScene.bag_gear`，物品页／装备页／出售／两种仓库存放共用）、商店进货（`XItemMarks.shop_goods`）都去掉。
  - 装备：`XActor.can_equip` 返回 false；当词缀：`XGear.valid_affix` 不收（原版 isValidItem 包装）。
  - 主菜单：`XMenu.commands()` 去掉「异化工坊」（原来只是点了打不开，现在照原版整行不显示）。
  - 读档迁移（`XState.from_dict` 里，原版 extractSaveContents 包装）：只跑一次，标记 `flags.alienHiddenV058` 随存档。背包、身上、PH 仓库里的异化实例还原成普通装备（名字回原名、去掉异化标记）；能量和异化石记数量归档进 `flags.alienHiddenItems`；残响整件移进 `flags.alienHiddenGear`，身上卸下的记 `alienHiddenEquip`、仓库移出的记 `alienHiddenWarehouse`；待选重抽清掉，最近掉落记录保留。
  - 星级仓库（跨存档，原版没管）：取出列表不列残响、残响取不出；取出的异化装备还原。
- 与原版的差别：原版把残响留在队伍容器里打隐藏标记、靠各列表过滤；重制把残响整件移出背包进归档，背包里就没有，列表过滤只是兜底。原版 `hasItem` 对两件材料恒 false，重制不另包（迁移后背包里不会再有）。
- 参照：新探针 `mv_oracle/alien_hide_probe.cjs`（产物 `alien_hide.json`，已登记进同步 PROBES）在装与不装 `installAlienationHide` 的两个引擎里各量一次：主菜单、六件物品得到／列表／商店、对残响本体的 canEquip、读档迁移。
- 专项 `tests/xiyou_alien_hide`（77 项）：参照两套（发行模拟对 hide.*、开发版对 plain.*）逐项比，另测开关组合、PH 仓库迁移、迁移只跑一次、身上普通异化装备还原后照穿、开发版不迁移、词缀、星级仓库存取、兜底过滤。反向验证 11 处改坏全部咬住。
- 改了 `actor.gd`（`can_equip` 一行）、`xstate.gd`（`gain_item`／`gain_gear` 各一行、`from_dict` 一行），这两个是原沙僧核心文件，开发版下新加的判断恒不生效（`hidden()` 为 false 时直接放行，不取随机数）。
- 玩家可见：发行版里看不到「异化工坊」，拿不到、看不到深渊异化的能量、异化石和四件残响；读旧档时身上和背包里的异化装备变回普通装备，残响和异化材料收进存档里的归档（以后开放可以退回）。

## 交接板

- 下一步：无新增（发行整包口径里「异化不开放」这一条由本分支做完）
- 用户试玩说明：发行包读档后异化装备变回普通装备，主菜单没有异化工坊；开发版不变
- 需要用户决定：无

## 进度账

- 无（扩展账：v0.58 异化隐藏从「只跟遭遇／奖励／工坊」到全套跟上）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·异化发行隐藏 | `modes/xiyou/core/alien_battle.gd` `XAlienBattle.RELEASE_HIDE`、`hidden()` | 正式 v0.58 起深渊异化整套隐藏；重制开发版保持开启（O-283 默认 false） | 发行构建（`ReleaseEntry.is_release`）里异化整套隐藏（遭遇、奖励、工坊、六件物品、读档迁移，同 O-283 打开）；开发版、测试不变 | Kyo 11-11「新整包里异化相关装备和词条都不开放」 | `XAlienBattle.RELEASE_HIDE = false`（发行版也开放） | cc（车道 C） | 保留 |

O-283 原行已在 `00_设计/优化登记.md` 原处改写（补全的几件、与原版的差别、参照探针）。

## 可优化（流程／工具／效率）

- 无

## 验证

- `语法检查.py` 通过。
- 专项：`xiyou_alien_hide` 77/77。
- 选测 54 个全过（308 秒）：xiyou_alien_hide／affix／battle／config／workshop、item_bag／list／marks／use、shop_buy／stock／auto_close、lobby_shops、map132_shop、warehouse、star_warehouse、equipment、equipment_admission、gear_ui／detail／search、flow、list_paging、crafting、enemy_book、party、hangup_options、orb_shop_ui、review135、pause_save、save_page、save_events、autosave、determinism、merchant29、affix_rate、battle_drop、drop_record、demon_crown、yunshang、yunshang_shop、growth_forge、treasure_batch、entry_release、tianqi_opening、tianqi_gear、super_acquire、wtype、dual_wield、orbs、global_vars、cat、heartsteel、actor_change。
- 没跑 `选测.py` 列的其余战斗核心场景（xiyou_rules 各段、事件对照等）：本分支在开发版下新加的判断恒不生效（`hidden()` 为 false 时直接放行、不取随机数），xiyou_determinism 已覆盖随机数顺序；交总装按影响面补。
- 反向验证（`反向验证.py`）11 处改坏：不挡 gain_item／gain_gear、不迁移、菜单不去工坊、can_equip 不挡、商店／物品列表／bag_gear 不滤、发行不隐藏、星级取出不还原、词缀不挡，全部咬住。
- 工具回归 `工具回归.py` 全过；`回退开关覆盖.py` 退出 0。
- 同步：本树 `同步正式西游.py --accept-additions` 测量不变、只增 `alien_hide.json`，留了同步指纹（新探针 186 秒）。

## 本分支提交

- 809d4d5b4 异化发行隐藏：XAlienHide 物品入口拦截、菜单去工坊、读档迁移、RELEASE_HIDE 开关、alien_hide 参照探针
- 10771827c 专项 xiyou_alien_hide、O-283 登记改写、交付单草稿
- （本提交）交付单定稿
