# 交付：cc/pro-qiyin-data

- 车道／工作者：天启篇·七印祭坛装备数据层／cc（Pro，云端项目线程「做七印祭坛装备数据层」）
- 状态：可合并
- 车道路径：无（云端容器；只新增文件，不改切片、转换器、探针，不用同步）

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇：七印祭坛装备的只读数据层（dev.待定）
- 起因：Kyo 11-11 派单，给天启篇「七印祭坛」先做数据：七套套装（每套 6 件，共 42 件）、13 把毕业武器、5 件神器。只加新文件，不接战斗、掉落、界面，不改原版数据库。
- 新增 `modes/xiyou/tianqi_data/qiyin_gear.json`（表头 `draft: true`，数值是占位）：
  - 七印按揭开顺序 bai 白、hong 红、hei 黑、hui 灰、xun 殉、zhen 震、mo 默；六个部位 head／body／hands／waist／legs／feet，装备类型号开工核过 `XTianqiGear.ORDER`，与派单一致（头部 3、盔甲 4、护手 6、腰带 8、裤子 5、鞋子 7）。
  - 套装：神话、80 级（31、32 层守层者首杀那件 `first_kill_level: 75`）、不分甲种；每套 6 件，件名先占位成「套装名·部位」（头、甲、手、腰、裤、鞋，如「胜而又胜·头」）；2／3／5 件各一档；词条照词条稿 v0.3 防具组、四阶、三槽；成色权重 普通 50、上品 30、极 20；真印全极、底子 ×1.1。
  - 毕业武器：神话、80 级、`base_mult: 1.1`；词条兵器组、四阶、三槽；前六印每印一个流派两类，默印「不立文字」随机类（`type: null`、`type_random: true`）；每印的流派印记（`mark`）与真印追加（`true_extra`）放在 `schools`，每把的独有效果放在 `weapons[].effects`。
  - 12 个武器类：弓弩 bow、暗器 hidden、剑 sword、斧 axe、枪械 gun、拳套 fist、太刀 katana、匕首 dagger、钝器 blunt、矛 spear、法杖 staff、书 book。**`wtype_id` 全部留 null，接入时按原版 System.weaponTypes 填**（云端读不到原版 System）。
  - 神器 5 件（bow_crown 弓与冠、great_sword 夺和大刀、scales 天平、grey_scythe 灰镰、seven_seal_scroll 七印书卷），`artifact_rule`：类型 17、全队同时生效 1 件；每件有 `effects` 和 `costs`。
  - 效果都写成 `{code, 参数…, text}`；百分比参数写整数百分数（20＝20%），倍数写倍数。全部效果码和含义列在 `_note.effect_codes`（见下「效果码清单」）。
  - 数值好看：设计数值不含 4；豁免键 `version`、`order`（印的编号）、`etype`（类型号）、`affix_tier`（词条阶）、`count`（件数／揭几条）、`first_kill_floors`（层数）。
- 新增读表类 `modes/xiyou/core/tianqi_qiyin_gear.gd`（`XTianqiQiyinGear`，照 `XTianqiBalance` 缓存＋`reload()`）：`seal_keys`、`seal`、`parts`、`part_etype`、`grade_weights`、`set_rule`、`set_of`、`set_bonus`、`weapon_rule`、`weapon_types`、`school`、`weapons`、`weapons_of_seal`、`weapon_of_type`（认类键或中文类名）、`weapon`、`artifact_rule`、`artifacts`、`artifact`、`effect_codes`、`used_effect_codes`、`nice_number_violations`。
- 新专项 `tests/xiyou_tianqi_qiyin_gear.tscn`：234 项（七印齐与顺序；每套 6 件、部位不重不漏、类型号对上 ORDER、2／3／5 三档；42 件名不重；13 把、名字与键不重、前六印各两类、12 类不重不漏、默印一把随机类；5 件神器、类型 17；效果码登记与使用一一对应、每条有 text；不含 4）。
- 玩家可见：无（只有数据，还没接进游戏）。
- 未完成／已知问题：效果码只是数据约定，战斗里还没有实现；`wtype_id` 待填。

### 效果码清单

| 效果码 | 含义 | 用在 |
| --- | --- | --- |
| dot_dealt_pct | 自己施加的持续伤害 +value% | 白印 2 件 |
| dmg_per_target_debuff_pct | 目标每有一种减益伤害 +value%，最多 +max% | 白印 3 件 |
| dot_extra_tick | 回合结束时自己挂的持续伤害再结算 times 次 | 白印 5 件 |
| aoe_skill_dmg_pct | 群体技能伤害 +value% | 红印 2 件 |
| kill_stack_dmg_pct | 每击倒一个敌人本场出伤 +value%，最多 max_stacks 层 | 红印 3 件 |
| kill_extra_action | 每回合前 per_turn 次击倒后再行动一次 | 红印 5 件、灰印真印、夺和大刀 |
| skill_cost_pct | 技能消耗 +value%（负数少耗） | 黑印 2 件 |
| weight_stack | 「砝码」叠层与消耗 | 黑印 3 件 |
| weight_full_crit | 一次用掉 stacks 层必暴，暴伤 +crit_dmg_pct% | 黑印 5 件 |
| low_hp_target_dmg_pct | 对生命低于 below_pct% 的敌人伤害 +value% | 灰印 2 件 |
| low_self_hp_dmg_pct | 自己越残伤害越高，最多 +max% | 灰印 3 件 |
| cheat_death | 免死留 hp 点、之后 turns 回合 +dmg_pct%、每场 per_battle 次，except 列的即死无效 | 灰印 5 件 |
| max_hp_pct | 最大生命 +value% | 殉印 2 件 |
| guard_lowest_ally | 替生命最低的队友承受 share_pct% 伤害 | 殉印 3 件 |
| judgment | 「判决」＝最大生命 max_hp_pct%，不吃增伤、无视防御；trigger on_hit／on_attack | 殉印 5 件、殉流派印记 |
| element_dmg_pct | 元素伤害 +value% | 震印 2 件 |
| element_switch_stack | 换系叠层，每层 +per_stack_pct%，最多 max_stacks | 震印 3 件 |
| skill_double_cast | 每 every_turns 回合下一个技能放两次 | 震印 5 件 |
| heal_shield_pct | 治疗、护盾量 +value% | 默印 2 件 |
| support_ally_dmg_taken_pct | 加增益／治疗时对方受伤 +value%，turns 回合 | 默印 3 件 |
| grant_skill_silence_all | 附带技能：敌全体沉默、我方下回合技能不耗魔法和 TP | 默印 5 件 |
| plague_stack | 「疫」叠层 | 瘟流派印记 |
| plague_can_crit | 「疫」可以暴击 | 瘟真印 |
| extra_hits | 攻击次数 +value | 战流派印记 |
| combo_hit_ramp_pct | 每多一段后面段 +value% | 战流派印记 |
| overflow_hits_redirect | 击倒时剩下的段转给另一个敌人 | 战真印 |
| single_action_dmg_pct | 本回合只出手一次时 +value% | 量流派印记 |
| ignore_def_pct | 无视 value% 防御 | 量真印 |
| execute_ramp | 目标每损失 per_lost_pct% 生命伤害 +value% | 终流派印记 |
| judgment_mult_high_hp | 生命高于 above_pct% 时判决 ×mult | 殉真印 |
| star_fall | 落星：chance_pct% 几率，全体 dmg_pct% 随机元素伤害 | 震流派印记 |
| star_fall_weakness | 落星必打弱点系 | 震真印 |
| normal_attack_as_skill | 普攻算技能 | 无字流派印记 |
| normal_attack_heal_lowest | 普攻后给最残队友回这次伤害 heal_pct% | 无字流派印记 |
| silenced_normal_attack_dmg_pct | 被沉默时普攻 +value% | 无字真印 |
| plague_pierce | 「疫」满 at_stacks 层时穿到下一个敌人，带 carry_pct% 层 | 白虹贯日 |
| plague_spread | 回合结束「疫」向旁边各传 per_turn 层 | 病从口入 |
| full_plague_heal_taken_pct | 满层目标受治疗 +value%（负数减） | 病从口入 |
| hit_count_burst | 每累计 every_hits 段，下次行动对全体各补 bonus_hits 段 | 止戈 |
| last_hit_mult | 最后一段 ×mult | 大刀阔斧 |
| overkill_carry | 最后一段溢出伤害落到下一个敌人 | 大刀阔斧 |
| mp_dump | 用光魔法，每 per_mp_pct% 最大魔法 +dmg_pct% | 一发入魂 |
| idle_charge | 上回合没出手时这一击 +dmg_pct% | 一力降十会 |
| target_lose_action | 目标下回合少动 count 次（每目标每场 per_target_per_battle 次） | 一力降十会 |
| kill_chain_slash | 打倒后再斩另一个（dmg_pct%），chain 可连 | 送行 |
| ally_followup_execute | 队友攻击后目标低于 below_pct% 自动追刀，每回合 per_turn 次 | 补刀 |
| judgment_lost_hp_ramp | 每损失 per_lost_pct% 生命，判决加最大生命 add_max_hp_pct% | 当头棒喝 |
| sacrifice_hp | 献出 hp_pct% 当前生命：判决 ×judgment_mult，给最残队友等量护盾 | 以身饲虎 |
| star_moon | 每 every_stars 颗星下一颗成「陨月」×mult | 危楼 |
| star_pages | 集满 kinds 系，敌全体元素抗性 +value%（负数降），turns 回合 | 天书 |
| random_unique | 揭开时从 pool 随机刻一条独有效果 | 不立文字 |
| single_skill_repeat | 单体技能 chance_pct% 再放一次（dmg_pct%） | 弓与冠 |
| skill_dmg_pct | 技能伤害 +value% | 天平 |
| execute_normal | 普通敌人低于 below_pct% 直接处决 | 灰镰 |
| boss_low_hp_dmg_pct | 首领低于 below_pct% 时伤害 +value% | 灰镰 |
| reveal_rift_rule | 开战从七个里副本规则随机揭 count 条，只对 target 生效 | 七印书卷 |
| heal_taken_pct | 受到的治疗 +value%（代价） | 弓与冠 |
| dmg_taken_pct | 受到的伤害 +value%（代价） | 夺和大刀 |
| skill_cost_mult | 技能消耗 ×mult（代价） | 天平 |
| no_revive | 不能被复活（代价） | 灰镰 |
| reveal_luck | 每场只揭 count 条、看运气（代价说明，无额外判定） | 七印书卷 |

## 交接板

- 下一步：七印祭坛接入（掉落、套装件数计数、效果码在战斗里实现、神器栏白名单加这 5 件）时以 `XTianqiQiyinGear` 为单一来源；接入前按原版 `System.weaponTypes` 填 12 个 `wtype_id`。
- 用户试玩说明：无（本轮没有玩家能看到的变化）。
- 需要用户决定：无（件名「套装名·部位」是占位，Kyo 之后可以改；数值都是 draft）。

## 进度账

- 天启篇扩展账：七印祭坛「数据层」完成；接入战斗、掉落、界面未开始。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 新专项 `xiyou_tianqi_qiyin_gear`：234/234（云端容器，Godot 4.7.2 headless；不用转换产物）。
- 同目录的 `xiyou_tianqi_balance`：85/85（确认没碰到它）。
- 反向验证（改表→跑专项→用备份字节还原）：设计数值改成 4、黑印护手类型号改成 5、白印少一件、两把武器同一类、效果码改成没登记的、白红两印对调、少一件神器，各自都掉 1～3 项，还原后 234/234。
- 没跑：`选测.py`／`工具回归.py`／全量检查。本分支只新增一个数据表、一个没人引用的读表类和它的专项，不改任何已有文件；`工具回归.py` 在云端因没有 zsh 固定有 3 项失败，跟本分支无关。
- 新脚本的 `.uid`（`tianqi_qiyin_gear.gd.uid`、`xiyou_tianqi_qiyin_gear.gd.uid`）按派单「只加点名文件」没有提交，Mac 上导入时会自动生成，总装合并后需要的话一起提交。

## 待交叉核查

- 乙档：`tianqi_data/qiyin_gear.json` 与派单表格逐条对照（效果数值、件数档、流派、武器类归属）；`core/tianqi_qiyin_gear.gd`；`tests/xiyou_tianqi_qiyin_gear.gd`。

## 本分支提交

- （本提交）七印祭坛装备数据层＋专项＋交付单
