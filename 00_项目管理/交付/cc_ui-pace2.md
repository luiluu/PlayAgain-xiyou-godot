# 交付：cc/ui-pace2（战斗行动之间、回合交界的空帧）

- 车道／工作者：界面（cc）；总装派单：rules-pace1 的 PACE_DIFF，原版行动间空 1～2 帧、回合间 35 帧，重制 0
- 基于：main 48c9046f（rules-pace1 合并后）
- 状态：**可合并**

## 原版这些帧在等什么（`03_转换工具/ui_reference/battle_pace_ref.cjs` 新加逐帧 frames／calls，冻结正式源）

- **行动之间**：`endAction` 之后那一帧 `_phase` 是 `turn`，下一帧 `updateTurn` 才 `getNextSubject`→`processTurn`。敌人当帧 `startAction`；角色 OTB `startOTBInput` 先进 `input`，再下一帧才 `startAction`。所以原版 startAction 的间隔是「敌人 1、角色 2」。另外 startAction 之后，行动序列第一条（DISPLAY ACTION）角色隔 1 帧、敌人隔 2 帧才出。
- **回合交界**（a1 结束 422 → a10 开始 457，共 35 帧）：
  1. 423～439：YEP `endTurn` 开头 `if (isTurnBased && _spriteset.isPopupPlaying()) return`。a1 打出的伤害数字还在飘，每帧重试，等到数字走完（出数字后第 46 帧）。
  2. 440～446：MV `endTurn` 给每个战斗成员（我方 4＋敌群 3，含倒下的）`displayRegeneration` → push `popupDamage`，日志窗一帧执行一条，共 7 帧。
  3. 447：`updateTurnEnd` → `startInput` → OTB `startTurn` → `Window_BattleLog.startTurn` push `wait`：等 `messageSpeed` 16，SSEP 每帧减 2，448～455 共 8 帧。
  4. 456 `updateTurn` → `processTurn`（角色进 input），457 `startAction`。
- 都是原版流程本来的样子，不是 bug：复现，不登 O 号。

## 重制的改法（`battle/battle_scene.gd` `_main`，开关 `XBattleScene.PACE_GAPS`，默认开）

- 每次行动 `_play` 完多等 1 帧（原版 `turn` 那一帧）。
- 回合末先等场上伤害数字全部走完（含排队中的），再 `_play(logic.end_turn())`，之后按战斗成员数（我方＋敌群全员）逐帧等。
- 回合开始等 8＋3 帧：8 帧是日志窗 `startTurn` 的等待；1 帧是 `updateTurn`；再 2 帧是原版 `startAction` 到序列第一条之间的那段。重制 `act` 当帧就开序列，这 2 帧在重制里算在每次行动的尾巴上，所以行动之间两边总帧数本来就一样；回合交界的等待是从「伤害数字走完」算起，不经过上一次行动的尾巴，所以在这里补。
- 角色起点：试过在角色行动前多等 1 帧（照原版 input 那一帧），结果逐次间隔反而比原版多 1。原因是那一帧在重制里已经包含在角色行动尾巴里，所以没加。

## 报告项 → 测试 → 修法

- PACE_DIFF 行动之间 1～2 帧、回合之间 35 帧 → `tests/xiyou_battle_pace`：
  - 新的 `pace_cycles`：三回合 21 次行动，逐次比「行动序列第一条」之间的帧数。原版起点加上上面那段偏移（角色 +1、敌人 +2）后，全部相等：行动之间 56／47、回合交界 80。改之前敌人之间是 55，会挂。
  - `pace_gaps_off`：`PACE_GAPS = false` 时敌人之间回到 55（回退支）。
  - 原有的 `otb_speeds`、`action_order`、`action_frames_*` 照旧。专项拆出 `_battle(n)` 开场函数，跑两场。

## 共性夹具.md

- `03_转换工具/ui_reference/共性夹具.md` 加了一节「战斗夹具前提」：随机恒 0.5（掉落记录时 0.01）、夹具技能（6168／5980／5548，1～7、52 号另加 2571／2786）、难度 3、队伍、地图 5 (10,10)、敌群 2、变量清 0。另外写了量节奏时加血、变速 4、关技能动画，以及重制加血后要标脏。

## 验证

- 云端选测通过：提交 368597cfba，104 个场景，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42344561249 （`xiyou_yunshang_ui` 并行时偶发、单跑通过，和本单无关）。
- 本机直跑 `xiyou_battle_pace` 6/6；`语法检查.py` 通过。

## 优化登记草稿

无。

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】战斗行动之间、回合交界照原版留空帧（dev.待定）

- 原版每次行动结束后空 1 帧才取下一位；回合末先等伤害数字飘完，再按战斗成员数逐帧走回合末结算，回合开始日志窗再等 8 帧。重制原来都不等（rules-pace1 量到：行动之间原版多 1～2 帧，回合交界原版 35 帧、重制 0）。
- 照原版补上（`XBattleScene.PACE_GAPS`，复现原版，可回退）；`xiyou_battle_pace` 逐次比行动起点间隔，和原版相等。
- 共性夹具.md 写明原版战斗夹具的前提。

## 交接板

- 下一步：无。
- 用户试玩说明：战斗里一回合结束到下一回合开始，会比原来多停一下（96 帧/秒下约 0.3 秒），和原版一样。
- 需要用户决定：无。

## 待交叉核查

- cc/ui-pace2：战斗节奏空帧（甲档：战斗流程）

## 可优化（流程／工具／效率）

- 无。
