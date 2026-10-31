# 交付：claude/bajie-alien-leftover

- 车道／工作者：C 规则／八戒（Claude，八戒_91，Opus／medium）
- 状态：可合并
- 本分支从 claude/bajie-warehouse 末端 80e6ab99 切（唐僧交代），带着星级仓库期一的提交；请在 bajie-warehouse 之后合。

## 现状核对（交接板「异化没做（八戒 dev.206／208／209）」与 dev.210 新增，逐条对冻结 v0.28 installAlienation*.js）

交接板这一条是 dev.210 时写的，之后 dev.221（异化补漏，bc987564）与 O-121 已做掉大半，交接板没跟着改。逐条：

| 条目 | 原版出处 | 现状 | 依据 |
| --- | --- | --- | --- |
| 绝缘 setHp | Adv:107 | 已做 | `XAlienBattle.routes_set_hp`（含 insulation），`resource_context.set_resource`；参照 `battle.insulation.sethp`（dev.221） |
| 绝缘对云裳 wake／addActions／freeGift | Adv:194 | 原版有、重制无此机制 | 重制没有云裳战斗运行时（赠行、储行、唤醒都没有，`alien_battle.gd` 1620／1754 注释）；云裳移植时一并接，只记不做 |
| 疫囊者阵亡保留状态 | Aff:75（protectedState） | 已做 | `battler.gd` 阵亡分支 `XAlienBattle.dying`＋`keeps_state`；参照 `battle.pest.death`（dev.221） |
| 囚厄／绝缘 clearBuffs 保留 | Adv:175 | 已做 | `XAlienBattle.keeps_buff`；参照 `battle.jail.death`、`battle.insulation.death`（dev.221） |
| 技能生命消耗 | — | 重制无此机制 | 只记不做（派单交代） |
| 事件增减 MP（312）：空壳回蓝变护盾、绝缘拒收外来回蓝 | Adv:111-112 | 已做（饕餮无效一并） | `mv_event_core.gd` 312 分支 `XAlienBattle.gain_mp_outside`；参照 `battle.hollow.mp`、`glutton.mp`、`insulation.mp`（dev.221） |
| 锁队检查「已倒下」「重复绑定」缺参照 | Adv:62 | 已做 | 参照 `battle.lifelink.dead`、`battle.sacrifice.twice`（dev.221） |
| 自动战斗／智能 AI／挂机选技估值按原技能 | Codex_SmartBattleAI | 已做 | O-121（`XSmartAI.o_projection`，回退支已按审查第 2 期 D1 改成原版混读）；自动战斗与挂机都经 `auto_battle_action`→`XSmartAI.choose` |
| 逆祷者反击没投影 | Runtime invokeCounterAttack | 已做 | `battle_logic.gd _invoke` 读投影；O-119 反击治疗不给敌人；参照 `battle.prayer.counter` |
| 逆祷借熟练度算治疗 | Aff:23 | 不涉及 | 重制熟练度恒 0（`XBattler.skillMasteryLevel`），取 min 不变（`alien_battle.gd` 662、1567 注释） |
| 投影后 is_attack 按 id 判 | rpg isAttack 比 item() 对象 | 已做 | `battler.gd is_attack`；参照 `battle.prayer.repeat`（攻击次数追加不加） |
| 逆祷阻断没接 gainHp／setHp 行动帧 | Runtime 98-101 | 已做 | `XAlienBattle.frame_blocks_hp`，`resource_context` gain／set_resource；自定义状态效果压来源帧；参照 `battle.prayer.dot` |
| **烈变加成没接行动帧里的 gainHp／setHp** | Runtime 96、98、100（wrapHp：帧为 active、不在 executeHpDamage 里时 `v=-outgoing`） | **本期做掉** | 见变更记录草稿第 1 条 |
| withFrame 收尾兜底（帧里生命被扣、来源是逆祷者对敌人→补回并去阵亡） | Runtime 25 | 不需要 | 重制帧里的扣血只有 `resource_context` 一条路，`frame_blocks_hp` 已在入口拦下；行动序列 HP±（`sequence_gain` 无上下文时直写）在原版也不在帧里 |

审查第 2 期 D2／P3（蚀术命中 `used` 与原版 testApply：目标活着、技能对阵亡友方时原版不算命中）不在派单清单里，本期没做，列进下期。

## 变更记录草稿

## 2026-10-31 【Claude·八戒_91·未经审查】异化遗留清账：烈变加成接行动帧里的扣血；遗留清单核对（dev.待定）

1. **烈变／小怪异化加成接行动帧里的扣血**（Runtime 96、98、100，`wrapHp`／`setHp` 包装）：原版异化敌人的伤害加成（Boss 烈变 ×1.15、小怪异化 ×1.1，`outgoing`）不只乘在 executeHpDamage 上，行动 apply 帧里不经 executeHpDamage 的扣血（效果「恢复 HP」负值、技能备注里的 `b.gainHp(-3000)` 如净化之雷 857／4013）也乘。重制原先只在 `battle_logic.execute_hp_damage` 乘。现在 `resource_context` 的 gain／set_resource 在逆祷阻断之后加一支：不在 executeHpDamage 的 settled 段里时调新的 `XAlienBattle.frame_outgoing`（只认 apply 帧：支援、自定义状态效果这些空道具帧不算；反击、派生行动由 `outgoing` 的 `_active` 排除）。
   - 参照：`alien_affix_probe.cjs` 加 `flare.gain`（Boss 烈变）、`flare.gain.mob`（小怪异化）两例（共 56 例），敌人 0 直接写成异化变体（同 mirror 的写法），先用效果「恢复 HP −10%」，再普攻（对照：executeHpDamage 那次不能多乘）：原版 8340→7381（834×1.15＝959）、7423（×1.1＝917）。
   - 反向验证：`frame_outgoing` 直接返回原值 → 两例的效果步与其后普攻步共 4 项失败。已还原。
2. **遗留清单核对**：交接板「异化没做」一条逐项对原版核对，见本交付单「现状核对」表；除上面一条外都已在 dev.221／O-121 做掉，或重制没有对应机制（云裳、熟练度、技能生命消耗）。

## 交接板

- 下一步：交接板「异化没做（八戒 dev.206／208／209）」整条可以删掉，换成一句：「异化遗留：绝缘对云裳 wake／addActions／freeGift 等云裳移植时接（重制无云裳战斗运行时）；审查第 2 期 D2／P3 蚀术 used 未改。」
- 用户试玩说明：异化 Boss（烈变）与异化小怪用「扣生命」类效果（不是普通伤害公式）时，伤害也带上 15%／10% 加成，同原版。
- 需要用户决定：无。

## 优化登记草稿

无（本期没有新的 O 号）。

## 进度账

- 异化：遗留清单清完（剩云裳接点等云裳移植）。

## 可优化（流程／工具／效率）

- 建议：交接板「下一步」里各车道的遗留清单在后续交付做掉后没人回头删，这次整条派单其实只剩一项。总装合并时可以让合并工具把交付单「交接板」节里「删掉某条」的指示提醒出来（归工具车道）。

## 下期清单

- 审查第 2 期 D2／P3：`battle_logic.gd apply` 的 `used` 改成 `(scope in [9, 10]) == t.is_dead()`（原版 testApply），加蚀术选定复活类技能打活目标的参照例；改 battle_logic 前 rg 与悟空、白龙对一下。
- 云裳移植时：绝缘拒收外来 wake／addActions、绝缘者不吃 freeGift（Adv:194）。

## 待交叉核查

- `core/resource_context.gd`（gain／set_resource 各一支 `frame_outgoing`）、`core/alien_battle.gd`（新 `frame_outgoing`）。没改原沙僧核心文件（battle_logic／actor／battler／damage／xstate）。
- 探针 `alien_affix_probe.cjs`（`spec.flare`、两例）；`tests/xiyou_alien_affix.gd`（`flare` 摆法）。

## 验证

- 合 main（c758dd62，nezha-tools17，没碰探针／切片）后 `同步正式西游.py --accept-additions` 通过（「新增用例，已接受（不登记）」：alien_affix 54→56；events 5806→5808 是本分支带的星级仓库 Map041），留了产物指纹。
- 本机选测 19 个场景全过：`xiyou_alien_affix`（2037/2037）、`xiyou_alien_battle`、`xiyou_alien_config`、`xiyou_alien_workshop`、`xiyou_boss_output`、`xiyou_boss_output_context`、`xiyou_mira_battle`、`xiyou_race_battle`、`xiyou_smart_ai` 四份、`xiyou_state_effects`／`_tp`、`xiyou_rules`／`_d1b`／`_d1c`／`_d1d`、`xiyou_event_compare`。
- 反向验证：见变更记录草稿第 1 条。
- 没跑全量与非 Godot 检查。

## 本分支提交

- eab6787d 异化遗留①：烈变加成接行动帧扣血，探针两例
- fbb50c98 交付单（现状核对表）
- （本提交）交付单可合并
