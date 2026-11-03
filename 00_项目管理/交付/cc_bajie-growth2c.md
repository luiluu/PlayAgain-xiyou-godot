# 交付：cc/bajie-growth2c

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：未完成（额度用完，WIP）

## 已做

- `mv_oracle/demon_crown_probe.cjs`：魔冠 7940 参照探针（公式、得到、战斗成长、死亡减半、换装、掉落、读档防回滚、失去、旧档收编），**还没跑过**（本机没有 `timeout`，直接 `node demon_crown_probe.cjs`）。

## 接续（下一位从这里接）

1. 跑探针、修到无错，产物 `.sandbox/demon_crown.json` 拷成 `tests/fixtures/demon_crown_oracle.json`。
2. 新文件 `core/demon_crown.gd`（XDemonCrown），账本照 `core/yunshang_orders.gd` 的写法：独立文件 `crown_progress_v1.json`（{version 1, profiles{id:{revision, items{uid:{spec,bonus,removed}}, battles, worldDeaths}}, legacy}），存档 flags 记 `_codexCrownProfile`／`_codexCrownEncounterSeq`／`_codexCrownWorldDeathSeq`；新局不平白写盘（第一次用到才建）。
3. 接线（原版 main.js 第 151 行装载，晚于心钢 111，是外层）：`battle_logic.start_battle` 最前 begin（开战掷点，用规则流，可注入）；`end_battle` 最末（在 `XGrowthForge.award_core`、`XHubris.clear_reward` 之后）finish；`battler.add_state` 死亡（addNewState：之前没死、之后死了）→ 减半；`XEquipment.change` 战斗中换掉就作废；`xstate.gain_gear` 得到 7940 走账本发；`lose_gear(record)` 带 uid 记移除；`xsave.load_slot`（旧档身份＋adopt＋replay）、`xsave.save`（adopt＋replay）。
4. describe：名字／说明／图标 290000（Codex_DemonCrown 图没转，先记待办）、品质 max(12, 14/15)、成长行 `成长：八项全属性＋N%`、八项 code21 特性 ×(1+b/100)（账本不可用时 1，提示一次）。
5. 掉落：Map162、敌群 539～542、`XYunshangOrders.immortal_clear`，roll<0.03。
6. 尾项（心钢／狂妄动态说明、Shift 看原件、智能 AI 7900、战力、甚尔抑制、toaster）仍按 growth2b 交付单「接续」。
