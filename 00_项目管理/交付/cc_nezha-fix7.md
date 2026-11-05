# 交付：cc/nezha-fix7

- 车道／工作者：AY 哪吒 fix7（cc；只改工具）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·nezha·未经审查】选测：事件空绿扫描／基线／补预设批量收窄后补回 content（dev.待定）

- 依据：审查 48 P2。fix6 的 toolNarrow 把 `事件空绿基线.json`、`事件空绿扫描.py`、`补预设批量.py` 收进 tool_readonly，只跑 guards＋tools，漏了 content；`检查.sh:243`「事件空绿扫描.py --check」挂在 content 下。
- 做法（审查推荐的第二种）：`选测对照.json` 新增组 `tool_readonly_content`（工具回归＋content＋引用它的测试，不选整组 converter），三个文件各一条规则，排在 `03_转换工具/*` 之前。toolNarrow 只改写 converter 组，不会碰它们；开关 `XIYOU_TOOL_NARROW=0` 仍回整组 converter（含 content）。
- 回归：`测试选测.py` 加两例（三文件各断言 checks = guards、tools、content 且不选 converter 场景；开关关掉回 converter）。
- 扫一遍 tool_readonly 其余只读文件（Boss战清单、mv_event_dump、zh_collation_table.cjs、事件增量比对、解锁链表、配方转换、验收盘点）：`检查.sh` 里没有任何 `--check` 调用它们，无同类漏项，无需修。共性参照验收.py、内容覆盖检查.py 被入口链引用，本来就留在 converter（含 content）。

## 优化登记草稿

无（只改选测工具，不改游戏行为）。
