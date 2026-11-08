# 交付：cc/events-seg-a3

- 车道／工作者：A 内容·地图事件对照分段甲三期（等级上限、角色门忘技能、脚本造选单）／cc（分段甲）
- 状态：**WIP，未完成，不可合并**（11-08 晚 Kyo 换账号，交接见「接续」）
- 分支从 cc/events-seg-a2 末端（bc1ae072）切出，已合 main（c2295516，seg-a、seg-a2 已在 main 里）；`event_presets.json` 合并冲突已解：以 main 为准，末尾追加本分支 `sa3_hh*` 14 条，note 补了 forget／maxLevel。
- **改了 `event_state_probe.cjs`：合并后事件状态探针指纹全变，整份重量（3 小时级）；其他车道合并后要重新拿底子（补齐／同步时会整份重跑，先跟总装约槽，`XIYOU_STATE_SHARDS=2`）。**

## 变更记录草稿

## 2026-11-08 【cc·分段甲·未经审查】事件对照分段甲三期：预设键等级上限 maxLevel 与忘技能 actors.N.forget，ce1442 脚本选单 14 个变体（dev.待定）

- **`maxLevel`**（探针 `event_state_probe.cjs` 与 `tests/xiyou_event_compare.gd` 同加，进 PRESET_KEYS）：同插件指令「maxlevel equal N」——参照设 `$gameParty.ActorMaxLevel` 与全部 `$dataActors[i].maxLevel`（每例由开局快照换回），重制设 `XState.actor_max_level`；在角色等级之前摆。`事件祖先预设.trace_var` 的「变量＝角色等级」一支在等级超过开局上限 10（YEP_CoreEngine Max Level）时同时出 `maxLevel`（m4e49 45 级以上、m4e74）。合并预设时取大。
- **`actors.N.forget`**（两边同加）：在 skills 之后 forgetSkill／forget_skill。`事件写法覆盖.open_preset` 的「否则（角色没学会技能）」从空预设改成 `forget: [技能]`（ce2495 三笠锻炼链等：角色开局就会前一级技能，否则分支进不去）；`_finish` 里同一技能既学又忘的记为开不了的门。
- **脚本造选单**：只有 ce1442 洪荒诅咒用 `$gameMessage.setChoices`（全源扫过）。探针 `msg()` 本来就按 answers 应答任何选单、重制 `mv_script._honghuang_curse` 也走宿主选单，**不用改探针**；按应答造 `sa3_hh1～14`（第 k 次选到 ((j+3k) mod 15)+1，5 个位置都取遍 1～15，j=0 即默认应答已由 s1 覆盖）。

## 接续（下一位做）

1. ✓ 整份重测（新探针）11-08 03:44 起、约 90 分钟跑完，结果在本工作树 `mv_oracle/.sandbox/event_states.json`（未入 Git）。
2. ✱ 合 main 后再补齐（`XIYOU_STATE_SHARDS=2`，经 长任务.py，日志 `04_验证/本地结果/补齐2_seg-a3.log`）：增量补跑 main 新预设＋`sa3_hh*`，交接时已跑 25 分钟、0/2 段完成，让它跑完；接手的先 `等待任务.sh <日志> --timeout 540` 看结果（看探针输出的 reused 数，确认是增量不是整份）。工作树：`.claude/worktrees/cool-dirac-af471d`；换了机器／工作树就在自己的树里 `新建工作树.sh --补齐 <路径> --branch <新名> --from cc/events-seg-a3`，那时探针会整份重量，先跟总装约槽。
3. ce1442：`xiyou_event_compare` 跑 `--only=ce1442#sa3_hh`（Godot：`07_开发环境/godot --headless --path 01_Godot工程 res://tests/xiyou_event_compare.tscn -- --only=… --coverage=<文件>`，外包 `占槽.py`），看 5 个位置 75 个分支是否都执行到、两边一致。
4. ce1442 的 70 个 `w8_*` 变体直接设 1468～1472，会被第 40 条脚本覆盖，结果应与 `s1` 相同；确认 delta、trace 与 s1 一样后删掉。
5. 整份 `xiyou_event_compare --coverage`（1 槽）→ `事件写法覆盖.py --coverage <文件> --missed <键> --missed-json 簇.json` → `事件祖先预设.py --missed-json 簇.json --tag sa3 --targets 目标.json`，只留链上带 `forget` 或 `maxLevel` 的新变体（ce2495 锻炼链、m4e49 45 级以上、m4e74），先抽样试点再放大；增量探针（SHARDS=2）、对照、`--prune --tag sa3 --targets 目标.json --states .sandbox/event_states.json`。
6. `事件空绿扫描.py --check`、`工具回归.py`、`测试事件探针分段.py`（比对两边 PRESET_KEYS）；写变更记录草稿的数字、「验证」，状态改「可合并」。

- 用户试玩说明：无
- 需要用户决定：无

## 优化登记草稿

优化登记草稿：无（没改游戏行为）

## 可优化（流程／工具／效率）

- 建议：`新建工作树.sh --补齐` 会顺带跑事件状态探针（默认 4 段占 4 槽）；工作树里探针已改时它会整份重量。可让补齐在探针相对 main 有改动时不自动跑探针、只提示（归工具车道）。本期教训：先补齐、再改探针。

## 本分支提交

- 26f32cea：预设键 maxLevel、actors.N.forget，开门生成跟上。
- c2dd7dff：ce1442 sa3_hh 14 个变体。
- 合 main（c2295516），解 event_presets 冲突。

## 验证

- `node --check`、`py_compile`、`语法检查.py`（654 个 .gd，0 问题）。
- 探针整份重测：跑完（约 90 分钟，4 段）。合 main 后增量补跑进行中（接续 2）。其余未跑。
