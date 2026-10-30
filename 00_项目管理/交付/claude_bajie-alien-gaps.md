# 交付：claude/bajie-alien-gaps

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_89）
- 状态：WIP 勿合并
- 本期：异化补漏——前几期交付登记过「没做」的边角集中补（每项先补参照用例，再实现，专项逐步对照）。夺舍本期不做。

## 现状

（收工时填）

## 逐项结果

| # | 项 | 结果 |
| --- | --- | --- |
| 1 | 绝缘 setHp 路径 | 实现在 dev.208 已有（`routes_set_hp` 含绝缘，setHp 改走 gainHp(差值)），本期补参照例 `insulation.sethp`、`sacrifice.sethp`：外来抬高拒收（舍身转给队友）、外来压低照扣、自己设照常，逐步对得上 |
| 1 | 绝缘对云裳 wake／addActions／freeGift（Adv:194） | **做不了**：重制没有云裳的战斗运行时（installNativeYunshangRuntime 的唤醒、赠行、储行、免费赠礼都没移植，`alien_battle.gd` 百相、蚀术处早已注明「重制没有这两种行动来源」）。等云裳战斗侧移植时一起接：三处包装都只是「绝缘者被外来唤醒／加行动返回 false，绝缘者不能收免费赠礼」 |
| 2 | 疫囊者阵亡保留状态；囚厄／绝缘在 clearBuffs 时保留 | 已做。原版 die() 里先 `_hp=0` 再 clearStates／clearBuffs，这时还没有阵亡状态，`isAlive` 仍真，疫囊的 pestStates 保留；囚厄接收的状态与减益、恶愿代价、绝缘者被外来打倒时身上的登记增益与增益也保留。重制阵亡分支原来直接清空，现照 `keeps_state`／新 `keeps_buff` 保留（`XAlienBattle.dying` 记正在 die 的战斗者，让疫囊判活）。参照例 `pest.death`、`jail.death`、`insulation.death`；O-106 开时囚厄接收到的角色减益阵亡也保留（`o106.jail_death_buff_kept`，原版对角色减益本来不转，见 O-106） |
| 3 | 锁队检查「已倒下」「重复绑定」 | 实现已有（dev.209 `eject_invalid`），本期补参照例 `lifelink.dead`（绑定的队友开战前已倒下→卸下）、`sacrifice.twice`（角色 1、2 都舍身绑定角色 8，后面的人卸下），比背包件数、是否还穿着、第三人是否锁上 |
| 4 | 逆祷者反击没投影 | 已做：`_invoke` 反击改 `apply(t, XAlienBattle.project(t, t.attack_skill()), u)`。原版反击变成「治愈」打在敌人身上（参照例 `prayer.counter`，敌人被打掉的 331 点生命补满）——**登记 O-待定**，默认打在敌人身上的逆祷治疗为 0，可回退（见「优化」） |
| 4 | 逆祷阻断没接 gainHp／setHp 行动帧 | 已做：`XResourceContext.gain`／`set_resource` 在帧来源是逆祷者、目标是敌人时扣血归零（Runtime wrapHp／setHp 包装）；另照 customEffectEval 包装，自定义状态效果执行时压一层来源为状态来源的帧（`state_effects.gd run_one`，只在有状态类词条的战斗里压）。参照例 `prayer.dot`（逆祷者挂给敌人的毒鸡汤 460，回合末自定义再生扣血被阻断） |
| 4 | 投影后 `is_attack` | 已做：`XBattler.is_attack` 遇到投影（带 `_alienMode`）恒否（原版比的是 item() 对象，投影是副本）。参照例 `prayer.repeat`（勇士 41 攻击次数 +1，逆祷普攻 numRepeats 仍是 1；石中剑把攻击换成 849，这例用未知的刀片 1521） |
| 5 | 自动战斗／智能 AI／挂机选技估值 | **只写方案**（见文末「自动战斗与投影方案」）：原版智能 AI 一半读投影一半读原技能，改动面大 |
| 6 | 事件增减 MP（312） | 已做：`mv_event_core.gd` 只改 312 分支（加 2 行，调新函数 `XAlienBattle.gain_mp_outside`），空壳回蓝变护盾、饕餮无效、绝缘拒收外来回蓝。参照例 `hollow.mp`、`glutton.mp`、`insulation.mp`（事件来源取 `_subject`，重制取行动根，事件里为空即自己） |
| 7 | 探针 host.cjs | 已做：`shared/host.cjs` 的 start 把 `SceneManager.terminate` 换成「记一笔（host.terminated）并抛错」，用例 errors 直接写出原因；alien_affix_probe 照旧自己覆盖成计数 |
| — | 技能生命消耗 | 重制没有这个机制，本期不做 |
| — | 逆祷借熟练度算治疗 | 熟练度统一 0，不做 |

## 变更记录草稿

## 2026-10-30 【Claude·八戒·未经Codex检验】异化补漏：阵亡保留、逆祷反击与帧内阻断、事件增减 MP（dev.待定）

1. **阵亡保留**（`battler.gd` 阵亡分支，Adv:169-175、Aff:75）：die 时疫囊者的 pestStates（此刻还没有阵亡状态，算活着）、囚厄接收的状态与减益、恶愿代价、绝缘者被外来打倒时的登记增益与增益都保留，复活后仍在；新 `XAlienBattle.keeps_buff`、`dying`。
2. **逆祷**：反击也读投影（`battle_logic.gd _invoke`）；投影不算普通攻击（`battler.gd is_attack`，攻击次数追加不加）；帧里对敌人的扣血无效（`resource_context.gd` gain／set_resource，新 `XAlienBattle.frame_blocks_hp`）；自定义状态效果压一层来源为状态来源的帧（`state_effects.gd run_one`，customEffectEval 包装）。
3. **事件增减 MP**（312，`mv_event_core.gd` 只改这一分支）：空壳回蓝变护盾、饕餮无效、绝缘拒收外来回蓝（新 `XAlienBattle.gain_mp_outside`）。
4. **O-待定**（可回退）：逆祷者的反击照原版变成治疗打在敌人身上，重制默认这份治疗为 0；`XAlienBattle.o_prayer_counter = false` 恢复原版。
5. 顺带：`XAlienBattle.end` 也清生命池与保护者标记（测试夹具重锁时卸下生命类配置后，旧池两人互相引用、Godot 退出报资源未释放）。
6. 参照：`alien_affix_probe.cjs` 加 13 例（共 44 例）：`insulation.sethp`、`sacrifice.sethp`、`pest.death`、`jail.death`、`insulation.death`、`lifelink.dead`、`sacrifice.twice`、`prayer.counter`、`prayer.repeat`、`prayer.dot`、`hollow.mp`、`glutton.mp`、`insulation.mp`；新步骤 `sethp`（行动外 setHp，来源 src）、event 的 `mp`／`src`，开战前 `dead`、第三名队员 `extra`、view 的 `repeats`。探针公用 `shared/host.cjs`：SceneManager.terminate 记一笔并抛错。
7. 没做：绝缘对云裳唤醒／赠行／免费赠礼（重制没有云裳战斗运行时）；自动战斗／智能 AI 按投影估值只出方案；原版 withFrame 收尾的「被逆祷帧扣掉的生命补回」兜底与帧内 gainHp／setHp 的烈变加成仍未移植（重制伤害走 executeHpDamage 已在外层拦下）。

## 原版依据

- `installAlienationRuntime.js`：A.withFrame（帧收尾补回）、gainHp／setHp 包装（帧里 A.blocksDamage）、customEffectEval 包装（来源 stateOrigin、kind dot）、invokeCounterAttack 包装。
- `installAlienationAffixes.js`：41-50（A.project、item() 替换、makeDamageValue）、51（A.blocksDamage）、64-75（疫囊 protectedState、clearStates）。
- `installAlienationAdvanced.js`：107（setHp）、111-112（gainMp）、169-175（removeState、clearStates、clearBuffs）、194（云裳三处）。
- `rpg_οbjects.js` command312（`actor.gainMp(value)`）；YEP_BattleEngineCore invokeAction／invokeCounterAttack（setAttack 后 apply）。

## 优化（O-待定，已加登记表行）

- O-待定：逆祷者的反击打在敌人身上的治疗为 0（`XAlienBattle.o_prayer_counter`）。原版反击走 item() 投影成治愈，把敌人刚打掉的生命补回去，和词条说明相反。回退：`o_prayer_counter = false`。登记表行写的是 `O-待定`，合并时请换号。

## 验证

（收工时填）

## 改了的原沙僧核心文件与独占表外的文件（待交叉核查点名）

- `battler.gd`：阵亡分支（keeps_state／keeps_buff、dying）；`is_attack` 投影恒否（热路径：多一次 has）。
- `battle_logic.gd`：`_invoke` 反击读投影（非异化战斗 project 第一步就按装备返回原技能）。
- 独占表外：`resource_context.gd`（gain／set_resource 各一处逆祷帧判断，4 行）、`state_effects.gd`（run_one 压／弹异化帧，只在 status_battle 时，5 行）、`mv_event_core.gd`（312 分支 2 行，派活交代准改）、探针公用 `mv_oracle/shared/host.cjs`（terminate 抛错，56 个探针共用）。请总装留意这几处有没有别的车道同时在改。
- 另：`alien_battle.gd`、`alien_affix_probe.cjs`、`tests/xiyou_alien_affix.gd`、`00_设计/优化登记.md`（O-待定 一行）。

## 交接板

- 下一步：异化剩夺舍（方案在 claude_bajie-alien-equip 交付单，等沙僧审）；自动战斗按投影估值见本单方案，等总装定要不要做；云裳战斗侧移植时顺带接绝缘三处。
- 用户试玩说明：疫囊、囚厄、绝缘的角色倒下再被复活，身上受保护的状态还在；逆祷者的反击不再打出伤害、也不给敌人回血；事件加减 MP 对空壳（变护盾）、饕餮（无效）生效。
- 需要用户决定：O-待定（逆祷者反击不治疗敌人）去留，默认保留，可回退。

## 可优化（流程／工具／效率）

- 已做：探针 terminate 抛错（派活第 7 项）。
- 建议：异化专项的读数（`_unit`）里 `states` 用 `Array(x.state_ids)`，与战斗者共用同一个数组，后面的步骤会改到前面行的读数（逐步对照时当场比不受影响，事后看 rows 会看到被改过的；本期 o106 检查踩到）。改成 `x.state_ids.duplicate()` 更稳，但会动到全部旧例的读法，本期没改，归下次碰这个专项时顺手。

## 自动战斗与投影方案（只出方案，未写代码）

### 原版行为

- 原生自动战斗（Game_Actor.makeAutoBattleActions → Game_Action.evaluate）：全程读 item()，即投影后的技能（逆祷的攻击按治疗友方估值、祸祝按对敌估值）。
- 智能 AI（Codex_SmartBattleAI，设置默认开）：`scoreCandidate` 用 actionFor 建行动，**目标方向与范围读投影**（action.isForOpponent／isForFriend／isForAll／numTargets 都走 item()），**伤害、治疗、增益估值读原技能**（recoveryUtility、benefit、expectedDamage 传的是 candidate.item）。逆祷者的攻击于是按「对友方」找目标、却拿原攻击技能（伤害类型 1）去算治疗量，估值近乎 0；全部候选都 0 分时退回「对 HP 最低的敌人普攻」（setTarget 敌人序号，执行时投影成友方单体，目标序号落到同序号的队友）。
- 挂机技能顺序表（XdRs_HangUp makeAction）：只 setSkill，不估值；执行时自然投影。

### 重制现状

- `XSmartAI` 全程读原技能（目标方向也按原技能），逆祷的攻击被当成对敌伤害技能估值、选敌人当目标；执行时 `execute` 投影成治疗友方，`targets_for` 按投影的 scope 重选友方目标。结果与原版不同的地方：候选排序（原版近乎 0 分，重制按伤害打分）与目标（原版落到同序号队友，重制按投影范围的缺省目标）。
- 挂机顺序表：与原版一致（执行时投影）。

### 要不要改、怎么改

- 照原版要把 `XSmartAI.score_candidate` 拆成「目标读投影、估值读原技能」两套，并照原版的退回规则（全 0 分→普攻打 HP 最低的敌人，序号落到队友）。这是在复制原版的不一致，改动落在 smart_ai.gd 的目标与范围判断十余处，还要补智能 AI 探针（smart_ai_probe 现在不带异化）。
- 建议：不照抄原版，作为 O 号候选「智能 AI 对异化投影一律读投影估值」（逆祷的攻击按治疗估值、祸祝按对敌估值），比原版合理；或维持现状（只影响带逆祷／祸祝／恶愿的角色在自动战斗时的选技）。等总装与用户定，本期不改代码。

## 本分支提交

- 见 git log（claude/bajie-alien-gaps）。
