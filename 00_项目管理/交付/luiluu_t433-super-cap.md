# 交付：luiluu/t433-super-cap

- 车道／工作者：T433 超强者上限为 0 时写「无法获得超强者」／小A（Gemini 4 Neon High＋medium）
- 状态：可合并
- 依赖：**依赖 T431（`luiluu/t431-remove-weak-lineup`，基线提交 `479b10cf2`）**；同改 `modes/xiyou/ui/tianqi_start_page.gd` 与 `tests/xiyou_tianqi_opening.gd`，须在 T431 合并后再合并（或按顺序合入）。

## 做了什么

按 Kyo 11-23 定措辞「改成，无法获得超强者」（T431 核 P3-3）及协调追加授权，修改天启篇开局页与旧回退路径中 `super_cap=0` 档（寻常、艰险）的超强者文案，九死／炼狱／证道原句不变：

1. **新界面难度卡规则行**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/tianqi_start_page.gd` 第 601–635 行）
   - `_rule_rows(d)`：当 `super_cap <= 0`（寻常、艰险）时返回 `["", "无法获得超强者"]`，不再显示「超强者最多上阵 / 0 名」；`super_cap > 0`（九死、炼狱、证道）保持 `["超强者最多上阵", "%d 名"]`（证道照旧保留小注「助力位可再放 1 名超强者」）。
   - `_difficulty_card(d)`：当行标题 `row[0]` 为空时，单行直接用正文样式（16px，`XUiSkin.TEXT`）显示 `row[1]`，避免空标题占位。
2. **新界面阵容页底部规则句**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/tianqi_start_page.gd` 第 710–715 行）
   - `build_lineup`：当 `super_cap <= 0` 时写 `"%s：无法获得超强者"`（寻常：`寻常：无法获得超强者`、艰险：`艰险：无法获得超强者`），不再出现「0 名」；`super_cap > 0` 保持原句（九死：`九死：同一场最多上阵 1 名超强者`、炼狱：`炼狱：同一场最多上阵 2 名超强者`、证道：`证道：同一场最多上阵 2 名超强者；助力位可再放 1 名超强者`）。
3. **旧非皮肤回退路径阵容页标题**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/entry.gd` 第 715–720 行）
   - `_tq_lineup`：当 `super_cap <= 0` 时 `cap_text` 写 `"无法获得超强者"`（寻常：`随机阵容 · 寻常（无法获得超强者）`、艰险：`随机阵容 · 艰险（无法获得超强者）`）；`super_cap > 0` 保持原句（九死／炼狱／证道含证道助力位句不变）。
4. **测试补充**（`03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_opening.gd`）
   - 难度页新增 `page_difficulty_super_cap_text_t433`：校验五档 `_rule_rows` 与卡片 `Label` 文本，寻常／艰险含「无法获得超强者」且不含「0 名」与「超强者最多上阵」，九死／炼狱／证道原句与证道助力位小注不变。
   - 阵容页新增 `page_lineup_rule_super_cap_text_t433`：逐档校验五档 `LineupRule.text` 精确等于预期文案且不含「0 名」。
   - 旧回退路径（`codexUiSkin = false`）新增 `old_lineup_title_super_cap_text_t433`：逐档校验五档旧窗口标题精确等于预期文案且不含「0 名」。

## 开局页截图（已入仓）

- 难度选择页（16:9，寻常／艰险卡写「无法获得超强者」，九死／炼狱／证道原句不变）：`00_项目管理/归档/交付截图/luiluu_t433-super-cap/01_difficulty_16x9.png`
- 寻常阵容页（16:9，规则句「寻常：无法获得超强者」）：`00_项目管理/归档/交付截图/luiluu_t433-super-cap/02_lineup_xunchang_16x9.png`
- 艰险阵容页（16:9，规则句「艰险：无法获得超强者」）：`00_项目管理/归档/交付截图/luiluu_t433-super-cap/03_lineup_jianxian_16x9.png`
- 九死阵容页（16:9，规则句「九死：同一场最多上阵 1 名超强者」）：`00_项目管理/归档/交付截图/luiluu_t433-super-cap/04_lineup_jiusi_16x9.png`

## 验证记录

- 静态与空壳检查：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1187 个 `.gd`，0 个问题（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本，782 个函数都有（退出码 0）
- 本机 Godot 专项测试（无头 `--audio-driver Dummy`）：
  - `res://tests/xiyou_tianqi_opening.tscn`：60/60 通过
  - `res://tests/xiyou_tianqi_title_flow.tscn`：45/45 通过
- 云端选测（提交 `444b765af9`，分支 `ci/luiluu/t433-super-cap`，基准 `479b10cf2a0bc48d67becb1f88db09c9622f9fe3`）：
  - 19 个场景、4 片，最长一片 3.2 分钟，全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45221492237

## 变更记录草稿

### 2026-11-23 【小A·未经审查】天启开局页超强者上限为 0 时改为「无法获得超强者」（dev.待定）

- **改动**：按 Kyo 11-23 定措辞（T433，基于 T431），将 `modes/xiyou/ui/tianqi_start_page.gd` 难度卡规则行与阵容页底部规则句，以及旧非皮肤回退路径 `modes/xiyou/entry.gd:716` 阵容页标题中 `super_cap=0` 档（寻常、艰险）改为「无法获得超强者」（不再出现「0 名」），九死／炼狱／证道原句不变；在 `tests/xiyou_tianqi_opening.gd` 补新旧界面五档断言并入仓开局页 4 张截图。
- **验证**：`语法检查.py` 1187 个 `.gd` 0 问题，`发行空壳.py check` 0，`xiyou_tianqi_opening.tscn` 60/60、`xiyou_tianqi_title_flow.tscn` 45/45 通过；云端选测 19 场景 4 片全过（run `45221492237`）。
- **玩家可见**：天启篇新开局选择「寻常」「艰险」难度时，难度卡片、随机阵容页底部规则句（含原版风格回退窗口标题）均显示「无法获得超强者」，不再显示「最多上阵 0 名超强者」。

## 交接板

- 下一步：合并本单前须先合并 T431（`luiluu/t431-remove-weak-lineup`）。
- 用户试玩说明：天启篇新开局的「寻常」「艰险」难度卡、随机阵容页规则句及原版风格回退窗口标题均改为「无法获得超强者」，九死／炼狱／证道原句不变。
- 需要用户决定：无。

## 进度账

- 天启篇开局页文案（T433）：`super_cap=0` 新旧界面三处措辞修改、五档断言、开局页截图与云端选测全过。

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

- 无（未修改 `core/`、`battle/`、`skin/` 下函数或开关）。

## 本分支提交

- `b92ddbf95` T433 超强者上限为 0 时写「无法获得超强者」
- `d1dfdd5ec` T433 交付单：超强者上限为 0 时写「无法获得超强者」
- `444b765af` T433 旧回退路径 entry.gd:716 同步改「无法获得超强者」
- 本提交：更新 T433 交付单（纳入 `entry.gd:716` 改动、60/60 断言与云端选测 run `45221492237`）
