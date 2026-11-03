# 交付：cc/wukong-xuan4b

- 车道／工作者：C 规则／悟空（cc，悟空 xuan4b，Opus medium；接另一账号悟空 `cc/wukong-xuan4` 的现场：835e92fb、总装十八代存的 WIP 679ccd2a）
- 状态：可合并（期一；期二见「接续」）

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】璇第三期（期一）：星契自律、审查 33／34 修正（dev.待定）

- 星契自律（`installNativeXuanRuntime` 自律反应，50 级第三阶、星谱选「自动」开战后附身时）：星契由模块自己花，内部施放照常付费、进冷却，不插入行动序列；只剩 1 点时只给护主（保留最后 1 点）；先照 1～3 级在星契 0 时护主预支 1 点（每 3 回合一次、只许一笔债，下回合还）。
  - 敌人对我方的伤害行动打到受益者前放璃壁（每回合一次；并轨 2 级打到副宿主也给）。
  - 行动结束：受益者低血（≤60%）或被硬控就救援回光（并轨 1 级救副宿主）；列星就绪且有别的队友就放；宿主（含星影）主动攻击后放棱光，打这次攻击最后打到的敌人（倒了打第一个活着的）。分光 1～3 级在全体攻击后分给 2／3／4 名敌人、伤害按人数分摊；同调 2 级跟攻击元素、1 级用星谱指定元素。
  - 同轨（默契 100）：回光、璃壁、列星各带一次棱光式协同（每次行动一次，不花星契）。
  - 回合末剩的星契依次放：受益者缺血或被控→回光、璇自己半血以下或被控→回光、棱光、给宿主璃壁，放不出就停。
  - 自动战斗（`makeAutoBattleActions` 包装，屠苏之内）：附身且自律时防御；本体时先救 30% 以下的队友，再寄星（命主名册优先，否则默认宿主）。
  - 接线：`battle_logic.gd` 的 `execute`（startAction 包装，屠苏之内）、`act`／`_forced_run`（endAction 包装，屠苏之内、谷雨之外）、`apply`（记主行动最后打到的敌人）、`auto_battle_action`；伤害钩子 `XXuanBattle.cast_ops`（分光分摊、同调换元素）并进 `XActorDamageHooks`。
- 审查 33 P3-3／P3-4 定星：定星包在最外层，本会被抗性挡下的硬控也先消耗定星；事件「更改状态」（`sequence_add_state`）、技能附加被抗性挡下、异化囚厄接收（`alien_battle.gd`）也先过定星；璇不在出战成员里不挡；挡下时不写「定星挡住了控制。」（原版外层直接 return，量过）。
- 审查 34 P2-1：璇附身期间回合末的中毒等持续伤害不再扣血（`_regenerate` 里负的 HP 再生遇 `XBinding.blocks_hp_loss` 归零，不吸护盾、不弹字），与原版 `Game_Actor.gainHp` 包装直接返回一致；回身后照扣。
- 审查 34 P2-2：读档后命主名册是 `[8.0]`，战斗里 `has(8)` 认不出；改在 `XTusuXuan.chart()` 读出时就把名册归成整数，战斗里读名册的各处（换宿主默契 75%、列星命主净化、自动寄星）都认得。
- 审查 34 P3-1：定轨（10 级，璃壁被打破给一次定星）只认原版 `direct(action)`：敌人、伤害类型 1／5、对敌；敌人用不带伤害的技能、行动里序列扣血打破璃壁不再给。
- 审查 34 P3-2：量了原版，留辉不跨战斗（第二场开头旧宿主双防已回到原值），重制存在本场数据里的写法一致，不改。
- 参照：`xuan_bind_probe.cjs` 补 `owner.poison`、`possess.roster_json`（40→42 例）；`xuan_battle_probe.cjs` 补定星 4 例；新加 `xuan_auto_probe.cjs`（17 例：救援、宿主攻击后棱光、保留最后 1 点、分光、同调 1／2 级、璃壁、并轨 1／2 级、先照、同轨、净化、回合末释放、手动、自动战斗、定轨、定轨非直接伤害）→ 新专项 `xiyou_xuan_auto`。

## 交接板

- 下一步：璇第三期期二（见下「接续」）。
- 用户试玩说明：璇 50 级第三阶在星谱选「自动」后，附身期间会自己放璃壁、回光、列星和棱光；附身期间中毒不再掉血；读档后命主名册在战斗里生效。
- 需要用户决定：无。

## 接续（期二，没做）

- 先照手动先制（原版 `Game_Action.speed` ＋100000，OTB 下怎么用还没量）。
- 60 级列星法宝特效（`installThreeGrowthRelicRuntime.js` 150～200 行：`_codex60Home`、星幕 `_codex60StarMist` 下一次敌方直接伤害 −10%、首次回光额外净化）。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：原版探针各例之间不结束战斗时，`CodexBinding` 的 `startedRound`／`endedRound` 会跨例残留（本期 xuan_auto 碰上）；`xuan_bind_probe`、`xuan_battle_probe` 和别的用绑定的探针（屠苏）也可在 setup 里补 `B.clearAll()`，或由 `shared/host.cjs` 的 `newGame` 统一清。归哪吒（工具），收益是少一类「夹具不对、重制其实对」的排查。

## 待交叉核查

- 核心文件改动：`battle_logic.gd`（`_regenerate`、`execute`／`act`／`_forced_run`／`apply`／`auto_battle_action` 接线、835e92fb 的技能附加抗性路径与 `sequence_add_state`）、`actor_damage_hooks.gd`、`alien_battle.gd`（囚厄接收）。
- 请看：①`xiyou_xuan_auto` 的 `seqhit` 步骤在重制一侧是手动按行动起止包装次序走的（参照包 `Game_Action.apply` 扣血），不是真实的序列扣血路径；②星契自律的伤害钩子 `cast_ops` 放在 `damage_ops` 前面。

## 验证

- 原版探针在本树重跑：`xuan_bind_probe` 42 例、`xuan_auto_probe` 17 例，产物复制为夹具；`xuan_auto_probe` 开战前补 `CodexBinding.clearAll()`（各例不结束战斗，原版绑定模块的 `endedRound` 会把上一例的回合号带进来、跳过第 1 回合的默契结算；只影响定轨例，其余 16 例重跑逐例不变）。
- P3-2 用临时原版脚本量（xuan_bind_probe 的 setup＋留辉 2 级换宿主＋结束战斗再开一场），不进仓库：第二场第 1～3 回合旧宿主双防都是原值 20。
- 专项（`并行测试.py`，并行 2）：`xiyou_xuan_bind` 669、`xiyou_xuan_auto` 1808、`xiyou_xuan_battle` 268、`xiyou_xuan_chart` 133，全过。
- 选测（同一轮，全过）：`xiyou_binding`、`xiyou_shield`、`xiyou_determinism`、`xiyou_regen_popup`、`xiyou_poison_collapse`、`xiyou_tusu`、`xiyou_tusu_battle`、`xiyou_actor_modules`、`xiyou_hangup_auto`、`xiyou_smart_ai`、`xiyou_alien_battle`、`xiyou_state_operation`、`xiyou_battle`、`xiyou_otb`、`xiyou_guyu_battle`、`xiyou_rules`、`xiyou_rules_d6`。
- 没跑的：`选测.py main --list` 因改了 `battle_logic.gd` 和探针列出 137 个场景（xiyou_rules 全部段、事件对照等），车道只跑上面 21 个，其余留给总装合并选测；没跑全量、没跑反向验证、没跑同步（改的是 xuan_* 探针，不进同步）。
- `语法检查.py`：512 个 .gd，0 个问题。

## 本分支提交

- 835e92fb 审查 33 P3-3／P3-4 定星，xuan_battle 探针补 4 例
- 679ccd2a WIP：星契自律（总装十八代存）
- ecbd4bcd WIP：审查 34 P2-1、P2-2、P3-1，xuan_bind 补 2 例、xuan_auto 补定轨 2 例
- 本提交：xuan_auto 探针开战前清绑定记号、定轨夹具重量；交付单定稿
