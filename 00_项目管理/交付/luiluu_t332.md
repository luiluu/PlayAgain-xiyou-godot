# 交付：luiluu/t332

- 车道／工作者：T332 天启篇敌人百分比掉血不吃难度倍率（cc，Opus＋medium）
- 状态：进行中

## 变更记录草稿

## 2026-11-21 【cc·T332·未经审查】天启篇敌人百分比掉血不再吃仓库倍率，灼伤 V 回到每回合 −5%（dev.待定）

- 依据：Kyo 11-21 D249 乙（T327 查清：原版 `Star_Warehouse` 把难度倍率同时乘在敌人 xparam（含 hrg）与 sparam（含 rec），回合末再生 `floor(mhp × hrg × rec)` 在天启篇开局 DCultyL3（×2）下叠成 ×4，灼伤 V −5% 变 −20%）。
- 做法：`XEnemy.regen_rates()`（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/enemy.gd`）给回合末 HP 再生用的 [hrg, rec]：天启篇存档且合计 hrg<0 时两处都取不乘仓库倍率的原值（`super.xparam(7)`、`super.sparam(2)`），否则照原版。`BattleLogic._regenerate`（`modes/xiyou/battle/battle_logic.gd`）对敌人改读它（含异化逆祷扣减、导入角色 DoT 缩放两条分支里的 rec）。
- 开关：`XTianqiCombat.DOT_NO_WAREHOUSE`（`modes/xiyou/core/tianqi_combat.gd`，默认 true；false＝天启篇也照原版 ×4）。随 `XTianqiCombat.ENABLED`、`XTianqi.active` 一起判，西游档不走这里。
- 影响面（只动负再生这一路）：
  - 变：天启篇敌人回合末 HP 再生合计为负时（灼伤、中毒等 47 个负再生状态），每回合掉血 ÷4（DCL3）。合计为负指 hrg 各项相加后 <0：敌人自带 +3% 再生又挂 −5% 灼伤时按 −2% 算、不再 ×4。
  - 不变：正再生（合计 ≥0，照旧 ×4）、敌人 pdr／mdr、恢复效果对治疗与吸收的倍率、MP／TP 再生、面板与别处读的 `e.hrg`／`e.rec`（照旧 ×2）、我方角色、西游档、冠军之路（本来 ×1）。
- 测试：改专项 `xiyou_guardian_burn_regen`：天启篇艰险（寻常借难度 3）1 层守层者挂灼伤 V 一回合正好 −5%、`regen_rates` 返回原值、再 25 回合停在 1 血；开关关掉的天启篇与西游档 −20%；没挂灼伤时 `regen_rates` 照旧乘倍率。
- 玩家可见：天启篇里给敌人挂的灼伤、中毒等百分比持续伤害，每回合掉血回到技能写的比例（之前在默认难度下是 4 倍）。

## 交接板

- 下一步：T327 交接里提的守层者血表（T239 三表）可以在本单合并后重量（DoT 已回到 5%）。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无（优化登记由总装按需补 O 号：恢复方法 `XTianqiCombat.DOT_NO_WAREHOUSE = false`，专项已把它设成 false 跑过回退支）

## 本分支提交

- 待写
