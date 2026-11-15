# 交付：cc/tianqi-ledger-p2

- 车道／工作者：C 规则·数值线「伤害加成总账·期二 归池清场」（cc 车道，Orca task_9c7afc7fa3b8，Opus＋medium：改战斗伤害乘区，甲档，交小A 核）
- 状态：进行中

依据：私密设计仓 `重制设定/天启篇_伤害加成总账_v0.4.md` 第八节表「二 归池清场」那行＋第五节第 1 条全表；D16＝乙（七印只归池，`qiyin_gear.json` 一个数没改）。期一核查记账（cc_tianqi-ledger-p1 交付单「co 甲档核查」）的 P2、P3、补记 1～2 条一并做。期三（回合预算、丹药下架、九线封顶）、期四（骑士血量、倍率、开卡、专属模块到期）没碰，任何数值表没改数（`balance_table.json` 只是把暴击、敏捷两个数原样复制进新的 `combat_rules` 节）。

## 结论

- 第五节第 1 条全表 11 行全部落地，每样一个回退开关（默认开）；期一登记成「豁免·期二到期」的七行（`qiyin`、`orb_resonance`、`race`、`affix_skill`、`skill_pass`、`enemy_race_bonus`、`self_rate`）全部改成「已归池」，`damage_ledger.json` 的 `phase` 改成 2，守卫随之生效：这些来源再出现单独相乘当场报错（专项 `guard_flags`）。
- 西游档行为与 main 逐位一致：所有归池判定都走 `XTianqiLedger.pool_on`＝开关开**且**天启篇存档；西游档 11 个模块角色普攻＋模块技能、暴击／不暴击（断言要求 80 下以上），十个开关全开、全关逐项相等（`xiyou_p2_switches_same`）；开关关掉的那条路和 main 的算式逐字相同（七印的旧路径按原次序连乘）。
- 没遇到停手条件：每一条都不用改数就接得通；守卫在西游档不进（`auditing` 先判天启篇），真打与 `--oracle` 选测里没有误报。
- `baseline_dps --duel` 1～33 层开／关对照：见下面「1～33 层对照」。

## 第五节第 1 条逐行

| 设计稿那一行 | 做法 | 开关（回退） | 证据 |
|---|---|---|---|
| 七印全部条件增伤（D1～D3、D5、D6、D9） | `tianqi_qiyin_effects.gd damage_ops`：每条条件记成 [池, x]，归池时同池相加——群体（`aoe_skill_dmg_pct`）、天平（`skill_dmg_pct`）进①`normalAdd`；元素（`element_dmg_pct`）进②`elementAdd`（0～15 每一系都加，原来是整下乘、候选元素哪个都吃到）；其余（减益、击倒、砝码、低血、换系、免死、量、终、连段、沉默普攻、灰镰、对低血敌人、一发入魂、蓄力）进③`finalAdd` | `XTianqiLedger.POOL_QIYIN` | 七印专项 `hui2_low_target`、`hui2_switch_off_old_mult`、`bai3_two_debuffs`、`scales_skill_dmg`、`weights_dmg_crit`；总账 `p2_qiyin_row` |
| 七印大刀阔斧「末段 ×2」 | 记成 [③, mult−1]＝末段 ＋100% 进③ | 同上 | 同上（同一段代码） |
| 宝珠共鸣 | `module_registry.gd _orb_sets`：天启篇 `facts.orbPooled` 时写 `finalAdd ＋g`，否则照旧 `finalMultiplier ×(1＋g)`；`damage.gd` 只在 `pool_on("POOL_ORB")` 时放这个键 | `POOL_ORB` | `p2_orb_pooled`（处理函数两边＋真打的 trace） |
| 种族祝福 | `race_battle.gd build`：`facts.race.pooled` 时出伤的 ×(1＋x) 一律改 `finalAdd ＋x`；治疗、防御率、固定减伤、魔族爆伤（本来就是④加项）照旧。只对物理（魔族两条）／魔法（神族）生效的按这一下的伤害方式折：对口全额、混合一半、不对口 0（见「我不同意的地方」1） | `POOL_RACE` | `p2_race_demon`、`p2_race_hunter`、`p2_race_counter_weapon`、`p2_race_god` |
| 对某族敌人增伤 `<EnemyRaceBo>` | `damage.gd`：种族乘数算出后，天启篇把 (乘数−1) 加进 `frame.finalAdd`、乘数置 1（`_race_factors` 挪到终伤池之前算，纯函数，次序无关） | `POOL_ENEMY_RACE` | `p2_enemy_race_pooled`（种族乘数 1、终伤池 ＋0.3；关掉 ×1.3） |
| 原版 SelfPhysRate／SelfElemRate | `damage._self_rates` 天启篇恒 [1, 1]（`_independent` 里的 `settlementMultiplier` 照旧，那是专属模块的，期四） | `NO_SELF_RATE` | `p2_self_rate_off` |
| 原版套装「结果 ×2」类 | **先核了走哪个字段**：原版套装改伤害只有一条路——套装给的状态在确认阶段 `mul`（红魔套装 3 件 → 铁头娃II 713 ×2，`cond nonzero`）；套装属性倍率乘能力值（属），套装技能全是 passiveHarmRi／ELUP／CrHarmRi 等加项（已经在池里）。做法：`XTianqiLedger.suit_confirm_add` 天启篇我方打敌人时 ＋(k−1) 进③；`suit_confirm_rows` 在确认阶段把那一步换成带 `skipTypes [1,2,5,6]` 的副本（打敌人的伤害不再乘；治疗、打自己人照旧 ×2）。缝合 38 是脚本、不是纯乘，留在 `state_confirm`（期四） | `POOL_SUIT` | `p2_suit_confirm`（真穿三件红魔：终伤池 ＋1、确认阶段不翻倍；关掉确认阶段 ×2；治疗 −100→−1000 照旧 ×2 ×5、打队友照旧） |
| 词条技能伤 | `tianqi_affix_battle.gd:381` 改加 `normalAdd`（①） | `POOL_AFFIX_SKILL` | 词条专项 `skill_mult`、`skill_mult_switch_off`、`attack_no_skill_mult` |
| 技能专属被动 skillPass.rate | `damage.gd`：天启篇 rate 加进 `normal_add`，`skillMultiplier` 起点恒 1（flat 照旧是底数） | `POOL_SKILL_PASS` | `p2_skill_pass_pooled`（只有它一条时数一样；明细里①＝1.5、残余 skillMultiplier＝1） |
| 万灵增元丹类被动（5974～5977） | 这 4 个被动的效果全在开战状态标签（StartPushState1286／1287／1289、StartAEPushState1288）：`XActor.battle_start_state_tags` 天启篇跳过它们（战力预演 `power.gd` 也走这个函数）；学会照旧（物品下架是期三） | `NO_PILL_PASSIVES` | `p2_pill_passive_skipped` |
| 暴击 ＋50%、敏捷 ×0.8 | 档位表 `balance_table.json` 新节 `combat_rules {crit_add 0.5, agi_rate −0.2}`（数原样复制）；`XTianqiCombat.combat_rule` 读；`XTianqiNoDiffPassive.xparam_add／traits_pi` 改读它（`legacy_passive` 里同名两项只留给回退） | `XTianqiLedger.COMBAT_RULES` | `p2_combat_rules_same_numbers`、`p2_combat_rules_read`（改表就跟着变、关开关回读旧节）；难度被动专项 `bites_*` 把两节都拿掉做「什么都不乘」 |

七印另两处跟着理顺（不是加成，不改数）：派生一击的伤害系数（弓与冠再射 50%、连斩 dmg_pct、补刀 1.0，`_derived` 的 `scale`）归池后单独写一条 `finalMultiplier`，总账登记 `qiyin_derived`＝永久允许（派生攻击系数，底数）；我方被打时的承伤（`dmg_taken_pct`、庇护 `support_ally_dmg_taken_pct`）改写在 `incomingMultiplier`（靶），乘积相同（七印专项 `great_sword_taken_up`）。`actor_damage_hooks.capture` 认操作上的 `src` 键当来源标签、交给注册表前去掉。

## 期一核查遗留

- **P2（`tianqi_ledger.gd:158` 到期／效果级守卫）**：① 运行期：`XStateEffects.run("confirm")` 天启篇我方打敌人时调 `XTianqiLedger.audit_confirm`，身上每个带确认阶段效果的状态逐个过 `check("state_confirm","confirm")`——没登记的状态号报 `unregistered`，期数到了报 `exempt_expired`；套装那一步（已进③）、难度被动等价行不算（`confirm_runtime_p2`、`confirm_runtime_expires`、`confirm_runtime_scope`）。② 效果级：`damage_ledger.json` 新增 `state_confirm_fp`（191 个状态各自确认阶段效果的指纹，`XTianqiLedger.confirm_fingerprint`＝键排序 JSON 的 md5 前 8 位），专项逐个比对，既有状态号的确认阶段效果改了也失败（`state_confirm_fingerprints`、`state_confirm_fp_bites`）。
- **P3（「11 角」表述）**：`_numbers_same` 补上 170（镜流），现在是 11 个模块角色、每人普攻＋前四个模块技能、暴击／不暴击，注释和本单都按这个口径写，不说「全部技能」。
- **未触发模块分支夹具**：做了静态那一半——专项 `static_module_fields_registered` 扫 11 个模块文件里每一处写单独相乘字段的操作（46 处，按 `{"op": …, "field": …}` 字面写法扫），字段都在该文件对应来源的登记行里（真打没触发的渡鸦 355／356、数字强化 68／73、宿傩 250……都在内）。逐条把触发条件全开的**运行期**夹具没做，见「没做的」。
- **敌人反伤、敌源 mhp 型状态分链验证**（期一「需设计稿补记」1、2 条，co 要求分链）：专项第九节四条链各自验证，十个开关全开／全关结果相同：
  1. 元素反射／魔法反射（`element_reflect_rate`）：原版把这一招打回出手者——我方打我方，走我方伤害帧、守卫照管；七印、套装、对某族增伤只算打敌人（`chain_element_reflect`）。
  2. 敌人状态 React 反伤（381 反伤属性）：数额来自这一下我方伤害（已过五池、已去 ×6），同一输入两边相同，敌人不进守卫（`chain_state_react`）。
  3. 技能卡状态反弹（`XTianqiSkills._reflect`）：我方按敌人那一下的伤害比例打回，不过伤害帧、不吃我方池（`chain_card_reflect`）。要不要进③仍待设计稿定。
  4. 敌源按生命上限比例状态（中毒 4，hrg −10%）：`floor(mhp × hrg × rec)`，不过伤害帧、不吃任何池、不跟去 ×6 缩（`chain_enemy_mhp_state`）。

## 1～33 层对照（baseline_dps --duel，只量不调数）

（待写）

## 我不同意的地方

1. **种族祝福里「只对物理／魔法」的条款怎么进③，设计稿没写。** 原来魔族 ×(1＋q) 乘在物理伤害乘数上，打魔法招不生效；直接 ＋q 进③会让魔族的魔法招也吃到。我按这一下的伤害方式折：对口全额、混合一半、不对口 0（混合按一半是近似，原来按攻防权重分）。请设计稿补一句定口径。
2. **七印派生一击的系数没归池。** 设计稿把七印 finalMultiplier 整个算条件增伤；但其中 `scale`（再射 50%、连斩 dmg_pct）是「这一击按原招几成算」，归池会把 0.5 变成 −50% 进③、和别的加成相加，派生一击反而几乎打不出伤害。我单独登记成永久允许（派生攻击系数），期三回合预算接派生攻击时再定。
3. **白印「持续伤害 +20%」（`dot_dealt_pct`）没动。** 疫的伤害是直接扣血（`plague_tick`），不过伤害帧、没有别的池可并，它单独一条 ×1.2 和「进①、①里只有它」是同一个数；等期三九线封顶或疫重做时再看。
4. **「暴击、敏捷挪进全局规则」仍跟着难度被动等价的开关（O-421）走。** 稿子说是常驻规则；但 O-421 关掉时角色会重新学天道诅咒 6168（自带暴击 ＋50%、敏捷 ×0.8），规则再加一遍就叠两份，所以保留原来的判定（学了 6168、带着 995 就不加），只把数的来源挪到 `combat_rules`。
5. **未触发模块分支的运行期夹具建议挪到期四做。** 这批都是「豁免·期四到期」的专属模块，期四本来就要逐个模块改；现在逐个造形态、印记、神器、本次行动帧的夹具要碰 11 个模块的内部状态，量大且期四会改掉。期二先用静态扫兜住「字段都登记过」。

## 变更记录草稿

## 2026-11-15 【cc·伤害加成总账期二·未经审查】天启篇伤害加成总账期二「归池清场」：单独相乘改进池、暴击敏捷挪全局规则、确认阶段运行期守卫（dev.待定）

- 设计仓《天启篇_伤害加成总账_v0.4》第五节第 1 条全表（D16＝乙，七印数一个不改）：七印条件增伤、宝珠共鸣、种族祝福、对某族敌人增伤、原版套装确认阶段「结果 ×k」从单独相乘改成进池（技能池①、元素池②、伤害加成池③）；词条技能伤、技能专属被动改进①；原版独立乘区 SelfPhysRate／SelfElemRate 天启篇不读；万灵增元丹类被动 5974～5977 天启篇不挂开战状态；暴击 ＋50%、战斗中敏捷 ×0.8 改读档位表 `combat_rules`（数不变）。只对天启篇存档，每样一个回退开关。
- 总账表 `damage_ledger.json` 进期二：期一「豁免·期二到期」的七行改成已归池，新增套装确认阶段、万灵增元丹被动、七印派生系数、常驻规则四行；守卫在这些来源再出现单独相乘时报错。
- 期一核查遗留：确认阶段运行期守卫（过 check、到期会报）＋191 个状态的效果指纹；不改数断言补 170；模块文件静态扫；敌人反伤三条链与敌源生命上限比例状态分链验证。
- 基准工具 `baseline_dps` 加 `--ledger=off`（期二归池全关）。
- 西游档不变（归池全走「开关开且天启篇存档」，西游档开关开关逐项相等）。
- 验证：专项 `xiyou_tianqi_ledger`（66/66）、七印、词条、难度被动等价、种族、宝珠、去 ×6 专项本机通过；`检查.sh --oracle --affected main --cloud` 见交付单「验证」。
- 提交：（合并时填）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `damage_ops`；`actor_damage_hooks.gd` `capture`（src 标签） | （天启篇）七印条件增伤各自 ×(1＋x) 连乘进 finalMultiplier | 各自 ＋x 进池（群体、天平进①，元素进②，其余进③；末段 ×2 → ＋100%）；派生系数单列；我方承伤改写在承伤 | 伤害加成总账期二（第五节第 1 条，D16 乙） | `XTianqiLedger.POOL_QIYIN = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/module_registry.gd` `_orb_sets`；`damage.gd` `_calculate`（orbPooled） | 宝珠共鸣 finalMultiplier ×(1＋g) | 天启篇 ＋g 进③ | 同上 | `XTianqiLedger.POOL_ORB = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/race_battle.gd` `build`、`_pooled_op`；`damage.gd`（facts.race.pooled） | 种族祝福出伤 ×(1＋q) 乘在终伤／物理魔法伤害乘数上 | 天启篇 ＋q 进③（对口全额、混合一半、不对口 0） | 同上 | `XTianqiLedger.POOL_RACE = false` | cc | 保留 |
| O-待定-4 | `modes/xiyou/core/damage.gd` `_calculate`（EnemyRaceBo） | 对某族敌人增伤单独一个种族乘数 | 天启篇加进③ | 同上 | `XTianqiLedger.POOL_ENEMY_RACE = false` | cc | 保留 |
| O-待定-5 | `modes/xiyou/core/damage.gd` `_self_rates` | 原版独立乘区 SelfPhysRate／SelfElemRate 相乘 | 天启篇不读 | 同上 | `XTianqiLedger.NO_SELF_RATE = false` | cc | 保留 |
| O-待定-6 | `modes/xiyou/core/tianqi_ledger.gd` `suit_confirm_add`、`suit_confirm_rows`；`damage.gd`；`state_effects.gd` `run` | 套装给的状态在确认阶段「结果 ×k」（铁头娃II ×2） | 天启篇我方打敌人 ＋(k−1) 进③、确认阶段那一步不乘；治疗、打自己人照旧 | 同上 | `XTianqiLedger.POOL_SUIT = false` | cc | 保留 |
| O-待定-7 | `modes/xiyou/core/tianqi_affix_battle.gd` `damage_ops` | （天启篇）词条技能伤加在 skillMultiplier 上（单独一区） | 改加 normalAdd（①） | 同上 | `XTianqiLedger.POOL_AFFIX_SKILL = false` | cc | 保留 |
| O-待定-8 | `modes/xiyou/core/damage.gd` `_calculate`（skillPass） | 技能专属被动 rate 是 skillMultiplier 的起点 | 天启篇加进 normalAdd（①） | 同上 | `XTianqiLedger.POOL_SKILL_PASS = false` | cc | 保留 |
| O-待定-9 | `modes/xiyou/core/actor.gd` `battle_start_state_tags` | 万灵增元丹类被动 5974～5977 开战挂全属性 ×120%、结算伤害 ×120%／×150% 等状态 | 天启篇不挂 | 同上（G15） | `XTianqiLedger.NO_PILL_PASSIVES = false` | cc | 保留 |
| O-待定-10 | `modes/xiyou/core/tianqi_no_diff_passive.gd` `_rule`；`tianqi_combat.gd` `combat_rule`；`balance_table.json` `combat_rules` | （天启篇）暴击 ＋50%、敏捷 ×0.8 读「难度被动等价」legacy_passive | 改读档位表全局规则 combat_rules（数不变） | 同上（第四节第 2 条第 4 款） | `XTianqiLedger.COMBAT_RULES = false` | cc | 保留 |

## 交接板

- 下一步：伤害加成总账期三（回合预算、丹药下架、九线封顶，设计稿第五节第 2～4 条；回合预算调用点清单在期一交付单）。上面「我不同意的地方」1～4 条请设计稿补记（种族折算口径、七印派生系数、疫的持续伤害、常驻规则判定）；第 5 条（模块运行期夹具）建议并进期四。
- 用户试玩说明：天启篇里堆了多条七印条件、宝珠共鸣、种族祝福、红魔套装的角色伤害会变低（同池相加，不再连乘），只有一条来源时不变；西游档不变。
- 需要用户决定：无（D16 已定乙）。

## 进度账

- 天启篇数值线第 3 步（伤害加成总账）：期一、期二完成，期三、四待做。

## 可优化（流程／工具／效率）

- 已做：基准工具 `baseline_dps` 加 `--ledger=off`，以后期三、期四的开关对照照这个写法加（回退：不传这个参数）。
- 建议：改了 `tests/virtual_player/baseline_dps.gd`（不是专项、没有测试引用它）会让 `选测.py` 判「拿不准」、云端整轮。可以在 `选测对照.json` 里把 `tests/virtual_player/` 下的工具脚本登记成「只跑 xiyou_virtual_player」，省一轮整轮云端（预计每次几十分钟额度，归工具车道，Sonnet＋medium）。

## 验证

（待写）

## 待交叉核查

- 甲档（小A，Hydrogen 高）：本分支全部提交。改到的原沙僧核心文件：`damage.gd`（技能专属被动、宝珠事实、对某族增伤、套装确认阶段、独立乘区，都只在 `pool_on` 时走新路）、`state_effects.gd`（确认阶段换行＋运行期守卫）、`actor.gd`（开战状态标签跳过丹药被动）、`actor_damage_hooks.gd`（src 标签）、`module_registry.gd`（宝珠处理函数）、`race_battle.gd`（build 归池）。请重点看：开关关掉时七印旧路径和 main 逐位相同（连乘次序）；种族折算口径；套装确认阶段 skipTypes 只在目标是敌人时生效、和 `suit_confirm_add` 判定一致（同一个函数出）；西游档 `pool_on` 恒假。

## 本分支提交

- 8173358a5 WIP：归池清场主体、确认阶段运行期守卫与指纹
- （后续提交见 git log）
