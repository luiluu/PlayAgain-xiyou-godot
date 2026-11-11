# 交付：cc/pro-tianqi-p3-1

- 车道／工作者：C 规则·机制／cc（pro-tianqi-p3-1，云端）
- 状态：进行中

## 变更记录草稿

## 2026-11-11 【cc·pro-tianqi-p3-1·未经审查】天启篇敌人倍率的基准难度跟本档开局走（审查 79 P3-1，dev.待定）

- 审查 79 P3-1：`XTianqiCombat.enemy_rates` 在天启篇里一律取 `XEnemy.difficulty_rates(XTianqi.NUMERIC_LEGACY)`（写死普通），不看 `XTianqi.UNIFIED_LEGACY`。只关 `UNIFIED_LEGACY` 时开局按各档原版难度走，敌人却仍按普通乘，两个开关不能各自回退。
- 改法：新加 `XTianqiCombat.base_legacy(s)`，取本档开局借的原版难度 `XTianqi.legacy_of(key)`（与开局 `opening_commands` 同一取值）；`enemy_rates` 的基准改读它。`s` 不传时取 `XState.current`。
- 默认行为不变：`UNIFIED_LEGACY` 默认 true，`legacy_of` 五档都返回 `NUMERIC_LEGACY`（3，普通），敌人数值与改前逐项相同。只有关掉 `UNIFIED_LEGACY` 时，寻常／艰险／九死／炼狱／证道的敌人基准分别跟到原版简单／普通／困难／地狱／天灾，再乘数值表的敌人血量、攻击。
- 回退：沿用 O-278（`XTianqiCombat.ENABLED`、`XTianqi.UNIFIED_LEGACY`），不新增开关、不新增优化号。没动 `XTianqi.RELEASE_OPEN`（O-307）。
- 专项 `xiyou_tianqi_numbers` 加两组断言（每档一条，五档共 10 条）：`enemy_base_unified_<档>`（开关开着时基准都是普通）、`enemy_rates_split_<档>`（只关 `UNIFIED_LEGACY` 时基准等于该档 `legacy`，再乘本档敌人血量、攻击；调用时故意传 5，确认天启篇不看传进来的难度）。
- 玩家可见：无（默认开关下数值不变）。

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：云端没有 Godot 时它直接报找不到 godot，改用下面的单跑代替。
- 云端单跑 `xiyou_tianqi_numbers`（Godot 4.7.2，转换产物取自 `refs/ci/generated/main`）：结果见下方「验证结果」。
- 没跑全量 `检查.sh`（车道规则：车道只跑专项）；`选测.py main --list` 依赖本机产物与 Godot，云端未跑。按影响面建议总装合并后选测 `xiyou_tianqi_numbers`、`xiyou_tianqi_opening`、`xiyou_determinism`（`enemy.gd` 每只敌人 setup 都经过 `enemy_rates`）。

### 验证结果

（待写）

## 风险

- 低。默认开关下只是把常量 3 换成 `legacy_of(key)`，而它在 `UNIFIED_LEGACY` 开着时恒为 3；对原版档（非天启篇存档）走的仍是旧分支 `XEnemy.difficulty_rates(difficulty)`，未改。
- 关掉 `UNIFIED_LEGACY` 后天启篇各档敌人会叠上原版难度自带的大倍率（血量 ×75～×750 等），这正是 O-278 那个开关要回到的「各借各的」做法，数值会比数值表设计高得多，只适合回退对照，不适合拿来平衡。
- 存档里难度键读不到（异常存档）时 `row(s)` 已为空，走原版分支，不会进 `base_legacy`。

## 交接板

- 下一步：划掉审查 79 P3-1。
- 用户试玩说明：无变化。
- 需要用户决定：无

## 进度账

- 无变化（开关一致性修正）。

## 可优化（流程／工具／效率）

- 建议：`语法检查.py` 在没有 Godot 时直接抛 FileNotFoundError 栈，可以改成提示「先跑 云端准备.sh 或设 GODOT」再退出（几行，工具车道）。

## 待交叉核查

- `modes/xiyou/core/tianqi_combat.gd`（战斗核心，甲档）：`enemy_rates`、新加 `base_legacy`。
- `tests/xiyou_tianqi_numbers.gd`：新加断言。

## 本分支提交

- 见 git log（从 main ea727c9 切出）
