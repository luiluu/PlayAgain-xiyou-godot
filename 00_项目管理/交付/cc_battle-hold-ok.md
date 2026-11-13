# 交付：cc/battle-hold-ok

- 车道／工作者：战斗按住确定连发（玩家反馈）／cc
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】战斗按住确定连续出招（键盘与虚拟确定键）（dev.待定）

- 玩家反馈：原版战斗里按住空格／J 不放，技能列表和选目标会一路确认、连续出招；重制版按住会停在选目标。查过不是回归：dev.476（v0.01.06 包）里就这样。原版选敌／选我方窗是 `Window_Selectable`，`isOkTriggered`＝`Input.isRepeated('ok')`（按住 24 帧后每 6 帧一次）；重制的技能列表 `XBattleList` 认回显，选目标（`battle_scene._unhandled_input` 的 `_target_mode` 分支）只认新按下。
- 键盘：选目标的确定、取消改成也认回显（`XBattleScene.HOLD_OK_TARGET`），按住确定从指令窗、技能列表一路确认到目标，节奏照原版 24／6 帧（`XKeyRepeat`）。
- 安卓虚拟确定键：O-225 之后按住一点不连发（原版 `Mehmet_GhostButtons` 也是 24／6 帧连发）。现在按住确定照方向键的做法发回车的回显（`XTouchControls.HOLD_OK_ECHO`）：商店、标题这类只认新按下的页面照旧只确认一次（O-225 的目的不变），认回显的地方（战斗技能列表、选目标、对话框、遗忘技能页，与键盘按住一致）按原版节奏连发；换场景即停，松开补发回车松开（回显会把 ui_accept 记成键盘按着，同 ui6 的方向键）。
- 测试：`xiyou_ui_input` 第 13 项改为按住确定＝一次新按下＋回显、轮询 `is_action_just_pressed` 只触发一次、松开后不再按着、换场景停，回退开关两边；`xiyou_battle_ui` 加选目标认确定／取消回显与回退支。
- 玩家可见：战斗里按住确定（空格、J、回车或手机上的确定键）可以连续选技能和目标出招，和原版一样。

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/battle_scene.gd` `XBattleScene.HOLD_OK_TARGET`；`core/touch_controls.gd` `XTouchControls.HOLD_OK_ECHO` | 选目标窗确定、取消认按住连发（24／6 帧）；虚拟按键按住确定也连发「新按下」 | 照原版：选目标认回显；虚拟确定键按住发回车回显，只认新按下的页面不受影响（保留 O-225 防连买） | 玩家反馈 v0.01.06：按住空格／J 不能连续出招 | `XBattleScene.HOLD_OK_TARGET = false`（选目标只认新按下）；`XTouchControls.HOLD_OK_ECHO = false`（虚拟确定键按住不连发） | cc | 保留 |

## 交接板

- 下一步：无。
- 用户试玩说明：战斗里按住空格／J（手机按住确定）不放，会一路确认技能和目标、连续出招。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：选测把 `battle_scene.gd` 一律当「其它游戏模块」扩成 121 个场景；只改输入分支时按引用 `_target_mode`／`_unhandled_input` 的测试选就够（预计每次省一轮大选测），归工具车道。
- 另：取消键按住在战斗里原版也连发，虚拟取消键这次没改（O-225 仍不连发），没人报，先不动。

## 验证

- 语法检查通过。
- 选测 12 个全过：`xiyou_ui_input`、`xiyou_battle_ui`、`xiyou_battle_pixel`、`xiyou_guyu_ui`、`xiyou_yunshang_ui`、`xiyou_map_hotkeys`、`xiyou_platform`、`xiyou_determinism`、`xiyou_popup_overlap`、`xiyou_battle_options`、`xiyou_boss_status`、`xiyou_feedback_v001`。`选测.py` 按 `battle_scene.gd` 列了 125 个（楼层、事件对照等），改动只在选目标的按键分支和虚拟键，没跑那批，合并时按影响面补。
- 反向验证 4 项全咬住：选目标确定／取消不认回显、虚拟确定不发回显、松开不补回车松开。
- 没有实机试（安卓、键盘按住），按「不等 Kyo 实测」交。

## 本分支提交

- d2eb85ef3 战斗按住确定连发（选目标认回显、虚拟确定键回显）
