# 交付：luiluu/t431-remove-weak-lineup

- 车道／工作者：T431 随机阵容取消弱者人数下限（D265）／小A（Gemini Neon high＋medium）
- 状态：可合并

## 做了什么

按 D265（Kyo 11-23 定「只保留低难度不出超强者。弱者数量不限制」）及设计仓库 `重制设定/数值测算/参数.json`（五档「至少弱者」均已改 0），取消天启篇随机阵容的弱者人数下限，同时保留候选池、超强者上限、证道助力位许可及全弱者相关规则不动：

1. **数值表**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json`）
   - 五档难度（寻常／艰险／九死／炼狱／证道）的 `roster.min_weak` 全部由 `4/3/3/2/2` 改为 `0`（保留 `min_weak` 字段为 `0`，与 `参数.json` 和 `天启篇数据校验.py` 逐项对齐）；候选池 `pool`、超强者上限 `super_cap`、`helper_super` 不动。
2. **随机阵容生成与校验**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi.gd`）
   - `roll_lineup`：去掉「先按 `min_weak` 抽弱者」步骤，改为直接从本档候选池 `pool(key)` 均匀抽满 5 人，仍按 `lineup_super_max(key)` 限制超强者数，打乱顺序并按 `HELPER_RULES` 排位。
   - `lineup_ok`：不再统计弱者数或检查 `weak >= int(d.min_weak)`；仍校验 5 人、无重复、全在本档候选池、超强者总数与前 4 格上限及助力位超强者许可。
   - `difficulty()` 仍从 `XTianqiBalance.difficulty(key)` 并入 `min_weak`（现五档皆为 0），保持单一来源与下游兼容。
3. **开局页文案**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/tianqi_start_page.gd`）
   - `_rule_rows`（原 629 行）：去掉难度卡的 `["弱者至少", "%d 名"]` 行，只保留「能抽到」与「超强者最多上阵」（证道仍保留小注「助力位可再放 1 名超强者」）。
   - `build_lineup`（原 705 行）：底部规则句由 `"%s：同一场最多上阵 %d 名超强者，至少 %d 名弱者"` 改为 `"%s：同一场最多上阵 %d 名超强者"`（证道仍拼接 `"；助力位可再放 1 名超强者"`）。
4. **测试与工具适配（均注明因 D265 修改）**
   - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_balance.gd`：新增 D265 断言，检查五档 `min_weak == 0`。
   - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_opening.gd`：因 D265 将五档随机抽样从 200 次扩至 1000 次，去掉 `weak < d.min_weak` 约束，新增弱者数 0～5 范围与寻常／艰险出现 0 弱者断言、五档 0 弱者与全弱者 `lineup_ok` 合法断言，以及难度卡与阵容页不再显示「弱者至少」文案断言。
   - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_team_builder.gd`、`tests/virtual_player/team_builder.gd`：因 D265 取消弱者人数下限（`min_weak=0` ⇒ `min_weak_field("jianxian") == 0`），更新艰险档配队测试（允许 4 强合法、保留拒绝超强者／重复／人数不对断言），并同步注释。
5. **关于「弱者挑战开关（真·无名者之路）」的实话说明**
   - 核对全仓代码：`modes/xiyou/` 中「真·无名者之路」开局开关尚未实装（见 `tests/virtual_player/zhengdao_scenarios.gd:18` 注明未实装）。现有全弱者通关判定 `XTianqiWeakClear`、原版弱者挑战 `XWeakChallenge` 及虚拟玩家只选弱者入口 `virtual_player.gd`（`weak_only`／`--vp-weak`，从弱者池取 5 名弱者并过 `XTianqi.lineup_ok`）均未改动且全弱者阵容仍合法通过。

## 开局页截图（已入仓）

- 难度选择页（16:9，去掉「弱者至少」行）：`00_项目管理/归档/交付截图/luiluu_t431-remove-weak-lineup/01_difficulty_16x9.png`
- 寻常阵容页（16:9，0 弱者 5 强者阵容，规则句无「至少 N 名弱者」）：`00_项目管理/归档/交付截图/luiluu_t431-remove-weak-lineup/02_lineup_xunchang_0weak_16x9.png`
- 炼狱阵容页（16:9，规则句「炼狱：同一场最多上阵 2 名超强者」）：`00_项目管理/归档/交付截图/luiluu_t431-remove-weak-lineup/03_lineup_lianyu_16x9.png`

## 五档各 1000 次随机阵容抽样分布（种子 20261123）

| 难度 | 候选池人数（弱/强/超） | 超强者上限 | 实测最大超强（前4/总/助力位次数） | 弱者数分布（0 / 1 / 2 / 3 / 4 / 5 名） | 不合规数 |
| --- | --- | --- | --- | --- | --- |
| 寻常 (`xunchang`) | 83 / 54 / 0 | 0 | 0 / 0 / 0 | 5 / 86 / 230 / 358 / 250 / 71 | 0 |
| 艰险 (`jianxian`) | 83 / 54 / 0 | 0 | 0 / 0 / 0 | 9 / 66 / 183 / 372 / 296 / 74 | 0 |
| 九死 (`jiusi`) | 83 / 54 / 16 | 1 | 1 / 1 / 0 | 14 / 95 / 299 / 348 / 196 / 48 | 0 |
| 炼狱 (`lianyu`) | 83 / 54 / 16 | 2 | 2 / 2 / 0 | 26 / 114 / 273 / 335 / 207 / 45 | 0 |
| 证道 (`zhengdao`) | 83 / 54 / 16 | 2（助力位可再放 1） | 2 / 3 / 119 | 20 / 137 / 267 / 338 / 201 / 37 | 0 |

## 验证结果

- **数值表校验（对照设计仓库 `参数.json`）**：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py --params <设计仓>/重制设定/数值测算/参数.json`：全部通过（退出码 0，`balance_table.json` 规则自检＋对照参数通过）
- **语法检查与发行空壳检查**：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1187 个 `.gd`，0 个问题（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本，782 个函数都有（退出码 0）
- **工具回归与守卫**：
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`：23/23 全部通过（退出码 0）
  - `探针登记检查.py`、`天启篇存档登记.py`、`随机守卫.py`、`变更记录分卷.py --check`：均通过（退出码 0）
- **本机 Godot 专项测试（无头 `--audio-driver Dummy`）**：
  - `res://tests/xiyou_tianqi_balance.tscn`：93/93 通过
  - `res://tests/xiyou_tianqi_numbers.tscn`：67/67 通过
  - `res://tests/xiyou_tianqi_opening.tscn`：57/57 通过
  - `res://tests/xiyou_tianqi_zhengdao_party.tscn`：94/94 通过
  - `res://tests/xiyou_tianqi_team_builder.tscn`：118/118 通过
  - `res://tests/xiyou_tianqi_weak_clear.tscn`：46/46 通过
  - `res://tests/xiyou_tianqi_title_flow.tscn`：45/45 通过
  - `res://tests/xiyou_tianqi_e2e.tscn`：60/60 通过
  - `res://tests/xiyou_tianqi_party.tscn`：33/33 通过
- **云端选测**（提交 `35cf5da09d`，分支 `ci/luiluu/t431-remove-weak-lineup`，基准 `d6ded643dfa8d2e666aea84406c43ad62a9a9384`）：
  - 158 个场景、16 片，最长一片 5.9 分钟，全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45214453766

## 变更记录草稿

### 2026-11-23 【小A·未经审查】天启篇随机阵容取消弱者人数下限（D265）（dev.待定）

- **改动**：按 D265 将 `balance_table.json` 五档难度 `roster.min_weak` 全部改为 `0`（对齐设计仓库 `参数.json`）；`core/tianqi.gd` 的 `roll_lineup` 去掉先抽弱者步骤、`lineup_ok` 去掉弱者人数校验（候选池、超强者上限、证道助力位许可与全弱者相关规则不变）；`ui/tianqi_start_page.gd` 的难度卡 `_rule_rows` 与阵容页规则句去掉「弱者至少 N 名」文案；同步因 D265 更新 `xiyou_tianqi_balance`、`xiyou_tianqi_opening`、`xiyou_tianqi_team_builder` 测试并入仓开局页 3 张截图。
- **验证**：`天启篇数据校验.py --params` 退出码 0，`语法检查.py` 0 问题，`发行空壳.py check` 0，`工具回归.py` 23/23，`xiyou_tianqi_balance` 93/93、`xiyou_tianqi_numbers` 67/67、`xiyou_tianqi_opening` 57/57、`xiyou_tianqi_zhengdao_party` 94/94、`xiyou_tianqi_team_builder` 118/118、`xiyou_tianqi_weak_clear` 46/46、`xiyou_tianqi_title_flow` 45/45、`xiyou_tianqi_e2e` 60/60、`xiyou_tianqi_party` 33/33，云端选测 158 场景 16 片全过（run `45214453766`）。
- **玩家可见**：天启篇新开局随机阵容五档均不再强制包含固定数量弱者，寻常／艰险可随出纯强者阵容（仍不出超强者）；选难度页与随机阵容页不再显示「弱者至少 N 名」。

## 交接板

- 下一步：合并后后续实装「真·无名者之路」开局开关时照旧独立限制只从弱者池抽取，不依赖 `min_weak`。
- 用户试玩说明：天启篇新开局随机阵容五档不再限制弱者人数下限，寻常／艰险仅保留「不出超强者」，选难度页与阵容页同步去掉「弱者至少 N 名」提示。
- 需要用户决定：无（已按 D265 落地）。

## 进度账

- 天启篇开局随机阵容规则（T431／D265）：五档取消弱者人数下限，数据、核心逻辑、开局页文案与测试对齐完成。

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqi.roll_lineup` | 5 处（`git grep -nE '[^[:alnum:]_]roll_lineup[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'` 去掉定义 1 处） | 调用方 5 处逐处结论：`modes/xiyou/entry.gd:705`（开局页抽 5 人）仍返回 5 人合规阵容、不依赖弱者下限；`tests/virtual_player/virtual_player.gd:771`（按种子抽阵容，`--vp-weak` 另走弱者池）不受影响；`tests/xiyou_tianqi_opening.gd:86` 已按 D265 更新为 1000 次抽样校验；`tests/xiyou_tianqi_zhengdao_party.gd:241, 259` 只验超强者／助力位与同种子复现，94/94 通过。 |
| `XTianqi.lineup_ok` | 33 处（`git grep -nE '[^[:alnum:]_]lineup_ok[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'` 去掉定义 1 处） | 调用方 33 处逐处结论：`modes/xiyou/entry.gd:757`（1 处）确认阵容校验放行 0～5 弱者、继续拦截超强者越限与非法助力位；`tests/virtual_player/virtual_player.gd:776, 783`（2 处）全弱者与点名阵容仍过；`tests/xiyou_tianqi_e2e.gd:464, 472, 663, 670`（4 处）与 `tests/xiyou_tianqi_title_flow.gd:169`（1 处）只验合法性、不依赖弱者下限；`tests/xiyou_tianqi_opening.gd`（14 处）已按 D265 补 0 弱者与全弱者断言通过；`tests/xiyou_tianqi_zhengdao_party.gd`（11 处）均验超强者上限、重复与助力位规则，94/94 通过。 |

## 本分支提交

- `35cf5da09` T431 随机阵容取消弱者人数下限（D265）
- 本提交：补充 T431 交付单（`00_项目管理/交付/luiluu_t431-remove-weak-lineup.md`，云端选测 run `45214453766` 全过）
