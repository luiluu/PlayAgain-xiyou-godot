# 交付：cc/bajie-growth2b

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：可合并

（growth2 会话过交接线未开工，接续要点已并进本单，旧单 `cc_bajie-growth2.md` 删掉。成长装备期二按派单分期：本单＝期二a 两件锻造；魔冠与尾项在期二b，见文末「接续」。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备期二a：利维坦锻造与杰作无我锻造（dev.待定）

派单：总装 growth2 交代（成长装备期二），先交能独立验证的两件锻造；魔冠、动态说明、智能 AI 分到下一期。

### 一、来源核对（走得到）

- 锻造锤 2867 只从 Map176（深渊：未知存在）EV004 的敌群 570～575 来：切片里 Map164／165／176、敌群 570～575 都在；进 176 的门在 Map164（魔王之渊）与 Map165（魔神之渊）的 EV005。来源地图用期一已有的 `XState.unknown_origin`（进 152／176 时记上一张图）。
- 原版只认来源 108／165：108 号地图不存在，所以**只有从魔神之渊进去的打赢才掷**，魔王之渊（164）进去的永远不掉；没记来源按变量 107（1→164、2／3→165）。照原版，写进「需要用户决定」。
- 配方 457（心之钢＋200 人道意志碎片＋5 锻造锤→杰作利维坦）、458（狂妄→杰作无我）在 `recipes.json` 里，缺省未学会；碎片 2530 已有来源。

### 二、原版参照 `growth_forge_probe`（44 例，不进同步，拷成 `tests/fixtures/growth_forge_oracle.json`）

- 参照引擎不会自己建配方（hc.js 用 XMLHttpRequest 读 Recipes.txt），探针照它读一次再建，所以配方的改写（bindRecipe）是真跑的。
- 锻造锤 14 例（结果、地图、来源、变量 107、敌群边界、20% 边界、每场一次、抽数）；解锁流程（得到原件、第二件、狂妄、失去后、忘记配方、重置配方）、直接得到杰作、旧档读档补设 4 例；能否锻造 18 例（够／差 1 碎片／差 1 锤／未解锁／战斗中／杰作本身／不是自己的／穿着的／没有）×配方三项；锻造 4 例（背包、穿着 × 两件：实例前后、预览不动原件、详情行、帮助文字、材料、穿着角色的生命与技能、再锻造）；材料不够时制作不扣东西。

### 三、移植（`core/growth_forge.gd` XGrowthForge，新文件）

- 锻造锤：`award_core` 接在 `battle_logic.end_battle` 心钢 `clear_reward` 之后、狂妄之前（原版同一个 endBattle 包装：clearReward→awardCore）；每场一次的标记在 `start_battle` 清（setup 包装，紧接心钢）。用战斗规则流 `next_float`。
- 解锁：`xstate.gain_gear` 得到心钢／狂妄一族时设标记、学配方；标记存在 `XState.crafting`（`codexLeviathanUnlocked`／`codexAtaraxiaUnlocked`，随存档）。另在查配方是否学会、能否锻造时，没解锁就补查一次（旧档、或从仓库等不经 gain_gear 的路子拿到装备）。
- 锻造：同一实例原地改成杰作（底子、属性加两件模板之差、名字与底名、图标、说明首段、备注标签、元数据），层数／盛名／词条／强化保留；扣材料后核数，不对就整件还原并补回材料；穿着的角色刷新（生命 ×1.1 起、巨人吞噬换成 10228）。原版锻造后 describe 重写说明行，重制把原件模板的说明行换成杰作模板的同一行（层数相关的动态行在期二b）。
- 配方：`XCrafting` 对 457／458 改用锻造口径——原件那项按自己的原件实例数（含穿着的）、能做 1 件或 0 件、不看金币、制作＝锻造选好的原件（`material_count` 加了可选参数 `r`，唯一外部调用在制作界面，已改）。
- 界面（`ui/crafting.gd`）：锻造配方确定后先在列表窗位置选一件原件（行高 72、两行字、不能锻造的半透明＋蜂鸣），选好进数量确认，取消回列表；帮助窗、详情窗多出锻造文字；锻造不成蜂鸣回列表。

## 待交叉核查

- 新文件：`core/growth_forge.gd`、`tests/xiyou_growth_forge.gd`（＋tscn、fixture）、`mv_oracle/growth_forge_probe.cjs`。
- 原沙僧核心文件：`battle_logic.gd` 两行（`start_battle` 里 `XGrowthForge.start_battle()`，`end_battle` 末尾 `XGrowthForge.award_core`，次序见三）。
- `xstate.gd` `gain_gear` 末尾一行 `XGrowthForge.on_gain`。
- `core/crafting.gd`（known／material_count／craftable／amount_craftable／craft 五处转给锻造）、`ui/crafting.gd`（选原件 mode "pick"）。
- 请重点核：解锁补查（重制在查配方时补，原版在 gainItem／读档／建配方时）——「拥有原件却没解锁」原版只能人为造出，专项里 `can.*.locked` 改比补解锁后的结果。

## 交接板

- 下一步：成长装备期二a（两件锻造）已交；期二b＝魔冠 `installNativeDemonCrownRuntime`（227 行，装备 7940，Map162，掉率 3%，有独立成长账本）＋尾项：心钢／狂妄动态说明（`H/U.helpRows`、`describe`、`helpView`，help_card）、选原件时 Shift 看原件词条、智能 AI 选巨人吞噬（`Codex_SmartBattleAI.js` 引用 7900）、战力（`installCombatPowerRuntime.js`）、甚尔抑制行动不减蓄力、解锁与锻造锤的提示（toaster）。
- 用户试玩说明：第一次拿到心之钢或狂妄，打造类别里多出「杰作利维坦」／「杰作无我」；选它会先让你挑一件心之钢／狂妄（穿着的也行），消耗 200 人道意志碎片和 5 个锻造锤，把这件升级成杰作，层数、盛名、词条都保留。锻造锤在深渊未知存在（从魔神之渊进去的）打赢有机会掉。
- 需要用户决定：锻造锤来源——原版只认从魔神之渊（165）进未知存在，魔王之渊（164）进去的永远不掉（代码里另一个 108 号地图不存在，疑似原想写 164）。重制照原版；要放开 164 再说。

## 进度账

- 养成·成长装备：约 40% → 约 60%，依据：两件锻造（掉落、解锁、锻造、配方与界面）已移植并对上参照；魔冠与动态说明、智能 AI 在期二b。

## 可优化（流程／工具／效率）

- 已做：无（本车道没改工具）。
- 建议：参照引擎 `shared/host.cjs` 不建配方表（`$gameRecipes` 为 null，hc.js 走 XMLHttpRequest），以后碰制作的探针都要自己读 Recipes.txt；可以在 host 的 newGame 里照 hc.js 建一次（要先看现有探针会不会因此变），归哪吒。

## 验证

- 原版探针 `node growth_forge_probe.cjs`：44 例无错。
- 专项 `xiyou_growth_forge`：534／534（含锻造后存档往返、界面选原件→确认→弹窗→回列表）；`xiyou_heartsteel` 放开 recipes／unlocked 后 411／411。
- `python3 07_开发环境/语法检查.py`：496 个 .gd 无问题。
- 选测：`选测.py main --list` 列 295 个（改了 battle_logic／xstate＝近全量）；按派单不跑全量，`并行测试.py --jobs 2` 跑了 44 个，全部通过（552 秒，无偶发）：xiyou_growth_forge、xiyou_heartsteel、xiyou_crafting、xiyou_event_compare、xiyou_system_evidence、xiyou_gold_cap、xiyou_achievement、xiyou_actor_warehouse、xiyou_alien_affix、xiyou_alien_battle、xiyou_alien_workshop、xiyou_autosave、xiyou_battle、xiyou_battle_drop、xiyou_combat、xiyou_determinism、xiyou_drop_dh、xiyou_drop_record、xiyou_equipment、xiyou_equipment_admission、xiyou_floor_abyss037／174／211、xiyou_gear_ui、xiyou_hit_warehouse、xiyou_item_bag、xiyou_item_marks、xiyou_lobby_shops、xiyou_orbs、xiyou_save_events、xiyou_save_page、xiyou_shop_buy、xiyou_star_warehouse、xiyou_warehouse、xiyou_yunshang、xiyou_yunshang_shop、xiyou_yunshang_wraps、xiyou_battle_gaps、xiyou_module_hooks、xiyou_rules_d1b／d3g／d5b、xiyou_smart_ai_b、xiyou_power。选的是碰 gain_gear（掉落、商店、仓库、存档）、战斗收尾与制作的；其余约 250 个（楼层流程、其余 rules／smart_ai 段、界面）留给总装合并后选测／每日全量。
- 没改切片、转换器、共用探针，不用重跑同步；新探针不进同步。
- 战斗里锻造锤真掉一次（end_battle 走到 award_core）没有单独的整场测试，award_core 本身按参照 14 例比过；接线两行请核。

## 本分支提交

- cb29fe7d 锻造运行时、制作配方与界面接线、参照探针
- 82e1a8f4 专项 xiyou_growth_forge；心钢专项放开配方解锁两项
- （本提交）交付单

## 接续（期二b）

- 魔冠：`installNativeDemonCrownRuntime.js`（装备 7940、limit 1000、dropRate 0.03、Map162 已在切片里；有 uid／hash 的独立成长账本与 extractSave 包装，先读全文再定移植口径）。
- 动态说明：心钢 `H.helpRows`／`H.rewriteHelpRows`／`H.describe`／`H.groupHelpRows`（`installNativeHeartsteelRuntime.js` 45～80 行）、狂妄 `U.helpRows`／`U.describe`／`U.helpView`（`installNativeHubrisRuntime.js` 22～38、168～176 行）。原版 describe 改实例的 note（建实例、读档、战斗结束时），重制可在 help_card 显示时算；锻造后的说明行现在只换成杰作模板的静态行。
- 选原件时 Shift 看原件词条（`patchCraftScene` 的 `_codexShowSourceHelp`，Sprite_ItemHelp 宽 RJO.HE.ItemDescWidth）。
- 智能 AI：`Codex_SmartBattleAI.js` 里 7900 的分支。
