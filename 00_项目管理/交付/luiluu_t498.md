# 交付：luiluu/t498

- 车道／工作者：西游档修复／小A（Neon＋high，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【小A·未经审查】T498 修西游三阶替身守层者不异化＋顶部首领血条显示异化前缀（dev.待定）

- 原因：玩家反馈三阶漩涡下守层者不异化；小o 实机复现定位两处问题：① 天道使者雕像／攻击引路人／轮回归来等教派路线的 13～30 层替身守层者（如 21 层`【求道者】关羽`）按敌名首个标签分类，`rift_alien.json` 的 `classes` 无「求道者」，被 `XRiftAlien` 排除；② `XBossHpBar._enemy_name` 只读 `original_name()`，顶部首领血条不显示异化前缀，与下方战斗详情不一致。
- 改动（仅西游档，天启篇零改动，均带回退开关，O-待定）：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift_alien.gd`：新增开关 `STAND_IN_GUARDIAN := true` 与辅助 `_stand_in_tid(enemies, troop_id, skip_hidden := false)`；`class_of(e, troop_id := 0)` 与 `plan(s, enemies, roll, troop_id := 0)` 接收可选 `troop_id`（`setup` 与 `_mark_looks` 传入 `int(logic.troop_id)`），仅当 `STAND_IN_GUARDIAN` 开启、`troop_id` 位于 `XZhenqi.STAND_IN_GUARDIANS`（13～30 层教派替身守层战）且本场无原生【守层者】时，才将首个标签为「求道者」的敌人判为 `guardian`；纯替身战（748～765）三阶 100%、二阶 33%、层段与常规守层者一致，联合战（798～814，已有原生【守层者】）不提升【求道者】、保持真守层者异化与二阶 33% 几率及守层脉动归属真守层者，不误伤非守层战带【求道者】标签的敌人（如敌群 787 斯盖／齐格鲁德、766 求道者）；`XRiftAlien.on(s)` 已含 `not XTianqi.active(s)` 守卫，天启篇零改动。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/boss_hp_bar.gd`：新增开关 `ALIEN_PREFIX := true`；`_enemy_name(e)` 在西游档（`not XTianqi.active(XState.current)`）且开关开启时拼接原版异化前缀 `XAlienBattle.name_prefix(e)` 与漩涡异化前缀 `tianqi_prefix` 再接 `original_name()`，与下方 `XBossStatusPanel` 保持一致；`step()` 同 `enemy_id` 下同步前缀变化（不干扰 `REBUILD = false` 变身回退用例），`REBUILD = true` 变身时经 `_refresh_identity()` 保留异化前缀；天启篇档走原 `original_name()` 零改动。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift_alien.gd`：补 `_stand_in_guardians()` 逐场覆盖 35 场替身守层战（18 场纯替身 748～765 异化【求道者】、17 场联合战 798～814 固定异化真【守层者】）、13／21 层常规与替身同层二阶 33%／三阶 100% 层段一致、806 联合战二阶顺序掷点（首掷 0.5 没中不二次掷点、保持 33%）与三阶／实战仅真守层者【守层者】六道魔君异化并挂脉动而【求道者】关羽按原分类、26 层双替身 761 最多异化 1 只、非守层战敌群 787 不误伤、规则随机流不受影响、`STAND_IN_GUARDIAN = false` 回退及天启篇零改动（150/150 过）。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_boss_hp_bar.gd`：补第 11 节覆盖 `ALIEN_PREFIX` 开关与回退、漩涡／原版异化前缀、变身保留前缀、天启篇零改动，以及三阶西游档 21 层常规守层（457）与求道者替身（756）实机战斗画面血条与详情名字一致并出对照截图（无头 109/109、窗口含截图 114/114 过）。
- 玩家可见：修复：走教派路线时，13～30 层由【求道者】代守的守层战，漩涡异化后守层者不会异化的问题。顶部首领血条现在也会显示异化前缀（如「蚀骨·」），和下方详情一致。

## 优化登记草稿

| 编号 | 位置 | 原版表现 | 改动 | 理由 | 恢复方法 | 提出者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/rift_alien.gd`（`STAND_IN_GUARDIAN`、`class_of`、`_stand_in_tid`、`plan`、`setup`、`_mark_looks`）与 `modes/xiyou/battle/boss_hp_bar.gd`（`ALIEN_PREFIX`、`_enemy_name`、`step`） | 13～30 层教派替身守层者【求道者】不在 `rift_alien.json` `classes` 内导致不异化；顶部首领血条只读 `original_name()` 不显示异化前缀 | 仅在 `XZhenqi.STAND_IN_GUARDIANS` 且本场无原生【守层者】的敌群上下文内将【求道者】归为 `guardian` 参与漩涡异化（联合战 798～814 保持原生【守层者】异化，不误伤其他【求道者】敌人）；西游档顶部首领血条拼接异化前缀与下方战斗详情一致；天启篇零改动 | 玩家反馈三阶守层没异化，小o 实机复现确认教派替身路线漏分类与顶部血条缺前缀 | `XRiftAlien.STAND_IN_GUARDIAN`、`XBossHpBar.ALIEN_PREFIX` 分别设 `false` | 小A（T498） | 保留 |

## 交接板

- 下一步：合并后核查方复核 `luiluu/t498`（甲档西游档修复）；玩家可见变更说明已按 cc 核查改写稿更新。
- 用户试玩说明：修复：走教派路线时，13～30 层由【求道者】代守的守层战，漩涡异化后守层者不会异化的问题。顶部首领血条现在也会显示异化前缀（如「蚀骨·」），和下方详情一致。
- 需要用户决定：无

## 进度账

- 西游档补丁维护：修复 T498 教派替身守层者漩涡异化缺口与顶部首领血条异化前缀显示（不涉天启篇与主表完成度变动）。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XRiftAlien.class_of` | 19 处（`git grep -nE '[^[:alnum:]_]class_of[[:space:]]*\(' -- '*.gd'`） | 调用方 19 处逐处结论：其中 3 处为 `rift_alien.gd` 内部 `_stand_in_tid`／`plan`／`_mark_looks`（`plan` 与 `_mark_looks` 经 `_stand_in_tid` 过滤后传入），2 处为 `tianqi_seg_alien.gd` 及 2 处 `xiyou_tianqi_seg_alien.gd`（不同类 `XTianqiSegAlien`，未改），其余 12 处为 `xiyou_rift_alien.gd`（含旧 1 参调用与本单新增 2 参调用）；`troop_id := 0` 默认参数向下兼容，不传参时不触发替身规则，不会改坏既有调用方 |
| `XRiftAlien._stand_in_tid` | 3 处（`git grep -nE '[^[:alnum:]_]_stand_in_tid[[:space:]]*\(' -- '*.gd'`） | 调用方 3 处逐处结论：1 处定义、2 处 `rift_alien.gd` 内部 `plan`／`_mark_looks` 调用；敌群已有原生【守层者】时返回 0，避免联合战 798～814 提升【求道者】 |
| `XRiftAlien.plan` | 103 处（`git grep -nE '[^[:alnum:]_]plan[[:space:]]*\(' -- '*.gd'`） | 调用方 103 处逐处结论：实际属于 `XRiftAlien.plan` 的仅 `rift_alien.gd` `setup`（1 处，已传 `int(logic.troop_id)`）及 `xiyou_rift_alien.gd`（测试调用，含旧 3 参和本单新增 4 参）；`troop_id := 0` 默认参数兼容所有旧 3 参调用，其余同名 `plan(` 属其他脚本，未受影响 |
| `XRiftAlien._mark_looks` | 2 处（`git grep -nE '[^[:alnum:]_]_mark_looks[[:space:]]*\(' -- '*.gd'`） | 调用方 2 处逐处结论：1 处定义、1 处 `rift_alien.gd` `setup` 内调用；函数签名不变，经 `_stand_in_tid` 仅在无原生守层者的替身守层战为【求道者】挂守层脉动 |
| `XRiftAlien.setup` | 1 处（`git grep -nE 'XRiftAlien\.setup[[:space:]]*\(' -- '*.gd'`） | 调用方 1 处逐处结论：唯一调用点在 `modes/xiyou/battle/battle_logic.gd:223`；签名不变，受 `on(s)` 的 `not XTianqi.active(s)` 守卫，天启篇零改动 |
| `XBossHpBar._enemy_name` | 5 处（`git grep -nE '[^[:alnum:]_]_enemy_name[[:space:]]*\(' -- '*.gd'`） | 调用方 5 处逐处结论：全在 `modes/xiyou/battle/boss_hp_bar.gd` 内部（定义 1 处、`_build`／`step`／`_refresh_all`／`_refresh_identity` 各 1 处）；`XSkinBossArc` 继承自 `XBossHpBar`，西游档开 `ALIEN_PREFIX` 时显示异化前缀，天启篇档由 `XTianqi.active(XState.current)` 守卫保持 `original_name()` 零改动 |
| `XBossHpBar.step` | 235 处（`git grep -nE '[^[:alnum:]_]step[[:space:]]*\(' -- '*.gd'`） | 调用方 235 处逐处结论：属于 `XBossHpBar.step` 的为 `boss_hp_bar.gd` `_physics_process` 与 `xiyou_boss_hp_bar.gd` 测试；新增分支仅在 `int(battler.enemy_id) == _shown_id` 且前缀变化时刷新 `_name_text`，不影响 `REBUILD = false` 的变身回退断言，其他类同名 `step(` 未受影响 |
| `XRiftAlien.STAND_IN_GUARDIAN`、`XBossHpBar.ALIEN_PREFIX` | 新增静态回退开关（`rift_alien.gd`、`boss_hp_bar.gd`） | 均默认 `true`，分别在 `xiyou_rift_alien.gd` 与 `xiyou_boss_hp_bar.gd` 覆盖 `false` 回退路径 |

## 验证与截图

- 本机专项（R2 返修后，均带 `--audio-driver Dummy` 前台单跑）：
  - `tests/xiyou_rift_alien.tscn`：150/150 通过（退出码 0）
  - `tests/xiyou_boss_hp_bar.tscn`（无头）：109/109 通过（退出码 0；R1 窗口模式出截图 114/114 通过，R2 未动血条代码）
  - `tests/xiyou_zhenqi_standin.tscn`：48/48 通过（退出码 0）
- 发行空壳：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0（84 个脚本，825 个函数都有）。
- 云端选测（R2，`gh run watch 45593329272 --exit-status` 前台等完）：
  - 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45593329272
  - 结论：success（提交 `ab167187e4`，基准 `ae83ba1efc`，40 个场景、4 片全部通过，最长一片 10.9 分钟；R1 提交 `f7a704168c` 云端选测 `45589291559` 44 个场景 8 片亦全部通过）。
- 实机同层对照截图（已入仓，三阶西游档 21 层威德天）：
  - 常规守层者 457（`蚀骨·【守层者】六道魔君`，顶部血条与下方首领面板名字一致、身上幽紫偏色）：`00_项目管理/归档/交付截图/luiluu_t498/t498_f21_regular.png`
  - 教派替身守层者 756（`蚀骨·【求道者】关羽`，顶部血条与下方首领面板名字一致、身上幽紫偏色）：`00_项目管理/归档/交付截图/luiluu_t498/t498_f21_standin.png`

## 本分支提交

- `f7a704168` T498：修西游三阶替身守层者不异化＋顶部首领血条显示异化前缀（STAND_IN_GUARDIAN／ALIEN_PREFIX）
- `ae83ba1ef` T498：补交付单 luiluu_t498.md（含云端选测 45589291559、截图与优化登记草稿）
- `ab167187e` T498 返修 R2：联合战已有原生守层者时不提升求道者并补 806 断言
