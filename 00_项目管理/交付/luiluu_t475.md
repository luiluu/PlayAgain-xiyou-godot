# 交付：luiluu/t475

- 车道／工作者：小A（Neon＋high，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【小A·未经审查】T475：D282 天启篇秘籍格随难度增加（九死+1、炼狱+2、证道+3，三档同加）（dev.待定）

- **依据**：Kyo 11-24「这个书要不要也跟着难度变化，越难能学的越多」，事项 55 选 2 → D282。不量数，只改格数规则（量数由 T471 按炼狱 8/6/5 承担）。
- **改动**：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json`：
    - 五档 `difficulties[]` 新增整数键 `secret_cap_bonus`（寻常 0、艰险 0、九死 1、炼狱 2、证道 3），更新顶层 `_note`。
  - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：
    - `balance_rules` 新增校验：五档难度 `secret_cap_bonus` 均为非负整数、随难度单调不降、符合 D282 约定（0/0/1/2/3）。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_balance.gd` & `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi.gd`：
    - `XTianqiBalance.difficulty(key)` 与 `XTianqi.difficulty(key)` 合并导出 `secret_cap_bonus`。
    - 新增 `XTianqiBalance.secret_cap_bonus(diff_key)`；`XTianqiBalance.secret_cap(name, diff_key := "")` 向后兼容单参调用，传入 `diff_key` 时返回「档位基数＋难度加成」（未知档位仍安全返回 0）。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd`：
    - 新增回退开关 `DIFFICULTY_BONUS := true`（置 `false` 回退到固定 6/4/3），以及受 `XTianqi.active(s)` 守卫的 `difficulty_key(s)`、`difficulty_name(s)`、`difficulty_bonus(s)`。
    - `limit(a, s = null)` 改为「档位基数（弱 6 / 强 4 / 超强 3）＋难度加成（寻常/艰险 +0、九死 +1、炼狱 +2、证道 +3）」，五档×三档分别为 6/4/3、6/4/3、7/5/4、8/6/5、9/7/6；西游档（`XTianqi.active == false`）零改动。
    - 抽出 `enforce_caps(s)` 供 `migrate_after_load(s)`（读档迁移）与运行期换低难度共用：换到低难度时多出的书走 T446 既有超量封印逻辑自动进 `sealed`、不丢书、被动立即失效，切回高难度可免费启封。
    - 功法页 UI 与满格提示文案同步更新（已过小A 文字审）：
      - `ui_slot_text`：显示当前难度下格数，有难度加成且非免费期长标题时注明如「秘籍格 5 / 5（炼狱 +2）」或「秘籍格 5 / 5（炼狱 +2，已封 1）」；
      - `ui_card_actions`：详情牌副标题显示当前难度下格数，有加成时为「占秘籍格（5 / 5，炼狱 +2）」；
      - `learn_reason`、`item_learn_reason`（单技能／多技能 code 43／CE）：满格提示带上当前难度与格数（如「炼狱难度下超强者最多装备 5 本秘籍（当前 5 / 5），请先在技能页封印已有秘籍」）；`unseal` 与 `ui_confirm_spec` 自动随 `limit(a, s)` 显示当前难度格数。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_ledger.gd`：
    - `secret_slots(a, s = null)` 同步加上 `XTianqiSecrets.difficulty_bonus(s)`，与 `XTianqiSecrets.limit` 保持单一语义口径（西游档恒加 0）。
  - 专项测试与实机截图：
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_balance.gd`：新增五档×三档 `secret_cap_bonus` 与 `secret_cap(tier, diff_key)` 断言（99/99 通过）。
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_secrets.gd`：新增第 11 节 `_test_t475_difficulty_secret_cap`，覆盖五档×三档矩阵、回退开关、证道 9/7/6 → 寻常 6/4/3 真写盘读档（含 `XState.current = null`）超量封印不丢书与二次读档幂等、切回炼狱免费启封、运行期降九死 `enforce_caps`、炼狱/证道满格文案与新旧两套皮肤功法页 UI、西游高难度档零改动（无头 102/102、窗口含截图 126/126 通过）。
    - 实机截图入仓（炼狱难度超强者 5/5，新旧两套皮肤 × 16:9 / 20:9，排版无溢出无截断）：
      - `00_项目管理/归档/交付截图/luiluu_t475/t475_new_skin_lianyu_5of5_16x9.png`
      - `00_项目管理/归档/交付截图/luiluu_t475/t475_new_skin_lianyu_5of5_20x9.png`
      - `00_项目管理/归档/交付截图/luiluu_t475/t475_old_skin_lianyu_5of5_16x9.png`
      - `00_项目管理/归档/交付截图/luiluu_t475/t475_old_skin_lianyu_5of5_20x9.png`
- 玩家可见：天启篇高难度增加可装备秘籍格数（九死 +1、炼狱 +2、证道 +3，弱/强/超强三档同加；寻常/艰险保持 6/4/3），功法页与满格提示同步显示当前难度下的格数上限；若换到更低难度，超出格数的秘籍自动转为已封印、不丢书。西游原版存档无任何变化。

## 交接板

- 下一步：合并入 main 后，供 T471 按炼狱 8/6/5 格继续开展量数校准。
- 用户试玩说明：天启篇进入九死／炼狱／证道难度时，角色秘籍格上限随难度提高（+1／+2／+3），在技能页功法／被动页签及满格提示中直接可见；换到低难度时超出格数的秘籍自动封印保留、不丢书。西游档无变化。
- 需要用户决定：无

## 进度账

- 天启篇秘籍格规则（D282）：完成难度动态格数加成、降难度超量封印与功法页 UI／文案适配（不涉及主表里程碑百分比变更）。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiBalance.secret_cap` | 13 处含定义（`git grep -nE '[^[:alnum:]_]secret_cap[[:space:]]*\(' -- '*.gd'`） | 核心调用 2 处（`tianqi_secrets.gd:452`、`tianqi_ledger.gd:1084`）均传单参取基础格数再加 `difficulty_bonus(s)`；测试 10 处（`xiyou_tianqi_balance.gd`、`xiyou_tianqi_ledger_p3.gd`、`xiyou_tianqi_secrets.gd`）均已验证通过；新增可选参数 `diff_key := ""` 完全向后兼容单参调用。 |
| `XTianqiBalance.difficulty` / `XTianqi.difficulty` | 48 处调用（`git grep -nE 'XTianqi(Balance)?\.difficulty[[:space:]]*\(' -- '*.gd'`） | 仅在返回字典中新增 `secret_cap_bonus: int` 字段，不改任何已有字段名、类型或默认值，48 处既有调用方全部安全兼容且云端选测 175 场景全绿。 |
| `XTianqiSecrets.limit` | 27 处含定义（`git grep -nE '(XTianqiSecrets\.|[^[:alnum:]_])limit[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_secrets.gd' '03_再刷重制_Godot/01_Godot工程/tests/' \| grep -E 'tianqi_secrets\.gd\|XTianqiSecrets\.limit'`） | `tianqi_secrets.gd` 内部全部调用（`learn_reason`、`item_learn_reason`、`unseal`、`enforce_caps`、`ui_slot_text`、`ui_card_actions`、`ui_confirm_spec`）均透传 `s`，按天启难度加成计算上限、西游档零改动；测试与探针（`xiyou_tianqi_secrets.gd`、`xiyou_tianqi_gongfa_shop.gd`、`t445_book_probe.gd`）均自动获得当前难度下的运行时上限；设 `DIFFICULTY_BONUS = false` 可一键回退 6/4/3。 |
| `XTianqiSecrets.migrate_after_load` | 5 处含定义（`git grep -nE '[^[:alnum:]_]migrate_after_load[[:space:]]*\(' -- '*.gd'`） | `tianqi_save.gd:188` 读档入口与 3 处测试调用均不变，内部将超格收敛逻辑抽为 `enforce_caps(s)` 供读档迁移与运行期降难度共用，保持幂等与不丢书。 |
| `XTianqiSecrets.ui_slot_text` / `ui_card_actions` | 5 处 / 3 处含定义（`git grep -nE '[^[:alnum:]_]ui_(slot_text\|card_actions)[[:space:]]*\(' -- '*.gd'`） | 供 `skill_scene.gd:204`、`skin_skill_page.gd:227,239` 与 `tianqi_secrets.gd:1000` 调用；寻常/艰险与免费期维持原文案兼容既有断言，九死/炼狱/证道清晰注明难度加成，两套皮肤 16:9 / 20:9 实机截图均验证无溢出。 |
| `XTianqiLedger.secret_slots` | 11 处含定义（`git grep -nE '[^[:alnum:]_]secret_slots[[:space:]]*\(' -- '*.gd'`） | `tianqi_ledger.gd:1145`（回退旧截断路径）与 9 处测试调用均已覆盖，与 `XTianqiSecrets.limit` 保持同口径（西游档及寻常/艰险加 0，九死/炼狱/证道 +1/+2/+3）。 |
| `XTianqiSecrets.DIFFICULTY_BONUS`（新增开关） | 仅本模块 `difficulty_bonus(s)` 读取，默认 `true` | 回退开关：置 `false` 时天启篇所有难度秘籍格立即回退至固定 6/4/3，已在 `t475_difficulty_bonus_rollback` 断言验证。 |

## 验收逐条核对

1. **格数＝角色档位基数（弱6/强4/超强3）＋难度加成（寻常/艰险 0、九死 +1、炼狱 +2、证道 +3），专项断言五档×三档**：通过。`balance_table.json`、`XTianqiBalance`、`XTianqiSecrets.limit`、`XTianqiLedger.secret_slots` 统一实现；`xiyou_tianqi_balance.gd` 与 `xiyou_tianqi_secrets.gd`（`t475_matrix_*`）逐一断言五档×三档（6/4/3、6/4/3、7/5/4、8/6/5、9/7/6）及回退开关。
2. **换到低难度时多出的书走 T446 超量封印，书不丢，读档迁移断言**：通过。`t475_downgrade_overflow_seal_and_migration` 实测证道 9/7/6 学满写盘、降为寻常后 `XState.current = null` 真读档迁移，自动封印多出 3/3/3 本、生效收敛至 6/4/3、`skill_ids` 全部保留不丢书、被动失效、二次读档幂等，且切回炼狱可免费启封至 5 格、运行期降九死 `enforce_caps` 收敛至 4 格不丢书。
3. **功法页 UI 显示当前难度下的格数，满格提示文案随之对（文字审）**：通过。已过小A 文字审；`t475_full_slot_wording_by_difficulty` 断言炼狱单书/多书与证道弱者满格提示文案，`t475_ui_new_skin_lianyu_5_of_5` 与 `t475_ui_old_skin_lianyu_5_of_5` 断言新旧两套皮肤显示「秘籍格 5 / 5（炼狱 +2）」与「占秘籍格（5 / 5，炼狱 +2）」，4 张 16:9 / 20:9 实机截图已入仓验证无溢出。
4. **西游档零改动（`XTianqi.active` 守卫）**：通过。`difficulty_key` / `difficulty_bonus` 均以 `XTianqi.active(s)` 守卫；`t475_xiyou_save_zero_change` 断言西游原版高难度（`difficulty = 6`）下 `difficulty_bonus == 0`、`limit` 照 `XTier` 基础值且不启秘籍格。
5. **云端选测全绿，交付自检 0**：通过（见下节测试与校验记录）。

## 测试与校验

- 云端选测（提交 `2c786fb2f2`，`ci/luiluu/t475`，基准 `143c9d9d2e`）：
  - 175 个场景、16 片全部通过（最长一片 6.9 分钟；`xiyou_tianqi_gongfa_shop.tscn` 并行偶发、单跑通过）
  - 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45500087894
- 本机专项与静态检查（前台单跑，`--audio-driver Dummy`）：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：82 个脚本、812 个函数全部通过（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1212 个 `.gd`、0 个问题（退出码 0）
  - `xiyou_tianqi_balance.tscn`：99/99 通过
  - `xiyou_tianqi_secrets.tscn`：无头 102/102 通过；窗口截图模式 126/126 通过
  - `xiyou_tianqi_ledger_p3.tscn`：44/44 通过
  - `xiyou_tianqi_general_books_b2.tscn`：46/46 通过
  - `xiyou_tianqi_gongfa_shop.tscn`：42/42 通过

## 本分支提交

- `2c786fb2f` T475：D282 天启篇秘籍格随难度增加（九死+1、炼狱+2、证道+3，三档同加）
