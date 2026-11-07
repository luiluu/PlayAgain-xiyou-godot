# 交付：cc/rules-newsrc1

- 车道／工作者：C 规则／rules（cc）
- 状态：第二轮已交付（待 Codex 核查；合回集成分支，不合 main）
- 基于集成分支 `cc/newsrc-switch`（cc69f998），交付合回集成分支，**不合 main、不标可合并给 main**。工作树里冻结正式源链接指向 `v0.62.12/app.nw`，转换产物与导入缓存克隆自集成分支工作树（新源产物）。

## 结论：「成长乘区 growth」初判不对

本机重跑 `xiyou_rules`（d1 第 0 份）复现云端 49142/61678。看样本后发现 `xiyou_rules` 本来就按「MV 值 ÷ growth」比较（测试头注释写着首期不移植 growth），growth 不是失败原因。实际是新源（v0.29～v0.62.12）在伤害链上的四处改动 Godot 没跟：

1. **百分比穿透也穿元素抗性**（`installDamageElementRuntime` `applyResistancePierce`）：攻击方被动缓存 `penetrateHarmRe.percent`（`<DepassiveHarmReXX: N%>`）按元素作用于目标 elementRate：0～1 之间 `1-(1-r)(1-通用穿透)(1-元素穿透)`；完全免疫（0）只有该元素穿透 ≥100% 才变 1；吸收不变。固定减伤穿透照旧。`dsPassiveSkill parseDepassiveHarmRe` 同时改成带正负号、同一对象内完全相同的标签只计一次。云端「d1 抗性 1.0≠0.8」就是这条。
2. **导入角色平衡解除**（`installImportedBalanceRuntime` v0.29／v0.36）：`outgoingRate` 恒 1（结算与持续伤害都不再 ×0.01／×0.001），共用伤害技能公式不再 ÷10；禁用名单扩成角色 141、143、144、145、146、152、157、160、161、166，号角 245、255、256、257、274、359、394、440、456、494。
3. **属性转换攻守分算**（`conversionId`／`originalElements`）：被动 `<DamageElements>` 转换时，目标侧（抗性、克制、固定减伤）按转换后属性，攻击方增伤、固定附加、独立乘区按技能原属性，多候选取最高；治疗的属性增伤改看原属性。
4. **反击概率夹 0～1**（引擎核心 `rpg_οbjects.js` v0.35 `cnt` getter）：`XBattler.cnt` 夹到 0～1，`xparam(6)` 本身不夹；`xiyou_rules` 的能力值快照第 6 项改读 `cnt`（参照 slice_probe 读的就是 `b.cnt`）。

结果：`xiyou_rules`（d1 第 0 份）49142/61678 → 61678/61678（先 61677，剩敌人 745 反击率 10 对 1，第 4 条修掉）。

## 改了哪些原沙僧核心文件（请沙僧重点核）

- `modes/xiyou/core/damage.gd`：`_resistance_pierce_by_element`、`apply_resistance_pierce`、`conversion_id`、`original_elements`；伤害循环改成「目标属性 × 原属性」两层；`_healing` 用原属性。
- `modes/xiyou/core/actor.gd` `refresh_passive`：穿透标签带正负号、同对象去重。
- `modes/xiyou/core/battler.gd` `cnt`。
- `modes/xiyou/core/imported_balance.gd`：倍率、÷10、禁用名单。
- 第二轮：`modes/xiyou/core/shield_ledger.gd`（`ACTOR_HP_LEDGER`、`hp_gain`）、`core/resource_context.gd`（gainHp／setHp 两处改调 `hp_gain`）、`battle/battle_logic.gd`（`_push_rows`、`sequence_gain`、`_regenerate` 一处）、`core/actor.gd`（10455）。

## 验证

- `语法检查.py` 通过。
- `xiyou_rules`：61678/61678（本机，新源产物，`--skip-generated-check`：本树产物克隆自集成分支，跟主工作区旧源产物本来就不同）。
- 云端（运行 42193458592，提交 c35a3d00 之上的交付单 WIP 提交，产物快照 `refs/ci/generated/cc/rules-newsrc1`＝集成分支新源产物）跑 69 个场景：**`xiyou_rules`～`xiyou_rules_d6*` 全部 64 片通过**，`xiyou_multi_element` 通过。没过的 4 个都不是本单改坏的，见下：
  - `xiyou_rules10` 86/90：`floor.2521.false.1/5/10`（开关关时隐月 2521 暴击率 Godot 0.21／0.29／0.39，参照 0.19）与 `floor.2521.db_untouched`。即派单说的「rules10 那 4 项」，样本已拿到，没修（留下一单，见「没做」）。
  - `xiyou_imported_balance` 224/230：6 项都是 141 的持续伤害例（`dot.a141.*`、`dot.rec.a141.*`）。参照里 hrg 为 0、HP 不掉：新源 141 进了禁用名单，它的行动对目标无效，中毒根本挂不上；测试是按夹具直接给 Godot 挂状态再重放，所以 Godot 照常掉血。要改测试（禁用角色的 DOT 例按「挂不上」比，或探针换一个未禁用的导入角色），不是倍率问题。
  - `xiyou_item_use` 11/12：`ce_items_count` 1037≠1029，测试里写死的公共事件物品数，新源多了 8 件（内容数量变化，改断言即可）。
  - `xiyou_module_hooks` 1309/1311：`view.same_source`、`oracle.native_registry`，来源身份夹具还是旧源（同集成分支表一的「只挂 source」一类），要在新源上重出夹具。

## rules10

（第二轮更正）上面的初判不对：不是层数口径，是新源把 2521 的数据改成了 +2%，见第二轮表。

## 第二轮（CM 补 8 项＋上轮遗留 4 项，基于集成分支 31d0628a）

| 项 | 结论 | 改了什么 |
|---|---|---|
| power_books／_boundary／_menu、book_capacity | 新源 `installIntegratedV029Runtime` 的 `Game_Actor.setup` 包装：开放专武（武器备注 `<req_actors>` 列着、角色有名字且不在停用名单）的所属角色开局学 10455「专武·特效吸取」；`installBalanceShopV041Runtime` 的 `skills()` 包装在背包和全体角色身上都没有本人开放专武时不列 | `actor.gd`：`AFFIX_ABSORB_SKILL`、`absorb_owners`、`is_absorb_actor`、`has_absorb_weapon`，`setup` 末尾学、`skills()` 过滤。顺带修好 actor_p0 的 passive_104／163、skills_104 |
| passive_content（书 1652／2237 +3.75%） | 合并第一轮（growth 等）后本机重跑已全过（113142/113142），不用另改 | 无 |
| battle_gaps | 新源多 10462 诛天（`<MP Cost: 15%>`），百分比 MP 技能 43→44，这 5 例本身都过 | 测试计数 44、cost 44×5+2 |
| pushstate 6706 | 新源 v0.62.02：治疗（结算值为负）时 recPushStates 只给行动者友方（`target.isActor()===subject.isActor()`），打吸收属性回血的敌人不挂也不掷 | `battle_logic.gd` `_push_rows` |
| xuan_auto 力壁 | **新源原版代码错误**：流萤运行时（模块序 33）在 `Game_Actor.prototype` 上自定义 `setHp`，捕获的是护盾账本（序 41）包装前的函数；krz 的 `Game_Actor.gainHp` 也捕获插件期原函数。角色的 gainHp／setHp 两条都绕过账本：行动序列 HP -x%、持续伤害、直接设生命不扣璃壁等期限护盾，原生 ShieldSystem 读到子类 getter 的合计、按合计白挡、只扣原生那份（同 O-144 的白挡）。executeHpDamage 和敌人不受影响 | 可撤回开关 **O-待定·角色HP包装** `XShieldLedger.ACTOR_HP_LEDGER`（默认 true 照旧源经账本；false 照新源）。`shield_ledger.gd` `hp_gain`，gainHp／setHp 四个入口改调它。xuan_auto 比参照时设 false，另加 `_check_actor_hp_ledger` 三例自查默认支（值取旧源 v0.28 参照）。登记状态「待用户确认」 |
| imported_balance 141 DOT 6 项 | 141 进停用名单，参照里 141 的行动（applyItem）附加不上中毒；测试原来直接给 Godot 挂状态 | 测试：禁用角色作附加者时改查 `blocks` 并跳过挂状态 |
| item_use | 新源公共事件物品 1029→1037（数据实数，新源 Items.json 数出来 1037） | 测试计数 |
| rules10 2521 关闭支 | 不是层数问题：新源 2521 的数据本身已从 +0.2% 改成 +2%，O-181 的回退支（读数据库）现在也是 +2% | 测试两支都按 +2%、`db_untouched` 改 0.02；O-181 登记注明两支同值、可考虑退役 |
| module_hooks | `oracle.native_registry`：新源钩子表 11 位多了 liuying，orb-sets 19→20；`view.same_source`：`module_equipment_view.json` 六档 elementBonus 跟新源 cat.json `stats.sword671` 逐项相同，只换 runtimeInputs | 测试下标、夹具来源 |
| 云端带出的 2 个（改动前过、改后挂） | `actor_change`、`party_skills` 的夹具还是 v0.28（没有 10455，不查来源所以以前一直过）。用 `XIYOU_APP=…/v0.62.12/app.nw` 在本树重跑 `actor_change_probe.cjs`、`party_skills_probe.cjs` 重出：actor_change 只差 10455；party_skills 另有新源 v0.29 `Star_SkilsShare` 的新提示「光环生效：…」（前 4 个名字、多了加「等 N 项」，不以「技能共享：」开头，V019 的吞提示拦不住，原版两条都弹）、羁绊技能 ID 从字符串变整数（测试本来就归一） | 两份夹具重出；`skill_share.gd` 补「光环生效」提示 |
| 顺带 | actor_p0 的 recruit_141／146／152／161／166：新源这 5 人进停用名单（V029 hiddenActors），重制 `add_actor` 本来就拦停用角色，测试改成「不入队」；raven_reflect 的 0.002 写死改读数据库 | 测试 |

### 验证（本机，新源产物，`--skip-generated-check`）

- `语法检查.py` 通过。
- 目标 11 个场景（power_books×3、book_capacity、passive_content、xuan_auto、battle_gaps、pushstate、imported_balance、item_use、rules10）＋ module_hooks、shield_ledger、item_bag、xuan_bind 全过。
- actor_p0 剩 1 项 `horn_paths_all_covered`（伙伴号角：流萤 3063，新角色流萤没移植，A 内容）。
- 改前改后同样失败、不是本单造成的：`xuan_battle`（source＋cleanse.hard／soft）、`book_capacity_ui`（source）、`raven_reflect`（reffloor 5 项）：三份夹具都还是 v0.28，要在新源上重出（工具／哪吒）；raven_reflect 重出后 0.002 那处已改读数据库。
- `事件空绿扫描.py --check`：退出 1、4739 条 ✗，跟改动前（stash 后同命令）输出逐字相同；全是 event_states 产物与预设对不上（本树产物克隆自集成分支），本单没碰事件。
- 之后 merge 集成分支 1eae323d（哪吒 newsrc2 新夹具），合并提交 62388d6c；冲突两处（item_use 计数注释、module_equipment_view.json）都取集成分支版（夹具改用哪吒重出的 cat_probe 版，内容同）。合并后本机重跑 module_hooks、xuan_battle、book_capacity_ui、item_use、xuan_auto、power_books、imported_balance 全过；actor_p0 只剩流萤号角 1 项；raven_reflect 夹具仍是 v0.28，reffloor 5 项待重出。
- 云端：fdde72b1（合并前）跑选测 310 个场景（运行 42199064992）：72 个失败。对比改动前：66 个在集成分支各交付单的失败表里；另 6 个（actor_change、party_skills、qiyu、vsfx、weapon_unleash 和本机复查的 guyu_battle 等）本机把四个核心文件换回 31d0628a 版重跑，只有 actor_change、party_skills 是本单带出来的（已修，见表），qiyu（state2626 两项）、vsfx、weapon_unleash、guyu_battle（revive 两项）、life_steal、state_effects、honghuang_curse 改前改后一样挂，不归本单。

## CW「角色技能」18 个场景（第三轮，基于集成分支 34d486ad）

本机先跑一遍（新源产物，`--skip-generated-check`），日志样本如下。**已过 3 个**：attack_element、attack_query、cat（第二轮之后本来就过，不用改）。其余 15 个初步分类：

| 场景 | 失败 | 样本 | 初判分类 |
|---|---|---|---|
| action_sequence | 1/117 | `conditions_translated ["user.hp < user.mhp * N.N"]` | 新写法没翻译（派单已知） |
| actor_advanced | 1/33 | `rows_count 490` | 计数断言（数据量变化），先核来源再改 |
| custom_params | 2/160 | `covers_aliases [atk,mat,maxhp,maxmp,def,mdf,luk,agi,tp]`、`converter_all_parsed [274,[]]` | 新源自定义参数写法多了别名 → 要翻译 |
| element_ternary、formulas | 2+2 | `ternary_10020_* [null,null,…]`（10020 三元公式取值空、大数超 64 位） | 新写法没翻译／公式求值（派单已知） |
| param_states、nanoha | 15、1 | 1768「杀敌加属性」：目标 hp0 的 conclude 原版 +10/+30，Godot 0（新源 1768 备注 271→381 字，改了条件）；param_states 另有 `source`（夹具旧） | 状态 JS 新写法没跟 |
| state_effects | 1097/30129 | 集中在几个状态：2558（value×0.9→×0）234、2561（×0.91→×0.1）195、1451 108、1726 87、2583 12、effect.row 200、revive.row 16＋1725 不朽1 复活条件改写（`hp<=0 && random>0.6` → `(hp<=0‖isDead()) && random<0.6`）、hook.turn_start 1714≠1713、fix.tiers 1716/1711、hook.weapon、fix.2575 | 新源改了这些状态的 Custom Effect 备注，产物数据已是新的（generated/db/States.json 2558 已是 ×0），Godot 结果还是旧值 → 先查状态 JS 的翻译是从哪份缓存／手写表来的，多半一处根因 |
| state_effects_tp | 2/544 | `inventory.costume_0 8`、`inventory.untranslated_46 77` | 未翻译清单计数（随新源变），要看是不是新写法 |
| state_overlay | 1/18 | `overlay_states_84 85` | 计数（新源多一个叠加状态） |
| life_steal | 5/341 | `source`；2570 急速冷却 `<DBHPLSteal:8%>`→`80%` 等 4 项 | 夹具旧（source）＋新源数据数值（重出夹具后再看） |
| qiyu | 2/231 | `state2626.a164／a162` 原版不挂 2626 | 新源机制（琦玉相关），要查 |
| skill_mastery | 2/306 | `table.count 6983≠6804`；10169、10457、10463…首项 0≠100000 | 新源熟练度表新增技能＋首项口径 |
| guyu_battle | 2/1637 | `script.sub.6.revive.party` 原版复活到满血，Godot 0 | 新源复活口径（可能与 1725 同源） |
| wtype | 1/17367 | `native_cache_source null` | 夹具来源旧 → 重出 |

新机制（要实现的）明显超过 3 个：三元公式／大数、自定义参数别名、行动序列条件写法、1768 conclude、state_effects 一批状态备注、1725 复活、2626、熟练度表。按派单先报计划，**还没动代码**。

### ① state_effects 根因（只查不改，归工具车道）

转换器 `03_转换工具/xiyou_export.py` 的 `parse_state_effects` 只认「原版实测过」的固定写法：`MEASURED_VALUE_BLOCKS`（按 v0.28 的整段 token 序列逐字匹配）、`revive_state_effect`、`permanent_state_effect`、`constant_bonus_effect` 等。新源改了这些状态 Custom Effect 的写法（数值或条件），整段对不上白名单，就落到 `op: js`（「尚未翻译」，运行时只记诊断、不生效），Godot 结果停在原值。例：2558 蝶引来生 v0.28 `value * 0.9` → 新源 `value * 0`、1725 不朽1 复活条件 `hp <= 0 && Math.random() > 0.6 ‖ …` → `(hp <= 0 ‖ isDead()) && Math.random() < 0.6`。

本机用转换器函数对新旧两份 States.json 逐条比：新源比旧源多出 `op: js` 的有 34 个状态。
- 改写的 19 个（正好覆盖 state_effects 的失败，以及 param_states／nanoha 的 1768、guyu_battle 的复活）：1061 混元护体（react）、1431 巡猎1（turn_start）、1450 智识1（establish）、1451 存护1（react）、1711 秩序0（turn_start）、1714 秩序3（confirm）、1716 同谐0（turn_start）、1725 不朽1（deselect）、1726 不朽2（confirm）、1731 均衡（confirm）、1768 杀敌加属性（conclude）、2544 剑终伤（confirm）、2545 太刀终伤（confirm）、2558 蝶引来生（react）、2559 血梅香（confirm）、2561 减伤90%（react）、2574 非天逆斩（apply）、2575 剑道争锋（confirm）、2583 雷道之威（confirm）
- 新源新增、本来就没翻译的 15 个：2720 舍身剑·燃血、2721 凝气成罡、2723 用剑终伤+150%、2724 诛仙剑主、2747 全知全能、2748 全知全能 -1、2750 全知全能-2、2751 全知全能-3、2771 超赛1、2772 超赛2、2773 超赛3、2774 超蓝、2775 自在极意功、2776 自我极意功、2777 自我终伤

处理：要在转换器里把这 19 个新写法加进白名单／模式，并按「实测过才收」的规矩补量具（state_effect 探针重出），属于工具车道（总装 11-06 定，本车道不改转换器）。新增的 15 个是新内容，另排。转换器改完、产物重出之后，本车道再跑 state_effects、param_states、nanoha、guyu_battle 看剩余。

### 第三轮进度（到 40% 线停手时）

已做（本车道 Godot 侧，均本机跑过）：
- action_sequence：`action_sequence.gd` `_atom` 补 `user.hp < user.mhp * 0.5` 这类「能力值 比较 能力值×常数」写法（新源舍身剑等），按 double 算 → 117/117。
- element_ternary：新源把 10020 爱之惩罚改写成 `(a.atk*588000+a.luk*588000)*(b.hpRate()<.25?3:1)*(1+熟练度*.13)`，没有 formulaGd（战斗走 formulaProgram，pure），v0.28 量值不再适用；夹具是旧源实测不改，这两例改成确认新公式、跳过 → 33/33。
- formulas：10020 两例换成仍是 hp 三元的 3512 → 7/7 全过，**但日志有两条 ERROR**（见下「大数」），并行测试按 ERROR 判失败。
- actor_advanced：进阶表新源 485 行＋渡鸦 5 行＝490（v0.28 462＋5）→ 计数改 490。
- state_overlay：新源多 2763 致命诱惑一个叠加状态（84→85，用 node 对新旧 States.json 数过），测试改「夹具 +1 且 2763 有 overlay」。
- custom_params：`converter_all_parsed` 新源 274 件（数过 274）。

归工具车道（本车道不改转换器／探针）：
- **① state_effects 根因**（见上节，19＋15 个状态）。连带：state_effects_tp 的 `inventory.costume_0 8`（新增 2771～2774 超赛的 apply/remove 换装块没走模板）和 `untranslated_46 77`、param_states／nanoha 的 1768、guyu_battle 复活，都等转换器补完重出产物再看。
- **② 大数**：原版 10037 死神领域、10060 作者之力 的公式是整数字面量 `99999999999999999999999`／`9999…`（41 位）。JS 里这是 double（1e23／1e41），**不是 BigInt**；转换器的 formulaProgram 已经存成 double（1e+23），战斗算对。只有旧式 formulaGd 原样抄了整数字面量，Godot Expression 解析时报「Cannot represent … as a 64-bit signed integer」。要转换器在 formulaGd 里把超过 int64 的整数字面量写成浮点（如 `1e+23`），照 double 精度。
- **custom_params `covers_aliases`**：探针 `custom_params_probe.cjs` 的 `mhp_mmp_eight` 挑的 1925／2019／2020／2021 在新源改成 `atk += …; mat += …`（KYO专武成长），不再有 mhp／mmp；新源还有 mhp／mmp 的是防具 129、4472、4473、4476…（20 件）。要改探针 PICKS 重出 generated/oracle/custom_params.json。Godot 对 `+=` 的结果逐行都对上了。

还没做（下一位接着）：
- life_steal（`source` 夹具旧；2570 急速冷却 `<DBHPLSteal:8%>`→`80%`，夹具重出后再看是否只剩数值）、wtype（`native_cache_source` 夹具来源）、param_states 的 `source`：先看有没有探针，能像 actor_change 那样 `XIYOU_APP=…/v0.62.12/app.nw node <探针>` 在本树重出就重出，重出不了的报工具。
- qiyu `state2626.a164／a162`（新源不挂 2626 欢迎来到异次元，状态备注没变，要查挂的入口）。
- skill_mastery `table.count 6983≠6804`、新技能 10169／10457／10463… 首项 0≠100000。
- 最后做改前改后对比（像第二轮那样，四个改过的文件换回基线重跑）。

建议顺序：① state_effects 先找翻译缓存根因（一处修好可能连带 param_states、nanoha、guyu_battle）；② 公式三元／大数（element_ternary、formulas）；③ action_sequence 条件、custom_params 别名；④ 计数类与夹具重出（actor_advanced、state_overlay、state_effects_tp、life_steal、wtype、param_states source）；⑤ qiyu 2626、skill_mastery 表。

## 接续

- 第二轮已合进集成分支（34d486ad）。第三轮 CW 只做了分类，见上节；下一位从「建议顺序」①开始。日志样本在本机 scratchpad，不进库，重跑一遍 18 个场景即可拿到。

## 没做、留给下一单

- C 规则另 43 个场景（派单说下一单）。其中会被本单影响、要一起看的：`difficulty_troop`／`difficulty_enemy`／`difficulty_actor` 三个探针也读 `b.cnt`，Godot 那边的快照若用 `xparam(6)`，反击率大于 1 的敌人会差；`imported_balance_probe` 的参照要在新源上重出（倍率全 1）。
- 引擎核心 v0.35 另一处：`rpg_managеrs.js` 反击「先承伤后返回实际受击者」（`invokeCounterAttack` 返回 realTarget），本单没碰 `battle_logic.gd` 反击段。
- `CodexImportedEffects` revision 2（恢复 12.27 缩减的专属效果系数）：重制本来就没移植效果补丁，数据直接用库里的，不受影响；`CodexPierceV058` 是旧档迁移，重制不迁移 MV 旧存档。
- 诛仙 162 同源被动只留最高档（v0.08）新源已删，重制原本就没移植，不用动。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源伤害规则追平：穿透打抗性、导入角色解除缩放、属性转换攻守分算、反击概率封顶（dev.待定）

见本交付单「结论」四条；`xiyou_rules` d1 第 0 份 49142 → 61678/61678。云端集成分支 189 失败表里 rules 那行「成长乘区」的初判更正为上面四条。核查：待 Codex。

## 2026-11-06 【cc·rules·未经审查】新源补单：专武·特效吸取开局学、治疗挂状态只给友方、角色掉血绕过护盾账本做成可撤回开关 O-待定·角色HP包装（dev.待定）

见本交付单「第二轮」表。O-待定·角色HP包装 待 Kyo 确认（默认照旧源：角色持续伤害／行动序列扣血先扣璃壁等护盾）。核查：待 Codex。

## 交接板

- 下一步：见「接续」。
- 用户试玩说明：新源口径下，穿透装备／被动对有抗性的敌人更有效；导入角色（141～166）伤害不再被压到 1%；停用角色多了 5 个。
- 需要用户决定：O-待定·角色HP包装（新源里角色的持续伤害、行动序列按比例扣血、直接设生命绕过了璇的璃壁等护盾，看起来是流萤更新的装载次序副作用；重制默认保留「护盾照挡」，开关可回原版）

## 进度账

- 无（集成分支追平，不改进度）

## 可优化（流程／工具／效率）

- 建议：`xiyou_rules` 失败只打印前 12 条，按角色归类要临时改测试；加个环境变量（如 `RULES_DUMP=<路径>`）把全部不符写成 JSON，省一轮手改（C 规则车道，小）。
- 建议：`云端选测.py` 的 `--scenes` 只认带 `.tscn` 的名字，不带时静默变成 0 个场景、运行显示成功；改成自动补后缀或空选时报错（工具／哪吒，小）。
- 建议：集成分支的 189 失败表初判按日志前几条样本写，rules 这行就判错了方向；以后初判最好标「未在本机重跑」并附一条样本的分项对比（已在表头注明过，这里再提一次）。

- 建议：`has_absorb_weapon` 每次 `skills()` 都扫背包和全体角色装备（只对学了 10455 的角色），原版按背包修订号缓存；背包很大时可加同样的缓存（rules，小）。
- 建议：`事件空绿扫描.py --check` 在工作树里因 event_states 产物克隆自集成分支恒报 4739 条，车道交付时只能比对改前改后；可加 `--baseline <文件>` 只报新增（工具，小）。

## 本分支提交

- c35a3d00 rules 新源追平：穿透作用于元素抗性、导入角色解除缩放与禁用名单更新、属性转换攻守分算、反击概率夹 0～1
- fdde72b1 rules 新源补单：10455、RecPushState 只给友方、O-待定·角色HP包装 角色掉血绕过护盾账本、测试口径与来源夹具
