# 交付：luiluu/t434-hide-super-count

- 车道／工作者：T434 超强者上限 0 时阵容页计数行藏掉超强者／小A（Gemini 4 Neon High＋medium）
- 状态：可合并
- 依赖：**依赖 T433（`luiluu/t433-super-cap`，基线提交 `7fd1e2bcb`；T433 本身依赖 T431）**；同改 `modes/xiyou/ui/tianqi_start_page.gd` 与 `tests/xiyou_tianqi_opening.gd`，须在 T433 合并后再合并（或按顺序合入）。

## 做了什么

按 Kyo 11-23 定案「藏」（T433 核 P3-1），调整天启篇新开局随机阵容页底部计数行（`LineupCount`），`super_cap=0` 档（寻常、艰险）隐藏「超强者 0 / 0」段，其余计数与 `super_cap>0` 档（九死、炼狱、证道）保持不变：

1. **阵容页底部计数行**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/tianqi_start_page.gd:702-715`）
   - `build_lineup`：在 `super_cap <= 0`（寻常、艰险）时，计数行文本仅显示 `"强者 %d　弱者 %d" % [n_strong, n_weak]`，藏掉「超强者 0 / 0」段且无前导空格；`super_cap > 0`（九死、炼狱、证道）保持原格式 `"超强者 %d / %d　强者 %d　弱者 %d"` 不变。
   - 经查旧非皮肤回退路径 `modes/xiyou/entry.gd:_tq_lineup` 无计数行，不涉及修改。
2. **测试补充**（`03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_opening.gd:229-255`）
   - 在 `_title_pages()` 新增 `page_lineup_count_super_cap_t434`：以确定性阵容逐档校验五档 `LineupCount.text`——寻常／艰险精确等于 `"强者 X　弱者 Y"` 且不含「超强者」与 `/`；九死／炼狱／证道精确等于 `"超强者 A / B　强者 X　弱者 Y"`（含证道 `HELPER_RULES` 开关分支）。

## 开局页截图（已入仓）

- 寻常阵容页（16:9，1280×720，左下计数行显示「强者 2　弱者 3」，不显示超强者段）：`00_项目管理/归档/交付截图/luiluu_t434-hide-super-count/01_lineup_xunchang_16x9.png`
- 九死阵容页（16:9，1280×720，左下计数行保持「超强者 1 / 1　强者 3　弱者 1」不变）：`00_项目管理/归档/交付截图/luiluu_t434-hide-super-count/02_lineup_jiusi_16x9.png`

## 验证记录

- 静态与空壳检查：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1187 个 `.gd`，0 个问题（退出码 0）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本，782 个函数都有（退出码 0）
- 本机 Godot 专项测试（无头 `--audio-driver Dummy`）：
  - `res://tests/xiyou_tianqi_opening.tscn`：61/61 通过
  - `res://tests/xiyou_tianqi_title_flow.tscn`：45/45 通过
- 云端选测（提交 `026dd4424a`，分支 `ci/luiluu/t434-hide-super-count`，基准 `7fd1e2bcb58ea54092155698633b6e124f6f9f87`）：
  - 5 个场景、1 片，最长一片 4.6 分钟，全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45253525102

## 变更记录草稿

### 2026-11-23 【小A·未经审查】天启开局阵容页 super_cap=0 时隐藏超强者计数（dev.待定）

- **改动**：按 Kyo 11-23 定案（T434，基于 T433），调整 `modes/xiyou/ui/tianqi_start_page.gd` 阵容页底部计数行，在 `super_cap<=0`（寻常、艰险）时隐藏「超强者 0 / 0」段，仅显示强者与弱者计数；九死／炼狱／证道保持原格式不变；在 `tests/xiyou_tianqi_opening.gd` 补五档计数行精确断言并入仓寻常、九死 16:9 截图各一张。
- **验证**：`语法检查.py` 1187 个 `.gd` 0 问题，`发行空壳.py check` 0，`xiyou_tianqi_opening.tscn` 61/61、`xiyou_tianqi_title_flow.tscn` 45/45 通过；云端选测 5 场景 1 片全过（run `45253525102`）。
- **玩家可见**：天启篇新开局选择「寻常」「艰险」难度进入随机阵容页时，左下角计数行仅显示强者与弱者人数，不再显示「超强者 0 / 0」；九死／炼狱／证道不变。

## 交接板

- 下一步：合并本单前须先合并 T433（`luiluu/t433-super-cap`，依赖 T431）。
- 用户试玩说明：天启篇新开局「寻常」「艰险」随机阵容页左下计数行隐藏了「超强者 0 / 0」，仅保留强者／弱者计数；九死／炼狱／证道照旧。
- 需要用户决定：无。

## 进度账

- 天启篇开局页计数行（T434）：`super_cap=0` 隐藏超强者段、五档断言、寻常／九死截图与云端选测全过。

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

- 无（未修改 `core/`、`battle/`、`skin/` 下函数或开关）。

## 本分支提交

- `026dd4424` T434 超强者上限 0 时阵容页计数行藏掉超强者
- 本提交：T434 交付单（含云端选测 run `45253525102`）
