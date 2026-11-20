# 交付：luiluu/cc-t282-smart-ai-eval

- 车道／工作者：T282 智能AI②统一预览引擎＋敌我共用估值底座／cc 车道（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T282·未经审查】天启篇智能战斗AI统一预览估伤＋敌我共用估值底座 XBattleEval（dev.待定）

- 依据：私密仓《天启篇_智能战斗AI评估_Neon_v0.1》第四节、第六节实现卡草稿 2（Kyo D236「乙」：卡1 止血＋卡2 统一预览引擎与敌我共用估值底座，T277 敌人六维 AI 排在卡 2 之后复用底座）。
- 开关 `XSmartAI.o_tianqi_preview_damage`（默认开，O-待定·天启篇智能AI统一预览估伤）：只在 `o_tianqi_smart_ai` 开着的天启篇存档里生效，西游档永不进；关掉退回卡 1（T281）的手抄乘区。
  1. 估伤统一收口：伤害、吸取、回复（类型 1～6）不再手抄「属性有效度 × pdr/mdr × 熟练度 × 全局增伤 × 档案倍率 × 去 ×6」，改走正式结算同一条链 `XDamage.calculate(preview)` → `XDamage.finish(不执行)`（新入口 `XDamage.preview_hit／preview_detail`）：元素牌组弱点／耐性／免疫／高阶、伤害加成总账五池与九线封顶、统一防御率、天启档位与注视、烙印破防 ×1.3、弱者词条、七印器印、防御减半一次对齐，以后数值再改 AI 自动跟。公式本身的值仍由各角色的受控估算给（随机固定 0.5、五条悟茈读当前对数，不写状态）。
  2. 暴击期望改按真实暴击倍率：每段 ×(1−p＋p×暴击倍率)，暴击倍率取 calculate 的 `criticalIf`（1.5＋暴伤加成＋这一击的爆伤池），不再用 ×(1＋暴击率×0.5)。
  3. 零副作用：预览期伤害加成总账守卫静音（选招试算不进 violations、不 push_error）；不传战斗随机流（混沌元素取第一档）、不抽全局 randf；`XTianqiSkills.formula`／`item_cri` 算完复原「正在算的技能号」`_cur_skill`（T281 核查 P3-2）。
  4. 新建 `battle/battle_eval.gd`（XBattleEval）：敌我共用的只读估值内核——范围判断、状态好坏、首领、护盾、威胁度、伤害效用、急需度、增减益、代价倍率、统一预览估伤、元素判定、通用一招打分 `score_skill`（给 T277 敌方 AI）。XSmartAI 瘦成我方策略壳：角色档案、背包、异化投影、魔炮、铺垫、长战判定留在壳里，零件转发给 XBattleEval（外部调用名不变）。
  5. T281 核查带来的：命运之手 6861 这类入口技计入本回合最大伤害 damageScale 与长战判定 best_attack（P2-3）；`shield_estimate` 先认天启篇重构护盾技 tq_shield（P3-1）；热循环正则预编译（状态好坏、安全算式、熟练度备注、冷却备注、首领表）、变量表一次选招只拼一次（P3-3）。
- 玩家可见：无文字改动；天启篇自动战斗会挑打弱点的招、避开对方免疫的属性，估伤和实际出手对得上。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/smart_ai.gd` `XSmartAI.o_tianqi_preview_damage`；`battle/battle_eval.gd`；`core/damage.gd` `XDamage.preview_hit` | 智能战斗 AI 估伤用手抄的几项乘区（属性有效度、物防魔防率、熟练度、全局增伤），看不到天启篇元素牌组、伤害总账、防御率、档位、烙印破防、词条、七印；暴击按 ×(1＋暴击率×0.5) | 天启篇存档里估伤走正式结算同一条乘区链的只读预览（不浮动、不执行、不记账），暴击按真实倍率求期望；估值零件抽成敌我共用的 XBattleEval | 估伤和实战对不上，弱点、免疫、破防进不了选招；敌方 AI（T277）要复用同一底座（Neon 评估卡 2，Kyo D236 乙） | `XSmartAI.o_tianqi_preview_damage = false`（退回卡 1）；`o_tianqi_smart_ai = false`（退回原样） | cc（T282） | 保留 |

## 改了哪些核心文件（请核查方重点看）

- `modes/xiyou/core/damage.gd`（只加，不改结算路径）：
  - 新函数 `preview_hit`、`preview_detail`（第 399～421 行，`finish` 之前）：复制 options，定 preview／不浮动／去掉 random，**临时把 `XTianqiLedger.GUARD` 置 false 再复原**，calculate → finish(execute=false)。
  - `_calculate` 返回的 breakdown 多一个键 `criticalIf`（`maxf(1.0, critical_base + frame.criticalAdd)`，第 395～396 行）；结算不读它。
- `modes/xiyou/core/tianqi_skills.gd`：`formula` 拆成外壳＋`_formula`（外壳存、复原 `_cur_skill`），`item_cri` 判完复原 `_cur_skill`。`tests/virtual_player/k_calibrate.gd` 自己写 `_cur_skill` 后调 `_cond`，不经 `formula`，不受影响。
- `modes/xiyou/battle/smart_ai.gd`：`_safe_damage` 拆出 `_parts`（公式值、档案、段数），预览分支在 `_safe_damage`／`expected_damage`／`healing_amount(_rec_factor)`；`threat`／`shield_points`／`benefit`／`recovery_utility`（打分部分）／`cost_multiplier`／范围判断／`harmful_state`／`formula_safe`／`is_boss` 转发 XBattleEval，数值逐行照搬。

## 性能基准（验收 1-3）

本机 M1 Pro 无头、`xiyou_tianqi_smart_ai_eval` 的 `_perf`：4 名角色（1 逍遥、100 云霄、131 立希、107 钟离，各学全部重构技，技能数 24／9／12／14）对敌群 394（5 个敌人），一次 `XSmartAI.choose`：

| 模式 | 平均 | 最慢 | 结算链调用（4 次选招合计） |
| --- | --- | --- | --- |
| 统一预览（开） | 约 180～200 ms | 约 350～390 ms | 141 次 |
| 卡 1 手抄（关） | 约 80～88 ms | 约 150～167 ms | 0 |

- 做过的：暴击不再整条重算（用 `criticalIf` 折算，调用 261→141）；变量表（5000 格）一次选招只拼一次；结算链结果按（攻、受、技能、公式值、双方 HP/MP/TP、视图）缓存。XSmartAI 的 `expected_damage` 已在上层按同样的键缓存，所以内核缓存命中数为 0（PERF 行打印 `cache_hits`），重复的是 safe_damage 与 expected_damage 之间的共用，按调用数算已经最少。
- **没达标**：评估稿写的安卓目标 ≤20～30 ms 本单达不到，卡 1 自己在电脑上就要 80 ms。瓶颈量过：一次 `XDamage.calculate` 约 2.8 ms，其中 `XActorDamageHooks.capture`（24 段模块钩子）约 2.0 ms，里面 `XTianqiQiyinEffects.damage_ops`、`XTianqiAffixBattle.damage_ops`、`XTianqiTrumpet.damage_ops` 各约 0.6 ms（其余 21 段合计不到 0.1 ms）。**真出手也走这条，每一段伤害都付这 2 ms**，不只是 AI。这三个文件不在本单独占范围，没动，见「可优化」。

## 给 T277（敌方六维 AI）：XBattleEval 接口

```gdscript
# 建：从谁的角度看（user 是 XEnemy 时 allies＝logic.enemies、foes＝存活的 logic.actors）
var ev := XBattleEval.create_for(logic, enemy, {"check_weakness": true, "check_kill": true, "check_shield": true, "ally_weight": 1.0})
# 或手给阵营：XBattleEval.new(logic, user, allies, foes, opts)

# 一招打分（不读六维；六维只决定 opts 和外面的 softmax 温度）
var r := ev.score_skill(XDB.rec("Skills", act.skillId), {"long_fight": false, "damage_scale": 0.0})
# r = {"score": float（已乘代价倍率）, "target": XBattler 或 null（全体／随机）}

# 零件
ev.expected_damage(ev.user, t, rec, ev.raw_value(ev.user, t, rec), ev.hits_of(rec))  # 期望伤害（命中、闪避、暴击、段数都算上）
ev.hit_value(a, t, rec, raw)          # 一段的结算值（正＝伤害，负＝回复／吸收），同正式乘区链
ev.hit_detail(a, t, rec, raw)         # {value, criticalIf, tianqiKind}
ev.heal_value(a, t, rec, raw)         # 回复量（取正）
ev.element_kind(t, rec)               # weak／resist／immune／higher_*／neutral（check_weakness 关时恒 neutral）
ev.damage_utility(t, damage, scale)   # 伤害效用（威胁×(11000×伤/剩血＋击杀7000＋4000×伤/本回合最大)）
ev.recovery_score(t, hp, mp, tp)      # 回复急需度
ev.benefit(t, rec, long_fight, opp, fri)  # 增减益、解状态、控制
ev.cost_multiplier(rec)               # MP／TP／HP 代价折扣
ev.threat(t)；ev.targets(rec)；XBattleEval.is_boss(e)；XBattleEval.shield_points(t, true)
```

- opts：`check_weakness`（关＝按无属性估，给低战商）、`check_kill`（关＝不加击杀分）、`check_shield`（关＝剩余血量不算护盾）、`ally_weight`（对友方治疗／护盾／增益分的倍率，给「配合」）、`raw`（Callable(a, t, rec) → 公式值，不给走 `raw_value`：重构技与安全算式只读求值，其余 0）。
- 全部只读；一个实例只用于一次决策（内部有缓存，打完就丢）。烙印破防 ×1.3 只在我方角色身上（`XTianqiBrand.taken_mult` 只认我方），所以「集火破防目标」是敌方 AI 的事：用 XBattleEval 估我方破防角色伤害自动 ×1.3（专项 `brand_break_x13`）。
- 没做、留给 T277／卡 3：嘲讽／挑衅预过滤（`targets` 只按 scope 给）、反伤／反弹折损、Boss 关键回合脚本招硬优先、softmax／温度。

## 实跑证据

- 新专项 `xiyou_tianqi_smart_ai_eval` 50/50：预览开估伤／估治疗／五条悟茈非 0、选主力技；开关关回卡 1（非 0、值不同）、总开关关回 0；元素（敌群 853 的 945 号：弱 8、7，耐 6、4，免疫 15）：弱点 > 无属性 ×1.2 以上、耐性 < 无属性、免疫估 0，AI 打分同序；低战商（check_weakness 关）弱点和无属性一样大；烙印破防 ×1.3；零副作用三组（每组 4 人 vs 5 敌，我方 choose＋敌方 score_skill 全招）：指纹（双方全字段含 meta、随机流快照与抽数、变量开关物品、五条悟印记与施放、烙印这一场记录）、全局 randf、总账 violations 条数、GUARD 复原、`_cur_skill` 复原全一致；敌方 score_skill 有分、目标都是我方角色；西游档不进预览。
- `xiyou_tianqi_smart_ai`（卡 1 专项）95/95：卡 1 手抄乘区的数值断言（141～166 号 ×100、不叠旧 boosts 上界）改在预览关时跑（＝验收 2 回退路径）；P2-4：上界补乘 `XTianqiNoX6.dealt_scale`、补 `expected_damage` 上界断言（4 条）。
- 选测（选测.py main --list 178 个场景，含 xiyou_smart_ai 全 16 片、xiyou_smart_ai_profile、xiyou_determinism、xiyou_rules 各片）：云端选测 05b5620eb，结果见下一行。
- 云端选测：（待填）
- 虚拟玩家 explore（`--vp-mode=explore --vp-seed=1`）：TEST_RESULT 14/14，报错 0。
- 短帧 climb（`--vp-mode=climb --vp-ff --vp-difficulty=jianxian --vp-frames=40000 --vp-seed=2 --vp-pass-after=3`）：到第 5 层（通过 4 层）、TEST_RESULT 9/9、stuck 空、violations 空、ERROR 0（只有既有的 XTianqiBase 守层表 warn_once 警告）。虚拟玩家是手动打，不走自动战斗。
- 语法检查.py：1092 个 .gd 0 问题。
- 没跑：`--oracle` 对照（合并时总装带，派单验收 5）；本机全量。

## 没做／偏离

- 治疗：统一预览也接了回复（`XDamage._healing` 已乘受益者 rec，壳里不再乘，见 `_rec_factor`）；物品回复效果 11／12 照旧手算（不是公式伤害）。
- 角色档案的 multiplier／pierce／boosts 在预览开时不叠（正式乘区链里这些来源各自生效）；我猜个别档案倍率模拟的是正式链里没有的东西，没逐个核，靠专项「非 0、选主力技」兜底。
- 评估稿第二节「补齐天启特色打分项」（嘲讽、反伤、follow、free_action、longFight 全队火力、新角色档案）属于卡 3，本单没做。

## 异议

- 评估稿说「`smart_ai.gd` 里 80% 逻辑阵营无关、整块抽走」：我只抽了真正阵营无关、跟原版插件对齐无关的零件。我方 `score_candidate` 带着异化投影、档案溅射／铺垫、逆祷平分、随机目标按 tgr 加权等 16 片 oracle 对齐的细节，整块搬给敌方没有意义还会拖累西游档对照；敌方另给一个干净的 `score_skill`（同一套零件、同一条估伤链）。这样共用的是「估值」，不共用「策略」，跟评估稿的分层图（内核 vs 策略壳）一致。
- 安卓 20～30 ms 目标：瓶颈在正式结算链的三个天启模块钩子上，不在 AI；建议先修钩子（真出手也受益），再谈 AI 侧粗筛。粗筛（先手抄估分、只对前几名跑预览）会让弱点技在粗筛阶段被手抄值刷掉，跟本单目标冲突，没做。

## 交接板

- 下一步：T277 敌人六维 AI 可以接 XBattleEval（接口见上）；建议派一单修 `XTianqiQiyinEffects`／`XTianqiAffixBattle`／`XTianqiTrumpet` 的 `damage_ops` 每段 0.6 ms（见「可优化」）。
- 用户试玩说明：天启篇开「智能战斗AI」自动战斗，会优先用打弱点属性的技能、不往免疫的敌人身上砸。
- 需要用户决定：无

## 进度账

- 部分：智能AI天启适配 卡1 完成 → 卡2 完成（统一预览＋共用底座），依据：新专项 50/50＋卡1 专项 95/95＋选测。

## 可优化（流程／工具／效率）

- 建议（性能，归战斗核心车道，Opus）：`XTianqiQiyinEffects.damage_ops`、`XTianqiAffixBattle.damage_ops`、`XTianqiTrumpet.damage_ops` 每次各约 0.6 ms（本机），`XActorDamageHooks.capture` 合计 2 ms、占一次 `XDamage.calculate` 的七成；真出手每一段伤害都付。多半是每次重扫装备／词条／号卷，按 `XActor` 只读窗口（O-348）缓存应能把 calculate 压到 1 ms 内，AI 选招跟着快一倍多。
- 建议：`XBattleLogic.vars()` 每次现拼 5000 格数组，正式结算也一招一拼；可在只读窗口里缓存。
- 已做：XBattleEval 静态计数 `stat_calls`／`stat_hits`，性能专项打印，回归时一眼看出调用数有没有涨。

## 本分支提交

- 05b5620eb T282：天启篇智能AI统一预览估伤（XDamage.preview_hit／preview_detail）＋敌我共用估值底座 XBattleEval、开关 o_tianqi_preview_damage
