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
