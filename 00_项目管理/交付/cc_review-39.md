# 交付：cc/review-39

- 车道／工作者：cc（审查）
- 状态：**可合并**（只加报告、交付单，无代码）

## 变更记录草稿

## 2026-11-04 【cc·审查】核查 审查第 39 期（甲 5 批、丙 2 批）

- 报告：`00_项目管理/核查报告_20261104_审查第39期.md`。无 P1／P2，P3 共 7 条：混乱＋自动战斗选防御的目标未量（rules7）、敌人战力无原版对照（ui5，开关默认关）、GM 加经验少一步 refresh_resources 与「解锁靠空文件」的设计面（testmode1）、开战清队列位置在移除 removeAtBattleEnd 状态之后（会清掉崩坏能 1307 的移除预约）、防连锁范围比描述宽、每回合反击计数在回合之外归到上一回合（fix2）。
- custom1b 的 `_v8_shuffle`：node v26.10（V8 14.6）对 n=2～12 各 20000 个种子逐例对照，结果与取随机数次数全一致；nwjs 154 的 V8 与之是否同一实现仍未实测。
- testmode1：无解锁文件时四处挂点与原行为逐字一致，仓库与导出过滤里无密钥或入口；未真导出验证包内容。
- 没跑 Godot、没复跑各批专项；云端选测结果按交付单自述。
- 核查覆盖：cc/wukong-custom1b 36444006、cc/bajie-rules7 3a9ef70b、cc/bailong-ui5 84d9ee18、cc/wukong-testmode1 b341ab14、cc/bajie-fix2 48c480ba；文档批 cc/wukong-gaps4 98aef2ff、cc/wukong-gaps5 12a6d5e7

## 交接板

- 下一步：总装把 P3-5、P3-6 派给规则车道；其余 P3 记着，不急。
- 需要用户决定：无（testmode1 的「解锁靠空文件」是否够用，Kyo 看一眼）。

## 可优化（流程／工具／效率）

- 无

## 验证

- 见报告开头：未跑 Godot；node 实测 V8 排序；读冻结源比对。

## 本分支提交

- 见 `git log main..cc/review-39`
