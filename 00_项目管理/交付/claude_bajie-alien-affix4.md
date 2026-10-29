# 交付：claude/bajie-alien-affix4

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_83）
- 状态：可合并（期一；期二没开工，见「期二交接」）
- 本期：①期一「生命池补漏」：行动外的扣血走生命池与保护者，顺带锁队配置检查（已做）。②期二「异化第③批·技能表与投影类」：**本会话没开工**，开工方案见「期二交接」。从 claude/bajie-alien-affix3（5a289290）切出，中途合过一次 main（9fe6abb1）。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化生命池补漏：行动外扣血、锁队配置检查（dev.待定）

- **内容**：
  - 腐蚀每回合末扣 2% 生命、镜骸反噬，原版都经 gainHp。现在对连命、嫁祸、空壳、舍身、绝缘的角色照 hpChange 结算：连命扣池，嫁祸由保护者付，空壳先吃护盾。接点是新函数 `XAlienBattle.gain_hp_outside`，`_lose_hp` 先走它。
  - 锁队检查（Adv:62）：异化装备配置失效时卸下放回背包，提示「X的异化配置失效，Y已放回背包，请在工坊重新配置。」，本场不生效。失效指 `XAlienation.ready` 不过，或者绑定词条（连命、夺舍、舍身、嫁祸、献器）的队友不在场、已倒下、已被前面的人绑定。期二①的舍身也一样。
- **参照**：`alien_affix_probe.cjs` 加 battle.lifelink.corrosion／scapegoat.corrosion／hollow.corrosion／lifelink.invalid 四例，新增 tick 步骤（照 endTurn 包装调 A.tickCorrosion）。共 16 例全干净。同步接受单 `04_验证/测量接受/claude_bajie-alien-affix4.json`（hostScope 描述）。

## 直接写角色 hp 的地方（rg 清单）

| 位置 | 是什么 | 原版走 gainHp？ | 处理 |
| --- | --- | --- | --- |
| `alien_battle.gd` `_lose_hp` | 腐蚀（A.tickCorrosion）、镜骸反噬（A.finishAction） | 走（`t.gainHp(-n)`、`root.subject.gainHp(-n)`） | **已改**：先走 `gain_hp_outside` |
| `mv_event_core.gd` `_change_resource` 311 | 事件「增减生命」（Game_Interpreter.changeHp） | 走（`target.gainHp(value)`） | **没改**：这个文件归事件车道，已请示唐僧。提案是在 `var applied` 前加两行 `if XAlienBattle.gain_hp_outside(a, value): return` |
| `race_battle.gd` 296 血契、414 毒／伤害回响、446 治疗回响 | 种族祝福 | 不走（原版直接写 `_hp`：installNativeRaceRuntime 的血契、absorbRaceDamage、healEcho） | 照原版不改 |
| `race.gd` 182 | 换种族时按比例保留生命 | 不走（直接写 `_hp`，战斗外） | 不改 |
| `battle_logic.gd` `sequence_gain` 没有 resources 的旁路 | 战斗事件改敌人生命（battle_event_runner） | — | 只给敌人用，不涉及 |
| `battle_logic.gd` `_regenerate` | 回合末再生 | 走（regenerateHp 包装） | 上期已改 |
| `battle_scene.gd` 561 | 允许失败时战后复活到 1 | 战斗已结束 | 不涉及 |
| `alien_battle.gd` 生命池／保护者／空壳自己的同步写入 | A.syncPools／syncRelations 等 | 原版同样直接写 `_hp` | 照原版 |
| `power.gd`、`equipment.gd`、`orbs.gd`、`gear_upgrade.gd`、`xstate.gd`、`pet_capture.gd`、`battler.gd` 阵亡／复活／回满 | 战力预估、换装夹值、读档、捕捉、阵亡置 0 | 战斗外，或者是原版同样直接写的底层 | 不涉及 |

## 验证

- 专项 `xiyou_alien_affix` **756/756**。新加的四例逐步对照原版；另外临时撤掉 `_lose_hp` 的改动跑过一次，连命、嫁祸的腐蚀步骤有 8 项失败，说明用例能区分出这处改动。
- 同步：第一次报 hostScope「有变化」。拿备份里的旧 oracle 核对：旧 12 例逐项不变，只多了 4 例。写接受单后第二次同步：「新增用例、显式接受 1 条既有用例改变，已接受（不登记）」，退出码 0。同一轮里悟空的 param_cache_probe 是新探针，按只增接受。
- 选测（合过 main 之后、同步之后跑，不跑全量，场景名都写全）：**35 个场景全过**，退出码 0，没有偶发。名单：`xiyou_actor_p0`、`xiyou_alien_affix／battle／config／workshop`、`xiyou_battle` 及 `xiyou_battle_*` 共 8 个、`xiyou_battleback_save`、`xiyou_boss_*` 6 个、`xiyou_combat`、`xiyou_determinism`、`xiyou_formula_effects`、`xiyou_formulas`、`xiyou_module_hooks`、`xiyou_param_states`、`xiyou_regen_popup`、`xiyou_review_regressions`、`xiyou_shield`、`xiyou_state_*` 5 个、`xiyou_race_battle`（`_lose_hp` 旁边就是种族的伤害）、`xiyou_rules`（难度 1 首段，因为每场开战都会跑锁队检查）。墙钟 2935 秒，大半时间在排共用槽。

## 待交叉核查

- `alien_battle.gd` `gain_hp_outside`、`_lose_hp`、`eject_invalid`（`lock_party` 开头调用；每场开战都跑，只扫出战角色的装备）。
- 锁队检查在测试里会跑两次（setup 一次，测试回满后又 `open` 一次）。第二次只剩已通过检查的装备，结果不变。

## 没做（留给后面）

- 事件「增减生命」的接点：等唐僧决定（见清单）。
- 期二①的三条（云裳 wake／addActions／freeGift、疫囊者阵亡保留状态、囚厄／绝缘对 clearBuffs 的保留）：本期没顺路，继续留着。
- 锁队检查的「已倒下」「重复绑定」两种情况没有参照用例（要三人队或开战前倒下），只对照了「队友不在场」。

## 期二交接（异化第③批·技能表与投影类）

本会话上下文到 34% 就要接力（规则 40%），期二的读码量大，所以没开工，留给新会话从本分支接着做：

- **建议这期做**：祸祝 blessing、恶愿 wish、逆祷 prayer。三个都是「行动道具投影」（`Game_Action.item` 换成投影后的技能），共用一套投影接点，祸祝、恶愿还共用 templates.blessing／wish（7100）和 statePairs。原版依据见期一交付单（git 里 `00_项目管理/交付/claude_bajie-alien-affix-354c33.md` 的词条表）：祸祝 Aff:42-46，逆祷 Aff:22、42-62，恶愿 Adv:176-181。如果额度宽裕，第四个加缄默 silence（Adv:130-149，费用与封印，接点不同，可以单独一批）。
- 先查重制的行动道具从哪里取（`battle_logic.gd` 的 `act`／`_apply` 和 AI 选技），投影要在命中、目标、伤害、效果、名字显示各处都生效；Aff:5 的云裳 transferDebuffs 登记属于云裳侧，随祸祝、恶愿一起看。
- 做法同前两批：探针补用例（合成技能用 `Object.assign` 改原对象），STATUS_AFFIXES 早退把新词条算进去，原版不合理处登记 O-109 起。

## 可优化（流程／工具／效率）

- 已做：探针加了 tick 步骤（行动外的腐蚀结算），以后行动外扣血的用例可以直接用。
- 建议：手动把探针输出拷进 `generated/oracle` 跑专项以后，同步就把它当基线，测量变化看不出来（上期踩过）。本期改成跑完专项就把基线拷回去，同步才拿到 hostScope 的摘要。可以给 `并行测试.py`／专项加一个「指定 oracle 目录」的开关，或者让同步固定拿主工作区的 oracle 比较（收益：少一轮同步；归维护工具的车道）。

## 本分支提交

- 67fc8522 WIP：生命池补漏（腐蚀、镜骸反噬走 gain_hp_outside），探针三例
- 23d5861c WIP：锁队配置检查，探针一例
- （合并 main 9fe6abb1）
- （本提交）交付单、接受单，期一可合并

临时输出已清理：本会话 scratchpad 里的测试日志、oracle 副本和同步日志都已删除。
