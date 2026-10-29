# 交付：claude/bajie-alien-affix5

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_84）
- 状态：可合并（期一、期二一起交）
- 本期：异化第③批「行动道具投影」：期一 投影接点＋祸祝 blessing；期二 恶愿 wish、逆祷 prayer。从 claude/bajie-alien-affix4（d728ec70）切出，合过一次 main（fa746789）。两期在同一分支，可以一起合；要分开合，期一到 7df2e3db 为止（加合 main 的 2ce366ed）。

## 原版依据（冻结 v0.28 `js/codex/runtime/`）

Aff＝installAlienationAffixes.js，Adv＝installAlienationAdvanced.js。

- **投影**（Aff:41-47）：`Game_Action.prototype.item` 整个换成 `A.project`，角色行动、词条和模板对上时返回 `A.clone` 改过的视图（按行动缓存）；`DataManager.isSkill` 认 `_alienOriginal`。
- **祸祝**（Aff:44）：templates.blessing（只有 7100 幻日虹，自身附加 2421 加速）改为敌方（原 scope 8→2，其余→1）；效果 31→32，其余效果的 dataId 换成 `statePairs`（2421→2668 祸祝·幻日虹，速度 ×0.75）；名字「祸祝·」。
- **逆祷**（Aff:22、42-62）：templates.attack 的技能照治愈（8）的副本改成治疗友方，保留原 id、名字、图标、说明、费用、技能类型、武器要求、连击数；伤害 0 的生命恢复（元素 10、不暴击），无效果，必中；原 scope 1→7，其余→8，原 3～6 不选目标、改随机友方 n 个（Aff:48-49）；治疗量（Aff:50）＝按原技能面板 MP 费用选治疗技能（≥125 治疗术 166，≥75 次级治疗术 135，否则 8）对该目标算一次的治疗值，平分给目标数（含连击重复）；对敌人的生命伤害全阻断（Aff:51）；敌人身上来源是逆祷者的负再生不算（Aff:55-62）；模板外的伤害技能（类型 1／2／5／6）不能用（Aff:22）。
- **恶愿**（Adv:176-181）：templates.wish（7100）改为全体友方再去掉自己；第一次 apply 先付代价（Adv:178-179）：增益变成自己的 −1 级减益，状态换成 statePairs 的诅咒挂到自己身上（回合照原状态最少回合）；付不起整次行动对谁都不生效。代价的诅咒与减益照囚厄接收的规矩（Adv:155-175：stateRate 1、不抵抗、不可驱散、清状态保留、自然到期才去、战斗结束清标记）。
- Aff:5（云裳 transferDebuffs 加诅咒与腐蚀）：`alienation.json` 的 transferDebuffs 是装好之后导出的，已含 2653～2671、2652，`xiyou_alien_config` 核对过，不另做。

## 重制落点

- `alien_battle.gd`（XAlienBattle）新节「行动道具投影」：`project`、`_project_blessing`、`_project_prayer`；`prayer_random_count`、`filter_targets`、`set_heal_targets`、`prayer_heal`、`blocks_skill`、`blocks_damage`、`prayer_regen_block`、`pay_wish`。恶愿代价的标记记在 meta `xalien_wish`／`xalien_wish_buff`，并进囚厄的 `receiving`、`after_removal`、`blocks_buff_removal`，战斗结束和囚厄标记一起清。`STATUS_AFFIXES` 加 wish、prayer。
- `battle_logic.gd`（原沙僧核心文件）：
  - `execute`：`weapon_unleash` 之后、付费之前 `skill = XAlienBattle.project(u, skill)`；算完目标后 `set_heal_targets`（两条路径：行动序列按 list 长度，普通按目标数×连击）。
  - `targets_for` 拆成包装＋`_targets_for`（原体）：逆祷 3～6 随机友方，恶愿去掉自己。
  - `apply` 开头：恶愿付不起就返回空结果（不跑 YEP 四段，原版包装在最外层）。
  - `_damage_value` 开头：逆祷走 `prayer_heal`。
  - `can_use`：逆祷者模板外的伤害技能不能用。
  - `execute_hp_damage` 开头：逆祷者对敌人的正伤害归零。
  - `_regenerate`：敌人扣掉逆祷来源的负再生后再算。
- **没接（问过唐僧，还没回）**：`battle_scene.gd` `_pick_target` 开头加一行 `skill = XAlienBattle.project(a, skill)`，选目标界面按投影后的 scope（祸祝选敌人、逆祷攻击选友方、逆祷 3～6 不选）。不加时界面按原 scope 选，逻辑里对不上的选中目标改随机（scope 1 随机敌人，scope 7 生命比例最低的友方）。

## 优化登记（O-109、O-110）

| 编号 | 原版 | 重制 | 回退 |
| --- | --- | --- | --- |
| O-109 | 投影用 `A.clone`（JSON 克隆）复制技能，丢了 YEP_SkillMasteryLevels 挂在技能对象上的 `masteryMpCost`／`masteryTpCost` 函数。用祸祝、恶愿技能（7100）、带 MP 费用的逆祷攻击时，付费算 `skillMpCost`／`skillTpCost` 报错，`SkillMasteryLevelsError` 先 `alert` 再 `SceneManager.terminate()`：**正式游戏里一用就弹错退出**（探针记 terminate 次数：祸祝、恶愿每次 2 次，火球术等带 MP 费用的逆祷 1 次，普攻 0 次） | 不崩，费用照原技能算。熟练度费用公式插件默认就是 `cost`，所以数值与「报错被吞」时一样 | 无开关：回退就是退出游戏，没有可复现的结算差别 |
| O-110 | 恶愿代价的诅咒用 `Game_Battler.prototype.addState` 挂，要过 `isStateAddable`：如果同一诅咒刚自然到期（记在恶愿者的行动结果 `isStateRemoved` 里），结果没清之前再用恶愿，诅咒挂不上，但代价算已付，队友照样得到增益——**免费恶愿**。正常流程里诅咒在回合末到期、下一回合再用就会碰到 | 照付：诅咒总能挂上 | 无开关：重制没有跨行动的结果对象，复现要另建；探针在到期后先普攻一次清结果，对照避开 |

## 验证

- 专项 `xiyou_alien_affix` **966/966**（上期 825）：新加 battle.blessing（穿异化本体 1020 世界树之枝；7100 打敌人 0、1，再普攻看不投影）、blessing.none、wish（7100；队友驱散代价被拒；自然到期；普攻；再用一次）、prayer（普攻治队友、火球术治自己、暴风雪 scope 2 治全体、炸裂火球 scope 5 随机三名友方、十字军打击 模板外不可用且对敌无伤、敌人普攻）。每步比双方生命、法力、护盾、状态、增减益，另比投影后的名字、scope、效果，逆祷用例再比原技能能不能用。跑专项时临时把探针输出拷进 `generated/oracle`，跑完拷回（cmp 确认基线没动）。
- 选测（最终代码，合过 main 之后；不跑全量）：**30 个场景全过**，没有偶发，墙钟 3337 秒（大半在排共用槽）。名单：`xiyou_actor_p0`、`xiyou_alien_battle`、`xiyou_alien_config`、`xiyou_alien_workshop`、`xiyou_battle`、`xiyou_battle_common_event_child`、`xiyou_battle_common_events`、`xiyou_battle_events`、`xiyou_battle_options`、`xiyou_battle_start_event`、`xiyou_battle_ui`、`xiyou_battleback_save`、`xiyou_boss_output`、`xiyou_boss_output_context`、`xiyou_cat`、`xiyou_combat`、`xiyou_determinism`、`xiyou_formula_effects`、`xiyou_module_hooks`、`xiyou_race_battle`、`xiyou_rules`（难度 1 首段）、`xiyou_smart_ai`（四段 `_b`／`_c`／`_d`）、`xiyou_state_effects`、`xiyou_state_effects_tp`、`xiyou_state_js`、`xiyou_state_merge_context`、`xiyou_state_operation`。（中途改代码时有一轮选测被我停掉重跑，不算。）
- 同步：工作树跑 `同步正式西游.py --accept-additions`。第一轮报 alien_affix 的 hostScope「有变化」，旧 19 例逐项不变、只多 4 例；写接受单 `04_验证/测量接受/claude_bajie-alien-affix5.json`（旧摘要 711978fd…＝main 上 affix4 的版本）后第二轮：「新增用例、显式接受 1 条既有用例改变，已接受（不登记）」，退出码 0。悟空的 param_cache 是新探针，按只增接受。同步后 `generated/oracle/alien_affix.json` 与探针产物一致，专项复跑 966/966。
- 已清理：本车道的并行测试日志目录、调试脚本都已删（同步备份目录是同步脚本的常规产物，保留）。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化第③批：行动道具投影（祸祝、恶愿、逆祷）（dev.待定）

- **内容**：异化词条「祸祝」「恶愿」「逆祷」在战斗里生效。
  - 祸祝：幻日虹改为对一名敌人施放，加速换成对应的诅咒（速度 ×0.75），技能名显示「祸祝·」。
  - 恶愿：幻日虹改为给除自己外的全体队友，自己先挂上对应的诅咒（不能驱散，到期才去掉）；付不起就整次无效。
  - 逆祷：普攻等攻击技能改成治疗队友（名字「逆祷·」），按原技能的 MP 费用选治疗技能算治疗量、平分给目标；不能用别的伤害技能，对敌人造成不了生命伤害，自己挂给敌人的持续伤害也不算。
  - 接点是 `XAlienBattle.project`（原版换掉 Game_Action.item），在 `execute` 里武器解放之后换一次，之后费用、目标、命中、伤害、效果、战斗记录名字都读投影。
- **优化**：O-109（原版用这三个词条的技能会弹错退出游戏，重制不崩）、O-110（原版恶愿代价在诅咒刚到期时会白付，重制照付）。
- **参照**：`alien_affix_probe.cjs` 加 battle.blessing／blessing.none／wish／prayer 四例（23 例）：开战前可学技能（`learn`，要先学会模板技能才穿得上）；步骤可记行动开始时 item() 的名字、scope、效果、原技能能否使用与 terminate 次数（`SceneManager.terminate`、`alert` 换成计数）。

## 待交叉核查（原沙僧核心文件）

- `battle_logic.gd`：`execute`（投影、`set_heal_targets` 两处）、`targets_for` 拆包装、`apply` 开头恶愿、`_damage_value` 开头逆祷、`can_use` 逆祷条件、`execute_hp_damage` 逆祷阻断、`_regenerate` 逆祷负再生。
- 另改：`alien_battle.gd`（车道独占）、`tests/xiyou_alien_affix.gd`、`mv_oracle/alien_affix_probe.cjs`。

## 交接板建议

- 下一步：异化剩下的技能表类（百相、无相、缄默、饕餮、蚀术）与装备类（吞器、献器、夺舍）。
- 用户试玩说明：异化装备的「祸祝」「恶愿」「逆祷」现在战斗里生效。原版用这几个词条的技能会弹错退出游戏，重制不会（O-109）。
- 需要用户决定：O-109、O-110（都按默认继续；两条都没有回退开关，原因见登记行）。

## 进度账

- 战斗规则·异化：词条效果 9/20 → 12/20（祸祝、恶愿、逆祷；前 9 个：逆骨、归墟、疫囊、囚厄、绝缘、舍身、空壳、连命、嫁祸）。

## 没做

- 选目标界面的投影（`battle_scene.gd`，等唐僧批）。
- 自动战斗、智能 AI、挂机选技与估值按原技能（原版 evaluate 读投影）；落到逻辑里照样投影。
- 逆祷者的反击（`_invoke` 里 `apply(t, t.attack_skill(), u)`）没投影。原版反击也走 item()，会变成「治疗」打到敌人身上；重制照普通反击，对敌伤害被 `blocks_damage` 归零。
- 逆祷借原技能熟练度算治疗：重制熟练度统一为 0（`battler.gd` `skillMasteryLevel`），原版新局也是 0，没移植。
- 投影后 `is_attack`（追加攻击次数）：原版投影对象不是 `$dataSkills[attackSkillId]`，逆祷普攻不吃攻击次数追加；重制按 id 判，会吃。探针没覆盖（角色没有这类特性）。
- 恶愿、囚厄代价减益在 clearBuffs 时的保留（上期就留着）。
- 逆祷阻断只接了 `execute_hp_damage` 与回合末再生；原版另在 gainHp／setHp 的行动帧里阻断（自定义状态的持续伤害等），重制没有对应帧，没接。

## 可优化

- 探针：参照引擎被 terminate 之后，后面的用例全挂，报的是 `location` 未定义，看不出原因。建议 `shared/host.cjs` 的 start 默认把 `SceneManager.terminate` 换成「记一笔并抛错」，探针直接报出是哪一步（这次查了几轮）。归维护探针工具的车道。
- O-106 预分配外：本期用了 O-109、O-110（派活交代「O-109 起」）。

## 本分支提交

- 7df2e3db WIP: 异化第③批期一：行动道具投影接点（execute 里武器解放之后）＋祸祝，探针两例，专项 867/867
- 2ce366ed Merge branch 'main' into claude/bajie-alien-affix5
- 017f2c59 WIP: 异化第③批期二：恶愿、逆祷（投影、目标、治疗分摊、阻断伤害与负再生、技能条件、代价保护），探针两例，专项 966/966
- （本提交）异化第③批：同步接受单、交付单可合并
