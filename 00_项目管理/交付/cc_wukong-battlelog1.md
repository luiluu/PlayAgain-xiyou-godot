# 交付：cc/wukong-battlelog1

- 车道／工作者：B 界面（战斗画面）／悟空（cc）
- 基线：总装九派单，从 cc/wukong-casino1 末端 93808909 切出（带着 itembag1、casino1 的提交与交付单；那两条先合了的话这里只多出本期），交付前合了 main f2b98e93。
- 状态：可合并

## 盘点：三位专属角色在原版走哪条显示路径

| 角色 | 原版（冻结 v0.28 js/codex/runtime/） | 显示路径 | 重制之前 | 本期 |
| --- | --- | --- | --- | --- |
| 宿傩 | installNativeSukunaRuntime `log(s)`＝`BattleManager._logWindow.push('addText', s)`：「X发动了神灶：开！」（open）、「X发动了空间斩／次元斩！」（begin 终式）、「X的伏魔御厨子持续斩击！」（endRound） | 战斗日志加一行（不清前面的行，不另等） | 逻辑层出 `battle_text` 记录，画面 `_play` 不认 | 接上：`_log_add` 加一行 |
| 宿傩 | 同上 `perform`：内部 Game_Action.apply＋startAnimation＋startDamagePopup＋displayActionResults | 动画、弹字 | 已是 hit 记录，画面照常 | 不用动 |
| 宿傩 | `Window_BattleEnemy.refresh` 包装：输入中的是宿傩的神灶 10232 时，敌人列表只留 `targetData(t).charged` | 选目标窗 | 列全部活着的敌人（逻辑层打没蓄力的不结算，技能可用条件已要求至少一个蓄力） | 接上：`XSukuna.selectable_enemies` |
| 渡鸦 | installNativeRavenRuntime `R.Fx.play(subject, target, type)`：战场层 4 个 PIXI.Graphics 轮流用，ring（神话封解进入神话形态）、slash（伤害技能每次 apply，不看命中）、harvest（冥界收割）、echo（回响） | 战场特效（不是日志文字；原版这两样没有日志行） | 没有特效 | 新 `XRavenFx`；ring／slash 记在命中记录 `raven_fx`，收割／回响沿用 regen 记录的 `raven` |
| 渡鸦 | `directDamage`：gainHp(−值)＋startDamagePopup＋performDamage＋倒下 performCollapse | 弹字、敌人闪烁／角色受伤动作 | regen 记录只弹字 | 接上：`_perform_damage` |
| 饿狼 | installNativeGarouRuntime `G.trigger`：追击／反击直接 apply，`_logWindow.displayAction(a, item)`＋`displayActionResults`＋`b.startAnimation(动画)` | 日志加一行技能名（YEP displayAction 的 `<SIMPLE>` 行）、动画、弹字 | 命中记录只放动画、弹字 | 接上：记录带 `garou_trigger`，画面 `_log_add_action`；原生反击（也带 counter 标记）不加 |
| 饿狼 | `creditVictory`：Boss 战突破到 333 时 `$gameMessage.add('饿狼突破神之境界，获得神之触媒×1。')`（processVictory 之前） | 消息窗（时机要看 Olivia 结算与消息窗的先后） | `victory_texts` 有字，画面没显示 | **留下一期**：要先用原版参照定消息出现在结算画面之前、之中还是回地图后 |
| 饿狼 | `Scene_ActorAdvanced.onBottomConfirmOk／onConfirmOk` 包装：条件不足 buzzer＋`$gameMessage.add(原因)`、不走原确认；进阶失败同样 | 菜单场景里没有消息窗，消息排队到回地图才出 | 重制走 O-094 的右上角提示「进阶条件未达成：原因」，确定音不是 buzzer；成功也提示「进阶成功」 | **留下一期**：先查原版回地图后那句消息、O-094 对饿狼要不要沿用，再定 |

## 插单：审查第 17 期 P2 归墟挂状态（pushstate，合并 bbeecb5b）

- 原版：installDamageElementRuntime 的 makeDamageValue 包装把挂状态回调推进 `result._after`，回调里排除写成 `CodexAlienation.isAttackDamage(this)`；运行时是严格模式、`part()` 用 `fn(r)` 直调，`this` 为 undefined，isAttackDamage 恒为假，所以归墟（异化 void）角色的攻击伤害照样挂 PushState／PushsubState。
- 参照：`pushstate_probe.cjs` 补 5 例（产物照旧手工拷成 `tests/fixtures/pushstate_oracle.json`，23 例）：`void.1580.direct`（同其余各例只调 makeDamageValue＋onPreDamageStateEffects）、`void.1580.apply`／`void.1491.apply`／`void.6706.heal`（整条 Game_Action.apply，异化行动帧在内）、`plain.1580.apply`（不带归墟的整条 apply 对照）。结果：整条 apply 里敌人照样挂上 161，归墟的 addState 包装（voidState）也没拦；自己挂 42；治疗给友方挂 1561。探针为整条 apply 补了 `$gameParty._inBattle`、`actor._alienBattle`、BattleManager 替身和云裳 `_acted` 表。
- 重制：保留排除，做成开关 `XBattleLogic.VOID_PUSH_EXCLUDE`（true 默认＝照本意排除；false＝照原版照挂）。照挂那支在 `_push_states` 里垫一层不是攻击的行动帧（`XAlienBattle.push_action(u, {})`），让 `blocks_state` 不拦，同原版；抽出 `_push_rows`。
- 影响面：只在带归墟异化、伤害类型 1／2／5／6、身上有 PushState／PushsubState 标签时。治疗（RecPushState）两支都照挂。
- 专项 `xiyou_pushstate`：void.* 两支都跑（关时对原版、开时攻击类不挂、治疗照挂），103/103。

| 编号 | 名称 | 原版 | 重制 | 恢复方法 | 状态 |
| --- | --- | --- | --- | --- | --- |
| O-待定 | 归墟攻击不挂 PushState | installDamageElementRuntime 排除写成 isAttackDamage(this)，this 为 undefined，归墟攻击照挂 PushState／PushsubState | 照本意：归墟的攻击类伤害不挂（治疗的 RecPushState 照挂） | `XBattleLogic.VOID_PUSH_EXCLUDE = false` | 待用户确认 |

## 插单：审查第 17 期 P3 事件对照登记

- `tests/event_compare_baseline.json`：match 5752 → 5750（登记 m4e1p2／p3 之后 5753 例里 3 例不一致）。
- note「该分支后面没有别的指令」改成：第 2 页选项块后还有 20 条打开开关（318、324～342，121 参数 0＝ON；第 3 页没有），称号事件不读这些开关，setupStartingEvent 先跑预约，结果一样。派单原话写「关开关」，查 Map004 EV1 数据是打开，按数据写。
- 本机这次跑 `xiyou_event_compare` 是 5806 例、5803 一致、3 例登记内、无退步（generated/oracle 是主工作区较新的产物），登记文件里的数字照派单改，没用 --update-baseline 重写。

## 顺手：合 main 后 bulk_pills 调用已删的函数

- main 上的 bulkpills1b `core/bulk_pills.gd` 调 `XPassiveBooks.begin_item(s)`，itembag1 已删这个函数（只清 capacity_refund meta，那个 meta 也一起删了），合在一起解析报错。删掉这行；已告诉总装九（合 itembag1 时同样要删）。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】专属角色战斗画面遗留：宿傩日志与神灶选目标、渡鸦特效、饿狼追击／反击日志（dev.待定）

- 战斗日志能多行：`battle_scene.gd` 加 `_log_add`（Window_BattleLog.addText，最多 10 行）与 `_log_add_action`（不清日志的 displayAction 行）；`_play` 认 `battle_text`。行动记录和行动序列之间夹着的 `battle_text` 先加进日志再交给序列（现有宿傩技能都没有序列，防将来）。
- 宿傩：「发动了神灶：开！」「发动了空间斩／次元斩！」「伏魔御厨子持续斩击！」出现在战斗日志；神灶选目标只列蓄力的敌人（`XSukuna.selectable_enemies`，`_pick_target` 调）。
- 渡鸦：新 `battle/raven_fx.gd`（XRavenFx，R.Fx 的四种图形与逐帧淡出）；`XRaven.applied` 在命中记录记 `raven_fx`（ring／slash）；收割／回响的 regen 加 performDamage（敌人闪、角色受伤动作）与特效。
- 饿狼：`XGarou.trigger` 的命中记录记 `garou_trigger`；画面在日志里再加一行追击／反击的技能名。
- 抽出 `_perform_damage`（hit 与渡鸦 regen 共用）。
- 专项 `xiyou_battle_log`（新）。
- 插单（总装九）：O-待定 归墟攻击不挂 PushState 开关 `XBattleLogic.VOID_PUSH_EXCLUDE`，pushstate 参照补 5 例；事件对照登记 match 与 note 改正；`bulk_pills.gd` 删掉已不存在的 `XPassiveBooks.begin_item` 调用。

## 验证

- 专项 `xiyou_battle_log`（新，30/30，单跑 8 秒）：真战斗画面（敌群 2、地图 5，队伍宿傩／渡鸦／饿狼 55 级）。宿傩：行动后的 battle_text 是技能名下面第二行、回合末单独一行、播完清日志、日志最多 10 行、神灶过滤（别的技能／别的角色不过滤）与 `_pick_target` 实际的目标池；渡鸦：`XRaven.applied` 记 slash（不看命中，别人不记）、命中记录的 ring／slash 与收割／回响 regen 依次放进特效层、4 个图形轮流、ring 28 帧／弧 16 帧、每帧 ×0.88 与 +0.025、到时隐藏；饿狼：`XGarou.trigger` 记 `garou_trigger`，追击在主行动技能名下加一行，原生反击只出「%1的反击！」。
- 选测（CHECK_JOBS=3，墙钟 13 分钟）19 场景全过、无偶发：`xiyou_battle_log`、`xiyou_sukuna_battle`、`xiyou_raven_battle`、`xiyou_raven_soul`、`xiyou_garou_battle`、`xiyou_garou_progress`、`xiyou_battle_ui`、`xiyou_battle`（前缀扩出 `xiyou_battle_common_events`、`xiyou_battle_options`、`xiyou_battle_events`、`xiyou_battleback_save`、`xiyou_battle_gaps`、`xiyou_battle_common_event_child`、`xiyou_battle_start_event`）、`xiyou_sequence_visual`、`xiyou_action_sequence`（`_play` 序列判定）、`xiyou_regen_popup`、`xiyou_popup_overlap`（`_perform_damage` 抽出、regen 弹字）。日志 `04_验证/本地结果/并行测试/20261101_031447_zjy0goqd/`。
- 插单与合 main 之后再跑 8 场景（CHECK_JOBS=3）全过：`xiyou_pushstate` 103/103、`xiyou_event_compare` 5/5、`xiyou_alien_battle`、`xiyou_designation`、`xiyou_bulk_pills`、`xiyou_item_bag`、`xiyou_casino_batch`、`xiyou_battle_log`。日志 `04_验证/本地结果/并行测试/20261101_033440_juxsjdbw/`。
- `语法检查.py` 通过（合 main 后先报 bulk_pills 解析错误，修后通过）。
- 没做原版参照探针：这几处都是把原版已知的写法照搬到画面（文字取各模块已有、已对过原版的记录），特效常量逐条抄自 R.Fx；时机只到「哪一条记录之后」，没有逐帧对原版截图。

## 交接板

- 下一步：饿狼 victory_texts「神之触媒」消息与进阶原因提示（盘点表最后两行，要先做原版参照定时机）；技能分类与指令窗、星空外观、宿傩完全体外观 2643 仍在原遗留里。交接板「宿傩画面遗留」「渡鸦遗留」里的战斗日志／特效两项、「白龙」条里的追击／反击战斗日志可以划掉。
- 用户试玩说明：宿傩展开领域、神灶：开、终式时战斗日志会多一行说明；神灶只能点蓄力过的敌人；渡鸦出手、收割、回响、进神话形态时目标上有紫／蓝色弧光或光环；饿狼追击、反击时日志多一行技能名。

## 进度账

- 专属角色画面遗留：宿傩日志与选目标、渡鸦特效、饿狼追击／反击日志完成；饿狼神之触媒消息与进阶原因留下一期。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 38465517 WIP：画面接日志、神灶选目标、渡鸦特效、饿狼追击／反击行
- 2f18c148／d98ca28d WIP：专项 xiyou_battle_log、交付单草稿
- 14928c60 交付单（战斗日志部分）
- c8180f67 WIP：插单 P2／P3、bulk_pills
- 交付单定稿（本提交）
