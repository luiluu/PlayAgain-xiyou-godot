# 交付：cc/bailong-ui4b

- 车道／工作者：B 界面／哪吒（cc，Sonnet／medium），接自白龙 `cc/bailong-ui4` 的 c78140a3（原分支、原工作树 hopeful-cohen-17442a 未动）
- 状态：**可合并**（Boss 面板已接线并通过专项；地图快捷键沿用白龙 551804de）

## 做了什么

- 地图快捷键（YEP_ButtonCommonEvents）：白龙已完成，`xiyou_map_hotkeys` 31/31，原样带过来。
- Boss 状态面板（Codex_BossStatusSummary v0.4.0，gaps5 真缺 3）：
  - `battle_scene.gd` `_build_ui` 末尾（OTB 之后）加 `XBossStatusPanel`，`position = _origin`，三个 Callable：`enemies_source` 返回 `logic.enemies`；`target_source` 在 `_target_mode == "enemy"` 时返回 `_hover`；`help_source` 在 `list_win`、`help_card` 都显示时返回说明卡矩形（减 `_origin`），否则空 Rect2。新成员 `boss_panel`。
  - `boss_status_panel.gd` 里静态函数 `wrap` 与 GDScript 内置 `wrap()` 重名，改名 `wrap_text`；`_track_hits` 的 `id` 补了类型。（这两处是语法检查揪出的，没运行过的代码原本就过不了解析。）
  - 专项 `xiyou_boss_status`（新）：Boss 判定（身份、现身、存活、非 Boss 敌人）、分类／回合文字／排序（原版读数当断言：异常 4＝黑暗 4回合、睡眠 4回合、物防弱化 1层·5回合、中毒 本场战斗；增益 1＝物攻强化 1层·5回合）、折叠栏与详情位置尺寸（105,131.5／440×96；详情 (105,233.5)／480×400）、点击展开、三个标签、翻页（含两端夹住）、点条目看说明、回列表、× 与 Esc 关闭、画布 `MOUSE_FILTER_STOP`（点击不穿透）、多 Boss 选目标优先／上一个掉血的、说明卡挡住折叠栏上移、Boss 死亡后面板消失。37 项。
- 核了白龙标的四件事：
  1. `_track_hits` 的 `b.hp` 比较：掉血后 `last_hit_kept` 通过，没问题。
  2. `state_turns` 键是 `int`（`battler.gd` 一律 `state_turns[id]`），`entries` 里 `b.state_turns.get(id)` 对得上。
  3. `state_data`：`XBattler` 上 `var state_data := {}`，每个战斗者都有，`.get("_stateCounter", {})` 空字典安全。
  4. 状态编号别想当然：state 4＝中毒、5＝黑暗（行动后结束）、10＝睡眠（3～5 回合随机）。原版读数的「睡眠 4回合」是夹具设的，专项里手设 `state_turns[10]=4`。
- 层数：重制里没有 `_statesFloor`。CP_StateFloor 在重制只落成特性加算（`traits_pi`），没有「状态叠几层」的存储；`state_data._stateCounter` 是 YEP 状态计数，原版面板已把它当「计数 N」显示。所以**面板不显示状态的「N层」**（Buff／Debuff 的强化弱化层数照常显示）。要补得先做状态叠层系统，不在这轮。
- 截图：窗口模式截了折叠栏和详情两张（`04_验证/本地结果/boss_status_shot/boss_status_bar.png`、`boss_status_detail.png`，不入 Git），位置、字体、分类、颜色与原版读数一致；**没对原版截图**（原版夹具要开浏览器，这轮没做）。

## 地图快捷键：原版可用场景（读源码，没在正式版实机按过）

`Scene_Map.updateScene` 包装：地图页面（开菜单、战斗、别的页面不响应）、没有文字窗、没有事件在跑才响应；走动、挂机、乘载具都能按。`Input.isRepeated`：按下一帧，按住 24 帧后每 6 帧连发。

| 键 | 公共事件 | 效果与限制（都在公共事件里） |
| --- | --- | --- |
| ~ | 428 一键存档 | 变量 21＝0 时存到开局存档位；副本中提示「需要存档请传送出去」 |
| 1 | 10 回到大厅 | 乘飞艇、副本中拒绝并提示 |
| 2、R | 624 快捷回血 | 要无尽瓶，回 99999；没瓶提示 |
| 3、T | 626 隐身 | 切换开关 54，消耗隐身／显形药剂一瓶，加减状态 174 |
| P | 486 屏蔽 | 打开屏蔽掉落页，这轮新接 `pingbizhuangbei` |
| L | 484 挂机 | **不是开关挂机**：解除挂机禁用并提示；副本中提示去重置副本。开关挂机在原版也是 G（XdRs_HangUp keyVal 71），重制已有 |

和原版的差别：「最后按下的键」只算这七个键，按住 R 再按方向键时继续连发（原版停）。

派单写「L 挂机」、gaps5 也这么写，实际如上表。

## 新发现／可优化（给总装）

- **重制没有 MOG_BossHP 的 Boss 血条**（原版战斗顶部的头像、彩虹血条、血量数字、状态图标）：每场 Boss 战都看得见，比状态面板显眼。面板位置先按原版血条下方写死（折叠栏 y=131.5）。这轮不做，要总装派。
- 面板原版折叠栏和详情有「战力」（CodexCombatPower.enemy），按 Kyo 定的不做敌人战力，没画。
- 按住 3／T 会连发，把隐身、显形药剂连着耗掉；按住 ~ 连着写档。原版行为，这轮照搬；可以改成只认按下，要总装分 O 号。
- 状态叠层（CP_StateFloor `_statesFloor`）重制没有，见上。
- 小提醒：GDScript 里 `static func wrap` 这类与内置函数重名的名字，`语法检查.py` 能揪出来，没运行过的新文件先过一遍它。

## 验证

- `语法检查.py`：522 个 .gd 0 个问题。
- 专项：`xiyou_boss_status` 37/37（窗口模式截图时 39/39）、`xiyou_map_hotkeys` 31/31（白龙跑的）。
- 选测：`选测.py main --list` 选中 162 个场景（含战斗核心类）；超过 40 个，走 `云端选测.py run`：**通过**（提交 7a909cd952，149 个场景、4 片；之后只改了交付单）。

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】Boss 状态面板接线、地图快捷键（接自白龙 ui4）

- 战斗画面接上 Boss 状态面板（Codex_BossStatusSummary）：有活着且已现身的 Boss 时，折叠栏在原版 Boss 血条位置下方（105,131.5），点开看异常／增益／全部三个标签、点条目看说明、翻页，Esc 或 × 关闭；只显示，不参与结算。不显示敌人战力，也不显示状态的「N层」（重制没有状态叠层）。
- 地图快捷键（YEP_ButtonCommonEvents）：~ 存档、1 回大厅、2／R 快捷回血、3／T 隐身、P 屏蔽、L 解除挂机禁用。
- 新专项 `xiyou_boss_status`（37 项）、`xiyou_map_hotkeys`（31 项）。

## 待交叉核查

- `battle_scene.gd`（`_build_ui` 接线、`_boss_panel_help_rect`）、`boss_status.gd`、`boss_status_panel.gd`（读 Codex_BossStatusSummary 源码对照：分类正则、排序、回合文字、位置）。
- `map_scene.gd`（快捷键、`open_pingbi`）、`mv_interpreter.gd`（pingbizhuangbei）。
- 没改 battle_logic／actor／battler／damage／xstate 等核心文件。
