# 交付：claude/bajie-40-25f7f4

- 车道／工作者：C 规则·机制／八戒（Claude，重制_八戒_40）
- 状态：进行中

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】336 变身能力值惰性缓存（dev.待定）

- 依据沙僧 codex/transform-param-cache 交付单的 40 项预检与实施设计。另读冻结源 krz_state_re：Game_Enemy.param 在 inBattle 时走 _ParamCache2／need_refresh_param，refresh 只在 need_refresh 为真时让八格一起变冷；本轮用调用栈追踪确认原版 refresh 的时点（useItem 付费后、removeImmortal、Game_Unit.onTurnStart、onTurnEnd 内 regenerateAll、endTurn 的 refreshAllMembers、加减状态与 buff 内部）。
- 正式参照：battle_event_probe.cjs 新增独立例 command336.param-cache-466（敌群 466 敌人 534→538，难度 3，开战后），既有 8 例与顶层 fixture 不动，契约 battle_event_contract.py 登记新 id；同步 --accept-additions 只新增此例。内容：开战初始格子、九种预热组合、连续变身、22 个刷新边界（refresh／setHp／setMp／加减状态 4、clearStates 与 recoverAll 各带不带 77、addBuff／addDebuff／removeBuff、onTurnStart／onTurnEnd、显式 dirty、gainHp／Mp／Tp 非零与零、gainSilentTp）、5 组真实解释器序列（336→334、336→334→334、336→333 加 4／加 77／去 4→334）。每步只读原始格子与 dirty，规定位置才读 2～7 号参数。
- 实现：XBattler 加 param_cells（8 格，null＝冷格，0 也算命中）与 param_dirty（与格子有效分开）；XEnemy.param 战斗中经 cached_param 惰性填格。XBattleLogic.setup 最后（逃跑率读敏捷之后）param_cache_begin，end_battle 退出。接入：add_state 新附加才 refresh＋标 dirty（已有状态只续回合）；remove_state 有该状态才 refresh、总标 dirty；XResourceContext.refresh 开头消费 dirty；gain 按请求值非零在调用结束后标 dirty，silent_gain 与 gain(0) 不标；sequence_buff 的 addBuff／removeBuff 标 dirty、addDebuff 不标；useItem（含防御）付费后 refresh；行动序列 IMMORTAL 解除及无序列技能收尾对目标 refresh；回合开始标 dirty 后 refresh；回合结束拆成 turn_end_battler（前后各标 dirty、中间 refresh）再全员 refresh；333 补的截资源不当场消费刚标的 dirty。去掉 stale_caps：变身不标 dirty，334 回满直接读缓存上限（含 77 与变身旧形态两种旧上限）。
- 新测试 xiyou_transform_params（249 项）逐项比格子、dirty 与读数，另测克隆隔离（克隆读冷格不暖原对象）与战斗结束退出缓存。xiyou_battle_events 夹具 put() 按参照快照同步缓存（快照读全八项、夹具最后一步留 need_refresh）。相关回归（battle／battle_events／troop_events／random_streams／combat／action_sequence／smart_ai×4／otb／floor 系列／rules×12／custom／formula 系列／shield）全部通过。
- 审查 XFormulaContext：effectful 路径按属性逐个读（_row 未被调用）；pure 路径按公式计划预读，计划跨三元分支收集，可能比原版多暖一格——只有之后未经 dirty 刷新又遇 336 才会显出差异，登记为残余风险不改公式适配层。预览 clone_battler 深拷贝格子，隔离已测。
- 未仿真：角色的同类缓存（Game_Actor.param）、战斗外的 paramRate 缓存（334.hidden 参照在战斗外，靠它留住 77 的上限；Godot 用战斗内格子表达同一结果）、xparam／sparam 缓存、applyModifyBuffTurns 的 refresh。

## 交接板

- 下一步：Codex 核查期一（缓存接入点是否漏掉原版 refresh／dirty 时点，尤其行动中途与回合交界）；角色能力值缓存与 paramRate 缓存是否要仿真另议。
- 用户试玩说明：变身首领（如三十层玉皇 466→538）变身前打过的能力值会留旧形态，直到下一次状态／回合刷新；与原版一致。
- 需要用户决定：无。

## 进度账

- 战斗规则：完成度不调整（属既有缺口的修复），由 Codex 核查后再定。

## 本分支提交

- 85e772b WIP：探针新例、缓存与新测试
- a5409e9 336 变身能力值惰性缓存（期一）
