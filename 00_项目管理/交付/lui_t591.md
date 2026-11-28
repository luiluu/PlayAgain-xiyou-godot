# 交付：lui/t591

- 车道／工作者：T591 熟练度 Lv100000 查因＋测试夹具隔离测试模式（cc，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-28 【cc·T591·未经审查】查因：战斗里技能熟练度一次跳到 Lv100000＝本机测试模式开着（dev.待定）

- 结论：**测试环境专有，玩家不会触发**。没改游戏代码，只改测试夹具（见下一条）。
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
- 修法（协调 11-28 定）：见下一条。

## 2026-11-28 【cc·T591·未经审查】测试夹具隔离测试模式（dev.待定）

- `tests/xiyou_test_env.gd`：`isolate()` 调新函数 `isolate_test_mode(目录)`，把 `XTestMode.unlock_override`／`state_override` 指到测试目录（那里没有解锁文件＝关）。
- `tests/lib/tq_save_kit.gd`：`_init` 同样隔离，`teardown` 还原。
- 要测试模式的专项（`xiyou_test_mode`、`xiyou_lobby_debug_npc`、`xiyou_enemy_book`）本来就自己设 override、不调 isolate／Kit，不受影响。
- 新增回归 `tests/xiyou_test_env_isolate`：先造一个「本机开着测试模式」（解锁＋状态 1），核对照组一招升满（Lv100000）、isolate／Kit 之后关闭且一招不升满、teardown 还原，7/7。
- 注意：不经过 isolate／Kit 的探针（如 T580 用的 `k_calibrate`／`t445_book_probe`，自己建档）不受这次修复覆盖，要在探针里自己调 `TestEnv.isolate_test_mode()`。
- 云端选测：提交 a2ad33fc9，基准 38702d755，181 个场景、3 片全过，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46098547254

## 2026-11-28 【cc·T591·未经审查】核查：T580 六维补算、法宝浸染挂机速度有没有被测试模式污染（dev.待定）

- 法宝浸染挂机速度（工作树 fabao-jinran，`hangup_rate_probe`）：**污染**。两次实测（11-28 02:14、02:32，看临时目录修改时间）晚于测试模式状态文件最后写入（00:23，内容 1），夹具 `tq_save_kit` 当时不隔离。
  探针新开局、熟练度 0，真挂机走 `act()`，每招第一次结算后直接升到启封上限 10 级（每级 +3% 伤害，共 +30%），经验 ×10 也生效，所以「每小时 300 场」偏快，偏多少没量；要摘 a2ad33fc9 关掉测试模式重测。
- T580 六维补算（工作树 t580，`t445_book_probe --book-build=lianyu --act-tail`）：**没污染**（测试模式开着也一样）。
  - 代码依据：测试模式影响熟练度的只有 `XSkillMastery.all_actions_end`（经 `_mastery_end`），只在 `XBattleLogic.act()` 和强制行动 `_forced_run`（由战斗事件 `_drive_events` 触发）里调；
    炼狱探针每次采样从快照还原、只调 `execute` 和模块收尾，不走 `act`／`run_turn`／`troop_events`，生存段（`--survive`，走 `act`）这次没跑。经验 ×10、掉落词缀加速不进木桩伤害。
  - 实测对照：在 scratchpad 克隆 t580（提交 2a18703a1），同一探针包两层，只差测试模式开（照本机，`enabled=true`）／关（`unlock_override` 指到空文件，`enabled=false`），
    `--book-build=lianyu --noisy --seed=3 --force-all-tiers --cond-full --act-tail --actors=95,167,172,173,174`：两份输出**逐字节相同**（`cmp`），4 行（95、167 渡鸦、172 宿傩、173 饿狼；174 云裳两边都没出行，探针自己的行数核对两边都退出 1），熟练度两边都是 8。
    结果存 `../交付截图/lui_t591/t580_seed3_testmode_on.json`、`t580_seed3_testmode_off.json`。
  - 种子 3 补跑在 02:28 起跑、测试模式开着，按上面结论不影响炼狱数；不用重跑。

## 交接板

- 下一步：T586 重出截图；法宝浸染挂机速度关掉测试模式重测（摘 a2ad33fc9 即可，hangup_rate_probe 走 tq_save_kit）。
- 用户试玩说明：无（玩家看不到变化）
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 已做：`TestEnv.isolate()`、`tq_save_kit` 隔离测试模式（回退：删掉 `isolate_test_mode` 调用和 Kit 里那三行）。
- 建议：自建档的量数探针（virtual_player 下的 k_calibrate 一系）开头也调 `TestEnv.isolate_test_mode()`，免得本机量数被测试模式带偏（归下一条动这些探针的车道）。

## 动了的共用函数和开关

无

## 本分支提交

- f8ececd7a 交付单（查因）
- a2ad33fc9 测试夹具隔离测试模式＋回归 xiyou_test_env_isolate
- （本提交）T580／法宝浸染污染核查结论＋对照结果
