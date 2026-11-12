# 交付：cc/android-touch-battle

- 车道／工作者：安卓 v0.01.01 玩家反馈（战斗虚拟按键）／cc（项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·线程·未经审查】安卓战斗：虚拟按键不再叠两份、加「信息」键、战斗里怪物信息不藏数值（dev.待定）
- 起因：测试玩家（玲樱）v0.01.01 安卓反馈：① 进战斗后虚拟按键变成两份 A／B 叠在一起；② 用虚拟按键看不了敌人属性，特别是第一次进战斗。
- ① 原因：进战斗时截地图画面当战斗背景（`XMapScene._snapshot`，照 Scene_Map.snapForBattleBackground），触屏虚拟按键在根视口的 CanvasLayer 120 里，被一起截进背景；背景上留着一份 A／B，上面活的按键又一份。原版 Mehmet_GhostButtons 的按键是场景子节点，同样会被截进去，按原版缺陷修：截图那一帧先藏起虚拟按键（O-待定·快照不带虚拟按键，`XMapScene.SNAP_HIDE_TOUCH`）。同一截图函数也给菜单、事件打开的页面当底图，一并不带按键。
- ② 原因：战斗里看怪物信息要按 Shift（AB_EnemyBook ShortCutButtonName），默认的原版虚拟按钮只有 A／B，改版 A／B 两键也没有 Shift，手机上没有入口。现在这两种布局在战斗中于 A 上方、B 左边的空角多一个圆形「信息」键（原版按钮样式 96 直径，A／B 两键样式 72），按下＝Shift：指令窗或技能列表开着时打开怪物信息。战斗外不显示、不吃触摸；「原多键」本来有 Shift 键，旧三键不加（O-待定·战斗信息键，`XTouchControls.BATTLE_INFO_BUTTON`）。
- ③ 玩家截图（第三张）显示她能打开怪物信息，但第一次遇到的怪能力值、属性、技能全是「？？？」：原版 AB_EnemyBook ResisterTiming 2＝打完才登记，登记前战斗里一律藏数值。现在战斗里的「怪物信息」没登记也照写数值；大厅那本图鉴的登记、击败数、掉落照旧打完才有（O-待定·战斗怪物信息不藏数值，`XEnemyBookPage.BATTLE_SHOW_UNREGISTERED`）。
- 大厅右边「一键解锁 99 级」NPC（Map004 事件 69）：没改。v0.28 里它一直显示；v0.62.12 起原版 installTestGateRuntime 把它收进测试模式（第 1 页以开关 2501 为条件，开关跟测试模式同步），重制照新源数据、没移植这个同步，玩家版里它现在不显示。玩家希望保留，要不要对玩家显示由 Kyo 定（见交接板「需要用户决定」）。
- 专项 `xiyou_platform` 加 13 项（信息键战斗外不显示、战斗中显示且可点、不压 A／B、按下＝Shift 松开即放、战斗结束收起、回退开关、`touch_info_visible` 跟战斗走）。
- 专项 `xiyou_battle_ui`、`xiyou_enemy_book`：没登记的敌人战斗里照写数值、大厅图鉴仍不画；原版参照（「？？？」）改成对照回退态。
- 玩家可见：安卓战斗里虚拟按键只有一份；战斗中多一个「信息」键，点它看敌人属性；第一次遇到的怪在战斗里也能看到数值。
- 未完成／已知问题：截图藏按键这一步无画面测试量不到（headless 不截图），没在实机上看过；「第一次进战斗看不了」按截图理解成没登记全写「？？？」。

## 交接板

- 下一步：随下一个修复补丁 v0.01.02（code > 471）一起出；补丁分支照 `cc/v001-fix-patch` 做法 cherry-pick 本分支，等 Kyo 说「推」再推给玩家。
- 用户试玩说明：安卓进一场战斗，看虚拟按键是否只有一份；轮到选指令时点「信息」键，应打开怪物信息，B 关掉回到指令。
- 需要用户决定：大厅右边「一键解锁 99 级」测试 NPC 要不要对玩家显示（原版新版只在测试模式出现；玩家玲樱希望保留）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·快照不带虚拟按键 | `modes/xiyou/map/map_scene.gd` `XMapScene.SNAP_HIDE_TOUCH`（`_snapshot`）；`tests/xiyou_platform.gd` | Scene_Map.snapForBattleBackground 只藏窗口层，Mehmet_GhostButtons 的虚拟按键是场景子节点，被截进战斗背景 | 截图那一帧先藏起触屏虚拟按键，战斗背景、菜单底图里没有按键 | 玩家反馈 v0.01.01：进战斗后 A／B 叠两份 | `XMapScene.SNAP_HIDE_TOUCH = false` | cc | 已接受（Kyo 11-11 优化直接接受） |
| O-待定·战斗怪物信息不藏数值 | `modes/xiyou/ui/enemy_book.gd` `XEnemyBookPage.BATTLE_SHOW_UNREGISTERED`（`status_ops`）；`tests/xiyou_battle_ui.gd`、`tests/xiyou_enemy_book.gd` | AB_EnemyBook ResisterTiming 2：打完才登记，登记前战斗内「怪物信息」能力值、属性、技能全写「？？？」 | 战斗内照写数值；大厅图鉴登记、击败数、掉落照旧打完才有 | 玩家反馈 v0.01.01：第一次进战斗看不了敌人属性 | `XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = false` | cc | 已接受（Kyo 11-11 优化直接接受） |
| O-待定·战斗信息键 | `core/touch_controls.gd` `XTouchControls.BATTLE_INFO_BUTTON`（`info_shown`、`_cond_shown`、`GHOST_INFO`、`AB_INFO`）；`modes/xiyou/map/map_scene.gd` `touch_info_visible`；`tests/xiyou_platform.gd` | 原版虚拟按钮只有 A／B（Shift 那行注释掉了），手机上战斗里开不了怪物信息 | 原版按钮与 A／B 两键布局在战斗中加圆形「信息」键＝Shift | 玩家反馈 v0.01.01：虚拟按键看不了敌人属性 | `XTouchControls.BATTLE_INFO_BUTTON = false` | cc | 已接受（Kyo 11-11 优化直接接受） |

## 进度账

- 无（安卓扩展账不变）。

## 验证

- `语法检查.py`：775 个 .gd 0 问题。
- `xiyou_platform` 155/155（加 13 项）；反向验证：把 `BATTLE_INFO_BUTTON` 改成 false，专项挂（info 断言访问不到），改回通过。
- `xiyou_battle_ui`、`xiyou_enemy_book` 通过（图鉴改动后重跑；`xiyou_event_compare*` 四片没跑，图鉴页不在事件对照路径上）。
- 选测 10 个全过：`xiyou_platform`、`xiyou_map_hotkeys`、`xiyou_battle_transition`、`xiyou_battle_ui`、`xiyou_ui_input`、`xiyou_feedback_v001`、`xiyou_map`、`xiyou_hud`、`xiyou_battle_me`、`xiyou_options_misc`。
- 没跑：`选测.py` 因 `map_scene.gd` 列出 133 个（楼层、事件对照等）；本分支在 `map_scene.gd` 只加了 `touch_info_visible` 一个新函数和 `_snapshot` 里 headless 早退之后的几行，无画面测试里走不到，所以没全跑，留给总装按影响面选测。截图藏按键没有自动测试（headless 不出图），没实机。

## 待交叉核查

- `core/touch_controls.gd`、`modes/xiyou/map/map_scene.gd`（`_snapshot`、`touch_info_visible`）、`tests/xiyou_platform.gd`、`modes/xiyou/ui/enemy_book.gd`、`tests/xiyou_battle_ui.gd`、`tests/xiyou_enemy_book.gd`。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- aec9a550e 战斗虚拟按键不叠两份、加信息键；交付单
- （本提交）战斗怪物信息没登记也写数值
