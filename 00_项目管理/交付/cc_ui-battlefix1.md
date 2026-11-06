# 交付：cc/ui-battlefix1（Kyo 11-06 实机战斗界面 5 项）

- 车道／工作者：界面（cc）
- 状态：可合并（第 2、3 条另交，改到 cc/ui-battlefix2）
- 说明：从 main 02a1798c 切，工作树 `.claude/worktrees/ui-battlefix1`。1、4、5 已改；2（多段伤害数字叠在一起）、3（手感不如原版流畅）没做，见「接续要点」。

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】战斗界面：鼠标选指令／技能、倍速自动键不抢确认、空技能列表一行高（dev.待定）

- **鼠标选不了战技等**（Kyo 实机 1，重制自己的错）：`XBattleScene` 铺满全屏、`MOUSE_FILTER_STOP`，点击在 `_gui_input` 就被收下，指令窗与技能／物品列表的 `_unhandled_input` 收不到鼠标。现在不在选目标时，左键与滚轮转给开着、可操作的列表（先技能／物品列表，再指令窗；坐标换成窗口父节点坐标），照 Window_Selectable：点别的行选中，再点选中的行确定。右键照旧取消。
- **确认时顺带切倍速／自动**（Kyo 实机 5，重制自己的错）：左上「自动」「变速」按钮（O-006 重制自加）被鼠标点过后留着键盘焦点，空格／J（ui_accept）先按到按钮。按钮改 `FOCUS_NONE`，只认鼠标。
- **没有技能时框只露一半**（Kyo 实机 4，O-待定·空列表一行高，`XBattleList.EMPTY_ONE_ROW`，默认开）：原版 Olivia_SideBattleUI `maxListHeight＝min(项数, 上限)`，空列表窗口高只剩上下内边距（22），只露出半截框；重制照搬了。开着时空列表按一行高画（空白一行），关＝照原版。
- 测试：`xiyou_battle_ui` 加 `mouse_pick_command`（左键点指令窗第 2 行两次→开技能列表，滚轮不报错）、`speed_auto_no_focus`、`empty_list_one_row`／`empty_list_v028`。

## 交接板

- 下一步：Kyo 实机 2、3（见接续要点）。
- 用户试玩说明：战斗里可以用鼠标点指令和技能（点一下选中、再点一下确定）；点过「自动」「变速」后再按空格／J 不会再误切；没有魔法的角色点「魔法」时框是完整一行。
- 需要用户决定：O-待定·空列表一行高（默认开）。

## 优化登记

| O-待定·空列表一行高 | `battle/battle_list.gd` `XBattleList.EMPTY_ONE_ROW`（`create`） | 原版：战斗技能／物品列表没有项时窗口高＝上下内边距，只露半截框 | 空列表也按一行高画 | Kyo 11-06 实机反馈 | `XBattleList.EMPTY_ONE_ROW = false` | cc（界面 battlefix1） | 待用户决定 |

## 接续要点（给下一位）

1. **多段伤害数字同时出现、叠在一起**（Kyo 实机 2；协调：原版错开显示，以原版为准）：没查完。弹数字在 `battle_scene.gd` `_popup`／`_show_hit`；`damage_popup.gd` 头注写了原版 LGP_BetterDamagePopup 读数，YEP Popup Overlap Rate 0.9「实际不起作用」（`tests/fixtures/popup_anchor_oracle.json`）。要先在原版量一个多段技能（如 repeats>1 的普通技能、带动作序列的多段技能）各段弹数字的出现帧和位置：现成驱动 `popup_anchor_ref.py`（加 XIYOU_APP＝v0.62.12）。确认原版是按时间错开（逐段 wait）还是按位置错开，再改；和原版不同的部分挂开关登记 O-待定。
2. **手感不如原版流畅**（Kyo 实机 3）：没查。可先看 project.godot 的 physics_ticks_per_second／max_fps／vsync、`_wait_frames` 用 physics_frame 等待、弹数字与 side_status 在 `_physics_process` 里每帧整块 queue_redraw、动画补间是否逐 physics 帧跳（60Hz 物理＋高刷屏会抖）。Kyo 11-07 答：「感觉是原版动作稍快一点的原因」——先在原版逐帧对行动节奏（`ACT_*` 帧常数、动作序列 wait、倍速档位、SV 动作帧速），再改。第 1 条 Kyo 同意去原版量（「去吧」）。

## 可优化（流程／工具／效率）

## 验证

- 本机（产物由 `新建工作树.sh` 从主工作区补齐）：`xiyou_battle_ui` 159/159（新 4 项）；反向验证：去掉转发与 FOCUS_NONE 后 `mouse_pick_command`、`speed_auto_no_focus` 挂，已还原。`语法检查.py` 通过；`事件空绿扫描.py --check` 空绿 55 均在基线内。没跑别的专项：改动只在战斗界面输入与空列表高度，`选测.py main --list` 会因 battle_scene 带出大片楼层场景，交总装按影响面选测。

## 待交叉核查

- `battle/battle_scene.gd`（`_gui_input`、`_mouse_to_window`、`_small_button`）、`battle/battle_list.gd`（EMPTY_ONE_ROW）、`tests/xiyou_battle_ui.gd`。
