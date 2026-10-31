# 交付：cc/bajie-blackflash

- 车道／工作者：C 规则／八戒（Claude，八戒_92，Opus／medium）
- 状态：可合并
- **分支名是 `cc/bajie-blackflash`**（不是 `claude/` 前缀；本会话的工作树守卫只许写自己的工作树，唐僧总装五交代在这里切）。从 `claude/bajie-sukuna2` 末端 c2eedb6e 切，带着宿傩第二期；请在 bajie-sukuna2 之后合。合并工具认 `cc/` 前缀要等哪吒 tools19。

## 机制对照（原版 `installNativeBlackFlashRuntime.js`，W.CodexBlackFlash）

| 机制 | 原版出处 | 状态 | 重制位置 |
| --- | --- | --- | --- |
| 共用注册表：甚尔 171（触发 10216～10219、觉醒技 10226、状态 2635、额外一击 10216）、宿傩 172（触发 10230／10238、觉醒技 10242、状态 2639、canRoll 体术或捌冲击段、暴击外部处理、onSuccess 斩击强化） | `B.register`（甚尔在本文件，宿傩在宿傩运行时） | 本期 | 新文件 `modes/xiyou/core/black_flash.gd`（XBlackFlash.CONFIGS） |
| 启用（学了 10225、活着）、觉醒（觉醒技、觉醒状态、expires ≥ round）、status | `valid`／`awake`／`B.status` | 本期 | `valid`／`awake`／`status` |
| 施放帧：只认战斗中主行动（不在反击／反射里、不是内部或强制行动），概率 min(0.45, 0.1＋0.05×集中＋觉醒 0.15)，eligible＝触发技能、单体、生命伤害 | `B.begin`（startAction 之后） | 本期 | `begin`：`execute` 两条路（宿傩 begin 之前）、防御支 |
| apply 命中帧、hits 计数 | `apply` 包装 | 本期 | `apply_begin`／`apply_end`（`battle_logic.apply`，异化三支早返之后） |
| 觉醒 ×1.2（awake 表里的技能）、判一次黑闪（随机 < 概率×(1−目标 cev)） | `evalDamageFormula` 包装 | 本期 | `formula`（`_calculate_damage`，原值算完之后；随机走规则流 `black_flash`） |
| 黑闪必暴击、CodexDamage 暴伤 +[1, 1.2, 1.4, 1.6][min(连闪, 3)] | `modifyCritical` 包装、`installDamageElementRuntime.js:157` | 本期 | `_calculate_damage` 的 critical、`_apply` 的结果暴击、伤害钩子 `criticalAdd`（XActorDamageHooks） |
| applyCritical 另加（非外部处理时） | `applyCritical` 包装 | 不需要 | CodexDamage 下不走旧暴击链 |
| 扣血记 damage、黑闪那次记 success | `executeHpDamage` 包装 | 本期 | `after_hp`（`execute_hp_damage`，宿傩包装之内） |
| 结束：成功集中 0、连闪 +1、觉醒 3 回合（加状态）、宿傩 onSuccess emp＝max(emp, min(连闪, 4))；失败连闪 0，eligible 且打出伤害集中 +1 | `B.finish`（endAction，宿傩之内） | 本期 | `finish`（`act` 里宿傩 finish 之后） |
| 回合结束：不启用的清空、觉醒到期去状态、round +1 | `B.endRound`（宿傩之内、米拉之外） | 本期 | `end_round`（`end_turn` 里宿傩之后） |
| 不能行动、逃跑连闪归 0 | `processTurn`／`otbCheckIfBattlerIsUnable`／`processEscape` | 本期 | `act` 不能动支、`try_escape` |
| 开战、结束、阵亡清空 | `startBattle`／`endBattle`／`die` | 本期 | `start_battle`／`end_battle`、`battler.gd` die 支 `on_death` |
| 宿傩侧：施放帧 emp（觉醒时）、斩击强化 ×(1＋领域 0.35／否则 0.2＋0.05×(层−1))、内部神灶：开觉醒 ×1.2、终式关 eligible、回合结束不觉醒才清 emp、阵亡清数据 | `installNativeSukunaRuntime.js` | 本期 | `sukuna.gd` |
| 甚尔额外一击（觉醒时 10216 `_tojiHitCount`＋1）与甚尔其余运行时（33 KB） | `startAction` 包装、`installNativeTojiRuntime.js` | 下期（甚尔移植） | 重制没有甚尔模块；配置已登记，甚尔学不到 10225 就不启用 |
| 遗忘 10225／觉醒技清空、refresh 时不启用清空 | `forgetSkill`／`refresh` 包装 | 下期 | 战斗中不会遗忘；end_round 里不启用会清 |
| 旧档 unlock（学 10225、觉醒技） | `setup`／`levelUp`／`extractSaveContents` | 不需要（宿傩） | 宿傩由 `XSukuna.sync` 管；甚尔移植时补 |
| 宣告弹字「黑闪！」「黑闪·二连！」与日志、说明框实时状态行 | `announce`、`Sprite_ItemHelp` | 下期（画面） | |

顺带修的：**回合结束 clearResult**（MV `Game_Battler.onTurnEnd` 首句）。重制 `turn_end_battler` 没清 `runtime_result`，回合结束时去掉的状态（黑闪觉醒到期）下一回合再附加会被「本次结果已去掉」挡住；黑闪段第二次觉醒抓到。改成回合结束先清结果。

## 变更记录草稿

## 2026-10-31 【Claude·八戒_92·未经审查】黑闪共用模块（甚尔／宿傩）、宿傩第三期；回合结束清行动结果（dev.待定）

1. **黑闪 XBlackFlash**（冻结 v0.28 `installNativeBlackFlashRuntime.js`）：新文件 `modes/xiyou/core/black_flash.gd`，甚尔 171 与宿傩 172 共用注册表；施放帧、觉醒 ×1.2、判黑闪（概率随集中与觉醒、乘 1−目标暴击闪避）、必暴击与暴伤加成、集中／连闪／觉醒三回合、不能行动与逃跑断连闪、开战／结束／阵亡清空，逐项见本交付单「机制对照」。甚尔运行时未移植，只登记配置。
2. **宿傩第三期**：施放帧带觉醒时的斩击强化层（emp，体术或捌冲击段黑闪成功后得），解／捌／伏魔御厨子 ×(1＋领域中 0.35／否则 0.2＋0.05×(层−1))；觉醒时内部神灶：开 ×1.2；终式不判黑闪；回合结束不觉醒才清强化；阵亡清宿傩战斗数据。
3. **回合结束清行动结果**（MV `Game_Battler.onTurnEnd` 的 clearResult）：`battle_logic.turn_end_battler` 开头清 `runtime_result`。之前回合结束去掉的状态，下一回合再附加会被挡住（resource_context 的「本次结果已去掉」判断）。影响所有战斗：回合结束后、下一次被行动打到之前，先前去掉的状态能再附加。
4. **参照与专项**：`sukuna_battle_probe.cjs` 加 flash 一段（给定黑闪判定的随机数，B.random；防御后 TP 定回 100），`xiyou_sukuna_battle` 700 项（命中另比是否暴击，快照加集中、连闪、觉醒、概率、强化层），本地断言加阵亡清数据。
   - 反向验证：觉醒 ×1.2 去掉（3 项失败）、暴伤加成去掉（4 项）、斩击强化去掉（2 项）、回合结束 clearResult 去掉（18 项），都已还原。

## 交接板

- 下一步：甚尔 171 移植（运行时 33 KB；黑闪配置已在 XBlackFlash，额外一击 `_tojiHitCount` 等甚尔模块做）；画面车道：神灶选目标只列蓄力敌人、`battle_text` 日志（宿傩「发动了神灶：开！」、终式名、黑闪宣告）、黑闪弹字与说明框实时状态。
- 用户试玩说明：宿傩会打出黑闪了——体术或捌的冲击段有几率黑闪（必暴击、暴伤更高，连闪越多越高），之后 3 回合觉醒，解／捌／伏魔御厨子吃斩击强化，觉醒中的神灶：开更痛。
- 需要用户决定：无。

## 优化登记草稿

优化登记草稿：无

## 进度账

- 172 宿傩：战斗内机制完成（剩画面）。171 甚尔：黑闪共用部分就绪，本体未移植。

## 可优化（流程／工具／效率）

- 无。

## 发现的问题（不在本期范围，交总装）

- **防御不给 TP**：原版防御（技能 2，tpGain 10）走 Game_Action.apply，会得 10 TP；重制 `act` 的防御支不跑 `_apply`，不给。sukuna_battle 黑闪段防御后两边差 10 TP（专项里防御后把 TP 定回 100 绕开）。该派规则车道补一次参照再改。

## 待交叉核查（改了原沙僧核心文件）

- `battle_logic.gd`：`turn_end_battler` 的 clearResult（影响所有战斗）；`_calculate_damage` 里黑闪改原值与 critical；`apply` 的 `apply_begin`／`apply_end` 位置（三支早返之后）；`_invoke` 反射与反击的 `nested`；`act` 不能动支断连闪、防御支建帧；`try_escape`。
- `battler.gd`：die 支调 `XSukuna.on_death`／`XBlackFlash.on_death`。
- `actor_damage_hooks.gd`：capture 加黑闪暴伤操作。

## 下期清单

- 甚尔 171 移植（见交接板）。
- 画面：神灶选目标窗、战斗日志文字、黑闪弹字、说明框实时状态（派界面车道）。
- 防御 tpGain（见上）。

## 验证

- 专项：`xiyou_sukuna_battle` 700/700（参照 `sukuna_battle.json` 6 例，本工作树跑出）。
- 选测（`并行测试.py`，27 个场景全过、无偶发，3267 秒，中间等主工作区检查的槽）：xiyou_sukuna_battle、actor_modules、alien_affix、alien_battle、attack_element、attack_query、battle、battle_gaps、battle_common_events、battle_events、battle_ui、cat、custom_damage、mira_battle、race_battle、yomi_battle、rules 难度 1 四段、smart_ai 四段、help_card、difficulty_inherit_battle、module_hooks。clearResult 影响所有战斗，总装合并时建议加跑 `xiyou_rules` 全部段。
- 合 main（4da2ca97，含宿傩第二期合并与哪吒工具 18～20）：没碰 modes／转换工具，无冲突，不重跑。
- 同步：本工作树 `同步正式西游.py --accept-additions` 通过（新探针执行 1、复用 67，测量不变），指纹已留。

## 本分支提交

- 679b8854 黑闪共用模块与宿傩接线、阵亡清数据
- 33eb59b0 黑闪探针段与专项；回合结束 clearResult
- 合 main 4da2ca97；本提交：交付单可合并
