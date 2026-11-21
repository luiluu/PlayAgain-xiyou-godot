# 交付：luiluu/t332

- 车道／工作者：T332 天启篇敌人百分比掉血不吃难度倍率（cc，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·T332·未经审查】天启篇敌人百分比掉血不再吃仓库倍率，灼伤 V 回到每回合 −5%（dev.待定）

- 依据：Kyo 11-21 D249 乙（T327 查清：原版 `Star_Warehouse` 把难度倍率同时乘在敌人 xparam（含 hrg）与 sparam（含 rec），回合末再生 `floor(mhp × hrg × rec)` 在天启篇开局 DCultyL3（×2）下叠成 ×4，灼伤 V −5% 变 −20%）。
- 做法（r1 返修后）：`XEnemy.regen_rates(drop)`（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/enemy.gd`）给回合末 HP 再生用的 [hrg, rec, 是否拆算]。天启篇存档且再生特性（22-7）里有负值时，照 T285 `xparam_parts` 先例拆成正值 pos 与负值 neg：正再生照原版吃两次仓库倍率（pos×w²），负再生不吃（×1），rec 取不乘倍率的原值，即 `floor(mhp × (pos×w² ＋ neg − drop) × rec原值)`；没有负再生、西游档、开关关时逐字照原版 `[hrg − drop, rec]`。`BattleLogic._regenerate`（`modes/xiyou/battle/battle_logic.gd`）先算异化逆祷挡掉的负再生（drop）再交给它，导入角色 DoT 缩放分支在拆算时也从拆算值里扣（该分支现版本 outgoing_rate 恒 1、走不到）。
- r1 返修（小A 核 T332_核查报告_r1）：P1-1 原来按净 hrg<0 一刀切，10～33 层自带正再生的守层者挂灼伤 V 净值仍 ≥0 时照吃 ×4，跨 0 时正再生被砍成 ×1（11 层 +8% 挂中毒 −10%：+32% 断崖到 −2%）；改成正负拆开后连续（11 层挂中毒＝+22%，挂灼伤 V＝+27%）。P2-1 逆祷扣减挪到拆开之后，残留正再生照旧 ×w²。P2-2 专项补用例。
- 开关：`XTianqiCombat.DOT_NO_WAREHOUSE`（`modes/xiyou/core/tianqi_combat.gd`，默认 true；false＝天启篇也照原版 ×4）。随 `XTianqiCombat.ENABLED`、`XTianqi.active` 一起判，西游档不走这里。
- 影响面（只动负再生这一路）：
  - 变：天启篇敌人身上的负再生（灼伤、中毒等 47 个负再生状态）每回合 ÷4（DCL3），不论敌人自带正再生多少。10～33 层自带正再生的守层者（如 10 层 +5%、11 层 +8%）挂负再生时：正的照旧 ×4、负的 ×1 相加（10 层挂灼伤 V＝+15%，原来 0%）。逆祷挡掉的负再生照旧不算，残留正再生 ×4。
  - 不变：正再生（照旧 ×4；没有负再生时整条路径逐字照原版）、敌人 pdr／mdr、恢复效果对治疗与吸收的倍率、MP／TP 再生、面板与别处读的 `e.hrg`／`e.rec`（照旧 ×2）、我方角色、西游档、冠军之路（本来 ×1）。
- 测试：改专项 `xiyou_guardian_burn_regen`：天启篇艰险（寻常借难度 3）1 层守层者挂灼伤 V 一回合正好 −5%、`regen_rates` 返回原值、再 25 回合停在 1 血；开关关掉的天启篇与西游档 −20%；没挂灼伤时 `regen_rates` 照旧乘倍率。r1 另补 `_mixed`：10／11 层守层者挂灼伤 V、11 层挂中毒跨 0（天启篇＝pos×w²＋neg，且大于 ×1 算法）、西游档 11 层挂中毒照原版、逆祷 drop 挡掉全部负再生后只剩 pos×w²（单元层面给 drop；整场逆祷要装异化装备，没搭）。本机专项 xiyou_guardian_burn_regen 48/48。r0：xiyou_tianqi_enemy_cev 123/123、云端选测 472 个场景全过（540a96541）；r1 云端选测（addce27fc）469 个场景 468 过、xiyou_tianqi_pozhen_type 偶发；挂 1 个 xiyou_tianqi_xinmo_traits（`wire.t5_replay_cast` 0，单跑重跑也挂）。本机查证是原有偶发、跟本单无关：换回 main（9844a8074）的 enemy.gd／battle_logic.gd／tianqi_combat.gd 跑 16 次挂 2 次（同一条），r1 跑 12 次挂 3 次；挂的那几次没走到天启篇拆算分支（加临时打印确认，已删）。测试已 seed 固定仍不稳，非确定来源没查，建议另派（影劫第 3 回合重演）。
- 玩家可见：天启篇里给敌人挂的灼伤、中毒等百分比持续伤害，每回合掉血回到技能写的比例（之前在默认难度下是 4 倍）。

## 交接板

- 下一步：T327 交接里提的守层者血表（T239 三表）可以在本单合并后重量（DoT 已回到 5%）。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：xiyou_tianqi_xinmo_traits 的 `wire.t5_replay_cast` 原有偶发（本机约 1/8，云端本次连挂两次），固定种子仍不稳，建议派心魔线车道查非确定来源。
- 优化登记由总装按需补 O 号：恢复方法 `XTianqiCombat.DOT_NO_WAREHOUSE = false`，专项已把它设成 false 跑过回退支）

## 本分支提交

- 540a96541 T332 天启篇敌人负 HP 再生不吃仓库倍率＋专项改断言
- f510a47e1 交付单补选测结果、标可合并
- addce27fc r1 返修：再生拆正负、逆祷扣减挪后、专项补用例
- （本提交）交付单补 r1 云端选测与偶发查证
