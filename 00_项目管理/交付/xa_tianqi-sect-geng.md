# 交付：xa/tianqi-sect-geng

- 车道／工作者：小A（xa/tianqi-sect-geng）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【小A·天启篇·未经审查】教派连带重做·包庚「传承与武运」（dev.待定）

- **魔塔外围五位传承 NPC**（Map195 EV016～020）：天启篇通过 `XTianqiSect.page_override` 与 `intercepts`/`run_event` 默认开放（走原 `sw1:2303` 线，不选轮回页），台词「他必须不被两派所束缚，」改写为「他必须不被世俗所束缚，」；EV020（六道魔君）`var 20 >= 24` 且 `self:A` 时的七煞功页同步保留。
- **15／20／25 层传承人**（Map032 EV008、Map116 EV007、Map147 EV005）：天启篇默认开放，第 2 页关闭条件由 `var 20 >= 16/21/26` 放宽到 `var 20 >= 31`（30 层前可补），提示文案改写为「踏上第 31 层前都可回来补领传承，登上 31 层后自动关闭」。
- **城隍庙**（Map189 EV021）：天启篇未领过武运时照随机页（第 2 页）走（四小强无损学 3920 一丝武运），去掉「忘掉强者压制 6216、学强者压制·削弱 6241」两步及选项中的「随机模式下，」字样；领过后照第 4 页走。
- **先查结论**：魔塔外围由大厅 `Map004 EV029`（塔外）进入，第 1 页无任何层数／开关／变量条件，开局即可进；15 层传承人关闭条件仍一并放宽到 `var 20 >= 31`。
- **回退开关**：`XTianqiSect.GENG`（O-待定，设 `false` 回原样）；仅在 `XTianqi.active` 为真时生效，不改 `generated` 原数据，西游普通档不受影响。
- **验证**：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：851 个 `.gd`，0 个问题。
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：54 个脚本，445 个函数都有。
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`：18 项全部通过（232 秒）。
  - 本地专项：`xiyou_tianqi_sect_geng.tscn`（80/80 通过）、`xiyou_tianqi_sect_a.tscn`（41/41 通过）。
  - 云端选测（提交 `f26f2f7cd6`，基准 `fbb2d9b960`，运行页 `https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43602473585`）：590 个场景通过 589/590（`选测.py` 列出的 95 个场景全过）；唯一失败 `xiyou_tianqi_alien_gear.tscn`（本地复测 54/57，挂在 `review6_tier_again` / `review6_huaxing_same_again` / `review6_o-off`）为 `main` 既有问题，与本车道无关。

## 交接板

- 下一步：合并后为 `XTianqiSect.GENG` 分配正式 `O-` 编号并替换 `dev.待定`。
- 用户试玩说明：天启篇无需教派／随机开关即可在魔塔外围领五条传承、30 层前在 15／20／25 层补传承、在城隍庙为四小强无损领先天武运。
- 需要用户决定：无。

## 进度账

- 无（天启篇教派连带重做包庚）。

## 可优化（流程／工具／效率）

- 无。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_sect.gd`、`modes/xiyou/map/mv_event.gd` | 魔塔外围五条传承、15/20/25 层传承人及城隍庙无损武运受随机／轮回开关与过层关闭限制 | 天启篇默认开放五条传承与无损武运，传承人关闭条件放宽至 31 层并改写教派／两派台词 | Kyo 11-14 拍板天启篇教派连带重做·包庚 | `XTianqiSect.GENG = false` | 小A | 保留 |

## 返修（cc 核查退回修复）

- **【甲级·阻断】发行空壳特例与回归**：在 `03_再刷重制_Godot/07_开发环境/发行空壳特例.json` 新增 `"XTianqiSect.intercepts": "false"` 与 `"XTianqiSect.page_override": "{}"`；`发行空壳.py show XTianqiSect` 确认 `intercepts` 返回 `false`、`page_override` 返回 `{}`；在 `03_再刷重制_Godot/07_开发环境/测试发行空壳.py` 新增 `test_real_project_sect_stub` 回归断言。
- **【丙级】去掉 intercepts 走普通 run_event**：移除 `XTianqiSect` 包庚段在 `intercepts`／`run_event` 的接管分支及 `_geng_intercepts`／`_geng_run_event`，仅保留 `page_override` 注入 `e.page`，使 NPC 对话保留 `e.locked` 与确定键转向玩家。
- **【丙级·隐患】hides 优先于 page_override**：在 `MVEvent` 抽取 `_is_hidden_event()`，令 `MVEvent.refresh()` 先判 `erased or _is_hidden_event()` 再调 `XTianqiSect.page_override`；`page_override` 内同步将 `_geng_is_target` 提前到 `on(s)` 之前。
- **返修验证**：`语法检查.py`（852 个 `.gd`，0 问题）、`发行空壳.py check`（54 脚本 445 函数）、`发行空壳.py show XTianqiSect`（`intercepts` 返回 `false`、`page_override` 返回 `{}`）、`测试发行空壳.py`（4/4 OK）、`工具回归.py`（18/18 通过，161 秒）、`xiyou_tianqi_sect_geng.tscn`（81/81）、`xiyou_tianqi_sect_a.tscn`（41/41）全部通过。

## 本分支提交

- `f26f2f7cd` 天启篇教派连带重做·包庚：传承与武运
- `f3dd3bf56` 交付单：补齐包庚测试结果并标为可合并
- `014e0ad50` 交付自检修复：补齐 .gd.uid 与优化登记草稿表
- 返修提交（见 `git log`）
