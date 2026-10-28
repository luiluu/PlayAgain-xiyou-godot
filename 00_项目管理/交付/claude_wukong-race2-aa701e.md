# 交付：claude/wukong-race2-aa701e

- 车道／工作者：C 规则·机制／悟空_63（Claude）
- 状态：进行中

## 期一逐项：原版依据与重制落点

原版文件 `app.nw/js/codex/runtime/installNativeRaceRuntime.js`（下称 R）、`installCombatPowerRuntime.js`（下称 P），冻结 v0.28。

| 项 | 原版依据 | 重制落点 | 结论 |
| --- | --- | --- | --- |
| 1 战力预览种族修正 | R:262–279（resetPowerCycle／startPowerTurn／powerBlood／powerCost／powerAdjust／commitPowerRoot），P:254（expected 末尾 powerAdjust）、P:280／283／295／296／306（循环里重置、费用、每回合、人族行动数、提交）、P:374（神族治疗 ×(1+q)）、P:386（蛮族「蛮骨与反攻」未计入）；钩子 R:150–152 的 power 分支（神族首魔看 godUsed、魔族血契看 powerBlood） | `power.gd`（_cycle／_expected／evaluate）＋ `race_battle.gd`（power_* 函数，capture 认 racePower／raceSuppress 选项） | 做 |
| 4 R.status 文字 | R:280 定义 | — | **死代码**：冻结源里没有任何调用（全目录 grep `CodexRaces.status`／`R.status` 只有定义一处），不做 |
| 5 敌人窗毒鸡汤信息 | R:214 poisonInfo、R:215 Window_BattleEnemy.updateHelp 包装 | `race_battle.gd` poison_info ＋ 战斗画面选敌帮助（文件见下） | 做 |
| 6 种族补给 bossReward | R:226–235（setup 记层、endBattle 记胜负、claimSupply、bossReward 包装） | 已在 `dungeon.gd` race_supply（dev.1xx XDungeon 一起接的），但没有参照 | 补参照与测试 |
| 7 learnSkill 改种族 | R:82 | `race.gd` learn ＋ `actor.gd` learn_skill 一行转交 | 做（原版唯一入口 Map137 兑换大厅「修复种族技能」不在切片，但技能共享等走 learnSkill 的路径要一致） |
| 9 人族 996 提示 | R:217 tell(名字+'九九六：额外行动') | 重制 `insert_human` 已写提示，但 `battle_logic.gd:1003` 调用时没传 logs，提示被丢；改成暂存，下一个行动根开始（begin）时吐出 | 做，不改 battle_logic.gd |

## 变更记录草稿

（待写）

## 交接板

- 下一步：（待写）

## 进度账

- （待写）

## 可优化（流程／工具／效率）

- （待写）

## 本分支提交

- （待写）
