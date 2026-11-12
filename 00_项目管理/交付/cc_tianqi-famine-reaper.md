# 交付：cc/tianqi-famine-reaper

- 车道／工作者：天启篇·饥荒线荒年与余粮、终焉掠夺者扣精魄、终焉收尸人吸收技能／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.505）切出，不依赖待合的分支。和 cc/tianqi-artifact-aura、cc/tianqi-alien-tiers 不碰同一处（本单在 `tianqi_alien_gear.gd` 的 `grant` 开头加一行，`battle_logic.gd` 改 `drop_chances` 一行、`decide` 加三行）。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇饥荒线「荒年」与余粮、终焉掠夺者扣精魄、终焉收尸人吸收技能（dev.待定）

- 按设计仓库《天启篇序章_四线异化与异化装备重构 v0.8》第 3.1、3.3 节；「精魄」照《四骑士原身整理 v0.3》就是金钱。只在天启篇存档、有这些异化怪的战斗里起作用。
- 饥荒线（`core/tianqi_famine_alien.gd`，数在 `famine_line.json` 的 `alien.lean_year`、`plunder.finale_gold*`）：
  - 荒年（线规则）：有饥荒异化的战斗，胜利掉落几率 ×0.67（`BattleLogic.drop_chances` 一处）；每只倒下的饥荒异化怪按级 20／30／50／80% 几率掉 1 份「余粮」，记在 `flags.tianqi.famine.grain`（不是物品），胜利时提示（`XTianqiAlienGear.grant` 开头调 `grant_grain`）。
  - 余粮的用处（设计稿没写，cc 草案）：饥荒战里零消耗技能交口粮时先扣一份余粮、不扣 MP 和生命；25 层模拟考答对一题给一份（`tianqi_famine_line.gd`）。
  - 终焉掠夺者：命中我方时另扣当前金钱 1%，本场合计不超过开战时金钱的 10%；打倒它全额还回来，没打倒就没了。
- 死亡线（`core/tianqi_death_alien.gd`，`death_line.json` 的 `reaper.absorb_use`）：终焉收尸人每收走一名死者，从死者已学会的伤害类主动技能里吸收一个；之后它每次行动 50% 几率改用吸收来的技能（`BattleLogic.decide` 三行，在七印寂静之后）。
- 新专项 `tests/xiyou_tianqi_famine_reaper`（13 项）。
- 玩家可见：开发版天启篇饥荒线掉落少了、会掉余粮（口粮先扣余粮）；终焉掠夺者会摸走金钱、打倒还回来；终焉收尸人会用死去队友的技能。发行版看不到。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_famine_alien.gd`（荒年、余粮、精魄）、`core/tianqi_death_alien.gd`（吸收技能）；挂钩 `battle_logic.gd`（`drop_chances` 一处、`decide` 三行）、`tianqi_alien_gear.gd`（一行）、`tianqi_famine_line.gd`（模拟考） | 原版没有天启篇异化 | 饥荒线荒年与余粮、终焉掠夺者扣金钱、终焉收尸人吸收技能 | 四线异化 v0.8 第 3.1、3.3 节 | 各线开关（`XTianqiFamineLine.ENABLED`、`XTianqiDeathLine.ENABLED`）；单关：`lean_year.drop_mult` 改 1、`grain_chance` 改 0、`finale_gold` 改 0、`absorb_use` 改 0 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：余粮的正式用处（现在是草案：抵口粮、模拟考给）；要不要做成能看到的物品或计量（现在只在胜利提示和口粮日志里出现）。
- 用户试玩说明：开发版天启篇选饥荒线，打带异化的战斗看掉落和「得到了余粮」；31～36 层终焉掠夺者打中会摸走金钱，打倒它钱回来；选死亡线到 31 层以上，让队友被终焉收尸人收走后看它放队友的技能。
- 需要用户决定：余粮用处（先按草案）。

## 进度账

- 天启篇四线异化（扩展账）：荒年与余粮、掠夺者精魄、收尸人吸收技能 0 → 已接。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_famine_reaper`：13/13。
- 相关专项（Mac，本工作树，`并行测试.py`，12 个场景，255 秒，全部通过）：`xiyou_tianqi_famine_reaper`、`xiyou_tianqi_famine`、`xiyou_tianqi_death`、`xiyou_tianqi_alien_finale`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_seg_alien`、`xiyou_battle_drop`、`xiyou_drop_record`、`xiyou_determinism`、`xiyou_battle`、`xiyou_rules`、`xiyou_tianqi_horsemen_battle`。
- 没跑的：`battle_logic.gd` 判整轮；本单那几行只在有饥荒异化／终焉收尸人的战斗起作用，原版掉落对照（`xiyou_battle_drop`、`xiyou_drop_record`）已过，其余请总装合并时按选测跑。
- 反向验证（`反向验证.py`，单跑本专项）：不扣金钱、不封顶、不还钱、不减掉落、不掉余粮、口粮不扣余粮、考试不给、不吸技能、从不用，9 处全部咬住。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇饥荒线荒年与余粮、终焉掠夺者、终焉收尸人；专项
- 交付单
