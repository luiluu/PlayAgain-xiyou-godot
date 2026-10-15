# 交付：claude/bajie-flow-test-3b9e3c（第四轮：出售报酬）

- 车道／工作者：B 界面·规则／八戒（Claude，重制_八戒_3 → 重制_八戒_4）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-flow-test-3b9e3c`
- 状态：可合并
- 任务：出售报酬——补商店出售漏掉的 YEP_X_MoreCurrencies 卖出报酬（普通出售与一键出售；悟空审查 dev.039 发现；唐僧 2026-10-15 09:09 派）。严格级：mv_oracle 参照探针逐项比对。

## 出售报酬

### 独占文件

- 改 `01_Godot工程/modes/xiyou/core/item_marks.gd`（新增卖出报酬解析 sell_rewards、can_sell、统一出售 sell）、`ui/shop.gd`（普通出售改走 XItemMarks.sell、0 价有报酬可卖）
- 改 `01_Godot工程/modes/xiyou/core/hang_up_auto.gd` 一处：after_battle_sell 改调 XItemMarks.sell（正式版挂机自动卖出 XdRsData.hangUp.doSell 同样给报酬；不在原派单范围，改动 1 行，xiyou_hangup_auto 226/226 通过）
- 新增探针 `03_转换工具/mv_oracle/sell_reward_probe.cjs`，加进 `03_转换工具/同步正式西游.py` 的 PROBES（输出 sell_rewards.json）
- 测试 `01_Godot工程/tests/xiyou_item_marks.gd` 扩充
- **转换器没改**：generated/db 已带 note 字段。

### 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】出售报酬：YEP_X_MoreCurrencies 卖出的变量与物品报酬（dev.待定）

- 悟空审查 dev.039 发现：Godot 卖东西只给金币。正式版 YEP_X_MoreCurrencies 的 doSellGold 按物品备注另加报酬，挂机自动卖出 XdRsData.hangUp.doSell 也照抄了同一段。现在商店普通出售、一键出售、挂机自动卖出都走 XItemMarks.sell：金币 sellingPrice×数量，再按基础记录备注 <Variable x Sell Price: y> 加变量、<Item x Sell Price: y> 给物品（各 ×数量），然后失去物品。
- 正式数据里的报酬：变量 199／200／201／206／212／213，物品 188、180、236、457、2530、2898、678～707 等；没有 <Weapon/Armor x Sell Price>（插件对独立装备目标也会跳过）、没有按名字的写法、没有 <Price>／<Sell Price>／<Can Sell>／<Cannot Sell>。
- 出售列表能否选照 YEP_ShopMenuCore：有价格，或有卖出报酬备注（MoreCurrencies 设 canSell）。原来 0 价的报酬装备（如武器 73「麒麟对剑」给变量 201）在 Godot 灰显不能卖，现在可以卖。
- 备注解析照插件逐行的判断顺序（一行只认第一种写法，同一 ID 只取第一行）。
- 严格级参照：新探针 sell_reward_probe.cjs 自动挑每张表各种备注的第一件、多备注的、无备注有价的、无备注 0 价的，经正式 Scene_Shop.doSell 与 XdRsData.hangUp.doSell 各卖一次，记能否卖、金币、变量、物品、装备件数变化（28 例，两条路径结果相同）；xiyou_item_marks 逐例比对全部一致。
- 验证：合并 main（9984feb）后 `检查.sh --oracle` 全部通过（37 个 Godot 测试，含 xiyou_item_marks 82/82、xiyou_hangup_auto 226/226、xiyou_flow 48/48、xiyou_gear_ui 44/44、xiyou_rules 17900/17900、xiyou_event_compare 5/5、xiyou_floor_run 1～7 层；参照守卫、MV 参照引擎、同源核对通过）。worktree 的 generated/oracle 与主工作区逐文件相同，另加本分支探针生成的 sell_rewards.json。
- 未完成／已知问题：商店数量窗没画报酬那几行（MoreCurrencies 的 Window_ShopNumber 会列出卖出得到的变量/物品）；界面项，另做。
```

### 停在哪里

- 09:30 收尾时只差全量检查；重制_八戒_4 合并 main（9984feb）、`--补齐`、核对 oracle 与主工作区一致后跑 `检查.sh --oracle`，全部通过。可合并。
- 小注（给唐僧）：`新建工作树.sh` 是 zsh 脚本，用 `bash` 调用会在第 9 行报 `A: unbound variable`；直接运行或用 `zsh`。

### 合并时要做

- 主工作区跑一次 `python3 03_再刷重制_Godot/03_转换工具/同步正式西游.py`，生成 `generated/oracle/sell_rewards.json`（不入 Git）；没有它 xiyou_item_marks 的 sell_oracle_loaded 会失败。

### 交接板

- 下一步：无新增；第 6 项「逐页复现原版界面」可补「商店数量窗的卖出报酬行（YEP_X_MoreCurrencies Window_ShopNumber）」。
- 用户试玩说明：卖装备/物品时，正式版会给的不朽灵魂、不朽碎片、法宝积分等变量与兑换物品现在也会给；0 价但有报酬的装备可以卖。

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

- 7a061d8 WIP 审查第一段（暂缓）
- 第四轮开工交付单；afdb882 探针；1e7b5d0 出售报酬；48dec51 装备判断修正；e22c432 合并 main；7ba5193 WIP 交付单；9984feb 合并 main；（本提交）交付单可合并
