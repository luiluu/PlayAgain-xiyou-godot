# 交付：cc/rules-gaps7

- 车道／工作者：C 规则·CounterGuard＋敌群页覆盖剩 21 条／cc（GB2）
- 状态：进行中（Kyo 18:40「该收工了」，停在 Godot 测试之前；代码与原版参照已提交，Godot 侧一项测试都没跑）

## 接续要点

1. **补齐已完成**（clone：scratchpad/rg7，已 `--补齐`）。接手者在自己的 clone 里 `git switch cc/rules-gaps7` 再 `新建工作树.sh --补齐`。
2. **没跑的测试（全部要跑）**：
   - `xiyou_counter_guard`（新场景）：4 例对照＋回退支 `COUNTER_GUARD = false`。
   - `xiyou_troop_events*`：先把嘤嘤怪 7 例并进本地 `modes/xiyou/generated/oracle/troop_events.json`（参照在 `mv_oracle/.sandbox/dev_troop_events.json`，用 `mkdev.py` 只跑新例生成；或整份同步），再 `XIYOU_TROOP_ONLY=1` 跑四份＋half。新函数 `_party_case` 没在 Godot 里跑过，可能要调（回合循环、`logic.state.actor()` 的取法、eventRandom 换流）。
   - 选测：`选测.py main --list` 列出的战斗核心类（battle_logic 改了，至少 xiyou_determinism、xiyou_life_steal、xiyou_raven_reflect）；工具回归.py。
   - 同步 `--accept-additions`（troop_event_probe 加了 7 例；要整份重量，先约总装，注意 GC 的分片）。
3. **语法检查.py 已过**（655 个 .gd，0 问题）。
4. **木桩 826 第二行动位（KNOWN_DIFF 826 t1_states）没动**，查到的线索：参照里不变身例 e0 是敌人 826「黑莲」（AGI 999，有无条件行动 3796～3800），第 1 回合只有强制 6068／6055／6064、没有普通出手；HP≤20% 例开战变身 937「木桩」（AGI 0，只有 8111，条件「队伍等级≥1」），第 1 回合强制之后紧接 8111、排在全部角色之前。所以差别像是「强制之后，原本的行动位还在不在」，和速度、行动表有关，不只是 OTB 第二行动位。下一期先在原版里记 makeActions／getNextSubject 的调用次序再改。

## 变更记录草稿

## 2026-11-08 【cc·GB·未经审查】反击者已不在敌群时跳过反击（v0.53.01 CounterGuard）；敌群探针加嘤嘤怪 1 换队伍（dev.待定）

- CounterGuard：原版 `installCounterGuardRuntime` 包装 `BattleManager.invokeCounterAttack`：反击者是敌人、却已不在 `$gameTroop.members()` 里就跳过这次反击（挨的那一下照样生效），原意是防 Game_Action 找不到队伍索引报错。新探针 `mv_oracle/counter_guard_probe.cjs`（4 例：在敌群／另造的同号敌人／开战后摘掉的敌人／角色反击）确认了。重制 `battle_logic._invoke` 两处反击前加 `_counter_guarded`，开关 `XBattleLogic.COUNTER_GUARD`（false＝v0.53.01 以前）。重制的 enemies 开战后不增不减，正常战斗走不到，跟原版一样留着防外部造的敌人。
- 嘤嘤怪 1：页条件 111 角色第 3 类是「会技能」（23／509／201／575），不是状态。`troop_event_probe.cjs` 加 `PARTY_CASE`／`runParty`（换队伍 1／4／20／29、开战后学会或忘掉技能，记 party／actorSkills），用例尾巴加 7 例；原版跑下来敌群 1 页内非空指令全部执行到（剩 21 条里的 20 条）。`xiyou_troop_events.gd` 的 `setup` 加 party 参数，新增 `_party_case`（比事件加的状态 11／34／45／51）。

## 优化登记草稿

- 无：CounterGuard 是照原版移植，不是改原版，所以没占 O 号（派单写了「O-待定·反击者离场」，请总装定要不要登记；开关已留）。

## 验证

- 原版：counter_guard_probe 4 例 errors 0；嘤嘤怪 7 例（XIYOU_COVER=1，只跑新例）errors 0，敌群 1 覆盖缺口为 0。
- 语法检查.py 通过。
- Godot 测试、选测、工具回归、同步：都没跑（见接续要点 2）。

## 交接板

- 下一步：跑完接续要点 2 的测试再交；826 第二行动位按接续要点 4 查。
- 用户试玩说明：无
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 已做：无
- 建议：探针的「只跑尾部新例」开关（GB 上期提过，归 GC）还没有，这次又用了 mkdev.py 临时脚本。

## 本分支提交

- 193f9d7b WIP：CounterGuard 探针与守卫、嘤嘤怪换队伍
- 交付单（本提交）
