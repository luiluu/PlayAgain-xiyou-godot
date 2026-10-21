# 交付：claude/wukong-32

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_32）
- 状态：可合并
- 完成范围：C 类试点三个角色（108、141、142）都**停在「模块分析＋实施设计」**，没有改代码、没有动切片。原因见各节：108 要新增 6 类战斗流程钩子（行动开始／结束、结束阶段、战斗开始状态脚本、自定义 MP 消耗＋伤害后多段），141／142 共用的 `installImportedBalanceRuntime` 要在每一处伤害结算点按行动者缩放，都落在任务停手条件里（改行动调度或伤害结算主链）。本交付单只含文档。

## 变更记录草稿

## 2026-10-21 【Claude·悟空·未经Codex检验】C 类角色试点：108 奈叶、141 女儿国王、142 天海麒麟星的模块分析与实施设计（dev.待定）

- 做了什么：读原版源码（`js/codex/runtime/installNanohaSharedKillRuntime.js`、`js/plugins/Bailong_NaiyeACS_FastSettlement..js`、`js/plugins/Codex_SmartBattleAI.js`、`js/codex/runtime/installImportedBalanceRuntime.js`）与数据库（Actors／Classes／Skills／States／CommonEvents），摸清三人各自要的专属机制；没有改代码。结论与设计写在交付单正文，C 类接入流程小结写在末节。
- **更正 dev.116（我上一批的交付说明）**：当时写「Godot 没有 Custom Effect 脚本机制」不准确。转换器 `xiyou_export.py` 的 `parse_state_effects` 已把状态备注里的 `<Custom X Effect>` 解析成 `states[].effects[]`（`phase`＋`op`），只翻译了三种形状：`mul`（`value` 乘系数取整，104 条 confirm＋21 条 react）与 `user_param_damage`（轮回困难 Establish）；其余一律 `op: "js"`＝**未翻译**。Godot 只在 `damage.gd:apply_state_effects` 处理 confirm／react 的 `mul`，`battle_logic.gd:1237` 处理 establish 的 `user_param_damage`，其他 phase 完全没人读。全库未翻译的 js 状态效果合计约 500 条（apply 138、remove 110、confirm 74、react 47、deselect 28、battle 26、regenerate 25、establish 21、turn_start 11、action_start 6、turn_end 5……）。所以错误数据状态 1741～1749（turn_start／leave／confirm js）的缺口是这批「js 状态效果」的一部分，不是单独一处缺失。

## 108 奈叶：为什么是 C 类，需要什么

沙僧预检指向 `installNanohaSharedKillRuntime`（队友击杀成长）、ACS 快速结算与 SmartBattleAI 六档炮击选择。实际要的机制比预检写的多，共六块：

1. **杀敌成长**：被动 5683「适应」（学得 1 级起）开战附加状态 1768「杀敌加属性」与 1708「奈叶适应」。
   - 1708：`<Custom Confirm Effect>` 把造成的所有伤害 `value = ceil(value * 0.05)`；这是 `mul`，**Godot 现成已支持**（这也是 104 条 confirm `mul` 里的一条）。
   - 1768：`<Custom Conclude Effect>`：行动后（无论成败）若 `target` 已死，`user.addParam(0,10); user.addParam(1,30)`（永久 +10 生命上限、+30 魔法上限）。conclude 阶段整库只有这一条，Godot 没有 conclude 钩子，也没有「永久 addParam」的存档字段需要核对（`XActor.param_plus` 是装备用的，不确定能否复用）。
2. **队友击杀共享**（`installNanohaSharedKillRuntime`）：奈叶会 10168「并肩适应」＋5683、活着、在出战队伍里时，别的出战角色的行动打中并击杀敌人后，奈叶每死一只敌人同样 +10 生命上限、+30 魔法上限（`BattleManager.endAction` 钩子，打中时 `result().isHit()` 才登记目标，行动结束后看谁死了）。另有读档后补学 10168 的兼容（新开局按职业 1 级习得，不需要）。
3. **自定义 MP 消耗＋伤害后多段**：凰霞风暴（5703／5704／5705）与厄临星爆（5706／5708／5709）都是 `<Custom MP Cost>`（`cost = floor(user.mp * 比例)`，`user._costmp = floor(user.mp*比例/2000)`）加 `<Post-Damage Eval>`：`_costmp > 0` 时对每个目标再 `gainHp(-value)`＋`startDamagePopup()` 重复 `_costmp-1` 次。ACS 插件在段数 >512 时把尾段合并（数学等价，只影响弹字个数）。要新做：自定义 MP 消耗写 `_costmp`、Post-Damage Eval 多段结算（弹字、护盾、角色／敌人结果槽顺序都要对）、百分比 MP 消耗。
4. **5692 小魔炮**：只有一个公共事件菜单（六选一），玩家手动战斗要弹选择框；`Codex_SmartBattleAI` 自动战斗时直接在六档里选（`cannonOptions`、`cannonHits = max(1, floor(beforeMp*power/2000))` 估伤害）。Godot 的 `smart_ai.gd` 要加同样的候选展开，手动战斗要有选择窗。
5. **战斗开始领域类状态**（`js` 效果）：5682「魔法领域」→ 状态 1774 `<Custom Battle Effect>`：`$gameTemp.reserveCommonEvent(2478)`，公共事件 2478 一串 313（改状态）给全员加 1792～ 系列状态；5685 →状态 1780 `action_start`／`action_end`：每次行动前后预约公共事件 2481／2480，按开关与变量在攻防之间转换（5685 的描述「双攻总值 50% 变防御」）。这是「状态效果阶段触发公共事件」，要有 battle／action_start／action_end 三个钩子加战斗内公共事件执行。
6. 数值曲线与技能树照 B 类模板接（职业 108，学 14 项）；`pSkillPointsVarId:1108`。

**为什么停**：2、4、5 要在行动调度里加钩子（行动开始前／结束后／战斗开始），3 要改伤害结算后的多段流程，1 要新 phase。都在「改战斗核心流程」的停手条件里，工作量超过一期。

**实施设计（给下一位）**，建议按依赖拆四步，每步配 mv_oracle 参照逐例对照：
1. **状态效果阶段钩子**（共性，惠及全库约 500 条 js 效果）：先在转换器里把常见 js 形状再翻译一轮（`user.addParam(i,v)` 加击杀判断、`$gameTemp.reserveCommonEvent(N)`、`user.addState(N)`、按速度掷骰），不能翻译的保留 `js` 并在 Godot 里记入 `troop_event_skipped` 风格的未翻译清单；Godot 侧在 `battle_logic.gd` 的行动开始／行动结束／回合开始／回合结束／战斗开始／行动后结算各加一个 `_run_state_effects(phase, user, target)`。参照探针：对一组状态在真实 BattleManager 里按阶段触发，记录 addParam／addState／公共事件调用。
2. **永久 addParam**：`XActor` 加 `param_plus_permanent`（存档字段），1768／10168 用；`slice_probe` 加一条杀敌后能力值例。
3. **自定义 MP 消耗＋Post-Damage Eval 多段**：`damage.gd`／`battle_logic.gd` 的 `_apply` 之后加一段；参照探针用 5703／5706 各档，逐段记弹字与 HP。
4. **AI 与选择窗**：`smart_ai.gd` 加 `cannonOptions`；手动战斗的 5692 公共事件窗口。

## 141 女儿国王、142 天海麒麟星：C 类原因与设计

- **C 类原因（两人相同）**：角色备注 `<CodexImportedDamageRate:0.01>`，属于 `installImportedBalanceRuntime` 管的 26 个「导入角色」（141～166，其中 143／144／145／157／160 禁用）。该模块把这些角色**造成的所有伤害结算**乘 `outgoingRate`（163＝0.001，其余 0.01）并向下取整（不保底 1）：包装 `Game_Action.apply／executeDamage／executeHpDamage／executeMpDamage`、`Game_Battler.gainHp／gainMp` 与 `setHp／setMp`、`BattleManager.processActionSequence／actionHpModify／actionMpModify`、魔法反射（`invokeMagicReflection`），并对 ACS 多段合并（`isAcsLoop`）单独处理，防止同一次伤害重复缩放（`settled`／`direct`／`reflections` 标记）。这是共享的伤害结算上下文，不能只改角色备注。
- **角色自身数据都是已有机制**：141 有 9 项技能（被动 `passiveXPBST／HarmRi／CrHarmRi`、行动序列 9910、伤害技能 9909）、无初始装备；142 有 19 项（行动序列 10098～10100、被动 `HarmRe／ELUP／APLUS／SPBST`、`StartPushState2584／2585／2587／2588`），状态 2588 带 `<Custom Confirm Effect>`（js，未翻译，见上）。装备槽数、技能树、等级曲线照 B 类模板。
- **为什么停**：伤害结算主链上每个落点都要分辨「本次结算有没有已被缩放」，与八戒_40 正在改的 `damage.gd` 取整重叠，也牵涉我上一批的 `sequence_gain`／`absorb_shield` 顺序（护盾吸收在缩放之前还是之后，源模块是先 `scaledNegative` 缩放再进原 `gainHp`，即**先缩放后吸收护盾**）。
- **实施设计**：
  1. 先写 `mv_oracle/imported_balance_probe.cjs`：真实 BattleManager，行动者取 141／142（再各取 163 和一个禁用角色），敌方单体／全体，覆盖普攻、伤害技能（9909）、行动序列（9910／10098～10100）、反射、吸血、DOT、直接 gainHp、MP 伤害；记每次结算前后的 HP／MP 与弹字。
  2. Godot 新增 `XImportedBalance`：`outgoing_rate(actor)`、禁用名单与禁用号角，只在 `execute_hp_damage`／MP 对应处、`sequence_gain`（负值）、反射与 DOT 入口按 `floor(value*rate)` 缩放，用一个「本次结算已缩放」标记防重复；禁用角色的行动整个跳过。
  3. 切片加 141、142、`xiyou_actor_p0` 招募表（CE 号要从 129 指令找）、`xiyou_rules*`／`xiyou_wtype` 难度段；`slice_probe` 的伤害行不含这个缩放，应同时核对「该角色的基线伤害行是否应带 ×0.01」（`power`／`rules` 测试对 141～166 的期望值要先从原版探针确认，不要沿用 B 类口径）。
  4. 与数值平衡文档「统一调整」的边界（预检 P3 已提）：先确认「导入倍率」与统一调整是叠乘还是替代。

## 建议的下一步分工

- 先做**共性前置**（对 108、141／142、错误数据 1741～1749 都有用）：状态效果阶段钩子＋转换器 js 再翻译；这一步是「改战斗核心流程」，应由总装安排独占 `battle_logic.gd` 的一条车道，并先确认 `damage.gd` 取整、sequence_gain 等同区域的改动都已合并。
- 再做 141／142（共享导入结算模块，一人，一期够）。
- 最后 108（依赖步骤 1～3，两期）。

## C 类接入流程小结（后续批量照搬）

1. **定类别**：`角色模板源索引_*.json` 的 `actors[].runtimeModuleCandidates` 与 `moduleEvidence` 给出候选模块；打开 `js/codex/runtime/<模块>.js` 与 `js/plugins/` 里对应插件，不要只信预检的一句话——奈叶预检写的是「击杀归属」，实际还有自定义 MP 消耗、战斗开始领域公共事件、AI 选择。
2. **逐项列依赖**：把角色职业所有 `learnings` 的技能备注扫一遍，列出 `<Custom …>`、`<Post-Damage Eval>`、`<Target Action>`、`StartPushState`（再看被附加的状态备注里的 `<Custom … Effect>`）、公共事件；Godot 现成支持什么用 `states[].effects[].op` 统计一眼可见（`mul` 已支持，`js` 未翻译）。
3. **按已有机制先试接**：加切片、招募表，跑 `slice_probe`／`xiyou_actor_p0`，看哪些用例失败，缺口直接定位；不要先写模块。
4. **需要新机制才动手**：先出 mv_oracle 参照探针（真实 BattleManager，固定 `Math.random`，只写 `.sandbox/`），再在共性代码里实现，保既有用例键不变（参照 dev.114／116：新角色不要抢旧 `why`／挑选角色逻辑）。
5. **常见坑**：①共享模块（如导入平衡 141～166）按「模块」而不是按「角色」建，一次覆盖多人；②`js` 状态效果不要因为一个角色全部翻译，先统计整库形状再归并；③参照探针里 `a.recoverAll()` 会让战斗快照读到「已回满」，Godot 侧要对应处理；④脚本错误会让 Godot 测试场景挂起到 600 秒超时，先用 `godot --headless --path … res://tests/x.tscn` 直接跑看输出；⑤`--accept-additions` 对「同键追加」不接受，新增用例要有区分键。
6. **验收**：同步 `--accept-additions` 一轮、内容覆盖检查、相关专项；全量交总装。

## 交接板

- 下一步：「待补角色」改记：108／141／142 已完成模块分析；先开「状态效果阶段钩子＋js 再翻译」共性车道，再做 141／142（导入平衡模块），最后 108。登记「全库约 500 条状态 js 效果未翻译」为已知缺口，并把 dev.116 变更记录里「Godot 没有 Custom Effect 机制」一句更正为「已有解析与 mul 翻译，其余 js 未翻译」。
- 用户试玩说明：无变化。
- 需要用户决定：无；建议总装安排上面的前置车道。

## 进度账

- 无变化。

## 检查

- 只改了交付单文档，没有改代码、切片、探针，没跑 Godot 测试与同步；`检查.sh` 的文档与登记段由总装合并后统一跑。

## 本分支提交

- 见 `git log main..HEAD`
