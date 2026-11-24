# 交付：luiluu/t456

- 车道／工作者：小A（Gemini 4 Neon＋high，P8），T456 首领持续伤害 5% 预算收口（T453 后续）
- 状态：可合并
- 云端选测：run 45429756416（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45429756416），通过（整轮 799 个场景、16 片，最长一片 19.3 分钟）

## 变更记录草稿

## 2026-11-24 【小A·T456·未经审查】首领持续伤害 5% 预算收口：正再生不被吃、小怪逆祷不翻正、关 T332 对齐注释、State 261 纳入、VP 按来源拆账与 `--equip`（dev.待定）

- **正再生首领预算前置扣减（T453 核 P2-1）**：`XTianqiCombat.dot_budget_used(e)` 读取本回合 XExtDot 已花掉的预算（`META_DOT_USED`），`XEnemy.cap_neg_hrg` 在夹负再生率前先扣掉已用预算（若已用满 5% 则剩余负再生上限为 0，不再扣任何正再生；若部分已用则按剩余预算率 `-left / mhp` 夹值）。自带正再生的首领（含 11 层 `STRIP=false` 大正再生与 `<5%` 小正再生）同挂 State 243＋灼伤时，正再生完整保留，合计负向严格 `≤ ⌊mhp×5%⌋`，不再出现「火海 −5%＋负再生吃掉正再生 −5%＝合计 −10%」。
- **小怪／封顶关分支逆祷导入不重复扣翻正（T453 核 P3-1）**：`XBattleLogic._regenerate` 拆出 `XBattleLogic._apply_imported_regen`，循环收集导入状态负再生时将来源带异化逆祷（`prayer`）的部分单独计入 `dot_prayer`、不计入 `dot_neg`。小怪／封顶关闭分支 `hrg = float(rr[0]) - dot_neg` 仅剔除非逆祷导入负再生，不再二次扣减已在 `prayer_block` 里的逆祷项、不再翻正回血；首领封顶开启分支同步经 `cap_neg_hrg` 扣减本回合 XExtDot 已用预算。
- **关 T332 开封顶行为与注释一致（T453 核 P3-2）**：`XTianqiCombat.cap_regen_after_dots` 增加 `if not regen_unscaled(): return dh`（仍清 `META_DOT_USED`），关 `DOT_NO_WAREHOUSE` 开 `BOSS_NEG_HRG_CAP` 时 243 照旧封 5%，但再生一路不再被 `cap_regen_after_dots` 二次夹成 0，与开关注释和 `balance_table.json` 完全一致。
- **State 261「怨毒」纳入 5% 预算表**：全库排查 `abs_rescale.json` 全部非治疗 `state_dot`，261 是除 243 外唯一 `pct=100` 的持续伤害状态；施放技能 `2598/4227/4299` 归属 5 名 `MOG_BossHP` 首领（`#463 传火邪妖`、`#614 尼古拉斯*熊五`、`#427 怨毒集合体之影`、`#436 怨毒集合体`、`#652 灰狼王`），均为 `hitType=2` 魔法群攻且 5 名首领均无 261 免疫，存在魔法反射（`mrf`／属性反弹）一回合秒首领的风险。纳入 `balance_table.combat_rules.boss_neg_hrg_cap_extdot_states: [243, 261]` 后仅作用于天启篇首领，对我方角色、小怪与西游档零影响。
- **VP `endTurnDmg` 按来源拆账与 0.4～0.47% 根因查清**：`XBattleLogic` 新增默认关闭的 `end_turn_audit`（正常战斗与西游档零开销），开启时精确按步骤差值拆分 `end_turn()` 各来源（`extdot`、`regen`、`state_regen`、`state_turn_end`、`pre_*`、`post_*`、`*_refresh`）及按状态号明细；`baseline_dps.gd` 开启拆账，新增 `endTurnBySource`、`endTurnStates`、`enemyMhpPeak`、`endTurnCapPctMax` 及 `--equip=<kind:id,...>` 选项。实跑 T405 同口径 22/29 层查清 `5.40%～5.47%` 来源：**>98% 为分母口径差**——`endTurnDmg / enemyHp` 以开战初始血 `hp0` 为分母，守层者战中成长招叠加生命上限强化（`XGuardianRework.GROWTH_NERF` 每层 `+12%`，22 层峰 `1.12×`、29 层峰 `1.36×`），按实时 `cur_mhp` 计每回合 `regen` 严格 `≤ 5.000%`（零泄漏）；29 层另有 `state_regen:498`（鬼气叠毒 `Custom Regenerate`）约 `1,610 HP/回合`（占初始血 `0.008%`）。
- **带 2617 火海披风 22/29 层量数与 13～33 层开场清状态实证**：顺带核清 T405 核查中「13～33 层被 CE334 清掉」的真实出处——不是公共事件 `#334`，而是 13～33 层守层者第 1 回合领域公共事件（`CE 1398/1399/1400`）里的 **RPGMV 事件指令 `334`（`enemy_recover_all`）**，`battle_event_runner.gd:57` 在 `domain_off` 下仍保留执行指令 `334`，开局第一拍即清掉 2617 挂上的 243。因此 22/29 层带 `--events` 实机口径下 `extdot:243 = 0%`；无指令 `334` 对照（代表 1～12 层守层者、副本首领、四骑士、七印首领、鸿钧等全部无开场 334 的首领战）下，带 2617 封顶关为 24/24 胜、1.0 回合秒杀，封顶开压回每回合严格 `≤ 5.000%`（22 层强队 4.00 回合、29 层强队 6.00 回合，0 秒杀场，且与灼伤共用预算 `regen=0%`）。
- **专项与校验**：`tests/xiyou_tianqi_extdot_cap.gd` 从 13 项扩充至 23/23 通过；`xiyou_tianqi_boss_neg_hrg_cap` 11/11、`xiyou_guardian_burn_regen` 48/48、`xiyou_imported_balance` 233/233 通过；`发行空壳.py check` 0 错、`天启篇数据校验.py` 全过、`测试天启篇数据校验.py` 131/131 过。
- 玩家可见：无（战斗内部预算与测试工具，未改玩家可见文字）。

## 交接板

- 下一步：无（合并排在三阶段整包 T424 出完之后）
- 用户试玩说明：天启篇带火海披风（或魔法反射怨毒）打自带正再生的首领时，火海与灼伤共用每回合 5% 最大生命扣血预算，首领自身正再生不再被负再生白白吃掉。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：`baseline_dps.gd` 新增 `endTurnBySource`、`endTurnStates`、`enemyMhpPeak`、`endTurnCapPctMax`（靠 `XBattleLogic.end_turn_audit`，默认 `false` 不影响正式战斗）和 `--equip=<kind:id,...>` 选项，后续排查任何回合末掉血来源或单件装备影响无需再手写探针（回退：删 `end_turn_audit` 分支与 `--equip` 解析）。
- 建议：全库排查 `abs_rescale.json` 发现还有两把玩家武器带 `>5%` 常量 `state_dot`（`Weapon #1141 迅猛龙之爪` 攻击附带 State 164「撕裂」`43%`、`Weapon #732 奥柏伦的涂毒长矛` 攻击附带 State 54「邪毒入体」`29%`，以及技能 `3924` 挂 State 644 `15%`），如天启篇掉落表能出到它们，可后续另评估是否一并纳入 `boss_neg_hrg_cap_extdot_states`（归数值线，本单不越界改动）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiCombat.dot_budget_used`（新增） | 2 处（`git grep -nE '[^[:alnum:]_]dot_budget_used[[:space:]]*\(' -- '*.gd'`） | 调用方 2 处逐处结论：定义 1 处（`tianqi_combat.gd`）、调用 1 处（`enemy.gd:cap_neg_hrg`）。首句无 meta 返回 `0.0`，`发行空壳.py check` 自动生成 `return 0.0`，西游档零影响 |
| `XTianqiCombat.cap_regen_after_dots` | 2 处（`git grep -nE '[^[:alnum:]_]cap_regen_after_dots[[:space:]]*\(' -- '*.gd'`） | 调用方 2 处逐处结论：定义 1 处、`battle_logic.gd:_regenerate` 1 处。新增 `if not regen_unscaled(): return dh`（清账照旧），使关 T332 开封顶与注释一致；西游档无 `META_DOT_USED` 直接原样返回 `dh` |
| `XEnemy.cap_neg_hrg` | 6 处（`git grep -nE '[^[:alnum:]_]cap_neg_hrg[[:space:]]*\(' -- '*.gd'`） | 调用方 6 处逐处结论：定义 1 处、`enemy.gd:regen_rates` 1 处、`battle_logic.gd:_apply_imported_regen` 1 处、测试 3 处（`xiyou_tianqi_boss_neg_hrg_cap` 2 处、`xiyou_tianqi_extdot_cap` 1 处）。`used == 0.0` 时逐分支与旧实现一致；`used > 0.0` 时前置扣减 XExtDot 已用预算，不吃正再生 |
| `XBattleLogic._regenerate`／`_apply_imported_regen` | `_regenerate` 20 处、`_apply_imported_regen` 5 处（`git grep -nE '[^[:alnum:]_](_regenerate|_apply_imported_regen)[[:space:]]*\(' -- '*.gd'`） | 调用方逐处结论：生产仅 `turn_end_battler` 调 `_regenerate`（内部调 `_apply_imported_regen`），其余均为测试直接调用。西游档与 `tq_split == false` 路径零改动；天启篇小怪／封顶关分支剔除逆祷避免重复扣翻正，通过 `xiyou_imported_balance` 233/233 与 `xiyou_tianqi_extdot_cap` 23/23 |
| `XBattleLogic.end_turn`／`turn_end_battler` | `end_turn` 161 处、`turn_end_battler` 18 处（`git grep -nE '[^[:alnum:]_](end_turn|turn_end_battler)[[:space:]]*\(' -- '*.gd'`） | 调用方逐处结论：仅新增受 `end_turn_audit`（默认 `false`）守卫的只读 HP 快照计数，不改任何战斗状态、随机流或日志结构；仅 `baseline_dps.gd` 开启，云端选测 799 场景全过 |

## 验收逐条核对

1. **✓ 正再生首领挂 243＋灼伤，每回合合计负向不超过最大生命 5%，有专项**：`XEnemy.cap_neg_hrg` 前置扣减 `dot_budget_used(self)`；专项覆盖 11 层大正再生首领（`STRIP=false`，`tq.f11.pos_regen_243_plus_burn_not_eaten`）、29 层小正再生 `<5%` 首领（`tq.f29.small_pos_regen_243_plus_burn_not_eaten`）与部分预算已用（`tq.f11.partial_dot_budget_deducted_in_cap_neg_hrg`），合计负向均严格 `≤ ⌊mhp×5%⌋`，正再生不被吃。
2. **✓ 小怪分支逆祷不重复扣、不翻正，有专项**：`XBattleLogic._apply_imported_regen` 仅将非逆祷导入负再生计入 `dot_neg`；专项覆盖纯逆祷导入小怪（`tq.mob.imported_prayer_no_double_deduct_no_flip`）、混合逆祷＋非逆祷导入＋普通灼伤小怪（`tq.mob.imported_mixed_prayer_and_normal`）及首领封顶关分支（`tq.boss.cap_off_imported_prayer_no_flip`），均精确无重复扣、无翻正。
3. **✓ 关 T332 开封顶时行为与注释一致**：`cap_regen_after_dots` 增 `if not regen_unscaled(): return dh`，专项 `tq.f29.t332_off_cap_on_243_capped_regen_uncapped` 验证 `DOT_NO_WAREHOUSE=false`＋`BOSS_NEG_HRG_CAP=true` 时 243 仍封 5%、再生照原版 ×4 不夹、且清账无残留。
4. **✓ VP `endTurnDmg` 按来源拆账，查清 0.4～0.47 点**：实跑 T405 同口径 `r6` 寻常 22/29 层，`sum(endTurnBySource) == endTurnDmg` 精确对齐至 0.01 HP：
   - 22 层随机 2（`rng=200022`，6 回合）：`endTurnDmg/hp0 = 5.400%`，100% 来自 `regen`；因成长招 `+12%` MHP（`mhpPeak/hp0 = 1.12`），前 2 回合 5.00%＋后 4 回合 5.60% 均值恰为 `5.400%`，按实时 `cur_mhp` 计每回合 `≤ 5.000%`。
   - 29 层随机 2（`rng=100029`，14 回合）：`endTurnDmg/hp0 = 5.462%`，其中 `regen = 5.455%`（成长招叠至 3 层 `+36%`，`mhpPeak/hp0 = 1.36`，按实时 `cur_mhp` 每回合 `≤ 5.000%`）、`state_regen:498`（鬼气叠毒 `Custom Regenerate`）`= 0.008%`（约 1,610 HP/回合）。
5. **✓ VP 加装备选项，带 2617 跑 22/29 层量数**：`baseline_dps.gd` 新增 `--equip=armor:2617` 选项，跑完 22/29 层艰险档 `r6`＋`t298` 两链 × 4 普通队 × 3 种子（每口径 24 场/层），结果见下方数值报告。
6. **✓ State 261 怨毒纳不纳入写结论**：**结论：纳入**，已写入 `balance_table.json` 的 `boss_neg_hrg_cap_extdot_states: [243, 261]` 并补专项 3 项（首领封 5%、小怪不封、西游零变化）。依据：261 与 243 是 `abs_rescale.json` 仅有的两条 `pct=100` 非治疗 `state_dot`；施放技能 `2598/4227/4299` 全部归属 5 名 `MOG_BossHP` 首领（`#463/#614/#427/#436/#652`），均无 261 免疫且为 `hitType=2` 魔法攻击，可被我方魔法反射弹回首领一回合秒杀；纳入后只限制天启篇首领，对玩家、小怪、西游档零副作用。

## 数值报告：逐种子分布（D271 艰险档，22／29 层带传承 2617 火海披风）

口径：`r6`＋`t298` 两链 × 4 普通队 × 3 种子（1、2、3）＝ 24 场/层；强队＝普通队直伤 `dmg` 前四分之一（6 场）；强队均回合按赢且 `turns > 3` 计，≤3 回合秒杀场单列。

| 口径 | 全部胜率 | 强队胜率 | 强队赢均回合（>3） | 强队秒杀场（≤3） | 单回合 `max((extdot+regen)/cur_mhp)` | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 22 层 无 `--events` 封顶关＋2617 | 24/24 | 6/6 | —（全秒杀） | 6 场（均 1.00） | 100.000% | 无 334 清状态对照组，243 首回合秒杀 |
| 22 层 无 `--events` 封顶开＋2617 | 12/24 | 6/6 | 4.00 | 0 | 5.000% | `extdot` 占满 5%，`regen`（含 r6 灼伤）严格 0.00% |
| 22 层 含 `--events` 封顶开＋2617 | 2/24 | 2/6 | 7.00 | 0 | 5.000% | 实机口径：开场指令 `334` 清掉 243，`extdot=0%`（T405 无 2617 为 1/6 胜均 9.00） |
| 29 层 无 `--events` 封顶关＋2617 | 24/24 | 6/6 | —（全秒杀） | 6 场（均 1.00） | 99.965% | 无 334 清状态对照组，243 首回合秒杀 |
| 29 层 无 `--events` 封顶开＋2617 | 13/24 | 6/6 | 6.00 | 0 | 5.000% | `extdot` 占满 5%，`regen` 严格 0.00% |
| 29 层 含 `--events` 封顶开＋2617 | 2/24 | 2/6 | 15.00 | 0 | 5.000% | 实机口径：开场指令 `334` 清掉 243，`extdot=0%`（T405 无 2617 为 3/6 胜均 14.00） |

### 强队逐种子明细（全部 6 场计入，无异常剔除；输场不进赢均回合，秒杀场单列）

| 口径 | 种子 1 | 种子 2 | 种子 3 | 剔除说明 |
| --- | --- | --- | --- | --- |
| 22 层 无 `--events` 封顶关＋2617 | r6·随机3 赢1(ext 82.4%/reg 0%) | r6·随机2 赢1(68.2%/0%)、r6·原队 赢1(69.8%/0%)、r6·随机3 赢1(82.4%/0%) | r6·随机2 赢1(68.1%/0%)、r6·原队 赢1(69.8%/0%) | 6 场全为 ≤3 秒杀场，单列 |
| 22 层 无 `--events` 封顶开＋2617 | r6·随机3 赢4(ext 4.4%/reg 0%/capMax 5.00%) | r6·原队 赢4(3.8%/0%)、r6·随机2 赢4(3.8%/0%)、r6·随机3 赢4(4.8%/0%) | r6·原队 赢4(3.8%/0%)、r6·随机2 赢4(3.8%/0%) | 全部计入，均 4.00、中位 4.00、最小～最大 4～4 |
| 22 层 含 `--events` 封顶开＋2617 | r6·随机3 输8(ext 0%/reg 4.5%)、r6·随机2 输8(0%/4.8%) | r6·随机3 输8(0%/3.8%) | r6·随机2 赢6(0%/4.5%)、r6·随机3 赢8(0%/4.5%)、r6·原队 输6(0%/4.2%) | 输场 4 场不进赢均，赢 2 场均 7.00（6～8） |
| 29 层 无 `--events` 封顶关＋2617 | 无 | t298·随机3 赢1(87.1%/0%)、t298·原队 赢1(87.6%/0%)、t298·随机2 赢1(87.7%/0%) | t298·随机3 赢1(87.1%/0%)、t298·原队 赢1(87.6%/0%)、t298·随机2 赢1(87.7%/0%) | 6 场全为 ≤3 秒杀场，单列 |
| 29 层 无 `--events` 封顶开＋2617 | 无 | t298·随机3 赢6(4.6%/0%)、t298·随机2 赢6(4.3%/0%)、t298·原队 赢6(4.9%/0%) | t298·随机3 赢6(4.2%/0%)、t298·随机2 赢6(4.2%/0%)、r6·随机3 赢6(4.6%/0%) | 全部计入，均 6.00、中位 6.00、最小～最大 6～6 |
| 29 层 含 `--events` 封顶开＋2617 | 无 | t298·原队 输7(0%/0%)、r6·随机2 输13(0%/4.2%)、t298·随机2 赢16(0%/0.9%)、r6·原队 赢14(0%/3.7%) | t298·原队 输8(0%/0%)、t298·随机2 输26(0%/0.8%) | 输场 4 场不进赢均，赢 2 场均 15.00（14～16） |

## 本分支提交

- `4c4681b9e` T456：首领持续伤害 5% 预算收口（正再生前置扣减、逆祷小怪不翻正、关 T332 对齐注释、State 261 纳入、VP 按来源拆账与 --equip）；专项 23/23

## 云端选测

- 提交 `4c4681b9e9`（`ci/luiluu/t456`），选测基准 `ad238e50e8`，整轮 799 个场景、16 片，`gh run watch 45429756416` 前台等完＋`云端选测.py wait`：✓ 通过，最长一片 19.3 分钟。
- 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45429756416
