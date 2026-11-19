# 交付：luiluu/t232

- 车道／工作者：C 规则·机制／cc（T232 七印击倒类效果在动作序列招和普攻上认不到击倒；追加：词条「斩获」同修、天启篇其他当场认击倒处盘点；Opus＋medium）
- 状态：可合并（R1 返修：小A 初审 P1×1 P3×2 已改）

## 一句话

动作序列招（转换后实际所有技能都带 `yepSeq`，普攻也是）打的过程中目标挂 IMMORTAL，0 血不倒、序列收尾才倒；七印 `after_apply` 当场用 `is_dead()` 认击倒，所以序列招上永远认不到。改成：这一击把挂着 IMMORTAL 的目标从有血打到 0 时先记成「待定击倒」（带这一击的溢出），`end_action` 开头（序列已收尾、该倒的已倒）再按 `is_dead()` 认。开关 `XTianqiQiyinEffects.SEQ_KILLS`（O-待定-1），关掉回到旧行为。

追加（协调同日）：词条「斩获」（`XTianqiAffixBattle.after_apply`）同病，实测属实，照同一办法修，单独开关 `XTianqiAffixBattle.SEQ_KILLS`（O-待定-2）；天启篇其他「当场 `is_dead()` 认击倒」的地方盘了一遍，见「盘点」节，没有别的要修。

## R1 返修（小A 初审 `T232_核_报告R0.md`）

- **P1-1**（盘点漏网）：`XTianqiSkills.after_apply` 调的 `_kill_grow`（击杀成长，11 张卡）、`_kill_tp`（击杀回 TP，5 张卡）当场看 `t.is_alive()`，16 张卡全是动作序列招，同病、实战从不触发。照同法修：规格条件都满足、目标挂 IMMORTAL 打到 0 血的记待定（`kpend`，按 种类＋出手者＋目标 去重），`end_action` 开头（行动帧还在，`kill_tp` 认得到）和 `_cast` 跑完追加释放的序列后各认一次，此刻倒了的照原来当场认的那条路再走；被救回、不死的不算；`begin_action` 清掉上次没收尾的。单独开关 `XTianqiSkills.SEQ_KILLS`（O-待定-3）。
- **重盘**：这次把天启篇所有「当场判死活」的写法都搜了，见下面「盘点（R1 重盘）」。新发现一处同病没修：**战真印「击倒后剩下的段转给别的敌人」（`overflow_hits_redirect`）在序列路上根本没接**（只在非序列 `execute` 里调），见「异议」。
- **P3-1**：`confirm_pending` 改用 `f.get("pending_over", {})`；待定记录带上记下时目标的「救回次数」（`XBattler.immortal_rescues`：挂 IMMORTAL 时 hp 从 ≤0 写成 >0 计一次，只计数、不参与结算）。记了待定以后又被救回过、再被不经 `after_apply` 的路子弄倒（序列 HP－、收尾后 ADD STATE 1）：击倒照算，旧溢出作废记 0；中途再挨致命一击的照最后一击重记（原来就这样）。
- **P3-2**：补状态抗死（挂带 TRAIT_STATE_RESIST 1 的状态）用例 `edge_state_resist_not_kill`；`edge_multi_kill` 去掉手动 `confirm_pending`，改看 `end_action` 自己认的击杀数；另补 `edge_rescued_then_dead_no_stale_overflow`（P3-1）。

## 独占文件（开工列）

- 改：`modes/xiyou/core/tianqi_qiyin_effects.gd`（`SEQ_KILLS` 开关、`after_apply` 末尾记待定、新 `confirm_pending`、`end_action` 开头调一次、文件头一行说明）
- 改（追加）：`modes/xiyou/core/tianqi_affix_battle.gd`（`SEQ_KILLS` 开关、`after_apply` 斩获那一行旁记待定、新 `_confirm_harvest`、`end_action` 开头调一次）
- 新：`tests/xiyou_tianqi_qiyin_seq_kill.gd／.tscn／.gd.uid`
- 改（R1）：`modes/xiyou/core/tianqi_skills.gd`（`SEQ_KILLS`、`_seq_pend`、`_confirm_kills`，`_kill_grow`／`_kill_tp` 把存活判断挪到规格检查之后、活着就记待定；`end_action` 开头、`_cast` 序列后、`begin_action` 清旧）
- 改（R1）：`modes/xiyou/core/battler.gd`（新字段 `immortal_rescues`，hp 写入时挂 IMMORTAL 从 0 救回计一次；不改任何结算）
- 改（R1）：`modes/xiyou/core/tianqi_qiyin_effects.gd`（`pending_over` 存 [溢出, 救回次数]、`confirm_pending` 用 get 兜底并认救回）
- 没改 `battle_logic.gd`、`action_sequence.gd`（IMMORTAL 的原版时序不动）。

## 先想一想（派单最后一条）

根子就是原版机制：YEP 行动序列 `immortal: targets, true` 先挂、收尾 `false` 才倒。但修法**不改原版行为**：IMMORTAL、倒下时机、随机数、日志一概不动，只是七印（天启篇自己的系统）在行动收尾多看一眼「谁倒了」。所以没 ask，直接做。

## 量清（验收 1）

专项打印 `QIYIN_SEQ_KILL_TABLE`，红印 5 件（击倒后再行动一次＋击杀叠层）打 1 血敌人：

| 出招 | 走哪条路 | 修前（开关关） | 修后（开关开） |
| --- | --- | --- | --- |
| 普攻 | 动作序列 | 目标倒了，但击杀计数 0、不再动 | 计数 1、再动 |
| 序列单体招 | 动作序列 | 同上 | 计数 1、再动 |
| 序列群体招（打倒 2 个） | 动作序列 | 计数 0、不再动 | 计数 2、再动 |
| 单段招（去掉 yepSeq） | 非序列 | 计数 1、再动（本来就对） | 同左 |
| 多段招（去掉 yepSeq，3 段） | 非序列 | 本来就对 | 同左 |
| 群体单段招（去掉 yepSeq） | 非序列 | 本来就对 | 同左 |

- 受影响的七印效果（都看 `f.killed`）：击倒后再行动一次（红印 5 件、灰真印、夺和大刀神器）、送行连斩、大刀阔斧溢出、红印 3 件击杀叠层伤害（`un.kills`）。实测溢出、连斩在普攻上修前都不出、修后都出。
- 现在库里没有不带 `yepSeq` 的技能（专项挑非序列招时一个都没挑到，只好拿序列招去掉 `yepSeq` 造），所以修前实际上**所有出招**都认不到。
- 追加类：七印自己的派生（连斩、横扫、再射、放两次、补刀）走 `logic.apply`，不挂 IMMORTAL，连斩「能一直连下去」看 `nx.is_dead()` 本来就对；派生里打倒的按原设计不回灌主行动（「派生不再触发派生」），本单没动。词条再释放、技能重构追加释放在七印 `end_action` 之后跑、七印行动帧已清，七印不认它们的击倒，修前修后一样（见「异议」）。

## 斩获（追加单）

- 实测（专项打印 `AFFIX_HARVEST_TABLE`，斩获 4 阶 9%，出手前魔法清 0，打 1 血敌人）：

| 出招 | 修前（开关关） | 修后（开关开） | 逐段结算开 |
| --- | --- | --- | --- |
| 普攻（序列） | 目标倒了，魔法 0（没回） | 回 90（最大魔法 9%） | 回 90 |
| 序列群体招（打倒 2 个） | 没回 | 只回一次 90 | 只回一次 90 |
| 单段招（去掉 yepSeq） | 回 90（本来就对） | 回 90 | 回 90 |

- 修法同七印：挂 IMMORTAL 被打到 0 血（这一击前有血）的目标记待定；`end_action` 开头（只在最外层行动、帧是本人的）有一个真倒下、出手者还活着就回一次。时机从「致命那一击当场」挪到「行动收尾」（序列招本来就要等收尾才倒），非序列招不变。
- 两个开关单独关：只关七印的，斩获照回（`harvest_普攻_on_qiyin_off`）；只关斩获的，七印照认（`qiyin_on_when_affix_off`）。序列里被救回不回（`harvest_rescued_none`），收尾真倒下回一次（`harvest_confirmed_end`）。

## 盘点（R1 重盘）：天启篇所有「当场判死活」的写法

**搜法**：`modes/xiyou/core/tianqi*.gd`（62 个）＋`gojo.gd`、`guardian_rework.gd`，搜 `is_dead()`、`is_alive()`、`hp <= 0`、`hp == 0`、`DEATH_STATE`、`state_ids.has(1)`、`logic.alive(`、`died`、`"collapse"`（`alive_members`／`dead_members` 天启篇里没有用到），按所在函数归组共 135 组；再对着 `battle_logic.gd`、`action_sequence.gd`、`resource_context.gd`、`battler.gd` 里调天启篇模块的地方，分清哪些函数会在**序列中途**（IMMORTAL 挂着）跑：`apply`（`before_apply`／`after_apply`）、`_apply_core`（`XGojo.after_apply`）、`execute_hp_damage` 和账本 `hp_damage`、`_apply_effect`（状态）、`resource_context._gain`、`XBattler.add_state`、序列 `_action_effect`。天启篇的 battle／ui／map 目录下的 `tianqi_*.gd` 只管显示，没有判死活。

判法：**收尾后才看（安全）**＝在行动收尾（`act` 里各模块 `end_action`／`after_action`）、回合首尾、战斗开始结束、AI 选招／选目标时看，序列已解除 IMMORTAL；**当场看（同病）**＝序列中途看、0 血挂 IMMORTAL 的目标被当成活着；**判不修**写理由。

### 当场看（同病）

| 位置 | 函数 | 情况 | 结论 |
| --- | --- | --- | --- |
| `tianqi_qiyin_effects.gd:506-518` | `after_apply` 击倒记录 | 七印击倒类效果认不到 | **已修**（O-待定-1，R0） |
| `tianqi_affix_battle.gd:500-508` | `after_apply` 斩获 | 斩获认不到 | **已修**（O-待定-2，R0） |
| `tianqi_skills.gd` `_kill_grow`、`_kill_tp` | `after_apply` | 击杀成长、击杀回 TP 认不到（16 张卡） | **已修**（O-待定-3，R1） |
| `tianqi_qiyin_effects.gd:425-430` `redirect`（`battle_logic.gd:2397`） | `execute` 非序列分支 | 战真印「击倒后剩下的段转给别的敌人」：只在非序列分支调；序列路 `_action_effect` 没接，0 血 IMMORTAL 目标也不算 `is_dead()`，剩下的段照打在 0 血目标上 | **没修，报协调另开单**：要在 `action_sequence.gd` 的段里改目标，牵涉序列画面、随机目标与 `segment_target`，超出本单（见「异议」） |
| `tianqi_qiyin_rule.gd:358-363` | `hp_damage` 战吼 | 按「此刻倒下人数」加伤，序列里 0 血的没算进 | 判不修（R0 已列，小A 同意）：口径是「此刻倒了几个」；改了同一招后几段伤害变 |
| `tianqi_alien_affix.gd:181-190` | `after_apply` 带毒 | 序列招打到 0 血的照样掷毒、取随机数 | 判不修（R0 已列，小A 同意）：改了挪随机流；被救回的少上毒 |
| `tianqi_skills.gd:1243、1245、1256` | `_on_hit`（`after_apply`）挂状态／叠层／随机挂一个 | 0 血 IMMORTAL 目标照样掷几率、挂状态 | 判不修：同「带毒」——挂在必倒的目标上无害，改了挪 `tianqi_skill_on_hit` 随机流；被救回的应当照挂 |
| `tianqi_plague_alien.gd:403-410` | `hp_damage` 腺体上毒、混乱掷几率 | 我方 0 血挂 IMMORTAL 的照样上毒、掷混乱 | 判不修：同上（敌人一方，挪 `plague_chaos` 随机流） |
| `tianqi_qiyin_effects.gd:477`（`_next_enemy`）、`491`→`547`（`_star_fall`）、`_random_enemy` 在 `after_apply` 里的用法 | 疫满层穿透、落星选目标 | 0 血 IMMORTAL 的敌人算「活着」，可能被选中（效果落在必倒的目标上浪费） | 判不修：改选目标挪 `qiyin_star` 等随机流、改结果分布；影响只是偶尔浪费一次，建议跟战真印一起另开单统一「此刻算活着」的口径（`XTianqiWeakAffix.legal` 已有 `immortal and hp <= 0` 的写法可抄） |
| `tianqi_qiyin_effects.gd:483、493` | `after_apply` 判决、一力降十会 | 0 血 IMMORTAL 目标算活着：判决照扣（`_lose_hp` 把 0 血的直接 `_die`，当场倒下、击倒当场认到，无害）；一力降十会每个目标每场一次的名额用在必倒的目标上 | 判不修：目标反正要倒，名额是按目标记的，不影响别的目标 |
| `tianqi_brand.gd:1113`、`681` | `sear_add`（`execute_hp_damage` → `sear_hit`）→ `trigger` | 我方被敌人序列招打到 0 血时灼痕满了，照样对这个必倒的角色开「发作」、弹一条字 | 判不修：角色收尾就倒，发作记录无实际效果；改了可能挪发作种类的随机流。列给另开单一起看 |
| `tianqi_war_alien.gd:314` | `clash_mult`（伤害计算） | 最后一只异化怪 0 血挂 IMMORTAL 时交锋加伤仍算 | 判不修：同战吼，「此刻在场」的口径 |
| `tianqi_death_alien.gd:479` | `hp_damage` 替身 | 0 血挂 IMMORTAL 的替身再挨段会再检查一次换人 | 判不修：第一下致命伤时序列与非序列完全一样（`value >= hp` 当场换人）；之后只会重复同一个不成立的条件 |
| `gojo.gd:681`；`tianqi_qiyin_effects.gd:353` | `after_apply` 茈「收」减速；`add_plague` 叠疫 | 0 血 IMMORTAL 敌人照挂减速、照叠疫 | 判不修：挂在必倒目标上无害，不取随机数 |

### 当场看（安全：看的是出手者、受击方存活或「这一击之前」）

| 位置 | 函数 | 为什么安全 |
| --- | --- | --- |
| `tianqi_qiyin_effects.gd:451、845、853` | `after_apply` 殉印反击、`hp_damage` 替队友挡、灰印免死 | 看的是我方受击者／挡的人此刻活着，0 血的再挨打不改结果 |
| `tianqi_qiyin_effects.gd:498` | `after_apply` 灰镰处决 | 0 血目标 `_lose_hp(t, t.hp=0)` 直接返回，无事 |
| `tianqi_qiyin_effects.gd:1014-1023` | `_lose_hp` | 0 血 IMMORTAL 的直接 `_die`（绕过 IMMORTAL 当场倒），之后的 `is_dead()` 当场认到 |
| `tianqi_qiyin_effects.gd:408、503、991` | `_lowest` 普攻回血、替挡选我方 | 选的是我方，自己的行动里我方不挂 IMMORTAL |
| `tianqi_trumpet.gd:485、550` | `hp_damage` 四号、`state_added` 三号 | 看受击的我方；`state_added` 只排除阵亡状态本身 |
| `tianqi_alien_affix.gd:163` | `hp_damage` 临终 | 第一下致命伤就判（`value >= hp`），与序列无关 |
| `tianqi_famine_alien.gd:372`、`tianqi_plague_alien.gd:415、439、447、517` | `hp_damage` 掠夺、挑衅混乱、`purge_blocked`、`forced_state` | 看出手者活着／状态号，出手者不挂 IMMORTAL |
| `tianqi_affix_battle.gd:487`、`599` | `after_apply` 吸血、`state_rate` | 看出手者活着；排除阵亡状态 |
| `tianqi_skills.gd:1061、1083` | `_reflect`（反弹） | 被反弹的是出手的敌人，不在自己的 IMMORTAL 目标里；0 血 `add_state(1)` 当场倒 |
| `tianqi_weak_b2.gd:99` | `settle`（治愈之歌结清） | 目标是被治的我方 |
| `tianqi_weak_affix.gd:458` | `legal`（引导者每段合法） | 已认 `immortal and hp <= 0`（批 0A） |
| `gojo.gd:609、624` | 无下限、自动反转 | 看我方受击者 |
| `tianqi_death_alien.gd:486` | `hp_damage` 替身选替死的我方 | 我方的行动里我方不挂 IMMORTAL（自己打自己的除外），选的是此刻真活着的 |

### 收尾后才看（安全）

| 文件 | 函数（行） |
| --- | --- |
| `tianqi_qiyin_effects.gd` | `start_turn` 285、`end_turn` 311-334、`begin_action` 378、`end_action` 586-642、`confirm_pending` 660、`_random_enemy` 在 `end_action` 里的用法（597、616） |
| `tianqi_affix_battle.gd` | `start` 268、`end_action` 529、540、`_confirm_harvest` 555 |
| `tianqi_skills.gd` | `_confirm_kills`、`_hp_equalize` 1400、`_self_heal` 1416、`_charge` 1453、`_ally_state` 1470、`_foe_drain` 1482、`_foe_states` 1525（都在 `end_action` 里）、`end_action` 1679-1748、`_cast` 1647（追加释放非序列路，每段前看）、`invoke_counter` 1789、`_guard` 1853、1861 |
| `tianqi_horsemen.gd` | `_check_kills`、`perform`、`_war_perform`、`_famine_perform`、`_devour`、`_lose_hp`（骑士自己的招走 `horseman_strike`，不挂 IMMORTAL）、`after_action`、`end_turn`、`lose_revive`、`_survive`、`_reinforce`、`_summon`、`war_extra_actions`、`_plague_turn_start`、`_next_minion`、`_death_pick`、`_pick_target`、`_alive_actors`、`_minion_alive`、`taunting`、`_zd_regen` |
| `tianqi_death_alien.gd` | `_alive_of`、`_zhongyan`、`doom_text`、`_kill`（自带解 IMMORTAL）、`_lift_dooms`、`_scan_deaths`、`decide_absorbed`、`start_turn`、`end_turn` |
| `tianqi_famine_alien.gd` | `_idx_of`、`hungry`、`ration_rate`、`start_turn`、`_refund_gold`、`grant_grain`、`end_turn` |
| `tianqi_plague_alien.gd` | `_idx_of`、`sick`、`finale`、`debuffs_of`、`refresh`、`_burst`、`_poison_tick`、`_taunters`、`end_turn`、`_spread` |
| `tianqi_war_alien.gd` | `spark_full`、`_apply_commander`、`_commander`、`extra_actions`、`after_action`、`_bomb` |
| `tianqi_brand.gd` | `start_turn`、`forced_action`、`perform`、`_back_ok`、`after_act` |
| `tianqi_gojo_trial.gd` | `_restore`、`decide`、`_sync_clash`、`end_round`、`check_awaken`、`defeat_line` |
| `tianqi_qiyin_dragon_run.gd` | `_put_reprieve`（`end_action` 里揭印）、`_check_cuts`、`start_turn` |
| `tianqi_qiyin_rule.gd` | `start_turn` 206-227 |
| `tianqi_rewards.gd` | `party_seal_tier`、`taunter`、`after_action`、`_random_enemy` |
| `tianqi_trumpet.gd` | `turn_begin` 393-399 |
| `tianqi_weak_affix.gd` | `active_keys` 156（选招） |
| `tianqi_weak_b2.gd` | `thunder` 178、`root_end` 242、296（`end_action`／行动收尾） |
| `tianqi_alien_affix.gd` | `start`、`end_turn` |
| `tianqi_alien_codex.gd`、`tianqi_alien_gear.gd`、`tianqi_money.gd`、`tianqi_elements.gd`、`tianqi_qiyin_look.gd` | 战斗开始／结束、技能角标、立绘，不在行动里 |
| `gojo.gd` | 435 `active_domain`、593 `overload`（敌人行动开始前判）、519、560（`finish`，行动收尾） |

## 验收逐条（卡上 5 条）

1. ✓ 见上表。
2. ✓ 各类出招都认到；边界：一招打倒多个（`序列群体招` 计数 2、`edge_multi_kill` 当场倒＋收尾倒混合）；不死目标（0 血不倒）不算（`edge_undying_not_kill`）；序列中途被救回不算（`edge_rescued_not_kill`）；打到 0→救回→再打到 0 只算一次、溢出按最后一次致命那一击、0 血上再挨的段不改溢出（`edge_twice_one_kill`、`edge_overflow_last_lethal`）。
3. ✓ PER_SEGMENT：专项用 `XBattleStream.start`＋`finish` 走交接线程，普攻、序列单体、序列群体、单段四类都和一次算完结果相同（`*_on_stream`）。新代码只在结算里读写七印本场数据，不碰场景树。
4. ✓ 随机流不变：新代码不取随机数、不改 IMMORTAL／倒下时机；七印只在天启篇档建数据（`legacy_no_store`：西游档序列普攻打倒照常、不再动）。`xiyou_determinism`、`xiyou_event_compare*` 四份全过；`mv_oracle/boot_check.cjs` 正常（db true、modulesFailed []）。没跑整份 `检查.sh --oracle`（车道不跑全量）。
5. ✓ 斩获见上节（普攻、序列群体、单段 × 开／关／逐段结算，救回、收尾倒下，两开关单独关）。七印开关 `SEQ_KILLS` 关：序列招回到旧行为（`off_seq_missed_*`、`edge_off_no_pending`），非序列不受影响；专项覆盖普攻、动作序列招（单体／群体）、非序列单段／多段／群体。

## R1 验收逐条（返修单 5 条）

1. ✓ P1-1：`XTianqiSkills.SEQ_KILLS`（O-待定-3）。专项 `SKILL_SEQ_KILL_TABLE`：关羽「青龙乱舞」521（击杀成长）开关关 成长 0、开 +1；「射虎」2586（击杀回 TP）关 +0、开 +30；逐段结算开着两项都同开关开；序列里被救回不回 TP（`skill_tp_rescued_none`）。两张都是动作序列招（`_fixture` 检查 `seq` 为真）。
2. ✓ 重盘见上「盘点（R1 重盘）」，每处标了「已修／没修另开单／判不修（理由）／安全」。
3. ✓ P3-1：见「R1 返修」节；`edge_rescued_then_dead_no_stale_overflow`（打到 0 记溢出 500 → 序列 HP＋救回 → HP－打回 0 → 收尾倒下：击倒算 1、溢出不落到下一个敌人）。
4. ✓ P3-2：`edge_state_resist_not_kill`（状态抗死，收尾不倒、不算击倒、不再动）；`edge_multi_kill` 只调 `end_action`，看 `un.kills == 2`。
5. ✓ `xiyou_tianqi_qiyin_seq_kill` 71/71、`xiyou_tianqi_qiyin_effects` 63/63、`xiyou_tianqi_skills` 245/245、`xiyou_determinism` 372/372（本机 `--headless --audio-driver Dummy`）。

## 变更记录草稿

## 2026-11-19 【cc·T232·未经审查】七印击倒类效果、词条斩获在动作序列招（含普攻）上认得到击倒（dev.待定）
- 原因：动作序列招打的过程中目标挂 IMMORTAL，0 血不倒，序列收尾才倒；`XTianqiQiyinEffects.after_apply` 当场 `is_dead()` 认不到。转换后所有技能都带 `yepSeq`，所以修前击倒后再行动、送行连斩、大刀阔斧溢出、红印 3 件击杀叠层在任何出招上都不触发（T018 猜、T230 实测）。
- 修法（`modes/xiyou/core/tianqi_qiyin_effects.gd`）：这一击把挂 IMMORTAL 的目标从有血打到 0 时记成待定击倒（连同这一击的溢出），`end_action` 开头 `confirm_pending` 按 `is_dead()` 认；不死、序列里被救回的不算；IMMORTAL 时序、随机流、日志不动。开关 `SEQ_KILLS`（O-待定-1）。
- 词条「斩获」（`modes/xiyou/core/tianqi_affix_battle.gd`）同病同法：序列招上打倒敌人修前不回血回魔，修后行动收尾回一次（一次行动仍只一次）。开关 `XTianqiAffixBattle.SEQ_KILLS`（O-待定-2），和七印的分开关。
- 天启篇其他当场认倒下的地方盘了一遍（交付单「盘点」），其余都在行动收尾以后看，没事；「战吼」倒下人数、「带毒」打 0 血目标两处拿不准，只列。
- R1（小A 初审 P1-1）：技能重构击杀成长（关羽、张飞、齐格鲁德、白晶晶，11 张卡）、击杀回 TP（孙权射虎等 5 张卡）同病同法（`modes/xiyou/core/tianqi_skills.gd`，开关 `XTianqiSkills.SEQ_KILLS`，O-待定-3）；七印待定击倒在序列里被救回过、之后再被不经结算的路子弄倒时旧溢出作废（`XBattler.immortal_rescues` 只计数）。
- 天启篇所有「当场判死活」写法重盘（交付单「盘点（R1 重盘）」）；战真印「剩下的段转给别的敌人」在序列招上没接，报另开单。
- 专项 `xiyou_tianqi_qiyin_seq_kill`（新）71/71。
- 玩家可见：天启篇里七印的击倒类效果（击倒后再行动、送行连斩、溢出、击杀叠层）、词条「斩获」、角色卡的击杀成长和击杀回 TP 现在普攻和技能都能触发了。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.SEQ_KILLS` | （天启篇）七印击倒类效果只认 after_apply 当场倒下的目标，动作序列招（含普攻）挂 IMMORTAL 收尾才倒，认不到 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾再按是否倒下认；IMMORTAL 时序不动 | 七印击倒类效果在所有出招上都不触发（T230 实测） | `XTianqiQiyinEffects.SEQ_KILLS = false` | cc（T232） | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_affix_battle.gd` `XTianqiAffixBattle.SEQ_KILLS` | （天启篇）词条「斩获」只认 after_apply 当场倒下的目标，动作序列招（含普攻）上认不到、不回 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾有一个真倒下就回一次 | 斩获在所有出招上都不触发（T232 实测） | `XTianqiAffixBattle.SEQ_KILLS = false` | cc（T232） | 保留 |
| O-待定-3 | `modes/xiyou/core/tianqi_skills.gd` `XTianqiSkills.SEQ_KILLS` | （天启篇）角色卡击杀成长（kill_grow）、击杀回 TP（kill_tp）当场看目标活没活，16 张卡全是动作序列招，认不到 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾（和追加释放的序列跑完后）倒了的再认 | 16 张卡的击杀效果实战从不触发（小A T232 初审 P1-1） | `XTianqiSkills.SEQ_KILLS = false` | cc（T232 R1） | 保留 |

## 验证

- R1：新专项 `xiyou_tianqi_qiyin_seq_kill` 71/71；`xiyou_tianqi_qiyin_effects` 63/63、`xiyou_tianqi_skills` 245/245、`xiyou_determinism` 372/372；语法检查 1057 个 .gd 0 问题。
- R1 战斗核心：`xiyou_battle_stream`～`_f`（6）、`xiyou_event_compare`～`_d`（4）、`xiyou_gojo`、`xiyou_gojo_trials`、`xiyou_guyu_battle`、`xiyou_otb`、`xiyou_smart_ai`、`xiyou_tianqi_affix_battle`、`xiyou_tianqi_again_use`、`xiyou_tianqi_alien_affix`、`xiyou_tianqi_brand`、`xiyou_tianqi_qiyin_endgame`、`xiyou_tianqi_weak_affix`、`xiyou_tianqi_doom_follow`、`xiyou_tianqi_horsemen`：23 个全部通过（`并行测试.py --jobs 3`）。
- R1 没跑：因为改了 `battler.gd`，`选测.py main --list` 列了 237 个（近整轮），车道不跑全量，只跑了上面这组；整轮／云端选测留给总装合并时跑。`battler.gd` 的改动只在 hp 写入时多一个计数，不改任何结算、不取随机数。
- 新专项 `xiyou_tianqi_qiyin_seq_kill` 57/57（本机 `--headless --audio-driver Dummy`；第一轮 44/44）。
- 追加后选测：`选测.py main --list` 列的 21 个（含 `xiyou_tianqi_affix_battle`、`xiyou_tianqi_affix_roll`、`xiyou_tianqi_alien_affix`、`xiyou_tianqi_artifact_aura`、`xiyou_tianqi_drop`、`xiyou_tianqi_money`、`xiyou_tianqi_trumpet`、`xiyou_event_compare*` 四份）＋`xiyou_determinism`、`xiyou_battle_stream`、`xiyou_tianqi_skills`、`xiyou_tianqi_weak_affix`、`xiyou_otb`：26 个全部通过；语法检查通过。
- 选测（`选测.py main --list` 列的 14 个全在内）＋战斗核心：`xiyou_event_compare`、`_b`、`_c`、`_d`、`xiyou_tianqi_elements`、`xiyou_tianqi_ledger_p3`、`xiyou_tianqi_phase4`、`xiyou_tianqi_qiyin_altar`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_qiyin_endgame`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_qiyin_seq_kill`、`xiyou_tianqi_weak_b1`、`xiyou_tianqi_weak_b2`、`xiyou_determinism`、`xiyou_battle_stream`、`xiyou_tianqi_skills`、`xiyou_tianqi_again_use`、`xiyou_tianqi_doom_follow`、`xiyou_tianqi_qiyin_dragon_run`、`xiyou_tianqi_affix_battle`、`xiyou_otb`：22 个全部通过；`xiyou_battle_stream*`（6 个）全部通过。
- 语法检查 1057 个 .gd 0 问题；工具快速回归全部通过；参照引擎启动检查正常。
- 没跑：虚拟玩家、云端选测、整份 `检查.sh`。

## 要 Kyo 定

- 「追加」打倒的敌人算不算击倒（协调让先记在这里备着，不改）：词条再释放（`XTianqiAffixBattle.end_action`）、技能重构追加释放（`XTianqiSkills.end_action`）打倒的敌人，七印不认（它们在七印 `end_action` 之后跑、七印行动帧已清），斩获也不认（再释放在 `end_action` 里走 `logic.apply`，行动帧已清）；七印自己的派生（连斩、横扫、再射、放两次、补刀）按原设计不回灌主行动。修前修后一样。A：照现在，追加打倒不算；B：追加打倒也算（再动、叠层、斩获可能多触发）。我倾向 A（追加本来就是额外收益，再叠击倒奖励容易滚雪球），不回就照 A。

## 异议

- 无（原来这里的「追加打倒算不算」挪到「要 Kyo 定」）。R1 补一句：技能重构追加释放（`_cast`）打倒的，击杀成长照认（修前非序列的追加本来就认，序列的现在也认）；击杀回 TP 照旧不认（追加时行动帧已清，修前修后一样）。
- **R1 重盘新发现，建议另开单**：战真印 `overflow_hits_redirect`（「击倒敌人时，把这次行动剩下的段转给另一个敌人」）只在 `battle_logic.execute` 的非序列分支调 `XTianqiQiyinEffects.redirect`；序列路 `action_sequence._action_effect` 没接，0 血挂 IMMORTAL 的目标也不算倒下，所以现在所有出招上这件七印都不生效。修要在序列每段前把「0 血挂 IMMORTAL」的目标换掉，牵涉序列画面、随机目标、`segment_target`，也要定「此刻算活着」的统一口径（同表里疫穿透、落星选目标、灼痕发作几处），不在本单顺手做。

## 可优化（流程／工具／效率）

- 已做：专项夹具 `_seq_skill`／`_plain`（序列招去掉 `yepSeq` 造非序列招），以后要对比两条路的专项可照抄。

## 本分支提交

- 834014646 WIP：待定击倒＋行动收尾认（SEQ_KILLS）；专项 44/44
- f72a8e61a 交付单；新专项 uid
- fc58489fd WIP：词条斩获同修（XTianqiAffixBattle.SEQ_KILLS）；专项 57/57
- 484006e3a 交付单补斩获、盘点、要 Kyo 定；专项头注释
- a2d40ae18 WIP：R1 技能重构击杀成长／回 TP 同修（XTianqiSkills.SEQ_KILLS）；七印救回后旧溢出作废；补抗死用例；专项 71/71
