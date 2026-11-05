# cc/wukong-barrier1 交付单（悟空）

**结论：不做屏障，无代码改动。可合并（仅本文件）。**

## 为什么不做
- gaps6 交付单把「月之庇佑」列为"真缺·中"，但没查到 dot2 ②（提交 3db71fc7，11-04）已经用 `mv_oracle/barrier_probe.cjs` 量过原版：
  - 全库只有技能 10032 带屏障标签，物品、角色、职业、敌人、武器、防具、状态都没有。
  - 10032 是 `occasion 3`（永不可用）、`scope 0`、无 effects：学会后 canUse／usableSkills 都是假，战斗开始、再生、回合结束屏障点数一直是 0。
  - 插件参数：屏障状态 0、每战清除 true，所以原版里屏障根本不会出现在玩家面前。
- 冻结源我也复读了一遍（YEP_AbsorptionBarrier＋_Optimize）：屏障只在 `applyItemUserEffect` 里加，而该技能永远走不到；重制照原版不做是对的。
- 守卫专项 `xiyou_barrier` 已在库（数据出现第二个屏障标签、10032 变可用、原版参照不成立就失败）。本分支重跑：通过（14 秒）。

## 若以后要做（记录，不在本期）
触发条件：守卫专项报失败（10032 改成可用，或别处出现屏障标签）。原版行为要点（读源码所得，未实测）：
- 存储：永久 `_permBarrier` ＋ 回合数组 `_turnBarrier[]`；`<Custom User Barrier>` 进永久，`value = user.hp`，floor。
- 受击 `executeHpDamage` 里先 `loseBarrier`：先扣回合数最低的、再永久；剩余才扣 HP；穿透 = 1-(1-技能率)(1-角色率)…，平扣在后，夹到当前屏障；0 伤害是否弹字由参数 Display0（本游戏 true）。
- 再生阶段 `updateBarrierTurns` shift 回合数组，再按 Barrier Regen 加；战斗开始／结束、死亡清空。
- `_Optimize` 只改弹字与刷新，数值同原版。

## 验证
- `并行测试.py … xiyou_barrier`：1 场景全部通过。无代码改动，不需其它选测。

## 变更记录草稿
无（仅更正 gaps6 的"真缺"判断：屏障不可达，已由 dot2 ② 守卫）。

## 优化登记草稿 / 待交叉核查
无。
