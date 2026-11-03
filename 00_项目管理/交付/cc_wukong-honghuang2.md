# 交付：cc/wukong-honghuang2

- 车道／工作者：A 内容·楼层／悟空（cc，悟空 honghuang2，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】洪荒二期：判定口径、诅咒加成券、不朽存在权能掉落、洪荒压制、诅咒战斗效果（dev.待定）

- 判定：新 `XHonghuang.is_honghuang`（开关 2483 或 2463，不看难度），替换 `mv_script` 原来按 `difficulty != 8` 的判定。原版牢妲能单独切怪物难度，所以只切到难度 8、没开开关的不算洪荒；关了 2483 但 2463 还开着的仍算（探针 `gate.*`）。
- 发券：`grant_ticket_bonus` 加发 round(5×(倍率−1)) 张 1639；持有者是队伍里第一个学了诅咒的人，没有取队首；提示的 `toFixed(1)` 单独写 `_fixed1`（`String.num` 对 2.25 取偶，`snappedf` 把 4.05 进成 4.1，都和原版不一样）。
- 权能：`battle_logic` 开战记本场身份（`battle_started`，在 `setup` 里，任何战斗都覆盖，同原版 `BattleManager.setup`／`startBattle` 包装）、结束记胜负（`battle_ended`），`roll_power` 按开战时楼层的区段每本掷一次，概率 min(1, 0.03×倍率×熟练度倍数)，每战一次。身份不进存档，`_become_current` 清，`battle_replay` 回放后还原。CE1439 的头尾两句接上。
- 洪荒压制：CE1445 那段脚本整段认出，给全员有名字的角色记 `learn 10300`（actor op）；技能 ID 和 `sync_native_tier` 共用 `suppress_skill`。普查 `script_census_known.json` 删去这一条。
- 指引：`XGuide._power_line` 接上，修行页和里程碑在洪荒路线显示本段权能书与掉率。
- 诅咒战斗效果：15 种诅咒和 10300 逐个对原版量过（状态与回合、八维、xparam、sparam、敌人再动、普攻伤害）。标签和状态重制本来就认，只有状态 1270 死而复燃的脚本没翻译（`XStateEffects._revive`，15% 回 30% 血、回满蓝、TP 翻倍、清结果槽）；复活的这一击不算击杀（`battle_logic.apply` 里 `r.died` 改写）。
- 原版参照：`mv_oracle/honghuang_reward_probe.cjs`（44 例）、`mv_oracle/honghuang_curse_battle_probe.cjs`（20 例，关五乘区、随机固定），产物手工复制为 `tests/fixtures/honghuang_reward_oracle.json`、`honghuang_curse_battle_oracle.json`，不进同步。新测试 `xiyou_honghuang_reward`（311 项）、`xiyou_honghuang_curse_battle`（296 项）。
- 验证：见下方「验证」。
- 已知问题：7207（爆伤）、7211（爆率）、7213（元素伤害）三条只确认了重制认这些标签，原版参照没量到数值（普攻不暴击、不掉落、物理属性）；7203／7204 的多回合持续时间只量了开战那一刻的回合数。

## 交接板

- 下一步：洪荒二期完成；上面三条诅咒的数值参照如果要补，可以单开一小期（在探针里加一个暴击例、一个元素技能例、一个掉率例）。
- 用户试玩说明：开洪荒并选诅咒后，打不朽存在胜利会多给肝帝积分券，并有机会掉权能书；修行页和里程碑会显示掉率；开 2463 后全员造成的伤害×0.1；选了死而复燃的话，敌人倒下有 15% 复活。
- 需要用户决定：无。原版行为和交代的口径没有对不上的地方。提醒一句：洪荒压制×0.1 和诅咒减伤都照原版接了，但原版同时有五乘区修正，重制不移植（O-050），所以洪荒路线的实际难度和原版不完全一样，试玩时可以留意。

## 进度账

- 洪荒难度（CodexHonghuang）：诅咒选择 → 诅咒奖励、权能掉落、压制、战斗效果都已接上。

## 待交叉核查

- 改了核心文件：`battle_logic.gd`（开战、结束两处钩子；`apply` 里 `r.died` 一行）、`state_effects.gd`（`_revive`）、`xstate.gd`（`sync_native_tier` 改用共用查找、`_become_current` 清身份）、`battle_replay.gd`（还原身份）。请重点看 `_revive` 和 `r.died`：原版 clearResult 之后这一击不显示也不算击杀。

## 可优化（流程／工具／效率）

- 建议：状态 1270 现在在 `state_effects.gd` 里按 js 原文比对，没动转换器（省一轮同步）。以后再有要翻译的 js 块，可以把这种写法挪进 `xiyou_export.py` 变成正式 op，随下一次改转换器一起做。归哪条车道都行，收益不大。
- 建议：这轮 15 个场景排队等了约 20 分钟，并行测试在排队时如果管道给 `tail` 就完全没有输出，看起来像卡死。用 `长任务.py start` 加 `等待任务.sh` 能看到「等槽」进度，车道须知已写，这里只是再踩一次。

## 验证

- `语法检查.py`：通过。
- 选测 `选测.py main --list` 列出 301 个场景，没有全跑（车道不跑全量）。跑了与改动直接相关的 16 个，全部通过：`xiyou_honghuang_reward` 311、`xiyou_honghuang_curse` 885、`xiyou_honghuang_curse_battle` 296、`xiyou_determinism` 372、`xiyou_guide` 63、`xiyou_battle` 9、`xiyou_difficulty_inherit` 6120、`xiyou_dungeon` 6954、`xiyou_zhenqi` 181、`xiyou_state_js` 1733、`xiyou_start_state_walk` 385、`xiyou_reward_branches`、`xiyou_yunshang_wraps` 214、`xiyou_floor_abyss211` 28、`xiyou_event_compare` 5、`xiyou_script_census`。
- 没跑 `xiyou_rules*` 等其余战斗核心类场景：本次对 `battle_logic.gd` 只加了不取随机数的钩子和 `r.died`，`state_effects.gd` 只多一个只对状态 1270 生效的分支；请总装合并时按影响面选测。
- 第一轮后改过 `guide.gd`（`seg.power` 为空时报错，已修）和两个新测试，这几个场景又单独跑过一次；`xiyou_determinism` 没有在修改后重跑，因为改动没碰战斗代码。
- 没开游戏实际玩过，界面上的提示只验证了文字。
- 没跑 `反向验证.py`。

## 本分支提交

- 2f12744c WIP：口径调查与探针
- 56e7a54b WIP：判定、发券、权能、压制、指引、诅咒战斗参照与死而复燃
- （本提交）交付：洪荒二期
