# 交付：cc/nezha-fix6

- 车道／工作者：C 规则＋工具／哪吒（cc，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】隐月叠层随陈旧状态过滤（审查 46 P3-1），选测只读工具收窄（dev.待定）

- **隐月叠层（审查 46 P3-1）**：先量原版——`raven_reflect_probe.cjs` 加 `reffloor.tcr2`／`.pre1`／`.pre2`（夹具 72→75 例）：8 号反射回自己、同一下附加隐月 2521 三次，pre＝行动前先加几次。原版**同一下只加一层、行动前再加也不叠**（`stateFloor` 恒 1），也就是原版隐月恒 1 层，「本体陈旧＋多出的层」在原版碰不到，只有重制 O-178 的叠层才有。没有原版可比，按一致性定：`XActor.trait_objects` 在有陈旧状态且 `STALE_TIMING` 开着时，`floor_states()` 里本体还陈旧的层也跳过（多出的层跟本体一起进缓存）。`tests/xiyou_raven_reflect` 加 `reffloor` 类（比原版的层数、暴击率，比时关 `FIX_YINYUE_2521` 取原版 0.2%），另加重制独有一步：本体陈旧时 `add_state_floor` 叠到 2 层，暴击率不变；下一击 refresh 后两层一起生效。561 项全过，反向验证（去掉过滤）咬住。挂现有 `STALE_TIMING` 开关，没新开关、没用 O 号。
- **选测只读工具收窄（accept4、fix5 交付单「可优化」）**：`选测.py` 新增 `toolNarrow`（`选测对照.json`，组 `tool_readonly`：工具回归＋引用它的测试）。改动落在 `03_转换工具/` 下直接放的文件，若从「产出 generated 的入口」（同步正式西游.py、xiyou_export.py、新建工作树.sh）按文件名（.py 另认模块名）在 03_转换工具 里一路引用下去都碰不到它，就不再归整组 converter。注释里提到不算（探针头注释写「见 事件空绿扫描.py」原来会把它拉进去），字符串都算（宁可多认）；一个入口都不在、或是切片文件，留在原组。现在认成只读的：Boss战清单.py、mv_event_dump.py、zh_collation_table.cjs、事件增量比对.py、事件空绿基线.json、事件空绿扫描.py、补预设批量.py、解锁链表.py、配方转换.py、验收盘点.py；转换器、同步、增量同步、event_presets.json、xiyou_slice.json、同步会跑的检查都还在 converter。拿历史提交实测：只改 事件空绿基线.json 的 69c40dd9 由 67 个场景降到 0 个（只跑工具回归），改 解锁链表.py 的 1f9b1cae 由 22 降到 4。回退：`toolNarrow.enabled` 设 false，或环境变量 `XIYOU_TOOL_NARROW=0`。

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：审查 46 P3-1 可销账（原版碰不到，按一致性改）。
- 用户试玩说明：无可见变化（隐月叠层只影响刚加上、还没进缓存那一击的暴击率）。
- 需要用户决定：无。

## 进度账

- 无变化（P3 尾项与工具）。

## 验证

- 合过 github/main（2b3c18e0，ui12 dev.355 收尾），`新建工作树.sh --补齐`；探针只改夹具式的 `raven_reflect_probe`（不在 PROBES），没跑同步。
- 专项：`xiyou_raven_reflect` 561／561。
- 云端选测：268 个场景、14 片全过（提交 cd385e1c，actions/runs/42031664903）。
- `测试选测.py` 128／128（新增 `ToolNarrowTests` 5 例：只读工具、只读数据与注释提及、入口链文件留 converter、对照表开关、真实资料库的只读集合）；`工具回归.py` 全过；`语法检查.py` 通过；反向验证（去掉叠层过滤）咬住。

## 待交叉核查

- `actor.gd` `trait_objects`（原沙僧独占核心文件）：只在有陈旧状态且 `STALE_TIMING` 时多一层过滤。
- `选测.py` `pipeline_files`／`strip_comments`：注释剥离的正则（`//` 前不是 `:`、引号、反斜杠；`#` 前是行首或空白）会不会把真引用当注释删掉，导致把转换链里的文件误判成只读（误判方向是少跑测试）。

## 可优化（流程／工具／效率）

- 已做：选测只读工具收窄（见上，回退开关两处）。

## 本分支提交

- 见 `git log main..cc/nezha-fix6`
