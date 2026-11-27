# 交付：luiluu/t553

- 车道／工作者：T553 天启篇我方 1 号普攻改物攻×1（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【cc·T553·未经审查】天启篇我方 1 号普攻＝物攻×1×等级缩放，敌人照旧（dev.待定）

- 依据：Kyo 11-26 事项82「甲：照稿改成物攻×1」；T552 普攻口径调查（设计仓 `协作交接/核查报告/T552_普攻口径调查.md`）。
- 做法：`XTianqiSkills.attack1_applies(item, a)`＝`ATTACK1` 开、技能号 1、出手者是角色（`XActor`）、天启篇角色卡开（`cards_on()`）、改写表里没有 `"1"`；满足时 `XFormulaExecution._run_item` 直接走 `XTianqiSkills.attack1_formula`（`XDamage.eval_formula` 的 pure 快路径对这种情况让给 `run_item`，AI 估伤、预估同口径），用内置规格 `{"coef": 1.0, "stats": {"atk": 1}}` 过同一条 `_formula`（等级缩放 1 级 0.5～99 级 1.0、角色条件、单段上限、弱者专属词条一并吃）。
- 不写进 `skill_rework.json`：1 号敌我共用，按号改写记录会连敌人、心魔影·原招（`xinmo_traits.gd` 复制 1 号记录）一起改；本单只在公式入口按出手者分流，1 号记录本身一字不动，敌人、心魔、疫囊扩散照旧读原版 `a.atk * 4`。也避开了 T549 正在改的 `skill_rework.json`。
- 回退：`XTianqiSkills.ATTACK1 = false`，我方普攻回原版物攻×4。
- 专项 `xiyou_tianqi_attack1`（新）12/12：我方 99 级＝物攻×1（正式结算与预估快路径都是）、1 级×0.5、50 级线性；敌人预估＝物攻×4；敌人开关两态一致且＝物攻×4；回退两态；西游档开关两态一致且＝物攻×4；怒战 ≥ 1 号、堕天一击＝2 倍；1 号记录未改。
- 玩家可见：天启篇里我方角色的普通攻击伤害明显降低（满级约为原来的 1/4，1 级约 1/8）；「普攻变 X」类被动不再比裸普攻弱。

## 交接板

- 下一步：按 T501 口径复量 31～36 层胜率（本单没量，见下「没做」），建议交 T450／数值车道；量完再看普攻型角色（甚尔 171、攻击次数＋1 类）是否需要补偿。
- 用户试玩说明：天启篇我方普攻伤害降到物攻×1（随等级从一半涨到满），敌人普攻不变。
- 需要用户决定：
  - 怒战（10718）在 D200 取整后卡面是「物理攻击×1」，跟新的 1 号一样大（不倒挂了，但也没有「变强 20%」）；原卡是 ×1.2。要不要把怒战回到 1.2（改 Kyo 定过的 D200 取整结果，本单没动）。
  - 堕天一击（3521）卡面 ×2.0，但学了 751 有「×0.5」条件，此时等于 1 号；悬崖／勒马（3222／4928）是 4 段×（魔攻＋敏捷）×15%、劫运神镖（6161）是 3 段×（幸运＋物攻）×25%，换算成物攻倍数要看角色属性，不一定都「比 1.0 高」。本单只保证不再被 1 号×4 压成倒挂，具体强多少照现有卡面，没改卡。

## 进度账

- 无（天启篇数值线内改动，不动完成度）

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiSkills._formula`（加可选参数 `sp_override`，默认空＝照旧按技能号取规格） | 2 处（`git grep -nE 'XTianqiSkills\._formula\|[^[:alnum:]_.]_formula\(' -- 'modes/xiyou/core/tianqi_skills.gd'`） | `formula` 照旧不传新参，行为不变；`attack1_formula` 传 1 号规格。别处同名 `_formula` 是各自文件的私有函数，无关 |
| `XFormulaExecution._run_item`（开头加 1 号我方分支） | `run_item` 产品调用 3 处（`git grep -nE 'XFormulaExecution\.run_item\(' -- '*.gd'`：battle_logic.gd 正式结算、smart_ai.gd 估伤、damage.gd 预估） | 三处都经 `_run_item`，正式结算、AI 估伤、预估口径一致；分支只在天启篇＋角色＋1 号时进，敌人和西游档不进（专项两态断言） |
| `XDamage.eval_formula`（pure 快路径加条件：天启篇我方 1 号让给 run_item） | 产品调用 3 处（`git grep -nE 'XDamage\.eval_formula\(' -- '*.gd'`） | battle_eval.gd:192 统一预览、smart_ai.gd:651 AI 估伤：我方 1 号改按 ×1，与正式结算一致；power.gd:823 只估回复技，1 号不进。只有 `attack1_applies` 为真时多走一次 `run_item`，其余原样；云端首轮 `xiyou_tianqi_smart_ai_eval` 挂的就是这里（AI 估 1 号仍按 ×4，preview 1204／real 429），补后本机 70/70 |
| `XTianqiSkills.ATTACK1`（新开关，默认 true） | 专项 `xiyou_tianqi_attack1` 两态都测 | 回退＝false |

## 没做／偏离

- 验收 5「按 T501 口径复量 31～36 层胜率」没做：长跑测量，本单不占时间，交 T450／数值车道（派单允许「或交 T450」）。
- 1 号记录说明（description 为空）没有写数，玩家看不到「物攻×1」字样，无玩家可见文字改动。

## 云端选测

- 第一轮 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45910137901 （3c01b0320）：93 场景，挂 1 个 `xiyou_tianqi_smart_ai_eval`（AI 估 1 号仍按 ×4，见上表），已修。
- 第二轮 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45912815071 （666b66fc6）：194 场景、11 片，全部通过（`gh run watch`／轮询前台等完）。

## 本分支提交

- 666b66fc6 T553 补：XDamage.eval_formula pure 快路径让天启篇我方 1 号走 run_item；专项 12/12
- 3c01b0320 T553：天启篇我方 1 号普攻＝物攻×1×等级缩放（XTianqiSkills.ATTACK1），敌人照旧；专项 xiyou_tianqi_attack1 10/10
