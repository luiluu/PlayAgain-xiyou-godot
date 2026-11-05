# 交付：cc/nezha-accept2

- 车道／工作者：难度验收／哪吒（cc，Sonnet）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】楼层验收第二期：难度验收盘点与难度 1～9 敌人对照（dev.待定）

- 盘点各难度对楼层的影响点（见下「盘点表」），难度 7 灭世、8 洪荒、9 混沌此前没有敌人能力值的原版对照（slice 敌群只到难度 6）。
- 新探针 `mv_oracle/difficulty_enemy_probe.cjs`（已登记 `同步正式西游.py` PROBES，产物 `difficulty_enemy.json`）：难度 1～9 × 24 个抽样敌人（常用 1／3／6／16／193／214＋全库等距＋boss 备注）× 非神话／神话，量原版 Game_Enemy 的最终 param／xparam／sparam、等级、exp()／gold()、dropItemRate、掉出件数分段概率（队伍 [1,8,9,10]，同 battle_drop_probe 的出战成员重建）。
- 新专项 `tests/xiyou_difficulty_enemy`：逐例比，3888 项全过；**没有查出真差异**，无需改游戏代码。
- 探针第一版漏了重建出战成员（掉率因子 1.33 对 4.49），专项当场报出 792 项失败，改探针后全过——说明该专项咬得住掉率的队伍因子。

## 盘点表（给进度核定用）

| 影响点 | 原版机制 | 已有对照证据 | 本期补的 | 仍缺 |
|---|---|---|---|---|
| 敌人能力倍率 | Vitsuno `n : Param Rate`（难度 1～9 各一行，9 档含混沌 HP×1e12） | `xiyou_rules*` 逐难度 1～6 × 切片敌群 param／xparam／sparam／属性抗性；`xiyou_enemy_warehouse`（难度 3～6 × 旗标 DCL）；`xiyou_difficulty_*`（难度来源、继承） | 难度 1～9 × 24 敌 × 神话/非神话（含 7、8、9） | 难度 7～9 的整敌群（敌群事件替换后的）未比；boss 难度被动（installBossDifficultyRuntime）只在 rules 的 boss 行里间接覆盖 |
| 敌人等级 | 出战最高等级＋浮动 | `xiyou_rules`（等级=3 固定种子） | 难度 1～9 同点 | 非 1 级队伍的等级随难度无关，没单独比 |
| 掉落表／掉率 | 难度表 `Drop Rate` 在原版被注释，**掉率与难度无关**；神话 ×5；队伍因子 | `xiyou_battle_drop`（难度 2／5） | 难度 1～9 × 24 敌 dropItemRate＋分段概率，证明与难度无关 | 刷怪掉落的实际抽样分布没比（按概率比，不比单次） |
| 经验金钱倍率 | 原版倍率被后装 EliteEnemy 盖掉**不生效**；重制 O-130 让它生效（可回退 `o_difficulty_reward`） | `xiyou_battle`、`xiyou_battle_gaps`、`xiyou_zhenqi_break`（回退支比原版） | 难度 1～9 原版 exp()／gold()（O-130 前）与难度无关，与数据库一致 | O-130 开启支只有公式自测，无原版可比（有意优化） |
| 难度被动／开局状态 | 5547～5564、1629～1631 等 | `xiyou_rules*`（角色侧 1～6）、`xiyou_difficulty_inherit/source` | — | 难度 7～9 的角色侧被动（slice 只到 6） |
| 洪荒诅咒／奖励 | 公共事件 1442、1439、1445 | `xiyou_honghuang_curse`、`_curse_battle`、`_reward` | — | 无新缺 |
| 副本难度 | `Difficulty SetID`、挑战档 | `xiyou_dungeon`、O-038 | — | 无新缺 |
| 事件按难度分支 | 6 页读难度 | 悟空 accept1 | — | — |

## 交接板

- 下一步：难度 7～9 的角色侧（被动、开局状态）与整敌群对照可再补一期；若要，则扩 slice_probe 到 9 档（约 +50% 同步时间）。
- 用户试玩说明：无（只增测试与探针）。
- 需要用户决定：无。

## 进度账

- 楼层、副本与剧情内容：难度验收这半项新增证据（敌人能力、等级、经验金钱、掉率 × 难度 1～9）。建议该行 +0.5～1 点（当前 93.3%，该行 2.5 分里的「事件、难度验收」难度半个，约 1.0～1.3 分）；依据：敌人侧 9 档全覆盖且全部与原版一致，缺的是难度 7～9 的角色侧与整敌群。

## 验证

- 专项：`xiyou_difficulty_enemy`（3888 项全过）；选测 `选测.py main --list` 20 个场景（含 `xiyou_rules` 抽样段），全部通过（exit 0，约 14 分钟，本机 2 并行）。
- `语法检查.py` 通过；`工具回归.py` 全过（44 秒）。
- 没跑 `同步正式西游.py --accept-additions`（只增一个探针，产物已在本工作树手工量出；总装合并时同步会自己量）。

## 待交叉核查

- `difficulty_enemy_probe.cjs` 抽样敌人是否有代表性；`xiyou_difficulty_enemy` 的 `setup_level(1, 0.99)` 与 `XEnemy.setup(…, roll)` 口径同 `xiyou_rules`。
- 未改任何游戏代码（battle_logic／actor 等核心文件未动）。

## 可优化（流程／工具／效率）

- 建议：该探针约 4 分钟，主要耗时在掉率二分（432 例×最多 14 件×36 步）；可只对每敌人的难度 1／9 做分段概率，其余难度只比 dropItemRate（预计探针降到约 1.5 分钟，归 A 车道/工具）。

## 本分支提交

- 见 `git log main..cc/nezha-accept2`
