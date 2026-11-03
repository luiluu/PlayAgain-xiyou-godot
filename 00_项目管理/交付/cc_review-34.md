# 交付：cc/review-34

- 车道／工作者：审查／cc（审查 34，Opus medium）
- 状态：可合并
- 基线：从 main `b5f3a0ce`（合并 xuan3，收尾提交之前）切出，只加本交付单。行号按这个基线。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 璇第二期、成长装备尾项二、璇修审查 32、工具第五十二期

- 核查覆盖：cc/wukong-xuan3（d9566a67）、cc/bajie-growth5（183365c8）、cc/bailong-xuan-fix1（4a90e055）、cc/nezha-tools52（24006d53）
- 结论：P1 无；P2 两条（都在璇：附身期间的持续伤害没隔离、读档后命主名册战斗里认不出）；P3 三条（定轨的敌方直接伤害判定放宽、留辉跨战斗、O-150 作者写错）。growth5、xuan-fix1 通过；xuan3 待修 P2 两条；tools52 除 P3 一条外通过。
- 验证：对着冻结 v0.28 读码；临时原版脚本量了璇附身期间的中毒再生（见 P2-1，不进仓库）；Godot 里量了 JSON 读回数组的 `has`／`find`（见 P2-2）；3 个原版探针（xuan_bind 40、heartsteel 49、growth_help 12 例）在本树重跑与夹具逐例相等；专项 7 个全过；没跑全量。

## 问题

### P2-1 璇附身期间中毒等持续伤害照扣，原版不扣（xuan3）

- 位置：`modes/xiyou/battle/battle_logic.gd` `_regenerate`（约 2367～2412 行）。xuan3 只在 `resource_context.gain` 开头接了 `XBinding.blocks_hp_loss`，回合末再生／持续伤害这条路直接写 `b.hp`，不过 `gain`，所以没挡。
- 原版量过（临时脚本，xuan_bind_probe 的 setup，璇寄星给 1 号后给自己挂中毒 4，hrg −0.1）：璇 `regenerateHp()` 前后 2349→2349 不变；同场没被绑定的 8 号同样中毒 450→405。原版注释也写明「璇附身期间也隔离回合持续伤害和直接扣血」（installNativeBindingChargeRuntime.js:226）。
- 重制：璇先中毒再寄星（毒留在身上），附身的每个回合末都会掉血；maxSlipDamage 夹到 1 血不会打死，但血量和原版不一样，回身后的血量也不同。
- 建议：`_regenerate` 里负的 HP 再生遇 `XBinding.blocks_hp_loss(b)` 归零（护盾吸收、弹字都不走）；xuan_bind 探针补一例「附身后中毒，回合末不掉血」。
- 顺带：xuan_bind 现有的 `owner.hp_loss` 一例只测了直接 `gainHp`／`setHp`。

### P2-2 读档后命主名册在战斗里认不出人（xuan3 读名册；xuan-fix1 只修了点名册那一处）

- 位置：`modes/xiyou/core/xuan_battle.gd:151` `_is_roster`：`(c.roster as Array).slice(0, stage).has(int(t.actor_id))`。
- 存档走 JSON，读回后名册是 `[8.0]`；在 Godot 里量过：`JSON.parse_string("[8]")` 的 `has(8)`、`find(8)` 都是假／−1。xuan-fix1 只在 `toggle_roster` 里归整，玩家读档后不点名册，名册就一直是浮点数。
- 后果：读档后打仗，名册里的宿主当成不在名册：换宿主默契只留 50%（应 75%），列星不给命主宿主净化硬控。存档里、新开局（没读过档）不受影响，所以现有测试测不出。
- 建议：在 `XXuanChart.chart()` 读出时就把 `roster` 归成整数（或 `_is_roster` 里比 `int`），一处管全部；测试照 xuan-fix1 的写法，存读档往返后不点名册直接进战斗量 `_is_roster`。

### P3-1 定轨用「敌人在行动」代替原版的「敌方直接伤害行动」，判定变宽（xuan3，交付单问③）

- 位置：`modes/xiyou/core/xuan_battle.gd` `on_absorb`：`XBinding.enemy_acting()` 只看行动者是不是敌人。
- 原版 `direct(action)`（installThreeGrowthRelicRuntime.js:52）还要求技能伤害类型是 1 或 5、`isForOpponent()`。所以敌人用不带伤害的技能、但行动序列里扣血（`sequence_gain`）打破璃壁时，重制给定星、原版不给。
- 眼下要碰上得有这种敌人技能，实际少见；建议第三期顺手把条件补全，探针加一例「非伤害技能的序列扣血打破璃壁」。

### P3-2 留辉原版挂在旧宿主身上、跨战斗不清；重制存在本场数据里（xuan3，只读码，没量）

- 原版 `transferEffects` 把留辉写在 `previous._codexXuanAfterglow`（installNativeXuanRuntime.js:350），只在下一次换宿主时删，`onClear` 不删；`param` 包装只比 `until >= round()`。如果 `round()` 每场从 1 数，上一场末尾留下的留辉在下一场开头几回合还会生效。
- 重制放在 `XXuanBattle.data.afterglow`，战斗结束随本场数据清掉，不会带到下一场。
- 先用探针量一下原版是否真的带过去：真带过去就是原版缺陷，重制的写法要按「原版缺陷先改后登记」补一条 O 号和回退开关；没带过去就不用管。

### P3-3 O-150 的作者写成了悟空，实际是八戒（tools52）

- tools52 补 O-149／O-150 的「执行者」列都写了 `cc（悟空）`。O-149（`O_RECAST_CASTER`）确实是悟空（ae3715bb）；O-150（`XHubris.KILL_FIX`）是八戒在 37395338（`执行者: cc（八戒）`）加的，`git log -S KILL_FIX` 只有这一个提交。
- 两条新补的「理由」是哪吒按条目意图写的，不是原作者的原话，内容我读过没毛病；作者列改成八戒即可。

## 交付单自己问的（xuan3 三问）

1. **共宿伤害钩子没读 `options.kind`**：现在没有差别。重制里没有调用处给 `XDamage.calculate` 传 `kind`，也没有钩子改 `frame.kind`，帧里的 kind 就等于技能表 `_damage_spec(item).kind`；`XRaceBattle` 也是同样读法。以后要是有路径传 kind（例如内部施放按百分比），记得这里改读帧，现在不用动。
2. **不掉血放在谷雨归根、护盾吸收之前**：对。原版是 `Game_Actor.prototype.gainHp／setHp` 的包装，角色身上它在 Game_Battler 那串（谷雨、护盾账本）外面，先挡下就不进护盾、不进谷雨，重制次序一致。漏的是不走 `gain` 的再生那条路，见 P2-1。
3. **定轨用 `enemy_acting()` 代替 `direct()`**：不等价，见 P3-1。

## 已查通过

- **cc/wukong-xuan3（甲）除 P2-1、P2-2、P3-1、P3-2 外通过。**
  - 绑定登记、onBind（名册 75%／普通 50%、换宿主台词、移光、留辉、同轨、接力 20 级）、onUnbind、onRoundStart（先照债务；璇玑星盘首回合星契交付单已说明不做）、默契结算（寄住、护主、协同、每回合上限、20 级额外、列星到期）与原版逐行对过。
  - `param` 链：共宿双防在谷雨与屠苏之间（安装序 41），同源取较高，`_param_guard` 防递归，与原版 `_codexXuanParam` 一样。
  - 伤害钩子：只认角色、非璇、伤害类型 1／5、normal／true、在共宿覆盖里，乘 `1＋共宿伤害率`，与原版 `xuan-host-offense` 一致。
  - `apply_command` 寄星／转移／回身不走普通结算；`meets` 的寄星·附身、列星条件与原版 `meetsSkillConditions` 包装一致（去掉 tusu_xuan 里的恒假占位后由 `XXuanBattle.meets` 接管）。
  - 列星：星影数 1／2／3／全部，副宿主优先再按血量比例；`extend_targets` 回光、璃壁加受益者，棱光每多一名星影多打一遍原目标；命主宿主净化一个硬控。
  - `take_logs` 在 act、强制行动、回合末三处取，台词次序在屠苏之前。
- **cc/bajie-growth5（甲）通过。**
  - 派单重点：`XHeartsteel.suppressed` 清 `_started`、`_cast` 后 `end_action` 直接返回，和原版「`_codexHeartsteelFinished` 照设、因 `_tojiSuppressed` 不减」结果相同：原版 endAction 包装里除了减蓄力没有别的事；`_codexHeartsteelFinished` 只防同一行动结算两次，重制一次行动只调一次 `execute`（`act` 里），清掉后不会再被 `start_action` 记回来。失效的巨人吞噬：原版 startAction 包装在 `oldStart`（里面 applyGlobal 设 `_tojiSuppressed`）之后照样设冷却 3，重制 `start_action` 在 `XToji.suppressed` 之前，同样进冷却。
  - `XHubris.suppressed` 同理，对原版 installNativeHubrisRuntime.js:157 的 `!action._tojiSuppressed`。
  - 智能 AI 巨人吞噬估伤与 Codex_SmartBattleAI.js:149～155 逐项一致（技能号定档、`actor.mhp`、castScale、物防最多减一半、不取整）。
  - 提示文字与次序、专属法宝战力三件读过，与探针对得上。
- **cc/bailong-xuan-fix1（甲）通过。**
  - O-152 开关两支都有断言：`max.rows`（开，「强化（已满级）」）、`max.rows_original_label`（关，「强化（星砂undefined）」）；`回退开关覆盖.py` 现在 90 个开关、新缺口 0。
  - P3-1 结论成立：原版 `_codexShowSourceHelp` 先把 descParams 压到 14 再 `setItem`（installNativeLeviathanForge.js:139），而原件都是心钢／狂妄一族，`U.isGear` 为真，hubris 的 setItem 包装走 `helpView` → `RJO.HE.getDescParams` 把 `descParams` 清空重建（HelpExtend.js:150），压的字号被冲掉。
  - 名册归整只修了 `toggle_roster`，战斗里读名册那处见 P2-2。
- **cc/nezha-tools52（丙，看结论）除 P3-3 外通过。**
  - 拆场景：rules 难度 3、6 各 16 个场景，part 0～15 连续不缺（`xiyou_rules_d3`／`d6` 是 part 0），按序号轮流分份，断言合计不变；map186 `mine` 仍跑 EV16～23 全部，`mine_a`／`mine_b` 各一半。
  - 探针五乘区正则加 `evalDamageFormula`、`.result()`，单测 6→8；七个探针补关五乘区。
  - 「选测过宽」的结论（分叉点旧）对，提示功能已派 tools53。

## 交接板

- 下一步：派 xuan4（悟空）顺手修 P2-1、P2-2、P3-1，并量 P3-2；P3-3 改优化登记一格，谁合并谁顺手改。
- 用户试玩说明：无。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 从 `s.flags` 读回的数组用 int 找不到，这一期又碰到一处（P2-2）。tools53 的只读扫描应把 `.has(`／`.find(`／`.slice(...).has(` 都算上，xuan_battle 这处可以当它的一个正例。

## 验证

- 原版探针在本树重跑：`xuan_bind_probe` 40 例、`heartsteel_probe` 49 例、`growth_help_probe` 12 例，产物与 `tests/fixtures` 逐例相等。
- 专项（`并行测试.py`，并行 2）：`xiyou_xuan_bind` 612、`xiyou_xuan_battle` 246、`xiyou_xuan_chart` 133、`xiyou_heartsteel` 463、`xiyou_growth_help` 53、`xiyou_growth_forge` 538、`xiyou_binding` 291，全过。
- `回退开关覆盖.py`：90 个开关，新缺口 0。
- P2-1 用临时原版脚本量（xuan_bind_probe 的 setup＋中毒＋`regenerateHp`），脚本不进仓库；P2-2 在 Godot 里量 `JSON.parse_string("[8]")` 的 `has`／`find`。
- 没跑全量，没跑反向验证；P2-1 重制一侧是读码（`_regenerate` 不过 `gain`），没在 Godot 里实打。

## 本分支提交

- 本提交：审查第 34 期交付单
