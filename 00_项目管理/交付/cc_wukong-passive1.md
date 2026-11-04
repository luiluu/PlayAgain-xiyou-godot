# 交付：cc/wukong-passive1

- 车道／工作者：A 内容／悟空（cc，Sonnet）；从 cc/wukong-dot2 头起（dot2 已合并 main）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】passive1：dsPassiveSkill 三处补齐（passiveGUARD、passiveXPBSTEX、PBSTEX 的 TP 条件）（dev.待定）

背景：dot2 细查列出的真缺。新探针 `mv_oracle/passive_probe.cjs`（产物 `passive.json`，3 个用例，原版报错放 `sourceErrors`，已登记 PROBES／oracle_additions）先量原版，再实现，专项 `xiyou_passive`（255 项）逐行对照。

- **passiveGUARD（技能 10089 苍龙*破晓）**：原版 `Game_Actor.isGuard` 在插件里被包成「基础结果 或 有 passiveGUARD」，所以学会它的角色**一直处于防御**：战斗里外 `isGuard` 都真，**不看能不能行动**（挂不能行动状态也真），受伤折减 ÷(2×grd)——同一击 16→8（grd 1），战斗里一直摆防御姿势。重制：`XBattler.is_guard()`（默认读 `guarding`），`XActor.is_guard()` 加 passiveGUARD；`damage.gd` 防御折减、`battle_logic.gd` 的 view `guarding`、`battler_sprite.gd` 姿势改读 `is_guard()`。防御指令照旧。
- **passiveXPBSTEX（技能 968 妖精匕首类：`EX2:20,HPUP,40`；3886 溢满：`EX9:50,MPUP,100`）**：原版 `xparam` 里条件满足才加：968＝HP 比例 ≥40% 时暴击率 +0.20；3886＝MP 满（≥100%）时 TP 回复率 +0.50，差一点（0.99）不加；战斗里外一致，两个叠加互不影响。重制：`actor.gd xparam` 在 passiveXPBST 之后按同条件加。
- **顺带查出的同类缺口：passivePBSTEX 的 TPUP／TPLW 条件**（技能 3219、4924、4925 的 `passivePBSTEX2:50%,TPUP,100`）：原版 `evaluateCondition` 有 TPUP／TPLW，重制 `_condition` 只有 HP／MP，所以这三个技能的「TP 满时攻击 +50%」一直不生效。量过：TP 满（200/200）攻击 47→62（+15＝基础攻击的 50% 取整），差 2 点（198）不加。已补 `TPUP／TPLW`（TP 比例＝tp/maxTp）。这条是玩法数值修正，让玩家变强（TP 满时攻击 +50%），按原版，不需要用户决定。

**没有新优化，不占优化号**（全部按原版测量实现）。

## 交接板

- 下一步：先制／偷袭整套（含 passivePREE／ASUP）、SvPngFd、SV 敌人画面细节（见 cc_wukong-dot2 的细查结论，已随 dot2 并入变更记录）仍待总装定。
- 用户试玩说明：苍龙学会「苍龙*破晓」后受到的伤害减半（防御状态，战斗里摆防御姿势）；妖精匕首类（968）HP≥40% 暴击率 +20%、溢满（3886）MP 满时 TP 回复 +50%；3219／4924／4925 的 TP 满时攻击 +50% 现在生效。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 待交叉核查（改了核心文件）

- `modes/xiyou/core/damage.gd`：防御折减读 `is_guard()`（原 `guarding`）。
- `modes/xiyou/battle/battle_logic.gd`：view 的 `guarding` 读 `is_guard()`。
- 另改 `core/battler.gd`（新 `is_guard`）、`core/actor.gd`（`is_guard`、`xparam` 加 XPBSTEX、`_condition` 加 TP）、`battle/battler_sprite.gd`（姿势）。

## 验证

- 专项 `xiyou_passive`（新，255 项，对照 passive.json）通过；`语法检查.py`、`探针登记检查.py` 通过。
- 选测名单：`选测.py main --list` 约 257 个场景（含战斗核心 xiyou_determinism），走云端选测；同步与云端结果见末尾。
- 没做反向验证（`反向验证.py`）：断言逐行对照原版测量，学了／没学、条件边界（0.39／0.40、0.99／1）都在里面，实现去掉任一块都会失败。

## 本分支提交

- 3feb651c passive1：三处补齐＋探针＋专项
- 本期：交付单

## 云端结果

- 合 main（头 f748c69a）后重跑 `新建工作树.sh --补齐`，`同步正式西游.py --accept-additions` 退出码 0（passive_probe 新增用例已接受；第一次同步因没合最新 main 报 dot.json 错误字段，合并后通过）。
- 云端选测（258 个场景、7 片，基准 fc7d88f33a，提交 b32ba7099d）：通过，<https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41865550893>。
