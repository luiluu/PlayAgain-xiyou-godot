# 交付：cc/rules-newsrc5

- 车道／工作者：C 规则／rules（cc）
- 状态：进行中（40% 线交接，下一棒接「接续」）
- 从集成分支 7c2a3a7e 切出，已合 `cc/rules-newsrc4`（4df3a75e，优化登记一处冲突：留奈叶那行，删「O-待定·流萤遮住角色 setHp」，它已并进 O-212），合并提交 b0a5d9cb。交回集成分支，不进 main。
- 工作树 `.claude/worktrees/vigilant-jackson-ab7704`；generated 是 recursing-shamir 58340027 的克隆，`oracle/state_effects.json` 换成哪吒 newsrc5 工作树（competent-fermat-5b663e）重出的新源参照（不入 Git）。**注意**：本树 manifest 还带 26 份 PlayerChangelog 指纹（集成分支 7c2a3a7e 起转换器不再记，要等集成树重新同步再克隆一次）。

## 任务（总装定）

敌人在热缓存下不复活，定成**原版代码错误**（复活状态本意就是复活；失效是 clearStates 时重建被动缓存带出来的副作用）。做法同 O-212：默认照常复活，另加开关，false 照原版；测试按 false 支比参照，另加默认值断言；登记 O-待定、待用户确认。依据：哪吒交付单 `cc_nezha-newsrc5.md` ①。

## 接续

- 现状（本树、新参照、含 newsrc4）：`xiyou_state_effects` 29962/30131，revive.apply 失败的全是 **30 组「敌人＋dirtyBefore=false」**（每组若干项）；另 action.counter.sequence（2792）、rest.costume 各 1，跟本单无关。Godot 现在这 30 组都复活，参照不复活。
- 已查到的 Godot 侧：
  - 死亡在 `core/battler.gd` `add_new_state(1)` 里做 die（清状态那段循环）。打了临时日志：**到死亡那一刻，两支（dirtyBefore 真／假）的 `effect_dirty`、`param_dirty` 都已是 false**（apply 里的 refresh 先消费掉了），所以不能拿死亡时的脏标记区分；能区分的只有 apply 开始时的 `t.effect_dirty`（测试里 dirtyBefore 真＝`param_mark_dirty()` 过）。
  - krz 的 deselect 表在 Godot 是 `effect_lists`／`effect_snapshot`（`battler.gd` 第 318 行 `effect_states`、第 612 行 `param_refresh`）。原版「表变成空且标成不脏」在 Godot 的对应写法：死亡时 `effect_lists.clear(); effect_snapshot = []; effect_snapshot_valid = true; effect_dirty = false`，下次 `param_mark_dirty`→`param_refresh` 才恢复。
- 原版机制**还没完全对上**：我写的单例追踪 `mv_oracle/.sandbox/rn5_trace.cjs`（不入库；新开战斗、双方 refreshPassiveCache、照探针 reset／预热）**没复现**热缓存不复活（两支 deselect 表都是 [1099]；敌人 clearStates 钩子也没被调到，敌人的 die 路径可能另有包装）。下一棒建议直接在哪吒改过的 `state_effects_probe.cjs` revive.blocks 实战段里打点（clearStates／die／`_statescache2`／`need_refresh_states`／`typestates('deselectState')`），找出「热」那一支表变空的确切时刻和条件，再决定 Godot 的触发条件：
  - 若条件确实是「apply 开始时 krz need_refresh 为假」：在 `battle_logic.gd` `apply()` 开头记 `t` 当时是否 `not effect_dirty`，死亡时开关为 false 且记为热、且这个持有者会按状态重建被动缓存（敌人总是；角色看 `XActor.passive_state_rebuild`，正式游戏开战后为真）→ 按上面写法冻空表。
  - 角色在正式游戏里同样有被动缓存（开战后 okadd 为真），原版角色热缓存下大概也不复活；参照里角色行照复活，是因为探针没跑 Scene_Battle.start（okadd 假）。开关的回退支要不要连角色一起，等机制查实再定。
- 开关建议：`XBattler.o_hot_cache_revive := true`（true＝照常复活；false＝照原版）。测试：`xiyou_state_effects` 复活实战按 false 比参照（30 组应全过），另加默认断言（同一行 true 时复活）。登记「O-待定·热缓存复活」，状态「待用户确认」。

## 本分支提交

- b0a5d9cb 合 cc/rules-newsrc4
- （本提交）WIP 交付单
