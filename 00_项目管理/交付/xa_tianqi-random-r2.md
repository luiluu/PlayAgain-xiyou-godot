# 交付：xa/tianqi-random-r2

- 车道／工作者：C 规则·随机门面 R2／ag（默认 Gemini 4 Hydrogen，方案定为 Sonnet＋medium 级搬家活，协调派单 task_1e2ea52efc99；乙档；方案见 `git show 12cd35586^:00_项目管理/交付/cc_save-rng-facade.md` 第 2.1、2.3、3.1、3.3 节）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【ag·随机门面R2·未经审查】天启篇随机门面 R2：第 2／3／5／7 类旧写法收进 XTianqiRandom，排查元素兜底（dev.待定）

- `modes/xiyou/core/tianqi_random.gd`（`XTianqiRandom`）新增第 2、3、5、7 类旧写法的同名包装（**不加新开关，公式与取数次序不变**）：
  - `drop_hash(drop_seed, key, total)`（第 2 类）：招牌掉落账 `sha256` 前 32 位取浮；`modes/xiyou/core/tianqi_drop.gd` `roll_signature` 改调它。
  - `qiyin_seed(s, domain)`（第 3 类）：七印祭坛、七首之龙与首杀招募按 `qiyin.seed`＋`qiyin.rng_n` 派生（尊重 `XTianqiQiyin.SEED_FROM_SAVE`）；`modes/xiyou/core/tianqi_qiyin.gd` `next_seed` 改调它。
  - `merchant_roll(round_seed, used)`（第 5 类）：深渊商人按 `cur.seed + cur.used * 104729` 构造 `XAbyssMerchant.seed_random` 流；`modes/xiyou/core/tianqi_merchant.gd` `draw` 改调它。
  - `elements_seed(s)` 与 `elements_rng(elem_seed, key := "")`（第 7 类）：元素牌组存档种子（`derived_seed`）及楼层牌组（`_generate_floor_deck`）、固定入口（`fixed_deal`）、骑士三阶段（`_deal_knight`）的 `RandomNumberGenerator` 构造与 `String.hash()` 定种统一改调门面。
- 排查 `modes/xiyou/core/tianqi_elements.gd` 两处兜底（R1 标待 R2 排查），均**走不到**，按要求注明并保留：
  - `element_rate_for`（原 `:633` 现 `:628` 的 `else randi_range(...)`）：经 `rg` 全工程追踪，所有调用经 `XDamage.calculate` 或 `{"preview": true}` 进入；非预览且 `options.random != null` 时只有 `battle_logic._rule()`（及 `yunshang.calculate_split` 透传）和专项中的 `XRandomStream`，且 `XDamage.apply_variance` 参数签名亦限定 `XRandomStream`。
  - `roll_higher_books`（原 `:1062` 现 `:1057` 的 `else randf()`）：全工程唯一生产调用 `grant_higher_books` 与 `tests/xiyou_tianqi_elements.gd` 3 处测试均显式传入有效 `Callable`，无不传或传无效 `Callable` 的调用方。
- `tests/xiyou_tianqi_random.gd` 新增 `_r2_baselines()`：在改动前先于实机测试场景跑出各固定种子序列写入基线，改动后经真存读（`Kit.new_game`、`kit.legacy`、`kit.roundtrip`、`kit.reload_same`）复测，确认第 2／3／5／7 类输出序列与改前逐位一致，并测 `XTianqiQiyin.SEED_FROM_SAVE = false` 回退路径。
- 验证：
  - 前台逐个通过的 Godot 专项（共 16 个）：`xiyou_tianqi_random` 75/75（含返修补 `elements_rng` 空键断言）、`xiyou_tianqi_drop` 85/85、`xiyou_tianqi_elements` 57/57、`xiyou_tianqi_qiyin_altar` 173/173、`xiyou_tianqi_qiyin_dragon_run` 90/90、`xiyou_tianqi_qiyin_drop` 151/151、`xiyou_tianqi_qiyin_endgame` 62/62、`xiyou_tianqi_qiyin_art` 62/62、`xiyou_tianqi_qiyin_equip` 104/104、`xiyou_tianqi_qiyin_dragon` 92/92、`xiyou_tianqi_qiyin_effects` 50/50、`xiyou_tianqi_qiyin_gear` 234/234、`xiyou_tianqi_affix_roll` 30/30、`xiyou_merchant29` 75/75、`xiyou_tianqi_save` 82/82、`xiyou_tianqi_affix_seed` 22/22。
  - 检查脚本：`语法检查.py`（874 个 `.gd`，0 问题）、`随机守卫.py`（60 个天启篇脚本通过）、`测试随机守卫.py`（9/9）、`天启篇存档登记.py`（通过）、`发行空壳.py check`（58 个脚本、479 个函数通过）。
- 未跑完、请总装合并时跑：
  - `选测.py main --list` 列出的其余场景未在本车道全跑：`xiyou_event_compare`、`xiyou_event_compare_b`、`xiyou_event_compare_c`、`xiyou_event_compare_d`、`xiyou_fabao_rework`、`xiyou_tianqi_money`、`xiyou_tianqi_no_diff_passive`、`xiyou_tianqi_trumpet`；以及 `工具回归.py` 整组、`--cloud` 选测。

## 交接板

- 下一步：乙档核查 `xa/tianqi-random-r2`（可按 1/5 抽核）；合并时总装按需要补跑 `选测.py` 剩余场景与 `工具回归.py`。
- 用户试玩说明：无（只搬家包装，公式、取数次序与老档结果序列完全不变）。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 待交叉核查

- 乙档抽核：`modes/xiyou/core/tianqi_random.gd`（新增 `drop_hash`、`qiyin_seed`、`merchant_roll`、`elements_seed`、`elements_rng`）、`tianqi_drop.gd`、`tianqi_qiyin.gd`、`tianqi_merchant.gd`、`tianqi_elements.gd`（4 处改调门面＋`:628`、`:1057` 两处兜底排查注释）、`tests/xiyou_tianqi_random.gd`（`_r2_baselines`）。

## 本分支提交

- 见 `git log main..xa/tianqi-random-r2`
