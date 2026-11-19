# 交付：luiluu/t240

- 车道／工作者：C 规则·机制／cc（T240 追加出手打倒的敌人也算击倒＋连锁上限，D223 乙；Opus＋medium）
- 状态：可合并

## 一句话

T232 之后，主行动（含动作序列招）打倒的已经认得到；但追加出手（七印派生、词条再释放、技能重构追加释放）打倒的仍不算：再释放、追加释放在七印 `end_action` 之后才跑，七印行动帧已清；七印派生开自己的临时帧、打倒的随帧丢掉。改成：七印 `end_action` 开「追加击倒窗口」，这三类出手前后比对还活着的敌人，新倒下的记给行动者；`act` 里三者跑完后新加 `XTianqiQiyinEffects.followup_settle` 按轮结算，最多 `FOLLOW_KILL_MAX`（3）轮。开关 `XTianqiQiyinEffects.FOLLOW_KILLS`（O-待定），关掉回到现在（追加打倒的不算）。

## 口径（项目经理cc 11-19 回 ask 定）

1. **上限按每次行动计**：一次行动里追加击倒的结算最多 3 轮（`FOLLOW_KILL_MAX`，整数可改），每轮不管倒几个算 1 次。实际会自我连锁的只有送行连斩（击倒再动有 per_turn 和回合预算、斩获一次行动一次、再释放／追加释放不由击倒触发）。到上限时没结算的击倒数记在 `fu_last.left`。
2. **补刀不记给行动者**：补刀是队友 h 出手（`_derived(h, …)`），窗口只认行动者本人的出手。
3. **红印 3 件击杀叠层（un.kills）加**：追加打倒的也数进叠层。
4. **大刀阔斧溢出不加**：追加出手不逐击记溢出，不认追加的击倒。

每轮结算：击杀叠层＋送行连斩＋词条斩获（这次行动还没回过才回，一次行动仍只一次）＋击倒再动（照旧受 per_turn 和回合预算）；本轮连斩又打倒的进下一轮。

## 随机数

- 西游档：七印没有本场数据（`_active` 为假），窗口不开、`followup_settle` 直接返回，不取随机数，零变化（`legacy_no_store`、`legacy_settle_noop`；`xiyou_determinism` 372/372、`xiyou_event_compare` 四份全过）。
- 天启篇档：**只在追加出手真打倒了敌人时**才会多取：送行连斩选目标（`qiyin_target`）和那一刀的 `apply`。比对存活本身不取随机数；没有追加击倒的行动，随机流与改前完全一样。

## 独占文件

- 改：`modes/xiyou/core/tianqi_qiyin_effects.gd`（`FOLLOW_KILLS`、`FOLLOW_KILL_MAX`；`end_action` 开窗口；送行连斩、击倒再动抽成 `_chain_slash`、`_kill_extra`（行为不变）；新 `fu_snap`／`fu_note`／`followup_settle`；`_derived` 前后比对；`begin_action` 清旧窗口）
- 改：`modes/xiyou/core/tianqi_affix_battle.gd`（`end_action` 记 `st.last` 这次回没回过斩获；再释放每击前后比对；新 `followup_harvest`）
- 改：`modes/xiyou/core/tianqi_skills.gd`（`_cast` 外包一层前后比对，原体改名 `_cast_run`，内容不变）
- 改：`modes/xiyou/battle/battle_logic.gd`（`act` 里 `XTianqiSkills.end_action` 之后加一行 `followup_settle`）
- 新：`tests/xiyou_tianqi_followup_kill.gd／.tscn／.gd.uid`

## 验收逐条（卡上 4 条）

1. ✓ 三类追加出手打倒都触发（专项 `xiyou_tianqi_followup_kill`，打印 `FOLLOW_KILL_TABLE`）：
   - 词条再释放（17 条完美再释放＝必中）：击倒 1、叠层 +1、斩获回 90（`recast_kill_counts_on`、`recast_harvest_on`）。击倒再动这一项没动：再释放已占掉本回合唯一的追加预算（`XTianqiLedger.take_extra`，期三规则），这是原有限制，不是本单漏的。
   - 技能追加释放 `_cast`，序列招与非序列招两条路：击倒 1、叠层 +1、击倒再动、斩获回 90（`follow_seq_on_kill_again_harvest`、`follow_plain_on_kill_again_harvest`）。
   - 七印派生（送行连斩）：见第 2 条；整次 `lg.act` 冒烟（送行原样 chain、全场 1 血）叠层＝倒下数、结算 1 轮、窗口用完清掉（`act_smoke_settled`）。
   - 补刀（队友）打倒的不记给行动者（`budao_not_actor_kill`）。
2. ✓ 连锁上限：送行连斩去掉 chain（每轮只斩一刀），怨念之魂×8 全场 1 血。上限 3：主招 1＋主收尾连斩 1＋3 轮各斩 1，停在 3 轮、剩 1 个击倒没结算、倒 5 个（还有 3 个站着）、叠层 4（`chain_cap3_stops`）；上限改 1：停在 1 轮（`chain_cap1_stops`）；斩获整次行动只回一次（`chain_cap_harvest_once`）。
3. ✓ `FOLLOW_KILLS = false` 回到现在：再释放、追加释放（两条路）打倒的叠层 0、不再动、不回斩获；送行连斩只有主收尾那一刀（`recast_off_old`、`follow_*_off_old`、`chain_off_old`）。
4. ✓ 西游档零变化（见「随机数」）；`xiyou_determinism` 372/372。

## 验证

- 新专项 `xiyou_tianqi_followup_kill` 19/19（本机 `并行测试.py`，headless）。
- 先合了 main（c73321b64）再跑：`xiyou_tianqi_qiyin_seq_kill` 71/71、`_qiyin_effects` 71/71、`_qiyin_redirect` 52/52、`_qiyin_endgame` 62/62、`_qiyin_dragon_run` 88/88、`_affix_battle` 86/86、`_skills` 245/245、`_again_use` 14/14、`_doom_follow` 74/74、`_ledger` 82/82、`_ledger_p3` 40/40、`_weak_affix` 101/101、`_weak_b2` 60/60、`_alien_affix` 37/37、`_brand` 234/234、`_horsemen_battle` 142/142、`_e2e` 60/60、`xiyou_determinism` 372/372、`xiyou_battle_stream`～`_f`（6 个）、`xiyou_event_compare`～`_d`（4 个）、`xiyou_otb` 34/34、`xiyou_gojo` 97/97：31 个全过。
- 语法检查 1060 个 .gd 0 问题；工具快速回归全部通过。
- 没跑：`选测.py main --list` 因改了 `battle_logic.gd` 列了 334 个（近整轮），车道不跑全量，留给总装合并时选测／云端；逐段结算（PER_SEGMENT）下的追加击倒没单独写用例（`followup_settle` 在 `act` 里，逐段路也经 `act` 收尾，`xiyou_battle_stream` 六份全过）；虚拟玩家没跑。

## 变更记录草稿

## 2026-11-19 【cc·T240·未经审查】天启篇追加出手打倒的敌人也算击倒，连锁最多 3 轮（dev.待定）
- 原因：D223 乙（Kyo 11-19）。T232 后主行动的击倒认得到了，但词条再释放、技能重构追加释放在七印行动收尾之后才跑，七印派生打倒的随临时帧丢掉，这些击倒不触发击倒再动、送行连斩、击杀叠层、词条斩获。
- 修法（`modes/xiyou/core/tianqi_qiyin_effects.gd`）：七印 `end_action` 开追加击倒窗口，行动者本人的派生、再释放（`tianqi_affix_battle.gd`）、追加释放（`tianqi_skills.gd` `_cast`）前后比对还活着的敌人，新倒下的记下；`battle_logic.act` 在三者之后调 `followup_settle` 按轮结算叠层、连斩、斩获（一次行动一次）、击倒再动（per_turn、回合预算照旧），一次行动最多 `FOLLOW_KILL_MAX`＝3 轮。补刀（队友）不记、大刀阔斧溢出不认追加击倒。开关 `XTianqiQiyinEffects.FOLLOW_KILLS`（O-待定）。
- 随机数：西游档零变化；天启篇档只在追加出手真打倒敌人时多取送行连斩的选目标与那一刀。
- 专项 `xiyou_tianqi_followup_kill`（新）19/19。
- 玩家可见：天启篇里再释放、追加释放、七印追加的攻击打倒敌人，现在也能触发击倒后再行动、送行连斩、击杀叠层和词条「斩获」。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.FOLLOW_KILLS`（上限 `FOLLOW_KILL_MAX`） | （天启篇）追加出手（七印派生、词条再释放、技能追加释放）打倒的敌人不算行动者的击倒 | 追加打倒的记给行动者，行动收尾按轮结算击杀叠层、送行连斩、斩获、击倒再动，最多 3 轮 | D223 乙（Kyo 11-19） | `XTianqiQiyinEffects.FOLLOW_KILLS = false` | cc（T240） | 保留 |

## 交接板

- 下一步：无新增
- 需要用户决定：无

## 要 Kyo 定

- 无（上限口径已由项目经理cc 定，见「口径」）。

## 异议

- 无。附带说明：再释放打倒的不会触发击倒再动，因为再释放和击倒再动共用每回合 1 次的追加预算（期三），再释放已经把它用掉了；这是原有规则，本单没改。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- e198d74e7 WIP：追加出手打倒也算击倒（FOLLOW_KILLS）＋连锁上限 3 轮；专项 19/19
- （合 main）bc962afbb
- 专项 uid
- 交付单（本提交）
