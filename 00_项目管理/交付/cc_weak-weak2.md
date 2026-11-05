# 交付：cc/weak-weak2

- 车道／工作者：C 规则·机制／weak2（cc，派单第四批 AH）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·weak2·未经审查】弱者挑战二期：说明卡「品质：神话」、一期边角例与开关关时零影响（dev.待定）

- **说明卡（盘点 15）**：原版 getItemExtraDescParams2 包装把技能 10357（备注 `<CodexWeakNewGame>`）的「品质：」行写成「品质：神话」。探针实测冻结 v0.28 里 10357 品质 14 按七档本来就叫神话，10356 对照也是，所以玩家看到的不变；重制照原版补上包装（`XWeakChallenge.quality_label`，挂在 `help_card.gd` 品质行处），防品质表以后改名。参照 help.10357／10356 开关两支逐行（文字、字号、颜色、对齐）对上。
- **一期边角例**（探针 weak_challenge 20 → 29 例）：开战前补学（本局标记开、技能被忘掉的弱者在 BattleManager.setup 时补学，不回满）、最终战里强者换进出战栏又换回（作废）、中途改难度 9→8→9（作废）、本局已有成就 142 时胜利（照发标记与技能，不重记全局成就）、战败（不给）。
- **开关关时零影响**：`XWeakChallenge.ENABLED = false` 时，全局标记开着的新局与伤害逐项等于参照「关」支；试学 10357 不拦（同移植前）；带本局标记的存档读进来不补学、已学的不忘、承伤率与终伤不变；最终战胜利不写标记、不判定；说明卡原样。
- **插件备注覆盖**：`<CodexWeakNewGame>` 变成「已读」，`测试插件备注覆盖.py` 的 `test_known_unread` 原例没了；真实数据里已没有「没读」的标签，改成守住「已读，且不再冒出新的没读」。
- 专项 `xiyou_weak_challenge` 125 项全过。

## 优化登记草稿

- 无新增：说明卡包装和边角例都在 O-186 的 `XWeakChallenge.ENABLED` 之下。

## 交接板

- 下一步：弱者挑战盘点 17 项已全部处理完（做完 12 项，3 项早已有，2 项不移植），这条线可以收了。
- 用户试玩说明：玩家看不出变化（说明卡本来就写神话）。
- 需要用户决定：无（O-186 仍待 Kyo 确认）。

## 进度账

- 规则／机制：弱者挑战 100%（盘点表全部处理完）。

## 可优化（流程／工具／效率）

- 无

## 待交叉核查

- 乙档：`weak_challenge.gd`（quality_label）、`help_card.gd` 一行、`tests/xiyou_weak_challenge.gd`、探针 `weak_challenge_probe.cjs` 新 9 例、`07_开发环境/测试插件备注覆盖.py` `test_known_unread` 改口径。
- 反向验证：说明卡不改、改难度不重判、重排不重判、开局不看开关、enabled 不看开关、开关关时也拦学、开战不同步，7 处都咬住。

## 验证

- 专项：`xiyou_weak_challenge` 125/125。
- 选测：`选测.py main --list` 列的 12 个全跑全过（xiyou_actor_book、xiyou_battle_ui、xiyou_black_flash_ui、xiyou_book_capacity_ui、xiyou_character_help_cost、xiyou_demon_crown、xiyou_event_compare、xiyou_growth_help、xiyou_guyu_ui、xiyou_help_card、xiyou_weak_challenge、xiyou_yunshang_shop）。
- 合 main（含 weak1b、ui11）后补齐、`同步正式西游.py --accept-additions` 测量不变（留了指纹）；`语法检查.py`、`工具回归.py` 全过。

## 本分支提交

- 从 cc/weak-weak1 切出；合了两次 main（第二次优化登记.md 取 main 的，weak_challenge.gd 注释改成 O-186）
- WIP：说明卡品质神话、边角例、开关关时零影响断言
- 最后一笔：交付单可合并
