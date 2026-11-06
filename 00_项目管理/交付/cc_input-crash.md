# 交付：cc/input-crash

- 车道／工作者：输入闪退（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：`main` 846a9358（合并 main 后无新提交，无冲突）
- 开关：`XKeyMap.SAFE_HANDLED`（`core/key_map.gd`），O-待定

## 变更记录草稿

## 2026-11-06 【cc·输入闪退·未经审查】按键标已处理不再对空视口调用：发行版按空格/J 闪退（dev.待定）

- Kyo 11-06：天启篇按空格或 J 直接退出、经常闪退。崩溃报告（`~/Library/Logs/DiagnosticReports`，15:54～15:55 五份，正式版 dev.379 与 dev.368、dev.377 备份都有）同一处 SIGSEGV `KERN_INVALID_ADDRESS at 0x450`，老问题，不是 dev.379 带进来的。
- 原因：标题按确认键（回车、空格、Z、J）开新游戏／返回版本选择时，`_unhandled_input` 里 `change_scene_to_file` 立刻把标题摘下树，下一行 `get_viewport().set_input_as_handled()` 的 `get_viewport()` 是 null。调试版只报「Cannot call method 'set_input_as_handled' on a null value」，发行模板的 GDScript 不查空，直接对空指针调用、闪退。用编辑器跑正式版 pck、注入空格复现了这条报错。
- 修：新增 `XKeyMap.handled(node)`（`core/key_map.gd`），节点不在树上就跳过；全工程 151 处 `get_viewport().set_input_as_handled()`（48 个文件）机械换成 `XKeyMap.handled(self)`，在树上时行为不变。别的页面在按键处理里切场景、关自己也是同一条路，一并消掉。
- 回退开关 `XKeyMap.SAFE_HANDLED = false`：照旧直接调用。登记 O-待定。
- 测试 `xiyou_input_handled`（10 项）：源码不再有直接写法；不在树上的节点不报错；标题按空格、J 选「返回版本选择」后没有空视口报错（把 entry.gd 那一处改回旧写法，3 项失败，咬得住）。测试走「返回版本选择」，没走「新的游戏」：新游戏挂着开局事件的协程，退出时报泄漏。

## 交接板

- 下一步：合并后重导正式版 `~/Applications/再刷一把：天启篇.app`，请 Kyo 再按空格/J 试一次。
- 用户试玩说明：标题、菜单各页按确认／取消键切页面不再闪退。
- 需要用户决定：导出包目录里的 `再刷一把：天启篇_dev368备份.app`、`_dev377备份.app` 会被启动台收录，显示成三个天启篇；删不删已经在线程里问 Kyo。

## 进度账

- 无（修缺陷，不改完成度）

## 可优化（流程／工具／效率）

- 建议：`发行入口冒烟.py` 只跑无头、不按键，发行模板才会出的空指针闪退它看不到。可以加一项：包内跑标题、注入一次确认键，看进程还活着（归哪吒工具车道）。

## 验证

- 语法检查 `语法检查.py`：594 个 .gd，0 个问题。
- 选测（选测.py 因 entry.gd 判「整轮」，车道按规矩不跑全量，手选界面／键位／入口相关 27 个）：全部通过，3044 秒（等槽占大半）。`xiyou_input_handled xiyou_key_map xiyou_key_repeat xiyou_pad xiyou_entry_release xiyou_platform xiyou_map_hotkeys xiyou_version_label ui_smoke xiyou_flow xiyou_ui_page_details xiyou_list_paging xiyou_panels xiyou_options_basic xiyou_options_misc xiyou_battle_ui xiyou_battle_options xiyou_save_page xiyou_choice_window xiyou_hud xiyou_reincarnation_entry xiyou_skill_page xiyou_party xiyou_gear_search xiyou_notice_options xiyou_hangup_options xiyou_event_compare`。整轮留给总装合并后跑（改了 48 个文件，各处只替换同一行）。
- 和八戒 cc/bajie-newsrc3（DJ：地图解释器在地图释放后还跑）可能碰同一批文件：本分支对每个文件只把 `get_viewport().set_input_as_handled()` 一行换成 `XKeyMap.handled(self)`，冲突时保留对方改动、再把这一行替换一遍即可（`rg 'get_viewport\(\)\.set_input_as_handled'` 应为 0，`xiyou_input_handled` 的 no_direct_set_input_as_handled 会查）。
- 没验：发行模板里实际按键（Kyo 没批准我操作游戏窗口；发行模板不认 `-s`），合并重导后请 Kyo 试。

## 本分支提交

- 21a086f2 按键标已处理走 XKeyMap.handled（含优化登记 O-待定）
- 5d962ba6 测试 xiyou_input_handled
- 改动的 .gd（48 个＋测试）：core/game_app、key_map、key_repeat、platform、touch_controls；modes/xiyou/entry；battle/battle_list、battle_scene、boss_status_panel；map/map_scene；ui/ 下 achievement_scene、actor_advanced、actor_book、actor_page、actor_warehouse、alien_workshop、casino_dialog、change_clothes、choice_window、costumes_scene、crafting、enemy_book、equip_scene、forget_skill_scene、game_end_panel、hang_up_options、hang_up_sub_page、inlay_book、item_scene、map_transfer、menu、message_box、notice_options、options_scene、party_scene、pets、pingbi_options、save_scene、shop、skill_scene、star_warehouse、status_page、test_mode_scene、text_prompt、touch_options、training_scene、victory_screen、warehouse、web_panel
