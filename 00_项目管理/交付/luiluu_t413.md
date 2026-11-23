# 交付：luiluu/t413

- 车道／工作者：T413 打开漩涡三阶怪物异化（蚀骨）／小A（Hydrogen＋high，P7）
- 状态：可合并

## 做了什么

1. **打开三阶怪物异化开关（O-641）**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift_alien.gd` 将 `XRiftAlien.STAGE3_ALIEN` 默认值由 `false` 改为 `true`，同步更新顶部与开关注释。未改动 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/rift_alien.json` 中的任何几率表——**三阶及各阶怪物异化几率仍是测试参数，待后续标定**（依 Kyo 11-23 事项 35「开，数字先用测试参数」）。
   - `rift3` 看过前（`XRift.stage() == 2`）：怪物端仍按二阶侵染规则。
   - `rift3` 看过后（`XRift.stage() == 3`）：怪物端按 `stages_aligned["3"]` 生效（稀有、首领、守层者、深渊怪按阶段表出蚀骨／对应级）；天启篇存档（`XTianqi.active(s)`）零变化；`XRiftAlien.STAGE3_ALIEN = false` 立即回退至二阶。
   - `RELEASE_OPEN` 仍为 `false`，发行空壳不变（`发行空壳.py check` 退出码 0，81 个脚本 781 个函数齐全）。
2. **补充专项测试**：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift_alien.gd` 新增 `stage3_alien_default_on` 与 `_stage3_default()`（不设 `STAGE_OVERRIDE`、走真 `XRift.stage()`）：覆盖 `rift3` 前仍二阶、`rift3` 后四类怪（稀有、首领、守层者分段、深渊怪）按三阶阶段表生效、真开战出「蚀骨·」且规则随机流逐条不变、天启篇存档零变化（`on`/`plan`/真开战 `_sig` 全一致）、关掉 `STAGE3_ALIEN = false` 回二阶。
3. **经协调批复扩改两处原版对照测试文件**（选 A）：首轮云端选测 run `45178379077`（38 场景 7 片）37 个全过，唯 `xiyou_floor_run_c.tscn` 挂 1 项 `f22_boss_no_global_random`（559/560）。根因：`tests/xiyou_floor_run.gd:525` 原版对照仅关了 `XRiftAlien.ALIGN_LOBBY = false`，而第 529 行 `TestEnv.isolate` 在 T412 已记 `rift3`；翻开 `STAGE3_ALIEN = true` 后旧表 `stages["3"]` 让 22 层守层者异化，战后 `XRiftAlien.grant()` 调 `XAlienation.create()` 消耗了全局 `randf()`。同源处还有 `03_再刷重制_Godot/07_开发环境/造测试档/full_clear_max.gd:51`。按协调批复选 A，在以下两处补关 `XRiftAlien.STAGE3_ALIEN = false`（保持原版对照关闭漩涡异化的既有口径）：
   - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_floor_run.gd`
   - `03_再刷重制_Godot/07_开发环境/造测试档/full_clear_max.gd`

## 验证结果

- **专项测试（本机无头 `--audio-driver Dummy`）**：
  - `res://tests/xiyou_rift_alien.tscn`：120/120 通过
  - `res://tests/xiyou_rift3_xufeng.tscn`：53/53 通过
  - `res://tests/xiyou_floor_run_c.tscn`：560/560 通过（扩改后复跑）
- **探索与短帧 climb（本机无头 `--audio-driver Dummy`）**：
  - `res://tests/xiyou_virtual_player.tscn`（explore）：14/14 通过（1853 帧，卡死 0、违规 0、脚本报错 0）
  - `res://tests/xiyou_virtual_player.tscn -- --vp-mode=climb --vp-ff --vp-frames=40000 --vp-seed=1`：9/9 通过（爬至第 7 层／通过 1～6 层，40021 帧，8558 步，卡死 0、违规 0、脚本报错 0）
- **工具检查**：
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：退出码 0（81 个脚本，781 个函数都有）
  - `python3 03_再刷重制_Godot/07_开发环境/回退开关覆盖.py`：退出码 0（O-641 `XRiftAlien.STAGE3_ALIEN` 已由测试覆盖回退值，无新增缺口）
- **云端选测**（提交 `44c374c786`，分支 `ci/luiluu/t413`，基准 `a06fc6acc19afecd25b91b37e50ea7c5d795737f`）：
  - 39 个场景、3 片，最长一片 8.4 分钟，全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45180636435
  - （首轮提交 `3a88b8be22` run `45178379077` 抓出 `xiyou_floor_run_c` 1 项，修后次轮 run `45180636435` 全绿。）

## 变更记录草稿

### 2026-11-23 【小A·未经审查】打开漩涡三阶怪物异化（蚀骨）（dev.待定）

- **改动**：按 Kyo 11-23 事项 35 拍板，将 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift_alien.gd` 的 `XRiftAlien.STAGE3_ALIEN`（O-641）默认值改为 `true`；不改 `rift_alien.json`（几率仍是测试参数、待后续标定）。`rift3` 看过后西游档三阶蚀骨规则按阶段表生效，天启篇存档零变化，关掉开关回到二阶。
- **测试与兼容**：`tests/xiyou_rift_alien.gd` 补 `_stage3_default()` 核真路径正反两态与天启篇零变化（120/120）；`tests/xiyou_floor_run.gd` 与 `07_开发环境/造测试档/full_clear_max.gd` 原版对照补关 `XRiftAlien.STAGE3_ALIEN = false`（`xiyou_floor_run_c` 560/560）。探索 14/14、短帧 climb 9/9（卡死 0、脚本报错 0）；云端选测 39 场景 3 片全过（run `45180636435`）。
- **玩家可见**：本地主线西游档在看过漩涡三阶段过场后，稀有／首领／守层者／深渊怪按三阶蚀骨阶段表触发异化（当前几率仍为测试参数，待标定；`RELEASE_OPEN` 仍关，暂不推正式发行包）。

## 交接板

- 下一步：
  - 总装合并时同步更新 `03_再刷重制_Godot/00_设计/优化登记.md` 的 `O-641` 条目（默认值由 `false` 改为 `true`，回退写法为 `XRiftAlien.STAGE3_ALIEN = false` 回到二阶；当前几率仍为测试参数、待标定）。
  - 后续由数值标定任务调整 `modes/xiyou/rift_alien.json` 的正式几率参数。
- 用户试玩说明：西游档看过三阶段徐凤年过场（`rift3`）后，稀有、首领、守层者、深渊怪开始按三阶蚀骨阶段表异化（几率暂用测试参数）；天启篇存档不受影响。
- 需要用户决定：无（三阶怪物异化开合与测试参数口径已由 Kyo 11-23 事项 35 拍板）。

## 进度账

- 漩涡三阶段怪物异化（蚀骨）：开关默认开启并补齐真路径专项与云端选测，几率参数待后续标定（不改主表百分比）。

## 可优化（流程／工具／效率）

- 建议：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd:25` 与 `tests/xiyou_rift3_xufeng.gd:3` 中仍保留 T412 时的旧注释「默认关／默认不开」，本单未动派单外无关文件，后续清理车道可一并更新（小）。
- 建议：其他只关 `XRiftAlien.ALIGN_LOBBY = false` 但未隔离 `options.json` 的原版对照测试（如 `xiyou_combat.gd`、`xiyou_pet_capture.gd`、`xiyou_difficulty_troop.gd`、`xiyou_troop_events.gd`），在干净 CI 下未记 `rift3` 故不受影响，但若本机 `user://options.json` 留有 `rift3` 也会触发旧表 3 阶异化；建议后续测试隔离车道统一改用 `TestEnv.isolate` 或一并关 `STAGE3_ALIEN`（小）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XRiftAlien.STAGE3_ALIEN` | 15 处（`git grep -n 'STAGE3_ALIEN' -- '03_再刷重制_Godot/01_Godot工程/*.gd' '03_再刷重制_Godot/07_开发环境/*.gd'`，含 4 处注释、1 处定义、1 处 `stage()` 逻辑、9 处测试／工具赋值） | 调用方 15 处逐处结论：生产代码仅 `rift_alien.gd:76`（`stage()`）读取，默认改 `true` 后 `rift3` 看过后返回 3、`false` 夹回 2；`xiyou_rift3_xufeng.gd:53` 显式设 `false` 不受影响（53/53）；`xiyou_floor_run.gd:526` 与 `full_clear_max.gd:53` 已补设 `false` 保持原版对照（`xiyou_floor_run_c` 560/560）；`xiyou_rift_alien.gd` 正反两态均覆盖（120/120） |
| `XRiftAlien.stage` | 精确 8 处外部调用（`git grep -n 'XRiftAlien\.stage(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`）＋类内 2 处（`on()`、`plan()`） | 调用方 10 处逐处结论：仅影响 `rift3` 已看过且 `STAGE3_ALIEN == true` 且非天启篇存档的西游战斗（`STAGE_OVERRIDE > 0` 不变），按 `stages_aligned["3"]` 生效；云端选测 39 场景全部通过 |

## 本分支提交

- `3a88b8be2` T413 打开漩涡三阶怪物异化（XRiftAlien.STAGE3_ALIEN 默认改 true）并补专项
- `44c374c78` T413 原版对照测试补关 XRiftAlien.STAGE3_ALIEN（xiyou_floor_run、full_clear_max）
- 本提交：补齐 T413 交付单（含测试参数待标定说明、扩改两测试文件说明、探索＋短帧 climb 与云端选测 run `45180636435` 结果）
