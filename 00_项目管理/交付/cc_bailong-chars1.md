# 交付：cc/bailong-chars1

- 车道／工作者：E 角色专属／白龙（cc，第十五批 FF）
- 状态：可合并

## 盘点（新源 v0.62.12 角色专属类运行时，重制还缺的）

| 运行时 | 内容 | 处理 |
| --- | --- | --- |
| installZhenhuoMark（v0.53.01～.03） | 至尊宝 36 真火印记追击 | **本期做**（XZhenhuo） |
| installStarburstBooks（v0.62.10） | 星爆气流斩三本被动书分开获得 | **本期做**（XStarburstBooks） |
| installDualExclusive（v0.62.10） | 双持时专武只能装一把（白晶晶 76 例外） | 第二期（要动 equipment.gd 与换装列表，总装 11-07 定第一期合完再派） |
| installVegettoForm | 贝吉特 2771～2774 形态战斗图兜底（MV 空图名） | 待核：哪吒 newsrc6 已做超赛多形态回落，重制没有空图名问题，第二期顺手核 |
| ExclusiveGrowth／LxyUnlock／ThreeBalanceV039 | 专武成长、李逍遥专武解禁、贝吉特旧武器 | 不做：模板已在 Weapons.json，运行时只剩 MV 旧档迁移 |
| UniqueEffectMark | 装备说明「◆唯一」 | 界面车道 |
| 拳一系数（v0.30／0.36／0.39～0.41）、祈求者等 4 档进阶（v0.52） | | 数据驱动：导入倍率 rules-newsrc 已追平，进阶表读插件参数 |

## 待交叉核查（审查甲档：battle_logic／battler／resource_context 钩子行）

总装 11-07 10:05 同意本车道在 battle_logic 加一行钩子，逐行列出：

- `battle/battle_logic.gd` `execute` 开头（XRaven.begin 之后）：`XZhenhuo.start_action()`——新的 Game_Action，追击格子清空。
- `battle/battle_logic.gd` `apply`（谷雨包装之前）：`var zhenhuo = XZhenhuo.apply_begin(self, u, skill, t)`——记行动前有没有印记；1083／1086 由来源施放时先挂 108（回合至少 2）。
- `battle/battle_logic.gd` `apply`（心钢 after_apply 之后）：`XZhenhuo.apply_end(self, u, skill, t, zhenhuo, r)`——火伤打中行动前已带印记的活敌人，来源排强制行动 1090（每目标每行动一次）。
- `battle/battle_logic.gd` `_apply`（`_damage_value` 之后）：`value = XZhenhuo.scale(u, skill, value)`——来源放 1090 时 ×(0.6＋1%×等级)，round、至少 1。
- `battle/battle_logic.gd` `grant`（XZhenqi.on_victory 之前）：`XStarburstBooks.on_victory(self)`。
- `core/battler.gd` `add_state`、`core/resource_context.gd` `add_state`：`XZhenhuo.blocks_state` 挡角色的 109（两条加状态路径都挡，开关见优化登记）。
- `map/map_scene.gd` 三处 `XItemMarks.deploy_start` 之后：`XStarburstBooks.map_start(XState.current)`（Scene_Map.start 补发）。

## 优化登记草稿

优化登记草稿：无
已直接写进优化登记 O-待定·真火旧追击，见 `03_再刷重制_Godot/00_设计/优化登记.md`：O-待定·真火旧追击（原版 bug，默认修好，Kyo 11-07 同意保留；`XZhenhuo.FIX_OLD_CHASE = false` 回原版）。

## 变更记录草稿

## 2026-11-07 【cc·白龙·未经审查】至尊宝真火印记追击、星爆三本被动书分开获得（跟到 v0.62.12）（dev.待定）

- **真火印记**（新 `core/zhenhuo.gd`，跟 `installZhenhuoMarkRuntime` v0.53.03）：学了 1089 的至尊宝放 1083／1086 先给目标挂印记 108；任何角色的火伤打中行动前已带印记的活敌人，印记来源追加横扫千军 1090（物理），伤害 ×(0.6＋1%×等级)。原版想屏蔽的旧追击状态 109 实际没挡住（装载次序），重制默认挡下（O-待定·真火旧追击）。
- **星爆三本被动书**（新 `core/starburst_books.gd`，跟 `installStarburstBooksRuntime` v0.62.10）：8／18 层守层者胜利各送一本封弊者／流光闪（每档一次，试炼、缩放战不送），152 不朽存在每场 1/66～1/33 掉阐释者，回地图时按已通过层数补发。
- 参照：`mv_oracle/zhenhuo_probe.cjs`（12 例）、`starburst_books_probe.cjs`（22 例），夹具在 `tests/fixtures/`，专项 `xiyou_zhenhuo`、`xiyou_starburst_books`。
- 玩家可见：至尊宝带真火印记时火伤会触发横扫千军追击；星爆气流斩的三本被动书改从神魔之塔 8、18 层守层者和不朽存在拿。

## 交接板

- 下一步：白龙第二期（双持专武只能一把、贝吉特形态图核对）。
- 用户试玩说明：同上「玩家可见」。
- 需要用户决定：无（O-待定·真火旧追击 Kyo 11-07 15:01 回「可以」，定为保留）。

## 进度账

- 角色：待总装按本期两项核定。

## 验证

- 已合 main 2443a7b0（无冲突），`新建工作树.sh --补齐`；`语法检查.py` 639 个 .gd 0 问题；`工具回归.py` 全过（第一次挂探针登记检查：zhenhuo_probe 没关五乘区，已加 `CodexZones.ENABLED=false`，之后 1090 逐段绝对伤害与原版一致）。
- 专项：`xiyou_zhenhuo` 97/97（开关开／关两头比）、`xiyou_starburst_books` 86/86。
- 云端选测（`云端选测.py run`，基准 2443a7b063，325 个场景含 xiyou_determinism、xiyou_rules 全段、事件对照）：第一轮 433fa402 挂 69 个，根因是星爆模块把真气 `battle.scaled`（字典）喂给 `bool()`，胜利结算报错；修后 cf96679a 全过（run 42393426820）。
- 原版探针：`zhenhuo_probe.cjs` 12 例、`starburst_books_probe.cjs` 22 例，夹具在 `tests/fixtures/`（不进同步 PROBES，同流萤做法）。探针跑法 `NODE_PATH=<主工作区>/03_再刷重制_Godot/03_转换工具/mv_oracle/node_modules node <探针>`。
- 不比的：真火追击例的命中段数与 108 回合数（原版强制行动排进事件，探针不跑事件，本次行动停在第一段）。

## 可优化（流程／工具／效率）

- 建议：探针里要跑 Scene_Map.start 等场景方法时，用一个「点到底」的空桩（属性和调用都返回自己，见 starburst_books_probe.cjs 的 deep）比逐个补方法省事；可收进 `mv_oracle/shared/host.cjs` 给别的探针用（哪吒，收益小）。

## 本分支提交

- 4f41818b、583a863b、1abec5b5、6daf8162、6727e832（WIP：模块、探针、测试、交付单、Kyo 定 O 号保留）
- 合并 main 2443a7b0
- 真火：旧自动施法每行动只排一次、倍率按 noScale 比；探针关五乘区、逐段绝对值也比
- cf96679a 星爆：scaled 是字典（云端 69 个挂在这里）
