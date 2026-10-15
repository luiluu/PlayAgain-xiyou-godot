# 交付：claude/bajie-flow-test-3b9e3c（第四轮：出售报酬）

- 车道／工作者：B 界面·规则／八戒（Claude，重制_八戒_3）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-flow-test-3b9e3c`
- 状态：进行中
- 任务：出售报酬——补商店出售漏掉的 YEP_X_MoreCurrencies 卖出报酬（普通出售与一键出售；悟空审查 dev.039 发现；唐僧 2026-10-15 09:09 派）。严格级：mv_oracle 参照探针逐项比对。

## 出售报酬（进行中）

（进行中）

## 审查草稿（暂缓，用户 2026-10-15 09:09：审查先暂缓、先继续做）

范围：内容与战斗，dev.032～dev.038（e2b1145..7167b48，modes/ 21 个文件 +979/−142，另有测试、探针与转换器）。

### 已审（第一段，05:00 额度重置前）

- ① 对照正式版（读正式插件代码核对）：
  - 敌人等级 `XEnemy.setup_level`（dev.035）：与 YEP_EnemyLevels 一致——Default Type 5＝出战成员最高等级，clamp(最小 1, 最大 999999)，浮动 floor(随机×(2+2+1) + 等级−2)，再 clamp(1, Maximum Cap 999999)。原版 negativeLevelFluctuation 误读了 Positive 参数（两者都是 2，无差别）。测试在 xiyou_rules / xiyou_drop_record。**通过**。
  - 敌群事件条件 `XBattleLogic._page_meets`（dev.034）：与 MV Game_Troop.meetsConditions 逐项一致（无条件页不执行；回合 b=0 / b>0 的取模式；敌人 HP 用 members()[index]；角色 HP；开关；turnEnding）。**通过**。
  - 轮回困难 Establish `_establish`（dev.034/036）：附加伤害在普通伤害之后、使用效果之前，逐个正能力值扣血、可致死（阵亡在 execute 末尾统一判定）；弹字按 O-026。**通过**。
- ③ 测试：敌人等级、敌群事件强制行动（xiyou_troop_events）、Establish、角色外观（xiyou_appearance）、事件对照（xiyou_event_compare＋baseline）都有专项。
- `检查.sh --oracle`（合并 main 885f100 后）：只有 xiyou_event_compare 失败（oracle_cases_complete 295≠266），原因是本 worktree 的 generated/oracle 是 00:54 的旧副本（`新建工作树.sh --补齐` 不覆盖已有文件）；从主工作区同步 03:01 的参照后，xiyou_event_compare 5/5、xiyou_troop_events 258/258、xiyou_rules 17900/17900 全部通过，其余测试第一次就全部通过。**不是代码问题。**
- 工具问题（给唐僧）：车道合并 main 后，`--补齐` 不刷新已存在的 generated/oracle 与转换产物，worktree 检查会拿旧参照对新切片而误报（上一轮也因此只测到五层）。建议 `--补齐` 按时间戳更新 oracle（rsync --update）并重跑转换器，或检查.sh 发现参照比切片旧时提示。

### 观察（不在本次修复范围，留给后续）

- 强制行动 339 对「全体敌人」按 enemies 列表逐个执行；MV iterateBattler 用 $gameTroop.members()，含未出现（隐藏）的敌人，只跳过阵亡。目前切片里的敌群事件没有隐藏敌人，暂无影响；接隐藏敌人的敌群时要核对。
- 普通伤害致死后，同一次行动的使用效果（加状态等）仍在 execute 末尾判阵亡前执行；MV 在扣血时就立即阵亡（死亡状态先加上）。此逻辑早于 dev.032，不在本次范围，记一笔供沙僧核对。

### 未审（重置后继续）

- ① 事件对照：xiyou_event_compare 报告逐项看一遍（七层后基线）、抽查 mv_interpreter／mv_script 新增指令与 JS 片段翻译。
- ② 读代码：mv_interpreter.gd（+151）、mv_script.gd（+82）、appearance.gd（新 258）、battler_sprite.gd（+178）。
- ⑤ 完成度：留给沙僧。

## 本分支提交

- 第三轮开工交付单、本 WIP 提交（审查第一段）
