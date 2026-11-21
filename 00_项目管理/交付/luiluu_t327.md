# 交付：luiluu/t327

- 车道／工作者：T327 守层者自掉血排查（cc，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·T327·未经审查】查清 1 层守层者每回合自掉约 20% 最大生命的来源（dev.待定）

- 来源：不是 bug，是原版难度怪物属性叠出来的。安东尼「三魔术*火」（技能 4845）给守层者挂灼伤 V（State 21，HP 再生率 −5%）；天启篇开局借原版难度 3（`DCultyL3`，`Star_Warehouse` 参数 DCL3＝2），`XEnemy.xparam`（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/enemy.gd:290`，含 hrg）和 `XEnemy.sparam`（同文件 `:314`，含 rec）各乘一次 ×2；回合末再生 `floor(mhp × hrg × rec)`（`modes/xiyou/battle/battle_logic.gd:3603`）＝ −5% × 2 × 2 ＝ −20%。
- 原版出处：冻结正式源 `js/plugins/Star_Warehouse.js`「难度怪物属性改变」段，`Game_Enemy.prototype.xparam` 与 `Game_Enemy.prototype.sparam` 都乘 `DCultyL1～5`；`js/plugins/krz_state_re.js` `regenerateHp` 就是 `Math.floor(this.mhp * this.hrg * this.rec)`。重制照原版，玩家版同样（原版行为，不用进补丁）。西游档存档置 DCultyL4／L5（×2.5／×3）时更狠：灼伤 V 每回合 −31.25%／−45%。
- 不会自己掉死：`maxSlipDamage` 把持续伤害夹到 hp−1，5 回合到 1 血后任何一下都死，这就是 T239「普通阵容 8 回合赢」的来路。
- T286「1 层守层者 58.3 万血、10 级阵容 40 回合僵局」是同一件事的另一面：那局阵容 [18, 28, 42, 43, 178] 没有安东尼（19），没有百分比持续伤害，只能靠直伤磨 58.3 万（守层者最终 mhp，专项里实测 583000，已含仓库倍率）。两条不矛盾：守层者血表现在只有靠百分比 DoT 才打得动，有 DoT 时血表又形同虚设。
- 复现：新专项 `xiyou_guardian_burn_regen`（14 条）：天启篇寻常 1 层守层者、西游档 DCultyL3 各一组，断言仓库倍率 2、hrg −0.05→−0.1、rec 1→2、一回合掉 20%、再 5 回合停在 1 血。

## 交接板

- 需要用户决定：天启篇里敌人身上百分比持续伤害（负 HP 再生率，共 47 个状态，如中毒 −10%→−40%、内裤 −25%→一回合到 1 血）要不要偏离原版。选项：A 照原版不动（×4）；B 天启篇里负再生率不吃仓库倍率（hrg、rec 都不乘，灼伤 V 回到 5%，照 T285 去 ×2 的先例做成开关）；C 只去掉一层（10%）。cc 倾向 B，并且守层者血表（T239 三表）要在 B 定了以后重量，否则量出来的「8 回合」里混着 DoT。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：仓库倍率乘在全部 sparam 上，敌人的受物理／魔法伤害率（pdr／mdr）也 ×2、恢复效果 ×2、正再生 ×4（都是原版行为）。天启篇数值标定时建议一并列明这几项，免得以后再被当成 bug 查（归数值车道）。

## 本分支提交

- 95cf03bbc T327 复现专项 xiyou_guardian_burn_regen
