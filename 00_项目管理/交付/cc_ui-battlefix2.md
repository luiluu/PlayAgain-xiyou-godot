# 交付：cc/ui-battlefix2（Kyo 11-06 实机战斗 2、3 条＋审查第 3、7 项）

- 车道／工作者：界面（cc）；前半由 `elated-chatelet-b43f1e` 的会话做到 61ed3ac7，接棒后在 `zealous-rubin-9a80c1` 续做
- **合并点：分支 `cc/zealous-rubin-9a80c1`**（含 cc/ui-battlefix2 61ed3ac7 全部提交，已并入 main）
- 状态：见文末「验证」

## 逐条：报告项 → 测试名 → 修法

- **审查第 3 项（O-190 胜利提示关不掉）** → `tests/xiyou_victory_text_flow`（饿狼 5 阶 55 级、累计突破 340、记成 Boss 战，主循环自动打赢；结算页之后全用 `Input.parse_input_event` 发确定／左键，断言神之触媒提示显示并等待、确定能关、战斗 `finished(0)`）→ `victory_screen.gd` 关结算页时 `set_process_input(false)`（`set_process(false)` 停不掉 `_input`，结算页留在画面上继续吞确定／左键）。测试第一次跑没出结算页，是测试自己的问题：`logic.auto` 设晚了（主循环已经停在指令窗等输入），改在 `add_child` 前设；`return finish(b)` 改成 `await`。
- **审查第 7 项（battlefix1 鼠标）** → `tests/xiyou_battle_ui` 的 `mouse_pick_command`、`mouse_wheel_list`、`mouse_pick_list_row`、`msg101_click_*`，全部改成 `Input.parse_input_event` 真实分发。**battlefix1 的 mouse_pick 只在直调 `_gui_input` 下成立**：
  - 真实分发下两项不过的第一个原因在测试环境：headless 的根视口只有 64×64，点在外面 GUI 收不到。`_mouse` 点的时候把根视口临时设成 1280×720（同游戏窗口），点完还原。
  - 第二个是真问题：**战斗里 101 消息用鼠标左键翻不了页**——`XBattleScene` 全屏 `MOUSE_FILTER_STOP`，左键在 GUI 阶段被场景收下，消息窗的 `_unhandled_input` 收不到。修法：`_gui_input` 里消息窗忙时把鼠标键转给消息窗。
  - `mouse_pick_list_row` 原来点的正好是光标所在行（等于确定、列表被关），改成挑一行光标不在的。
- **Kyo 实机 2「多段伤害数字叠在一起」** → `tests/xiyou_popup_multi`（正式版逐帧读数 `fixtures/popup_multi_oracle.json`：3772、10250、104、2800、160、普攻，速度 4）。改法都在 `battle_scene.gd`／`damage_popup.gd`：
  1. 每个战斗者每帧只出一个弹数（`POPUP_QUEUE`，原版 `setupDamagePopup` 一帧取一个）：同一次结算的几个弹数隔帧出。行动序列里在本帧结算之后出（`XSequencePlayer` 在 `_step` 后调 `flush_popups`），先后照原版战斗者精灵顺序（画面 y，同 y 敌人在前）。伤害数字关着时不出。回退：`XBattleScene.POPUP_QUEUE = false`（同帧全建，`popup_multi` 的 `switch_off` 测这一支）。这是复现原版，不登 O 号。
  2. 状态行：原版 `drawDefaultState` 的绘制整段被注释掉，只剩空精灵，看不见，但照样占一帧队列、活 90 次。重制建一个不画的占位（`XDamagePopup.setup_state`）。
  3. `hpAffected` 时伤害为 0 也弹「0」（LGP 按 hpAffected 拷 HP 行；10250 在这个夹具里打 0，原来不弹）。
  4. 建出当帧更新一次（原版首帧就是 [89, −0.3, 0.7]）；走完后要等下一次 update 开头才 remove；在 Spriteset 的 children 循环里被摘掉时，紧跟其后加入的那个弹数这一帧少更新一次（`skip`）。
  - 连带改的测试：`xiyou_battle_log`、`xiyou_regen_popup`、`xiyou_battle_options`、`xiyou_popup_overlap` 里同帧连弹几个再数的地方加 `drain_popups()`；`popup_overlap` 的锚点轨迹少手动更新一次（建出当帧已更新）。
  - 测试取数照原版读数口径：去掉每个战斗者第一个已走完（`_duration ≤ 0`）的弹数（原版 `_damages.shift()`）。**剩一处不比**：不画的状态占位走到最后 2 次时（s2800 e0 第 165 帧），原版谁被「跳一次」还取决于同帧加进 Spriteset 的其它精灵，没逐个仿；它看不见，也不影响数字位置。
  - Kyo 看到的「叠在一起」：原版各段数字也是在同一个点出、靠时间错开（3772 速度 4 时每段隔 11 帧，前一个已飘出约 34 像素）；重制原来同一次结算的几个数字同帧同点，加上整体慢 1.6 倍，看着更挤。
- **Kyo 实机 3「原版动作稍快」= 变速齿轮 1.6** → `tests/xiyou_speed_gear`（复现原版，不登 O 号，回退 `XSpeedGear.ENABLED = false`）。
  - 原版 `Drill_SpeedGear`（「初始齿轮速度」1.6、不绑变量、数据里没有改速指令）在 `Game_System.initialize` 设 `SceneManager._deltaTime = 1/96`，`updateMain` 的累加器每真实秒跑 96 次 `updateScene`。
  - 重制 `XSpeedGear`：`physics_ticks_per_second = 96`、`time_scale = 1.6`；入口 `entry.gd` 设，`return_to_menu` 还原。物理帧 delta 仍是 1/60，逐帧逻辑按物理帧数走、计时器与补间按 time_scale 走，都快 1.6 倍。
  - **查出一处没跟上**：地图事件「等待 N 帧」（230）和震屏的等待原来按渲染帧（`process_frame`），不跟物理帧率：60 Hz 屏上等 60 帧要 1 秒（原版 0.625 秒），120 Hz 屏上只要半秒。改成物理帧（`MVInterpreter._wait_frame`）。headless 测试照旧按渲染帧（`HEADLESS_RENDER_WAIT`：headless 物理帧按真实时间走，几百个事件测试会慢十几倍，第一次云端跑 event_compare 超时、dungeon 从 28 秒到 462 秒），专项里关掉它量真实节奏。
  - 其余按帧走的地方（地图 `_physics_process`、`mv_character`、战斗 `_wait_frames`、`XSequencePlayer`、弹数）都在物理帧上；`_process` 里按帧计数的只有纯画面的（图块动画、选中闪烁），没动。
- **实测三段（总装要求，原版和重制各量）**：原版用 `03_转换工具/ui_reference/speed_gear_ref.cjs`（冻结正式源、无头 Chrome，三次），重制用 `xiyou_speed_gear`（headless 下设 96／1.6）。

  | 项目 | 原版 | 重制 |
  | --- | --- | --- |
  | 每真实秒的帧数 | updateScene 96.2／97.3／97.6 次 | 物理帧，专项断言 96 ± 5%（先空转 0.5 秒再量 2 秒；第一次跑量到 107.7 是入口卡顿后追帧） |
  | 事件「等待 60 帧」 | 61 次 updateScene，598／571／727 毫秒 | 60 物理帧，609 毫秒 |
  | 玩家走 10 格（速度 4、不奔跑） | 每格 8 次（`distancePerFrame` 0.125，含 rpg_objects 的 ×2）；量到 9 格 74 次，657～800 毫秒 | 每格 16 帧（0.0625，×2 由八戒改 `move_distance_scale` 2.0），10 格 161 帧 1683 毫秒＝161／96 秒；只对 1.6 倍这部分 |
  | 战斗普攻（角色，startAction→endAction） | 46 次（无头 Chrome 软件渲染慢时 580～1395 毫秒，理论 0.48 秒） | 46 物理帧，410 毫秒 |

- **声音 1.06 的依据**：原版那份插件生效的是覆写后的 `AudioManager.updateBufferParameters`：`buffer.pitch = audio.pitch/100 + (齿轮 − 1) × 同步率`（同步率参数 0.10，覆写版不看「声音是否变速」开关）。MV `WebAudio` 的 pitch 就是 `playbackRate`，所以**音高和播放速度一起快 6%**（pitch 100 的声音 1.06 倍）。重制 `AudioServer.playback_speed_scale = 1.06` 也是两者一起变；原版是加在各自 pitch 上，pitch 不是 100 的声音差不到 2%（150 时原版 1.56、重制 1.59）。
- **战斗节奏**（`tests/xiyou_battle_pace`，正式版夹具两回合每次 startAction／endAction）：只断言每次行动演出的时长（角色、敌人各自排序后逐个比，容差 1 帧：两边起止钩子差一帧，角色普攻 46 对 45）。**对不上、没断言的**：行动先后不同（第 2 次行动原版是 e0，重制是 a9；同速时谁先，属规则车道），行动之间的空档原版 1 帧、重制 0 帧，第 8 次前原版空 18 帧。测试把这些打成 `PACE_DIFF` 行。另外正式版第 3 回合 a9 有一次行动 111 帧（1154→1265，别的都是 54），重制没有对应的长行动，原因没查，不比，打成 `PACE_LONG`（可派规则车道看）。

## race_poison 3 项（总装要求查是不是本单引起）

- **是本单引起的，已修**：main ab80ca89 云端整轮（444 场景）`xiyou_battle_ui` 是过的。本单新加的 `msg101_click` 排在 `_race_ui` 之前，消息没关掉（见下）就一直开着，后面的选敌说明卡跟着错。
- `msg101_click` 没关掉的原因在测试：消息停住后还有几帧 `_wait`（Window_Message.updateWait，期间不收输入，原版同），一次点击连同设根视口要 6 帧，后两下都落在等待里。改成等 `_wait` 走完再点。改完本机直跑 `xiyou_battle_ui` 164/164。

## 接续要点

- 复查 m234、help_card 10622／10623：等同步失败表（协调转）。

## 可优化（流程／工具／效率）

- 本机测试槽有一回 40 分钟里没有 godot 在跑：集成分支整轮同步占着 4 个槽跑 node 探针，看着像空占。`并行测试.py` 的心跳行可以写出槽被谁占、在跑什么（进程名＋工作树），等的人就知道该转 `--cloud`。
- headless 根视口只有 64×64：所有用真实鼠标事件的测试都得先把根视口设成 1280×720。可以在 `tests/test_main_loop.gd` 的 `_initialize` 里统一设，但会改变现有 headless 测试里的 `_origin` 等，要整轮验，没在本单做。

## 验证

- 本机单跑（会话中）：`xiyou_speed_gear` 10/10（实测见上表）、`xiyou_popup_multi`、`xiyou_popup_overlap`、`xiyou_regen_popup` 过。
- 云端选测：见下一次提交补的结果。
