# 交付：claude/bajie-alien-fix

- 车道／工作者：C 规则／八戒_90（Claude，Opus／medium）
- 状态：进行中

## 变更记录草稿

## 2026-10-30 【Claude·八戒_90·未经审查】沙僧交回的异化／战斗 P2 六项（dev.待定）

每项先补原版参照（或反例），再改，反向验证一次。

1. **嫁祸保护者行动外扣血同步**（沙僧第三十一期）：原版 gainHp 包装末尾 `A.syncRelations`（Adv:101），嫁祸者的生命按保护者比例、保护者倒下嫁祸者跟着倒下。重制行动外直接写生命的两处没同步：`XAlienBattle._lose_hp`（腐蚀、镜骸反噬）与事件 311（`mv_event_core._change_resource`）。新 `XAlienBattle.after_outside_hp`：保护者行动外改完生命后 `sync_relations`。另修 `sync_relations` 的倒下判断：原版 `!a.isDead()` 只看阵亡状态，重制 `is_dead` 把生命 0 也算倒下，刚把嫁祸者生命写成 0 就判成「已倒下」、不加阵亡状态——改看 `state_ids.has(1)`。
   - 参照：`alien_affix_probe` 加 `mirror`（敌人 0 直接写成镜骸变体，不经遭遇抽签）与四例 `scapegoat.mirror_protector`／`corrosion_protector`／`event_protector`／`event_protector_death`，原版读数与沙僧日志逐项相同。
   - 反向验证：`after_outside_hp` 改成空函数，四例 4 项失败（嫁祸者生命停在 8340）。
2. **减益效果掷骰（疫囊传播 P2，沙僧第二十六期）**：原版 `Game_Action.itemEffectAddDebuff` 按「减益有效度（特性 12）× 幸运差」掷一次，中了才加；重制**所有**效果 32 都直接加（不只疫囊）。新 `XBattler.debuff_rate`、`XBattleLogic.add_debuff_effect`：一般技能的效果 32 与疫囊传播（`spread_pest`）都走它；rule 流原因 `add_debuff`。
   - 参照：`alien_affix_probe` 加 `enemyTraits`（给这一局的敌人包一层 traitObjects；Godot 侧临时接到敌人数据的特性表、本例结束摘掉）与 `pest.resist`：敌人物攻减益有效度 0，疫囊传播物攻减益不过、物防照常过；队友直接对敌人放物攻减益也不中。
   - 反向验证：疫囊传播换回 `sequence_buff` 3 项失败；效果 32 换回 `sequence_buff` 2 项失败。
   - 注意：每个效果 32 多掷一次 rule 流，凡是对照随机序列的测试都可能受影响，见「验证」。
3. **W1 武器解放**（沙僧第七期）：原版 `switchUnleashSkill` 的 `canUse` 含 `meetsUsableItemConditions` 的 `canMove`，不能行动（强制行动）时解放候选全跳过、不掷，原技能照常执行。重制 `weapon_unleash` 加 `can_move` 判断。
   - 参照：`weapon_unleash_probe` 加 `state`（开战后挂状态、刷新参数缓存）与 `w207.stunned`（眩晕 29：canMove 假、不掷、执行技能 1）。原版不刷新时 canMove 读不到眩晕，探针照沙僧「刷新后」的摆法。Godot 侧该例照强制行动 `execute(..., true)` 执行。
   - 反向验证：去掉 `can_move` 判断，2 项失败（换成 127、掷 1 次）。
4. **行动无效时行动结束状态**（沙僧第十期，`battle_logic.act`）：原版敌人没有行动、或 isValid 假时，`processTurn` 不 startAction／endAction，`onAllActionsEnd` 在 `_processTurn` 内不 `updateStateActionEnd`（YEP_BattleEngineCore:4166），行动结束的状态不减回合。重制 `act` 在这两种情况不再 `_tick_states(u, 1)`；不能行动（skip）分支不改。
   - 参照：`attack_query_probe` 加 `skip.enemy73-state`、`skip.enemy1-mp-short-state`（黑暗 5 剩 1 回合，真实 processTurn 连调两次：状态仍在、剩 1、endAction 0 次，同沙僧读数）。
   - 反向验证：改前 4 项失败（状态被去掉）。
5. **连命负再生击穿护盾**（沙僧第三十六期 WIP 现场 ab8c55bb／e553852c）：**不是缺口**。把沙僧隔离探针的两例（`lifelink.regen_shield` 护盾 1000 够吸收、`lifelink.regen_shield_break` 护盾 100 被击穿）连同 set 的 `aShield` 搬进 `alien_affix_probe`，重制两例逐项一致（击穿后 a 8064、b 2693、护盾 0），不改实现，两例留作回归。
6. **探针 terminate**：`state_effects_probe` 的 `action.counter` 克隆技能（JsonEx 深拷贝）补回原技能上的函数（YEP 挂的 `masteryFormula` 等）。改前 stderr 报「SceneManager.terminate 在用例 action.counter 被调用」，改后不再报，产物 `state_effects.json` 与改前逐字节相同。

## 交接板

- 下一步：期二夺舍（方案在 claude_bajie-alien-equip 交付单，审查线程未审就按方案做、交付单写「方案未审」）。
- 用户试玩说明：敌人减益有效度低、或幸运比施放者高时，减益会被抵抗（原来必中）；嫁祸的保护者被腐蚀、镜骸反噬、事件扣血时，嫁祸者生命跟着变、保护者倒下会一起倒下；眩晕中被强制行动不再触发武器解放；没有行动的敌人身上「行动结束解除」的状态不再白白减回合。
- 需要用户决定：无。

## 进度账

- 无变化（核查交回问题的修复）。

## 可优化（流程／工具／效率）

- 已做：`state_effects_probe` 克隆技能补函数（第 6 项）。
- 建议：探针里「现场克隆技能」的写法（`JsonEx.makeDeepCopy($dataSkills[n])`）别的探针也可能有，丢 YEP 函数时不一定 terminate、可能静默算错；可在 `shared/host.cjs` 提供一个 `cloneSkill` 共用（改 host 会让全部探针缓存失效，宜攒到下次本来要整轮重跑时做；归 C 车道）。

## 待交叉核查

- 原沙僧核心文件：`battle_logic.gd`（`act` 的 started 判断、`add_debuff_effect`、`weapon_unleash` 的 can_move）、`battler.gd`（`debuff_rate`、`TRAIT_DEBUFF_RATE`）。
- `alien_battle.gd`：`after_outside_hp`、`sync_relations` 倒下判断、`spread_pest` 减益改走 `add_debuff_effect`。
- 独占表外：`mv_event_core.gd`（311 后一行 `after_outside_hp`）。
- 探针：`alien_affix_probe.cjs`（mirror、enemyTraits、set 的 Shield、新 7 例）、`weapon_unleash_probe.cjs`（state、1 例）、`attack_query_probe.cjs`（2 例）、`state_effects_probe.cjs`（克隆补函数）。

## 验证

（待写）

## 本分支提交

- 见 git log（claude/bajie-alien-fix）。
