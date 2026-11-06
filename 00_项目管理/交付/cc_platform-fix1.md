# 交付：cc/platform-fix1

- 车道／工作者：平台／CJ（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·CJ·未经审查】手机标题页「导出存档」不再被存档键盖住（dev.待定）

- 起因：审查 50 P2-1。keys3 的触屏存档键 `Rect2(1050, 8, 100, 40)` 在所有页面都显示，标题页 android4 的「导出存档」（x1055～1160）有 1055～1150 一段压在它下面；`XTouchControls` 在 `_input` 先命中存档键就吃掉触摸，按钮收不到。
- 先查原版：冻结源 v0.62.12 `Mehmet_GhostButtons.js` 第 41～43 行 `disableGhostButtonsScene = [Scene_Boot, Scene_Title]`（标题页整套虚拟键不建），第 672 行只在 `[Scene_Map, Scene_Menu]` 加 Save 键（战斗、物品等子页面都没有）。按方案①照原版。
- `core/touch_controls.gd`：新增 `SAVE_MAP_MENU_ONLY`（默认 true）和 `save_shown()`：当前场景有 `touch_save_visible()` 且返回 true 才显示存档键、`hit()` 才认它；`_process` 每帧同步可见性，布局编辑时照旧全显示。测试用 `scene_override`。
- `modes/xiyou/map/map_scene.gd`：`touch_save_visible()`：战斗中（`_in_battle`）为否；菜单开着时看 `XMenu.is_top_level()`（`modes/xiyou/ui/menu.gd` 新增，`_mode != "page"`，即指令窗或选人＝Scene_Menu 本身）。标题页、入口菜单等没有这个方法，就不显示。
- `modes/xiyou/entry.gd`：刘海机右缩进或拖过按键时，「隐藏按键」（回退成所有页面显示时连同存档键）挡在标题按钮那一行，两个按钮整体左让到它左边 10 像素；默认布局位置不变（940／1055）。
- 回退：`XTouchControls.SAVE_MAP_MENU_ONLY = false` 回到 keys3 的所有页面显示（此时标题按钮会同时避开存档键）；O-211（编号待总装确认，派单没预分配）。
- 已知差别：地图上由事件打开的整页界面（商店等）不是 Scene_Map，原版不出 Save 键；这里仍按地图算会显示，按了走地图快捷键，事件运行中不响应（`XMapHotkeys` 本来就这样），只是多一个按了没反应的键。要收窄就让这些页面在 `touch_save_visible` 里也算进去，建议等手机实测后定。

## 交接板

- 下一步：无新增（审查 50 P2-1 收掉）。
- 用户试玩说明：手机上标题页右上的「导入存档」「导出存档」都能点了；存档键只在地图和打开菜单时出现，进战斗、进物品／技能等子页面会消失。
- 需要用户决定：无。

## 进度账

- 平台：不变（修审查问题）。

## 可优化（流程／工具／效率）

- 建议：`选测.py` 把 `modes/xiyou/entry.gd` 归到「拿不准：整轮」，本轮只改了触屏时才建的两个按钮，也只能整轮。可给 entry.gd 加一条 refs 规则（引用它的 6 个测试：ui_smoke、xiyou_platform、xiyou_flow、xiyou_hud、xiyou_entry_release、xiyou_floor_run），预计每次改标题页省一次整轮；归工具车道。

## 验证

- 先在旧代码上挂：新专项（去掉新代码才有的 `scene_override` 等行）在旧 `touch_controls.gd`／`entry.gd` 上 76/79，挂 `title_touch_no_tilde_ExportSave`、`title_touch_export_pressed`（导出 0 次、导入 1 次）、`title_buttons_clear_notch`（右缩进 80 时隐藏键 x1100 压住导出 x1055～1160）。
- 新代码：`xiyou_platform` 83/83（新增：存档键在非地图页不显示不吃触摸、地图上显示、战斗／子页面不显示、回退开关；标题页真触摸 `InputEventScreenTouch`＋模拟鼠标点「导出存档」「导入存档」中心各收到一次、不按下 ~；刘海右缩进 80 时两个按钮不和隐藏键重叠）。`xiyou_map_hotkeys` 36/36（新增：真地图上真触摸点存档键＝存进 1 号位并提示；`_in_battle` 时隐藏；打开菜单在主菜单时显示，进状态子页面隐藏）。
- `语法检查.py` 591 个 .gd 0 问题。`xiyou_event_compare` 通过。
- 选测：`选测.py main --list` 因 entry.gd 结论是整轮；车道不跑整轮，改跑引用 XMenu／XTouchControls／标题页的 29 个专项（结果见下）。map_scene.gd 只新增一个只被触屏调用的函数，没跑它对应的 110 个地图场景，交总装整轮覆盖。
- 相关专项：引用 XMenu／XTouchControls／标题页的 29 个场景（ui_smoke、xiyou_actor_book、xiyou_alien_workshop、xiyou_book_capacity_ui、xiyou_crafting、xiyou_enemy_book、xiyou_entry_release、xiyou_floor_run、xiyou_flow、xiyou_gear_ui、xiyou_gold_cap、xiyou_hangup_options、xiyou_hud、xiyou_item_bag、xiyou_item_use、xiyou_list_paging、xiyou_notice_options、xiyou_options_misc、xiyou_orb_shop_ui、xiyou_panels、xiyou_party、xiyou_pets、xiyou_race_menu、xiyou_review135、xiyou_save_page、xiyou_shop_stat_mode、xiyou_skill_page、xiyou_ui_page_details、xiyou_zhenqi_break）全部通过，无偶发。已合 main 5d8a9bf2（只带进文档与合并工具，没碰 Godot 文件）。`工具回归.py` 全过（68 秒）。

## 本分支提交

- 2e895608 触屏存档键照原版只在地图与主菜单显示，标题导入/导出按钮避开隐藏键
- 7966151c 合并 main
