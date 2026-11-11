# 交付：claude/project-thread-fxqj11

- 车道／工作者：天启篇·五档难度与档位数值表（数据层）／cc（Pro，云端容器）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇档位与五档难度数值表、只读加载器、对照校验（dev.待定）

- 设计仓库交接单「五档难度与档位数值表」：把 Kyo 拍板的天启篇数值测算参数（设计仓库 `重制设定/数值测算/参数.json`，提交 7767262）做成游戏数据表。**只做数据和测试，不接进任何流程**：伤害结算不读档位出伤与协力，开局仍用 `XTianqi.DIFFICULTIES`（legacy 借原版难度）。
- 新文件 `modes/xiyou/tianqi_data/balance_table.json`：档位（弱者／强者／超强者：出伤 0／+50%／+150%，承伤 0／−10%／−30%，秘籍上限 6／4／3）；弱者协力（每名上场弱者全队出伤 +3%、承伤 −2%，助力位不算）；五档难度（键、名、`scaling` 敌人血量／敌人攻击／我方伤害／品质偏移标 `draft`，`roster` 候选池／超强者上限／至少弱者）；助力位光环全队出伤 +5%（`draft`）。表头 `version`、`source`、`dev`，以及「数值不出现 4」的豁免键 `nice_number_exempt`（version、secret_cap、super_cap、min_weak）。
- 新文件 `modes/xiyou/core/tianqi_balance.gd`（`XTianqiBalance`）：只读加载，`tier(name)`／`tier_damage_mult`／`tier_taken_mult`／`secret_cap`（档位名用 `XTier.WEAK／STRONG／SUPER`）、`difficulty(key)`（拍平成一行）、`difficulty_keys()`、`assist_bonus(weak_count)`（按上场 4 人封顶）、`assist_slot_aura()`、`team_damage`／`team_taken`（全队相对出伤／承伤，测试用）、`nice_number_violations()`。不读转换产物、不引用 XDB。
- 新专项 `xiyou_tianqi_balance`（85 项）：三档位五难度齐全；难度键、顺序、名、`super_cap`、`min_weak` 与 `XTianqi.DIFFICULTIES` 一致，候选池与 `XTianqi.pool` 的规则（超强者上限 > 0 才进池）一致；档位单调；档位盖过本体 ±20%；4 人上场时协力不让弱者多的队更强（换强者、换超强者各一遍，出伤与承伤）；敌人血量、攻击从寻常到证道不降，寻常、艰险没有超强者；设计数值不含 4。
- 新脚本 `03_转换工具/天启篇数据校验.py`（只用标准库）：B 组同上规则自检（难度键用正则从 `core/tianqi.gd` 取）；A 组 `--params <设计仓库>/重制设定/数值测算/参数.json` 逐项对照档位、协力、五档、助力位，不一致打印「项、游戏数据、参数.json」并退出 1；不给 `--params` 打印「跳过：没有参数.json」，退出 0。脚本写成「每张表一个检查函数」（`CHECKS`），词条表那张单往里登记 `affix_table`。
- 玩家可见：无（还没接线）。

## 交接板

- 下一步：天启篇数值接线（Max 等开局第二批合并后另派）：伤害结算按 `XTianqiBalance` 叠档位出伤／承伤与弱者协力（独立乘区只乘一次），开局与出战限制改读本表或与本表对齐；`XTianqi.DIFFICULTIES` 的 `super_cap`／`min_weak` 要不要改读本表，由接线时定（本次按交接单没挪）。
- 用户试玩说明：无。
- 需要用户决定：无（见下「需要对方做什么」里给总装的两条）。

## 优化登记

- 无（没加开关；本表不进任何流程）。

## 进度账

- 无（天启篇改版，不计重制完成度）。

## 可优化（流程／工具／效率）

- 建议：`语法检查.py` 通过 `07_开发环境/godot` 包装调 Godot，包装写死 Mac 的 `当前Godot.app`；云端容器有 `$GODOT` 也用不上，只能扫同名 func。可让包装在没有 .app 时读 `$GODOT`（工具车道）。
- 建议（沿用 d4k4ag 交付单那条）：`工具回归.py` 的「选测替身与 检查.sh 解析」在云端 Linux 挂 13 项（`mktemp` 模板在 GNU 下要求 XXXXXX、没装 zsh 时调不起 `检查.sh`），与本分支改动无关。

## 需要总装做什么

- **和「词条实装数据层」那条分支合 `天启篇数据校验.py`**：两边都新建了同名脚本（本分支先建、那边可能也建）。合法：保留一份，`CHECKS` 里两项都登记（`balance_table`、`affix_table`），`--params` 只给 balance 用。两边都用 `modes/xiyou/tianqi_data/` 目录。
- 开局第二批（`claude/project-thread-d4k4ag`）合并后有 `XTianqi.FIGHTERS := 4`；接线时可让 `XTianqiBalance.FIELD_SIZE` 改引用它（本次按交接单不碰 `tianqi.gd`，先写死 4）。
- `选测.py main --list` 选了 `xiyou_event_compare*` 四份＋`xiyou_tianqi_balance`；事件对照四份要转换产物，云端跑不了，请在 Mac 上按影响面决定跑不跑（新类没有任何地方引用，事件对照不会受影响）。

## 验证

- 专项 `xiyou_tianqi_balance` 云端容器（Godot 4.7.2，无转换产物）单跑 85/85；`--import` 无 SCRIPT ERROR。
- `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：规则自检通过，对照参数打印「跳过：没有参数.json」，退出 0。
- 同上加 `--params <设计仓库 7767262>/重制设定/数值测算/参数.json`：规则自检通过、对照参数通过，退出 0。
- 反向验证（Godot 用 `07_开发环境/反向验证.py`，Python 用同一份清单逐项改表跑脚本，跑完字节还原）：表里 ① 强者出伤 0.5→0.3 ② 九死敌人攻击 1.25→1.4（含 4）③ 协力出伤 0.03→0.2 ④ 九死超强者上限 1→2 ⑤ 炼狱敌人血量 2.0→1.2 ⑥ 超强者承伤 −0.3→0，六处 Godot 专项与 Python 脚本都挂（Python 同时报规则与对照两类）；参数一侧（表不动）⑦ 强者出伤 0.3 ⑧ 协力承伤 −0.03 ⑨ 证道候选池去掉超强者 ⑩ 助力位光环 0.06，A 组都挂。基线全过。
- `语法检查.py`：云端只做了同名 func 检查（Godot 包装找不到 Mac 版，见「可优化」）；两份新 .gd 已由专项实际加载。
- 工具回归：14 项过；「选测替身与 检查.sh 解析」云端环境原因挂（见「可优化」），与本分支无关。
- 没跑：`xiyou_event_compare*`（要转换产物，见上）。

## 待交叉核查

- 乙档：`modes/xiyou/tianqi_data/balance_table.json`（和参数.json 对照）、`modes/xiyou/core/tianqi_balance.gd`、`tests/xiyou_tianqi_balance.gd`、`03_转换工具/天启篇数据校验.py`。

## 本分支提交

- 9ea767ec 天启篇：档位与五档难度数值表、只读加载器 XTianqiBalance、Godot 规则自检
- （本提交）天启篇数据校验.py 与交付单
