# 交付：cc/wukong-fix5

- 车道／工作者：C 规则·战斗／悟空（cc）
- 基线：main 198dac5b 切出，并入 cc/wukong-accept4，交付前合到 main 333411bf（含 accept4 合并）
- 状态：进行中

## 做了什么

- **原版怎么做的**（临时探针，跑六耳猕猴 321 两种打法：全队普攻／全队用 6168）：
  - 856「模仿」的 `<After Eval>` 由 YEP_SkillCore 在 `Game_Action.apply` 每个目标结算完后 eval：`BattleManager.queueForceAction(user, target._lastUsedSkill || 1, -2)`。
  - `_lastUsedSkill` 原版没有任何代码写它（在 `Object.prototype` 上设拦截，两场 0 次），恒为 undefined，所以就是「对上次目标（-2）强制普通攻击 1」，目标先用过别的技能也一样。
  - 排进 `$gameTemp.forceActionQueue`（并 clearResults），856 这次行动一结束就在事件阶段插队执行，先于本回合还没行动的人：856 → 强制 1 打倒 a8 → 再轮到 a10。
- **重制**：`battle_logic.gd` 新增 `after_eval_force_of(skill)`（认这一种写法，按技能缓存）和 `_after_eval_force()`，在 `apply()` 末尾（心钢拦下之后、奈叶之前）调用：有行动资源上下文时走 `XStateEffects.queue_force`（同 queueForceAction 清结果），否则 `queue_force_quiet`。强制行动由现有的 `_drive_events` 取 `_forces` 执行，目标 -2 走 `last_target_index`（`_invoke` 开头已按 setLastTarget 写好）。与 fix2 防连锁（O-173，只拦 5576／5577 的 quiet 排队）、开战清队列互不影响：强制的是普攻 1，不再带出新的强制。
- **回退开关**：`XBattleLogic.SKILL_AFTER_EVAL_FORCE`（static var，默认 true；false 回到修之前，不执行、少这次强制行动）。这是补原版行为、不是优化，没有占 O 号。
- **测试**：`xiyou_troop_events` 去掉 accept4 加的 KNOWN_DIFF（表留空）；第 1 回合强制行动比较在「强制行动不在回合开头」时改比参照从头到最后一次强制行动的整段；第 2 回合「守层者只行动一次」扣掉 After Eval 带出的强制；`_unit_checks` 加开／关两支（开：856 后紧接 1；关：只有 856）。

## 验证

- `xiyou_troop_events*` 五份全过（4839／4816／4796／4819／half 4306）；321 原来记成已知差异的两项现在严格比、全过。
- `语法检查.py`、`工具回归.py`：通过。
- 选测：改了 battle_logic，`选测.py` 选 287 个场景，走 `云端选测.py run`（提交 2f06d7ed）：（待写）

## 变更记录草稿

## 2026-11-05 【cc·悟空·未经审查】六耳猕猴「模仿」补上强制普通攻击（dev.待定）

- 六耳猕猴的「模仿」856 原版每次命中后让它对同一目标强制普通攻击一次（YEP_SkillCore After Eval 里的 queueForceAction），重制以前没执行；现在接进强制行动队列，行动结束立即插队，与原版参照一致。
- 回退开关 `XBattleLogic.SKILL_AFTER_EVAL_FORCE`；敌群事件对照去掉 accept4 记的已知差异。

## 交接板

- 下一步：无新增（accept4 记的这条差异已修）。
- 用户试玩说明：打六耳猕猴时，它用「模仿」之后会马上再普攻同一个人一次。

## 进度账

- 战斗规则：修一处原版行为缺失，不单独调行内点。

## 可优化（流程／工具／效率）

- 建议（给哪吒）：`选测.py` 把只读工具（如 `03_转换工具/解锁链表.py`、`补预设批量.py`）和 `事件空绿基线.json` 归进 converter 组，accept4 只改这些就选上 65 个 `xiyou_rules*`；这类不进同步、不产参照的脚本可以单分一组只跑工具回归与引用它的测试（预计每次省几十分钟本机或云端额度）。
- 已做：`after_eval_force_of` 按正则认写法；以后再有技能用同样的 After Eval 写法会自动生效，别的写法仍不执行（全库目前只有 856 用 queueForceAction）。

## 待交叉核查

- `modes/xiyou/battle/battle_logic.gd`（原沙僧独占核心文件）：`apply()` 末尾新增 `_after_eval_force` 调用与两个新函数、开关；重点看插入位置（心钢拦下时不排、反射回自己时也会排）和 queue_force 清结果对后续弹字的影响。
- `tests/xiyou_troop_events.gd`：t1_forced_all 整段比较、t2_enemy_once 扣减、回退两支。

## 本分支提交

- 并入 cc/wukong-accept4（快进）
- WIP: 模仿 856 After Eval 接上、去 KNOWN_DIFF、回退支
- 合并 main
- 交付提交（本提交）
