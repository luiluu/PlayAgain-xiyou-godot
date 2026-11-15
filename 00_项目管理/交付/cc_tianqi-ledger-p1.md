# 交付：cc/tianqi-ledger-p1

- 车道／工作者：C 规则·数值线第 3 步「伤害加成总账·期一 总账入口（不改数）」（cc 车道，Orca task_246ba90d1cca，Opus＋medium：战斗核心接线，甲档，交 co 核）
- 状态：进行中

依据：私密设计仓 `重制设定/天启篇_伤害加成总账_v0.4.md` 第八节「期一」那行＋「期一细则」（1）～（4），第五节第 4 条（3）（来源分桶口径），稿末第十一节 co 评审第 5 条。D24（骑士计时、全弱者资格）没碰，骑士数值一个没动。

## 结论

- **不改数**：天启篇档总账四个开关全开、全关，11 个模块角色的普攻和模块技能（卡关、暴击／不暴击）伤害逐项相等（专项 `tq_numbers_same`）；技能卡开关 `CARDS` 默认仍关，卡关时 MODULE_CAP 原样返回（`cap_cards_off_untouched`），所以期一合进去天启篇数值和 main 一样。
- **西游档零影响**：守卫、分桶、五池明细都先判 `XTianqi.active`；西游档模块钩子返回值不带 `tags`、被动缓存不带 `bySource`、伤害详情不带 `pools`（专项 `xiyou_*` 三条）。`damage.gd`、`actor.gd` 只加不改：`_independent` 的循环原样挪进 `_self_rates`（算式逐字不变），`XActorDamageHooks.capture` 分段算再按原次序拼（MODULE_CAP 是逐条过滤，分段与整段结果相同）。
- 没遇到停手条件：期一不用改数就接得通；守卫只在天启篇档我方出手时跑，西游档不进（`guard_xiyou_off`），不会误报。

## 逐条对应

### 期一细则（1）守卫三种登记状态

- 新文件 `modes/xiyou/core/tianqi_ledger.gd`（`XTianqiLedger`）＋ `modes/xiyou/tianqi_data/damage_ledger.json`。每个「乘」一行：`status` 是 `pooled`（已归池，出现就失败）／`exempt`（豁免，写 `expires` 到期期数，到期那一期起出现就失败）／`allowed`（永久允许）；`fields` 写这个来源许写的单独相乘字段。表里 `phase: 1`。
- 「乘」的口径（`MUL_FIELDS`）：落在设计稿第三节第 1 条五个口子（`skillMultiplier`、`elementMultiplier`、`finalMultiplier`、`settlementMultiplier`、`physical/magicalDamageMultiplier`）和 `growthMultiplier` 上、且不是恒等（mul/set 1、add 0）的操作，不论 add／mul／set（词条技能伤是 add 在 `skillMultiplier` 上，照样算单独一区）；另有不走钩子的三处：技能专属被动 `skillPass.rate`（`skillMultiplier` 起点）、种族乘数 `<EnemyRaceBo>`、原版独立乘区 `<SelfPhysRate>／<SelfElemRate>`。
- 守卫（`XTianqiLedger.audit`，`damage._calculate` 在算完各候选之后调用一次）：天启篇档、出手的是我方角色时，把注册表 trace 里每条「乘」按来源认一遍——`actor-modules` 那段按 `XActorDamageHooks.capture` 打的 `tags`（跟 ops 一一对应）认，别的注册表模块按模块号（`orb-sets`→宝珠共鸣、`race-blessings`→种族、`cat-sword`→猫）。来源没登记、字段不在那一行、已归池、豁免到期 → `push_error`（并行测试把 ERROR 行判失败）并记进 `violations`；**只记不改数**，伤害照算。
- 期一登记（与细则一致）：七印 `qiyin`、宝珠共鸣 `orb_resonance`、种族 `race`＝豁免·期二到期；15 个专属模块钩子 `module.*`＝豁免·期四到期。另按设计稿第五节第 1 条（期二归池那张表）把同样在表里的四处登记成豁免·期二：词条技能伤 `affix_skill`（B3）、`skill_pass`（C6）、`enemy_race_bonus`（G12）、`self_rate`（G13）；C5「另有猫、五条悟」和天启篇专属模块 `XTianqiModules.damage_ops`（卡开着才有）登记成豁免·期四；弱者挑战 `weak_challenge`（A9，天启篇不开）登记成已归池＝出现就失败；⑤档位池、技能卡招式倍率、机制类（靶）、敌方两项（见下面第 6 条）是永久允许。
- 没登记的新乘区当场失败：专项 `guard_flags` 造了四种违规（已归池、字段没登记、来源没登记、注册表新模块），全部认出；`guard_exempt_expires` 把期数改成 2，宝珠共鸣报「豁免到期」；`guard_ok_rows` 合规的不报；`guard_real_hit_clean`、`tq_hits_no_violation` 真打一遍没有误报。
- 原版状态确认阶段乘（设计稿第三节公式里有、登记表没列）：登记成一行 `state_confirm`（豁免·期四，暂定），`state_confirm_ids` 记期一时有确认阶段效果的 191 个状态号（转换数据 190 个＋贝吉特合体复制 2803）；专项 `state_confirm_all_registered` 扫状态表，新状态出现确认阶段效果就失败。这是测试期守卫，运行时不逐下查。归哪一期见「需设计稿补记」。

### 期一细则（2）MODULE_CAP 卡开着就默认拦、白名单才放

- `tianqi_skills.gd` `module_ops`：去掉「只管表里改写过的技能」那一判，卡开着时专属模块对任何技能（普攻、防御、没改写的、派生的）产出的增伤乘（终伤／技能／结算倍率 >1）、增伤加（终伤／普通／元素／暴击 >0）都去掉；新参数 `module`（段名）让白名单按「模块、技能号、字段」放行，白名单在 `damage_ledger.json` 的 `module_whitelist`，期初为空（`module_whitelist_empty_at_p1`）。机制类照旧放行：伤害方式、种类、元素、承伤、治疗，无视防御照旧夹到 ≥0.7、抗性穿透 add 夹到 ≤0.1（`cap_mechanics_kept`）。
- 回退：`XTianqiSkills.MODULE_CAP_ALL = false` 回到只拦改写过的技能（`cap_switch_off_attack_kept`、`cap_old_leaks_unrewritten`）。卡开关 `CARDS` 默认值没动（仍关），卡关时 `module_ops` 原样返回（`cap_cards_off_untouched`）。
- 逐号清单（任务第 1 条）：见下面「15 个钩子的乘操作逐号清单」。卡开着时清单里每一条增伤都被拦掉（`cap_all_blocks_boosts`）。
- `xiyou_tianqi_skills` 的 `p6_module_ops` 原断言「普攻原样 5 条」是旧口径：改成旧开关下仍是 5 条、新口径下只剩 3 条机制类。

### 期一细则（3）来源分桶

- `actor.gd` `_refresh_passive_now` 在求和之后、存记忆之前，天启篇档并排多存一份 `c.bySource`（`XTianqiLedger.passive_buckets`，同一批对象 `stat_equips()＋skills()＋states()`、同一份扫描 `_note_scans`）：`globalHarmRi`、`critHarmRi`、`skillTypeDvup`（按类型）、`SkETypeHarmRi`（按武器类型）、`skillPass`（rate）、`passiveELUP`（按元素），以及装备元素增幅 `elementAmplify`（按元素；`damage.own_bonus` 的同一批对象：状态＋装备＋角色＋职业）。原合计字段一个不动，西游档不建这份，`damage.gd` 照读原合计。
- 桶：秘籍格（功法 `XPowerBooks.is_power`、通用被动书 stypeId 5）、符文之语（装备有 `runewords`）、宝珠（装备孔里宝珠的 ELEMENT AMPLIFY 行，从装备的元素增幅里单拆）、原版装备、种族（`XRace.skill_info`）、成长装备（`XHubris.is_gear`）、天启篇自己的（装备带 `qiyin`／`tianqi_affixes`／`tq_reward`／天启篇异化标记）、角色自带与技能、状态。原版套装、真气不进被动缓存（套装走属性、真气 `APPLY_TO_DAMAGE` 关），表里留了桶名、期三接封顶时再接。
- 封顶函数 `XTianqiLedger.bucket_total(桶, 上限)`：吃分桶、吐封顶后的合计；期一没有调用处（九线封顶是期三）。
- 被动缓存记忆（O-396 `PASSIVE_MEMO`）多认一条「这份记忆带不带 bySource 和现在该不该带一致」，免得同一组备注在西游档、天启篇档之间串用。
- 专项：`buckets_sum_to_total`（各桶相加＝原合计，含九个元素的元素增幅）、`buckets_nonempty`、`bucket_of_equip`、`buckets_switch_off`。

### 期一细则（4）其余

- 五池定义照设计稿第四节第 1 条：① 技能池＝(1＋normalAdd)；② 元素池＝(1＋自身元素增幅＋elementAdd)；③ 伤害加成池＝(1＋finalAdd)；④ 暴击；⑤ 档位池＝`XTianqiCombat.damage_mult`。单独相乘的残余另列：`skillMultiplier`、`elementMultiplier`、`finalMultiplier`、种族乘数、独立乘区、物理／魔法伤害乘数。
- 伤害详情：天启篇档 `breakdown.row` 多两项 `pools`、`residual`（只加明细，`pools_detail` 核对 pools.skill＝normal、pools.bonus×finalMultiplier＝terminal、pools.element×elementMultiplier＝bonus；`pools_switch_off` 关了不带、伤害一样）。游戏里现在没有界面读这两项，留给期二的「九线封顶」标注和以后的伤害详情页。
- 回合预算调用点清单（只列不接）：见下面「回合预算调用点」。
- `总账.py`、`总账档位.py` 并进测算主流程：设计仓本车道只读，见下面「设计仓要改的（协调另派）」。

## 任务 1～8 逐条

| # | 要求 | 做了什么 | 证据 |
|---|---|---|---|
| 1 | 15 个钩子三种情形的乘操作全打出来 | 专项直接调（每个模块角色学满模块里出现的技能，普攻、防御、各技能，卡关、卡开）＋真打（11 个模块角色各上场打 8 回合，卡关、卡开各一场，记录钩子原始操作，「这一下不是所选的招」记成派生）；每条打 `LEDGER_DUMP` 行 | 下面「逐号清单」；`dump_all_registered`、`dump_scenarios`、`battle_recorded` |
| 2 | 总账表＋三种状态＋守卫 | `tianqi_ledger.gd`、`damage_ledger.json`，见细则（1） | `guard_*`、`p1_*`、`ledger_*` |
| 3 | MODULE_CAP 默认拦、白名单 | 见细则（2） | `cap_*` |
| 4 | 来源分桶 | 见细则（3） | `buckets_*` |
| 5 | 五池明细＋回合预算调用点清单 | 见细则（4） | `pools_*`；下面清单 |
| 6 | 敌人反伤、来源为敌人的 mhp 型状态怎么登记 | 登记两行永久允许（`enemy_reflect`、`enemy_mhp_state`，池＝「敌方」），口径见「需设计稿补记」；守卫只管我方出手（`guard_enemy_skipped`） | `damage_ledger.json` |
| 7 | 总账.py、总账档位.py 并进测算主流程 | 设计仓只读，没改；要改的列在下面 | — |
| 8 | 专项、选测登记、回退开关 | 专项 `tests/xiyou_tianqi_ledger`（40 条断言）；选测对照 `battle_hooks` 冒烟组加 `xiyou_tianqi_ledger.tscn`（核心文件里只加模块钩子行时也跑总账守卫；别的改动按引用自动选中）；四个开关测试里都赋过回退值，优化登记草稿见下 | 本机专项通过 |

## 15 个钩子的乘操作逐号清单

### 实际跑出来的（专项 `LEDGER_DUMP`，卡关时的原始操作，去重）

「情形」：普攻＝技能 1；改写＝在 `skill_rework.json` 里；没改写＝不在表里；派生＝真打时不是这一下所选的招。值是实际算出来的（同一条多个值逗号分开）。类：乘＝落在单独相乘口子上，加＝卡开着会被拦的增伤加。

| 钩子 | 情形 | 字段 | 操作 | 类 | 技能号 | 实际值 |
|---|---|---|---|---|---|---|
| module.raven | 改写 | elementAdd | add | 加 | 10122、10123、10124、10125、10126 | 2.0、2.0002 |
| module.raven | 改写 | settlementMultiplier | mul | 乘 | 10122、10123、10124、10125、10126 | 2.66 |
| module.raven | 改写 | finalAdd | add | 加 | 10122 | 0.0001 |
| module.number_boost | 改写 | settlementMultiplier | mul | 乘 | 10122、10123、10124、10125、10126 | 1.15 |
| module.number_boost | 改写 | criticalAdd | add | 加 | 10140、10141、10142、10143、10146、10148、10149、10150、10151 | 9.99 |
| module.number_boost | 改写 | finalMultiplier | mul | 乘 | 10140、10141、10142、10143、10146、10148、10149、10150、10151 | 7.66 |
| module.number_boost | 没改写 | criticalAdd | add | 加 | 10147 | 9.99 |
| module.number_boost | 没改写 | finalMultiplier | mul | 乘 | 10147 | 7.66 |
| module.yomi_jingliu | 改写 | normalAdd | add | 加 | 10171、10172、10173、10174 | 0.88 |
| module.yomi_jingliu | 改写 | elementAdd | add | 加 | 10171～10174、10187～10193 | 0.77、1.0 |
| module.yomi_jingliu | 改写 | criticalAdd | add | 加 | 10171、10172、10173、10174 | 6.66 |
| module.yomi_jingliu | 改写 | skillMultiplier | mul | 乘 | 10171～10174、10187～10192 | 1.33、2.0、16.55 |
| module.toji | 改写 | skillMultiplier | mul | 乘 | 10216～10223 | 0.2、0.5647、1.5002、4.546 |
| module.toji | 没改写 | skillMultiplier | mul | 乘 | 10224 | 0.5647 |
| module.yunshang | 普攻 | skillMultiplier | mul | 乘 | 1 | 0.3、0.555、0.66 |
| module.yunshang | 改写 | skillMultiplier | mul | 乘 | 10270、10271、10274、10282、10286 | 0.3、0.555、0.66 |
| module.liuying | 改写 | elementAdd | add | 加 | 10622、10623 | 2.0 |
| module.black_flash | 改写 | criticalAdd | add | 加 | 10216、10238 | 1.0 |
| module.tusu | 派生 | finalMultiplier | mul | 乘 | 10313 | 1.2 |
| module.xuan_damage | 改写 | finalMultiplier | mul | 乘 | 103、104（璇宿主队友放的招） | 1.3 |
| module.xuan_damage | 普攻 | finalMultiplier | mul | 乘 | 1 | 1.3 |

上表每一条「乘」都登记得上（`dump_all_registered`）。米拉 `mira_ops`、甚尔 `incoming_ops`、璇 `incoming_ops` 只出承伤和伤害方式，没有乘也没有增伤加。

### 源码里全部的乘／增伤加位置（静态，核查照这张对源码）

跑出来那张受触发条件限制（形态、印记、神器、本次行动的帧），下面是 15 个钩子函数（含它直接调用、本文件里写操作的辅助函数）里所有写乘口子或增伤加的地方。**本轮真打没触发的**：渡鸦 355／356、数字强化 68／73、宿傩 250、黄泉镜流 261／263／519～525、甚尔 305、饿狼 658、云裳 206／211、璇 944、屠苏 324／329／333、流萤 187～210 的乘——它们的字段都在各自那行登记的 `fields` 里，守卫照认；卡开着时一样被 MODULE_CAP 拦（拦法按字段和值，不按触发条件）。

| 钩子 | 位置 | 操作 | 字段 | 值（源码） | 类 |
|---|---|---|---|---|---|
| module.raven | `raven.gd:350` | add | elementAdd | `((2 + p) if tempered else 0.0) + power` | 加 |
| module.raven | `raven.gd:352` | add | normalAdd | `((1.5 + p) if tempered else 0.0) + power` | 加 |
| module.raven | `raven.gd:353` | add | finalAdd | `1.5 * minf(1.0, (stage(a) + p) / 5.0)…＋1.5 * power` | 加 |
| module.raven | `raven.gd:355` | mul | finalMultiplier | `1.1` | 乘 |
| module.raven | `raven.gd:356` | mul | skillMultiplier | `1.6 if artifact_equipped(a) else 1.0` | 乘 |
| module.raven | `raven.gd:357` | mul | settlementMultiplier | `crown_rate(a) * growth_rate(a)` | 乘 |
| module.number_boost | `number_boost.gd:64` | add | criticalAdd | `9.99` | 加 |
| module.number_boost | `number_boost.gd:66` | mul | finalMultiplier | `7.66` | 乘 |
| module.number_boost | `number_boost.gd:68` | mul | settlementMultiplier | `2.0` | 乘 |
| module.number_boost | `number_boost.gd:71` | mul | settlementMultiplier | `1.15` | 乘 |
| module.number_boost | `number_boost.gd:73` | mul | settlementMultiplier | `4.25` | 乘 |
| module.sukuna | `sukuna.gd:250` | mul | settlementMultiplier | `1.5` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:253` | add | normalAdd | `0.88` | 加 |
| module.yomi_jingliu | `yomi_jingliu.gd:255` | add | elementAdd | `0.77` | 加 |
| module.yomi_jingliu | `yomi_jingliu.gd:257` | add | criticalAdd | `6.66` | 加 |
| module.yomi_jingliu | `yomi_jingliu.gd:259` | mul | skillMultiplier | `1.33 if id == 10174 else 16.55` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:261` | mul | skillMultiplier | `1.77` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:263` | mul | skillMultiplier | `spread_rate` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:513` | add | normalAdd | `0.25` | 加 |
| module.yomi_jingliu | `yomi_jingliu.gd:516` | add | elementAdd | `1.0` | 加 |
| module.yomi_jingliu | `yomi_jingliu.gd:519` | mul | skillMultiplier | `2.0` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:521` | mul | skillMultiplier | `2.0` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:523` | mul | skillMultiplier | `1.0666` | 乘 |
| module.yomi_jingliu | `yomi_jingliu.gd:525` | mul | skillMultiplier | `1.1` | 乘 |
| module.toji | `toji.gd:305` | mul | skillMultiplier | `m` | 乘 |
| module.toji | `toji.gd:325` | mul | skillMultiplier | `mult` | 乘 |
| module.garou | `garou.gd:658` | mul | skillMultiplier | `1.0 + e * (evolution_percent + extra) / 100.0` | 乘 |
| module.yunshang | `yunshang.gd:202` | mul | skillMultiplier | `0.555` | 乘 |
| module.yunshang | `yunshang.gd:204` | mul | skillMultiplier | `_spread_rate(a)` | 乘 |
| module.yunshang | `yunshang.gd:206` | mul | settlementMultiplier | `1.99 * glow` | 乘 |
| module.yunshang | `yunshang.gd:211` | mul | skillMultiplier | `derived_frame.rate * glow`（派生伤害） | 乘 |
| module.black_flash | `black_flash.gd:178` | add | criticalAdd | `hit.increment` | 加 |
| module.xuan_cast | `xuan_battle.gd:944` | mul | finalMultiplier | `1.0 / split`（分段，缩小） | 乘 |
| module.xuan_damage | `xuan_battle.gd:584` | mul | finalMultiplier | `1.0 + gongsu_damage_rate(x)` | 乘 |
| module.tusu | `tusu.gd:324` | mul | finalMultiplier | `ARM_ACTIONS / host_actions` | 乘 |
| module.tusu | `tusu.gd:329` | mul | finalMultiplier | `lock_rate(t)` | 乘 |
| module.tusu | `tusu.gd:331` | mul | finalMultiplier | `heming_rate(t)` | 乘 |
| module.tusu | `tusu.gd:333` | mul | finalMultiplier | `_cuoshi[a].rate`（挫势，敌人出手） | 乘 |
| module.liuying | `liuying.gd:184`、`185` | add | elementAdd | `2.0` | 加 |
| module.liuying | `liuying.gd:187` | mul | skillMultiplier | `4.0` | 乘 |
| module.liuying | `liuying.gd:189`、`191`、`195` | add | finalAdd | `2.0`、`3.0`、`lost * 0.01` | 加 |
| module.liuying | `liuying.gd:197`、`199`、`201`、`203`、`206` | mul | skillMultiplier | `5.0`、`1.5`、`single`、`spread_rate`（扩散）、`1 + 0.1 × 印记` | 乘 |
| module.liuying | `liuying.gd:210` | add | finalAdd | `FIREFLY_RATE * firefly` | 加 |

## 回合预算调用点（只列不接，期三用）

| 类（第五节第 2 条） | 位置 | 现在怎么走 |
|---|---|---|
| 初始次数 | `battle/battle_logic.gd:1899` `make_action_times` → `tianqi_skills.gd:738` `cap_actions`；`:1913` 猫 `extra_actions`、战争线 `XTianqiWarAlien.extra_actions` | 回合开始压一次，之后的插队不看它 |
| 昏迷醒来补排 | `battle/battle_logic.gd:1953-1969` `_insert_orders` | 重新按 `make_action_times` 掷，设计稿要改成「2 − 已行动 − 已用预算」 |
| 追加行动（插队） | `tianqi_qiyin_effects.gd:604-607` 七印击倒再动 `push_front`；`gojo.gd:561`；`yomi_jingliu.gd:653`（镜流追加行动）；`tianqi_skills.gd:1388` 技能卡 `free_action` | 直接 `current_order.push_front(u)` |
| 强制行动 | `battle/battle_logic.gd:1496`、`:1704` `_force_action`；`battle/battle_event_runner.gd:512` | 事件预约，原版机制 |
| 再释放 | `tianqi_affix_battle.gd:519-522` 词条再释放；`tianqi_qiyin_effects.gd:597-601` 震印放两次；`battle/battle_event_runner.gd:207`、`:276` 原版公共事件再释放（`_recast_script`／`_push_recast_script`）；`liuying.gd:588-590` 流萤再放 | 直接再打一次 |
| 派生攻击 | `tianqi_qiyin_effects.gd:579`、`589`、`596`、`624`（`_derived`，`:631`）；`toji.gd:475` 武器库追击；`garou.gd:687` 追击／反击；`xuan_battle.gd:834`、`887` `_follow_up`；`yomi_jingliu.gd:598` 追加段；`yunshang.gd:1022`、`1031` 派生伤害；`liuying.gd:595` `_segment`（扩散、额外段）；`tusu.gd:515` `apply_segments` | 各自的次数上限（期三按表补上限） |
| 连击段数 | `actor.gd:1110` `attack_times_add`（词条连击、道法连击）；`raven.gd:421`、`yunshang.gd:242`、`liuying.gd:220`、`cat.gd:429` `repeats`；七印红印流派 `tianqi_qiyin_effects.gd:406` | 算段数 |
| 再动（掷） | `actor.gd:1113` `action_plus_set`（词条、异化、道法分神、饿狼形态 `garou.gd:239`） | 进 `make_action_times` |

## 需设计稿补记

1. **敌人反伤**（co 去 ×6 复核提的）：登记 `enemy_reflect`＝永久允许、池「敌方」。口径：反伤是目标反应把伤害打回出手的我方，数额来自我方这次伤害（已去 ×6、已过五池），属于敌方出伤；不是我方加成，不进五池、不占预算，守卫不判（守卫只管我方出手）。它打到我方身上时照「靶」那一侧（我方承伤、档位承伤）算。技能卡状态反弹 `tianqi_skills.gd _reflect`（敌人伤害 × 比例打回敌人）属于我方出伤，去 ×6 时已按「缩」处理，期二归池时要不要进③由设计稿定。
2. **来源为敌人的按生命上限比例状态**（毒、灼烧、诅咒这类按承受方 mhp% 扣血）：登记 `enemy_mhp_state`＝永久允许、池「敌方」。口径：按承受方生命上限比例，不吃任何加成池，也不跟去 ×6 缩（我方血量没缩）；只在敌方给我方挂时适用，我方给敌人挂的按来源能力算的毒伤已按去 ×6 的「缩」处理。
3. **原版状态确认阶段乘**（设计稿第三节公式「确认阶段状态」一行有、登记表没列）：期一登记成 `state_confirm`（191 个状态号的快照，豁免，暂定期四到期）。要设计稿定：这批（铁头娃 ×1.5、破阵系列、星鹫／阿莫斯／麒麟等坐骑状态……）归哪个池、哪一期改。
4. **天启篇专属模块 `XTianqiModules.damage_ops`**（第七期 tq_ops，卡开着才有，9 个模块的 `finalMultiplier`）：设计稿 C5 只列了 15 个原版钩子。期一登记成 `module.tianqi_modules` 豁免·期四；它不过 MODULE_CAP（本来就是按卡写的）。要设计稿补一句它算「技能卡预算内」（永久允许）还是跟模块一起期四归池。
5. 期一登记里比细则多的四行（`affix_skill`、`skill_pass`、`enemy_race_bonus`、`self_rate`，都是第五节第 1 条期二表里的）：细则只点名了七印、宝珠共鸣、种族，这四处不登记守卫会当场报错，所以按期二表登记成豁免·期二。

## 设计仓要改的（任务第 7 条，协调另派）

设计仓本车道只读。要做的：
- `数值测算/测算.py` `main()`（第 788 行起，现在跑完报告后按需 `import 骑士`、`import 画图`）：报告写完后接着 `import 总账`、`import 总账档位` 各调一次 `main()`，各自把报告写到 `结果/总账报告.md`、`结果/总账档位报告.md`；加一个开关（如 `--no-ledger`）可跳过，两者共约 45 秒。
- `总账.py`、`总账档位.py` 现在各自 `import 测算` 再自己读参数：并进主流程后改成接收 `测算.main` 已算好的 `M, P, rows, ref, gears`（`总账.ledger`、`总账档位.main` 入口加参数，单独跑时照旧自己算），避免同一份测算跑三遍。
- `README.md`「怎么用」一节补一句：`python3 测算.py` 默认连总账两份报告一起出。
- 总账参数里「证道完美目标回合 8」等旧标尺照设计稿第十节，等 D24 定了随四骑士数值稿 v0.6 一起改，本步不动。

## 变更记录草稿

## 2026-11-15 【cc·伤害加成总账期一·未经审查】天启篇伤害加成总账入口：总账表与守卫、模块增伤默认拦、来源分桶、五池明细（不改数）（dev.待定）

- 设计仓《天启篇_伤害加成总账_v0.4》第八节期一：新 `XTianqiLedger`＋`tianqi_data/damage_ledger.json`，每个「乘」一行（已归池／豁免·有到期／永久允许）；天启篇我方出手时守卫逐条认来源，没登记的新乘区当场报错（只记不改数）。期一登记：七印、宝珠共鸣、种族、词条技能伤、技能专属被动、对某族增伤、独立乘区豁免·期二；15 个专属模块钩子、猫、天启篇专属模块、原版状态确认阶段乘豁免·期四。
- MODULE_CAP 改成「技能卡开着就默认拦，白名单才放」：普攻、没改写的技能、派生一样拦，白名单期初为空（卡开关默认仍关，数值不变）。
- 被动缓存与装备元素增幅并排存一份按来源分桶的数（秘籍格、符文之语、宝珠、原版装备、种族、成长装备、天启篇自己的……），原合计不动；伤害详情加五池明细。
- 15 个专属模块钩子在普攻／没改写／派生下的乘操作逐号清单、回合预算调用点清单见交付单。
- 西游档不变：守卫、分桶、明细都只在天启篇档；`damage.gd`、`actor.gd`、`actor_damage_hooks.gd` 只加不改。
- 验证：专项 `xiyou_tianqi_ledger`（新）、相关战斗专项 19 个本机通过；`--oracle` 云端选测见交付单「验证」。
- 提交：（合并时填）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定-1 | `modes/xiyou/core/tianqi_ledger.gd` `XTianqiLedger.GUARD`、`audit`；`damage.gd` `_calculate`；`actor_damage_hooks.gd` `capture`（tags） | （天启篇）单独相乘的增伤谁都能新开，没有登记 | 天启篇档我方出手时按 `damage_ledger.json` 认来源，没登记／已归池／豁免到期就报错（只记不改数） | 伤害加成总账期一（设计稿第八节细则（1）） | `XTianqiLedger.GUARD = false`（不认、不报） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_ledger.gd` `XTianqiLedger.BUCKETS`、`passive_buckets`；`actor.gd` `_refresh_passive_now` | （天启篇）被动缓存只存合计，分不出来源 | 天启篇档并排多存 `bySource`，原合计不动 | 期一细则（3），期三九线封顶要用 | `XTianqiLedger.BUCKETS = false`（不建分桶） | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/tianqi_ledger.gd` `XTianqiLedger.DETAIL`、`pools`；`damage.gd` `_calculate` | （天启篇）伤害详情没有五池明细 | 天启篇档伤害详情每一行多 `pools`、`residual` | 期一细则（4） | `XTianqiLedger.DETAIL = false`（不加明细） | cc | 保留 |
| O-待定-4 | `modes/xiyou/core/tianqi_skills.gd` `XTianqiSkills.MODULE_CAP_ALL`、`module_ops`；`damage_ledger.json` `module_whitelist` | （天启篇，技能卡开着时）MODULE_CAP 只拦改写表里的技能，普攻、没改写的、派生漏 | 卡开着就默认拦专属模块的增伤，白名单才放 | 期一细则（2）、co 评审第 5 条 | `XTianqiSkills.MODULE_CAP_ALL = false`（回到只拦改写过的技能） | cc | 保留 |

## 交接板

- 下一步：伤害加成总账期二「归池清场」（设计稿第八节；先二后三）；期二开工时把 `damage_ledger.json` 里到期的行改成 `pooled`。上面「需设计稿补记」五条请设计稿补记（第 3、4 条要定归哪一期）；设计仓测算主流程合并（任务第 7 条）另派。
- 用户试玩说明：无（玩家看不到变化）。
- 需要用户决定：无。

## 进度账

- 天启篇数值线第 3 步（伤害加成总账）：期一完成，期二～四待做。

## 可优化（流程／工具／效率）

- 建议：逐号清单的真打只触发了一部分模块条件（形态、印记、神器、本次行动帧），期四专属模块到期前可以给每个模块补一个「把条件全开」的夹具（各模块专项里已有布置法），让 `LEDGER_DUMP` 覆盖静态表里每一行（预计半天，归 cc 车道，配 Sonnet＋medium）。

## 验证

（待写）

## 待交叉核查

- 甲档（co）：本分支全部提交。改到的原沙僧核心文件：`damage.gd`（守卫调用、五池明细、`_independent` 挪出 `_self_rates`）、`actor.gd`（被动缓存分桶、记忆多认一条）、`actor_damage_hooks.gd`（分段算、tags、专项记录口）；另 `tianqi_skills.gd` `module_ops`。请照「逐号清单」两张表对源码，重点看：分段拼接和原来一行相加是否逐项相同、MODULE_CAP 分段过滤与整段是否等价、西游档返回值和 main 是否一样。

## 本分支提交

- 7d5bc63ba WIP：总账表与守卫、MODULE_CAP 默认拦、来源分桶、五池明细、专项
