# 交付：luiluu/cc-t134-hangup-tp

- 车道／工作者：T134 挂机按实际消耗判 TP／MP（cc，Opus＋medium）；同一工作树随后接 T135（另一节写）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T134·未经审查】挂机顺序表按实际消耗判 TP／MP：书把消耗降到 0 也能放（dev.待定）

- 依据：玩家反馈（Kyo 11-17 转，私密仓 `协作交接/附图/玩家反馈_1117/`）：米拉吃了书（洗髓经，技能消耗 −100%）后解放·黑龙手动开局就能放，挂机排了解放却一直普攻，有人回 TP 才变身。
- 根因：`XHangUpAuto.scheduled_skill` 照搬原版 `XdRs_HangUp.js` 的 `Game_Actor.makeAction`（冻结正式源 v0.62.12 第 1735 行）：拿 `$dataSkills[id].mpCost／tpCost`（技能表原始值，解放 80 TP）比当前 MP／TP，不看书、装备、状态、禁忌等减耗。原版 bug，重制照搬了。智能 AI 选技、手动出招都走 `can_use`（含 `skill_cost` 实际消耗），只有挂机顺序表这一处用原始值。原版自己的异化饕餮包装（Adv:138-142）也是同样的问题、改走 canUse，重制 `_auto_battle_action` 已照它做。
- 修法：`XHangUpAuto.REAL_COST`（O-待定-1，默认开）：顺序表技能只看 `can_use`（已含实际 MP／TP、HP、物品等费用判定），去掉原始值比较；MP 同一条。关掉＝原版。
- 专项 `xiyou_mira_battle` 加 `hangup_free.*` 4 项：带洗髓经、TP 0、表排解放 → 挂机放 10146；`REAL_COST = false` 退成普攻（修前行为）；不带书 TP 0 两种都不放。反向验证：把判定换回原始值，`hangup_free.book_real_liberates` 挂（得 1＝普攻）。
- 玩家可见：挂机技能顺序表里的技能按实际消耗判断够不够，被书、装备等减到 0 消耗的技能开局就会放，不再改放普通攻击。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/hang_up_auto.gd` `XHangUpAuto.scheduled_skill` | XdRs_HangUp makeAction 拿技能表原始 mpCost／tpCost 比当前值，减耗到 0 仍判不够、改普攻 | 按实际消耗（同手动出招 canUse） | 玩家反馈 T134：吃书后挂机放不出解放·黑龙 | `XHangUpAuto.REAL_COST = false` | cc | 保留 |

## 交接板

- 下一步：无（T134 修复要摘进补丁线 cc/v00300，见下）
- 用户试玩说明：米拉学洗髓经后，挂机顺序表第 1 回合排解放·黑龙，开局 TP 不满也会直接变身。
- 需要用户决定：无

## 进度账

- 无（bug 修复）

## 补丁线（cc/v00300）要摘的提交

- `ae7ab815e`：只改 `hang_up_auto.gd`、`tests/xiyou_mira_battle.gd`（西游档文件，不依赖天启篇改动）。已在临时克隆里对 `cc/v00300`（3b661b8ef）`cherry-pick` 过，无冲突；补丁线上没跑专项（克隆没有转换产物），摘进去后请跑 `xiyou_mira_battle xiyou_hangup_auto`。

## 我不同意的地方

- 无。派单写的「改成和手动出招同一套判定」就是对的口径；补一句：智能 AI 选技本来就走实际消耗，没问题的不用动，所以只改了顺序表这一处。

## 验证

- `并行测试.py … xiyou_mira_battle xiyou_hangup_auto`：292/292、239/239。
- `检查.sh --affected main --oracle`：退出 0，选中 14 个场景全过（含 event_compare 四份、floor_run 三份、hangup_auto、mira_battle、nanoha），MV 参照引擎启动正常。
- `工具回归.py`：全部通过（91 秒）。
- `交付自检.py`：退出 0（交付单提交后跑）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ae7ab815e T134 挂机顺序表按实际消耗判 TP／MP（书减耗到 0 也能放）
