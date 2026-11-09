# 交付单 cc/rules-gaps11（GB9）

状态：**未完成，WIP 接续**（额度 92%，Kyo 19:40 要求收工换账号）。不可合并。

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
（待完成后写）

## 可优化
- 测试槽很挤：一条只读的浏览器参照（几十秒）排了约 28 分钟。轻量的浏览器参照可考虑单独的轻槽，不和 Godot 测试抢。

## 接续（11-09 21:30，第二位八戒；额度紧，总装叫停）

- 分支头 6c3fb0647（本条记录提交之后为新头）。**本会话没改代码**：切了分支、读了交接要点，起了 `--补齐` 和原版参照，都被叫停中断。
- `--补齐` 没跑完（被停），下一位重跑一次即可，不用清理。
- 原版参照 `battle_screen_fx_ref.cjs` 在测试槽里排了 8 分钟没轮上就被停，**一次都没跑**，所以上面「接续要点」第 1 条（消息窗在指令输入阶段没开）仍未查明；`tests/fixtures/battle_screen_fx_oracle.json` 仍没有，`xiyou_battle_ui` 的 screen_fx_oracle 现在会挂。
- 下一步照上面「接续要点」1～5 原样做。建议排槽时避开合并长任务；参照服务 `serve.py` 已关，8766 端口空着。
- 没有跑到一半的东西。不可合并。
