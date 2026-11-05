# 交付：cc/bailong-ui12

- 车道／工作者：B 界面／白龙（cc，ui12）
- 状态：验证中

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】选敌名字旁的状态图标与剩余回合；名字窗淡出照原版 ui12（dev.待定）

**名字旁的状态图标**（派单第 1 条，ui11「下一期」）：原版 `Olivia_WeaknessDisplay` 给每个敌人建一个 640×72、内边距 0 的名字窗，Weakness Show States 为 true 时窗里挂一个 `Sprite_StateIcon`，再叠 `YEP_BuffsStatesCore` 的回合数和 `CP_StateFloor` 的层数。重制原来只画名字。新文件 `battle/enemy_state_icon.gd`（`XEnemyStateIcon`），名字窗画布上照做：
- 位置：图标中心 x＝round(640／2)＋round((18 号名字宽＋32＋4)／2)、y＝16（读数：「嘤嘤怪Ａ宝宝」在 392,16）；不透明度跟名字。
- 轮换：SSEP 把 animationWait 改成 StateIcon÷BattleSpeed(Default)＝40÷2＝20 帧；每次换下一格（越界回 0），取 allIcons（活着时：带图标的状态，再接强弱化）；图标和数字只在换格时更新。
- 回合数：状态 autoRemovalTiming＞0 才画（中毒 timing 0 不画、睡眠画），ceil(剩余回合)、千分位；32×32 格内 (−3, −8) 宽 32 行高 36 右对齐，16 号、颜色 0；强弱化同位置，强化色 24（#80ff80）、弱化色 2。
- 弱点图标：Element Icons 全 0、未知图标 0，原版画的是第 0 格，画面上什么也没有；重制第 0 格本来不画，不另做。
- 回退开关 `XEnemyStateIcon.SHOW = false`（不画，回到原来的样子）。补缺失内容，按派单做成开关并登记 O-待定。
- 原版缺陷：`CP_StateFloor` 画层数字样（「%1层」，(2, 6)、12 号、#ffffa0）时把宽度写成 `Window_Base,_iconWidth`（逗号），宽度成了函数，canvas 一个字也不画（读数：drawText 调了 3 次、位图 0 个像素）——原版看不到隐月等叠层状态的层数。按「原版缺陷先改后登记」照参数画出来，`XEnemyStateIcon.FLOOR_TEXT = false` 回原版不画，O-待定。

**名字窗淡出**（派单第 2 条，战斗画面零星项里最确定的）：`Window_WeaknessDisplay.updateOpacity` 在选中或 Hide Duration（180 帧）内直接 255，过了以后每帧 −16 淡出；隐藏或死了也是 −16 淡出。重制原来到点直接消失、死了立刻没。名字和新加的状态图标共用这个不透明度。向原版对齐，回退开关 `XBattleScene.NAME_FADE = false`，不占 O 号。

**盘点**（派单第 2 条的其余）：照 SSEP 覆写清单再核了一遍（ui10 可优化里建议的）：StateIcon（本期做）、StateOverlay（ui11）、Weapon、motionSpeed、Balloon（ui10）、startMove、动画倍率、日志等待都已对上；`Sprite_Damage` 的 SSEP 时长（90÷2 夹到 60）被后面的弹数插件覆盖回 90（读数 `_duration` 90），重制 90 次没错。`battle_logic.gd` 头注释「胜利提示画面还没接」已过时（ui11 接了），改正。没再找到别的确定的画面缺口，所以只做了这两项。

## 优化登记草稿

| 编号 | 位置 | 原版 | 现在 | 理由 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定（选敌状态图标） | 选敌名字旁状态图标（`battle/enemy_state_icon.gd`） | 有（WeaknessDisplay＋BuffsStatesCore） | 重制原来没有，照原版补上 | 缺失内容 | `XEnemyStateIcon.SHOW = false` | cc（白龙） | 待用户决定 |
| O-待定（敌人状态层数） | 同上 `floor_text` | CP_StateFloor 宽度笔误，层数字样不显示 | 照参数画「N层」 | 原版缺陷 | `XEnemyStateIcon.FLOOR_TEXT = false` | cc（白龙） | 待用户决定 |

## 交接板

- 下一步：无新增（胜利结算背景仍等 Kyo 定）。
- 用户试玩说明：选敌人或打到敌人时，名字右边会轮流显示它身上的状态和强弱化图标，图标右上角是剩余回合数（和正式版一样，中毒这类不按回合消失的不显示数字）；隐月这类叠层状态还会在图标下面写「N层」（正式版因为代码笔误看不到，这里改成能看到）；敌人名字不再一下子消失，而是慢慢淡出。
- 需要用户决定：两个 O-待定（见上表）。

## 进度账

- 战斗规则与画面：补上「选敌状态图标与回合数」「名字窗淡出」两项画面零星项。

## 可优化（流程／工具／效率）

- 无新增。

## 验证

（跑完填）

## 本分支提交

（跑完填）
