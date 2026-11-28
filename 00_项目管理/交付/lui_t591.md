# 交付：lui/t591

- 车道／工作者：T591 熟练度 Lv100000 查因（cc，Opus＋medium，只查不改）
- 状态：可合并

## 变更记录草稿

## 2026-11-28 【cc·T591·未经审查】查因：战斗里技能熟练度一次跳到 Lv100000＝本机测试模式开着（dev.待定）

- 结论：**测试环境专有，玩家不会触发**。没改游戏代码。
- 根因：Kyo 本机开发用户目录 `KYO/再刷重制_开发/modes/xiyou/` 下有 `test_mode_unlock`，`test_mode_state` 为 1，测试模式是开着的。
  测试模式（`modes/xiyou/core/test_mode.gd` 头注释、`used_skills`／`train`，原版 installTestModeRuntime 同款）让角色战斗里付过费的技能结算后直接升到当前上限；
  西游档变量 13 不为 1、变量 8 为 0 时上限就是 `Default Max Mastery` 100000（`skill_mastery.gd` `max_level`），所以横幅是 Lv0→Lv100000，伤害按十万级熟练度乘，木桩每下掉约 27%。
- 为什么测试也中招：测试夹具 `tests/xiyou_test_env.gd` 的 `isolate()` 只隔离了存档目录和 options.json，**没隔离 `XTestMode` 的解锁／状态路径**，
  本机跑的截图工具、专项照样读到 Kyo 的真实测试模式；云端是新目录、没有解锁文件，所以云端不出现（本机与云端结果会不一致）。
  T586 截图工具 `t586_shots.gd` 调了 `TestEnv.isolate("t586_shots")`，照样中招；跟 T586 开关无关（开关关着也一样）。
- 复现（本机、headless、临时场景，跑完已删）：`isolate` 后 `XTestMode.enabled()=true`，徐凤年（152）技能 6216 记一次使用、`all_actions_end` 后 Lv0→Lv100000；
  同一脚本把 `XTestMode.unlock_override` 指到不存在的文件，`enabled()=false`，用一次后仍是 Lv0（正常：要攒够次数才升级）。
- 玩家侧：解锁只认本机 `user://modes/xiyou/test_mode_unlock` 文件，代码里只有读、没有任何地方写它；发行预设排除 `*test_mode_unlock*`（`测试发行预设排除检查.py`）。
  玩家没有这个文件 → 测试模式恒关 → 不触发。v0.04.08 西游档、启封档同理。
  启封档（天启篇）熟练度上限被 `XTianqiSkills.mastery_cap()` 夹到 10，本机测试模式开着时也只会到 Lv10，不会到 100000。
- 另注：Kyo 发行版用户目录 `KYO/再刷重制/` 里也有解锁文件、状态 1，Kyo 自己玩发行版时同样会一用就满级（测试模式设计如此，不是 bug）。
- 建议修法（未做，等协调定）：`TestEnv.isolate()` 里把 `XTestMode.unlock_override`、`state_override` 指到测试自己的目录（默认没有解锁文件＝关），
  需要测试模式的专项（现有 9 个自己设了 override）不受影响；`t586_shots` 等截图工具随之恢复正常木桩伤害。

## 交接板

- 下一步：派一单修 `tests/xiyou_test_env.gd` 的 `isolate()` 隔离测试模式（见上「建议修法」），修后让 T586 重出截图。
- 用户试玩说明：无（玩家看不到变化）
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 建议：`TestEnv.isolate()` 隔离 `XTestMode` 解锁／状态路径，消除本机与云端结果不一致（收益：本机截图、数值测量不再被 Kyo 的测试模式污染；归一条小车道，Sonnet＋medium 即可）。

## 动了的共用函数和开关

无

## 本分支提交

- 本交付单（只查不改，无代码提交）
