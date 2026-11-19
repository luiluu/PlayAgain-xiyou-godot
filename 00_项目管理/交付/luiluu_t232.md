# 交付：luiluu/t232

- 车道／工作者：C 规则·机制／cc（T232 七印击倒类效果在动作序列招和普攻上认不到击倒；Opus＋medium）
- 状态：可合并

## 一句话

动作序列招（转换后实际所有技能都带 `yepSeq`，普攻也是）打的过程中目标挂 IMMORTAL，0 血不倒、序列收尾才倒；七印 `after_apply` 当场用 `is_dead()` 认击倒，所以序列招上永远认不到。改成：这一击把挂着 IMMORTAL 的目标从有血打到 0 时先记成「待定击倒」（带这一击的溢出），`end_action` 开头（序列已收尾、该倒的已倒）再按 `is_dead()` 认。开关 `XTianqiQiyinEffects.SEQ_KILLS`（O-待定），关掉回到旧行为。

## 独占文件（开工列）

- 改：`modes/xiyou/core/tianqi_qiyin_effects.gd`（`SEQ_KILLS` 开关、`after_apply` 末尾记待定、新 `confirm_pending`、`end_action` 开头调一次、文件头一行说明）
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

## 验收逐条（卡上 5 条）

1. ✓ 见上表。
2. ✓ 各类出招都认到；边界：一招打倒多个（`序列群体招` 计数 2、`edge_multi_kill` 当场倒＋收尾倒混合）；不死目标（0 血不倒）不算（`edge_undying_not_kill`）；序列中途被救回不算（`edge_rescued_not_kill`）；打到 0→救回→再打到 0 只算一次、溢出按最后一次致命那一击、0 血上再挨的段不改溢出（`edge_twice_one_kill`、`edge_overflow_last_lethal`）。
3. ✓ PER_SEGMENT：专项用 `XBattleStream.start`＋`finish` 走交接线程，普攻、序列单体、序列群体、单段四类都和一次算完结果相同（`*_on_stream`）。新代码只在结算里读写七印本场数据，不碰场景树。
4. ✓ 随机流不变：新代码不取随机数、不改 IMMORTAL／倒下时机；七印只在天启篇档建数据（`legacy_no_store`：西游档序列普攻打倒照常、不再动）。`xiyou_determinism`、`xiyou_event_compare*` 四份全过；`mv_oracle/boot_check.cjs` 正常（db true、modulesFailed []）。没跑整份 `检查.sh --oracle`（车道不跑全量）。
5. ✓ 开关 `SEQ_KILLS` 关：序列招回到旧行为（`off_seq_missed_*`、`edge_off_no_pending`），非序列不受影响；专项覆盖普攻、动作序列招（单体／群体）、非序列单段／多段／群体。

## 变更记录草稿

## 2026-11-19 【cc·T232·未经审查】七印击倒类效果在动作序列招（含普攻）上认得到击倒（dev.待定）
- 原因：动作序列招打的过程中目标挂 IMMORTAL，0 血不倒，序列收尾才倒；`XTianqiQiyinEffects.after_apply` 当场 `is_dead()` 认不到。转换后所有技能都带 `yepSeq`，所以修前击倒后再行动、送行连斩、大刀阔斧溢出、红印 3 件击杀叠层在任何出招上都不触发（T018 猜、T230 实测）。
- 修法（`modes/xiyou/core/tianqi_qiyin_effects.gd`）：这一击把挂 IMMORTAL 的目标从有血打到 0 时记成待定击倒（连同这一击的溢出），`end_action` 开头 `confirm_pending` 按 `is_dead()` 认；不死、序列里被救回的不算；IMMORTAL 时序、随机流、日志不动。开关 `SEQ_KILLS`（O-待定）。
- 专项 `xiyou_tianqi_qiyin_seq_kill`（新）44/44。
- 玩家可见：天启篇里七印的击倒类效果（击倒后再行动、送行连斩、溢出、击杀叠层）现在普攻和技能都能触发了。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.SEQ_KILLS` | （天启篇）七印击倒类效果只认 after_apply 当场倒下的目标，动作序列招（含普攻）挂 IMMORTAL 收尾才倒，认不到 | 打到 0 血的 IMMORTAL 目标先记待定，行动收尾再按是否倒下认；IMMORTAL 时序不动 | 七印击倒类效果在所有出招上都不触发（T230 实测） | `XTianqiQiyinEffects.SEQ_KILLS = false` | cc（T232） | 保留 |

## 验证

- 新专项 `xiyou_tianqi_qiyin_seq_kill` 44/44（本机 `--headless --audio-driver Dummy`）。
- 选测（`选测.py main --list` 列的 14 个全在内）＋战斗核心：`xiyou_event_compare`、`_b`、`_c`、`_d`、`xiyou_tianqi_elements`、`xiyou_tianqi_ledger_p3`、`xiyou_tianqi_phase4`、`xiyou_tianqi_qiyin_altar`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_qiyin_endgame`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_qiyin_seq_kill`、`xiyou_tianqi_weak_b1`、`xiyou_tianqi_weak_b2`、`xiyou_determinism`、`xiyou_battle_stream`、`xiyou_tianqi_skills`、`xiyou_tianqi_again_use`、`xiyou_tianqi_doom_follow`、`xiyou_tianqi_qiyin_dragon_run`、`xiyou_tianqi_affix_battle`、`xiyou_otb`：22 个全部通过；`xiyou_battle_stream*`（6 个）全部通过。
- 语法检查 1057 个 .gd 0 问题；工具快速回归全部通过；参照引擎启动检查正常。
- 没跑：虚拟玩家、云端选测、整份 `检查.sh`。

## 要 Kyo 定

- 无。

## 异议

- 「追加」一类：词条再释放（`XTianqiAffixBattle.end_action`）、技能重构追加释放（`XTianqiSkills.end_action`）打倒的敌人，七印不认（它们在七印 `end_action` 之后跑、七印行动帧已清；七印自己的派生也按原设计不回灌）。这是现设计的结算顺序，修前修后一样，本单没改；要不要让追加打倒也算七印击倒（比如再动、叠层）是设计口径，需要的话另开一单。

## 可优化（流程／工具／效率）

- 建议：`XTianqiAffixBattle.after_apply` 的「收割」（harvest）同样用 `t.is_dead()` 当场认击倒（`modes/xiyou/core/tianqi_affix_battle.gd:495`），在动作序列招上大概率也认不到（我猜，没测）；修法可照本单：记待定、`end_action` 再认。归规则·机制车道。
- 已做：专项夹具 `_seq_skill`／`_plain`（序列招去掉 `yepSeq` 造非序列招），以后要对比两条路的专项可照抄。

## 本分支提交

- 834014646 WIP：待定击倒＋行动收尾认（SEQ_KILLS）；专项 44/44
