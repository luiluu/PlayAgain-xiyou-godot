# 交付：cc/bajie-relic3

- 车道／工作者：C 规则／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu2b 末端 6cd1f05f 切（总装十派），工作树 `.claude/worktrees/pensive-ardinghelli-6b5eb0`。guyu2a、guyu2b 还没进 main，合本分支会一起带进来。

## 做到哪

- ✓ 三法宝成长里切片用得上的部分：百谷生 7912 在谷雨 60 级进化。
- 没做（不在切片或只是显示）：屠苏 176 止戈环 4047、璇 177 璇玑星盘 4048 的进化与五相／列星特效（两位角色不在切片，`rg` 过重制没有）；说明卡里法宝条目的改写（relicLines，只是显示）；传家宝品质整理 RQ.normalize（原表这 18 件本来就是品质 9，只对随机前缀改了品质的实例有用）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】三法宝成长：百谷生 60 级进化成万象长春盏（dev.待定）

1. **XThreeGrowth**（冻结 v0.28 `installThreeGrowthRelicRuntime.js` 的 R.syncItem，W.CodexThreeGrowth v0.4.0）：新文件 `modes/xiyou/core/three_growth.gd`。谷雨 60 级时百谷生进化：每级成长由 18（生命、物防、魔防、速度四项 36）改为 36（72），改名「万象长春盏」，说明换成进化后的那句；进化一次后不退（实例记 `_codex60Evolved`，人物降回 60 级以下也不变）；没进化时说明也改成原版那句。原版在 changeLevel／levelUp／changeEquip／startBattle／读档／算法宝能力时同步，重制在 `XActor.magic_param`（算法宝能力）时同步，名字与说明跟着变。
   - 这就是上期记下的「60 级 5 阶谷雨戴百谷生，最大生命原版多 47」：原版进化后法宝 1 级每级生命多 36，乘百谷生的生命 ×1.3。
2. **谷雨归春例改回真戴法宝**：`guyu_battle_probe` 的 relic 例去掉测试开关 G.setTestRelic，改成招募时装上百谷生；`xiyou_guyu_battle` 照样全过。`XGuyu.test_relic` 留着（对应原版的 G.setTestRelic），专项不再用。
3. **参照与专项**：新探针 `mv_oracle/three_growth_probe.cjs`（9 例：谷雨 1／59／60／70 级 × 法宝 1／10 级，再加 60 级进化后降回 50 级），登记进 `同步正式西游.py` 的 PROBES 与 `oracle_additions.py`；新专项 `xiyou_three_growth`（逐例比八项能力、法宝名、说明、每级成长、进化标记）。
   - 反向验证（临时改代码，已还原）：进化后不翻倍时 60、70 级四例的能力与每级成长都对不上；去掉「进化后不退」时降回 50 级那例的名字、说明、能力、成长都对不上。专项里常驻：别的法宝不归这里管、没有谷雨时不进化。

## 发现的原版问题

- **O-待定（建议登记，重制不重现）**：原版刚招募、生成百谷生实例时，第一次同步按「旧版倍率」去重（实例备注认不出「额外四项」这几个字），结果生命 ×1.3、物防 ×1.2 两条特性各重复一条，生命按 ×1.6、物防按 ×1.4 算；之后改过人物等级或法宝等级，CP_MagicWeapon 重算时才恢复正常。参照 `relic.lv1.r1` 量到了（rates 字段有五条）。重制的实例不改特性，一直是正常的三条；专项里这一例只比其余六项，另断言重制的生命、物防比原版低。这是只在招募后、改等级前的短暂状态，要做回退开关得模拟 CP_MagicWeapon 重算特性的时机，所以没做开关。请总装登记，由 Kyo 定要不要重现。

## 交接板

- 下一步：屠苏、璇进切片时再接两件法宝的进化与特效；法宝说明卡条目改写归界面车道。
- 用户试玩说明：谷雨到 60 级时，百谷生会变成「万象长春盏」，每级成长翻倍。
- 需要用户决定：上面那条 O-待定（原版刚招募时百谷生倍率重复，重制不重现）。

## 进度账

- 三法宝成长：未移植 → 百谷生进化部分完成（屠苏、璇不在切片）。

## 验证

- 专项：`xiyou_three_growth` 全过（新）；`xiyou_guyu_battle` 1523/1523（relic 例改回真戴百谷生）。反向验证见变更记录草稿。
- 选测（本机 CHECK_JOBS=3，`RULES_ONLY_ACTORS=175`，33 个场景全过，用时 1969 秒）：`xiyou_guyu`、`xiyou_guyu_battle`、`xiyou_three_growth`、`xiyou_magic_weapon`、`xiyou_magic_weapon_level`、`xiyou_actor_p0`、`xiyou_actor_modules`、`xiyou_help_card`、`xiyou_wtype`、`xiyou_rules*`（24 份）。三件法宝的持有者里只有谷雨在切片，谷雨的战斗专项就是 `xiyou_guyu_battle`。
- 同步（一轮）`同步正式西游.py --accept-additions`：重跑 three_growth_probe 与 guyu_battle_probe，「测量不变」（本树参照已是新的），来源核对 0 问题。main 上合并时 three_growth.json、guyu_battle.json 算新增。
- `语法检查.py` 通过；没有偶发。没合 main（等总装通知）。

## 待交叉核查

- 甲档：`core/three_growth.gd`；`core/actor.gd` 的 magic_param 一行。
- 乙档：无。
- 丙档：`three_growth_probe.cjs`、`xiyou_three_growth`、`guyu_battle_probe` 的 relic 例、`xiyou_guyu_battle`。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | XThreeGrowth（百谷生 7912 实例） | 招募生成实例时第一次同步按旧版倍率去重（备注认不出「额外四项」），生命 ×1.3、物防 ×1.2 各重复一条，生命按 ×1.6、物防按 ×1.4 算，改过人物等级或法宝等级后 CP_MagicWeapon 重算才恢复 | 重制不重现：实例特性一直是原表三条 | 只是招募后、改等级前的短暂错算，原版自己改等级就恢复 | 无开关（要模拟 CP_MagicWeapon 重算特性的时机）；参照 three_growth_probe 的 relic.lv1.r1 量着原版行为 | cc（八戒） | 待 Kyo 定（重制不重现、无开关） |

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 4f8aaa0b WIP：探针、XThreeGrowth、钩子、专项；谷雨归春例改回真戴
- 73fc936f WIP：交付单草稿、选测
- 交付单可合并（本提交）
