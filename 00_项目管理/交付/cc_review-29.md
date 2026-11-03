# 交付：cc/review-29

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `2784a3c6` 切出，只加本交付单。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 心钢狂妄、奈叶共享击杀、批量丹药数量窗、谷雨强制行动、沿用认失败、普查认再次释放、星谱不可用，及 battle_logic 冲突解法

- 核查覆盖：cc/bajie-growth1（80990e8d）；cc/bailong-ui1、cc/bailong-tails1（9fd39c6c）；cc/wukong-nanoha1（2d4e1b1c）；cc/nezha-tools46（05b5ff87）；cc/nezha-tools47（d05fcd66）；cc/bailong-tusu8（71b18ad5）
- 结论：P1 无，P2 无，P3 四条，其余通过。总装在 `battle_logic.gd` 解的冲突（奈叶 begin／end_execute 包住 execute、`finish` 在谷雨 `after_action` 之前；apply 里奈叶 `applied`、心钢 `after_apply` 排在谷雨 apply 之后）对照原版装载次序是对的，返回值走向也对。查出的次序偏差不在总装解的那几行，在 growth1 自己加的钩子：P3-1 `act()`／`_forced_run` 里心钢、狂妄的 endAction 前半段排在屠苏、谷雨前面，原版正好相反（屠苏 137、谷雨 133 在外层，前半段先跑）；P3-2 心钢 `blocks_apply` 放在谷雨 apply 外面，原版在谷雨里面（谷雨先打行动执行标记）。P3-3 批量丹药数量窗垫的底色铺满整个窗，原版只铺内框（缩进 4）。P3-4 tools46 只给本机记录带了失败集，云端失败的运行整条跳过，较旧的通过仍会被沿用。详见下文「报告」。
- 验证：对着冻结 v0.28 读码（`js/main.js` 装载次序，奈叶、心钢、狂妄、谷雨、屠苏、绑定运行时的 endAction／apply 包装，`rpg_windows.js` Window_ShopNumber，`installBulkPillsRuntime.js`）；本树专项并行测试见「验证」；`测试选测.py` 90/90。

## 报告

### 重点：battle_logic.gd 冲突解法

原版装载次序（`js/main.js`，后装的包在外层）：奈叶 103 → 心钢 111 → 狂妄 112 → … → 谷雨 133 → 护盾账本 134 → 绑定 135 → 璇 136 → 屠苏 137。所以 BattleManager.endAction 的实际执行是：

1. 前半段（外到内）：屠苏（剑气／镇魂内部施放、消费锁定）→ 绑定 → 谷雨 `G.end`（代命成立就归根）→ … → 狂妄（`settleDeaths`、行动数＋1）→ 心钢（不是巨人吞噬就减 1 蓄力）→ 奈叶（取本次行动的目标表，**此刻**判奈叶是否合格）→ 更里层（甚尔、镜流、米拉、渡鸦）→ 原 endAction；
2. 后半段（内到外）：奈叶（目标表里已死的敌人各给奈叶生命 10、魔法 30）→ … → 谷雨 `afterAction`（花期绽放）→ 绑定（清行动者、validate）→ 屠苏。

Game_Action.apply 外到内：屠苏 → 绑定 → 谷雨（`doSpecial`；特技没成就 `clearResult` 返回；**先置 `e.executed = true`** 再调里层）→ 狂妄（深度计数，最外层结束时 `settleDeaths`）→ 心钢（巨人吞噬没放成、已结算过、不是本次行动就整次返回；记打前生命）→ 奈叶（记打前是否活着的敌人）→ 原 apply；返回时奈叶记目标 → 心钢按权重记待结算 → 谷雨 makeSuccess／伤害统计。

逐条对照：

| 位置 | 重制次序 | 原版 | 结论 |
| --- | --- | --- | --- |
| `_forced_run`／`act()` 奈叶 `begin`／`end_execute` | 只包住 `execute` | 目标表挂在本次 Game_Action 上，追击、反击、绽放、屠苏剑气都是另建的行动 | 通过 |
| 奈叶 `finish` 与谷雨 `after_action` | 奈叶先、谷雨后 | 奈叶后半段在里层，先跑 | 通过 |
| 心钢／狂妄 `end_action` 与屠苏、谷雨 `end_action` | 心钢 → 狂妄 → 屠苏 → 谷雨 | 屠苏 → 谷雨 → 狂妄 → 心钢 | **P3-1** |
| apply：奈叶 `applied`、心钢 `after_apply` 在谷雨 apply 之后 | 谷雨后半段 → 奈叶 → 心钢 | 奈叶 → 心钢 → 谷雨后半段 | 通过：谷雨后半段只对谷雨自己的特技 makeSuccess、记伤害统计，不改目标生命和命中，奈叶／心钢读到的一样 |
| apply：`live`、`hp_before` 在谷雨 apply 之前取 | 谷雨前半段之前 | 谷雨前半段之后 | 通过：谷雨 `_special` 只动我方（治疗、花荫、转移），不改敌人生命 |
| apply：心钢 `blocks_apply` | 谷雨 apply 之外，拦了谷雨不跑 | 谷雨之内，谷雨先置 executed | **P3-2** |
| 返回值 | 屠苏／绑定／心钢拦截返回空结果；其余返回谷雨（含 `_apply_core`）的结果 | 原版 apply 返回值没人用，结果在 `target.result()` | 通过 |

另看了不算问题的两处：

- 奈叶合格判定原版在 endAction 前半段取（里层甚尔／镜流／米拉／渡鸦和原 endAction 跑之前），重制在 `finish` 里才判。只有奈叶在这些里层收尾里倒下或离队才不同，现有机制里没找到会这样的路径，不记问题。
- 狂妄原版还包了 apply（最外层 apply 结束就 `settleDeaths`），重制只在 endAction／endTurn／endBattle 结算。原版倒下由 YEP 延后挂、`_deaths` 靠 `die()` 填，加上击杀判定本来就改成了「打到 0 血」（O-待定），结算时点已是重制自定；参照 `hubris.fix.*` 量过，不记问题。

#### P3-1 心钢、狂妄的 endAction 前半段排在屠苏、谷雨之前（与装载次序相反）

- 位置：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd` `act()` 837～840 行、`_forced_run` 1234～1237 行（growth1 加的，不是总装解冲突时排的）。
- 原版依据：`js/main.js` 111／112 心钢、狂妄在 133 谷雨、137 屠苏里层；`installNativeTusuRuntime.js:351` 屠苏剑气／镇魂在 `old.apply` 之前；`installNativeGuyuRuntime.js:362` `G.end` 在 `old.apply` 之前；`installNativeHubrisRuntime.js:155`、`installNativeHeartsteelRuntime.js:203` 都是前半段。
- 影响（按代码读出，没跑原版复现）：
  - 屠苏持武者穿着狂妄：剑气／镇魂打出的贡献在原版记的是「行动数＋1 之前」的值，重制记的是＋1 之后，`_qualified` 的「2 次行动内」多算一次行动；剑气打死的敌人原版在本次 endAction 就进结算（狂妄前半段在屠苏之后），重制拖到下一个结算点。
  - 谷雨穿着狂妄：本次行动里代命成立（队友免死、谷雨待归根），原版 `G.end` 先让谷雨归根倒下，狂妄再结算，谷雨不合格（`a.isAlive()` 假）；重制先结算，谷雨还活着就拿到扬名和待存盛名。谷雨自己是行动者时，心钢蓄力减 1 与狂妄行动数＋1 也会多算一次。
- 建议：把两处的 `XHeartsteel.end_action`／`XHubris.end_action` 挪到 `XGuyu.end_action()`／`take_visuals()` 之后（狂妄在心钢之前：外层先跑），heartsteel_probe 补一例「屠苏剑气＋狂妄」或「代命＋狂妄」对照。派八戒（growth2 正在做同一对文件，可以一起）。

#### P3-2 心钢 `blocks_apply` 在谷雨 apply 外层，拦下时谷雨没打行动执行标记

- 位置：`battle_logic.gd` `apply()` 1839～1840 行。
- 原版依据：`installNativeGuyuRuntime.js:316～324` 谷雨 apply 在调里层（含心钢）之前置 `e.executed = true`，心钢（111）在里层才 `return`。
- 影响：巨人吞噬被拦（没放成、已结算过、不是本次行动对象）时，原版谷雨仍记本次行动「执行过」，花期里的绽放（`after_action` 要 `executed`）照样触发；重制不触发。正常出手 meets 已经保证能放成，第一个目标就置了 executed，所以只有「强制行动放没蓄满的巨人吞噬」才走得到；现有事件数据里没找到对 10227／10228 的强制行动，眼下走不到。
- 建议：把心钢拦截挪进谷雨之内：在 `XGuyu.apply` 置 executed 之后、`_apply_core` 之前判（比如给 `XGuyu.apply` 加一个里层回调，或者把拦截挪到 `_apply_core` 开头）。优先级低，可以跟 P3-1 一起派八戒。

### growth1（心钢＋狂妄，dev.281）

逐项对了 `installNativeHeartsteelRuntime.js` 与 `installNativeHubrisRuntime.js` 的 startBattle、startAction（施放有效＝技能对、蓄力 0；有效就蓄力 3、记施放）、apply（拦截条件、打前生命大于 0、命中按权重、一次施放只记一次）、endAction（没施放、带着、活着、不是强制行动才减 1）、endTurn（每个全局回合一次回 3%／5%）、settleDeaths／qualified（活着、同一件、行动数差不超过 2）、executeHpDamage 包装（贡献、首领分段）。巨人吞噬 10227／10228 数据里 repeats 1、单体，原版 numRepeats 强制 1 对重制没有差别。甚尔抑制行动不减蓄力、动态说明、锻造等交付单已列为未做。O-待定（狂妄击杀判定，`KILL_FIX`）有回退、有原版口径参照。除上面 P3-1、P3-2 外通过。

### ui1＋tails1（dev.280）

- ui1 批量丹药数量窗：对照 `rpg_windows.js` Window_ShopNumber（createButtons、placeButtons、buttonY、isOkTriggered、updateButtonsVisiblity）与 `installBulkPillsRuntime.js`（buttonY＝行高×5＋12＝192、宽 456、不透明 255、`_refreshBack`）。五键的帧、宽、间距 16、居中、按「最近一次输入是触摸」才显示，左键不再确定、滚轮无效、右键取消，都对。
- **P3-3 底色铺的范围比原版大**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/mv_window.gd` `_draw()` 里 `draw_rect(r, backdrop)` 铺满整个窗；原版 `_refreshBack` 填的是 `_windowBackSprite` 的位图，背景精灵在 MV 里缩进 margin 4（重制 `xwindow_style.gd:26` 的 `rect.grow(-4)` 也是这么画背景的）。外圈 4 像素原版是皮肤边框本身（四角有透明），重制在边框下面多垫了 #111827，四个圆角外会露出深色小角。影响只在画面。建议改成 `draw_rect(r.grow(-4), backdrop)`，派白龙。
- 小差别不记问题：原版 Sprite_Button 是按下再松开才触发，重制按下就触发。
- tails1 谷雨强制行动：`_forced_run` 补谷雨 `end_action`／`take_visuals`（屠苏之后）和 `after_action`（奈叶之后），与 act 一致；guyu_battle_probe 加了 forced 例（事件强制普攻触发绽放、谷雨自己被强制治疗），探针走的是原版 forceAction＋processForcedAction。通过。

### nanoha1（奈叶一期，dev.279）

对 `installNanohaSharedKillRuntime.js` 逐行：合格条件（行动者是出战的别的角色、奈叶学会 10168 与 5683、活着、出战、在战斗中）、apply 后命中且打前是活着的敌人才记、同一目标只记一次、endAction 后对已死的给 addParam(0,10)／(1,30)；读档补学不移植（不迁移 MV 旧存档，交付单写了）。目标表只在 execute 期间开，追击、反击、绽放、剑气不算，和原版「挂在本次 Game_Action 上」一致。

- 小差别不记问题：重制用 `missed`／`evaded` 判命中，原版 `isHit()` 还要 `used`。谷雨的终结特技没成时，原版 `clearResult` 后 `used` 假、不记；重制谷雨这一支返回的结果 `missed=false`，会记进目标表。被记的那个敌人要在同一次行动里死掉才有影响，终结没成的那次行动不会伤到它，实际走不到。

通过。

### tools46（沿用认失败、抽样种子数合并提交）

- 审查 27 的两例复现已写成 `测试选测.py` 的 `test_failed_part_is_not_replaced_by_group_mate`、`test_newer_failure_beats_older_pass`，本树跑 90/90 通过。`plan()` 取「没被波及的提交里最新一条」，最新失败就照跑、不拿同组替补；本机记录和云端记录合并后按候选提交顺序（新的在前）重排。种子改成 `--first-parent --merges --count`，合并和它的收尾提交同一段。审查 27 P2-1（本机部分）、P3-1 可销账。
- **P3-4 云端失败的运行没有进失败集**：`03_再刷重制_Godot/07_开发环境/沿用车道.py` `cloud_records()` 遇到 `passed` 为假的结果直接 `continue`，返回的三元组失败集永远是空的（文档串写着「通过的场景、失败的场景」）。`云端选测.py:652` 的结果里其实有 `failed` 名单。后果：较新的提交在云端跑挂了某个场景，较旧的提交在本机或云端通过了它、两边都没被波及时，还会沿用旧的通过，跟审查 27 P2-1 是同一个洞，只是换成了云端（11-01 起合并默认 `--cloud`）。建议：失败的运行也读进来，把 `res['failed']`（没有就整份 `sceneNames`）放进失败集，`测试选测.py` 加一例「云端新失败压过旧通过」。派哪吒。

### tools47（普查认再次释放、slice_probe 只量指定角色）

- 普查：只有原文同时含 `new Game_Action(actor, true)` 和 `BattleManager.forceAction(actor)`、而且战斗解释器（`_try_battle`）一条不漏才算原生处理；已知清单删了 39 条，新断言 `native_recast_seen ≥ 30` 防口径失效，没认下的变体会回到 unknown 被 `no_new_unknown` 抓到。CodexFreezeFollowup 变体留在清单。通过（专项结果见验证）。
- slice_probe：`XIYOU_PROBE_ACTORS` 过滤 ACTORS（第 53、81 行两处循环都只用 ACTORS），切片外报错，产物改写 `.sandbox/slice_actors`，不覆盖同步用的那份；每个难度量完就写，默认输出不变。通过。
- 第 3 项（选测窄口径）只有方案，没有代码，不核。

### tusu8（dev.282）

- 审查 28 P3-1：`MENU_UNBUILT = [10349]`，`usable()` 返回假（蜂鸣，跟原先一样）；星谱页还没做，交接板已列。P3-2：`ok()` 的 list 分支直接用后补 `_refresh()`；`use_skill()` 预约了公共事件、发了 `closed` 后再 `_refresh()` 也没坏处（重画的是还没释放的窗）。P3-3：专项 `xiyou_skill_menu_events` 跑了 74 个公共事件，只有 9015 被跳过，有单独的不可用断言。审查 28 三条 P3 可销账。通过。

## 交接板

- 待交叉核查：删掉 growth1、ui1、tails1、nanoha1、tools46、tools47、tusu8 七行。
- 发现的问题（未修）：P3-1、P3-2 派八戒（growth2 在改同一对文件，可以带上）；P3-3 派白龙；P3-4 派哪吒。
- 下一步：审查 27 P2-1（本机部分）、P3-1，审查 28 P3-1～3 销账。
- 用户试玩说明：无（只改文档）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 无新的。

## 验证

- 本树（main `2784a3c6`）并行测试 9 个全过（73 秒）：xiyou_heartsteel、xiyou_nanoha、xiyou_guyu_battle、xiyou_tusu_battle、xiyou_bulk_pills、xiyou_skill_menu_events、xiyou_script_census、xiyou_determinism、xiyou_battle_common_events。
- `python3 07_开发环境/测试选测.py`：90/90。
- 没跑全量（审查只跑专项）；P3-1、P3-2 是按原版代码读出的次序差，没有写原版复现探针，建议修的车道补参照例。

## 本分支提交

- 见 `git log 2784a3c6..cc/review-29`。
