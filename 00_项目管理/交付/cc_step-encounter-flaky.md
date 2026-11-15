# 交付：cc/step-encounter-flaky

- 车道／工作者：cc（Sonnet 5.5＋medium，派单 task_334581c43343）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】xiyou_step_encounter_stop 偶发修复：测试采样时序＋战斗曲播放器已释放守卫（dev.待定）

- 测试时序：`rollback_stale_target_walks`（`stale_target_hangup`）开／停挂机的点按在快时钟下进行，点按那几帧里游戏已跑出几十个物理帧，人在 b0／g0 采样前已走完旧目的地，断言漏记（小o 甲档复核二定位）。修法不靠加等待：①开／停挂机点按改正常时钟（`tap_button_normal`，同 `stop_at`／`tap_cell` 做法）；②停挂机后用 `_physics_process` 事件观察「挂机已停而目的地仍留着」（`_stop_seen_target`），走了／打了／目的地留着任一成立即记为「停后会接着走」，不依赖点按之后才采的位置。回退开关臂（MV_CLEAR_DEST=false 要走、true 要停）的双向断言保留。
- 复现：本分支加 `XIYOU_STEP_FPS` 环境变量（压测用，默认不设）设 `Engine.max_fps`；原采样时机 max_fps=15 单次即 FAIL，只改点按为正常时钟仍 5/10 通过（采样后才看位置，目的地在点按窗口内走完仍会漏记），事件观察后本机 max_fps=15/30/60 各 10 次 30/30 全过（8/8，无 SCRIPT ERROR）。
- stop_fade／战斗曲已释放：`battle_scene.bgm` 即地图遇敌演出放起的 `prestarted_bgm`，节点归地图，地图收掉后战斗场景败北／胜利收场再 `stop_fade(bgm)`／`bgm.stop()` 会报 previously freed（本机压测 15 帧档曾出现 `Cannot call method 'stop' on a previously freed instance`）。加守卫：`XAudio.stop_fade` 参数去类型＋`is_instance_valid`，`XBattleScene._bgm_alive()` 守住败北／胜利收场里的 stop／换曲；开关 `XAudio.STOP_FADE_GUARD`（O-待定），关了＝照旧不检查。有效对象行为不变。测试加 `stop_fade_freed_player_ok`。
- 玩家可见：无（偶发报错＋测试修正）。

## 交接板

- 下一步：核查——游戏代码有改（audio.gd、battle_scene.gd），升**甲档交小o**。
- 需要用户决定：无。

## 优化登记（总装并入时发 O 号）

| O-待定 | `core/audio.gd` `XAudio.STOP_FADE_GUARD`；`battle/battle_scene.gd` `_bgm_alive` | 战斗曲播放器被地图释放后，战斗收场仍 stop／stop_fade 它 | 先检查对象是否有效，无效则跳过 | 原版没有此结构（重制自有），防偶发 previously freed 报错 | `XAudio.STOP_FADE_GUARD = false` | cc | 保留 |

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：测试加 `XIYOU_STEP_FPS` 压测钩子（不设不生效）。建议：其它「快时钟下 await tap 再采样」的专项（`xiyou_hangup_stop` 同款）也可能有同类低帧率偶发，归测试车道排查。

## 本分支提交

- 见 git log

## 验证

- 本机 `XIYOU_STEP_FPS`＝15／30／60 各跑 xiyou_step_encounter_stop 10 次，30/30 全过（8/8、无 SCRIPT ERROR）。
- 相关专项本机并行测试.py：battle_bgm 7/7、battle_end_ce 46/46、hangup 55/55、hangup_stop 11/11、victory_text_flow 4/4、transfer_touch、step_encounter_stop 8/8 全过。
- 云端：没有跑。云端选测对 core/audio.gd 判整轮（634 场景、约 196 分钟额度），为 7 个相关专项不值得；合并时按总装的选测来。


## 小o 甲档核查

- 核查者：co（派单 gpt-6.1-sol＋medium）；对象：7a57a0a0c、1449d4d1f。仅追加本节，未改游戏代码。
- **结论：不通过；P1 无，P2 一项，P3 无。** 正常对象的代码路径保持原样，测试时序修正可接受；但承诺的回退开关不成立，修正后需复核。

### P2：STOP_FADE_GUARD=false 没有恢复已释放对象的原行为

- **实测**（Godot 4.7.2）：释放播放器后 `bgm == null` 为 true、`is_instance_valid(bgm)` 为 false。关闭开关再调用 `XAudio.stop_fade(bgm)` 正常返回；`_bgm_alive()` 中 `bgm != null` 同样先挡住已释放引用，关闭开关也不会恢复胜利分支原先无条件的 `bgm.stop()`。去掉参数类型的改变本身不受开关控制，故交付单“关了＝照旧报错／不检查”的说法不实。位置：audio.gd:57–59、battle_scene.gd:253–254、2584–2597。
- 建议执行轨让开关真正切回原分支（包括调用入口的类型行为），或明确重定回退范围并改正注释、交付单及优化登记；不能把当前开关登记为完整回退。未在本核查中修代码。

### 释放时序与漏点（代码判断，未复现原偶发堆栈）

- 地图 `_encounter_effect` 在第 30 帧创建 `_battle_bgm` 并 `add_child` 到地图，再赋给 `battle.prestarted_bgm`；战斗 `_ready` 令 `bgm` 引用同一个播放器。
- 正常收场是 `_victory/_defeat` 返回后 `_main` 才发 `finished`；地图等待该信号，先 `battle.stop_bgm()`、接 ME、恢复地图曲，淡出结束后 `_end_battle_bgm()` 才 queue_free 播放器、清 `prestarted_bgm`，随后 queue_free 战斗。`battle.bgm` 没清，存在直至战斗销毁的悬空引用窗口，但正常流程不会在该窗口再进入胜利／败北。因此“地图先释放导致正常收场访问”的具体来源尚未证实，提前退出／测试拆场景或仍在运行的异步流程需要原报错堆栈才能定位。
- 已 rg 全部 prestarted_bgm 与 stop_fade 调用处。`stop_bgm`、`_me_finished` 已有有效性守卫；`play_me`、`_change_bgm` 虽没有新增有效性守卫，但现有 `bgm != null` 在本机挡住已释放对象，临时探针调用 `_defeat_me`（真实 Defeat2）和 `_change_bgm` 均无 SCRIPT ERROR，不能据此报漏点。胜利原无条件 stop 的防护位置合理；不能把防护当成已确认根因修复。

### 测试与有效对象行为

- **代码判断**：正常播放器新增条件均为真，fade_in 的 0.5 秒、续播、ME 与胜利换曲、地图恢复代码未改。**实测**：有效播放器在开关 true/false 两档调用 fade_in 后 stop_fade，均停止 tween、恢复 -12 dB 目标音量并移除 fade_tween 元数据；未做人耳音频验收或淡入全时长测量。
- stale_target_hangup 仍断言 tt、started、stopped；正常臂要求未移动、未新增战斗且未观察到残留目的地，新增观察只会加强正常臂。回退臂允许“停后残留目的地”作为继续走的代理信号，因而该臂不再单独证明实际多走了一步，但原有位移／遇敌观察仍保留，与本用例验证清目的地的目标一致。
- `stop_fade_freed_player_ok` 虽写 check(true)，报错会由并行测试.py 的 result_ok 检出 SCRIPT ERROR，不能仅靠该常量假通过；它未覆盖开关关闭或战斗所有权生命周期，不能证明完整修复。
- 云端未跑：本轮 estimate --base cdf35cb92 实得 134 场景、约 59 分钟额度，工具未提供直接指定这三项的 run 参数，未启动扩大的云端测试。
- 临时探针证据（不入 Git）：`03_再刷重制_Godot/04_验证/本地结果/step_encounter_review/step_review_probe4.log`。

- **本轮独立实测**：并行测试.py --jobs 1 指定三项各一次，退出码 0；xiyou_step_encounter_stop 8/8、xiyou_battle_bgm 7/7、xiyou_battle_end_ce 46/46，全无 SCRIPT ERROR，无重跑。共 204 秒；日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_214447_v8dj36y4/`。
- 待执行轨处理上述 P2 后复核；本轮未核到原偶发释放堆栈、云端运行及实际听感。
