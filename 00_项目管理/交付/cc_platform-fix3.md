# 交付：cc/platform-fix3

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；EJ 单，来源审查第 51 期 P2-1）
- 状态：可合并
- 基于：main ab80ca89（dev.391，含 input1）

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】开战前的自动存档检查点真正生效（dev.待定）

- 玩家可见：手机上打仗时被系统杀掉，标题页「继续」能回到开战前
- 审查第 51 期 P2-1 → 复现测试 `xiyou_pause_save` 的 encounter_checkpoint_saves、event_battle_checkpoint_saves（真走一次随机遇敌、一次事件战斗指令 301；把入口改动还原后两项都挂在 `skip:event`）→ 修法：
  - 删掉 `start_battle` 里那行（入口都先置了 busy，blocker 见 busy 永远跳过）。
  - `XAutoSave.battle_checkpoint(map, in_event)`：随机遇敌在 `_encounter` 的 `_set_busy(true)` 之前调；事件战斗（`mv_interpreter` 指令 301）、小猫试炼（`mv_script` CodexCat.startTrial，放在 `XCat.start_trial` 换成单人队伍之前）、真气闭关（`zhenqi_retreat`）在开打前调，这三处是事件里开的战斗，`in_event` 让 busy 不算阻挡（读回来事件从头再跑，按总装定接受）。从主菜单开的真气闭关仍被「菜单开着」挡住。
  - 限频（总装定）：挂机中跳过（`skip:hangup`）；两次战斗检查点至少隔 `BATTLE_GAP_MSEC` 60 秒（`skip:recent`）。测试 battle_checkpoint_rate_limited、battle_checkpoint_after_gap、battle_checkpoint_skip_hangup、in_event_ignores_busy、not_in_event_busy_skips。
  - 删掉只查源码文本的旧断言 battle_checkpoint_before_battle_state。
- 开关仍是 O-221 的 `XAutoSave.CHECKPOINTS`；优化登记 O-221 行改了说明。

## 交接板

- 下一步：无
- 需要用户决定：无（O-221 原有的待定照旧）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `xiyou_pause_save` 40/40（本机直接跑）；反向：把 map_scene／mv_interpreter 还原，encounter_checkpoint_saves、event_battle_checkpoint_saves 挂 `skip:event`。
- `语法检查.py` 605 个 .gd 0 问题；`事件空绿扫描.py --check` 55 例均在基线内。
- 云端选测通过：提交 d39455afd1，148 个场景、4 片（基准 ab80ca89），https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42333314575
