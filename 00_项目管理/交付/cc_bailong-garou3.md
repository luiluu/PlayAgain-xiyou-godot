# 交付：cc/bailong-garou3

- 车道／工作者：E 角色专属／白龙_7（cc，项目线程「做饿狼第二期」local_f2e515ec）
- 状态：可合并

## 变更记录草稿

## 2026-10-31 【cc·白龙_7·未经审查】饿狼第三期：战斗内进化、解析、反击、追击（dev.待定）

照原版 installNativeGarouRuntime.js 的战斗包装（G.analysis／addAnalysis／clearBattle 第 17～19 行，meetsSkillConditions 第 193 行，
beginAction／targetRow／base 第 203～215 行，makeDamageValue 第 217 行，itemCnt 第 224 行，apply／trigger／finishAction 第 226～259 行，startAction／onTurnEnd／startBattle／endBattle 第 261～276 行，
伤害钩子 garou 第 389～398 行），重制 `XGarou` 第三期：

1. **施放帧**：`XBattleLogic.execute` 开头（startAction 包装）`XGarou.begin` 记施放开始时的进化层；各目标第一次被打时记下当时的解析层；`_invoke` 的普通 apply 之后 `XGarou.applied` 记本帧命中与伤害（追击、反击这些触发行动不记），模式：琦玉 10262 命中自己时开琦玉模式。
2. **伤害钩子 garou**（`XActorDamageHooks.capture` 加 `XGarou.damage_ops`）：饿狼 10250～10263 解析每层无视物防（半怪人 11%～四臂 33%）／魔防（星空 33%）、最多 99%；按公式定物理或混合；进化 ×(1＋层×(形态每层 16～99％＋戴着破限之心另加 3～22％)/100)。参照证实原版进化只乘一次（makeDamageValue 包装与伤害钩子不叠加）。
3. **饿狼拳法收尾**（`act`／强制行动在 endAction 之前调 `XGarou.finish`）：每个命中目标，追击开着（翼化起、学了 10268）且施放开始时解析满 3 层就追加神杀瞬击 10258（沿用施放开始的进化层），再给它加一层解析；有命中就进化 +1（最多 3）；流水岩碎拳命中回 20 TP。
4. **敌人打饿狼**：敌人 HP 伤害行动命中饿狼且扣了血，进化 +1（每回合一次）、给出手的敌人加一层解析；饿狼活着、学了 10265 时 33%（规则流 `garou_counter`）用流水岩碎拳反击，反击命中再加一层解析。回合结束（`turn_end_battler` 末尾）清「本回合受过伤」与琦玉模式；开战（`start_battle`）、结束战斗（`end_battle`）清全部。
5. **其他包装**：itemCnt——饿狼不被原生反击（`_invoke` 的反击率）；meetsSkillConditions（`can_use`）——未到形态的拳法、追击 10258 不能用，认真一拳 10263 要琦玉模式，打完关。
- 不移植：输入阶段预排了模式：琦玉时认真一拳可选（原版看输入阶段已排的行动；重制选指令时没有预排，四臂以上两次行动时第二次选不到认真一拳，只能等模式生效后的下一次输入）；追击／反击借主拳熟练度（重制无熟练度）；applyCritical 0 伤不暴击；技能分类与指令窗；战斗日志的追击／反击显示（记录里带 `followup`／`counter` 标记，画面没接）。
- 参照：新探针 `mv_oracle/garou_battle_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5，反击例 0.1）15 例：模块常量 1、主拳连打 5 次 5（赤发、半怪人、翼化、翼化不戴法宝、星空）、流水回 TP 1、全体拳 1、敌人打饿狼 2（不反击／反击）、itemCnt 1、使用条件 3、结束战斗 1。产物拷成 `tests/fixtures/garou_battle_oracle.json`，**不接全量同步**。
- 专项 `tests/xiyou_garou_battle`（255 项）：每段命中的行动者、技能、追击／反击、目标、暴击逐条比；伤害按行动者分组比对第一段的比值（绝对值另有伤害链固定差，不比；星空混合拳比值差约 3e-6，容差 1e-5，其余形态 1e-6 内）；每次后的进化层、各敌人解析层、TP（敌人打饿狼的例不比 TP）；使用条件、结束战斗清数据。
- 反向验证：进化不乘（66 项失败）；追击关掉、反击关掉、认真一拳不看琦玉一起改（14 项失败：追击 6、反击 6、条件 2），都已还原。

## 机制对照

照冻结 v0.28 installNativeGarouRuntime.js 逐项（第二期交付单的表搬过来、更新到本期）：

| 原版机制 | 重制现状 |
| --- | --- |
| G.config、G.stage／G.form、setup／levelUp／levelDown → G.sync、learnSkill 准入 | 第一期 |
| G.form 包装（被动门槛、没学 10269 回人类倍率与 1 次行动）、paramRate、makeActionTimes | 第二期；本期加 `passives`（反击／进化／解析／追击开关） |
| paramMax 999999999999 | dev.235（悟空） |
| 累计突破、creditVictory、神之触媒、G.reason／G.advance、evolveRelic、changeEquip 同步 | 第二期 |
| G.analysis／addAnalysis／clearBattle | 本期 |
| beginAction／targetRow（施放帧） | 本期 |
| G.base 解析减防、伤害钩子 garou（减防、mode、进化增伤）、makeDamageValue 进化 | 本期（只乘一次，参照证实） |
| apply 包装（记命中、琦玉模式） | 本期 |
| finishAction（追击、解析、进化、流水回 TP；敌人命中的进化、解析、反击；认真一拳关琦玉） | 本期 |
| trigger（追击／反击直接 apply、反击命中加解析） | 本期；熟练度来源不做（无熟练度） |
| itemCnt 包装 | 本期 |
| meetsSkillConditions（未到形态、triggered、认真一拳） | 本期；输入阶段预排不做 |
| onTurnEnd、startBattle／endBattle 清理 | 本期 |
| applyCritical 0 伤 | 未做（伤害为 0 时暴击与否不影响数值） |
| addState／eraseState 包装（G.invalidate 刷缓存） | 不需要（重制 refresh_passive 随状态变化） |
| extractSaveContents（读档清战斗数据并同步） | 未做（战斗数据不进存档；读档同步待定） |
| performAttack 动作、技能名品质色、法宝图标、图鉴立绘、describeRelic、星空外观、技能分类与指令窗、进阶界面提示 | 画面层，未做 |

## 优化登记草稿

优化登记草稿：无（本期没有改原版行为的地方）。

## 待交叉核查

- 原 Codex 核心文件：改了 `modes/xiyou/battle/battle_logic.gd`——`execute` 开头 `XGarou.begin`；`_invoke` 反击率加 `XGarou.no_counter`、普通 apply 之后 `XGarou.applied`；`act` 与强制行动在宿傩收尾之前 `XGarou.finish`；`can_use` 加 `XGarou.meets`；`turn_end_battler` 末尾 `XGarou.turn_end`；`end_battle` 加 `XGarou.clear_battle`。没碰 note_costs 与经验奖励（悟空 gaps2）。
- 共用挂点：`actor_damage_hooks.gd` 的 capture 加 `XGarou.damage_ops`。

## 验证

- 专项 xiyou_garou_battle 255/255（本机）。
- 相关战斗选测（本机，并行 2，负载 30～40，用时 2350 秒）：xiyou_garou_battle、xiyou_garou_progress、xiyou_actor_modules、xiyou_action_sequence、xiyou_alien_battle、xiyou_battle、xiyou_battle_gaps、xiyou_cat、xiyou_custom_damage、xiyou_mira_battle、xiyou_otb、xiyou_race_battle、xiyou_raven_soul、xiyou_rules 与 d1b／d1c／d1d、xiyou_smart_ai 与 _b／_c／_d、xiyou_sukuna_battle（含黑闪）、xiyou_yomi_battle、xiyou_battle_events，24 个全部通过，无偶发。
- 没改切片、转换器、全量同步里的探针、界面，没跑同步与事件对照。已合 main 50798646（带进的只有工具、文档与 garou2 的 .uid），合进来的没有游戏代码，没重跑。

## 交接板

- 下一步：饿狼剩画面层——技能分类 [2,1,5,4] 与指令窗、追击／反击的战斗日志、胜利提示 `XBattleLogic.victory_texts`（神之触媒）、进阶界面的饿狼原因提示、星空外观与图鉴立绘、法宝说明；逻辑层只剩输入阶段预排琦玉与读档同步（要不要做看画面车道怎么接指令输入）。
- 用户试玩说明：饿狼连打同一个敌人会越打越疼（进化最多 3 层），半怪人起打过的敌人会被「解析」、越打越破防，翼化起解析满 3 层的敌人每次还会被追加一记神杀瞬击；敌人打饿狼会让他进化，并有三成机会被流水岩碎拳反击；星空形态先用「模式：琦玉」才能放认真一拳。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：饿狼 405 行完成度 0.55 → 0.8（战斗内被动做完，剩画面层），角色约 +0.6 个百分点（405×0.25÷8817×50≈0.57）。按期数估，不是测量值。

## 可优化（流程／工具／效率）

- 建议（画面车道）：接 `XBattleLogic.victory_texts`（神之触媒提示）、进阶界面的饿狼原因提示（现在前面多「进阶条件未达成：」）、战斗日志里 `followup`／`counter` 标记的追击与反击（原版 displayAction／displayActionResults）。
- 建议（工具，归哪吒）：`godot --check-only --script` 在本工程报 GameApp 找不到（autoload 没载入），没法单独查语法；写错一个类型推断要排一整轮测试槽（这次一次 7 分钟才看到 Parse Error，测试卡到超时才退）。可做个只载工程、不跑场景的语法检查入口，或让并行测试遇到 Parse Error 立即判失败。

## 本分支提交

- 3dd857b1 补 tests/xiyou_garou_progress.gd.uid
- 35b010b0 参照 garou_battle_probe 与夹具
- b15c1613 XGarou 第三期与专项 xiyou_garou_battle
- d79a35f9 交付单草稿、头注释
- 50798646 合并 main
