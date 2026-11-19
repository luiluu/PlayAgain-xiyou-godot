# 交付：luiluu/t234

- 车道／工作者：C 规则·机制／cc（T234 七印战真印溢出转移接序列路＋统一「0 血 IMMORTAL 算不算活着」口径；Opus＋medium，职级 P8，因为接战斗序列结算、统一几处死活口径）
- 状态：可合并

## 一句话

战真印「击倒敌人时把剩下的段转给另一个敌人」（`overflow_hits_redirect`）原来只在 `battle_logic.execute` 的非序列分支调，库里技能全带 `yepSeq`，所以一招都不转。现在序列路 `XActionSequence._action_effect` 每条 ACTION EFFECT 打之前问 `XTianqiQiyinEffects.seq_redirect`：目标已倒或 0 血挂 IMMORTAL（已被击倒、收尾才倒）就转给另一个站着的敌人（开关 `SEQ_REDIRECT`，O-待定-1）。另定统一口径 `standing`：「挑另一个人接效果、按人发的一次性名额」时 0 血挂 IMMORTAL 算倒了，用在转段、疫满层穿透、一力降十会三处（开关 `DOWN_RULE`，O-待定-2）；对目标本身的结算、我方自身触发、「此刻几人」类加成照旧算活着，不改（理由见「口径」节）。

## 独占文件（开工列）

- 改：`modes/xiyou/core/tianqi_qiyin_effects.gd`（两个开关、`seq_redirect`、`standing`、`_alive_for_pick`；`redirect`、`_next_enemy`、一力降十会改用 `_alive_for_pick`；文件头一处说明）
- 改：`modes/xiyou/battle/action_sequence.gd`（`_action_effect` 一处：先问 `seq_redirect` 再判 `is_dead()` 跳过）
- 新：`tests/xiyou_tianqi_qiyin_redirect.gd／.tscn／.gd.uid`
- 没改：`battle_logic.gd`（非序列路本来就接了；非序列不挂 IMMORTAL，换口径结果一样）、`tianqi_brand.gd`、`tianqi_qiyin_rule.gd`、`tianqi_war_alien.gd` 等（口径表里判「不改」的）。

## 量清（验收 1）

专项打印 `QIYIN_REDIRECT_TABLE`：战真印剑（流派印记攻击次数 +1、真印转段），打敌群 2（3 个敌人），低血目标 1 血、其余满血。数没打空的命中：

| 出招 | 开关关：低血目标挨几段／别人挨几段 | 开关开 | 逐段结算（PER_SEGMENT）开 |
| --- | --- | --- | --- |
| 普攻（序列，2 段） | 2／0（第二段打在 0 血目标上） | 1／1（第二段转走） | 同开关开 |
| 序列单体招（2 段） | 2／0 | 1／1 | 同开关开 |
| 序列群体招（2 个低血，每人 2 段） | 4／2 | 2／4 | 同开关开 |
| 非序列多段招（去掉 yepSeq，2 段） | 1／2（本来就对） | 1／2 | 同左 |

- 开、关总段数相同（只换了目标，`hits_conserved_*`）；逐段结算开、关结果相同（`stream_same_*`）。
- 转过去的目标不在 IMMORTAL 名单里，打到 0 当场倒（`apply` 末尾 `_die`），七印击倒当场认到；它要是也在名单里（群体招），0 血后再转下一个站着的。
- 没有别的站着的敌人：照原样打在原目标上，不丢段（`last_enemy_keeps_hits`）——和非序列路「没得转就停」不同，序列路保留原版「段照打」的行为。
- 西游档、没戴真印（同流派非真印剑）：不转（`legacy_no_redirect`、`no_true_seal_no_redirect`）。
- 新代码只读写结算数据（敌人列表、七印本场数据），不碰场景树；PER_SEGMENT 的 gate 在 ACTION EFFECT 前，转段在 gate 之后的结算线程里判。

## 口径：0 血挂 IMMORTAL 算不算活着（验收 2）

**规则（按场合）**：「站着」＝`is_alive()` 且不是 `immortal and hp <= 0`（`XTianqiQiyinEffects.standing`，同 `XTianqiWeakAffix.legal` 批 0A 的写法）。

1. **挑另一个人来接效果、按人发的一次性名额** → **算倒了**（用 `standing`）。落到必倒的人身上纯浪费；就算之后被救回，选了别人也不吃亏。不取随机数。
2. **对这个人本身的结算**（伤害、判决、处决、落星、上疫、挂状态、带毒）→ **算活着**，不改。被救回的应当照吃；改了会让目标当场倒／不倒，后面的段打不打它跟着变，挪随机流。
3. **我方自己 0 血挂 IMMORTAL 时的自身触发**（灼痕发作）→ **算活着**，不改。可能被救回，被救回就该发作；发作掷 `brand_fit` 随机数。
4. **「此刻倒了几个／在场几个」类加成**（战吼、交锋）→ 照 `is_dead()`，**算活着**，不改。口径就是「此刻倒下」；改了同一招后几段伤害变。

| 位置 | 情况 | 归哪条 | 结论 |
| --- | --- | --- | --- |
| `tianqi_qiyin_effects.gd` `redirect`／`seq_redirect`＋`action_sequence.gd` `_action_effect` | 战真印转段：序列路没接，0 血挂 IMMORTAL 的不算倒 | 1 | **改**（O-待定-1 接序列路；O-待定-2 挑人） |
| `tianqi_qiyin_effects.gd` `_next_enemy`（`after_apply` 疫满层穿透） | 可能穿到 0 血挂 IMMORTAL 的敌人身上 | 1 | **改**（O-待定-2）。`end_action` 里的那次用法在序列收尾后，前后一样 |
| `tianqi_qiyin_effects.gd` `after_apply` 一力降十会 | 每个目标每场一次的名额用在必倒的人身上 | 1 | **改**（O-待定-2） |
| `tianqi_weak_affix.gd` `legal` | 引导者每段合法 | 1 | 本来就是这个口径（批 0A），不动 |
| `tianqi_qiyin_effects.gd` `_star_fall` 目标、判决、灰镰处决 | 0 血挂 IMMORTAL 的照吃（`_lose_hp` 当场 `_die`） | 2 | 不改：当场倒下会让这一招后面的段不再打它，改了挪随机流 |
| `tianqi_qiyin_effects.gd` `add_plague`；`gojo.gd` 茈「收」减速 | 照叠疫、照挂减速 | 2 | 不改：挂在必倒的人身上无害，被救回的应当照挂 |
| `tianqi_alien_affix.gd` 带毒、`tianqi_skills.gd` `_on_hit`、`tianqi_plague_alien.gd` 腺体 | 照掷几率挂状态 | 2 | 不改：挪 `tianqi_skill_on_hit`／`plague_chaos` 等随机流 |
| `tianqi_death_alien.gd` 替身 | 0 血替身再挨段再判一次 | 2 | 不改：第一下致命伤序列非序列一样，之后条件不成立 |
| `tianqi_brand.gd` `sear_add`→`trigger` | 我方 0 血挂 IMMORTAL 时灼痕满了照发作 | 3 | 不改：被救回要发；挪 `brand_fit` 随机流 |
| `tianqi_qiyin_rule.gd` 战吼、`tianqi_war_alien.gd` `clash_mult` | 按此刻倒下／在场人数加伤 | 4 | 不改：改了同一招后几段伤害变 |

（T232 盘点表里其余「安全」「收尾后才看」的条目不受影响，没重列。）

## 验收逐条（卡上 4 条）

1. ✓ 普攻、序列单体、序列群体招上都转（表见上）；PER_SEGMENT 开、关一致。
2. ✓ 见「口径」节：规则写清（按场合四条），改 3 处，其余写了不改的理由。
3. ✓ 随机流：西游档不进七印（`_active` 为假，`seq_redirect` 直接返回 null），`xiyou_determinism` 372/372；`mv_oracle/boot_check.cjs` 正常（db true、modulesFailed []、errors []）。天启篇战真印持有者的出招按设计换了目标（总段数不变）。没跑整份 `检查.sh --oracle`（车道不跑全量）。
4. ✓ 两个开关单独可回退：`SEQ_REDIRECT = false` 回到序列招不转（`off_wasted_*`）；`DOWN_RULE = false` 回到只看 `is_alive`（`next_enemy_off_old`、`lose_action_off`、`guard_seq_off_*`）。新专项 `xiyou_tianqi_qiyin_redirect` 52/52（热修后）。

## 变更记录草稿

## 2026-11-19 【cc·T234·未经审查】七印战真印「剩下的段转给另一个敌人」在动作序列招（含普攻）上接通；统一「0 血挂 IMMORTAL 算不算活着」口径（dev.待定）
- 原因：转段只在 `battle_logic.execute` 非序列分支调；转换后所有技能都带 `yepSeq`，序列路没接，0 血挂 IMMORTAL 的目标也不算 `is_dead()`，所以战真印这条在任何出招上都不生效，剩下的段照打在 0 血目标上（T232 R1 重盘发现）。
- 修法：`XActionSequence._action_effect` 每段打之前问 `XTianqiQiyinEffects.seq_redirect`，目标已倒或 0 血挂 IMMORTAL 就转给另一个站着的敌人；没得转照原样打。开关 `XTianqiQiyinEffects.SEQ_REDIRECT`（O-待定-1）。
- 口径：新 `XTianqiQiyinEffects.standing`（活着且不是 0 血挂 IMMORTAL）。挑另一个人接效果、按人发的一次性名额时算倒了：转段、疫满层穿透、一力降十会名额三处改用它（开关 `DOWN_RULE`，O-待定-2）；对目标本身的结算、我方自身触发（灼痕发作）、「此刻几人」类加成（战吼、交锋）照旧，理由见交付单「口径」节。
- 专项 `xiyou_tianqi_qiyin_redirect`（新）51/51。
- 玩家可见：天启篇战真印的「击倒敌人时把剩下的段转给另一个敌人」现在普攻和技能都生效了；疫满层穿透、一力降十会不再落在已被击倒的敌人身上。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.SEQ_REDIRECT`（接在 `modes/xiyou/battle/action_sequence.gd` `_action_effect`） | （天启篇）战真印转段只在非序列招上生效，序列招（含普攻）剩下的段照打在 0 血挂 IMMORTAL 的目标上 | 序列每段打之前，目标已倒或 0 血挂 IMMORTAL 就转给另一个站着的敌人；没得转照原样 | 库里技能全带 yepSeq，修前战真印这条一招都不生效（T232 R1 重盘） | `XTianqiQiyinEffects.SEQ_REDIRECT = false` | cc（T234） | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.DOWN_RULE` | （天启篇）转段、疫满层穿透挑人、一力降十会名额只看 is_alive，0 血挂 IMMORTAL（必倒）的算活着 | 这三处 0 血挂 IMMORTAL 的算倒了（standing） | 效果落在必倒的人身上是浪费；统一口径（同引导者 legal） | `XTianqiQiyinEffects.DOWN_RULE = false` | cc（T234） | 保留 |

## 验证

- 新专项 `xiyou_tianqi_qiyin_redirect` 51/51（`并行测试.py`，headless）。
- 选测（`选测.py main --list` 列的 26 个）＋`xiyou_battle_stream*`（另 5 个）＋`xiyou_determinism`、`xiyou_otb`（`并行测试.py --full`，CHECK_JOBS=3）。
- 回归结果：32 个全部通过（含 `xiyou_action_sequence` 117/117、`xiyou_all_scope_repeat` 60/60、`xiyou_boss_sequence` 8315/8315、`xiyou_event_compare`～`_d` 四份、`xiyou_battle_stream`～`_f` 六份、`xiyou_tianqi_qiyin_seq_kill` 71/71、`xiyou_tianqi_qiyin_effects` 63/63、`xiyou_tianqi_brand` 234/234）；另一轮 `xiyou_determinism` 372/372、`xiyou_otb` 34/34。
- 语法检查 1059 个 .gd 0 问题；工具快速回归全部通过；参照引擎启动检查正常（`boot_check.cjs`：db true、modulesFailed []、errors []）。
- 没跑：整份 `检查.sh`、`--oracle` 全量对照、云端选测、虚拟玩家。

## 核后热修（小A Neon 核过：P2×1、P3×2）

- **P2-1 殉印 3 件替挡**：`hp_damage` 在敌方序列招里跑，我方挂 IMMORTAL。改：挑「生命最低的队友」用 `_lowest(logic.actors, true)`（按 DOWN_RULE 口径，0 血挂 IMMORTAL 的不算），挑替挡者用 `_alive_for_pick(g)`；都挂在 `DOWN_RULE` 下，关掉回到只看 `is_alive`。不取随机数。`_lowest` 另两处调用（献血护盾、普攻治疗最低）不动（pick 默认 false）。专项 `xiyou_tianqi_qiyin_effects` 加 `_guard_seq`：按段重放敌方群体多段序列招（我方全挂 IMMORTAL、第一段把一名队友打到 0 血），后续段残血队友照被替挡、0 血的不被锁定、0 血的替挡者不白挡；开关关时回到旧口径（8 条），71/71。
- **P3-1 选「改行为」**：`seq_redirect` 不再先调 `redirect`（DOWN_RULE 关时取第一个 `is_alive` 的、若它 0 血就整段不转），改成自己挑第一个 `standing` 的敌人，不看 DOWN_RULE；第 50 行附近注释写明「序列转段不归 DOWN_RULE 管，要回退关 SEQ_REDIRECT」，并把替挡列进 DOWN_RULE 管的范围。理由：序列转段本身的触发条件就是「目标 0 血挂 IMMORTAL」，DOWN_RULE 关时仍可能转到另一个 0 血的人身上是白转，旧写法则会在有站着的敌人时也不转。专项加 `seq_redirect_off_skips_down`，原 `seq_redirect_off_not_to_down` 改名 `seq_redirect_off_only_down_left`（只剩倒下的人时不转）。
- **P3-2**：`legacy_no_redirect` 改成 `not leg.has("skip") and …`（探针没找到技能不再算过）。
- 重跑：`xiyou_tianqi_qiyin_redirect` 52/52、`xiyou_tianqi_qiyin_effects` 71/71、`xiyou_determinism` 372/372（`并行测试.py --full`）；语法检查 1059 个 .gd 0 问题。

## 要 Kyo 定

- 无。（口径只动天启篇七印自己的挑人与名额，没改原版行为，所以没 ask。）

## 异议

- 无。补一句：序列路「没得转」时照原样把段打在原目标上，没照非序列路「停手」。理由：停手会少打段、改原版序列的结算次数；而这时场上只剩这一个（必倒的）敌人，打不打它结果一样。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- （热修提交见 git log）
- 68ea9b54a WIP：战真印转段接序列路（SEQ_REDIRECT）＋0 血 IMMORTAL 挑人口径（DOWN_RULE）；专项 51/51
