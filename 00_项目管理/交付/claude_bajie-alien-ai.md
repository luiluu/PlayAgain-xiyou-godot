# 交付：claude/bajie-alien-ai

- 车道／工作者：B／C 界面·规则／八戒_90（Claude，Opus／medium）
- 状态：可合并

## 变更记录草稿

## 2026-10-30 【Claude·八戒_90·未经Codex检验】智能 AI 对异化投影读投影估值（O-待定）；terminate 路径排查；异化专项读数（dev.待定）

1. **智能 AI 读投影估值（O-待定，可回退）**：`XSmartAI` 每个技能候选先 `valued`（`XAlienBattle.project`）再打分，目标方向、范围、伤害／治疗／增益估值全读投影；候选与返回的仍是原技能，`execute` 照旧再投影。
   - 逆祷：攻击按治疗友方估值，治疗量 `healing_amount` 照 `prayer_heal` 的口径，借治疗技能（原技能 MP 费用 ≥125 治疗术 166、≥75 次级治疗术 135、否则治愈 8）的 safeDamage × 受疗率，平分给目标数（友方单体 1、原 scope 3～6 随机 n、其余全体存活友方）；原 scope 3～6 的投影（scope 8）按随机 n 个友方加权。冷却折扣看原技能备注（投影抄的是治愈的备注）。
   - 祸祝：按对敌减益与诅咒估值。恶愿：目标去掉自己（`filter_targets`），付不起代价（新 `XAlienBattle.wish_affordable`，从 `pay_wish` 拆出的纯判断）记 0 分。
   - `alien_battle.gd`：`prayer_heal` 的治疗技能选择拆成 `prayer_healer`（行为不变）。
   - 开关 `XSmartAI.o_projection`（默认开）；关掉回到此前做法。非异化角色 `project` 原样返回，开关对他们没有影响（smart_ai 参照对照不变）。
2. **原生自动战斗**：原版 `XdRs_HangUp` 改写的 `makeAutoBattleActions` 只在 `MakAct.IsOldAi` 时走 `Game_Action.evaluate`，而 `makeAction` 里设它的那行被注释掉了，原版走不到原生评估；重制 `auto_battle_action` 本来也不移植它（顺序表 → 智能 AI → 普攻）。两边一致，无需修。挂机顺序表不动（执行时投影，与原版一致）。
3. **terminate 路径排查**：上期探针在 `state_effects_probe` 的 `action.counter` 例报出 YEP_SkillMasteryLevels `updateSkillMasteryUsageMax` 报错 → `SceneManager.terminate`。查明**不是原版缺陷，是探针用例的副作用**：该例用 `JsonEx.makeDeepCopy($dataSkills[1])` 现场克隆一个技能推进 `$dataSkills`，深拷贝丢了 YEP 读备注时挂上的函数 `masteryFormula`，`skillFormula.call` 抛错后走 `SkillMasteryLevelsError`（alert＋terminate）。正式数据里每个技能在 DataManager 读备注时都有缺省 `masteryFormula`（YEP_SkillMasteryLevels.js:628），玩家走不到这条。重制同一路径（`xiyou_state_effects` action.counter，复制技能 1 改 hitType 1）正常继续，熟练度统一为 0、不调用熟练度公式；该例逐项对照通过。不记原版缺陷，不改代码。
4. **异化专项读数**：`xiyou_alien_affix` 的 `_unit` 里 `states` 改为 `x.state_ids.duplicate()` 再排序（`Array(Array[int])` 可能与 `state_ids` 同一份，排序会改到战斗者身上的状态顺序）。旧例全部重跑结果不变（见验证）。
5. **专项**：`xiyou_smart_ai`（第 0 份）加 `alien_projection`：1 号角色挂逆祷／祸祝（7100 临时去掉技能类型与费用），开关两支各断言——开：逆祷选攻击、目标是生命 20% 的 9 号，治疗估算与借来的治愈 8 同口径；祸祝 7100 目标是敌人且有分。关：逆祷攻击候选按对敌伤害打分、选中目标是敌人；祸祝 7100 目标是自己。共 6 项。
   - **没给 smart_ai_probe 加异化参照**：开关两支都不同于原版（见下「三方差别」），关掉那支也对不上原版，所以只写 Godot 侧断言。

### 三方差别（逆祷者的攻击、祸祝技能，智能 AI 开时）

| | 目标方向与范围 | 估值 | 结果 |
| --- | --- | --- | --- |
| 原版 Codex_SmartBattleAI | 读投影（action.item()） | 读原技能（candidate.item） | 逆祷攻击按友方找目标、却拿伤害技能算治疗量≈0；祸祝对敌、增益效果按对敌判不出收益≈0。全 0 分时退回「普攻打 HP 最低的敌人」，执行时投影成友方单体、目标序号落到同序号队友 |
| 重制此前（`o_projection = false`） | 读原技能 | 读原技能 | 逆祷攻击当对敌伤害打分、选敌人，执行时 `targets_for` 按投影改成 HP 比例最低的队友；祸祝当对自己／友方增益打分 |
| 新行为（`o_projection = true`，默认） | 读投影 | 读投影 | 逆祷攻击按治疗打分、直接选残血队友；祸祝按对敌诅咒打分、选敌人；恶愿付不起代价不选 |

## 交接板

- 下一步：O-待定（智能 AI 读投影估值，总装说合并时给 O-121）待用户确认。
- 用户试玩说明：带逆祷词条的角色开自动战斗（智能 AI）时，会用攻击去治疗残血队友；带祸祝的会对敌人用祸祝技能。
- 需要用户决定：O-待定 智能 AI 对异化投影读投影估值（保留／恢复原版——注意原版本身是半读投影半读原技能）。

## 进度账

- 无变化（异化部分的自动战斗收尾）。

## 可优化（流程／工具／效率）

- 建议：`state_effects_probe` 的 `action.counter` 例克隆技能后补上 YEP 挂的函数（`masteryFormula` 等，从原技能对象拷引用），探针就不再触发 terminate 记录；改探针会动参照产物，归 C 车道顺手做（收益：探针 stderr 里少一条误报）。
- 已做：无。

## 待交叉核查

- `smart_ai.gd`：`valued`、`prayer_targets`、`score_candidate`（恶愿过滤与代价、逆祷随机 n）、`healing_amount`（逆祷）、`has_cooldown`（投影看原技能）。
- `alien_battle.gd`：`wish_affordable`（从 `pay_wish` 拆出）、`prayer_healer`（从 `prayer_heal` 拆出）。
- 本单没改 battle_logic.gd、battler.gd 等核心文件。

## 验证

- 选测（`选测.py main` 选出 9 个场景）＋ `xiyou_state_effects`（terminate 路径的 action.counter）＋必跑 `xiyou_rules` 难度 1 四段，并行测试 14 个场景全部首轮通过（日志 `04_验证/本地结果/选测_ai.log`）：`xiyou_alien_affix` 1798/1798（与上期相同，`_unit` 改 duplicate 后旧例不变）、`xiyou_alien_battle` 330、`xiyou_battle_ui` 152、`xiyou_event_compare` 5、`xiyou_regen_popup` 26、`xiyou_smart_ai` 22133（含新 6 项）／`_b` 22038／`_c` 19531／`_d` 19531、`xiyou_state_effects` 19949、`xiyou_rules` d1 四段 115637／115733／115746／115725。没改战斗对照与切片，不加 `--oracle`、不重同步。
- 反向验证：smart_ai.gd 换回改动前（只补一个 `o_projection` 变量）、测试不变：`alien.on.*` 三项失败（prayer.choice、prayer.heal_estimate、blessing.foe），关的三项照过；已还原。
- 合 main（bajie-alien-gaps dev.221、wukong-c75a）：`alien_battle.gd` 的 prayer_heal 与优化登记表冲突，保留 main 的 O-119 注释与 O-119／O-120 两行，本分支的 prayer_healer 拆分与 O-待定 一行接在后面。合并后重跑 `xiyou_alien_affix`、`xiyou_smart_ai`、`xiyou_alien_battle`：全部首轮通过（1798／22133／330，日志 `04_验证/本地结果/选测_ai2.log`；排队等槽约 70 分钟，主工作区批测占满）。

## 本分支提交

- 见 git log（claude/bajie-alien-ai）。
