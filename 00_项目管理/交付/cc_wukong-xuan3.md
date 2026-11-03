# 交付：cc/wukong-xuan3

- 车道／工作者：A 内容／悟空（cc，悟空 xuan3，Opus medium；接上个会话没提交的现场，先 `WIP:` 提交 cefa4e0f 再做）
- 状态：可合并（选测结果见「验证」）

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】璇第二期：绑定与手动附身（dev.待定）

- 绑定：璇登记进 `XBinding`（种类 xuan，手动模式）；寄星、寄星·附身（转移）、回身走 `Game_Action.apply` 包装；指令窗附身时加「回身」；选宿主只列合法队友；星纹标记；默契结算（寄住 10、护主 5、协同 5、每回合上限 20、20 级起额外、转移保留 50%／名册 75%）；同轨（默契 100）；附身期间不掉血（`resource_context.gain` 接 `XBinding.blocks_hp_loss`，原来这个开关登记了但没接）；换宿主台词、定星台词进战斗日志。
- 移光（换宿主迁移旧宿主璇护盾 50%／75%／100%）、留辉（旧宿主保留共宿双防 1～3 回合）。
- 共宿：宿主（含列星星影）直接伤害 ×(1＋10%～30%)（伤害钩子 xuan-host-offense，并进 `XActorDamageHooks`）；双防加璇双防的 15%～30%（`actor.gd` param 链，在谷雨与屠苏之间）；并轨 3 级副宿主拿同一份；三者同源取较高。
- 列星（手动）：星影按等级 1／2／3／全部（副宿主优先、再按血量比例），持续 2 回合，到期撤状态；期间回光、璃壁目标加上全部受益者，棱光每多一名星影再打一遍原目标；命主宿主净化一个硬控。
- 三法宝成长（installThreeGrowthRelicRuntime）：星盾流转·接力（20 级，换宿主时旧宿主璇护盾 20%／60 级 30% 给血量比例最低的另一名队友）、定轨（10 级，璃壁被敌人打破时给一次定星）；璇的护盾真挡下伤害计护主。
- 去掉 `XTusuXuan.meets` 里「寄星·附身、列星恒假」的占位（绑定合进来前加的）。
- 原版参照：`mv_oracle/xuan_bind_probe.cjs` 40 例（真实 Game_Action.apply、BattleManager.startTurn／endTurn，随机 0.5，关五乘区、路线压制与路线支援 O-050），产物手工复制为 `tests/fixtures/xuan_bind_oracle.json`；新测试 `xiyou_xuan_bind` 612 项。
- 已知没做：先照手动先制（原版 `Game_Action.speed` +100000，OTB 下怎么用还没量）；60 级列星法宝特效（homeUsed、星雾、额外净化）；星契自律全部（第三期）；定轨没有原版参照例（代码照读，没量）。

## 交接板

- 下一步：璇第三期（星契自律，盘点见 xuan2 交付单）；顺手补先照先制与 60 级列星特效、定轨参照例。
- 用户试玩说明：璇现在能寄星附身、换宿主（每回合一次）、回身；附身时宿主伤害和双防变高，换宿主带走护盾；30 级起能用列星让更多队友一起受护。星契自律还没有。
- 需要用户决定：无新增（余辉仍在交接板）。

## 进度账

- 璇（177）战斗机制：第一期、第二期完成（先照先制、60 级列星特效留到第三期），第三期未做。

## 待交叉核查

- 改了核心文件：`actor.gd`（param 链加一层）、`actor_damage_hooks.gd`（capture 加一项）、`battle_logic.gd`（targets_for 一行、take_logs 三处、apply 一处）、`resource_context.gd`（gain 开头一行：附身不掉血）、`shield_ledger.gd`（_on_absorb 一行）、`battle_scene.gd`（指令窗、选目标）、`tusu_xuan.gd`（删占位）。
- 请看：①共宿伤害钩子的 kind 判断用的是 `XRaceBattle._damage_spec(item).kind`，没读调用时传进来的 `options.kind`，带 kind 选项调伤害的路径可能判不准；②`resource_context.gain` 的不掉血放在谷雨归根之前、护盾吸收之前，原版绑定包在 Game_Actor.gainHp／setHp 上；③定轨用 `XBinding.enemy_acting()` 代替原版的 `direct(BattleManager._action)`。

## 可优化（流程／工具／效率）

- 探针关路线压制要关三处（otherScale、isSuper、support），这轮漏了 support，共宿伤害率量出来减半。和 xuan2 提的「超强者参照公用开关」是同一件事，归工具车道。

## 验证

- `语法检查.py` 通过；`探针登记检查.py` 通过。
- `xiyou_xuan_bind` 612/612。
- 选测：`选测.py main --list` 列出 308 个（param 链和伤害钩子改动波及几乎全部），没全跑；跑了 18 个全部通过：`xiyou_xuan_battle` 246、`xiyou_xuan_chart` 128、`xiyou_binding` 291、`xiyou_tusu` 327、`xiyou_tusu_battle` 4977、`xiyou_guyu_battle` 1637、`xiyou_shield` 565、`xiyou_shield_ledger` 138、`xiyou_determinism` 372、`xiyou_battle` 9、`xiyou_battle_gaps` 1023、`xiyou_state_js` 1733、`xiyou_rules_d1c` 61597、`xiyou_rules_d4` 61678、`xiyou_race_battle` 653、`xiyou_alien_battle` 330、`xiyou_honghuang_curse_battle` 342、`xiyou_garou_battle` 255。请总装按影响面再选。
- 没开游戏实际玩过；没跑 `反向验证.py`。

## 本分支提交

- WIP：上个会话的现场（cefa4e0f）
- 合 main（28b8480a）
- 检查点：第二期续（4bd706ae）
- （本提交）交付
