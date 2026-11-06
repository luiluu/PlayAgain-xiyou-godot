# 交付：cc/bajie-events13

- 车道／工作者：tests／预设／八戒（cc，派单 CE）
- 状态：可合并（t1 一轮）。已合 main 12ba39f3，无冲突。

## 变更记录草稿

## 2026-11-06 【cc·八戒·未经审查】敌群战斗事件页覆盖：加覆盖钩子与簇报告，t1 补 100 个「第 3 回合随机强制」变体，有对照的指令 1274→2000（dev.待定）

- **钩子（默认关，不改游戏行为）**：Godot `XBattleEventRunner.COVER`（静态，null＝关）设成字典后每条指令记「tTpP:下标」（敌群页根游标）或「ceN:下标」（公共事件）；
  `tests/xiyou_troop_events.gd --coverage=<文件>` 打开它并按参照用例序号写 byCase。原版 `troop_event_probe.cjs` 在 `XIYOU_COVER=1` 时包一层
  `Game_Interpreter.executeCommand`，按 `_list` 对象认页，另写 `.sandbox/troop_events_cover.json`；不设时 troop_events.json 逐字节不变（已比 SHA）。
- **报告**：新工具 `03_转换工具/敌群页覆盖.py`（只读，借用 事件写法覆盖.py 的写法键与门）：没执行到的指令按「敌群没进探针／页条件／页内分支门」聚簇，
  出门型汇总、簇表和「原版走到、Godot 没走到」差异候选。338 个敌群里有内容的页 511 页（接续单说的 2336 页多是空页）。
- **结果**：改前两边都执行到 1274 条、没执行到 1504 条，最大簇是守层者／首领第 1 页「回合 3+3·X」随机强制（1196 实例）。t1：这 100 个敌群各加一例
  回合计数预置 2、跑开战检查和第 3 回合（variant `t1`，Godot `_turn_page_case` 只比两段的对话与强制行动［行动者, 技能］，事件随机同参照取 0.5）。
  改后执行到 2000、没执行到 778；原版与 Godot 执行到的集合完全相同（差异候选 0）；新增 600 项断言全过。

## 优化登记草稿

- 无

## 交接板

- 下一步（敌群页 t2 可选）：剩下的门型——页内 111 变量 308（第 3 回合页里按随机变量 844 选的其余分支：要加「事件随机取值」旋钮，两边同改）、
  页条件·回合 184（798～814 的第 2 页同为回合 3+3·X 但排在第 1 页后面、824／825 回合 30 等）、页条件·敌人 HP 172（17 个敌群的 HP≤20% 页；
  现成的 hpRate 例在 Godot 侧走 `_transform_case`，它按变身页写的断言不通用，要另写一个只比对话／强制的分支）、敌群 1 与 826 不在探针里（44）。
- 注意：troop_event_probe 变 475 例，单跑约 8 分钟（原约 5.5 分钟）；xiyou_troop_events 四份各多 25 例，每例只跑一次。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 敌群战斗事件页：有对照的指令 2000／2778（无条件页 5 条不计），完成度由总装定。

## 发现的不一致（只记，没改游戏代码）

- t1 新例无不一致。
- 合 main 前本地跑 `xiyou_troop_events_c` 时 troop321（六耳猕猴「模仿」856 后的强制 1）有 10 项 FAIL，COVER 关着也一样，属当时分支底子的问题；
  合 main（12ba39f3）后云端同场景通过，已不复现。

## 验证

- 原版：`XIYOU_COVER=1` 跑 troop_event_probe，旧 375 例与 generated 逐字节相同（SHA 724cf0d6），新 100 例无报错；不设变量时不写覆盖文件。
- Godot：四份 `xiyou_troop_events*` 带 `--coverage` 本地全量（合 main 前），新增 600 项全过；覆盖报告原版／Godot 执行集合一致。
- 合 main（12ba39f3）后：`同步正式西游.py --accept-additions` 退出 0（只新增 troop_events 100 例）；`工具回归.py` 全过（73 秒）；
  `选测.py main --list` 79 个场景 → 云端选测全过（提交 7e958e9a，8 片，含 xiyou_event_compare、xiyou_troop_events 四份与 _half、rules 各片）。

## 待交叉核查

- `battle_event_runner.gd` 新加的 `_execute` 覆写：COVER 为 null 时直接 `super._execute`，确认没有别处依赖子类不覆写 `_execute`。
- 原版侧按 `_list` 对象认页：插件若复制页列表会漏记（本轮原版与 Godot 集合完全一致，暂未见）。

## 本分支提交

- 覆盖钩子（Godot／原版）、敌群页覆盖.py、t1 变体（探针＋测试）、交付单
