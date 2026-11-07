# 交付：cc/ui-input1

- 车道／工作者：B 界面·输入（cc，项目线程「完成再刷西游Godot引擎重制」），总装派单：Codex 审查报告第 13～16 项，追加 rules-bugfix1 照搬清单第 1～3 条
- 状态：进行中

## 逐条对应

派单说的报告附件没传到本线程，按派单原文里的位置和要求做。

| 来源 | 复现测试（在旧代码或回退开关下会挂） | 修法 | 开关 |
| --- | --- | --- | --- |
| 报告第 13 项（`touch_controls.gd`、`shop.gd` 的确认） | `xiyou_ui_input`：`13_ok_hold_confirms_once`、`13_stick_hold_one_press`、`13_stick_hold_repeats_as_echo`、`13_hold_does_not_carry_to_next_scene`（旧代码：按住确定 60 帧算 7 次确认，方向连发 7 次「新按下」、0 次回显） | 确定、取消按住不再连发，要松开再按；方向按住 24／6 帧的连发改成方向键回显（`is_echo()` 为 true，带标记让 `XKeyRepeat` 放行）；按着时换了场景回显停下。`xiyou_platform` 的 `hold_repeats` 改成 `hold_ok_no_repeat` | `XTouchControls.HOLD_REPEAT_ECHO`，O-待定 |
| 报告第 14 项（`web_panel.gd`、`casino_dialog.gd` 的取消） | `xiyou_ui_input`：`14_virtual_cancel_*`、`14_back_key_*`、`14_pad_b_*`、`14_x_key_*`、`14_casino_*_cancels`（旧代码只认 Esc，全挂） | 新增 `XKeyMap.popup_cancel`：Esc 以外也认 ui_cancel（虚拟取消键、安卓返回键、手柄 B、X／K／Insert）；输入框有焦点时，会打出字的键（X、K、小键盘 0）归输入框，Esc、虚拟取消、返回键、手柄 B 照样关 | `XKeyMap.POPUP_CANCEL_ACTION`，O-待定 |
| 报告第 16 项（`entry.gd` 的 `_load_auto`） | `xiyou_ui_input`：`16_title_has_cursor`（旧代码挂） | 光标和初始选中搬回 `_title()` 末尾，`_load_auto()` 只留读档和跳转 | 无（修复回归，不是改行为） |
| 报告第 15 项（`mv_tilemap.gd` 水面重绘） | `xiyou_tilemap_chunks`：`chunked_water_tick_redraws_view_only`、`chunked_offscreen_not_drawn`；回退开关那一轮断言旧行为「每次换水面整张 2×150×150 格重画」 | 先实测确认有问题（见下），再改成按 16 格分块：每块一个静态节点（进画面时画一次）和一个水面节点（只画含 A1 的格），换水面帧只重画画面内的水面节点。同一格里水面节点画到最后一个 A1 图块，静态节点画其余，格与格不重叠，所以叠放次序不变 | `MVTilemap.CHUNKED` |
| 照搬清单第 1 条（`hang_up_overlay.gd` 挂机提示） | `xiyou_hangup`：`tip_word_drawn`、`tip_word_rollback_none` | 照原版 drawWord 把 huWord「摆烂中.....」用 huColor 画在提示上（0,30 宽 560 行高 30 居中，28 号），跟提示一起 160 不透明度 | `XHangUpOverlay.TIP_WORD`，O-待定 |
| 照搬清单第 2 条（`boss_hp_bar.gd`） | `xiyou_boss_hp_bar`：`rebuild_transform_name`、`rebuild_transform_face`、`rebuild_late_boss_builds`，`rebuild_off_*` 断言原版行为 | 条跟着的敌人编号变了就换名字和头像；开战没有 Boss 的，每帧按开战规则再挑一次，敌人现身或变身成 Boss 就建条 | `XBossHpBar.REBUILD`，O-待定 |
| 照搬清单第 3 条（`map_transfer.gd`） | `xiyou_transfer`：`detail_keeps_drop_selection`（真实按键：下、左、E）、`detail_rollback_moves_drop` | 掉落详情开着时，方向键和 Q/E 翻页不再动后面的掉落框 | `XMapTransferScene.DETAIL_LOCKS_DROPS`，O-待定 |

第 13、14、16 项的「旧代码会挂」是实际跑过的：把两个开关临时改成 false、`entry.gd` 换回 main 版，跑 `xiyou_ui_input` 挂了 13 项，结果见上表；之后已还原。

## 第 15 项实测数据

无头，本机 M1 Pro，天之上 Map069（150×150，A1 图块 18784 格），上下两层 MVTilemap，跑 180 帧，另做一轮每帧平移（模拟走动）：

| | 换水面帧（每 30 帧） | 首帧 | 画布命令占内存 | setup |
| --- | --- | --- | --- | --- |
| 原先整张画 | 320～480 毫秒，每 30 帧一次 | 320～460 毫秒 | 约 8.5 MB | 60～90 毫秒 |
| 分块 | 不再卡顿，180 帧里最长一帧 10～16 毫秒 | 11～14 毫秒 | 0.2～0.9 MB | 160～195 毫秒 |

结论：问题确实存在（玩家在天之上每半秒卡一次），已修。代价是进图时 setup 多 100 毫秒左右（要找哪几块有水面），只在换图时一次。

## 变更记录草稿

## 2026-11-07 【cc·界面输入·未经审查】触屏连发、弹层取消、标题光标、天之上水面卡顿，及三条原版界面缺陷（dev.待定）

- 审查报告第 13 项：虚拟确定、取消键按住不再连发，松开再按才算第二次；虚拟方向键按住的连发改成回显事件，换场景即停（`XTouchControls.HOLD_REPEAT_ECHO`，O-待定）。
- 第 14 项：网页面板和批量抽奖窗认虚拟取消键、安卓返回键、手柄 B 和 X 键；输入框里打字的键归输入框（`XKeyMap.POPUP_CANCEL_ACTION`，O-待定）。
- 第 16 项：标题光标回到 `_title()`，原先误放在读自动存档里，标题上没有光标。
- 第 15 项：天之上（150×150）实测每 30 帧卡 320～480 毫秒，地图改成分块绘制、只重画画面内的水面，最长一帧降到 16 毫秒内（`MVTilemap.CHUNKED`）。
- 原版缺陷（rules-bugfix1 照搬清单 1～3）：挂机提示显示「摆烂中.....」（`TIP_WORD`）；Boss 变身换血条名字头像、后现身的 Boss 补建血条（`REBUILD`）；传送页掉落详情开着时方向键不再动后面的框（`DETAIL_LOCKS_DROPS`），各 O-待定。
- 新专项 `xiyou_ui_input`、`xiyou_tilemap_chunks`；改 `xiyou_platform`、`xiyou_hangup`、`xiyou_boss_hp_bar`、`xiyou_transfer`。
- 玩家可见：手机上按住确定不会连买；网页面板、抽奖窗能用返回键关；标题有光标；天之上不再一卡一卡；挂机时提示上有字；Boss 变身后血条名字跟着换。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 触屏虚拟键按住连发（`core/touch_controls.gd`，`core/key_repeat.gd` 放行） | 原版二合一包虚拟键按住时确定、取消、方向都按 24／6 帧重复「新按下」 | 确定、取消不连发，松开再按才算第二次；方向连发改成回显（echo），换场景即停 | 商店等只认新按下的确认会被连按（Codex 审查报告第 13 项） | `XTouchControls.HOLD_REPEAT_ECHO = false` | cc（界面输入） | 待用户决定 |
| O-待定 | 弹层取消键（`XKeyMap.popup_cancel`；`ui/web_panel.gd`、`ui/casino_dialog.gd`） | 原版网页覆盖层只认 Esc | 也认虚拟取消键、安卓返回键、手柄 B、X 等；输入框有焦点时打字键归输入框 | 手机上关不掉面板（Codex 审查报告第 14 项） | `XKeyMap.POPUP_CANCEL_ACTION = false` | cc（界面输入） | 待用户决定 |
| O-待定 | 挂机提示的字（`map/hang_up_overlay.gd`） | drawWord 把「摆烂中.....」画进离屏画布，字从不显示 | 照 drawWord 的位置、颜色把字画上 | 原版缺陷（rules-bugfix1 照搬清单第 1 条） | `XHangUpOverlay.TIP_WORD = false` | cc（界面输入） | 待用户决定 |
| O-待定 | Boss 血条重建（`battle/boss_hp_bar.gd`） | 变身后名字头像仍是旧编号；开战没有 Boss、之后现身的不建条 | 编号变了换名字头像；没建条时每帧再挑，现身或变身成 Boss 就建 | 原版缺陷（rules-bugfix1 照搬清单第 2 条） | `XBossHpBar.REBUILD = false` | cc（界面输入） | 待用户决定 |
| O-待定 | 传送页掉落详情（`ui/map_transfer.gd`） | 详情开着时方向键、Q/E 仍移动后面的掉落框 | 详情开着时这些键不动后面的框 | 原版缺陷（rules-bugfix1 照搬清单第 3 条） | `XMapTransferScene.DETAIL_LOCKS_DROPS = false` | cc（界面输入） | 待用户决定 |

## 交接板

- 下一步：无新增。总装给 5 个 O-待定分号（HOLD_REPEAT_ECHO、POPUP_CANCEL_ACTION、TIP_WORD、REBUILD、DETAIL_LOCKS_DROPS）。
- 用户试玩说明：见变更记录「玩家可见」。
- 需要用户决定：无。

## 验证

- 专项（本工作树合 main b206af0d 后）：待填
- `语法检查.py`：604 个 .gd，0 个问题。
- `工具回归.py`：全部通过。
- `事件空绿扫描.py --check`：空绿 55 例，都在基线内。
- 选测说明：`选测.py main --list` 因 `entry.gd` 归「拿不准」给出整轮；车道不跑全量，按改动手选上面的场景，其中包含 map 类改动要求的 `xiyou_event_compare` 和两个楼层专项。总装合并时按影响面再选。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 给 `modes/xiyou/entry.gd` 配一组（`xiyou_entry_release`、`xiyou_reincarnation_entry`、`xiyou_ui_input`、`xiyou_platform`），免得改标题页就判整轮（收益：标题小改不用跑全量；归工具车道）。
- 建议：派单说「附件」时，把报告放进仓库或项目库，线程里收不到附件（本单没收到，只能按派单原文做）。

## 本分支提交

- 030df8f2 第 13、14、16 项及 `xiyou_ui_input`
- 13dfa4ca 第 15 项分块绘制
- （后续）`xiyou_tilemap_chunks`、照搬清单 1～3、合 main、uid
