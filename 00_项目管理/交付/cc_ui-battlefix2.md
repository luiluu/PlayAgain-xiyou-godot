# 交付：cc/ui-battlefix2（Kyo 11-06 实机战斗 2、3 条＋总装 EG 插队）

- 车道／工作者：界面（cc）
- 状态：进行中（WIP，测试还没跑：工作树 `elated-chatelet-b43f1e` 的 `新建工作树.sh --补齐` 在等 godot --import 槽）
- 说明：从 cc/ui-battlefix1 7b3f24db 切出，工作树 `.claude/worktrees/elated-chatelet-b43f1e`（分支 cc/ui-battlefix2）。

## 逐条（总装要求「报告第 N 项 → 复现测试名 → 修法」）

- **Codex 审查报告第 3 项（O-190 胜利提示关不掉）** → `tests/xiyou_victory_text_flow`（饿狼 5 阶 55 级、累计突破 340、记成 Boss 战，主循环自动打赢；结算页之后全用 `Input.parse_input_event` 发确定／左键，断言神之触媒提示显示并等待、确定能关、战斗发 `finished(0)`）→ 修法：`victory_screen.gd` 关结算页时 `set_process_input(false)`（`set_process(false)` 停不掉 `_input`，结算页留在画面上继续吞确定／取消／左键）。旧测 `xiyou_battle_log` 的 `victory_text_case` 直接调 `message._unhandled_input`，抓不到这个问题。**还没跑**。
- **报告第 7 项（battlefix1 鼠标）** → `tests/xiyou_battle_ui`：`mouse_pick_command`（改成真实事件：左键两下点指令窗第 2 行开技能列表）、新增 `mouse_wheel_list`（滚轮下滚）、`mouse_pick_list_row`（列表里左键选中行）、`msg101_click_*`（战斗 101 消息用左键翻页、关闭）。原测试直接调 `b._gui_input`。**还没跑**；若 `msg101_click` 挂，多半是 XBattleScene 全屏 MOUSE_FILTER_STOP 把左键在 GUI 阶段收下、消息窗 `_unhandled_input` 收不到，修法是 `_gui_input` 里消息窗忙时不收（或把左键转给 message）。

## 第 3 条「原版动作稍快」：根源是变速齿轮（总装定案：复现原版、不登 O 号、留开关）

- 原版 `Drill_SpeedGear`（v0.28 与 v0.62.12 都启用，「初始齿轮速度」1.6）在 `Game_System.initialize` 设 `SceneManager._deltaTime = 1/60/1.6`，MV `updateMain` 按累加器每真实秒跑 96 次 updateScene：地图、战斗、菜单整体快 1.6 倍。绑定变量关，数据里没有「>变速齿轮」指令，全程固定。声音：它覆写 `AudioManager.updateBufferParameters`，pitch ＋(1.6−1)×0.10＝＋0.06。
- 重制：新 `modes/xiyou/core/speed_gear.gd`（`XSpeedGear`，倍率只在这一处，读插件参数）：`physics_ticks_per_second = 60×1.6 = 96`、`time_scale = 1.6`、`max_physics_steps_per_frame` 同比、`AudioServer.playback_speed_scale = 1.06`。重制的地图（`map_scene._physics_process`、`mv_character`）、战斗（`_wait_frames` 等物理帧、`XSequencePlayer`）都按物理帧走，提高物理帧率就同比加快；`_process(delta)` 与计时器随 time_scale。入口 `entry.gd _ready` 调 `XSpeedGear.apply()`；`GameApp.return_to_menu` 还原（`XSpeedGear.reset()`）。headless 不设（测试按帧比对；快进照旧由 `fast_forward` 管），`HEADLESS_APPLY` 给专项用。回退：`XSpeedGear.ENABLED = false`。
- 专项 `tests/xiyou_speed_gear`：实例化 entry 后断言 96／1.6／1.06；真实 1 秒物理帧数在 86～106、等 60 帧 540～760 毫秒；开关关回 60。**还没跑**。
- 八戒的走路先不动（总装定），本单交付后再量剩余差距。
- 平台追赶（`XPlatform.start_catch_up`）存的是当时引擎值，还原时回到 96／1.6；追赶本身仍按 60×CATCH_UP_SPEED，没乘齿轮（可优化，见下）。
- 附带的逐帧对照：`tests/xiyou_battle_pace`＋`fixtures/battle_pace_oracle.json`（原版战斗夹具 4 人、敌群 2，两回合每次 startAction／endAction 的帧：角色普攻 45 帧、敌人 55 帧，行动之间 1～19 帧，回合交界 35 帧）。按帧比对，倍率之外的节奏差由它查。**还没跑**。

## 第 2 条 多段伤害数字

- 原版读数（本机 v0.62.12，`ui_reference` `__seqRef` 加了逐帧存活弹数 `pops`，见 `mac-preload-shim.js`）：3772 百式观音五式（5 段）、10250、104、2800、160、普攻，速度 4。结论：各段数字在各自 ACTION EFFECT 当帧出（WAIT 按倍速，速度 4 时 3772 每段隔 11 帧），之前的数字已经按轨迹上飘（隔 11 帧约 34 像素），所以错开是按时间、靠轨迹拉开位置；同一次结算的几个弹数（如 2800 的伤害＋第二个弹数）原版 `setupDamagePopup` 一帧只取一个，隔 1 帧出。
- 重制 `_popup` 在同一帧把一次结算的几个弹数全建出来（同位置），这是已确认的差；段与段之间的帧数是否对上看 `tests/xiyou_popup_multi`（`fixtures/popup_multi_oracle.json`，逐帧比 [_duration, x, y]）。**还没跑**。加上变速齿轮后，Kyo 看到的「叠在一起」可能部分来自整体慢 1.6 倍以外的差，跑完再定改法（若要改：每个战斗者一个弹数队列，每物理帧出一个）。

## 接续要点（给下一位）

1. 等补齐完成（日志在本会话 scratchpad `buqi.log`；或重跑 `zsh 03_再刷重制_Godot/07_开发环境/新建工作树.sh --补齐 <本工作树>`），然后单跑：`python3 并行测试.py ./godot ../01_Godot工程 --full xiyou_victory_text_flow xiyou_speed_gear xiyou_popup_multi xiyou_battle_pace xiyou_battle_ui xiyou_battle_log`（在 07_开发环境 下）。
2. `xiyou_battle_pace` 现在只打印两边日志并按差值比对，第一次跑多半会挂；用它找倍率之外的节奏差（入场 30 帧、行动之间的空档），不一定要求全对上，对不上的写进交付单。
3. `xiyou_popup_multi` 若只挂「同帧多弹数」，按原版做弹数队列（`battle_scene._popup` 入队，`_physics_process` 每帧每个战斗者出一个）。
4. 复查 m234、help_card 10622／10623：第二次同步（集成分支 cc/newsrc-switch）完成后协调会通知分支。
5. 交付前：`事件空绿扫描.py --check`、`语法检查.py`、`回退开关覆盖.py`；删临时产物（scratchpad 里的参照服务 8766 记得停）。

## 可优化（流程／工具／效率）

- 平台追赶倍速（`XPlatform.CATCH_UP_SPEED`）可以读 `XSpeedGear.rate()` 相乘，追赶时节奏与正常一致。

## 验证

- 还没跑任何 Godot 测试（导入在排队）。原版读数两份已取（本机 Chrome 无头，127.0.0.1:8766，冻结源只读）。
