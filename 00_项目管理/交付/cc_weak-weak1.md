# 交付：cc/weak-weak1

- 车道／工作者：C 规则·机制／weak1（cc，派单第三批 AF）
- 状态：可合并

## 盘点：原版弱者挑战（`js/codex/runtime/installWeakChallengeRuntime.js`，CodexWeakChallenge v2）

| # | 项 | 原版位置 | 重制现状 | 期 |
| --- | --- | --- | --- | --- |
| 1 | 弱者分类 isWeak：有名字；不在 CE1345 `actorIds`；不是 167～174；备注无 `<GuyuActor>`／`<CodexSuperStrong>`；不在超强者、强者名单（品质无关） | isWeak | 本期做（`XWeakChallenge.is_weak`），参照 79 名弱者逐个对上 | 一 |
| 2 | 全局标记 `ConfigManager._codexWeakFiveClearV2`（makeData／applyData，只认 `=== true`） | makeConfig／applyConfig | 本期做（`XConfig` 键 `codexWeakFiveClearV2`） | 一 |
| 3 | 本局标记 `$gameSystem._codexWeakClearV2`，新局取全局的；之后学不学只看本局 | setupNewGame、enabled | 本期做（`XState.flags.codexWeakClearV2`，只在为真时写，旧档不变） | 一 |
| 4 | 同步 sync：标记开且是弱者学 10357，否则忘；新局结束、读档后、每场 BattleManager.setup 前、最终战胜利后 | sync／syncActors | 本期做；忘掉后 HP／MP 夹回新上限（参照 load.forget） | 一 |
| 5 | 角色建出（Game_Actor.setup）时同步，新学到就回满 | setup 包装 | 本期做（`XState.actor` 建出后） | 一 |
| 6 | learnSkill(10357) 拦截：标记关或不是弱者不学 | learnSkill 包装 | 本期做（`XActor.learn_skill` 开头） | 一 |
| 7 | 10357 备注 passivePBST0～7 各 +500% | 技能备注 | 通用被动本来就读，参照八项属性逐项对上 | 一 |
| 8 | 持有者 sparam 6／7 ×0.5 | sparam 包装 | 本期做（`XActor.sparam` 外层） | 一 |
| 9 | 伤害钩子 weak-new-game：主动造成伤害 finalMultiplier ×3（恢复类不经伤害钩子） | CodexDamageHooks | 本期做（`XActorDamageHooks.capture` 追加） | 一 |
| 10 | 最终战判定：Map157 敌群 469、难度 9、出战五人全弱者；入队／离队／换位、改难度重判（作废不恢复）；强者行动作废 | BattleManager.setup、Game_Party 六个方法、setDifficultyId、startAction | 本期做（`battle_setup`、`check`、`start_action`；挂 add_actor／remove_actor／rearrange_actors／XDungeon.set_difficulty） | 一 |
| 11 | 胜利结算：result 0、仍满足、敌群全灭 → 本局／全局标记、全员同步、成就 142、写配置；阵亡出战队员照算，替补不算 | endBattle 包装 | 本期做（`before_end`／`after_end`） | 一 |
| 12 | 成就 142「本质高手」定义 | isDatabaseLoaded | 早已有（`XAchievement.EXTRA`） | — |
| 13 | 徽章图 240201、成就册与弹窗金色渐变名字 | drawIcon、drawItem、popup | 早已有（`achievement_badge.gd`，专项 xiyou_achievement_badge） | — |
| 14 | CE714 难度修复在混沌时不改难度 | command356 包装 | 早已有（`mv_event_core.gd` 公共事件 714） | — |
| 15 | 说明卡 10357「品质：」行改「品质：神话」（`<CodexWeakNewGame>`） | RJO.HE.getItemExtraDescParams2 包装 | 未做 | 二 |
| 16 | 旧存档解释器里 Map48／49／54／85 公共事件 1431 跳过 | command117 包装 | 不移植：重制存档不存解释器现场 | — |
| 17 | `_codexWeakNewGameBuff` 清零 | setupNewGame／extract | 不移植：旧版残留字段，v2 没人读 | — |

## 变更记录草稿

## 2026-11-05 【cc·weak1·未经审查】弱者挑战一期：五名弱者通关混沌鸿蒙老祖与「你才是真正的强者」（dev.待定）

- **原版怎样**：五名弱者在混沌难度打赢最终守层者鸿蒙老祖（Map157 敌群 469）得成就 142「本质高手」，之后（所有存档共用的全局标记）每个新游戏的弱者都自动带被动 10357「你才是真正的强者」：八项基础属性 +500%、最终伤害额外 ×3、物理与魔法承伤 ×0.5。
- **重制之前**：只有成就 142 的条目和徽章，判定、标记、发技能都没有：成就拿不到，10357 没人学（raven2 插件扫描、scan2 留下的唯一真缺）。
- **现在**：照原版移植（新模块 `modes/xiyou/core/weak_challenge.gd` `XWeakChallenge`），盘点表 1～11 项。参照探针 `mv_oracle/weak_challenge_probe.cjs`（20 例，产物 `weak_challenge.json`，已进 `同步正式西游.py` PROBES）：弱者分类、新局开关两支的技能／八项属性／承伤率／回满、试学、存读档四种、弱者 2 号普攻与挨打伤害（关 51／31，开 1466／4）、最终战十种情形（胜利、阵亡照算、难度 8、四人、混入强者、满员时强者只进替补照给、离队、离队又回来不恢复、逃跑、别的敌群）、通关后新局。专项 `xiyou_weak_challenge` 85 项全过。
- **开关**：`XWeakChallenge.ENABLED = false` 回到移植前（O-待定）。
- 改的共用核心文件：`actor.gd`（learn_skill 开头、sparam 6／7 外层）、`xstate.gd`（新局两处、角色建出、读档、入队／离队／重排）、`battle_logic.gd`（setup、act 开头、end_battle 首尾）、`actor_damage_hooks.gd`、`dungeon.gd`（Difficulty SetID 后重判）、`xconfig.gd`（新配置键）。标记关着时（所有现有存档与测试）这些挂点都直接返回，不改行为。

## 交接板

- 下一步：弱者挑战二期——说明卡 10357「品质：神话」（盘点 15）；做完把 `07_开发环境/测试插件备注覆盖.py` `test_known_unread` 的 `codexweaknewgame` 换一个例子（一期没读这个标签，测试照旧过）。
- 用户试玩说明：五名弱者（不在强者名单、不是新增专属角色）在混沌难度打赢鸿蒙老祖，得「本质高手」；之后新开的存档里弱者入队就带「你才是真正的强者」并回满。老存档读档不变（看的是那个存档自己的标记）。
- 需要用户决定：O-待定（弱者挑战移植）默认照原版开着，Kyo 看过再定。

## 进度账

- 规则／机制：弱者挑战从「只有成就条目」到一期可玩（判定、开局、数值）；剩说明卡一行文字。

## 可优化（流程／工具／效率）

- 无

## 待交叉核查

- 甲档（战斗核心＋存档）：`actor.gd`、`xstate.gd`、`battle_logic.gd`、`actor_damage_hooks.gd`、`dungeon.gd`、`xconfig.gd`、新文件 `weak_challenge.gd`；探针 `weak_challenge_probe.cjs`。重点：sparam 外层位置（在小猫 XCat.sparam 之外，原版装载先后未量，乘法与加法混在时次序可能有差）；`battle_setup` 每场对全队 sync（标记关时一行返回）。
- 反向验证（`反向验证.py`）：终伤 ×3、承伤 ×0.5、建出回满、离队又回来不恢复、读档同步 5 处都咬住；「强者名单不排除」没咬住——原版 strongIds 全在 CE1345 名单或 167～174 里，这一条在原版本身就是多余的，照原版保留。

## 验证

- 专项：`xiyou_weak_challenge`（85/85）。
- 选测（本机，没走云端）：`选测.py main --list` 列 344 个（改了 actor／xstate／battle_logic，近乎全量），按影响面挑 40 个本机跑，全过：xiyou_determinism、xiyou_rules、xiyou_rules_d6、xiyou_smart_ai、xiyou_actor_p0、xiyou_actor1_damage、xiyou_actor_modules、xiyou_actor_bonus、xiyou_race_battle、xiyou_tusu_battle、xiyou_yunshang、xiyou_power、xiyou_status_power、xiyou_skill_mastery、xiyou_super_acquire、xiyou_super_deploy、xiyou_difficulty_inherit、xiyou_difficulty_inherit_battle、xiyou_difficulty_inherit_load、xiyou_dungeon、xiyou_floor_inherit、xiyou_unlock_chain、xiyou_achievement、xiyou_achievement_badge、xiyou_autosave、xiyou_save_page、xiyou_save_events、xiyou_battleback_save、xiyou_options_basic、xiyou_options_misc、xiyou_battle_options、xiyou_notice_options、xiyou_hangup_options、xiyou_hangup、xiyou_change_clothes、xiyou_drop_record、xiyou_review_regressions、xiyou_test_mode、xiyou_system_evidence、xiyou_weak_challenge。没跑的其余约 300 个留给总装合并选测（标记关时挂点都直接返回，预期不受影响）。
- 合 main（rules10、ui10、accept3、review-45）后补齐、`同步正式西游.py --accept-additions`（测量不变，留了产物指纹），再跑 xiyou_weak_challenge、xiyou_rules10、xiyou_determinism、xiyou_actor1_damage、xiyou_achievement，全过。
- `工具回归.py` 全过。
- `语法检查.py` 通过；`回退开关覆盖.py` 新开关已覆盖（测试里字面量 `XWeakChallenge.ENABLED = false`）。

## 本分支提交

- d62433a8 弱者挑战参照探针 weak_challenge_probe（20 例），进 PROBES
- e8d40e14 XWeakChallenge 一期＋专项 xiyou_weak_challenge
- 98261239 交付单、优化登记 O-待定
- 最后一笔：合 main、交付单可合并
