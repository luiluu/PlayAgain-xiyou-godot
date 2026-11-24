# 交付：xa/t476-main

- 车道／工作者：小A（Gemini 4 Neon + high，P8，T468 原作者）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【小A·未经审查】T476：西游档老存档 >99 级法宝按 888→99 等比例折算等级并受楼层上限限制（dev.待定）

- 依据：Kyo 11-24 22:3x 看 v0.04.01 更新说明后定稿「超过99级的法宝等比例折算等级并且仍然收到层数上限限制」，推翻 T468 验收 3「老存档 >99 级保持原等级不降级、封顶 888 总值」。
- 玩家可见：老存档中超过 99 级的西游法宝在读档时按 888→99 等比例折算等级（如 888→99、331→37、1000→99 封顶），并受当前楼层法宝等级上限限制；超过本层上限的法宝按上限生效与显示，存档保留折算等级，楼层上限提高后自动恢复、不丢等级；99 级及以下法宝、天启篇与三法宝 60 级进化状态均不受影响。
- 读档折算（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/magic_weapon.gd`、`xstate.gd`、`star_warehouse.gd`）：
  - 新增 `XMagicWeapon.convert_old_level`、`migrate_item`、`after_load` 与迁移标记 `OLD_LEVEL_MIGRATE_MARK`（`fabao_old_lv_scaled_v1`）。
  - 西游档读档（`XState.from_dict`）扫描背包、全员装备栏及 PH 仓库中的法宝：等级 >99 时按 `clamp(round(旧等级×99/888), 1, 99)` 折算写回 `item["level"]`（溢出的旧经验清零），仅在实际迁移（`changed > 0`）时写入 `s.flags[OLD_LEVEL_MIGRATE_MARK] = true`，重复读档不再二次折算；不含 >99 级法宝的干净西游档零改动、保持存读档逐字节一致。
  - 跨存档星级仓库（`XStarWarehouse.withdraw_gear`）向西游档取出 >99 级法宝时同步调用 `XMagicWeapon.migrate_item` 折算；天启篇与关折算（`SCALE_99_TO_888 = false` 或 `LEVEL_99 = false`）零改动。
- 楼层上限生效与升层恢复（`magic_weapon.gd`、`actor.gd`、`equipment_view.gd`、`formula_context.gd`、`power.gd`、`item_row.gd`、`xstate.gd`）：
  - 新增 `XMagicWeapon.max_level_in` 与 `effective_level`：存档保留折算/原始等级，西游档启用折算时按 `min(level_of, max_level_in)` 作为生效等级。
  - `XActor.magic_param`、`XMagicWeapon.trait_objects`、`XMagicWeapon.item_skills`、`XEquipmentView.first_armor_level`、`XFormulaContext.row`、`XPower.equipment`／`_signature`（缓存键纳入 `level_cap`）与 `XItemRow.paint_magic_level` 统一改读 `effective_level`。
  - `XState.set_variable(20, ...)` 提升楼层上限时仅清只读窗口与战斗参数缓存（`XActor.read_touch()` 与 `param_dirty`），不误标 `effect_dirty`，升层后自动恢复法宝生效等级。
- 说明卡同步（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/help_card.gd`）：
  - 去掉 `_relic_rows` 与 `_apply_fabao_scale_rows` 中「旧档超上限」「超出现行上限，按99级满级加成计」「高于满级，按原等级加成计」等旧行，按折算后／本层生效等级正常显示（被低楼层限制时带简短「保留X级」提示，升层后自动消失）。
- 验证：
  - 本机专项（均带 `--audio-driver Dummy`）：`tests/xiyou_fabao_99_scale.tscn` 81/81（断言 331/888/1000/99/50 级折算、落盘与跨存档仓库迁移、重复读档、低楼层上限与升层恢复、三法宝 60 级进化保持、天启篇隔离、说明卡与干净档往返）、`tests/xiyou_xufeng_rework.tscn` 71/71、`tests/xiyou_save_slim.tscn` 126/126、`tests/xiyou_magic_weapon.tscn` 43/43、`tests/xiyou_three_growth.tscn` 110/110、`tests/xiyou_garou_progress.tscn` 180/180、`tests/xiyou_tianqi_phase4.tscn` 176/176、`tests/xiyou_equipment.tscn` 1254/1254、`tests/xiyou_flow.tscn` 50/50、`tests/xiyou_random_streams.tscn` 490/490、`tests/xiyou_boss_sequence.tscn` 8315/8315、`tests/xiyou_floor_run.tscn` 273/273。
  - 发行空壳：`python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 通过（80 个脚本，774 个函数都有，退出码 0）。
  - 云端选测（提交 `d038415f41`，基准 `cab3ad5e5d`，753 个场景分 16 片，全过；1 偶发 `xiyou_floor_reach080.tscn` 单跑通过）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45505950327 。

## 交接板

- 下一步：T476 已合入 `patch/v0.04` 并随 v0.04.01 上线，本次将原分支 `luiluu/t476 @ 47ace9fe8` 无冲突 cherry-pick 同步回 `main`。
- 用户试玩说明：v0.04.01 西游老存档读档时 >99 级法宝按 888→99 等比例折算等级并受楼层上限限制，低楼层按本层上限生效、升层后自动恢复，不丢等级。
- 需要用户决定：无

## 进度账

- 无主表／扩展账完成度变更（属于 v0.04.01 补丁线 T468 口径修订）。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XMagicWeapon.max_level` | 96 处（`git grep -nE '[^[:alnum:]_]max_level[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 96 处逐处结论：签名与返回值不变，仅抽内部委托 `max_level_in(item, XState.current)`，全部 96 处调用行为等价 |
| `XMagicWeapon.scaled_growth` | 5 处（`git grep -nE '[^[:alnum:]_]scaled_growth[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 5 处逐处结论：`actor.gd` 2 处、`power.gd` 1 处、`help_card.gd` 1 处、`magic_weapon.gd` 1 处；`lv >= 99` 统一按 `orig_max * per` 封顶，与 T476 口径一致 |
| `XMagicWeapon.trait_objects` | 31 处（`git grep -nE '[^[:alnum:]_]trait_objects[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 31 处逐处结论：`actor.gd:964` 与测试按 `effective_level` 叠加法宝升级特性；关折算／天启篇退回原 `level_of`，零副作用 |
| `XMagicWeapon.item_skills` | 5 处（`git grep -nE '[^[:alnum:]_]item_skills[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 5 处逐处结论：`magic_weapon.gd` 内部 `skills()` 及测试按 `effective_level` 判法宝学技能区间，受楼层上限限制；天启篇与关折算不变 |
| `XActor.magic_param` | 61 处（`git grep -nE '[^[:alnum:]_]magic_param[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 61 处逐处结论：`actor.gd`、`yunshang.gd`、`help_card.gd` 与各测试统一按 `effective_level` 算西游档法宝成长；天启篇走 `XTianqiGear.fabao_applies` 原路径不受影响 |
| `XEquipmentView.first_armor_level` | 5 处（`git grep -nE '[^[:alnum:]_]first_armor_level[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 5 处逐处结论：`formula_execution.gd`、`formula_program.gd`、`state_effects.gd` 缺省读取改为 `effective_level`，确保公式里引用法宝等级也受本层上限限制；非西游档不变 |
| `XFormulaContext.row` | 84 处（`git grep -nE '[^[:alnum:]_]row[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 84 处逐处结论：仅装备快照字段 `instanceLevel` 改取 `XMagicWeapon.effective_level(item)`，非魔法装备仍返回 `-1.0`，非西游档与原版完全一致 |
| `XPower.equipment` | 23 处（`git grep -nE '[^[:alnum:]_]equipment[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 23 处逐处结论：缓存签名追加 `level_cap`，西游档法宝按 `effective_level` 计分与记 `s.level`，升层自动刷新不串缓存；天启篇／关折算 `cap=0` 不变 |
| `XPower._signature` | 11 处（`git grep -nE '[^[:alnum:]_]_signature[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 11 处逐处结论：角色战力缓存签名追加 `level_cap`，升层时自动重算角色战力，不串旧层缓存 |
| `XState.set_variable` | 689 处（`git grep -nE '[^[:alnum:]_]set_variable[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 689 处逐处结论：仅 `id == 20` 且西游档折算开启时调用 `XActor.read_touch()` 并置 `param_dirty`（不改 `effect_dirty`），全部 689 处调用无额外副作用（`xiyou_boss_sequence` 8315/8315 过） |
| `XState.from_dict` | 201 处（`git grep -nE '[^[:alnum:]_]from_dict[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 201 处逐处结论：末尾接入 `XMagicWeapon.after_load(s)`，仅西游档存在 >99 级法宝时折算并写标记；无 >99 级法宝或天启篇零改动（`xiyou_equipment`、`xiyou_flow`、`xiyou_save_slim` 全过） |
| `XStarWarehouse.withdraw_gear` | 11 处（`git grep -nE '[^[:alnum:]_]withdraw_gear[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 11 处逐处结论：取出装备到西游档时同步调用 `XMagicWeapon.migrate_item(rec, s)` 折算老 >99 级法宝，≤99 级与天启篇零改动 |

## 本分支提交

- `e82eb8485` T476：西游档老存档 >99 级法宝按 888→99 等比例折算等级并受楼层上限限制
- `d038415f4` T476：修复两处云端回归（仅实际迁移时写迁移标记；变量 20 变化不误标 effect_dirty）
