# 交付：cc/review-17

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `2a5e2c51`（dev.250）切出，只加报告和本交付单。

## 变更记录草稿

## 2026-11-01 【cc·审查】核查 回退支期三与角色能力末尾夹值、伤害时挂状态一二期与称号一二期

- 核查覆盖：cc/nezha-parammax1（da122664）；收尾 48354a6b；cc/nezha-rollback3；cc/wukong-title2（bbeecb5b）；收尾 2a5e2c51；cc/wukong-pushstate1；cc/wukong-pushstate2；cc/wukong-title1
- 结论：一条 P2、三条 P3，其余通过。P2：`_push_states` 里「异化虚空的攻击伤害不挂」这条排除，原版实际上不生效。原版回调在 strict 模式下用 `isAttackDamage(this)`，`this` 是 undefined，正式引擎实测虚空＋1580 照样挂上 161；已报总装，派悟空保留排除、登记 O-待定、加回退开关、补探针。P3：夹值层在小猫剑圣包装里面，原版是在它外面（现在没有可见差异）；event_compare 基线的 match 计数没改；基线说明里「后面没有别的指令」不够准确。fb830b96 登记 m4e1p2／p3 的理由实测站得住（参照引擎里 ComLen 是 undefined，预约落空）。详见[报告](核查报告_20261101_审查第17期.md)。
- 验证：对着冻结 v0.28 读 diff；正式引擎两个临时脚本（虚空＋PushState、ComLen／预约）；没跑 Godot。

## 交接板

- 下一步：悟空 cc/wukong-battlelog1 先修本期 P2（虚空排除登记＋回退开关＋探针一例）。三条 P3 记进遗留：夹值层次序挪到 XCat 外面、event_compare 基线 match 改成 5750、基线说明改写。三条都可以顺手做。
- 用户试玩说明：无（只改文档）。
- 需要用户决定：无。O-待定由悟空登记，默认保留排除。

## 进度账

- 无变化。

## 优化登记草稿

优化登记草稿：无（P2 的 O-待定由悟空的修复批登记）

## 可优化（流程／工具／效率）

- 探针缺口：PushState 这条 P2 漏掉，是因为参照没有覆盖异化组合。以后给战斗机制写参照时，碰到原版回调里有 `this`／`arguments` 的地方，顺手加一例实测，不要只按读码写期望。

## 本分支提交

- 见 `git log 2a5e2c51..cc/review-17`。
