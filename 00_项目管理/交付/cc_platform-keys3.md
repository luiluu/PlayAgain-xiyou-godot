# 交付：cc/platform-keys3

- 车道／工作者：B 界面／输入（cc，platform-keys3）
- 状态：可合并
- 注意：从 `cc/platform-keys2` 切出（keys2 又在 keys1 之上，main 都还没有），合并顺序 keys1 → keys2 → keys3。

## 变更记录草稿

## 2026-11-06 【cc·未经审查】插件按键全覆盖对照、触屏加「存档」键（dev.待定）

- 冻结正式源 v0.28 与 v0.62.12 的 `plugins.js` 里 YEP_ButtonCommonEvents 参数相同。逐键对照结果见下表；重制早已接好全部有意义的键，本轮没有缺的公共事件键。
- 触屏加「存档」键（`XTouchControls`，右上「隐藏按键」左边）：对应 Mehmet_GhostButtons 的 Save 键，按下＝键盘 `~`，走已有的一键存档公共事件 428。回退 `XTouchControls.SAVE_BUTTON = false`。

### ①YEP_ButtonCommonEvents 键→公共事件→重制

| 键 | 原版参数 | 公共事件 | 重制 |
| --- | --- | --- | --- |
| ~ | 428 | 一键存档 | ✓ `XMapHotkeys`（KEY_QUOTELEFT） |
| 1 | 10 | 回到大厅 | ✓ |
| 2、R | 624 | 快捷回血 | ✓ |
| 3、T | 626 | 隐身 | ✓ |
| P | 486 | 屏蔽 | ✓ |
| L | 484 | 挂机 | ✓ |
| W、A、S、D | 参数被写成按钮名字符串（`Key Up (Up)` 之类），Number 得 NaN | 无（NaN 不会预约出任何事件） | ✓ 这几个键在原版每个场景开头被改回方向；重制 WASD＝方向（keys1） |
| 小键盘 8、4、6、2 | 写成 W/A/D/S 字符串，同上 NaN | 无 | 原版地图上数字键盘因此不能走路（菜单里能）；重制地图上也能走（keys1 已记，没照搬这个副作用） |
| 其余键 | 0 | — | — |

- 判定节奏（按下触发，按住 24 帧后每 6 帧一次、只认最后按下的键、BCE 列表顺序先到先得）、可用场景（只在地图页面、没有事件与文字时）：`XMapHotkeys` 头注释已按插件源码逐条写明，`xiyou_map_hotkeys` 31 项覆盖，本轮没改。
- 与 `XKeyMap.MV_KEYS` 无冲突：新补的 Z/J/X/K/Insert/小键盘0、WASD、小键盘方向没有一个出现在 BCE 的公共事件键里。
- 其它启用插件里的专用键（顺便核）：G 挂机 `XdRs_HangUp`（重制已有）、F 传送确认 `MapTransferPlugin`（已有）、Tab 切装备页下窗 `YEP_EquipCore`（已有）、Q／E 翻页（`MOG_BossHP` 的 Boss 血条翻页、`PKD_SimpleSkillsTree` 等，翻页键已通）。
- **缺口（本轮没做）**：`YEP_ShopMenuCore` 商店里装备的状态窗按 **Tab** 在「队员对比」与「默认（逐项属性）」两种显示间切换（`adjustMode`，Default Mode 参数是 actor，Stat Switching 开）；重制商店只有队员对比，没有默认模式那一页（要画 `drawStatDisplayed` 单项属性＋`drawEquipInfo` 装备信息，并让 ←→ 在默认模式下换属性）。这是一整页的画法而不是键位接线，建议另开一单做（商店车道）。同文件里的 Shift（`isPageChangeRequested`）原版没有任何调用，没有缺。

### ②Mehmet_GhostButtons

- 原版（插件 v1.0.3，「仅供移动端使用」）：`Utils.isMobileDevice()`（或测试参数）才建，且选项里「虚拟按钮」默认关；打开后左下一根摇杆（长按成固定方向、左右拽拉可换页），右边圆形 A（确定）、B（取消）两键，地图与菜单另有右上「Save」键（＝~，428 一键存档）。桌面端玩家看不到；插件指令 `GhostButtons Show/Hide` 只改这个选项。
- 重制：重制版没有这个选项，插件指令只记标记（`mv_event_core.gd`）；手机上由 `XTouchControls`（照二合一包 android-integration.js 的布局：左下摇杆、右下确定／取消／跑步、右上隐藏按键）代替，一直显示、可隐藏、位置记忆。
- 取舍：两套功能重叠（摇杆＋确定＋取消），重制保留 `XTouchControls` 的布局（实际安卓包用的就是它），不另做 Ghost 的圆形键；只补 Ghost 独有的 Save 键。没做：摇杆拽拉换页（有 LB／RB 与 Q／E 翻页，手机上缺换页手势，若 Kyo 要再说）。「虚拟按钮」选项不加（`XTouchControls` 已有隐藏键）。

## 验证

- 工具回归全过；语法检查 0 问题；xiyou_platform 40/40（含新增存档键 2 项）、xiyou_pad 18/18、xiyou_key_map 31/31、xiyou_map_hotkeys 31/31、xiyou_event_compare 10/10、ui_smoke 24/24。
- `选测.py main --list` 132 个场景（>40，走云端），本机因其它车道占满测试槽未跑，请总装 `--cloud` 补跑。

## 交接板

- 下一步：商店装备状态窗 Tab「默认模式」页（见缺口）；手机摇杆拽拉换页看 Kyo 要不要
- 用户试玩说明：手机上右上角多一个「存档」键，地图上点它＝一键存档
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无（并行测试排不上槽的建议见 keys2 交付单）

## 本分支提交

- 触屏存档键；插件按键对照
