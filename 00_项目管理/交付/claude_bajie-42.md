# 交付：claude/bajie-42

- 车道／工作者：C 规则·机制／八戒（Claude，重制_八戒_40 会话复用）
- 状态：可合并
- 验证（车道不跑全量）：合并 main 一次（main 只改文档与版本号，未碰切片／探针／转换器，之后不再同步）；`同步正式西游.py --accept-additions` 最后一轮「新增用例，已接受」：imported_balance.json 新增 68 例，slice_d1～d6／actor_passive／help_cards／wtype 只增 141、142 的行，custom_params 不变；`内容覆盖检查.py --check` new 0、resolved 0。相关专项全过：xiyou_imported_balance 257、xiyou_actor_p0 2772、xiyou_rules 十二段（各 111353～111418）、xiyou_wtype 13726、xiyou_help_card 900、xiyou_custom_params 160、xiyou_power 137、xiyou_smart_ai 四段、xiyou_custom_damage 145、xiyou_formula 四项、xiyou_combat 34、xiyou_battle 系列、xiyou_battle_events 108、xiyou_troop_events 7699、xiyou_action_sequence 115、xiyou_floor_run a／b／c、xiyou_shield、xiyou_zhenqi 三项、xiyou_transform_params、xiyou_review_fix、xiyou_random_streams。

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】导入角色平衡模块（141～166）；141 女儿国王、142 天海麒麟星加回切片（dev.待定）

- 依据悟空 C 类试点设计（claude_wukong-32 交付单「141 女儿国王、142 天海麒麟星」）与冻结源 `js/codex/runtime/installImportedBalanceRuntime.js`。
- **参照（期一）**：新增 `mv_oracle/imported_balance_probe.cjs`（登记进同步探针表与只增接受键），68 例。真实 BattleManager／Game_Action，Math.random 0.5；行动者 141／142／163／143（禁用）／1（基线），敌群 2。覆盖普攻与本人技能（9909、9910、10098～10100、9933、10116）、单体／全体伤害、MP 伤害、吸血、MP 吸取、治疗、护盾、魔法反射、序列 HP／MP 增减（含百分比）、DOT（中毒 4，来源为行动者）、无上下文直接 gainHp、敌人打导入角色，另录各夹具双方生命／魔法上限（caps.*）。在战斗者实例上挂最外层记录，记每次结算调用的缩放前原值、嵌套深度、前后 HP／MP／护盾与弹字。
  - 实测要点：缩放在最外层、先于护盾（护盾 1000、原值 17208 → 172，盾剩 828、生命不动）；魔法反射回行动者自己也缩放（14 → 0）；吸血按缩放后的值回血；治疗（负值）不缩放；禁用角色 143 对目标没有任何结算；无行动上下文的 gainHp 与敌人打导入角色不缩放；DOT 由导入角色附加的那部分固定 ×0.01（163 也是 0.01，不是 0.001）。
- **实现（期二）**：新增 `core/imported_balance.gd`（`XImportedBalance`）：outgoing_rate（163＝0.001，141～166＝0.01）、禁用角色 143／144／145／157／160 与禁用号角 255／256／257／394／440、scales／reduced。`battle_logic`：禁用角色或号角的行动付费后直接结束（行动序列不跑）、apply 直接返回；`execute_hp_damage` 最外层先缩放正伤害，再走真气减伤与护盾；新增 `execute_mp_damage`（先缩放，MP 伤害以目标现有 MP 为上限，类型 6 吸取回给行动者）；魔法反射回自己的那次 apply 照样缩放；`sequence_gain` 带行动者，对序列目标的 HP／MP 减少缩放；`_regenerate` 把导入角色附加状态里负的 HP 再生率部分 ×0.01。`XBattler.state_origins` 记附加状态时的行动者（YEP stateOrigin，弱引用，避免自加状态／互记来源成环泄漏），预览克隆不带。
  - 新测试 `xiyou_imported_balance`：把参照每次最外层结算的原值按顺序重放进对应 Godot 入口，比每次弹字与最后 HP／MP／护盾；禁用角色另跑真实 apply／execute 确认对目标无效。
  - 未移植（Godot 无对应机制，未做参照）：行动内公式直接 gainHp／setHp 的缩放（scaledNegative 对行动目标）、Bailong A.C.S 合并尾段（isAcsLoop）、反击状态脚本 1341／2550 的来源改写。
- **加回切片（期三）**：`xiyou_slice.json` 的 actors 加 141、142；`xiyou_actor_p0` 新增 RECRUIT_7（CE2501「招募_女儿国王」、CE2502「招募_天海麒麟星」的 129 指令）。参照伤害行（slice_probe）用的是 `makeDamageValue`，原版模块不包这一层，所以两人的伤害行本来就不带 ×0.01，与 Godot 的 `XDamage.calculate` 口径一致（×0.01 在结算处由 XImportedBalance 做）。142 的开战状态 2588 `<Custom Confirm Effect>` 已被转换器翻译成 `mul`（×1.005 向上取整），不是未翻译 js，未触发停手条件。
  - `custom_params_probe.cjs` 挑装备穿戴者时跳过 141～166（同 104 的做法）：否则加回切片会改挑 142，搅掉既有两例（4160 的普通穿戴与 74 的直接写槽）的覆盖。
  - **导入效果平衡（同文件 CodexImportedEffects）**：加回后 rules 伤害行发现原版还有第二层——导入角色用不是本人专属的伤害技能（类型 1／2／5／6；本人技能 9906～10121 与 10169 除外，普攻等共用技能都算）时 `Game_Action.evalDamageFormula` ÷10。Godot 新增 `XImportedBalance.formula_value`，接在 `XDamage.eval_formula`（纯公式）与 `XFormulaExecution.run_item`；混合模式求偏导的能力值代理按被代理的行动者算。
  - **强者分类**：原版 `installNativeMiraRuntime.fixStrongClassification` 在 `Game_Actor.setup` 后对 141～172 一律忘 6235、学 6216「强者压制」、5970 换 5971、去 1035／1276／1277；`XActor.setup` 照做（强弱分档系数属五乘区，按数值平衡不移植，只对齐已学技能）。
  - **说明卡**：10264「异界制约」（<CodexImportedBalance>）落在角色专用说明段 10122～10299，原版 characterHelpView 对它没有专用副本与动态行，与普通分组同形；Godot 只把它放回普通分组视图，其余该段技能仍原样。
  - 同文件未移植（另记缺口）：导入角色专属装备的效果补丁（CodexImportedEffects.patches，改装备备注／特性／元素增幅）、导入角色身上 2301 换 2718、技能类型页签（7／8 拆成物理／魔法／被动，界面）。

## 交接板

- 下一步：Codex 核查本分支（缩放落点与只缩一次、DOT 来源、禁用角色、公式 ÷10 的技能范围、强者分类）。143～166 其余导入角色加回时复用 XImportedBalance，逐人补招募与参照行；未移植项（专属装备效果补丁、2301→2718、技能页签、公式内直接 gainHp、A.C.S、1341／2550）遇到用到的角色再补参照。
- 用户试玩说明：141 女儿国王、142 天海麒麟星可招募；她们（及之后的导入角色）造成的伤害只有原来的 1%（163 琦玉 0.1%），用普攻等共用技能时公式值再 ÷10，与原版一致。
- 需要用户决定：导入角色的 ×0.01 结算倍率，与数值平衡文档「统一调整」阶段的「我方伤害系数」是叠乘还是由后者取代？本轮按原版做（只有导入倍率）。

## 进度账

- 角色：+2 人（141、142）按 B 类模板与导入平衡模块，由总装按现行口径计入。

## 本分支提交

- 06a4563 期一：imported_balance_probe
- 2c5a066 期二：XImportedBalance 与逐例重放测试
- b27c8b2 期三：141、142 加回切片；状态来源改弱引用
- 4902bb4 期三：custom_params_probe 跳过导入角色
- cb7f0b0 期三：导入效果平衡（公式 ÷10）、强者分类、10264 说明卡
- b9ff8ff 合并 main
