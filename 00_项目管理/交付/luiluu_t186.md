# 交付：luiluu/t186

- 车道／工作者：T186 测试偶发排查／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·未经核查】xiyou_battle_pace、xiyou_hp_gauge_visible 偶发失败排查（dev.待定）

- 只改测试，没动游戏代码。xiyou_battle_pace：回合末 `await process_frame`，负载下一个渲染帧会补跑最多 8 个物理帧，回合交界空档 80 帧变 81～87，并行 40 路 32 次失败；专项里把 `Engine.max_physics_steps_per_frame` 设为 1（结束还原），不加长超时、不重试。xiyou_hp_gauge_visible：T180 旧日志显示 18/18 通过但退出时有「resources still in use」ERROR 行，并行运行器按 `^ERROR:` 判失败；本机 100 次没复现，推断是 `scene.queue_free()` 后立刻 quit，改为等 2 帧再退出（加固，非已证实根因）。
- 验证：xiyou_battle_pace 修前 40 路并行 8 过，修后 40/40、30/30；xiyou_hp_gauge_visible 修后 60/60、30/30；均 0 失败、无 ERROR／WARNING。没跑全量检查.sh。
- 提交：见本分支提交
- 未完成／已知问题：hp_gauge 若再偶发，需要那次的完整日志再查。

## 交接板

- 下一步：无
- 用户试玩说明：无玩家可见变化
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 1315fadd8 T186：战斗节奏专项限每渲染帧补跑 1 个物理帧；血条专项退出前等释放走完
