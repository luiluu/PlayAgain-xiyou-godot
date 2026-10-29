# 交付：claude/bajie-alien-affix-354c33

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_82）
- 状态：可合并
- 本期：异化词条效果移植·期一（installAlienationAffixes.js 81 行、installAlienationAdvanced.js 199 行）。期一只做「现有伤害钩子＋行动接点就能接上」的逆骨、归墟；其余 18 个词条列在下面清单，归期二。

## 原版词条／机制清单（冻结 v0.28 `js/codex/runtime/`）

词条池：`alienation.json` pools 共 22 件本体（武器 10、防具 12）。逆骨 16 件、逆祷 14、吞器 10、疫囊 8、祸祝 6，其余 15 个词条 22 件全有（Boss 专属：连命、夺舍、嫁祸、献器），**20 个词条都出得了**，期二收益不小。

「Aff」＝installAlienationAffixes.js，「Adv」＝installAlienationAdvanced.js，数字是行号。

| 词条 | 战斗里怎么生效（触发点 · 公式） | 依赖的钩子 | 期 |
| --- | --- | --- | --- |
| 逆骨 inversebone | 公式帧（evalDamageFormula，Aff:28）里：目标是逆骨者且技能是物理或逆骨技能时目标物防读 0；行动者是逆骨者、技能在 templates.inversebone 时物攻改读物防（Aff:29，原值取包装之内）。伤害钩子 enter 再压一层 physical=false 的帧（Aff:31-35，整次伤害计算），build 时目标是逆骨者则 physicalDefenseRate=0（Aff:37） | Game_Actor.param、evalDamageFormula、CodexDamageHooks | **期一已做** |
| 归墟 void | 攻击类伤害（伤害类型 1／2／5／6）：伤害钩子 noElement、elements=[0]（Adv:193）；applyItemEffect 跳过效果 21／31／32（Adv:187）；行动帧内不给别人附加状态（Adv:191-192）；持续伤害帧（dot）里阻断（Adv:190） | CodexDamageHooks、applyItemEffect、addState、blocksDamage | **期一已做**（dot 那条见「没做」） |
| 祸祝 blessing | 投影 `Game_Action.item`：templates.blessing（只有 7100）的技能改为敌方：scope 8→2、其余→1；效果 31→32，状态换成 statePairs 对应的诅咒；名字「祸祝·」（Aff:42-46） | 行动道具投影、DataManager.isSkill；**config 缺 statePairs** | 二 |
| 百相 mimic | 敌人行动根结束时记录其合法攻击（borrowable，最多 3 个，Aff:24 由 finishAction 调）；技能表去掉被替换技能、加入当前仿形技能与切换技能 10197（Aff:21）；切换消耗行动（Aff:26）；熟练度取 min（Aff:23） | skills()、meetsSkillConditions、skillMasteryLevel、finishAction、apply | 二 |
| 逆祷 prayer | 投影：templates.attack 的攻击改为照技能 8 的治疗：scope 1→7、其余→8，原 scope 3～6 改为随机友方 n 个（Aff:42-49）；治疗预算＝按 MP 费用选治疗技能（≥125→166，≥75→135，否则 8）算的治疗值，平分给目标（Aff:50）；本人对敌伤害全阻断（Aff:51）；敌人身上来自逆祷者的负再生剔除（Aff:55-62）；非 attack 模板的伤害技能不能用（Aff:22） | 行动道具投影、makeTargets、makeDamageValue、blocksDamage、regenerateHp、meetsSkillConditions | 二 |
| 疫囊 pest | pestStates 状态与 2～7 号减益：对本人必中、不可抵抗、不可驱散（只能自然到期），清状态时保留（Aff:64-77）；每回合末把这些状态与减益传给全体敌人（回合取较长、腐蚀到期同步，Aff:78-79） | stateRate、isStateResist、isStateAddable、addState／removeState、clearStates、debuffRate、removeBuff、endTurn | 二 |
| 无相 faceless | 最多 2 对「用另一名队友已学的合法攻击替换自己一个主动技」（Aff:15、19-23）；熟练度 min(自己、等级、主人等级、主人熟练) | skills()、meetsSkillConditions、skillMasteryLevel | 二 |
| 空壳 hollow | 最大生命变 1，剩余生命换成护盾（Adv:58、75）；治疗、吸血失效；回蓝按比例转护盾（Adv:111）；生命费用从护盾付（Adv:126-128）；公式里 mhp 读原值（Adv:129）；战后护盾换回生命（Adv:196） | param、gainHp／setHp、gainMp、addShield、skillHpCost 三件套、evalDamageFormula、endBattle | 二 |
| 连命 lifelink | 与绑定队友合并生命池（Adv:53-54、73），伤害、治疗、复活都走池（Adv:100、195） | gainHp／setHp、revive、skillHpCost、行动结束同步 | 二（Boss 专属） |
| 吞器 swallow | 借背包里一件武器的登记特性（effectGhost，Adv:31-35），本武器栏外的武器位清空；供体被占用（Adv:28-30、87-90） | lockParty、traitObjects、changeEquip、背包／商店 | 二 |
| 夺舍 possession | 绑定队友整场退出战斗（battleMembers 过滤，Adv:80），取得其登记主动技与安全被动（Adv:37、72、85-86）；自己倒下两人退场（Adv:105） | battleMembers、traitObjects、skills() | 二（Boss 专属；**会动行动顺序与出战名单，可能要改 battle_logic 流程，先报方案**） |
| 绝缘 insulation | 外来的减益、控制、驱散免疫；外来治疗、护盾、增益、回蓝、赠行、觉醒、复活拒收（Adv:97、111、114、160、169-175、194-195） | 来源帧（A.frame().source）、gainHp、gainMp、addShield、addState／removeState、addBuff、revive、云裳 | 二 |
| 舍身 sacrifice | 自己得到的治疗、护盾、增益转给绑定队友（Adv:93、98、114、163、171） | gainHp、addShield、addState、addBuff | 二 |
| 嫁祸 scapegoat | 敌方生命伤害行动的命中、闪避、暴击、伤害都改由保护者承受（Adv:117-122）；自己生命随保护者比例（Adv:104）；生命费用由保护者付 | itemHit／Eva／Cri、makeDamageValue、executeDamage、gainHp、skillHpCost | 二（Boss 专属） |
| 缄默 silence | 选定攻击技能 MP 费用为 0，改为锁定生命上限：每次 +(面板 MP 费用／开场 MP)×20%（Adv:130-134、143），并绕过魔法沉默（Adv:145-149） | skillMpCost、canPaySkillCost、paySkillCost、param、isSkillTypeSealed | 二 |
| 恶愿 wish | templates.wish（7100）改为除自己外的全体友方；自己先吃对应逆向减益，不能抵抗、净化（Adv:176-181） | 行动道具投影、makeTargets、apply；**config 缺 statePairs** | 二 |
| 献器 offer | 自己全部装备的登记特性交给绑定队友，自己整场空装（Adv:70、84、87） | lockParty、traitObjects、changeEquip | 二（Boss 专属） |
| 囚厄 jail | 接收其他队友实际获得的 jailStates 与 2～7 号减益（Adv:154-175），不能免疫、抵抗、净化 | stateRate、isStateResist、addState、addDebuff、removeState／removeBuff、clearStates；**config 缺 jailStates** | 二 |
| 饕餮 glutton | 实际 MP 上限 0、回蓝失效；吞掉自己的登记增益得饥饿储备（Adv:150-151、161、171）；MP 费用从储备扣（Adv:132-144）；吞噬技能 10198（Adv:152-153）；挂机选技（Adv:138-142） | param、gainMp／setMp、skillMpCost 三件套、addState／addBuff、skills()、apply、evaluate、挂机 | 二 |
| 蚀术 erosion | 选定攻击的生命伤害改为只扣护盾（Adv:124），同一行动的其他伤害归零（Adv:190）；命中后封印目标上次用的合法技能，同时封印自己的选定技能，到双方下一次原有行动窗口结束（Adv:182-185） | executeHpDamage、blocksDamage、apply、isSkillSealed、startAction／endAction | 二（要新加技能封印判定） |

另：Aff:5 把 statePairs 的诅咒与腐蚀登记进云裳 transferDebuffs（云裳侧，随期二的祸祝／恶愿一起做）。

**期二前置**：`alienation.json` 的 templates 目前只有 attack、inversebone、blessing、possessionSkills、wish、silence、gearTraitCodes、pestStates，**没有 statePairs 与 jailStates**；期二要先让 `alien_config_probe.cjs` 导出这两张表。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条效果·期一：逆骨、归墟在战斗里生效（dev.待定）

1. `alien_battle.gd`（XAlienBattle）文末新增「词条效果」：
   - **公式帧** `_formula_frames`（原版 A.formulaFrames）：`push_formula(item, a, b, formula)`／`pop_formula()`。公式求值压 physical＝物理技能或逆骨技能；伤害计算整段压 physical＝否（原版伤害钩子 enter）。
   - **逆骨** `param(a, i, v)`：Game_Actor.param 包装，帧内目标物防读 0、行动者用逆骨技能时物攻改读 `a.param_before_alien(3)`；帧外原值。影子克隆（预演）按 actor_id 认同一角色。
   - **伤害钩子** `descriptor()`：模块 `alienation`，order 1 写 physicalDefenseRate（原版 unshift 到最前），order 21 写 noElement／elements（原版 installAlienationAdvanced 时 push，排在小猫剑圣 19 之后、宝珠 39 之前）；事实 `capture()`＝{目标逆骨, 行动者归墟且攻击类伤害}。
   - **归墟**：`skips_effect`（applyItemEffect 跳过 21／31／32）、`blocks_state`（行动帧 `_action_frames` 内，归墟者的攻击不给别人附加状态）。
   - `has(b, key)`：原版 A.has（战斗中按冻结词条，战斗外按身上的异化装备）。
2. 接点：`actor.gd` 的 param 拆出 `param_before_alien`（专属模块→小猫→**异化**→种族祝福，按原版安装先后）；`damage.gd` 的 `calculate` 包一层公式帧（原体改名 `_calculate`），纯公式程序取上下文时压公式帧；`formula_execution.gd` 的 `run_item` 包一层公式帧（原体改名 `_run_item`，战斗、预演、智能 AI 都经过）；`battler.gd` 的 `add_state` 开头问归墟；`battle_logic.gd` 的 `apply` 前后压／弹行动帧（在 YEP initiate～conclude 之外），`_effect` 开头问归墟；`module_registry.gd` 标准表加 `XAlienBattle.descriptor()` 并取 `facts.alienation`。
3. 参照探针 `mv_oracle/alien_affix_probe.cjs`（3 例）：角色 1（99 级）穿本体 1044 石中剑的异化武器（无词条／逆骨／归墟），角色 8 同队，敌群 2；真实 BattleManager 跑普攻 1、连续攻击 3、十字军打击 109（元素 8）、火球术 114（不在逆骨技能里），敌人普攻打角色 1／8，角色 8 普攻；每步记双方生命、法力、护盾、状态、增减益与帧外物攻／物防。登记 `同步正式西游.py` 探针表与 `oracle_additions.py` KEYS（期二追加用例时按 id 认新增）。
4. 专项 `xiyou_alien_affix`：templates 头尾与长度、三例逐步与参照一致，每步之后两种帧都已弹空。
5. `tests/xiyou_module_hooks.gd` 的 `cat.default_host_handlers`：标准钩子表多了 alienation 两条（order 1、21），期望的调用顺序跟着改。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：`apply` 前后 `XAlienBattle.push_action`／`pop_action`；`_effect` 开头 `XAlienBattle.skips_effect`。
- `actor.gd`：`param` 改为 `XRaceBattle.param(XAlienBattle.param(param_before_alien(i)))`，新函数 `param_before_alien`（原 param 内三层）。
- `battler.gd`：`add_state` 开头 `XAlienBattle.blocks_state`。
- `damage.gd`：`calculate` 外包公式帧，原体改名 `_calculate`；`eval_formula` 纯公式分支取上下文时压公式帧。
- 另改（非原沙僧文件）：`formula_execution.gd`（`run_item` 外包、原体改名 `_run_item`）、`module_registry.gd`（标准表与取事实各一处）、`tests/xiyou_module_hooks.gd`（见草稿 5）。

## 没做（期一范围内）

- 归墟的持续伤害阻断（Adv:190 `kind==='dot'` 且帧的行动是攻击类伤害）：原版只有「Game_Action.apply 嵌在 dot 帧里」才会碰到，正式流程里 dot 帧（customEffectEval、腐蚀）都不带行动，重制也没有 dot 帧，没移植。
- 原版 A.frames 还有反击、反射、资源等帧种（Runtime:89、97-100）；归墟只用 apply 帧，期一只建了它。

## 验证

- 合 main：`git merge main` 时 main 未前进（末端 fd00ec47），无冲突。
- 选测（并行测试，31 个场景全部通过，无偶发）：`xiyou_alien_affix` 150/150、`xiyou_alien_battle` 330/330、`xiyou_alien_config` 95/95、`xiyou_alien_workshop` 45/45、`xiyou_module_hooks` 1310/1310、`xiyou_actor_modules` 56/56、`xiyou_actor_p0` 3322/3322、`xiyou_cat` 994/994、`xiyou_race_battle` 436/436、`xiyou_formula_effects` 908/908、`xiyou_formula_equipment` 1804/1804、`xiyou_formula_program` 43458/43458、`xiyou_formula_rest` 1352/1352、`xiyou_formulas` 7/7、`xiyou_custom_damage` 145/145、`xiyou_attack_element` 66/66、`xiyou_element_ternary` 33/33、`xiyou_combat` 34/34、`xiyou_param_states` 582/582、`xiyou_smart_ai`（四段）全过、`xiyou_determinism` 372/372、`xiyou_boss_output` 3823/3823、`xiyou_boss_output_context` 16621/16621、`xiyou_imported_balance` 273/273、`xiyou_rules` 难度 1 四段（`xiyou_rules`／`_d1b`／`_d1c`／`_d1d`）全过。
- 同步：工作树跑 `同步正式西游.py --accept-additions`：只执行新探针 alien_affix_probe（6 秒，其余 61 个复用），结果「测量不变」，核对 0 个问题；同步后 `xiyou_alien_affix`、`xiyou_module_hooks` 复跑通过。
- 已清理：本车道的并行测试日志目录与临时调试脚本都已删除（同步备份目录是同步脚本的常规产物，保留）。

## 交接板

- 下一步：异化词条效果期二（18 个词条，见本单清单）。建议分批：①状态类（疫囊、囚厄、绝缘、舍身，先补 statePairs／jailStates 配置）；②生命池类（空壳、连命、嫁祸）；③技能表与投影类（祸祝、恶愿、逆祷、百相、无相、缄默、饕餮、蚀术）；④装备类（吞器、献器、夺舍）。夺舍会改出战名单，开工前先报方案。
- 用户试玩说明：异化装备的「逆骨」「归墟」词条现在战斗里生效：逆骨角色的物理技能按物防出伤、自己物防不再减伤；归墟角色的攻击按无元素结算，不附带状态与增减益。其余词条仍只有工坊侧（能抽、能配、能穿，战斗里不起作用）。
- 需要用户决定：无

## 进度账

- 战斗规则·异化：词条效果 0/20 → 2/20（逆骨、归墟）。

## 可优化（流程／工具／效率）

- 建议：`alien_config_probe.cjs` 补导出 templates.statePairs、jailStates（期二前置，八戒车道期二顺手做）。
- 建议：异化专项想用低等级角色穿异化装备时，池里的本体大多要 25～99 级（角色 1 在 30 级一件都穿不上）；以后加异化用例照本期用 99 级或角色 8。无需改工具。
- O-106（预分配）：本期未用。

## 本分支提交

- 62903a96 WIP: 异化词条效果期一：逆骨、归墟接入伤害钩子与行动帧，新参照探针与专项
- （本提交）异化词条效果期一：oracle_additions 登记、专项 .uid、交付单可合并
