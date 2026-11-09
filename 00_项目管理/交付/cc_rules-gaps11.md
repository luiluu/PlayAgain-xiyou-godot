# 交付单 cc/rules-gaps11（GB9）

状态：**可合并（待云端选测结果，见文末）**。①参照＋逐帧对齐完成；②淡出淡入／闪烁的战斗画面截图对照完成，状态图标／伤害数字／Boss 血条场面没做（见「没做的」）。注意本分支基于 cc/rules-gaps10（再往前是 gaps9），要在 gaps9／10 合进 main 之后再合。

分支 cc/rules-gaps11，从 cc/rules-gaps10 头 4a0c3d38 切。在 scratchpad 的 `git clone --shared` 里做（会话没有自己的 worktree），已推回本库。

## 已做（未测）
- 新 `modes/xiyou/battle/battle_screen.gd`（XBattleScreen）：照 Game_Screen 的 updateFadeOut／updateFadeIn／updateFlash 逐帧推进亮度与闪烁强度，画 _flashSprite、_fadeSprite 两层（先闪烁后黑幕）。事件当帧不推进（原版 Scene_Battle.update 先 $gameScreen.update 再跑事件）。
- `battle_scene.gd`：combo 之后、伤害记录和 ui 之前加 screen_fx（原版层次：spriteset 里，压在 MOG hudField／Star_Record／窗口层之下）；不进 _cam_base；_physics_process 每帧 step；_play 认 `event_view` → `_event_view`：221/222 起 24 帧淡出淡入并等 24 帧，224 起闪烁、勾等待才等。
- `battle_event_runner.gd`：224 闪烁画面在战斗里记 `event_view`（flash/duration/wait），原来落到通用跳过（小明基因锁 CE1551～1554 的红闪）。
- 223 色调：战斗里碰得到的数据全是 0（CE10 复原 0；地图唯一非零 Map004 事件 76 演完复原，中间不开战），不画，写在 battle_screen.gd 文件头。
- `tests/xiyou_battle_ui.gd` 加 `_screen_fx`（读 `tests/fixtures/battle_screen_fx_oracle.json`，**这个参照文件还没有**，测试现在会挂 screen_fx_oracle）。
- 参照脚本 `03_转换工具/ui_reference/battle_screen_fx_ref.cjs`（照 battle_pace_ref.cjs：serve.py＋无头 Chrome，战斗夹具 4 人，独立 Game_Interpreter 跑 221→101→222→224→230，逐帧记亮度／黑幕不透明度／闪烁、截 gb9_input、gb9_fade_f12／f24、gb9_fade_message、gb9_flash_f5／f15）。

## 接续要点
1. 参照脚本第一次跑到「等消息窗 pause」超时（60 秒没等到；f12/f24 截图已出）。已改成固定等 110 帧后记消息窗状态（out.mw），**改后的版本还没跑成**（等槽被收工打断）。先查为什么消息窗在指令输入阶段没开：可能 Scene_Battle 输入阶段 Window_Message 不 update，必要时先关指令窗（`_actorCommandWindow.deactivate()`）或改在回合中跑。
2. 跑法：`python3 -I serve.py <app.nw> <输出目录> &`，`占槽.py --label gb9-ref -- node battle_screen_fx_ref.cjs <输出>/gb9_ref.json`。数据压成 tests/fixtures/battle_screen_fx_oracle.json（frames 每行 [k, 指令下标, 亮度, 黑幕不透明度, 闪烁强度, 闪烁层不透明度, 消息忙, 消息窗开度]），核对 `_screen_fx` 的帧对齐（消息开始帧 marks.msg 对 ref_msg-1 的假设要按数据校）。
3. 先 `新建工作树.sh --补齐`（主工作区那份）补齐这个 clone，跑 parse／`xiyou_battle_ui` 选测。注意新类 XBattleScreen 要进 global_script_class_cache（导入一次）。
4. ② 战斗画面对照：Godot 窗口模式 `xiyou_battle_ui -- --out=<目录>` 出 battle_40_input、battle_60*_fade/flash，和原版 gb9_* 逐像素比（没装 PIL，用 Godot Image 或纯 Python PNG 解码）。还没挑状态图标／伤害数字／Boss 血条的场面。
5. 收尾：回退开关（若要，按回退开关测试约定）、变更记录草稿、可优化、回报 @parent。

## 变更记录草稿
- dev.待定（rules-gaps11，八戒）：战斗里的事件指令 221 淡出、222 淡入、224 闪烁画面真的演出来了（原来 224 落到通用跳过，221／222 只等不画）。新 `XBattleScreen` 照 Game_Screen 逐帧推进亮度与闪烁，画在战斗画面之上、Boss 血条／伤害记录／窗口之下，不随镜头；事件等待按原版 wait(n) 的 n＋1 帧。原版参照 `battle_screen_fx_ref.cjs` → `tests/fixtures/battle_screen_fx_oracle.json`，`xiyou_battle_ui` 的 `_screen_fx` 逐帧比淡出／淡入／闪烁与消息开始帧；截图对照 `battle_screen_fx_compare.py`。223 色调战斗里数据全是 0，不画。

## 可优化
- 无头测试里「按一次键等几个空闲帧」不可靠：无头时一个物理帧里会跑好几个空闲帧，`_press` 的 2＋2 空闲帧可能落在同一个物理帧里，读物理帧输入的窗口（消息窗）几次按键只算一次。`tests/xiyou_battle_ui.gd` 的 `_press` 可考虑改成等物理帧（本条只在 `_screen_fx` 里绕开，没改公用的 `_press`，免得动其他用例的帧数）。
- 测试槽很挤：一条只读的浏览器参照（几十秒）排了约 28 分钟。轻量的浏览器参照可考虑单独的轻槽，不和 Godot 测试抢。

## 接续（11-09 21:30，第二位八戒；额度紧，总装叫停）

- 分支头 6c3fb0647（本条记录提交之后为新头）。**本会话没改代码**：切了分支、读了交接要点，起了 `--补齐` 和原版参照，都被叫停中断。
- `--补齐` 没跑完（被停），下一位重跑一次即可，不用清理。
- 原版参照 `battle_screen_fx_ref.cjs` 在测试槽里排了 8 分钟没轮上就被停，**一次都没跑**，所以上面「接续要点」第 1 条（消息窗在指令输入阶段没开）仍未查明；`tests/fixtures/battle_screen_fx_oracle.json` 仍没有，`xiyou_battle_ui` 的 screen_fx_oracle 现在会挂。
- 下一步照上面「接续要点」1～5 原样做。建议排槽时避开合并长任务；参照服务 `serve.py` 已关，8766 端口空着。
- 没有跑到一半的东西。不可合并。

## 第三位八戒（11-09 22:50 起）

- `--补齐` 用 `长任务.py start` 重跑，41 秒完成；语法检查 660 个 .gd 0 问题。
- 原版参照跑成（等槽这次 1 分钟内就轮上）：消息窗**其实开了**（out.mw：open 255、pause、busy、y 274、指令下标 3），第一次的超时是旧版脚本等 pause 的写法问题，不是输入阶段不开消息窗。压成 `tests/fixtures/battle_screen_fx_oracle.json`（frames 201 行＋order／shots／mw）。
- 原版逐帧：221 在 k=1、k=2 起变暗、k=25 到 0；101 在 k=26 开始（消息忙）；222 在 k=119（terminateMessage 当帧，消息窗还在合）、k=143 回到 255；224 在 k=144，k=174 闪烁到 0。场景层次：spriteset（base → pictures → timer → flash → fade）之后才是 hudField、windowLayer，和 battle_screen.gd 文件头写的一致。
- 对齐修正：原版 wait(n) 之后 n 帧都在 updateWaitCount 空转、第 n＋1 帧才跑下一条，Godot `_event_view` 原来等 n 帧，消息早一帧开始（screen_fx_message_after_24 [24,26]）；改成等 n＋1（淡出淡入、勾了等待的闪烁）。
- 测试修正：`_screen_fx` 关消息窗只按一次确定、且只数空闲帧——无头时一个物理帧里会跑好几个空闲帧，几次按键挤进同一物理帧只算一次，消息没关上，连带 race_poison_card 三项失败；改成每按一次等 3 个物理帧、最多 5 次。trace 分段原来把淡出当成淡入，改成按 k=1 数段（第 1 淡出、第 2 淡入、第 3 闪烁）。
- `xiyou_battle_ui` 172/172（快车道，47 秒）。提交 1f5f955ed。

### ② 战斗画面截图对照（11-10 00:20）
- Godot 窗口模式 `xiyou_battle_ui -- --out=<目录>`（经 占槽.py，排槽约 25～40 分钟，跑 207/207）出 battle_40_input／battle_60*，截图帧改成和原版同一画面（原版 k=12 截图时淡出已推进 11 帧；闪烁 f5 在 224 之后第 3 帧）。
- 两边背景、敌我数据不同（原版夹具底图是标题画面，Godot 是地图 5），不比整图；`battle_screen_fx_compare.py` 各以输入阶段截图为底拟合：淡出 f12 亮度 原版 139.0／Godot 137.97（公式 138.125），f24 10.98／10.10（10.625），闪烁 f5 强度 153.89／153.23（153），拟合误差都在 1.2 以内；淡黑后的消息截图战斗画面区两边全黑，消息窗区平均色 (40.1,37.3,41.2)／(38.6,36.0,39.8)。
- 截图里看到的不一致（都不是本条范围，没改）：Godot 的「自动／变速」按钮在黑幕之上，原版这个夹具里没这两个按钮，层次没核；原版右下版本号在黑幕下，Godot 的 dev 号在上（开发版标记）；状态图标 i／太极与 TP 数是夹具数据差别。

### 没做的
- 状态图标、伤害数字、Boss 血条场面的截图对照没挑（派单 ② 原写「能做多少做多少」）；建议另派，参照脚本可照 battle_screen_fx_ref.cjs 起。
- 224 勾等待、闪烁中再闪、淡出中开新战斗这些组合没单测（数据里战斗内 224 都不勾等待：小明基因锁 CE1551～1554）。

### 验证
- 语法检查 660 个 .gd 0 问题；`xiyou_battle_ui` 无头 172/172、窗口模式 207/207。
- 云端选测（基准 eb6ab526bf，196 场景，含 gaps9／10 的改动面）：结果见下一行。
