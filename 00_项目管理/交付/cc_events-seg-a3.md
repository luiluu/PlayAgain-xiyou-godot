# 交付：cc/events-seg-a3

- 车道／工作者：A 内容·地图事件对照分段甲三期（等级上限、角色门忘技能、脚本造选单）／cc（分段甲）
- 状态：**可合并**
- 分支从 cc/events-seg-a2 末端（bc1ae072）切出，已合 main（b445a3fe，dev.420）；`event_presets.json` 冲突以 main 为准、末尾追加本分支的 sa3 变体，note 补了 forget／maxLevel。
- **改了 `event_state_probe.cjs`：合并后事件状态探针指纹全变，整份重量（本机 2 段约 2 小时 50 分）。** 本工作树 `03_转换工具/mv_oracle/.sandbox/event_states*.json` 已是新探针量的整份（23988 例），总装合并时可直接拷进主工作区，免得再整份重量；其他车道合并后补齐时 `新建工作树.sh --补齐` 会提示要 `--confirm-full`，先从主工作区拷 `.sandbox/event_states*.json`。

## 变更记录草稿

## 2026-11-09 【cc·分段甲·未经审查】事件对照分段甲三期：预设键等级上限 maxLevel 与忘技能 actors.N.forget，ce1442 脚本选单 15 个变体，sa3 祖先链 39 个变体（dev.待定）

- **`maxLevel`**（探针 `event_state_probe.cjs` 与 `tests/xiyou_event_compare.gd` 同加，进 PRESET_KEYS）：同插件指令「maxlevel equal N」——参照设 `$gameParty.ActorMaxLevel` 与全部 `$dataActors[i].maxLevel`（每例由开局快照换回），重制设 `XState.actor_max_level`；在角色等级之前摆。`事件祖先预设.trace_var` 的「变量＝角色等级」一支在等级超过开局上限 10（YEP_CoreEngine Max Level）时同时出 `maxLevel`。合并预设时取大。
- **`actors.N.forget`**（两边同加）：在 skills 之后 forgetSkill／forget_skill。`事件写法覆盖.open_preset` 的「否则（角色没学会技能）」从空预设改成 `forget: [技能]`；`_finish` 里同一技能既学又忘的记为开不了的门。
- **脚本造选单**：只有 ce1442 洪荒诅咒用 `$gameMessage.setChoices`（全源扫过）。探针 `msg()` 本来就按 answers 应答任何选单，不用改探针；`sa3_hh1～14` 按「第 k 次选到 ((j+3k) mod 15)+1」造，覆盖后发现选项号是剩余列表的下标、不是诅咒号，位置 2～5 各缺一个值（1469＝4、1470＝7、1471＝10、1472＝13），补 `sa3_hh15`（answers [0,2,4,6,8]＝选 1、4、7、10、13）。现在 ce1442 的 76 个条件分支全进过，570 条指令里没执行到的只剩结构行。
- **ce1442 的 70 个 `w8_*` 冗余但保留**：它们直接设 1468～1472，被第 40 条脚本覆盖，旧探针结果和 `s1` 逐项一致（trace、reached 相同，变量终值相同）。本来删了（e7c6cf50），总装合并时同步拒收「删除既有参照用例」（oracle_additions 只在换源时接受删除），已 revert（e7c269d6），**换源时再删**。
- **sa3 祖先链变体**：整份对照覆盖（29907 例）→ `事件写法覆盖 --missed` 1303 簇 → `事件祖先预设 --tag sa3` 出 185 个，只留预设带 `forget` 或 `maxLevel` 的 40 个，量完对照 41／41 一致，剪掉目标仍没执行到的 1 个（ce2500#sa3_28），留 39 个：ce2500 锻炼链 9、m4e49p1 9、m4e49p2 8、m4e74p0 5、m67e2p2 4、ce2495／m67e2p0／m146e6p0／ce1685 各 1。
- 顺手：`测试事件探针分段.py` 的 `--force` 提示用例 mock 掉 `changed_probe_files`，不然在改过探针的分支里被「相对 main 改过」守卫提前返回而误红。

## 本分支提交

- 26f32cea：预设键 maxLevel、actors.N.forget，开门生成跟上。
- c2dd7dff：ce1442 sa3_hh 14 个变体。
- e7c6cf50：删 ce1442 的 70 个 w8_*；e7c269d6 revert 回来（同步不收删除既有用例）。
- bc6d2767：sa3_hh15、sa3 祖先链 39 个变体。
- 7cd4cb91：测试事件探针分段 --force 用例不受守卫影响。
- 合 main 三次（最后一次 b445a3fe，均无冲突外的改动；event_presets 冲突解法同上）。

## 验证

- 事件状态探针整份重量（新探针，`XIYOU_STATE_SHARDS=2 XIYOU_CONFIRM_FULL=1 新建工作树.sh --补齐`，11-09 02:37～05:25，reused 0）；之后两次增量补跑（reused 11974／11994 每段，约 2 分钟）。
- `xiyou_event_compare` 整份 `--coverage`：29907 例，一致 29899，不一致 8 例均在基线内，regressions 0。`--only` 新变体 41 例全一致；`--only=ce1442` 16 例全一致。
- 恢复 w8_* 后（11-09 07:43）增量补跑：`XIYOU_STATE_SHARDS=2 补跑事件状态探针.py --confirm-full`（守卫只看探针相对 main 有差异，本树 .sandbox 已是新探针量的，实际增量），每段 reused 11994、共 24058 例（＝23988＋70），2 分 15 秒；`xiyou_event_compare --only=ce1442` 87 例全一致。
- `事件空绿扫描.py --check`：空绿 92 例均在基线内（另提示 ce1604 已补上、可 `--update-baseline`，没动基线，留给总装）。
- `测试事件探针分段.py` 33 例通过（含 PRESET_KEYS 两边比对）；`工具回归.py` 通过；`语法检查.py` 658 个 .gd 0 问题。
- 选测：`选测.py main` 因改了探针结论是整轮；本分支只动事件预设与事件状态探针（只产出 event_states.json），跑了 xiyou_event_compare 四段＋引用它的 25 个场景，共 29 个，合 main（b445a3fe）后在本树跑，**全部通过**（551 秒，并行 2；`--skip-generated-check`，因为本树 event_states.json 是新探针量的、本来就跟主工作区不同）。没跑整轮里其他战斗核心场景，理由：探针与预设不进战斗数据。

- 用户试玩说明：无
- 需要用户决定：无

## 优化登记草稿

优化登记草稿：无（没改游戏行为）

## 可优化（流程／工具／效率）

- 建议：`选测.py` 对 `event_state_probe.cjs`、`event_presets.json` 归到 converter 组、给出整轮；它们只产出 `generated/oracle/event_states.json`，可单列一组只选 `xiyou_event_compare*` 与引用它的场景（归工具车道）。
- 建议：`合并车道.py` 准备阶段就查 event_presets／参照用例有没有删除既有键（同 oracle_additions 的 switchOnly 判法），在派单方一侧早报，别等同步才整轮拒收（本次 e7c6cf50 就是到同步才发现）。
- `事件空绿扫描 --check` 提示 ce1604 可更新基线，总装合并时顺手 `--update-baseline`。
