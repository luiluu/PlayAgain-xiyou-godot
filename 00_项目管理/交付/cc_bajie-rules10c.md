# 交付：cc/bajie-rules10b（接续 cc/bajie-rules10）

- 车道／工作者：C 规则／八戒（cc，总装定的 rules10 两条小接续）
- 状态：可合并
- 分支从 cc/bajie-rules10（666273f5）续，包含 rules10 全部提交；先合 rules10 或直接合本分支都行。

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】隐月叠层封顶 10 层；剑饮空月 10119 的隐月按说明每层 +2%（dev.待定）

依据：总装按 Kyo 11-05 授权（「待拍板按你分析的优化方向做」）定的两条。

- **隐月叠层封顶 10 层**（并入 rules10 隐月叠层那条 O 号，`XBattler.FLOOR_YINYUE_MAX`）
  - rules10：按说明不限层，1327 叠 20 层暴击率 2.19，带 1749 时溢出的暴击率全变成暴击伤害。
  - 现在：按说明能叠，但封顶 10 层，第 11 层起不再加。1327 叠 10／11／20 层都是 1.19（基础 0.19）；带 1749 时暴击伤害最多 +119%。
  - 回退：`XBattler.FLOOR_YINYUE_MAX = 0` 回到不限层；`XBattler.FLOOR_YINYUE = false` 回到原版 1 层。
- **剑饮空月 10119 的隐月 2521 按说明 +2%**（O-待定，`XBattler.FIX_YINYUE_2521`）
  - 原版：10119 说明写「每层隐月 +2% 暴击几率」，但它挂的隐月 2521 数据是 +0.2%（同名的 7489 挂 1323 是 +2%）。
  - 现在：2521 每层读成 +2%。只在战斗者读状态特性时换一份复制的记录（`XBattler.state_rec`），数据库原值不动。
  - 改前改后（Godot，角色 1 基础暴击 0.19，叠 1／5／10 层）：原版 0.192／0.200／0.210 → 现在 0.21／0.29／0.39。
  - 说明：总装让在转换器 `EFFECT_FIXES` 里做，但那张表只管状态脚本块（Custom … Effect），2521 是特性数值不是脚本，接不进去；改在运行时读状态记录这一层，开关一样可回退。
- `xiyou_rules10` 扩到 90 项：层数用例加 10、11 层，封顶回退支（上限 0 叠满 20 层），2521 开／关两支，数据库原值不变。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| （rules10 隐月那条） | 同上，`core/battler.gd` `add_state_floor` | 同上 | rules10 那行「优化」列改成：按说明能叠，封顶 10 层（`FLOOR_YINYUE_MAX`），每层同单层效果 | 不限层 20 层暴击 +219%，叠 1749 太强 | `XBattler.FLOOR_YINYUE_MAX = 0`（不限层）／`XBattler.FLOOR_YINYUE = false`（原版） | cc（八戒） | 待用户决定 |
| O-待定 | 隐月 2521（`core/battler.gd` `state_rec`） | 剑饮空月 10119 说明每层 +2%，2521 数据 +0.2% | 读成每层 +2%（复制记录，数据库不改） | 说明与代码不符按说明走 | `XBattler.FIX_YINYUE_2521 = false` | cc（八戒） | 待用户决定 |

## 交接板

- 下一步：无新增（隐月层数显示仍建议归 B 界面车道，见 rules10 交付单）。
- 用户试玩说明：隐月最多叠 10 层；带 10119 剑饮空月的角色隐月每层 +2%。
- 需要用户决定：并入 rules10 的三个 O-待定一起定，外加 2521 这一条。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过；`工具回归.py` 全过。
- `xiyou_rules10` 90/90。
- 选测（本机）9 个全过：xiyou_pushstate、xiyou_state_effects、xiyou_determinism、xiyou_trait_stack、xiyou_param_cache、xiyou_status_power_panel、xiyou_actor_p0、xiyou_help_card、xiyou_power。范围同 rules10，其余请合并时 `--affected`；没开云端。没改转换器、切片、探针。

## 待交叉核查

- `battler.gd`：`FLOOR_YINYUE_MAX`、`FIX_YINYUE_2521`、`state_rec`（`states()`／`floor_states()` 改走它）、`add_state_floor` 封顶。

## 本分支提交

- 65117f13 WIP: 封顶与 2521
- （本提交）交付单
