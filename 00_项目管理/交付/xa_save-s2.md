# 交付：xa/save-s2

- 车道／工作者：存档门面 S2／ag（默认模型，协调派单 task_4e406e922414）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【ag·存档门面S2·未经审查】其余 14 个天启篇分区接进 XTianqiSave，三处复制路径接 strip_on_copy（dev.待定）

- 14 个已登记分区从各模块「就地补」换成 `XTianqiSave.section()`（只读判断走 `XTianqiSave.peek()`，公式、键名、默认值一字未改）：四线 `war`／`famine`／`plague`／`death`（`tianqi_line.gd` `progress`＋`fill`）、`famine_prologue`（数组形，`tianqi_famine_line.gd` `_said`）、`summit`（`tianqi_summit.gd` `progress`）、`weak_clear`（`tianqi_weak_clear.gd` `finish`／`has`）、`rewards`（`tianqi_rewards.gd` `progress`＋`fill`）、`elements`（`tianqi_elements.gd` `store`＋`fill`）、`money`（`tianqi_money.gd` `money`）、`trumpet`（`tianqi_trumpet.gd` `store`／`dropped`＋`fill`）、`skill_grow`（`tianqi_skills.gd` `grow_count`／`_kill_grow`）、教派包丙 `sect_bing` 与包乙 `fetters`（数组形，`tianqi_sect.gd` `_bing_flag`／`fetters_given`／`grant_fetter`）。`XTianqiSave.WIRED` 与 `_fill` 同步补全（`no_diff_passive` 仍按 `vkey` 由 `sync_difficulty_after_load` 在能力刷新前处理）。
- seed-fix 三处装备复制路径（`yunshang_orders.gd` `grant_spec`、`warehouse.gd` `deposit` 原版复制、`demon_crown.gd` `_grant`）改调 `XTianqiSave.strip_on_copy`，统一清除 `tq_seed_id` 与 `tq_rng_n` 等 `GEAR_KEYS` 中 `copy=false` 的键。
- 专项 `tests/xiyou_tianqi_save.gd` 扩充 S2 用例（82/82，全走 `tq_save_kit` 真实写盘读档 `roundtrip`）：覆盖 14 个分区删键老档懒建与新旧补法逐键相等、部分缺键读档后自动补全并记版本、关门面开关兜底、只读接口不建区、非天启篇档不建 `flags.tianqi` 根表，以及三处实际复制路径去键。
- 验证：`xiyou_tianqi_save` 82/82 与各分区／复制路径专项共 23 个场景全部通过；`天启篇存档登记.py` 通过；`测试天启篇存档登记.py` 10/10；`语法检查.py`（核心代码改动后）872 个 `.gd` 0 问题。
- 提交：df1b36edf
- 未完成／已知问题：其余 `选测.py` 场景（含 `xiyou_tianqi_e2e`、`xiyou_event_compare*` 等）、`工具回归.py` 与全量 `检查.sh` 留总装合并时跑。

## 交接板

- 下一步：乙档核查 `xa/save-s2` 后由总装按影响面跑完余下选测与 `工具回归.py` 合并；下一步 S3（旧专项改走 `roundtrip`）或 R1（随机门面骨架）由协调派单。
- 用户试玩说明：无（只搬迁存档读写与复制去键入口，数值、公式、默认值未改）。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `xiyou_tianqi_save`：82/82（6 秒，含 S2 新增 31 条：14 分区删键老档逐键相等、部分缺键补全、开关回退、非天启篇档不建区、三处复制路径去键）
- 各分区／复制路径原有专项（22 个场景全通过）：
  - 四线＋峰顶：`xiyou_tianqi_war` 99/99、`xiyou_tianqi_famine` 99/99、`xiyou_tianqi_plague` 100/100、`xiyou_tianqi_death` 95/95、`xiyou_tianqi_summit` 79/79、`xiyou_tianqi_famine_reaper` 13/13
  - 其余分区：`xiyou_tianqi_weak_clear` 46/46、`xiyou_tianqi_rewards` 78/78、`xiyou_tianqi_alien_gear` 57/57、`xiyou_tianqi_elements` 57/57、`xiyou_tianqi_money` 77/77、`xiyou_tianqi_trumpet` 161/161、`xiyou_tianqi_skills` 231/231、`xiyou_tianqi_sect_bing` 28/28、`xiyou_tianqi_sect_b` 76/76、`xiyou_tianqi_sect_a` 41/41、`xiyou_tianqi_sect_ren` 8/8、`xiyou_tianqi_sect_geng` 81/81
  - 复制路径：`xiyou_tianqi_seed_fix` 77/77、`xiyou_warehouse` 32/32、`xiyou_demon_crown` 106/106、`xiyou_yunshang` 1675/1675
- 工具与语法：`天启篇存档登记.py` 通过；`测试天启篇存档登记.py` 10/10；`语法检查.py` 872 个 `.gd` 0 问题（核心代码改动后跑；测试脚本之后已由 `xiyou_tianqi_save` 实际加载运行通过）。

## 未跑完、请总装合并时跑

| 项 | 原因 | 说明 |
| --- | --- | --- |
| `xiyou_tianqi_e2e` | 超出单步 10 秒前台等待转后台（按规定未等，已取消） | 请总装合并选测跑 |
| `选测.py main --list` 其余 31 个场景（共 54 个，已跑 23 个） | 含 `xiyou_event_compare*` 等多场景，按车道规则留总装 | 请总装 `--affected`／云端选测跑 |
| `工具回归.py` | 约 2 分钟以上（超过单步等待上限） | 请总装合并门禁跑 |
| `检查.sh` | 按车道须知不在 worktree 跑全量 | 请总装合并后跑 |

## 待交叉核查

- 乙档抽核（存档门面 S2）：
  - `modes/xiyou/core/tianqi_save.gd`：`WIRED`（17 个分区）、`_fill`（新增 `war/famine/plague/death`、`rewards`、`elements`、`trumpet` 分支）
  - 各模块接线与 `fill`：`tianqi_line.gd`、`tianqi_famine_line.gd`、`tianqi_summit.gd`、`tianqi_weak_clear.gd`、`tianqi_rewards.gd`、`tianqi_elements.gd`、`tianqi_money.gd`、`tianqi_trumpet.gd`、`tianqi_skills.gd`、`tianqi_sect.gd`
  - 三处 `strip_on_copy`：`yunshang_orders.gd`、`warehouse.gd`、`demon_crown.gd`
  - 重点检查：`tianqi_elements.gd` `store()` 保留 `not XTianqi.active(s)` 返回 `{}`（不破 `ensure_deck` 空表判断）；`tianqi_sect.gd` `fetters_given()` 走 `peek` 不建区、`grant_fetter()` 用 `section().assign()` 原地更新数组；`rewards` 在非天启篇档不再建空 `flags.tianqi`（与 S1 P2-1 一致）。

## 本分支提交

- df1b36edf 存档门面 S2：14 个天启篇分区接进 XTianqiSave＋三处复制路径接 strip_on_copy
