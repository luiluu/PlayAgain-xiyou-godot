# 交付：cc/plague-flaky

- 车道／工作者：修 xiyou_tianqi_plague 偶发失败／cc（技能重构）
- 状态：可合并（从 main c28739778 切出，只改测试）

## 变更记录草稿

## 2026-11-12 【cc·测试·未经审查】修 xiyou_tianqi_plague 偶发失败（dev.待定）

- 根因：阵容里的小痔（5 号）被动「痔疮」有 `<StartPushState0138: 20%>`，开局 20% 挂「痔疮犯了」（疾病类，算减益），开局随机数没固定。挂上时「开场病灶 0／12」(focus_text) 和「传染只传 1 个」(contagion_spread／contagion_turns) 会失败；本机连跑 6 次失败 2 次，和技能重构第三期无关（第三期的卡默认关，也不碰这条被动）。
- 修法：专项在 `_alien_logic`／`_kind_logic` 开战后去掉角色身上开战随机挂的减益（`_clear_start_debuffs`），只测瘟疫线自己挂的减益；focus_text 失败时多打各人状态号。游戏代码不动。
- 玩家可见：无。

## 交接板

- 下一步：无。
- 需要用户决定：无。

## 优化登记

- 无。

## 待办

- 无。

## 验证

- `xiyou_tianqi_plague` 本机连跑 12 次 12 次通过（改前 6 次挂 2 次）。

## 本分支提交

- （见分支）
