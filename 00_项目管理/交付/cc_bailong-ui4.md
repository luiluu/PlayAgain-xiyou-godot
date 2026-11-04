# 交付：cc/bailong-ui4

- 车道／工作者：B 界面／白龙（cc）
- 状态：**未完成，不可合并**（Kyo 11-04 叫停，WIP 停在这里）

## 接续要点

已做完：地图快捷键，专项 `xiyou_map_hotkeys` 31/31 通过，提交 551804de。可以单独合，但还没跑选测（`选测.py main --list`）。

没做完：Boss 状态面板。
- 已写未接线、从没运行过：`modes/xiyou/core/boss_status.gd`（XBossStatus，分类、回合、说明）、`modes/xiyou/battle/boss_status_panel.gd`（XBossStatusPanel，折叠栏、详情、点击）。
- 下一步：
  1. 在 `battle_scene.gd` 的 `_build_ui` 末尾（OTB 之后）`ui.add_child` 面板，`position = _origin`，给三个 Callable：`enemies_source` 返回 `logic.enemies`；`target_source` 在 `_target_mode == "enemy"` 时返回 `_hover`；`help_source` 在 `list_win` 和 `help_card` 都显示时返回说明卡矩形（减 `_origin`），否则空 Rect2。
  2. 写专项（分类、回合文字、排序、Boss 判定、点击翻页、Esc、点击不穿透）。
  3. 窗口模式截图，对照下面的原版读数。
  4. 查 `battler.hp` 比较（`_track_hits`）、`XBattler.state_turns` 的键类型、`b.state_data` 是否每个敌人都有。这些都是照读码写的，没验证。
- 没移植 `_statesFloor` 层数（CP_StateFloor）：`entries` 里只有「计数」没有「N层」。重制没有这个字段，battler.gd:483 的 CP_StateFloor 是加算。要查原版状态层数在重制存哪，补上。

原版参照（`?battle_ref=1` 夹具，`$dataTroops[2].members[0].enemyId=6` 在点「战斗夹具 4 人」前改，点第二次会崩，要先重载页面；状态加 4、5、10，`addBuff(2,5)`、`addDebuff(3,5)`）：
- Boss 血条框 (105,45.5) 高 78；折叠栏 (105,131.5) 440×96；详情相对折叠栏 (0,102)，480×400。
- 分类结果：异常 4（黑暗 4回合、睡眠 4回合、物防弱化 1层·5回合、中毒 本场战斗），增益 1（物攻强化 1层·5回合）。排序也是这个顺序，可直接当断言。
- 截图没存盘，只看过；接手要重新截。

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

## 新发现（待总装定）

- **重制没有 MOG_BossHP 的 Boss 血条**（原版战斗顶部的头像、彩虹血条、血量数字、状态图标）。`rg` 工程里 BossHP 只用来读 Boss 名单，gaps5 按名字筛没筛出来。每场 Boss 战都看得见，比状态面板更显眼。这轮没做，面板位置先按原版血条下方写死。
- 面板原版折叠栏和详情有「战力」（CodexCombatPower.enemy），按 Kyo 定的不做完整战力系统没画。要不要补等 Kyo 定。

## 可优化（流程／工具／效率）

- 按住 3 或 T 会连发，把隐身、显形药剂连着耗掉；按住 ~ 连着写档。都是原版行为，这轮照搬。可以改成只认按下、不连发，要总装分 O 号。

## 验证

- `xiyou_map_hotkeys` 31/31（快捷键部分）。Boss 面板只过语法检查，没跑过。没跑选测。

## 变更记录草稿

等做完再写。

## 待交叉核查

`map_scene.gd`（快捷键、`open_pingbi`）、`mv_interpreter.gd`（pingbizhuangbei）。
