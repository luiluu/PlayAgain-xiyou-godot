# 交付：cc/review-30

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `c4473c42` 切出，只加本交付单。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 利维坦／杰作无我锻造、奈叶二期（比例收费、伤害后多段、预约、小魔炮 AI）、窗口底色内框、饿狼读档同步，及沿用云端失败集、事件普查结论

- 核查覆盖：cc/bajie-growth2b（33a5e029）；cc/wukong-nanoha2b（f6ba607b）；cc/bailong-ui2（c9b00c97）；cc/bailong-ui3（881063be）；cc/nezha-tools48（a20fc450）；cc/nezha-census2（ddbced75）
- 结论：P1 无，P2 无，P3 无，全部通过。甲档细核 growth2b（锻造锤、解锁补查、锻造事务、配方改写）与 nanoha2b（`battle_logic.gd`／`state_effects.gd` 改动、ACS 快速结算、智能 AI 魔炮），对照冻结 v0.28 逐条一致；三份参照探针（growth_forge、nanoha2、nanoha3）在本树重跑，产物与 tests/fixtures 逐例相同。乙档 ui2、ui3 通过：ui3「预排琦玉在 OTB 下取不到」对照 `Olivia_BattleSysOTB.js` 核实成立。丙档 tools48、census2 结论通过。另记两处原版与重制有差但现有数据走不到的地方（不记问题），见「报告」。
- 验证：对着冻结 v0.28 读码（`installNativeLeviathanForge.js`、`installNativeHubrisRuntime.js` 锻造段与读档包装、`plugins/hc.js` 配方、`YEP_SkillCore.js` skillMpCost／executeDamage／applyPostDamageEval、`Bailong_NaiyeACS_FastSettlement..js`、`Bailong_StarDamageRecord_ExactAction.js`、`Codex_SmartBattleAI.js` 魔炮段、`installBulkPillsRuntime.js`＋`rpg_core.js` `_refreshBack`、`installNativeGarouRuntime.js`、`Olivia_BattleSysOTB.js`＋`rpg_οbjects.js` `_actionInputIndex`）；本树重跑 `growth_forge_probe`／`nanoha2_probe`／`nanoha3_probe` 与 fixture 比对相同；专项选测与 `测试选测.py` 见「验证」。

## 报告

### growth2b（甲档）：利维坦／杰作无我锻造

对照 `installNativeLeviathanForge.js` 全文与 `installNativeHubrisRuntime.js` 40～82、166 行：

| 项 | 重制 | 原版 | 结论 |
| --- | --- | --- | --- |
| 锻造锤掷点 | `end_battle` 心钢 `clear_reward` 之后、狂妄之前 | Leviathan 的 endBattle 包装：原函数→`clearReward`→`awardCore`；狂妄（第 17 个）包在外层，后跑 | 通过 |
| 每场一次 | `start_battle` 清 `_core_rolled` | setup 包装清 `_codexLeviathanCoreRolled` | 通过 |
| 条件 | 胜利、Map176、来源 108／165、敌群 570～575、没掷过；`next_float >= 0.2` 不掉 | 同；`Math.random()>=0.20` | 通过（只认 165 照原版，已写进「需要用户决定」） |
| 来源 | `XState.unknown_origin`，没记按变量 107 | `$gameMap._codexLeviathanUnknownOrigin`，没记按 107（1→164，2／3→165） | 通过（期一已有，随存档） |
| 解锁 | `gain_gear` 得到一族时 `unlock`；`known()`／`can_forge` 没解锁时补查 | gainItem（amount>0）、`bindRecipe`（建配方时）、读档 `extractSaveContents` 都调 `unlockForge(false)` | 通过，见下 |
| 能否锻造 | 战斗外、已解锁、是自己的原件实例、碎片 ≥200、锤 ≥5 | `canForge` 同 | 通过 |
| 配方改写 | 原件那项按原件实例数；`craftable` 不看金币；能做 1／0；`craft` 转锻造 | `bindRecipe` 四处改写同 | 通过 |
| 锻造事务 | 原地改实例、扣材料、核数不对整件还原补回；穿着的角色刷新、夹生命 | `restoreItem`＋try／catch 同；`actor.refresh()` | 通过（两件杰作的属性只增不减，不用夹 MP） |

解锁补查（派单重点）：

- 原版三个补查点里，「建配方」只在 `DataManager.createRecipes`（hc.js 读 Recipes.txt 时）跑，`resetKnownRecipes` 只在新开局 `createGameObjects` 里跑；「读档」由心钢、狂妄各自的 `extractSaveContents` 包装 `unlockForge(false)`。重制把这几处换成「查配方时没解锁就补」，玩家看得到的只有制作列表与能否锻造，这两处都先走补查，结果一样。
- 有一处不同：原版 `unlockForge` 在**已解锁**时也会重学配方，所以「已解锁＋配方被 `crafting forget 457／458` 忘掉」的档读进来，原版会重新学会，重制 `unlocked()` 只在没解锁时补，不会重学。冻结数据里没有任何 `crafting forget` 指令（全库只有 `crafting learn`），这种档造不出来，不记问题。

另核：`growth_forge_probe` 在本树重跑 44 例，产物与 `tests/fixtures/growth_forge_oracle.json` 相同。

### nanoha2b（甲档）：奈叶二期

**① 比例收费与 `_costmp`**（`battle_logic._skill_cost`、`pay_skill_cost`、`XNanoha.note_cost`）

- 原版 `YEP_SkillCore.skillMpCost`：`cost = mpCost + mmp×mpCostPer` → eval 把 cost 改成 `⌊mp×比例⌋` 并写 `_costmp=⌊mp×比例/2000⌋` → `max(0, ⌊cost×mcr⌋)`。重制先按当前 MP 取 ⌊⌋ 再 ×mcr、取 ⌊⌋，熟练度等包装在外层照旧，一致。
- 原版每次调 skillMpCost（canUse、技能窗画费用）都会改写 `_costmp`（`Codex_SmartBattleAI` 的 `canUse`／`previewCost` 专门存回旧值），重制只在付费时写。`nanoha3_probe` 走真实 startAction 与 YEP actionList／actionTargetList 阶段，付费到伤害之间没有别的 skillMpCost 调用，`_costmp` 都是付前值，两边一致。只有「不付费就重放大招」才会读到不同的旧值，现有数据里没找到这种路子，不记问题。

**② 伤害后多段**（`_apply` 生命伤害分支、`XNanoha.post_damage`）

- 位置：原版 `Game_Action.executeDamage`（YEP_SkillCore）：原 executeDamage（含 executeHpDamage 及其包装，如种族蛮骨上限、云裳记段）→ `applyPostDamageEval(target, value)`。重制在 `execute_hp_damage`、`XRaceBattle.after_hp` 之后、BSC Respond／Establish 之前补段，`value` 是进 executeHpDamage 前的值，目标用嫁祸后的 `dt`，次序与取值都对。
- 补段：`gainHp(-value)`＋弹字 `_costmp-1` 次，每段过 ShieldSystem（重制 `absorb_shield`），伤害记录按 `Bailong_StarDamageRecord_ExactAction` 最终 gainHp 的 ⌊max(0, hpDamage)⌋ 记，一致。
- ACS：`hitCountFromCost`＝⌈_costmp⌉；目标是敌人、value 是正整数、段数 >512 才走快速：桌面留 `min(hits-1, 95)` 段逐段，尾段 `setHp` 一次（不过护盾）＋`recordBulk` 按 ⌊value⌋×段数。重制 `fast` 条件、95 段、尾段不过护盾、记录口径都一致。
- `nanoha3_probe` 本树重跑 29 例，产物与 fixture 相同。

**③ 状态效果预约**（`state_effects.gd` `reserve_common_event`、`battle_logic._take_state_reserves`）

- 转换器只认单句 `$gameTemp.reserveCommonEvent(N)`，全库命中 1774（battle）、1780（action_start／action_end）。三处 `run("battle"／"action_start")` 之后都紧跟 `_take_state_reserves()`，静态表不会漏到下一场；交给原有的单槽 `XBattleCommonEvent.reserve`（后一个盖前一个，同 `$gameTemp`），在 `_drive_events` 取出执行，同原有技能效果 44 的时机。
- 1774 的 battle 块只有这一句；重制若在开战效果时已挂上 1774，会先预约 2478，但 `setup` 末尾无条件预约 1320 盖掉，表现与原版（从不预约 2478）相同。`nanoha2_probe` 重跑产物与 fixture 相同。

**④ 小魔炮智能 AI**（`smart_ai.gd`）

- 对照 `Codex_SmartBattleAI.js` 57～95、480～500 行：`cannonOptions`（108、学会 5692、5692 能用，六档各自能用即可，不必学会）、候选次序（技能去掉 5692 → 普攻 → 去掉已会的六档 → 接六档；物品在后）、`safeDamage` 先按付费后 MP 估公式再 ×max(1, ⌊付前 MP×比例/2000⌋），逐项一致。5692 自身伤害类型 0 带 44，两边的合法性检查本来就排除。
- 重制估伤时临时改 `a.mp` 再还原；`XBattler.mp` 是普通变量，没有副作用。

### ui2（乙档）：窗口底色只铺内框

`rpg_core.js` `Window._refreshBack`：底图 `(width-2m)×(height-2m)`、`move(m, m)`，`Window` 初始化 `_margin = 4`；`Window_BulkPillNumber._refreshBack` 在这张底图上 `destination-over` 垫 #111827。重制 `backdrop_rect()`＝`grow(-4)`，`backdrop` 只有批量丹药数量窗设，范围对。通过。

### ui3（乙档）：饿狼读档同步、预排琦玉

- 读档：原版 `installNativeGarouRuntime.js:202` `extractSaveContents` 之后 `G.clearBattle(a)`＋`G.sync(a)`（380 行包的被动准入在 sync 里先跑）。重制 `XGarou.after_load` 在 `_become_current(s)` 之后调，`sync` 里查 `XState.current` 读的是新档；`clear_battle` 清的项与原版 `clearBattle` 对得上（进化、解析、本回合受伤、琦玉、熟练度来源）。`save.old`／`save.roundtrip` 改成按字段比，是因为 sync 会写 `garou.breakthroughs`（原版同样写 `_garouBreakthroughs`），合理。
- 预排琦玉（派单点名对照 OTB）：`plugins.js` 里 `Olivia_BattleSysOTB` 开着、`OTB Force Battle System` 为 true，`isOTB()` 恒真。`_actionInputIndex` 只在 `rpg_οbjects.js` 的 `clearActions`（置 0）、`Game_Actor.selectNextCommand`（+1）、`selectPreviousCommand`（−1）里改；全库调 `actor.selectNextCommand()` 的只有 `rpg_managеrs.js:2386` 原版 `BattleManager.selectNextCommand`，而 OTB 667 行把它整个换掉（有 _subject 就 startAction，没有就 otbSetSubject＋startOTBInput），其余 `selectNextCommand()` 调用（YEP_BattleEngineCore 4612、YEP_WeaponUnleash、zidongzhandou、璇）都是 Scene_Battle 的，转到被换掉的 BattleManager 版本。所以下标恒为 0，`slice(0, 0)` 恒空，`planned` 恒假。白龙的结论成立，不移植正确。

### tools48、census2（丙档，只看结论）

- tools48：`cloud_sets` 让没通过的云端运行带上失败集（`failed` 名单，空就整份 `sceneNames`），不再报通过；审查 29 P3-4 的情形（较旧通过被沿用）已堵住。产物树对不上、没有 `sceneNames` 的运行照旧跳过，与 docstring 一致。同步基线那条「已过时」的结论可接受。通过。
- census2：122 读敌人数据已有、PetGet 只在战斗里（捕获网 occasion 1）、ConductItemMakeUpSign 依赖整个签到系统，三条结论可接受；签到系统要不要做已写进「需要用户决定」。通过。

## 交接板

- 下一步：审查 30 六条销账（growth2b、nanoha2b、ui2、ui3、tools48、census2），无新问题要派。
- 需要用户决定：无新增（growth2b 锻造锤只认 165、nanoha2b 领域 1774 死内容、census2 签到系统三条已由各车道写过）。

## 验证

- 原版参照：本树重跑 `node growth_forge_probe.cjs`（44 例）、`nanoha2_probe.cjs`（1 例）、`nanoha3_probe.cjs`（29 例），均无错，`.sandbox` 产物的 `cases` 与 `tests/fixtures/*_oracle.json` 逐例相同。
- 专项选测（`并行测试.py --jobs 2`，123 秒）14 个全部通过：xiyou_growth_forge、xiyou_heartsteel、xiyou_crafting、xiyou_nanoha、xiyou_state_effects、xiyou_state_effects_tp、xiyou_smart_ai、xiyou_smart_ai_b、xiyou_bulk_pills、xiyou_garou_progress、xiyou_garou_battle、xiyou_script_census、xiyou_battle、xiyou_save_events。日志 `04_验证/本地结果/审查30/选测.log`。
- 工具回归 `测试选测.py` 91/91（含 tools48 新加的 `test_cloud_failure_beats_older_pass`）。
- 没跑全量（今天的全量已跑过）。

## 本分支提交

- （本提交）交付单
