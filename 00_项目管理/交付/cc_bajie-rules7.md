# 交付：cc/bajie-rules7

- 车道／工作者：C 规则／八戒（cc，Sonnet／medium）
- 状态：进行中（云端选测结果待填；custom1b 合进 main 后需再 `git merge main` 一次）

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】混乱类状态（restriction 1～3）：愤怒／混乱／魅惑接进战斗（dev.待定）

背景：悟空 custom1 探针发现原版有 13 个状态（7、8、9、124、1045、1113、1567、1830、2046、2504、2505、2506、2580）restriction 为 1～3，重制只认 ≥4（不能行动），中了混乱的人照常出招。这轮先用探针量原版，再实现。

**参照探针** `mv_oracle/confusion_probe.cjs`（真实 BattleManager.processTurn；夹具 `tests/fixtures/confusion_oracle.json`，不进同步，53 例，运行约 90 秒）。量到的规则：

- 能行动（canMove 真，OTB 顺序照常）、不能输入（canInput 假：角色没有指令窗，OTB `startOTBInput` 直接 startAction）；状态回合行动结束 −1（3→2），与普通状态相同。
- **行动内容**：敌人 `Game_Action.prepare` 把行动换成普通攻击（行动选择的随机数照取，换在其后；预设技能 2、8 都被换成技能 1，不付 MP）。角色 `makeActions` 里是 `makeConfusionActions`（也是普通攻击），但**自动战斗优先**（`isAutoBattle`：挂机、自动战斗特性）：保留自动选的技能，`startOTBInput` 不走 prepare，只有目标走混乱。强制行动（forceAction）整个绕过混乱。
- **目标**（YEP_WeaponUnleash `makeConfusionTargets` 在最外层，Custom Target Eval 不走）：
  - 单体（scope 非 2／8／10，含随机、自己）：1 级＝对方随机一个；2 级＝掷 randomInt(2)，0 对方、1 己方，再在那一方随机一个；3 级＝己方随机一个。取随机数次数：1／2／1。
  - 全体（scope 2／8／10）：1 级＝对方全体存活；2 级＝掷 randomInt(2) 选一侧整侧存活；3 级＝己方全体存活。取随机数次数：0／1／0。
  - 随机一个按 tgr 加权，**只在存活者里挑**（扫了 8 个随机值 × 2 个后续值，各侧倒下 1 人，已倒下的人从不被选中）。
- 状态 7／2504 `removeByDamage`、chanceByDamage 50（受击解除）沿用通用状态逻辑，没单独测。

**实现**：
- 新模块 `core/confusion.gd`（`XConfusion`）：`level` 等级、`confused`、`prepare_enemy`（敌人行动换普攻）、`targets`（按等级和 scope 选目标）。
- `battle_logic.gd` 三处钩子：`targets_for` 加第 4 参数 `confusable := false`，execute 两条目标路径传 `not forcing`，带混乱时在原 `_targets_for` 位置换成 `XConfusion.targets`（其后的屠苏／异化／云裳／绑定／璇包装照旧套在外面）；`decide()` 敌人两个出口过一遍 `XConfusion.prepare_enemy`。**没碰 `_targets_for` 本体**（悟空 custom1b 在改它的开头）。
- `battle_scene.gd` `_command`：混乱角色跳过指令窗直接 `logic.decide`（挂机／自动战斗的分支在前，不受影响）。

**原版疑似缺陷（照原版做，没改）**：混乱（2 级）和魅惑（3 级）选己方一侧时，行动者自己也在候选里，会打到自己。

**没覆盖／没测（交接）**：
- 自动战斗选中防御（技能 2）时的混乱目标：重制 act 的防御分支不看目标，原版 makeTargets 仍走混乱，防御效果落点是否有差没量。
- 正式数据里每个技能都带 yepSeq，execute 的"普通路径"（无序列）实际不会遇到伤害技能，只在两条路径都加了同样的参数。
- 智能 AI 在混乱状态下的敌人选行动（`Codex_SmartBattleAI`）：prepare 之后都换成普攻，不影响结果，但选行动时消耗的随机数没逐项对。
- 动画画面：没有混乱状态的专属动作（原版 motion 1 的"异常"姿态在重制是否已有，没查）。

## 验证

- 专项 `xiyou_confusion`（新，367 项）：对照夹具——13 个状态的等级与可行动、7/8/9 × 敌我 × 低/中/高随机 × 无预设/预设技能的目标与取随机数次数、扫描（随机值×2、各侧倒下 1 人）、自动战斗保留技能下 scope 1/2/4/11 的目标、强制绕过、execute 全链打到的人与状态回合 3→2、decide 把敌人 8 号技能换成普攻。
- 反向验证（`反向验证.py`）：1 级改己方、2 级判断反向、全体范围去掉 scope 2、不滤死人、敌人不换普攻、序列路径不传 confusable、序列路径强制也混乱、decide 不换普攻——8 项全部咬住。
- `语法检查.py` 通过；`探针登记检查.py` 通过。
- 选测（`选测.py main --list`，battle_logic 命中 battle 档 209 个场景，>40 走云端选测）：见下方云端结果。

云端选测结果：（待填）

## 交接板

- 下一步：custom1b 合并后核对 `targets_for` 与 `_targets_for` 开头没有互相踩。
- 用户试玩说明：战斗里中了愤怒／混乱／魅惑的人（敌我都是）现在会只出普通攻击；混乱随机打敌我，魅惑打队友（可能包括自己），愤怒只打对方；角色不再弹指令窗。挂机时仍按自动战斗选技能，但目标按混乱。
- 需要用户决定：无

## 进度账

- 战斗规则对照：混乱类状态（原先缺项）→ 已对照，其余不变

## 待交叉核查

- `battle_logic.gd`（核心文件）：`targets_for`、`execute` 两处、`decide`；`battle_scene.gd` `_command`；新模块 `core/confusion.gd`。
- 重点核：(1) 自动战斗 + 混乱的组合是否应保留技能（探针里是用 isAutoBattle 重写模拟的，没有真开挂机）；(2) 敌人选行动的随机数先取后换普攻的顺序；(3) 夹具 53 例的序列设置（敌人 sweep 的第一个随机数被行动选择占用）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- afec7627 WIP: 混乱类状态（restriction 1～3）：探针、XConfusion 模块、钩子、专项
- 2f0c0531 Merge main
