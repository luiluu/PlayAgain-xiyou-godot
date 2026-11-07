# 交付：cc/ui-newsrc1（换源集成分支·界面失败表）

- 车道／工作者：界面（cc）；总装派单：集成分支 run 42343228257 界面四个场景，修好交回集成分支（**不进 main**）
- 基于：cc/newsrc-switch 3948463f
- 状态：**可合并进集成分支**（不进 main）

## 场景 → 用例 → 根因 → 修法

- **xiyou_zhenqi** → `page.default`／`qi2000`／`capped`／`canBreak`／`hard.f20`／`daozu` → **原版 bug，重制多显示了一段**：重制「修行·详细」末尾多出「高阶词条概率」一段（XAffixRate.detail_rows），新源参照没有。查原版：`installAffixDifficultyRateRuntime` 在 main.js 第 201 行包装 `G.detailRows`，但「修行·详细」窗口在第 160 行装引导模块时，已经由 `panelWindow(JAH_Window_Status_ZhenqiDetail, G.detailRows)` 把没包装的函数抓走了，所以这段包装到不了页面，v0.62.12 实机和 zhenqi_probe 都没有这一段。作者本意是要显示的（方案 v0.3「修行页末尾加一段」）。修法：按规矩修好、留开关。`XAffixRate.DETAIL_SHOWN`（O-待定·高阶词条概率页）默认 true 显示；false 照原版不显示。测试里 `page.*` 用 false 和原版逐行比；新加 `page.affix_section` 断言开着时页末多出这一段，其余各行与原版相同。本机用 v0.62.12 重跑 zhenqi_probe（24 分钟）对照，201/201。
- **xiyou_item_bag** → `tp.consumable.menu`＝null → **测试前提**：新源大厅 Map4 的 EV76 是首次进入时自动播的漩涡过场（`CodexWhisper.seen('rift1')` 为假才播），过场期间地图 busy，开菜单被忽略。本机能过，是因为本机开发档的 options.json 里已经记过 rift1（这个测试原来没设配置目录，用的是开发档）；云端是全新配置，所以挂。修法：测试改用自己的存档／配置目录，先 `XConfig.whisper_mark("rift1")`，写法同 casino_batch、floor_reach041、actor_p0。清掉配置目录后本机能复现，修后 160/160。
- **xiyou_hangup** → `no_enemy` → 根因同上：过场占住大厅，按挂机键被忽略，`map.busy` 一直为真。本机能过，是因为上一轮留下的 `test_xiyou_hangup/options.json` 已经记了 rift1。修法：同上标记看过。删掉测试目录后能复现，修后 31/31。另外加了「等地图就绪再按」的循环。
- **xiyou_hangup_options** → `options_list`、`prohibited_no_hangup` → **测试写死了行数**：设置页「Boss状态面板」那一行随 `XBossStatusPanel.TOGGLE` 出现。main 上默认关，33 行；集成分支已翻成开（O-204），34 行。修法：断言改成 33／32 加上 `TOGGLE` 带来的那一行，失败时打印实际列表。不是挂机改动接不上（派单里猜的 input1 TIP_WORD 无关）。57/57。

## 复查 m234／help_card（上一单留的）

- help_card 10622／10623：run 42343228257 用的是第二次同步后的产物，`xiyou_help_card` 不在失败表里，按它算已过。
- m234 五个预设（`事件空绿扫描.py --check` 的 `#a1` 没量）：这是同步工具的检查，不是 Godot 场景，要在集成树（第二次同步的产物）上跑一次 `事件空绿扫描.py --check`。本树的 generated 是本机重转的，参照取自主工作区（v0.28），在这里跑没意义，交回总装在集成树跑。

## 同表里不归本单的（看到了顺手记）

- `xiyou_pause_save` 的 `skip:event`／`no_popup`：很可能也是大厅漩涡过场（新局在大厅、事件在跑），可让对应车道先试 `XConfig.whisper_mark("rift1")`。没改。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·高阶词条概率页 | `core/affix_rate.gd` `XAffixRate.DETAIL_SHOWN`（`detail_rows`） | v0.62 高阶词条概率模块包装 G.detailRows 晚于「修行·详细」窗口抓取函数，页末那段「高阶词条概率」从不显示 | 照作者本意显示 | 原版 bug 要修（Kyo 2026-11-07） | `XAffixRate.DETAIL_SHOWN = false` | cc（界面 ui-newsrc1） | 待用户决定 |

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】换源集成：修行·详细页高阶词条概率段照作者本意显示；四个界面测试改正前提（dev.待定）

- 原版 v0.62 的「高阶词条概率」包装装晚了，修行·详细页从来不显示这一段；重制照本意显示，开关 `XAffixRate.DETAIL_SHOWN`（O-待定）可回原版。
- item_bag、hangup 的测试要先把大厅首次漩涡过场记成看过（云端全新配置会播过场、占住地图）；hangup_options 的行数随 Boss状态面板开关。

## 交接板

- 下一步：集成树上跑一次 `事件空绿扫描.py --check` 确认 m234 五个预设。
- 用户试玩说明：修行·详细页末尾有「高阶词条概率」一段（原版因为装载顺序不显示）。
- 需要用户决定：O-待定·高阶词条概率页（默认显示）。

## 待交叉核查

- cc/ui-newsrc1：高阶词条概率页开关（乙档）、四个测试前提（丙档）

## 可优化（流程／工具／效率）

- 好几个测试原来没设配置目录，用的是本机开发档，所以本机和云端结果不一样（这次 item_bag 就是）。可以在 `tests/test_main_loop.gd` 里默认把 XConfig／XSave 指到每个测试自己的临时目录，跑完再删；测试目录残留的 options.json 也会让本机连跑时结果不同（这次 hangup 就是）。

## 验证

- 本机（v0.62.12 重转产物，zhenqi.json 用 v0.62.12 重跑探针）：`xiyou_zhenqi` 201/201、`xiyou_item_bag` 160/160、`xiyou_hangup` 31/31、`xiyou_hangup_options` 57/57。hangup、item_bag 删掉测试目录、从全新配置跑过。
- 云端选测通过（用集成分支的产物快照：给本分支建了 `refs/ci/generated/cc/ui-newsrc1` 指向 `refs/ci/generated/cc/newsrc-switch` 的同一提交 905a0a2d）：提交 5e243a57，9 个场景，含 xiyou_zhenqi 201/201、item_bag 160/160、hangup 31/31、hangup_options 57/57、affix_rate、guide、event_compare，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42351277311 。
- 回退开关：`XAffixRate.DETAIL_SHOWN = false` 在 xiyou_zhenqi 里有字面量赋值（page.* 按原版比）。
