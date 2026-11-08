# 交付：cc/events-seg-a3

- 车道／工作者：A 内容·地图事件对照分段甲三期（等级上限、角色门忘技能、脚本造选单）／cc（分段甲）
- 状态：**WIP，未完成，不可合并**（周额度 96%，总装叫停；交接见「接续」）
- 分支从 cc/events-seg-a2 末端（bc1ae072）切出，已合 main（ef489a59）。先合 cc/events-seg-a、cc/events-seg-a2，再合本分支。
- **改了 `event_state_probe.cjs`：合并后事件状态探针指纹全变，整份重量（3 小时级）；其他车道合并后要重新拿底子（补齐／同步时会整份重跑，先跟总装约槽，`XIYOU_STATE_SHARDS=2`）。**

## 变更记录草稿

## 2026-11-08 【cc·分段甲·未经审查】事件对照分段甲三期：预设键等级上限 maxLevel 与忘技能 actors.N.forget，ce1442 脚本选单 14 个变体（dev.待定）

- **`maxLevel`**（探针 `event_state_probe.cjs` 与 `tests/xiyou_event_compare.gd` 同加，进 PRESET_KEYS）：同插件指令「maxlevel equal N」——参照设 `$gameParty.ActorMaxLevel` 与全部 `$dataActors[i].maxLevel`（每例由开局快照换回），重制设 `XState.actor_max_level`；在角色等级之前摆。`事件祖先预设.trace_var` 的「变量＝角色等级」一支在等级超过开局上限 10（YEP_CoreEngine Max Level）时同时出 `maxLevel`（m4e49 45 级以上、m4e74）。合并预设时取大。
- **`actors.N.forget`**（两边同加）：在 skills 之后 forgetSkill／forget_skill。`事件写法覆盖.open_preset` 的「否则（角色没学会技能）」从空预设改成 `forget: [技能]`（ce2495 三笠锻炼链等：角色开局就会前一级技能，否则分支进不去）；`_finish` 里同一技能既学又忘的记为开不了的门。
- **脚本造选单**：只有 ce1442 洪荒诅咒用 `$gameMessage.setChoices`（全源扫过）。探针 `msg()` 本来就按 answers 应答任何选单、重制 `mv_script._honghuang_curse` 也走宿主选单，**不用改探针**；按应答造 `sa3_hh1～14`（第 k 次选到 ((j+3k) mod 15)+1，5 个位置都取遍 1～15，j=0 即默认应答已由 s1 覆盖）。

## 接续（下一位做）

1. 整份重测：补齐（`新建工作树.sh --补齐`）时自带的事件状态探针已按新探针起跑（4 段，各占 1 槽；本机 auto 模式拦了 kill，没能改 2 段）。日志 `04_验证/本地结果/补齐_seg-a3.log`（工作树根下，未入 Git）。跑完后补齐继续做 godot --import。**若中途被停，下次先跟总装约槽，`XIYOU_STATE_SHARDS=2` 重跑。**
2. 跑完后：增量补跑新加的 `ce1442#sa3_hh*`（14 个），`xiyou_event_compare --only=ce1442#sa3_hh --coverage` 看 5 个位置 75 个分支是否都执行到。
3. ce1442 的 70 个 `w8_*` 变体直接设 1468～1472，会被第 40 条脚本覆盖，结果应与 `s1` 相同；确认 delta、trace 与 s1 一样后删掉（本期没删）。
4. 整份 `xiyou_event_compare --coverage` → `事件写法覆盖.py --missed` → `事件祖先预设.py --missed-json … --tag sa3`，只留链上带 `forget` 或 `maxLevel` 的新变体，先抽样试点再放大；增量探针、对照、`--prune`。
5. `事件空绿扫描.py --check`、`工具回归.py`、`测试事件探针分段.py`（它比对两边 PRESET_KEYS）。

- 用户试玩说明：无
- 需要用户决定：无

## 优化登记草稿

优化登记草稿：无（没改游戏行为）

## 可优化（流程／工具／效率）

- 建议：`新建工作树.sh --补齐` 会顺带跑事件状态探针（默认 4 段占 4 槽）；工作树里探针已改时它会整份重量。可让补齐在探针相对 main 有改动时不自动跑探针、只提示（归工具车道）。本期教训：先补齐、再改探针。

## 本分支提交

- 26f32cea：预设键 maxLevel、actors.N.forget，开门生成跟上。
- ce1442 sa3_hh 14 个变体（WIP 提交）。

## 验证

- `node --check`、`py_compile`、`语法检查.py`（654 个 .gd，0 问题）。
- 探针整份重测：进行中（见接续 1）。其余未跑。
