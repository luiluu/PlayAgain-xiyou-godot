# 交付：luiluu/t480

- 车道／工作者：T480 元素效果B 效果接线（我方打敌）（cc，Opus＋medium，P8），从 luiluu/t484 @ 1ad6347c6 开出（含 T479、T484，未合 main；它们合 main 后再 rebase）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·未经审查】T480 天启篇元素独特效果接线：我方打敌＋圣护（dev.待定）
- 新增 `XTianqiElementEffects`（`modes/xiyou/core/tianqi_element_effects.gd`）和 `XTianqiNature`（`tianqi_nature.gd`，读 T479／T484 两张体质表）。照设计稿《天启篇_元素独特效果_v0.3》§3.1～3.6、4.2～4.3 接线：段记录只记账、行动收尾按（实际扣血对象, 胜出元素）各掷一次；十个效果（灼烧、迟缓→冰冻、碎甲、麻痹、寄生、浸湿、乱流、魔蚀、圣护、遮蔽锋芒）＋首领版（感电、只迟缓、最终持续写死）；灼伤／麻痹白名单归并；麻痹、冰冻只跳一个行动位、停手共用冷却 5 次、旧控后先放行一次；圣护（对己方给每个目标、对敌给施放者、盾挡对方一次可解除减益）。
- 新状态 12 个（表外号段 10940～10951）；数值进 `elements_table.json` 的 `element_effects` 等 7 个新字段，数据校验同步。
- 只在天启篇存档生效；开关 `XTianqiElements.EFFECTS`（O-待定）。西游档每个入口直接返回、不取随机数。效果掷点用本场种子派生的子流 `elem_effects`，不动战斗主流。
- 玩家可见：天启篇里我方基础十系伤害有几率给敌人挂效果，神圣技能给自己人「圣护」；战斗日志多出「陷入【灼烧】」「【麻痹】，这次无法行动」「得到【圣护】」等行（文字是草稿，待小A 审）。

## 交接板

- 下一步：B2（敌打我方）接同一套接口：放宽 `XTianqiElementEffects._side_ok`，`_try_apply` 里接 4.4 我方判定（硬免疫→体质→有效度→韧性）、5.3 施效预算、首领一侧圣护每场 3 次（`effect_rules.holy_boss_per_battle` 已留）；C 卡重数人数档、调几率（`effect_tier_of` 现在是 v0.7 估算）；E 卡小A 审状态名与日志文字（见下「文字」）。
- 用户试玩说明：天启篇战斗里打出火、冰、雷等伤害会偶尔给敌人挂状态；神圣治疗会顺手驱散一个减益并给个挡减益的盾。
- 需要用户决定：无（口径疑点列在「没做／偏离」，按设计稿默认做了）

## 进度账

- 无

## 优化登记草稿

| 编号 | 名称 | 原版行为 | 改法 | 开关 | 恢复方法 | 状态 | 来源 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 天启篇元素独特效果（我方打敌＋圣护） | 元素伤害只有倍率，没有附带效果 | 设计稿 元素独特效果 v0.3：十系效果、首领版、行动位停手、圣护 | `XTianqiElements.EFFECTS` | `XTianqiElements.EFFECTS = false` | 保留 | T480 |

## 可优化（流程／工具／效率）

- 建议：`effect_tier_of` 现在手填 v0.7 估算，C 卡可以写个脚本按「能打出该系伤害的可用角色数」生成（数值车道 Sonnet）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XBattleLogic.execute`（原函数体改名 `_execute_body`，外面包一层开帧／收帧） | 54 处（`git grep -nE '[^[:alnum:]_]execute[[:space:]]*\(' -- '*.gd'`，去掉 Expression.execute） | 调用方 54 处逐处结论：签名、返回值不变，只在返回的记录末尾多出效果日志；西游档、开关关着 `frame_begin` 返回假，不加任何记录。`xiyou_combat`、`xiyou_otb`、`xiyou_tianqi_xinmo_traits` 等直接调 execute 的专项本机全过 |
| `XBattleLogic._counter_attack` | 5 处（`git grep -nE '_counter_attack[[:space:]]*\(' -- '*.gd'`） | 调用方 5 处逐处结论：返回 `[counter, r]` 后面可能多出效果日志（只天启篇），调用方都是整段 append／返回，不按下标取第 3 项 |
| `XBattleLogic.apply`／`_apply` | apply 末尾加 `note_hit`（只记账）；`_apply` 给结果加 `hp_loss`、`hit_target` 两个键 | 新键不覆盖旧键；没有调用方遍历结果字典的全部键 |
| `XBattleLogic.act` | 元素停手吃位（`take_skip`）、收尾 `act_end` | 西游档恒空串／空数组，不改 skipped |
| `XBattleLogic.turn_end_battler` | 18 处（`git grep -nE 'turn_end_battler[[:space:]]*\(' -- '*.gd'`） | 调用方 18 处逐处结论：只在 ExtDot 之后插 `tick_dot`，没有记账时直接返回 |
| `XBattler.add_state` | 圣护盾 `shield_blocks`、`after_add_state` | 两个钩子在没有天启篇战斗记账（`_logic` 为空或单位没挂盾）时第一句返回 |
| `XDamage.calculate` | 浸湿 `out_mult`、遮蔽锋芒 `crit_mult` | 单位没挂这两个状态时恒 1／原值 |
| `XTianqiElements.combined_exposure_pct` | 6 处（`git grep -nE 'combined_exposure_pct[[:space:]]*\(' -- '*.gd'`） | 调用方 6 处逐处结论：只多认「感电」一种，跟弱点暴露同一格取高 |
| `XTianqiElements.start／finish／end_turn` | 各加一行转给效果模块 | 效果模块自查开关 |
| `XDB.rec`（States 表外号段） | 10940～10951 | 号段不撞 `skill_rework.new_states`（10801～10833）、徐凤年 19501，测试断言 |
| `BattleScene._command` | 我方这一位会被元素停手跳过时不开指令窗 | 同旧控不能行动的处理 |

## 做法

- **事件契约（§3.1）**：`apply` 末尾 `note_hit` 记段（实际扣血对象、胜出元素 `best_row.element`、判定、`hp_loss`＝过护盾后空蚀前实扣、来源）；`execute` 一次、反击一次各开一帧，帧收尾按（对象, 元素）首次出现顺序各掷一次，基数＝合格段 `hp_loss` 合计。没开帧的零散 apply 在 `act` 收尾按出手者补掷。持续伤害跳数、空蚀不经 apply，天然不算；反射回自己的段标 `reflect` 不算。
- **十个效果**：普通版、首领版、免疫矩阵、人数档、冷却、停手规则全读 `elements_table.json`（`element_effects`、`effect_tiers`、`effect_tier_of`、`effect_rules`、`effect_immunity`、`effect_merge`、`enemy_effect_rules`（B2 留口，本卡不读））。几率：火冰神圣 11%、雷自然奥暗 15%、地水风 22%（神圣按 D285 补「群体人人都给」从中档降一档）；首领 ×0.5；雷对水体质或浸湿中 ×1.5（只一次）。
- **状态**：12 个表外状态，restriction 全 0；麻痹、冰冻是「待跳过 1 个行动位」标记（自动解除时机 0）；首领版不带控制标签（霸体、1 回合免控、骑士不拦），挂上后直接写最终回合数（不再走首领减半、号卷延长）。
- **停手（§3.6）**：`act` 开头 can_move 判完后，有标记就吃这一位（日志「【麻痹】，这次无法行动」＋原 skip），标记移除、停手计数 5；之后每次自己完成的行动（出招、防御、等待，被跳过的不算）减 1。旧控（restriction ≥ 4）挂上或被旧控跳过时计数至少 1，待生效标记直接移除不算吃位。
- **圣护（§3.5＋D285 补）**：一次行动最多掷一次；对己方用（技能带神圣、目标是自己人且活着）给每个目标；神圣伤害打中敌人给施放者。先驱散 1 个可解除减益（照状态排序取第一个，保留瘟疫异化「净化可能失败」），再给盾；盾挡下一次「对方出手者」施加的可解除减益，挡一次就碎、最多 2 回合；冷却记在持盾人身上。
- **随机**：本场种子（钉住时用 pin_seed）派生 `elem_effects` 子流，掷点和挂状态的持续回合都从子流取。

## 没做／偏离（请核查重点看）

1. 派单说「读 XTianqiNature.of」，库里没有这个类，本卡新建（只读表，鸿钧、骑士按战斗身份取 `special`）。
2. 圣护盾「不挡脚本锁定状态」落成：只挡**对方出手者**正在施加的可解除减益（`XImportedBalance.acting_battler()` 是对方单位）；没有出手者的（回合开始脚本、阶段状态、剧情锁）一律不挡。没去逐个列骑士阶段状态号。
3. 硬免疫／有效度 0：除了查新状态号，也查借图标的原版同类状态（灼伤 17、停滞 61、降众天华·冰冻 1082、碎甲 12、麻痹 100、致盲 37）；感电不借麻痹（不是控制）。
4. 第 2 次迟缓本该冰冻但停手资格不够（共用冷却、已被停手、本场冻过）时，照挂普通迟缓。
5. 驱散沿用 `XTianqiPlagueAlien.purge_blocked`：它在瘟疫异化战里会取一次战斗主流（原判定照留，非瘟疫战不取数）。
6. 灼烧、寄生跳伤照四骑士先例直接扣生命（过护盾），不走资源上下文（首领扣血上限等不参与）；寄生回复同样直接加。
7. 感电走弱点暴露那一格，那一格只在词条战斗记账（`xaffix`）开着时进伤害；跟现有弱点暴露同样的前提。
8. §3.1 正反例里「转换书、技能转属、装备附加伤害并入本行动」靠胜出元素取 `best_row.element` 自然成立，**没单独写测试**；装备附加伤害是不是走 `apply` 没核。
9. 战斗日志、状态名、说明都是草稿：灼烧、迟缓、冰冻、碎甲、麻痹、寄生、浸湿、乱流、魔蚀、圣护、遮蔽锋芒、感电；「X陷入【Y】」「X【麻痹】，这次无法行动」「X得到【圣护】」「X的Y被驱散」「【圣护】挡下了Y」——**待小A 审**。
10. 敌打我方（B2）、首领一侧圣护每场 3 次、5.3 预算都没做（不在本卡）。

## 文字

有玩家可见文字（上面第 9 条），待小A 审。

## 验证

- 新专项 `xiyou_tianqi_element_effects`：41/41（§3.1 两条＋护盾全吸不掷＋散段补掷＋跳伤不再触发；§3.4 四例＋旧麻痹归并；§3.6 三条＋共用冷却 5 次；冰冻、水体质、浸湿、体质免疫；§4.3 首领九系版本与最终回合、首领冷却 2 回合、首领谓词；§3.3 高等不掷十系且吞没／空蚀／弱点暴露照旧、敌人高等打我方按受击者原倍率；圣护单体、群体人人、对敌给施放者、挡对方减益、不挡无出手者、持盾人冷却；子流不动主流（开关关 vs 开且几率 0 主流快照逐字相同）、开关关不建记账、西游档零改动）。
- 本机：xiyou_tianqi_elements、xiyou_tianqi_element_effects、xiyou_combat、xiyou_otb、xiyou_determinism、xiyou_tianqi_xinmo_traits、xiyou_tianqi_balance、xiyou_attack_element、xiyou_multi_element 9 个全过；语法检查 0 问题；`天启篇数据校验.py` 全部通过、`测试天启篇数据校验.py` 148 例 OK（新增 `ElementEffectsRules` 3 例）；工具快速回归全部通过；`发行空壳.py check` 退出 0（新两个类的空壳：out_mult 1.0、crit_mult 原值、has_state false、钩子空）。
- 云端选测：待回填

## 验收

1. 3.1 事件契约、十个效果、归并、首领链、3.6 行动位规则、停手共用冷却：✓
2. 圣护：己方目标给目标、对敌给施放者、群体己方每个目标都给：✓
3. 回退开关（`XTianqiElements.EFFECTS`）；西游档零改动：✓（测试 `switch_off_no_meta`、`substream_leaves_main_stream_identical`、`west_save_untouched`）
4. 固定断言全过（3.1 两条＋3.4 四例＋3.6 三条＋4.3 首领表＋3.3 高等回归两条）：✓ 本机

## 本分支提交

- 1b58feb5d 效果接线与固定断言（WIP）
- （后续）数据校验字段、回退支字面量、西游档清钩子指针、交付单
