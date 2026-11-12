# 交付：cc/tianqi-seal-hooks

- 车道／工作者：天启篇奖励·净印挂钩补两处／cc（总装三十九顺手做，奖励车道交付单「未做」第 1 条）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·总装·未经审查】天启篇净印接进死亡线、瘟疫线异化怪（dev.待定）

- 奖励分支（dev.483）合并时死亡线、瘟疫线异化怪已在 main，交付单「未做」1 的两处挂钩在这里补：
  - `XTianqiDeathAlien.start_turn`：宣判者挂死期前先过 `XTianqiRewards.doom_spared(logic, t, false)`，挡下就只扣一半生命、不挂死期，日志写「死期落在…身上，被净印挡下，只损失了一半生命」（和骑士本体战同一句）。
  - `XTianqiPlagueAlien.frail_rate`：病弱每个减益的比例过 `XTianqiRewards.frail_per(a, per)`（清心三档 3% → 1%）；病灶说明文字仍写基础值。
- 开关沿用 `XTianqiRewards.ENABLED`，不新加。
- 专项：`xiyou_tianqi_death` 加 `seal_doom_hooked`（全员穿三档长明，30 次宣判里有挡下也有挂上，合计 30）；`xiyou_tianqi_plague` 加 `seal_frail_hooked`（3% → 1%）。两条都反向验证过（去掉挂钩各自挂）。
- 玩家可见：天启篇死亡线、瘟疫线穿对应净印后，异化怪的死期、病弱也会被减轻（原来只对骑士本体生效）。

## 验证

- `语法检查.py` 通过；`xiyou_tianqi_death`（95）、`xiyou_tianqi_plague`（100）、`xiyou_tianqi_rewards`（78）通过。

## 交接板

- 下一步：无。
- 用户试玩说明：无单独项（随奖励一起试）。
- 需要用户决定：无。

## 优化登记

- 无（沿用奖励的开关）。

## 进度账

- 无（天启篇不计重制完成度）。
