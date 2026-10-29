# 交付：claude/bajie-alien-affix3

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_83）
- 状态：可合并
- 本期：异化词条效果期二·第②批「生命池类」：空壳（hollow）、连命（lifelink）、嫁祸（scapegoat）。基线 main 5bb5e608。期一（三个词条＋期二①「没做」里同一接点的两条）做完；期二（可砍的三条）没做，见「没做」。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条效果期二②：空壳、连命、嫁祸（dev.待定）

- **内容**：照冻结 v0.28 installAlienationAdvanced 移植三个生命池类词条。
  - 空壳：战斗中生命上限读 1，开场剩余生命变成护盾（不超过原生命上限）；治疗、吸血无效；回蓝（含回合末再生）按开场生命／法力比例变护盾；护盾打穿就倒下；战后按剩余护盾还原生命。
  - 连命：与绑定队友合并生命池（开场按两人剩余生命相加），各自按自己的上限比例显示；伤害和治疗都结算到池，治疗只加一次；池归零两人一起倒下。
  - 嫁祸：敌人对自己的生命伤害（类型 1／5）改由绑定保护者承受，命中、闪避、暴击、伤害都按保护者算，技能效果仍落在自己身上；自己没有独立生命和护盾，生命按保护者比例显示，治疗、护盾无效，其他扣血由保护者付；保护者倒下自己也倒下。
- **顺带**（期二①「没做」里同一接点的两条）：舍身、绝缘对回合末再生（再生改走 gainHp：舍身转给队友，绝缘自己的再生照常），绝缘对 setHp（改走 gainHp）。
- **O-108（优化，可回退）**：原版复活包装被 Olivia_BattleSysOTB 盖掉，连命复活后生命池仍为 0、嫁祸的保护者倒下也能复活；重制默认照词条说明生效，`XAlienBattle.o108_life_revive = false` 恢复原版。待用户决定。
- **参照**：`alien_affix_probe.cjs` 加 battle.hollow／lifelink／scapegoat／sacrifice.regen／insulation.regen 五例（共 12 例全干净），步骤新增 regen（onTurnEnd）与 revive（去阵亡状态）。同步接受单 `04_验证/测量接受/claude_bajie-alien-affix3.json`（hostScope 描述）。

## 原版依据（文件:行，均为 installAlienationAdvanced.js）

- 词条说明：8（hollow）、9（lifelink）、14（scapegoat）；绑定词条表 6（boundKeys）。
- lockParty 包装 61-77：记 referenceHp／referenceMp（rawParam）、originalHp／originalMp，绑定队友；73 连命合池，74 嫁祸绑保护者（护盾清零、生命按比例），75 空壳换护盾。
- A.syncPools 46、A.setLife 47、A.referenceParam 49、param 包装 56-59（空壳生命上限 1）。
- shieldLoss 94、hpChange（gainHp 包装）95-101、A.syncRelations 103-105、setHp 包装 107、regenerateHp 包装 108-109、regenerateMp 110、gainMp 111-112、addShield 包装 114-115。
- A.damageTarget 117、itemHit／itemEva／itemCri／makeDamageValue 118、executeDamage 119-122、apply 123（保护者目标后同步）。
- skillHpCost／canPay／pay 126-128、evalDamageFormula 129（公式里的生命上限、嫁祸的生命读参照）。
- endAction 185（同步）、revive 195、endBattle 196（空壳还原、解除池与保护者）。
- O-108 依据：`Olivia_BattleSysOTB.js:2164` 定义 `Game_Battler.prototype.revive`，盖过 Adv:195 包在 `Game_BattlerBase.prototype.revive` 上的复活包装。参照探针实测：lifelink 例最后一步复活后 a 生命 1、b 仍倒下（池为 0）；scapegoat 例保护者已倒下，a 照样复活到 1 血。

## 重制落点

- `alien_battle.gd` 文末「期二②」一节：`setup_life`（锁队时）、`end_life`（结束时）、`hollow_param`、`sync_pools`、`set_life`、`sync_relations`、`_shield_loss`、`route_life_gain`、`after_gain`、`routes_set_hp`／`routes_regen`、`route_hollow_mp`、`blocks_life_shield`／`clamp_hollow_shield`、`damage_target`、`route_revive`、开关 `o108_life_revive`。`STATUS_AFFIXES` 加了这三个，没有这些词条的战斗仍是一步早退。`lock_party` 在有状态类词条时调 `setup_life`；`end` 调 `end_life`；`param(0)` 走 `hollow_param`；`finish`（endAction）先 `sync_relations`。
- `battle_logic.gd`：`_apply`（嫁祸：命中、闪避、暴击、伤害计算、执行生命伤害、结果槽都改用 `dt = XAlienBattle.damage_target(...)`，改过时之后同步）；`_regenerate`（特殊角色的生命再生退回后改走 `gain`，空壳的法力再生变护盾）。
- `resource_context.gd`：`gain`（`route_life_gain`、`route_hollow_mp`，末尾 `after_gain`）、`set_resource`（`routes_set_hp` 时改走 `gain(差值)`）。
- `battler.gd`：`add_shield`（嫁祸拒收、空壳护盾封顶）、`remove_state`（阵亡状态的复活走 `route_revive`）。
- 测试 `xiyou_alien_affix.gd`：regen、revive 两种步骤；回满前先解掉 setup 那次锁队（原版是回满后才 lockParty，而且只锁一次）；`o108.*` 两项。

## 验证

- 专项 `xiyou_alien_affix` **674/674**（期二② 五例逐步对照，对照时 O-106、O-108 都关；`o108.lifelink_revive_pool`、`o108.scapegoat_no_revive` 开时检查）。
- 同步：`同步正式西游.py --accept-additions` 通过。拿主工作区的 alien_affix.json 当基线核过：旧 7 例逐项不变，只多了 5 例，hostScope 只是描述文字。写接受单后第二次同步：「新增用例、显式接受 1 条既有用例改变，已接受（不登记）」，退出码 0。同一轮里 race_battle.json 49→51 是 main 带进来的悟空用例，按只增接受。
- 选测（不跑全量，场景名都写全）：40 个场景全过，退出码 0，没有偶发，墙钟 506 秒。名单：`xiyou_actor_p0`、`xiyou_alien_affix／battle／config／workshop`、`xiyou_battle` 及 `xiyou_battle_*` 共 8 个、`xiyou_battleback_save`、`xiyou_boss_*` 6 个、`xiyou_combat`、`xiyou_determinism`、`xiyou_formula_*`／`xiyou_formulas` 5 个、`xiyou_module_hooks`、`xiyou_param_states`、`xiyou_regen_popup`、`xiyou_review_regressions`、`xiyou_shield`、`xiyou_state_*` 5 个，再加 `xiyou_rules` 难度 1 四段（改了 `_apply` 伤害路径）。

## 待交叉核查（核心文件，请沙僧重点核）

- `battle_logic.gd` `_apply`：嫁祸改目标的范围（只换生命伤害结算，状态效果、TP 获得、阵亡判定仍对 t），以及 `XRaceBattle.before_hp／after_hp` 改传保护者。
- `battle_logic.gd` `_regenerate`：只对 `routes_regen` 为真的角色（连命、嫁祸、空壳、舍身、绝缘）退回再生改走 `gain`；原版对所有战斗者都这样走，普通角色结果相同，所以没改。
- `resource_context.gd` `gain`／`set_resource`，`battler.gd` `add_shield`／`remove_state`。
- `alien_battle.gd` 的 `_hp_resolving`／`_death_sync` 两个计数（照原版 hpResolving／_alienDeathSync）。

## 优化登记行（请唐僧登记进 03_再刷重制_Godot/00_设计/优化登记.md）

| O-108 | 异化连命、嫁祸的复活照词条说明（XAlienBattle.o108_life_revive，alien_battle.gd `route_revive`，battler.gd `remove_state`） | installAlienationAdvanced.js:195 把复活包装挂在 Game_BattlerBase.prototype.revive，Olivia_BattleSysOTB.js:2164 自己定义的 Game_Battler.prototype.revive 盖过它：连命者复活只回 1 血，生命池仍是 0（下次同步又变 0 血却没倒下）；嫁祸者的保护者已倒下仍能复活（alien_affix_probe lifelink／scapegoat 例最后一步） | 连命复活把池回到复活者生命上限的 10%（两人一起起来）；嫁祸的保护者倒下时不能复活 | 词条写明的规则因插件加载顺序失效，还会留下 0 血活着的角色 | `XAlienBattle.o108_life_revive = false`（xiyou_alien_affix 对照时关、o108.* 两项开时验证） | Claude（八戒_83） | 待用户决定 |

## 没做（留给后面）

- 期二（可砍，本期没做）：绝缘对云裳 wake／addActions／freeGift（Adv:194）；疫囊者在阵亡 clearStates 时保留状态；囚厄、绝缘对 clearBuffs 的保留（重制阵亡时直接清零）。
- 技能生命消耗（Adv:126-128：空壳用护盾付、连命从池扣、嫁祸由保护者付）：重制目前没有技能生命消耗，不涉及。
- 公式帧里嫁祸者的 `hp` 读参照（Adv:129）：重制公式读的是同步后的显示生命，和原版只有取整差别，没做。空壳的生命上限在公式帧（伤害计算整段）里读参照，原版只在 evalDamageFormula 里读。
- 锁队时绑定配置失效的检查（Adv:62：队友不在场、已倒下、被重复绑定时把装备放回背包并提示）：没做。重制在绑定队友缺席时跳过合池／保护者。期二①的舍身也一样。
- 行动外的扣血：腐蚀 `XAlienBattle._lose_hp` 直接写生命，没走生命池和保护者（原版走 gainHp）。另外公式副作用等别的直接写生命的地方也没接。

## 交接板

- 下一步：异化词条后续批次（拟态、无面、缄默、侵蚀、吞器、夺舍、献祭、暴食等还没移植）；上面「没做」里的期二三条可以并进以后某期。
- 用户试玩说明：带空壳、连命、嫁祸异化武器出战时，这三个词条现在会生效。
- 需要用户决定：O-108（连命、嫁祸的复活照词条说明，默认开，可关回原版）。

## 进度账

- 异化词条效果：已移植 6 个 → 9 个（加空壳、连命、嫁祸），依据：五例参照逐步对照通过。

## 可优化（流程／工具／效率）

- 已做：探针加了 regen（onTurnEnd 前先清掉 `BattleManager._subject`，免得把上一个行动者当成外来来源）和 revive 两种步骤，以后的生命类词条可以直接用。
- 建议：在车道工作树里手动把探针输出拷进 `generated/oracle` 跑专项以后，同步就拿它当基线，测量变化（这次是 hostScope）就看不出来了。本期是把主工作区的 oracle 放回来再同步才拿到摘要。可以让同步在工作树里固定拿主工作区的 oracle 当基线比较，或者在 `mv_oracle/README.md` 写明「先同步再跑专项，别手动拷」（收益：少一轮同步；归维护工具的车道）。
- 建议：zsh 不按空格拆变量，`$N` 当场景名列表会变成一个参数，并行测试就 0.2 秒失败退出。车道须知或 `并行测试.py` 的用法说明可以给个现成写法（如 `${=N}`，或者支持 `--names-file`）（收益：少踩坑；归维护工具的车道）。

## 本分支提交

- deafd753 WIP：空壳、连命、嫁祸实现，O-108，探针三例，专项 612/612
- fead439a WIP：舍身／绝缘回合末再生两例，专项 674/674，同步接受单
- （本提交）交付单，可合并

临时输出已清理：本会话 scratchpad 里的测试日志、计时文件和同步日志都已删除。同步备份在 `04_验证/本地结果/自动同步/`，属于工具的正常产物，留着。
