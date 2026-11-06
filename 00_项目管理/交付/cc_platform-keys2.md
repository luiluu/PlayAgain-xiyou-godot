# 交付：cc/platform-keys2

- 车道／工作者：B 界面／输入（cc，platform-keys2）
- 状态：可合并
- 注意：本分支从 `cc/platform-keys1` 切出（`XKeyMap` 在 keys1 里，main 还没有），合并顺序必须在 keys1 之后；keys1 的交付单与选测见 `cc_platform-keys1.md`。

## 变更记录草稿

## 2026-11-06 【cc·未经审查】手柄照原版 gamepadMapper、地图右键呼出菜单与按住左键拖着走（dev.待定）

- 原版映射（rpg_core `Input.gamepadMapper`＋`_updateGamepadState`；没有启用手柄改键插件，MK_Sanfu_KeyConfig 不在 plugins.js 里）：A 确认、B 取消、X＝shift（冲刺、怪物图鉴快捷键）、**Y＝menu**（地图呼出菜单；调度单里写的「X 菜单、Y 翻页」与原版不同，按原版做）、LB／RB 翻页、十字键与左摇杆方向（摇杆阈值 0.5，先判上再判下、先判左再判右）。
- `XKeyMap.apply_pad`：A→ui_accept、B→ui_cancel（先清掉 Godot 默认的手柄键，防平台设置对调）、LB／RB→ui_page_up／down，新动作 `mv_dash`（X）、`mv_menu`（Y）。地图的 `mv_player.is_dashing` 和 `map_scene` 开菜单轮询它们。
- `XKeyRepeat` 加手柄：十字键、左摇杆、X 键被吃掉，换成键盘方向键／Shift 的按键事件（摇杆在 0.5 附近抖动只触发一次），所以页面不用改，连发走同一套 O-189 的 24／6 帧。拔手柄时全部松开。回退 `XKeyRepeat.MV_PAD = false`（手柄事件原样往下传，回到 Godot 默认映射）。
- 鼠标：逐页对照原版 `TouchInput`／`Window_Selectable.processTouch`（点到别的行＝移动光标、点已选行＝确认、右键＝取消、点击移动光标而不是悬停高亮、滚轮滚列表而不是移光标），重制 40 多个页面已经照做；缺的两处补上：
  - 地图上右键（两指点按）呼出菜单（原版 `Scene_Map.isMenuCalled` 含 `TouchInput.isCancelled`）。回退 `XKeyMap.MV_MAP_RIGHT_MENU = false`。
  - 地图上按住左键满 15 帧后目的地跟着鼠标换格（原版 `processMapTouch`）。只在换格时更新，不重复触发脚下／前方一格的确认。回退 `MVPlayer.MV_HOLD_MOVE = false`。
- 测试：新增 `xiyou_pad`（18 项）；`xiyou_key_map` 加开关检查（31 项）；`xiyou_list_paging` 里「W 不翻页」断言跟着改（W 现在是向上，光标上移一格、页不变，这正是原版）。

### 页面×操作表（重制现状；✓＝与原版一致，—＝本页没有这个操作的意义）

| 页面 | 左键点别行＝选中 | 点已选行＝确认 | 右键＝取消 | 滚轮 |
| --- | --- | --- | --- | --- |
| 主菜单 menu、物品 item_scene、技能 skill_scene、装备 equip_scene、整队 party_scene、状态 status_page | ✓ | ✓ | ✓ | ✓（滚列表顶行）；状态页本身不滚 — |
| 存档 save_scene、设置 options_scene、各设置子页（hang_up_options／sub_page、notice_options、pingbi_options） | ✓ | ✓ | ✓ | 列表多于一页的有，其余 — |
| 商店 shop、各商店、合成 crafting、仓库 warehouse／star_warehouse／actor_warehouse、宠物 pets、成就、图鉴（enemy_book／actor_book／inlay_book）、传送 map_transfer、换装 costumes／change_clothes、技能遗忘 forget_skill、训练 training、选择框 choice_window | ✓ | ✓ | ✓ | ✓（短列表 —） |
| 战斗指令／技能／目标 battle_list | ✓ | ✓ | ✓ | ✓ |
| 战斗场景 battle_scene（目标点选） | ✓ | ✓ | ✓ | — |
| 对话框 message_box、文字输入 text_prompt | ✓ | ✓ | ✓ | message_box ✓ |
| 胜利结算 victory_screen | ✓ | ✓ | 原版无取消 — | ✓ |
| 地图 | 点格子＝走过去（已有）；**按住拖着走（本次补）** | 点脚下／前方一格＝确认（已有） | **右键＝菜单（本次补）** | — |
| 标题 entry | 点选＝选中并确认（图片指令）✓ | — | — | — |
| 其它面板（boss_status_panel、test_mode_scene、game_end_panel、alien_workshop） | ✓ | ✓ | boss 面板、alien_workshop 只认 Esc（保持） | — |

与原版不同、做了开关的：无新增（上面两处补的都是原版有的行为，开关只为回退）。

## 验证

- 工具回归全过；语法检查 0 问题；xiyou_pad 18/18、xiyou_key_map 31/31、xiyou_platform 38/38、xiyou_list_paging 145/145、ui_smoke 24/24、xiyou_key_repeat 9/9（本机机器负载 26，并行测试排队排不上，直接用 Godot 跑的这些单项）。
- `选测.py main --list` 列出 131 个场景（超过 40 个，按规定走云端），本机没跑，请总装合并时 `--cloud` 补跑。改动面：输入动作、`XKeyRepeat`、`map_scene` 开菜单条件、`mv_player` 冲刺与点击移动。

## 交接板

- 下一步：无
- 用户试玩说明：插上手柄：A 确认、B 取消、X 冲刺、Y 开菜单、LB／RB 翻页、十字键与左摇杆走路选菜单（按住自动连发）；地图上点右键开菜单；按住左键拖动，角色跟着走。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 建议：本机并行测试在别的车道探针占满槽时一个 3 秒的单测也要排两小时；`并行测试.py` 可以给「个位数场景」一条不占重进程槽的快车道（预计省每次交付约 1～2 小时等待，归哪吒工具车道）。本轮我绕过它，直接用 Godot 跑了单项。

## 本分支提交

- 手柄、地图右键菜单、按住左键拖着走
