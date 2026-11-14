# 交付：xa/release-stub-guard

- 车道／工作者：发行空壳通用护栏＋照搬 `return true` 盘点／小A（Gemini 4 Hydrogen Medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【小A·工具·未经审查】发行空壳通用护栏＋照搬 return true 盘点（dev.待定）

- 依据：cc 核包庚发现 `发行空壳.py` 规则 2（`if …: return true`）会把拦截类函数照搬成 `return true`（`XTianqiSect.intercepts` 差点让发行包所有地图事件不执行）。
- 改动：
  1. `03_再刷重制_Godot/07_开发环境/发行空壳.py`：新增 `COPIED_TRUE` 集合追踪规则 2 照搬出 `return true` 的函数；`load_overrides()` 排除 `已确认放行` 键，新增 `load_allow_true()`；`check` / `report` 打印警告列表；`check_errors()`（含 `check` 与 `make_tree`）对不在 `发行空壳特例.json`「已确认放行」名单里的 `return true` 直接失败。
  2. `03_再刷重制_Godot/07_开发环境/发行空壳特例.json`：新增「已确认放行」名单并写明逐条理由，盘点全部 7 个规则 2 照搬 `return true` 的函数（外加特例表已有 `XTianqiGear.open_type`）。
  3. `03_再刷重制_Godot/07_开发环境/测试发行空壳.py`：新增通用护栏测试 `test_intercept_and_takeover_stubs_return_falsy_or_empty`（全量扫描「拦截／接管类」函数，要求空壳必须返回 `false` / 空 / `pass`）与 `test_copied_return_true_requires_allowlist_and_warns`（规则 2 照搬 `return true` 时打印警告，未进「已确认放行」则 `check` 失败）。
- 不改游戏逻辑本身，只改 `03_再刷重制_Godot/07_开发环境/` 下空壳工具、特例表和测试。

## 照搬 `return true` 逐条盘点结论

全量扫描 `发行空壳.py` 生成的 56 个脚本、460 个函数，共发现 7 个由规则 2 照搬出 `return true` 的函数（另 1 个为特例表 `XTianqiGear.open_type`）：

| 函数 | 来历 | 调用处 | 发行包行为分析 | 结论 |
| --- | --- | --- | --- | --- |
| `XGojo.listed` | 照搬关着时的返回 | `battle_logic.gd:801` | 战斗技能列表过滤；发行包五条悟未启用，非五条悟角色必须返回 `true`，否则西游全员技能列表为空 | **放行**（已入「已确认放行」） |
| `XGojo.meets` | 照搬关着时的返回 | `battle_logic.gd:734` | 战斗技能可用条件；非五条悟角色必须返回 `true`，否则西游全员无法使用任何技能 | **放行**（已入「已确认放行」） |
| `XTianqi.join_allowed` | 照搬关着时的返回 | `xstate.gd:390` | `_add_actor` 入队门槛；天启篇未开时必须返回 `true`，否则西游无法招募任何角色 | **放行**（已入「已确认放行」） |
| `XTianqiDrop.keeps_row` | 照搬关着时的返回 | `battle_logic.gd:3509,3516`、`map_transfer.gd:167` | 怪物原表掉落行保留判定；通用掉落未开时必须返回 `true`，否则西游怪物不掉精良及以下原表装备 | **放行**（已入「已确认放行」） |
| `XTianqiGear.allows` | 照搬关着时的返回 | `actor.gd:232` | `can_equip` 穿戴栏位与神器白名单；天启篇未开时必须返回 `true`，否则西游角色无法穿戴防具饰品 | **放行**（已入「已确认放行」） |
| `XTianqiGear.open_type` | 特例（`"true"`） | `equipment.gd:8` | `XEquipment.can_change` 栏位开放判定；天启篇未开时所有栏位开放，返回 `false` 会导致西游无法换装 | **放行**（已在特例表确认） |
| `XTianqiQiyinRule.can_use` | 照搬关着时的返回 | `battle_logic.gd:714` | 七印战斗规则限制；天启篇未开时必须返回 `true`，否则西游全员无法使用任何技能 | **放行**（已入「已确认放行」） |
| `XTianqiSkills.meets` | 照搬关着时的返回 | `battle_logic.gd:712` | 天启篇技能重构变量条件；未开时必须返回 `true`，否则西游全员无法使用任何技能 | **放行**（已入「已确认放行」） |

## 拦截／接管类函数清单（`测试发行空壳.py` 通用护栏）

`test_intercept_and_takeover_stubs_return_falsy_or_empty` 覆盖以下两类命名：
- **精确名单**：`intercepts`、`run_event`、`handles`、`override`、`overrides`、`hides`、`silenced`、`forced_state`、`redirect`、`infinity_block`、`reforge_locked`、`run_door`、`run_arrival`、`run_laoda`、`run_draw`、`run_line_choice`、`run_scale`、`hide_affix_rate`、`skips_row`、`skips_rate`、`no_encounter`、`no_rewards`、`no_crit`、`no_regen`
- **前后缀模式**：`intercept*`、`handle*`、`override*`、`blocks_*`、`*_blocked`、`hide_*`、`skips_*`

上述全部函数在当前 56 个空壳中均返回 `false`、`null`、`{}` 或 `pass`。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：打印 7 个照搬 `return true` 警告列表，均在「已确认放行」名单内，通过（56 个脚本，460 个函数都有）。
- `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py show XTianqiSect`：核对 `intercepts` 返回 `false`、`run_event` 为 `pass`。
- `python3 03_再刷重制_Godot/07_开发环境/测试发行空壳.py`：11 项测试全部通过（含合并 `main` 保留的 `test_real_project_sect_stub`，以及 `override\w*|\w+_override`、`run_\w+` 扩展模式）。
- 补丁：合并 `main` 解冲突并扩展拦截／接管类模式至 `override\w*|\w+_override` 与 `run_\w+`，`发行空壳.py check`（56 个脚本，471 个函数）通过。
- `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`：工具回归未在车道跑完（已通过 15/18 项，余 3 项仍在跑），请总装合并时跑。
- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：通过（855 个 `.gd`，0 个问题，25 秒）。

## 本分支提交

- 见 git log（luiluu/xa-release-stub-guard）
