# 交付：cc/rules-newsrc5

- 车道／工作者：C 规则／rules（cc）
- 状态：可合并（第二棒做完；第一棒 40% 线交接的「接续」节留作背景）
- 从集成分支 7c2a3a7e 切出，已合 `cc/rules-newsrc4`（4df3a75e，优化登记一处冲突：留奈叶那行，删「O-待定·流萤遮住角色 setHp」，它已并进 O-212），合并提交 b0a5d9cb。交回集成分支，不进 main。
- 工作树 `.claude/worktrees/vigilant-jackson-ab7704`；generated 是 recursing-shamir 58340027 的克隆，`oracle/state_effects.json` 换成哪吒 newsrc5 工作树（competent-fermat-5b663e）重出的新源参照（不入 Git）。**注意**：本树 manifest 还带 26 份 PlayerChangelog 指纹（集成分支 7c2a3a7e 起转换器不再记，要等集成树重新同步再克隆一次）。

## 任务（总装定）

敌人在热缓存下不复活，定成**原版代码错误**（复活状态本意就是复活；失效是 clearStates 时重建被动缓存带出来的副作用）。做法同 O-212：默认照常复活，另加开关，false 照原版；测试按 false 支比参照，另加默认值断言；登记 O-待定、待用户确认。依据：哪吒交付单 `cc_nezha-newsrc5.md` ①。

## 结论（第二棒）

- **原版机制**（读 v0.62.12 `dsPassiveSkill.js` 1575～1690、`krz_state_re.js` 刷新与 `typestates`，没另跑追踪）：死亡那次 `clearStates` 包装先置脏、再 `ensurePassiveCacheUpToDate`，签名（状态列表）变了就 `invalidateBattlerStateCache`（连 `_statelist`、`need_refreshstatelist` 一起清掉）并 `refreshPassiveCache`，此刻 `_states` 已清，krz `typestates` 按空状态重算成空表、标成不脏。krz `Game_Enemy.refresh` 只在 `need_refresh` 为真时才把 `need_refreshstatelist` 重新标脏；出手前 `need_refresh` 假（热）的那一支，之后到 deselect 都读这张空表，复活状态在 `_states` 里也不生效、不抽数。脏那一支照常复活。角色要等 `Scene_Battle.start` 后 okadd 真才重建，探针没跑它，所以参照里角色行照复活；正式游戏开战后角色同样会中。
- **开关** `XBattler.o_hot_cache_revive := true`（`core/battler.gd`）：true＝照常复活（修正，默认）；false＝照原版。`battle_logic.gd` `apply()` 在 initiate 之前记 `t.hot_at_apply = not t.effect_dirty`，deselect／conclude 之后还原；`add_new_state(1)` 清完状态后，若开关为 false、热、且持有者会按状态重建被动缓存（敌人总是；角色看 `XActor.passive_state_rebuild`），把 `effect_lists` 清空、`effect_snapshot` 设成空且有效（等于 krz 表空且不脏），下一次脏的 `param_refresh` 才恢复。
- **测试** `xiyou_state_effects`：复活实战 136 行按 false 比新源参照；另加 `revive.hot_cache.rows`（敌人热缓存倒着、同状态同抽数的脏行复活的行＝13）和 `revive.hot_cache.default.<行>`（这 13 行开关 true 时复活）。这 13 行在 false 支下与参照一致是倒着的，所以默认断言咬得住。
- **登记** 优化登记「O-待定·热缓存复活」，待用户确认；`回退开关覆盖.py` 不报它。

## 验证（本树；generated 仍是 58340027 克隆＋哪吒新源 state_effects 参照）

| 项 | 结果 |
|---|---|
| 语法检查.py | 通过 |
| xiyou_state_effects | 30143/30145；剩 action.counter.sequence（2792）、rest.costume.undefined_note，与本单无关（第一棒就有） |
| 选测 28 个（tests 里出现 revive／o_hot／effect_dirty 的场景） | 24 过、4 个有失败，判断与本单无关（见下） |
| 回退开关覆盖.py | 不报本开关 |
| 事件空绿扫描.py --check | 空绿 96 例均在基线内 |

- 选测 4 个失败：`xiyou_battle_log` indicator.domain-live；`xiyou_enemy_book` index_ids／oracle_status（图鉴 299% 对 99%）；`xiyou_param_states` 1768.self.repeat／save 五项；`xiyou_state_effects_tp` inventory.costume_0／untranslated_46（哪吒交付单已记，来源是 2771～2774 新状态）。本单默认支（开关 true）行为与改前逐行相同：新增的只有 `apply` 里记／还原 `hot_at_apply`，冻表分支要开关为 false 才走，而全工程只有 `xiyou_state_effects` 临时关它、用完还原。所以这 4 个是本树产物（58340027 克隆＋拷来的参照）对新源的旧差，**没在改前提交上复跑确认**（共用槽满，28 个场景排了 46 分钟），总装合并后按影响面选测时请留意。
- 没跑全量。集成树重新同步后要重新克隆 generated 再跑一次 state_effects（本树 manifest 还带更新日志指纹）。

## 本分支提交（第二棒）

- 95a147f4 热缓存复活开关、测试、登记
- （本提交）交付单验证补全

## 接续（第一棒，背景）

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
