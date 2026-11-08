# 交付：cc/rules-gaps7

- 车道／工作者：C 规则·CounterGuard＋敌群页覆盖剩 21 条＋技能页战力分歧＋审查 69 P3-1／P3-2／cc（GB2 起，GB3 接续）
- 状态：**可合并**（同步 `--accept-additions` 没跑，见「交给总装」）

## 交给总装

- **同步 `--accept-additions` 没跑**：troop_event_probe 加了嘤嘤怪 7 例，正式同步要整份 troop 探针，派单要求先约总装、跟 GC 分片错开，所以没起。本地验证用的是只跑新例的临时探针（mkdev.py）生成的 7 例，并进 clone 的 `generated/oracle/troop_events.json`（1044→1051 例）。合并后请在 GC 分片合入后补跑（有 XIYOU_PROBE_FROM 就只跑尾部新例）；云端选测用的是 main 的产物快照，没带这 7 例，嘤嘤怪换队伍只在本机验过。
- 木桩 826 第二行动位（KNOWN_DIFF 826 t1_states）本期没动，线索见下「接续要点」。

## 变更记录草稿

## 2026-11-08 【cc·GB·未经审查】反击者已不在敌群时跳过反击（v0.53.01 CounterGuard）；敌群探针加嘤嘤怪 1 换队伍；战力预演不算状态 Confirm／React（dev.待定）

- CounterGuard：原版 `installCounterGuardRuntime` 包装 `BattleManager.invokeCounterAttack`：反击者是敌人、却已不在 `$gameTroop.members()` 里就跳过这次反击（挨的那一下照样生效），原意是防 Game_Action 找不到队伍索引报错。新探针 `mv_oracle/counter_guard_probe.cjs`（4 例：在敌群／另造的同号敌人／开战后摘掉的敌人／角色反击）确认了。重制 `battle_logic._invoke` 两处反击前加 `_counter_guarded`，开关 `XBattleLogic.COUNTER_GUARD`（false＝v0.53.01 以前）。重制的 enemies 开战后不增不减，正常战斗走不到，跟原版一样留着防外部造的敌人。
- 嘤嘤怪 1：页条件 111 角色第 3 类是「会技能」（23／509／201／575），不是状态。`troop_event_probe.cjs` 加 `PARTY_CASE`／`runParty`（换队伍 1／4／20／29、开战后学会或忘掉技能，记 party／actorSkills），用例尾巴加 7 例；原版跑下来敌群 1 页内非空指令全部执行到（剩 21 条里的 20 条）。`xiyou_troop_events.gd` 的 `setup` 加 party 参数，新增 `_party_case`（比事件加的状态 11／34／45／51）。敌群页 214「暂时消除事件」重制原先记成没翻译跳过，改为战斗内无操作（原版 command214 只在地图上、事件号 >0 时才消除，敌群页事件号是 0）。
- 技能页战力「原版 755、重制 1358」（ui-gaps5 交出）：原版 `installCombatPowerRuntime` 的 `confirm()` 在 CodexDamage v3（新源）直接返回原值；预演里 `nativePreState` 也因 `prepare→refreshPassives` 清掉 `need_refreshstatelist` 而不跑，所以状态 Confirm／React 都不进战力。重制 `XPower._expected` 原先经 `XDamage.finish` 把它们算进去，学 5980「难度适应」（开战挂 1691 伤害 ×5）、5548「普通难度」（1631 ×1.5）后战力虚涨。改成只留固定减伤结算，开关 `XPower.POWER_SKIP_STATE_EFFECTS`（false＝旧算法）。原版临时探针（v0.62.12，狗逍遥 Lv10 依次学 5980／5548／6168／2571／2786）：808→808→808→808→808→839，钩 `onPreDamageStateEffects` 计数为 0；人为置 `need_refreshstatelist` 也是 0。重制改后同数。
- 353 游戏结束（审查 69 P3-1／P3-2）：重制走普通全灭收场，会跑 `end_battle(2)` 的战败包装（原版切 Scene_Gameover 后不跑），有意保留、写进 `battle_event_runner` 注释（清理更干净，玩家可见只多一行战败字样）；`xiyou_troop_events` 加 `t1_game_over`：参照 `sceneChange == "Scene_Gameover"` 的例子断言 `logic.game_over`、`is_lost()`，且 353 之后的 222 淡入没执行，其余例子 game_over 不置位。
- 玩家可见：学了难度类被动的角色，技能页／状态页战力不再虚高（跟原版一致）。

## 优化登记草稿

无

说明：CounterGuard、战力不算状态 Confirm 都是照原版移植（修重制与原版的分歧），不是改原版，没占 O 号；两个开关已留（`COUNTER_GUARD`、`POWER_SKIP_STATE_EFFECTS`，测试里都有回退支字面量赋值）。派单写的「O-待定·反击者离场」请总装定要不要登记。（总装 11-08：战力部分按 Kyo 选 C 不合，power.gd／xiyou_power.gd 合并时保持 main。）

## 验证

- 原版：counter_guard_probe 4 例 errors 0；嘤嘤怪 7 例（只跑新例的临时探针）errors 0；战力临时探针见上。
- 语法检查.py：655 个 .gd，0 问题。
- 本机专项（XIYOU_TROOP_ONLY=1）：xiyou_counter_guard、xiyou_power、xiyou_troop_events、_b、_c、_d、_half 全过（参照含嘤嘤怪 7 例）。
  - 首跑查出两处并已修：① counter_guard 测试只改了行动用的技能副本，反击走的是数据库技能 1（探针是直接改 $dataSkills[1]），反击伤害对不上（16 vs 34、161 vs 134）；改成照探针改数据库、本例结束还原。② 嘤嘤怪第 3 页 214 被记成跳过，见上。
- 工具回归.py：全部通过（63 秒）。
- 云端选测（170d6365，基准 main d7f2953a，`--no-upload`）：`选测.py main --list` 217 个场景（含 xiyou_determinism、xiyou_life_steal、xiyou_raven_reflect 等战斗核心），216 过、xiyou_qiyu 挂 2 项（a162／a164 技能 9934 反击）：测试另造的敌人不在敌群，被 CounterGuard 跳过反击；参照里目标是敌群成员，测试改成把它放进 `logic.enemies[0]`，本机重跑 231／231 过。只改了测试，没再上云。
- 同步：没跑（见「交给总装」）。

## 待交叉核查

- 改了 `battle_logic.gd`（CounterGuard，上期）、测试 `xiyou_counter_guard`／`xiyou_qiyu`／`xiyou_power`／`xiyou_troop_events`、`core/power.gd`（`_expected` 的结算）、`battle/battle_event_runner.gd`（214、353 注释）。
- `power_enemy.gd` 的敌人战力预演同样走 `XDamage.finish`（含状态 Confirm），原版敌人那条路没查，本期没改。

## 接续要点

- 木桩 826 第二行动位（KNOWN_DIFF 826 t1_states）：参照里不变身例 e0 是敌人 826「黑莲」（AGI 999，有无条件行动 3796～3800），第 1 回合只有强制 6068／6055／6064、没有普通出手；HP≤20% 例开战变身 937「木桩」（AGI 0，只有 8111，条件「队伍等级≥1」），第 1 回合强制之后紧接 8111、排在全部角色之前。差别像是「强制之后，原本的行动位还在不在」，和速度、行动表有关。下一期先在原版里记 makeActions／getNextSubject 的调用次序再改。
- 敌人战力 `power_enemy.gd` 是否也要跳过状态 Confirm：先看原版 `enemyPower` 的预演路径。

## 交接板

- 下一步：总装约时补跑同步 `--accept-additions`（嘤嘤怪 7 例）；826 第二行动位按接续要点查。
- 用户试玩说明：学了「难度适应」「普通难度」等被动的角色，技能页战力应跟原版一致（不再翻倍）。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 已做：无
- 建议：① 探针「只跑尾部新例」开关（GC 在做）合入前，车道生成新例都靠 mkdev.py 临时脚本，而且 `.sandbox/dev_troop_events.json` 会被下一次临时探针覆盖（这次上期的 7 例就被 826 调查盖掉了，只好重跑）；建议临时探针输出名带标签。② 用 clone 当工作区时，`新建工作树.sh --补齐` 要用主工作区那份脚本跑（用 clone 自己的会把 clone 认成主工作区、报「不需要补齐」），可在脚本报错里提示一句。

## 本分支提交

- 193f9d7b WIP：CounterGuard 探针与守卫、嘤嘤怪换队伍
- 5ddbedc0 WIP：交付单（进行中）
- 3866cd16 合并 main
- 90b3360d 战力预演不算状态 Confirm／React；353 注释、game_over 断言
- 170d6365 214 无操作、counter_guard 测试修正
- 交付单可合并＋xiyou_qiyu 目标放进敌群（本提交）
