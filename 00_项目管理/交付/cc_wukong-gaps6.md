# 交付：cc/wukong-gaps6

- 车道／工作者：C 规则／机制·悟空（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】GM 加经验补刷新资源；gaps5 留下的 8 个插件逐个查实，修 1 个、查出 2 个真缺（dev.待定）

派单：①审查 39 P3-3；②gaps5「没查实」的 8 个插件逐个查清。**②里查出一个大缺口：YEP_X_ExtDoT 的持续伤害／再生整个没实现（约 46 个状态），不是 gaps5 说的「数据 1 处」，见下表。**

- ① GM 加经验：`XTestMode.give_exp` 升级循环后补 `refresh_resources()`（对应原版 `changeExp` 末尾 `refresh()`：HP／MP 夹回新上限）。`xiyou_test_mode` 加一例 `exp_refresh_clamps`（当前 HP／MP 先设成超上限，加 1 点经验后必须夹回 mhp／mmp）。关闭测试模式时路径不变。
- ② 修了 StateChangeIfRemove 的「SC自动解除」：`battle_logic._tick_states` 里状态到期移除后，若备注有 `<SC自动解除:N>` 且该状态已不在身上，改附加状态 N（数据里只有 1328 纵横→1329 联宇，剑舞逍遥 7491 会放 1328）。新专项 `xiyou_state_change_remove`（7 条：备注、到期前、到期换状态、新状态同轮不递减、手动移除不触发）。其余 SC 标签（步数／物品／受伤／战斗结束／行动限制解除）数据里 0 处，没做；`SC触发开关解除` 数据 0 处，仍是 `resource_context.supported` 里的「未支持」报警。

### 8 个插件结论

插件都在 `plugins.js` 里 `status:true`。数据用量按冻结源 `data/*.json` 全部字符串（含地图事件的插件命令、脚本、文字代码）扫过。

| 插件 | 参数／启用 | 数据用量 | 重制 | 结论 |
| --- | --- | --- | --- | --- |
| DEX_GaugeActionSystem | 启用，无参数 | 0（没有 `$gameSystem.gauge(` 调用） | 无 | 不用移植（没数据） |
| YEP_X_ExtMesPack2 | 启用，文字代码 `\qi \compare \caseSwitch` 等 | 0（全库文字里一个都没有） | 无 | 不用移植（没数据）；ExtMesPack1 已有 |
| MOG_BattleTransitions | 启用，默认动画 -1、遇敌闪烁 false | 0（没有 `transition_effect` 命令） | 无 | 不用移植：-1 是 MV 默认转场，唯一效果是关掉遇敌闪屏，重制没有这个闪屏 |
| LL_GalgeChoiceWindowMV | 启用 | 0（没有 `LL_GalgeChoiceWindowMV` 命令） | 无 | 不用移植（没数据） |
| StateChangeIfRemove | 启用 | 1 处 `<SC自动解除:1329>`（状态 1328，技能 7491 可放） | 无 | **真缺·小，已修**（见上） |
| YEP_X_VisualStateFX | 启用，状态图标／动画开 | 1 处：状态 1297「刻印环身盾」`<State Animation: 900>`（循环「光环·呼吸」），状态 1297 挂在多个首领敌人身上（280／284／286／359／601／607／662／695／703／711／719 等） | 无循环状态动画；战斗里也没有状态 overlay 代码 | **真缺·小（纯画面）**：状态在身上时循环播动画 900。不影响数值，没做（需要战斗场景加「状态循环动画」通道，约半期，归 B 界面车道）。状态 overlay／状态图标这些通用画面另有没有也没查，见下「顺带」 |
| YEP_AbsorptionBarrier（Custom User Barrier） | 启用（另有 `_Optimize` 补丁，只做性能） | 1 处：技能 10032「月之庇佑」（嫦娥 156 职业 154，Lv50 学）`<Custom User Barrier> value = user.hp;`，伤害公式 0；全库没有别的屏障备注 | **整套屏障（吸收伤害、穿透、回合屏障、清除规则）没有实现**，`modes` 里 0 处 barrier | **真缺·中**：嫦娥这一个技能放了没有任何效果。要做的话：屏障值（永久／回合）存档、受击先扣屏障（含穿透率、弹字）、战斗结束／死亡清除。需要先用 `mv_oracle` 量原版，再做，约 1 期 |
| **YEP_X_ExtDoT** | 启用，Regen 动画 46、DoT 动画 59、默认波动 20%、默认元素 0 | **约 46 个状态**：`<DoT Formula: …>` 约 35 个（中毒 33／35／48／54／69／70／84／89／93／95…、损伤 43／91／164／473…）、`<Regen Formula: …>` 约 10 个（55／57／117／160／168／185…），自定义公式 2 个（1386、2038）；公式有常数、`a.mat*5`、`b.mhp*0.03`、`1025 + a.atk*7 - b.def*2` 等；`a` 是状态来源、`b` 是持有者 | **没有实现**：`modes`、转换器、设计文档里搜不到 `DoT Formula`／`dotFormula`；实测下面一条 | **真缺·中（玩家直接能碰到）** |

**实测（YEP_X_ExtDoT）**：临时专项（已删，不入库）给敌人挂 33（毒 300）、43、55（再生）、95（3% 最大生命）、1386 后调 `turn_end_battler`，HP 全部一点没变（5000→5000，日志 0 条）。原版 `regenerateAll` 前会跑 `processDamageOverTimeStates`：对每个状态按公式算 `value = max(0, 公式)`，减伤状态取负，加 ±波动（默认 20%）与元素倍率、四舍五入，`gainHp` 后弹字并播动画。重制的 `_regenerate` 只处理特性里的 HP 再生率和叠毒脚本，所以这批状态现在不掉血、不回血。

**建议（不在本期做，需要总装决定）**：
- 派一条规则车道做 YEP_X_ExtDoT，约 1～2 期：① 转换器把 `<DoT／Regen Formula>`、动画、波动、元素、`<Custom DoT／Regen Formula>` 解析成状态 `effects`（可复用 `formula_program`，公式变量 `a／b／user／target／origin／s／v`）；② `_regenerate` 之前对每个状态按原版次序处理，走 `XResourceContext.gain`（护盾吸收、绑定隔离、导入角色平衡都在那一层），弹字与动画走 `regen` 日志；③ 先用 `mv_oracle` 加一个 `dot_probe` 量原版（固定随机：波动 `Math.randomInt`、元素倍率），再对照。注意：导入角色平衡里「持续伤害 ×0.01」目前只认特性里的负 HP 再生，DoT 公式要不要缩放也要查原版 `installImportedBalanceRuntime`（`imported_balance.gd` 里「行动内公式直接 gainHp 缩放」写着未移植）。
- 屏障（月之庇佑）放在 DoT 之后，单独一期。
- 状态循环动画（1297）并入界面车道的战斗画面清单。

**顺带（没查实，不进清单）**：重制战斗里没找到状态 overlay 的绘制（States 数据有 `overlay` 字段，VisualStateFX 的「Actor／Enemy State Overlay: true」也开着），可能是另一处在画；没有逐项确认。

## 交接板

- 下一步：加「YEP_X_ExtDoT 持续伤害／再生（约 46 个状态，现在完全不生效，规则车道 1～2 期，先 mv_oracle 量原版）」为**高优先**；「月之庇佑屏障（嫦娥 10032）」「状态循环动画 1297」为低优先。gaps5 的「没查实」8 项划掉，其中 4 项不用移植、1 项已修、3 项进上面的清单。
- 用户试玩说明：连续伤害类状态（中毒、流血、灼烧、祝福再生）目前不生效是**已有的缺口**，本期没改；修了纵横到期后接联宇。
- 需要用户决定：无新增（DoT 是否本期就做由总装排）。

## 进度账

- 不改数。备注：ExtDoT 约 46 个状态不在 dev.239 的分母里，补上后分母要加。

## 可优化（流程／工具／效率）

- 建议（工具，归哪吒）：gaps5 提的「插件名 × 重制引用」脚本，这次又验证了它的必要：名字对不上（DoT 公式是 meta 键，不是代码里的字面量）只能靠「数据用量 × 重制行为实测」。可做成 `插件覆盖实测.py`：对每个插件在数据里的备注标签／命令枚举出用量，再对「标签字符串是否出现在 modes／转换器」打表，0 出现 + 数据用量 >0 的自动列为疑似缺口。预计半期。
- 已做：无。

## 验证

- 专项：`xiyou_test_mode`（68／68，含新例 `exp_refresh_clamps`）、`xiyou_state_change_remove`（7／7）本机通过；`语法检查.py` 通过（533 个 .gd，0 问题）。
- `选测.py main --list`：140 个场景（battle_logic 触发战斗核心类），>40 走 `云端选测.py run`（提交 415dd3f2f4，已推 `ci/cc/wukong-gaps6`），结果见下方「云端结果」。
- 没碰切片、转换器、探针，不用重跑同步。

## 云端结果

云端选测通过：提交 415dd3f2f4，140 个场景分 4 片，最长一片 9.4 分钟，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41842066614 。

## 本分支提交

- 6e46798d StateChangeIfRemove「SC自动解除」+ 专项
- GM 加经验补 refresh_resources（本分支第一个提交）
- 415dd3f2 合并 main
- 本交付单
