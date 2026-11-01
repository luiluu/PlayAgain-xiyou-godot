# 交付：cc/bailong-tusu2

- 车道／工作者：E 角色专属／白龙_14（cc）
- 状态：可合并
- 分支从 cc/bailong-tusu1 末端 98484670 切出（链式交付，**包含 tusu1 与 cat-trial1**，那两张交付单照它们自己的合），开工后合过 main 5692e099（第八批）。
- 范围：屠苏、璇二期——来源护盾账本抽成公用、形态绑定框架（只有框架与数据层；屠苏、璇自己的种类三期起登记）。画面层不做。

## 变更记录草稿

## 2026-11-01 【cc·白龙_14·未经审查】屠苏、璇二期：公用护盾账本与形态绑定框架（dev.待定）

1. **公用护盾账本**（installSourceShieldLedgerRuntime.js，138 行）：新模块 `XShieldLedger`，谷雨一期起那份只认 guyu.shield 的账本抽出来，谁都能记。
   - grant：只在战斗中；量×(1＋护盾效果加成，noBonus 不加)向下取整；同源取较高、期限取较晚；期限按自然回合（含施加回合）；opts 有 noDecay、noHalve、noBonus、skip。
   - 吸收：executeHpDamage、gainHp、setHp 三处最外层；到期早的先扣；有非 noHalve 的行挡下过、还有剩余且原生护盾为 0 时剩余减半一次（原生护盾还有就交给它减半）；挡下后通知谷雨（先许一枝开强化）。
   - 种族伤害 absorbRaceDamage：账本静默先扣，再原生护盾。
   - 自然回合末撤销到期、其余不带 noDecay 的衰减 floor(×decayRate)；开战、结束、读档清空。
   - 谷雨改调它（花荫、护盾合计、先许一枝开）；种族毒鸡汤／残响、再生扣血、行动序列扣血三处原来只过原生护盾，现在照原版先过账本（原版这三处都经 setHp 包装）。
   - 重制差异照旧：账本不并进 b.shield，护盾栏读合计。
2. **形态绑定框架**（installNativeBindingChargeRuntime.js 1～282）：新模块 `XBinding`，角色模块用 register 登记种类。
   - canHost、defaultHost、bind（转移）、unbind（各原因）、spend／gain、状态同步（形态状态、充能耗尽状态）。
   - 自然回合开始把行动次数转为充能（不能动 0、manual 0）；回合末有充能交给 onRoundEnd、onRoundClose 后清零；回归当回合每次行动扣 1 点。
   - 行动前后 validate：本体或宿主阵亡、离场就解除。
   - 敌方不可命中：makeTargets 滤掉、randomTarget 抽到就换人、apply 整次不生效。
   - 战斗结束、读档清理。
   - 原版这份数据只在战斗内、读档时清空，所以没有要存档的字段。
   - 不移植：敌方行动期间拦脚本扣血与加状态（原版这两层挂在 Game_Battler 上，角色的 gainHp／addState 被 Game_Actor 自己的方法接管，对角色不起作用，参照里实测扣血、加状态都照常生效；重制照原版不拦）；开战默认绑定（原版算了不绑）；指令窗「攻击」换名、器谱／星谱菜单（画面）；内部施放 cast（三期随屠苏支援做）；超强者名单标签（两人数据没有）；伙伴号角上架（招募期）。
- 钩子各一行：`battle_logic.gd`（setup、start_turn、end_turn、act 的 startAction 两处与 endAction、targets_for、_random_target、apply、end_battle）、`resource_context.gd`（gain、set_resource 换成账本）、`race_battle.gd`（settled_damage）、`xstate.gd`（读档两行）。
- 参照：新探针 `mv_oracle/shield_ledger_probe.cjs`（真实 CodexShieldLedger，不打战斗）、`mv_oracle/binding_probe.cjs`（登记参照种类 probe、真实 BattleManager）；都不进同步，产物拷成 `tests/fixtures/shield_ledger_oracle.json`、`tests/fixtures/binding_oracle.json`。新专项 `xiyou_shield_ledger`、`xiyou_binding`。

## 优化登记草稿

| O-待定 | 护盾账本跳过的行（`core/shield_ledger.gd` hp，installSourceShieldLedgerRuntime 的 skip 与 shield getter） | 账本行的量经子类 getter 并进 b.shield；被 skip 跳过的行还留着量，后面 ShieldSystem 按合计「吸收」、却只扣原生那份，跳过的行白挡一份伤害、自己不少（谷雨付生命费用时花荫还在就是这样，参照 shield_ledger_probe skip 例：挡下 75、生命不动） | 跳过的行不替角色挡伤害 | skip 本意是这时不吸收；白挡是 getter 合计与原生扣减对不上的副作用 | `XShieldLedger.o_skip_unshielded = false`（照原版白挡） | cc（白龙_14） | 待用户确认 |

## 验证

- 专项 xiyou_shield_ledger 138/138：参照 9 个步骤例逐步比（加成、同源、吸收顺序、原生护盾分工、noHalve、skip、回合末、种族、撤销），参数、战斗外、开战／结束／读档清空；开关回退值比参照，默认值另比 skip 例。
- 专项 xiyou_binding 291/291：参照 8 个例逐步比（宿主规则、充能、回归、离场阵亡、不可命中、直接调 randomTarget／apply、敌方行动期间、结束清理），比返回值、事件、命中、四人绑定数据与状态、回合、出战成员。
- 反向验证：账本 17 处、绑定 22 处全咬住（见下「反向验证」）。
- 语法检查通过；探针登记检查通过。补 direct 例后 xiyou_binding 单跑 291/291（只改了探针与专项）。
- 选测（全名）32 个全过：xiyou_action_sequence、xiyou_alien_battle、xiyou_attack_query、xiyou_autosave、xiyou_battle、xiyou_battle_gaps、xiyou_battle_log、xiyou_binding、xiyou_boss_lifecycle、xiyou_cat_trial、xiyou_determinism、xiyou_event_compare、xiyou_garou_battle、xiyou_guyu、xiyou_guyu_battle、xiyou_guyu_ui、xiyou_jingliu、xiyou_mira_battle、xiyou_otb、xiyou_race_battle、xiyou_raven_battle、xiyou_rules、xiyou_rules_d3、xiyou_save_events、xiyou_shield、xiyou_shield_ledger、xiyou_smart_ai、xiyou_state_js、xiyou_three_growth、xiyou_toji_battle、xiyou_tusu、xiyou_yunshang。`选测.py main --list` 因链上带着 tusu1 的 actor／battle_logic／xsave 会选三百多个；本期钩子只在有账本行或登记了绑定种类时生效（现在只有谷雨的花荫），所以跑上面的名单，含派单要的六个。

## 需要用户决定

- O-待定（护盾账本跳过的行）：默认开（跳过的行不替角色挡），关掉照原版白挡。

## 交接板

- 下一步：屠苏、璇三期（屠苏：武具数据、属性基准、伤害公式、噬主、绑定登记、五相支援、易武／化武／归形）；前置 A 车道把 176／177 加进切片 actors、CodexTusu／CodexXuan 公式进 MODULE_FORMULAS。
- 用户试玩说明：本期玩家看不到变化（谷雨的花荫照旧；种族伤害、再生扣血现在也先扣花荫，同原版）。
- 需要用户决定：O-待定 护盾账本跳过的行（默认不白挡）。

## 进度账

- 角色与专属机制：屠苏、璇 约 1/7 → 约 2/7（护盾账本、绑定框架），按工作量估。

## 可优化（流程／工具／效率）

- 参照探针里的「整数随机取中点」坑又踩了一次（敌人魔法技能伤害浮动对不上）：建议把 xiyou_raven_battle 的 FixedStream 收成 tests 公用的一个类（如 `tests/support/half_stream.gd`），新专项直接用（tools 车道）。

## 待交叉核查

- 共用核心：`battle/battle_logic.gd` 11 行（setup 后 start_battle；start_turn 末；end_turn 里账本 round_end 与绑定 end_turn；act 里防御支与技能支的 start_action、末尾 end_action；targets_for 末 filter_targets；_random_target 两个 return 改走 retarget；apply 首行 blocks_apply；_regenerate 与 sequence_gain 两处扣血先过账本；end_battle 两行清理）；`core/resource_context.gd` 两行；`core/race_battle.gd` settled_damage；`core/xstate.gd` from_dict 两行。
- `core/guyu.gd`：花荫改记公用账本（_grant_shield 加施加者参数、spring_shield_hit、shield_of／total_shield 读账本，行里去掉 shield／shield_until，end_round 去掉到期撤销）。
- `core/shield_ledger.gd`、`core/binding.gd` 全文；两个新探针、夹具、专项。

## 接续要点

- 三期登记屠苏种类：`XBinding.register("tusu", {...})`，form_state＝武具状态（ids().state.armed）、empty_state＝耗尽状态，回调照 installNativeTusuRuntime 126～330；内部施放 B.cast 这期没做，随五相支援一起做。
- 屠苏、璇的护盾来源（tusu.jintang、tusu.body、xuan.libi、xuan.yuhui）用 `XShieldLedger.grant`；璇的「护主」与定轨要接 `XShieldLedger._on_absorb`（现在只有谷雨一支）。侧栏护盾段现在只加谷雨那份（`XGuyu.shield_of`），有别的来源后改成 `XShieldLedger.amount(b)`（battle_logic views 与 side_status 各一处）。
- 璇附身期间隔离扣血：种类 spec 写 `blocks_hp_loss: true`，再在 resource_context 的 gain／set_resource 接 `XBinding.blocks_hp_loss`（这期没接，没有种类用）。
- 充能次数取本回合行动顺序里本体出现的次数（原版 a._actions.length）；参照只有 1 次的例，多次行动到三期用真屠苏再对一次。

## 反向验证

- 账本（xiyou_shield_ledger）17 处全咬住：加成不算、同源较低也覆盖、期限多一回合、晚到期先扣、原生护盾还在也减半、noHalve 不认、skip 不认、noDecay 不认、到期晚一回合、回合末不去重、种族不减半、回退支不白挡、gainHp／setHp 不接账本、revokeOwner 不撤、读档不清、战斗外也记。
- 绑定（xiyou_binding）22 处全咬住：转移不发 onUnbind、本体离场阵亡不清充能、manual 也记回归、耗尽状态不看回归回合、回合开始不清回归、manual 也转充能、行动次数算错、回合末没充能也 onRoundEnd、回合末不清充能、宿主离场／阵亡不解、回归不扣充能、默认宿主从队首找、makeTargets 不滤、randomTarget 不换、apply 不挡、技能行动不 startAction、不 endAction、开战不建数据、结束不清、回合开始／回合末不接。
- 第一轮 randomTarget 不换、apply 不挡两处没咬住：固定随机下 makeTargets 的过滤先把形态中的本体滤掉，两层包装看不出差别；补了参照 direct 例（8 号不在时 randomTarget 原生抽到 9、敌人直接 apply 打 9）后都咬住。

## 本分支提交

- 前面同 tusu1（到 98484670）
- 合 main 5692e099
- WIP: 公用护盾账本 XShieldLedger、参照、专项
- WIP: 形态绑定框架 XBinding、参照、专项
- 本提交：交付单可合并
