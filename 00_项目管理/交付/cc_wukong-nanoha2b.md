# 交付：cc/wukong-nanoha2b

- 车道／工作者：A 内容·楼层／悟空（cc，悟空 nanoha2 → nanoha2b 接续，Opus medium）
- 状态：可合并

奈叶二期三条都做完：②（上一位，nanoha2）、①③（本会话，nanoha2b）。分支从 `cc/wukong-nanoha2`（f1df1d94）切出，已合 main（4313494c，无冲突）。原 nanoha2 交付单已并进本单、删掉。

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】奈叶二期：领域与身经百战的公共事件预约、大招自定义 MP 消耗与多段、小魔炮自动战斗（dev.待定）

- **② 公共事件预约**（nanoha2）：
  - 原版参照：新探针 `mv_oracle/nanoha2_probe.cjs`（真实 `Scene_Battle.prototype.start`，含 `BattleManager.startBattle` 和 dsPassiveSkill 其后加的被动 StartPushState；再奈叶、队友各行动一次，回合结束；记每步 `$gameTemp.reserveCommonEvent`），产物拷成 `tests/fixtures/nanoha2_oracle.json`。结论：领域 1774 的 `<Custom Battle Effect>`（预约 2478）在原版**从不触发**（被动状态在 `startBattle` 跑完开战效果之后才加），开战只预约 1320，「魔法领域：全员按奈叶等级加全属性」在原版是死内容；身经百战 1780 只有奈叶行动开始时预约 2481（防转换），action_end 的 2480（攻转换）在 OTB 下不触发，队友行动、回合结束都不预约。
  - 转换器：`parse_state_effects` 把 battle／action_start／action_end 三个阶段里单独一句的 `$gameTemp.reserveCommonEvent(N)` 翻成 `{op: reserve_common_event, id}`（全库只命中 1774、1780；带条件的 887、1318、2007 等和 apply 阶段的 2033 不动）。
  - Godot：`XStateEffects` 新 op `reserve_common_event`，编号存进静态整数表；`battle_logic.gd` 新 `_take_state_reserves()`，在开战 battle 分发后和两处 `action_start` 之后取出交给 `XBattleCommonEvent.reserve`（单槽）。`NEVER_FIRED` 没动。切片 `extraCommonEvents` 加 2481（2478、2480 原版走不到，不加）。
- **① 大招 5703～5709 的自定义 MP 消耗与伤害后多段**（nanoha2b）：
  - 原版参照：新探针 `mv_oracle/nanoha3_probe.cjs`（真实 `BattleManager.startAction`，记付费前后 MP、`skillMpCost`、`applyPostDamageEval` 收到的 value 与 `_costmp`、每次 `gainHp` 与弹字数），产物拷成 `tests/fixtures/nanoha3_oracle.json`，29 例。结论：实扣 MP＝⌊⌊当前MP×比例⌋×mcr⌋（`<Custom MP Cost>` 的 eval 改写 cost，数据库的 1000／9999 不算）；付费那次 `skillMpCost` 按付前 MP 写 `_costmp`＝⌊MP×比例/2000⌋；伤害后每个目标再 `gainHp(-value)`＋弹字 `_costmp-1` 次（同一 value，暴击与浮动只掷一次；全体技能每个目标都补；中途打死照补）；Bailong_NaiyeACS_FastSettlement 总段数超 512 时只留 96 段（桌面）逐段、其余合并成一次扣血。
  - 转换器 `xiyou_export.py`：新 `cost_hit_blocks`，只认完整形状，把 `<Custom MP Cost>` 翻成技能字段 `mpCostCurrentRate`／`costHitPer`、`<Post-Damage Eval>` 翻成 `postDamageCostRepeat`（全库只命中 5703～5706、5708、5709；2192 落日矢的 Post-Damage Eval 形状不同，不动）。
  - Godot：`battle_logic._skill_cost` 有 `mpCostCurrentRate` 时基础费用改 ⌊当前MP×比例⌋（之后照常 ×mcr、熟练度、减耗等包装）；`pay_skill_cost` 付费前 `XNanoha.note_cost` 写 meta `costmp`；`_apply` 生命伤害之后（BSC Respond／Establish 之前，同原版 YEP_SkillCore 在 BSC 里层）`XNanoha.post_damage` 补段：每段过 ShieldSystem 护盾吸收再扣血、记进 `r.extra`（弹字）与 `record_hp`（伤害记录）；value 用进 executeHpDamage 之前的值（Boss 输出等包装在里层，补段不乘，同原版）；超 512 段走 ACS：95 段逐段、尾段合并一次扣、记录按 ⌊每段⌋×段数。
- **③ 小魔炮 5692**（nanoha2b）：
  - 手动战斗：5692 的效果 44 预约 CE2483「魔炮选择」，102 六选一 → 339 强制奈叶放所选大招；重制的战斗事件游标原本就支持选项与 339，切片早有 CE2483，没改代码，只加断言锁住。
  - 智能 AI（`smart_ai.gd`，照 Codex_SmartBattleAI `cannonOptions`／`safeDamage`）：奈叶会 5692 且能用时，候选里已会的 5703～5709 换成六档魔炮（不必学会、各自能用）；估伤先按付费后的 MP 算公式、再 ×max(1, ⌊付前 MP×比例/2000⌋)。参照 `nanoha3_probe` ai.*（MP 0／1500／6667／23000／50000、低血敌、不会 5692）：原版 50000 MP 选 5704，其余选 5710 星光或普攻，重制逐例一致。
  - 没移植：`scheduledSkill`（按角色名＋回合查表的预定技能，预定 5692 时只在魔炮里挑）——重制 AI 还没有这张预定表；`nanohaFallback` 只在 choose 返回空时用，重制原有的「普攻打最低血→防御」退路已覆盖同一情形。
- 专项 `xiyou_nanoha`：44 → 223 条（field 段＋cast.*（MP、`_costmp`、每目标段数、每段同值、死活、弹字数）＋ai.*＋manual.*）。

## 交接板

- 下一步：奈叶二期完成。可接：AI 的 `scheduledSkill` 预定表（Codex_SmartBattleAI，按「角色名＋回合」查表；预定 5692 时只在魔炮里挑），等 AI 车道有空。
- 用户试玩说明：奈叶的凰霞风暴／厄临星爆现在按当前魔法的 30%／60%／90% 收费，每 2000 点多打一段（全体技能每个敌人都多打）；放小魔炮会弹六选一。自动战斗时奈叶会在六档魔炮里挑估伤最高的。身经百战每次行动前把双防的一部分转成双攻（CE2481），跟原版一样。
- 需要用户决定：（可选，默认不做）领域 1774 在原版是死内容，「魔法领域」说明写的全员加成玩家永远拿不到。要不要当作原版缺陷做活（登记优化、可回退）？默认照原版不做。

## 进度账

- 奈叶（108）二期：大招、小魔炮、领域／身经百战预约三项接完；奈叶专属机制只剩上面「可接」的 AI 预定表（不属奈叶独有）。

## 可优化（流程／工具／效率）

- 建议：`nanoha3_probe` 的宿主下奈叶普攻对 1 号敌伤害原版 1869、重制 359（大招各档也都是同一倍数 5.2），说明这套「newGame＋直接 setup 敌群 2」宿主里整条伤害链（或开局难度、被动）两边不一致，和多段无关；本专项改按结构比（段数、同值、MP），没追。建议派 C 车道（规则）用 `nanoha3_probe` 的 `cast.1.6667` 一例查：是探针宿主少了什么（难度、被动缓存），还是重制伤害链真有差。
- 原版次序上的小差（nanoha2 记下，未改）：原版 startBattle 先预约 1320、再跑开战效果；重制 `setup` 先跑开战效果、末尾才预约 1320。只有开战效果里预约公共事件时才分得出来，全库唯一的 1774 走不到。

## 待交叉核查

- 改了原沙僧核心文件：`battle_logic.gd`（`_skill_cost` 比例费用、`pay_skill_cost` 记 `_costmp`、`_apply` 补段；nanoha2 的 `_take_state_reserves`）、`core/state_effects.gd`（nanoha2 的 `reserve_common_event`）。另改 `smart_ai.gd`、`core/nanoha.gd`、转换器 `xiyou_export.py`。

## 验证

- 同步：工作树里一轮 `同步正式西游.py --accept-additions`（已合 main 后），测量只有新增 `events.json /cases[id=ce2481]`，产物指纹已留。
- `内容覆盖检查.py`：hard 0、new 0、resolved 0，基线不用更新。
- 选测：`选测.py main --list` 给出的 126 个场景全跑（`并行测试.py --jobs 2`，3807 秒，排共用槽），125 过；`xiyou_state_effects_tp` 的 `inventory.merged_318` 得 315——是 nanoha2 把 1774／1780 三块单句 `reserveCommonEvent` 从 js 翻成结构化 op 的预期变化，上一位漏改，本会话改成 315 并注明原因，单跑 `xiyou_state_effects_tp`、`xiyou_nanoha` 通过（537/537、223/223）。没有偶发。
- `xiyou_nanoha` 223/223；反向验证（手改后单跑、备份字节还原）：去掉补段 173/197、去掉比例收费 155/197、ACS 可见段数改 9600 196/197、去掉魔炮候选／段数乘法／付费后 MP 各 210/211。
- `语法检查.py`：495 个 .gd，0 问题。

## 本分支提交

- 8c1cdda6、f1df1d94（nanoha2，②）
- 4313494c 合 main
- 03d203f2 ① 大招自定义 MP 消耗与多段
- c9ffaa5c ③ 小魔炮 AI 与手动流程断言
