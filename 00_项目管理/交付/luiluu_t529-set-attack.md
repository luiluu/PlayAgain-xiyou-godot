# 交付：luiluu/t529-set-attack

- 车道／工作者：T529 套装攻类改单独乘（2B 续）（小A，Gemini 4 Neon＋high，P8）
- 状态：可合并
- 基准：main `cb8cf51fa`（已合 T513 2A、T515 2B、T535 等）

## 变更记录草稿

## 2026-11-26 【小A·T529·未经审查】套装攻类改单独乘（2B 续）＋收 T515 P2 template_on 解耦（dev.待定）

- 依据：预算稿 `重制设定/天启篇_全局数值预算_v0.16.md`（@093e51d1，三家同意）第六.3／第九.6 甲与配套 `附表一 2B`；D290（Kyo 11-26 拍板第九节全按推荐）；拆卡草稿 `协作交接/拆卡草稿/T522_后续卡草稿.md` N06；T515 核查 P2-1；协调确认（三处边界均选 A：`damage.gd` 候选循环 2 行最小接线、攻·本系稿定排 `1/2/4/6` 放行 4、照附表一 2B 验模板本身）。查重确认 `tianqi_suits.gd`／`suit_template.json` 仅合到 T513／T515，零重复。
- 模板表 `modes/xiyou/tianqi_data/suit_template.json`（version 1 → 2）：
  - `kinds.atk_final`（攻·伤害）与 `kinds.atk_element`（攻·本系伤害）标 `standalone: true`（保留 `affix` 键供回退开关 `ATTACK_STANDALONE = false` 使用）；守类、功能类、掉率类不变。
  - 新增 `values_by_kind.atk_element` 独立排（照附表一 2B 稿定，全整数）：2 件 `[1, 2, 4, 6]`、3 件 `[6, 7, 10, 12]`、5 件 `[11, 13, 16, 20]`（单套 5 件四阶 ×1.20，两套 5+2 四阶 ×1.26；2 件三阶为稿定数字 `4`，同 `brand.json` 先例；默认 `values` 排仍维持不出 4，供 `atk_final` 及守／功能／掉率共用：5 件四阶 ×1.15、5+2 ×1.20）。
- 套装模板引擎 `modes/xiyou/core/tianqi_suits.gd`：
  - 新增 `XTianqiSuits.attack_mult(a, b, element_id)` 与回退开关 `XTianqiSuits.ATTACK_STANDALONE`（O-待定，默认 `true`）：攻·伤害与对口攻·本系在同一个独立乘区里相加（`1.0 + sum / 100.0`，不逐套相乘），不再生成 `tqAffix` 进词条池；只对天启篇我方打敌人（`a is XActor and not (b is XActor)`）生效；西游档、开关关恒返回 `1.0`（发行空壳规则 2 自动生成 `return 1.0`）。
  - 模板缓存 `_tpl_bonus` 键并入 `standalone` 标志，运行期切换 `ATTACK_STANDALONE` 无需手动清缓存。
  - 收 T515 P2-1：`template_on(a)` 改为 `TEMPLATE and a is XActor and XTianqi.active(XState.current)`，与 2A 上限开关 `ENABLED` 解耦；`bonuses_of` 对走词条通道的类别（`def_*`/`func_*`，以及 `ATTACK_STANDALONE = false` 时的攻类）校验 `XTianqiAffixBattle.on()`，词条战斗层关闭时保留原套装效果，不再替换成白板（掉率类与独立乘攻类不受词条层关闭影响）。
- 伤害结算接线 `modes/xiyou/core/damage.gd`（经协调批准最小 2 行）：
  - `_calculate` 候选循环内计算 `suit_mult = 1.0 if absorb or not hp_type else XTianqiSuits.attack_mult(a, b, oe)` 并乘入 `gross`；只影响天启篇我方打敌人的 HP 伤害／吸取（非吸收），混穿逐招按攻击方原系 `oe`（双系逐候选、属性转换按转换前原系、DECK 物理无属性按物理 1）独立结算，不触发 `XTianqiLedger.audit`，西游档零改动。
- 数据校验 `03_转换工具/天启篇数据校验.py` 与 `03_转换工具/测试天启篇数据校验.py`：
  - `suit_template_rules` 同步校验 `kinds.*.standalone`（仅限 `atk` 且非 `drop`）与 `values_by_kind`（逐阶逐档严格递增；仅 `atk_element` 稿定排放行数字 `4`，默认 `values` 排与其余类别仍拦截 `4`）；新增 `test_t529_standalone_and_values_by_kind` 6 项反测全过。
- 专项 `tests/xiyou_tianqi_suit_template.gd`（32 → 48 项，全过）：
  - 攻·伤害（5 件 ×1.15／5+2 ×1.20）、攻·本系（5 件 ×1.20／5+2 ×1.26）在基准配与极品最优配各量一次真实 `XDamage.calculate`，确认恒不稀释且同区相加（显式反证非 `1.15×1.05=1.2075`、`1.20×1.06=1.272`）。
  - 混穿逐招：本系 5＋通用 2（本系 ×1.25、别系 ×1.05）、通用 5＋本系 2（本系 ×1.21、别系 ×1.15）、本系 5＋另一系 2（火 ×1.20、冰 ×1.06、雷／无属性 ×1.00）；双系招逐候选；属性转换招（原火转雷 `row.element == 5`）按转换前原系火结算；MP 伤／治疗／打队友不乘；总账守卫 0 违规。
  - 全表 4 阶 × 2/3/5 件逐档增、逐阶增；T515 P2 双解耦（`ENABLED = false` 仍走模板、`XTianqiAffixBattle.ENABLED = false` 防白板）；`ATTACK_STANDALONE = false` 与 `TEMPLATE = false` 回退；西游档零改动。
- 玩家可见：天启篇里攻类模板套（样板：14 高阶火焰、23 所有伤害板甲）改为独立乘区结算，不被词条／终伤／元素池稀释；高阶火焰 3 件四阶从池内 +10% 变为独立乘 ×1.12，所有伤害板甲 3 件四阶从池内 +10% 变为独立乘 ×1.10；西游档无变化。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_suits.gd` `XTianqiSuits.ATTACK_STANDALONE` | （T515 2B）攻·伤害进终伤词条池、攻·本系进元素词条池（共用默认排 1/2/3/5、5/6/8/10、8/10/12/15），高词条下被稀释 | 攻·伤害（×1.15／×1.20）与攻·本系（另排 1/2/4/6、6/7/10/12、11/13/16/20，×1.20／×1.26）改独立乘、同一乘区相加、混穿逐招，不进词条池；西游档零改动 | 预算稿 v0.16 六.3／九.6 甲／附表一 2B＋D290（Kyo 11-26） | `XTianqiSuits.ATTACK_STANDALONE = false` | 小A（T529） | 保留 |

## 交接板

- 下一步：T530（N07 总账改造核心）可继续接 `damage.gd`（本单在 `damage.gd:413-414` 仅 2 行独立乘接线，注释清晰、冲突面极小）；2C（约 130 套归类）与 2F（全角色矩阵与拆顶前置）已可按新攻类单独乘引擎开工。
- 用户试玩说明：天启篇穿高阶火焰（14）或所有伤害板甲（23）打本系／通用招时，增伤改为独立乘区，不再与词条伤害加成互相稀释。
- 需要用户决定：无（九.6 甲与附表一 2B 均已由 D290 拍板）。

## 进度账

- 部件 9（数值总账与养成）：T522 后续卡 N06（2B 续，套装攻类单乘＋T515 P2 收口）完成，交由总装按账记。

## 可优化（流程／工具／效率）

- 建议：`07_开发环境/启封数值对账.py`（口径 19）与 `启封数值对账_来源.py` 仍按旧口径把 `atk_final`/`atk_element` 记在 `③伤害加成%`/`②元素伤%` 且只读默认 `values`；后续对账更新时可读取 `values_by_kind.atk_element` 与 `standalone: true` 归入独立乘区列（归对账脚本维护车道，本单不越界改）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XDamage._calculate` | 非测试调用 1 处，定义 1 处（`git grep -nE '[^[:alnum:]_]_calculate[[:space:]]*\(' -- '*.gd' ':!*/tests/*'`；外层 `XDamage.calculate` 非测试调用 14 处） | 调用方 1 处逐处结论：`XDamage.calculate`（`damage.gd:239`）。仅在候选循环内（`damage.gd:413-414`）乘入 `suit_mult`；吸收、非 HP 伤害／吸取、西游档、开关关或未穿归类攻类模板套时 `suit_mult` 恒为 `1.0`，`row` 字段结构与 `XTianqiLedger.pools`/`audit` 均不变，既有调用方不会被改坏 |
| `XTianqiSuits.template_on` | 非测试调用 3 处（`git grep -nE '[^[:alnum:]_]template_on[[:space:]]*\(' -- '*.gd' ':!*/tests/*'`） | 调用方 3 处逐处结论：全在 `tianqi_suits.gd` 内部（`bonuses_of`、`attack_mult`、`affix_entries`）。去掉对 2A 开关 `ENABLED` 的耦合（收 T515 P2），仍守卫 `TEMPLATE and a is XActor and XTianqi.active(XState.current)`，西游档恒 false |
| `XTianqiSuits.template_value` | 非测试调用 1 处（`git grep -nE '[^[:alnum:]_]template_value[[:space:]]*\(' -- '*.gd' ':!*/tests/*'`） | 调用方 1 处逐处结论：`_template_bonus`（`tianqi_suits.gd:293`）。仅在 `_kind_standalone(kind)` 为真且 `values_by_kind` 有该键（当前仅 `atk_element`）时读独立排，其余类别及 `ATTACK_STANDALONE = false` 均照旧读默认 `values` 排 |
| `XTianqiSuits.bonuses_of` | 非测试调用 1 处（`git grep -nE '[^[:alnum:]_]bonuses_of[[:space:]]*\(' -- '*.gd' ':!*/tests/*'`） | 调用方 1 处逐处结论：`XEquipSuits._active_now`（`equip_suits.gd:32`）。新增对词条通道类别校验 `XTianqiAffixBattle.on()`，词条层开启时行为不变，关闭时原样返回原套装档防白板；首句守卫不变，发行空壳仍照搬 `return bonuses` |
| 新函数 `XTianqiSuits.attack_mult` | 非测试调用 1 处（`git grep -nE '[^[:alnum:]_]attack_mult[[:space:]]*\(' -- '*.gd' ':!*/tests/*'`） | 调用方 1 处逐处结论：`XDamage._calculate`（`damage.gd:413`）。西游档、开关关、目标为我方角色时首句返回 `1.0`；发行空壳自动生成 `return 1.0` |
| 新开关 `XTianqiSuits.ATTACK_STANDALONE`（O-待定） | 新增 | 默认 `true`；`false` 退回 T515 词条池与默认排，登记见上「优化登记草稿」 |

## 验证与反证

- **本机前台专项（全部带 `--audio-driver Dummy`，单场景前台跑）**：
  - `res://tests/xiyou_tianqi_suit_template.tscn`：`48/48` 通过（退出 0）
  - `res://tests/xiyou_tianqi_suit_cap.tscn`：`41/41` 通过（退出 0）
  - `res://tests/xiyou_tianqi_nine_off.tscn`：`19/19` 通过（退出 0）
  - `res://tests/xiyou_tianqi_affix_battle.tscn`：`86/86` 通过（退出 0）
  - `res://tests/xiyou_tianqi_drop.tscn`：`102/102` 通过（退出 0）
  - `res://tests/xiyou_tianqi_ledger.tscn`：`83/83` 通过（退出 0）
- **撤修复反证（保留新测试、临时撤回修复验证测试确实抓错）**：
  - **反证 A（撤回 `damage.gd` 2 行独立乘接线）**：跑 `res://tests/xiyou_tianqi_suit_template.tscn` 退出码 `1`，`38/48` 通过、**10 项失败**：`atk_final_steps_base`、`atk_final_steps_peak`、`atk_elem_steps_base`、`atk_elem_steps_peak`、`mix_elem5_fin2`、`mix_fin5_elem2`、`mix_elem5_other2`、`dual_element_per_candidate`、`converted_uses_original_element`、`rollback_attack_standalone`（全部伤害比值跌回 `1.0`）。恢复接线后重跑 `48/48`。
  - **反证 B（撤回 `tianqi_suits.gd` T515 P2 解耦与词条层守卫）**：跑 `res://tests/xiyou_tianqi_suit_template.tscn` 退出码 `1`，`46/48` 通过、**2 项失败**：`p2_decoupled_from_cap`（`[0,{},1.0]`）、`p2_affix_off_no_blank`（`[false,true,true,false]`）。恢复修复后重跑 `48/48`。
- **数据校验与工程静态检查**：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：退出码 `0`（全部通过，含 `suit_template.json 规则自检：通过`）
  - `python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`：退出码 `0`（156 tests OK，含 `SuitTemplateT515` 4/4）
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：退出码 `0`（1242 个 `.gd`，0 个问题）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：退出码 `0`（86 个脚本，846 个函数都有；`XTianqiSuits.attack_mult` 自动生成 `return 1.0`）
  - `python3 03_再刷重制_Godot/07_开发环境/发行预设排除检查.py`：退出码 `0`（493 个脚本／场景 × 3 个发行预设无排除）
- **云端选测（`gh run watch 45871850763 --exit-status` 前台等完）**：
  - 提交 `336603e403`（`ci/luiluu/t529-set-attack`，基准 `cb8cf51faa`）：**139 个场景、11 片全部通过**（最长一片 11.4 分钟，退出码 0）
  - 运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45871850763
- **截图**：本单无界面改动，没有截图。

## 没做／偏离

- `modes/xiyou/core/damage.gd` 不在派单初稿独占文件列表，经开工前 `ask` 获协调批准加 2 行最小接线（`msg_b7b150dd7d04` 选 A）。
- `suit_template.json` 攻·本系 2 件三阶数值为 `4`（来自附表一 2B `1/2/4/6`＋D290 稿定），经协调批准仅对该稿定排放行 `4`（照 `brand.json` 先例），默认 `values` 排与其余类别仍严格不出 `4`。
- 照附表一 2B 与协调确认（选 A），本单只验模板引擎本身（基准配与极品最优配各一次、2/3/5 件逐档增、混穿逐招、解耦、回退、西游零改动），不另跑 T438 五档 3 种子长战；全角色矩阵归 2F。
- 装备说明卡上的套装文字显示仍为原版文字，留给界面小单处理（同 T515 登记）。

## 本分支提交

- `336603e40` T529：套装攻类改单独乘（2B 续）＋收 T515 P2 template_on 解耦
