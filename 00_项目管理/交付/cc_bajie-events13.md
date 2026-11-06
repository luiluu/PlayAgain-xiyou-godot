# 交付：cc/bajie-events13（接续单，未交付）

- 车道／工作者：tests／预设／八戒（cc，派单 CE）
- 状态：**未开始实做，只做了摸底，上下文到线，写接续**。分支已从 main 切出并 merge 了 cc/bajie-events12（无冲突），工作树干净。

## 摸底结论（新会话照此接着做）

- 敌群战斗事件页的现有参照是 `03_转换工具/mv_oracle/troop_event_probe.cjs`（真实 BattleManager 跑两回合，队伍 1/8/9/10，普通难度，输出 `.sandbox/troop_events.json`，用例见脚本开头注释：守层者 TROOPS 数组、hpRate 例、flags 预置页、preset），Godot 侧是 `tests/xiyou_troop_events.gd`（按序号轮流分 4 份：xiyou_troop_events／_b／_c／_d）。另有 `battle_event_probe.cjs`（战斗事件）、`difficulty_troop_probe.cjs`。
- 数据规模：`generated/db/Troops.json` 里带事件页的敌群 338 个、共 2336 页。现有探针只覆盖 TROOPS 数组里列出的守层者／首领敌群，绝大多数页没有原版对照。
- **没有现成的“执行到哪条指令”覆盖**：地图事件那套靠 `xiyou_event_compare --coverage` 记「位置:下标」；敌群页在 `modes/xiyou/battle/battle_event_runner.gd` 里跑，没有同类记录。要先做：
  1. 在 `battle_event_runner.gd`（或测试侧子类）加一个只在 `--coverage` 时记录「敌群号 e页 p页:下标」的钩子（不改游戏行为，默认关）；原版侧在 `troop_event_probe.cjs` 里同样记每个解释器 `_index`（见 event_state_probe.cjs 的 `ran` 做法）。
  2. 仿 `事件写法覆盖.py` 出敌群页的覆盖表与簇报告（门＝页条件 conditions 的 turn／hp／switch／variable／actor、页内 111／402／601 分支）。
  3. 补变体：页条件满足的预设（回合数、HP 比例 hpRate、开关／变量、已执行 flags），tag `t1`；先挑实例多的簇。
- 现有可抄：hpRate、flags 预置页的写法在 troop_event_probe.cjs 里已有；预设键白名单要同步（探针、对照两处）。
- 必跑：xiyou_troop_events（含 _b／_c／_d）、xiyou_event_compare、`工具回归.py`、`选测.py main --list` 列出的。不一致只记交付单。

## 变更记录草稿
- 无（未做实事）

## 交接板
- 下一步：新开一条车道会话读本接续单做上面 1～3；这是新工具加探针记录，工作量比地图事件大，建议单独一期按 Opus 或 Sonnet-high 派。
- 用户试玩说明：无
- 需要用户决定：无
