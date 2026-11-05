# 交付：cc/bajie-rules11

- 车道／工作者：C 规则／八戒（cc，派单第七批 AO）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】两个 Apply 类 TP 块查清：早已正确，测试改核正式数据并补开战端到端（dev.待定）

- **是哪两块**：状态 1334、1336「横霸千峰」的 `<Custom Apply Effect> user.gainTp(25)／(75)`。挂法：技能 7499／7516 备注 `<StartPushState1334／1336: 100%>`，dsPassiveSkill `Scene_Battle.start`（initTp 之后）给自己加状态，YEP_BuffsStatesCore `customEffectEval(…,'addState')` 里 `user = this`（持有者），于是持有者加 TP。dev.201 起各期核定都把它列为「两个 Apply 类 TP 块未做」，交接板归档 rules1b 盘点又写「已做完、由 production.apply 锁着」，两种说法都只说对一半。
- **实际情况**：转换器早已把两块译成 `gain_steps`（资源 tp，常数 25／75，走 `XResourceContext.gain`），开战路径 `XBattleLogic._battle_start_states` → `_state_add` → Apply 也接通了；但 `xiyou_state_effects_tp` 比参照前，会先把这两块临时换成 `gain_resource` 替身（文件头注释还写着「production Apply stays JS」），正式那段从没和原版比过，只核了「op 是 gain_steps」。
- **本期**：去掉替身，矩阵（native／reapply／guarded_apply／custom caps／refresh boundary，共用 `state_effects_tp_context_probe` 参照）直接跑正式数据，全过；`production.apply` 改核整条效果的形状（单条 apply、gain_steps、一步、资源 tp）。新增 `start_push_tp`：学了 7499／7516 的角色开战后挂上 1334／1336、TP＝initTp（替身固定 12）＋25／75，同队另一人不受影响。反向验证：把 `_gain_steps` 的加值乘 0，native.*、journal 等成批红（换替身时这条改动测不出来）。
- 没改游戏代码，不用回退开关。

## 交接板

- 下一步：战斗节「两个 Apply 类 TP 块」可以从仍缺里删掉。
- 用户试玩说明：无变化（原本就对）。
- 需要用户决定：无

## 进度账

- 战斗规则与画面：这一项本来就做了，本期只是补上测试，建议不另加分，「仍缺」里删掉这一条即可。由审查核定。

## 可优化（流程／工具／效率）

- 建议：核定报告的「仍缺」能不能每条附一个 rg 或测试名作为依据，免得同一条缺口挂好几期（这两块从 dev.201 挂到 dev.355）。归审查线程。

## 验证

- 专项：`xiyou_state_effects_tp` 544 项全过（原 538 项＋开战 6 项）；`语法检查.py` 通过；`未翻译块清单.py` 里没有 1334／1336。
- 选测：`选测.py main --list` 只选中 `xiyou_state_effects_tp` 一个（只改了测试），本机已跑过；`工具回归.py` 通过。分支从 e9c52d60（合并 fix6，收尾提交还没到）切出：本分支只改一个测试，收尾提交不会碰到它，就没再等着合 main。

## 待交叉核查

- 只改了测试 `tests/xiyou_state_effects_tp.gd`。请核 `start_push_tp` 的期望（initTp 之后加，封顶 max_tp）。

## 本分支提交

- d9fd5129 两个 Apply 类 TP 块改用正式数据比参照，补开战端到端
- （本提交）交付单可合并
