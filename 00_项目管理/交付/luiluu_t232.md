# 交付：luiluu/t232

- 车道／工作者：C 规则·机制／cc（T232 七印击倒类效果在动作序列招和普攻上认不到击倒；追加：词条「斩获」同修、天启篇其他当场认击倒处盘点；Opus＋medium）
- 状态：可合并

## 一句话

动作序列招（转换后实际所有技能都带 `yepSeq`，普攻也是）打的过程中目标挂 IMMORTAL，0 血不倒、序列收尾才倒；七印 `after_apply` 当场用 `is_dead()` 认击倒，所以序列招上永远认不到。改成：这一击把挂着 IMMORTAL 的目标从有血打到 0 时先记成「待定击倒」（带这一击的溢出），`end_action` 开头（序列已收尾、该倒的已倒）再按 `is_dead()` 认。开关 `XTianqiQiyinEffects.SEQ_KILLS`（O-待定-1），关掉回到旧行为。

追加（协调同日）：词条「斩获」（`XTianqiAffixBattle.after_apply`）同病，实测属实，照同一办法修，单独开关 `XTianqiAffixBattle.SEQ_KILLS`（O-待定-2）；天启篇其他「当场 `is_dead()` 认击倒」的地方盘了一遍，见「盘点」节，没有别的要修。

## 独占文件（开工列）

- 改：`modes/xiyou/core/tianqi_qiyin_effects.gd`（`SEQ_KILLS` 开关、`after_apply` 末尾记待定、新 `confirm_pending`、`end_action` 开头调一次、文件头一行说明）
- 改（追加）：`modes/xiyou/core/tianqi_affix_battle.gd`（`SEQ_KILLS` 开关、`after_apply` 斩获那一行旁记待定、新 `_confirm_harvest`、`end_action` 开头调一次）
- 新：`tests/xiyou_tianqi_qiyin_seq_kill.gd／.tscn／.gd.uid`
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

## 盘点：天启篇其他「is_dead() 认击倒」的地方（词条、专属、七印以外）

判法：在一击结算当场（`after_apply`、`hp_damage` 这类序列中途会跑的钩子）认倒下的才会踩坑；在行动收尾（`battle_logic.act` 里各模块 `after_action`／`end_action`）、回合首尾、战斗结束才看的，那时序列已解除 IMMORTAL，没事。

| 位置（函数） | 什么时候跑 | 结论 |
| --- | --- | --- |
| `tianqi_affix_battle.gd` `after_apply` 斩获 | 每一击当场 | **踩坑，已修**（O-待定-2） |
| `tianqi_qiyin_effects.gd` `after_apply` | 每一击当场 | **踩坑，已修**（O-待定-1） |
| `tianqi_horsemen.gd` `_check_kills` | 骑士 `perform` 收尾、`after_action`、`end_turn` | 没事（行动收尾以后） |
| `tianqi_horsemen.gd` `_devour`、`_famine_perform` 看 `r.died` | 骑士自己的招，走 `horseman_strike`（不挂 IMMORTAL） | 没事 |
| `tianqi_war_alien.gd` `after_action` 号令官倒下 | 行动收尾 | 没事 |
| `tianqi_death_alien.gd` `_lift_dooms`／`_scan_deaths` | `after_action`、`end_turn` | 没事 |
| `tianqi_famine_alien.gd` `_refund_gold`（`take_logs`）、`grant_grain` | 行动收尾、回合首、战斗结束 | 没事 |
| `tianqi_qiyin_dragon_run.gd` `_check_cuts` | 七首之龙 `end_action`、`start_turn` | 没事 |
| `tianqi_alien_gear.gd` `grant`、`tianqi_alien_codex.gd` `record` | 战斗结束 | 没事 |
| `tianqi_weak_affix.gd` `segment_target` 一带 | 每一段 | 已经认 `immortal and hp <= 0`（批 0A 就处理过），没事 |
| `tianqi_qiyin_rule.gd` `hp_damage` 「战吼」按场上倒下人数加伤 | 每一击当场 | **拿不准，只列**：序列中途 0 血挂 IMMORTAL 的还没算进倒下人数，要等收尾；这是「此刻倒了几个」的口径，不是认击倒，改了会让同一招后几段的伤害变，没动 |
| `tianqi_alien_affix.gd` `after_apply` 「带毒」看 `t.is_alive()` | 每一击当场 | **拿不准，只列**：反过来的情形——序列招把目标打到 0 血（挂 IMMORTAL、算活着）时照样掷毒、取一次随机数；非序列招致命那一击目标已倒、不掷。改了会挪随机流，没动 |

## 验收逐条（卡上 5 条）

1. ✓ 见上表。
2. ✓ 各类出招都认到；边界：一招打倒多个（`序列群体招` 计数 2、`edge_multi_kill` 当场倒＋收尾倒混合）；不死目标（0 血不倒）不算（`edge_undying_not_kill`）；序列中途被救回不算（`edge_rescued_not_kill`）；打到 0→救回→再打到 0 只算一次、溢出按最后一次致命那一击、0 血上再挨的段不改溢出（`edge_twice_one_kill`、`edge_overflow_last_lethal`）。
3. ✓ PER_SEGMENT：专项用 `XBattleStream.start`＋`finish` 走交接线程，普攻、序列单体、序列群体、单段四类都和一次算完结果相同（`*_on_stream`）。新代码只在结算里读写七印本场数据，不碰场景树。
4. ✓ 随机流不变：新代码不取随机数、不改 IMMORTAL／倒下时机；七印只在天启篇档建数据（`legacy_no_store`：西游档序列普攻打倒照常、不再动）。`xiyou_determinism`、`xiyou_event_compare*` 四份全过；`mv_oracle/boot_check.cjs` 正常（db true、modulesFailed []）。没跑整份 `检查.sh --oracle`（车道不跑全量）。
5. ✓ 斩获见上节（普攻、序列群体、单段 × 开／关／逐段结算，救回、收尾倒下，两开关单独关）。七印开关 `SEQ_KILLS` 关：序列招回到旧行为（`off_seq_missed_*`、`edge_off_no_pending`），非序列不受影响；专项覆盖普攻、动作序列招（单体／群体）、非序列单段／多段／群体。

## 变更记录草稿

## 2026-11-19 【cc·T232·未经审查】七印击倒类效果、词条斩获在动作序列招（含普攻）上认得到击倒（dev.待定）
- 原因：动作序列招打的过程中目标挂 IMMORTAL，0 血不倒，序列收尾才倒；`XTianqiQiyinEffects.after_apply` 当场 `is_dead()` 认不到。转换后所有技能都带 `yepSeq`，所以修前击倒后再行动、送行连斩、大刀阔斧溢出、红印 3 件击杀叠层在任何出招上都不触发（T018 猜、T230 实测）。
- 修法（`modes/xiyou/core/tianqi_qiyin_effects.gd`）：这一击把挂 IMMORTAL 的目标从有血打到 0 时记成待定击倒（连同这一击的溢出），`end_action` 开头 `confirm_pending` 按 `is_dead()` 认；不死、序列里被救回的不算；IMMORTAL 时序、随机流、日志不动。开关 `SEQ_KILLS`（O-待定-1）。
- 词条「斩获」（`modes/xiyou/core/tianqi_affix_battle.gd`）同病同法：序列招上打倒敌人修前不回血回魔，修后行动收尾回一次（一次行动仍只一次）。开关 `XTianqiAffixBattle.SEQ_KILLS`（O-待定-2），和七印的分开关。
- 天启篇其他当场认倒下的地方盘了一遍（交付单「盘点」），其余都在行动收尾以后看，没事；「战吼」倒下人数、「带毒」打 0 血目标两处拿不准，只列。
- 专项 `xiyou_tianqi_qiyin_seq_kill`（新）57/57。
- 玩家可见：天启篇里七印的击倒类效果（击倒后再行动、送行连斩、溢出、击杀叠层）和词条「斩获」现在普攻和技能都能触发了。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.SEQ_KILLS` | （天启篇）七印击倒类效果只认 after_apply 当场倒下的目标，动作序列招（含普攻）挂 IMMORTAL 收尾才倒，认不到 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾再按是否倒下认；IMMORTAL 时序不动 | 七印击倒类效果在所有出招上都不触发（T230 实测） | `XTianqiQiyinEffects.SEQ_KILLS = false` | cc（T232） | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_affix_battle.gd` `XTianqiAffixBattle.SEQ_KILLS` | （天启篇）词条「斩获」只认 after_apply 当场倒下的目标，动作序列招（含普攻）上认不到、不回 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾有一个真倒下就回一次 | 斩获在所有出招上都不触发（T232 实测） | `XTianqiAffixBattle.SEQ_KILLS = false` | cc（T232） | 保留 |

## 验证

- 新专项 `xiyou_tianqi_qiyin_seq_kill` 57/57（本机 `--headless --audio-driver Dummy`；第一轮 44/44）。
- 追加后选测：`选测.py main --list` 列的 21 个（含 `xiyou_tianqi_affix_battle`、`xiyou_tianqi_affix_roll`、`xiyou_tianqi_alien_affix`、`xiyou_tianqi_artifact_aura`、`xiyou_tianqi_drop`、`xiyou_tianqi_money`、`xiyou_tianqi_trumpet`、`xiyou_event_compare*` 四份）＋`xiyou_determinism`、`xiyou_battle_stream`、`xiyou_tianqi_skills`、`xiyou_tianqi_weak_affix`、`xiyou_otb`：26 个全部通过；语法检查通过。
- 选测（`选测.py main --list` 列的 14 个全在内）＋战斗核心：`xiyou_event_compare`、`_b`、`_c`、`_d`、`xiyou_tianqi_elements`、`xiyou_tianqi_ledger_p3`、`xiyou_tianqi_phase4`、`xiyou_tianqi_qiyin_altar`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_qiyin_endgame`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_qiyin_seq_kill`、`xiyou_tianqi_weak_b1`、`xiyou_tianqi_weak_b2`、`xiyou_determinism`、`xiyou_battle_stream`、`xiyou_tianqi_skills`、`xiyou_tianqi_again_use`、`xiyou_tianqi_doom_follow`、`xiyou_tianqi_qiyin_dragon_run`、`xiyou_tianqi_affix_battle`、`xiyou_otb`：22 个全部通过；`xiyou_battle_stream*`（6 个）全部通过。
- 语法检查 1057 个 .gd 0 问题；工具快速回归全部通过；参照引擎启动检查正常。
- 没跑：虚拟玩家、云端选测、整份 `检查.sh`。

## 要 Kyo 定

- 「追加」打倒的敌人算不算击倒（协调让先记在这里备着，不改）：词条再释放（`XTianqiAffixBattle.end_action`）、技能重构追加释放（`XTianqiSkills.end_action`）打倒的敌人，七印不认（它们在七印 `end_action` 之后跑、七印行动帧已清），斩获也不认（再释放在 `end_action` 里走 `logic.apply`，行动帧已清）；七印自己的派生（连斩、横扫、再射、放两次、补刀）按原设计不回灌主行动。修前修后一样。A：照现在，追加打倒不算；B：追加打倒也算（再动、叠层、斩获可能多触发）。我倾向 A（追加本来就是额外收益，再叠击倒奖励容易滚雪球），不回就照 A。

## 异议

- 无（原来这里的「追加打倒算不算」挪到「要 Kyo 定」）。

## 可优化（流程／工具／效率）

- 已做：专项夹具 `_seq_skill`／`_plain`（序列招去掉 `yepSeq` 造非序列招），以后要对比两条路的专项可照抄。

## 本分支提交

- 834014646 WIP：待定击倒＋行动收尾认（SEQ_KILLS）；专项 44/44
- f72a8e61a 交付单；新专项 uid
- fc58489fd WIP：词条斩获同修（XTianqiAffixBattle.SEQ_KILLS）；专项 57/57
