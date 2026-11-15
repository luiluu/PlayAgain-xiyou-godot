# 交付：cc/fix-treasure-map-1115

- 车道／工作者：玩家反馈修复／cc（Orca worker，task_5d5eb6125de1，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·藏宝图·未经审查】发行版藏宝图能在背包里直接用了：发行包没有 manifest.json 时按新源认（dev.待定）

- 玩家反馈 v0.01.10「藏宝图不能在背包里直接使用了」。根因：`XTreasureMap.v029()` 读 `generated/manifest.json` 的 `runtimeInputs` 判断正式源有没有 `installTreasureBatchRuntime`（背包里直接／批量用藏宝图、不看站位），读不到就当旧源。导出预设从 10-18（bdebddf4c「导出瘦身」）起排除 `modes/xiyou/generated/manifest.json`，dev480 发行 pck 里确实没有这个文件（`db/*.json`、`slice.json` 都在）。所以发行版 21 种藏宝图一直走旧源原生：背包里只预约公共事件、回地图后要站在宝点上才挖，否则只提示坐标。开发工程有清单，专项一直过，查不出来。不是 v0.01.10 哪次提交弄坏的，Godot 发行版从第一版起就这样；玩家说的「以前能用」是跟 RPGMV 原版（v0.29 起）比。
- 修法：`treasure_map.gd` 的 `v029()` 缺清单时按新源认（正式源已永久定在 v0.62.12，带这个运行时）；有清单时照旧看 `runtimeInputs`。清单路径改成 `static var manifest_path` 方便专项模拟发行包。`treasure_map.gd`、`treasure_batch.gd` 在 `release/v0.01` 与 main 上逐字相同，补丁线可直接摘。
- 专项 `xiyou_treasure_batch` 加「发行包没有 manifest.json」一段（33→41 条）：指到不存在的清单→ v029 为真、21 种都支持、背包里选藏宝图开数量窗、不预约事件、确定后当场用掉 1 张；有清单但没有这个运行时（旧源）仍走原生；还原后照旧。反向验证 2 项都咬住（缺清单当旧源＝修前写法、有清单不看 runtimeInputs）。
- 玩家可见：藏宝图能在背包里直接用（可选数量批量用），不用再走到宝点

## 交接板

- 下一步：出下个补丁时把本分支的 treasure_map.gd 改动摘进补丁线（两个文件和 release/v0.01 一致，干净摘）
- 用户试玩说明：背包→物品里选一张藏宝图（如「藏宝图」212 号）→ 确定：弹出「使用藏宝图」数量窗，选张数后确定，当场挖宝、说明栏写结果，不回地图、不用站在宝点上
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：运行时代码不该依赖导出时被排除的文件（`generated/manifest.json`、`generated/oracle*`、`sync_stamp.json`）。现在全工程只有 `XTreasureMap.v029()`（已修）和调试用的 `XBattleReplay.identity()` 读 manifest。可在 `语法检查.py` 或发行内容审计里加一条：非 tests 的 .gd 里出现这些路径就报（预计十几分钟，归工具车道）。
- 建议：发行模式测试（simulate_release）只换行为不删文件，覆盖不到「导出排除」这一类；可让发行入口冒烟在真 pck 上多跑一个「背包用藏宝图」按键脚本（归发行工具车道，收益中等）。

## 本分支提交

- 17a5ca5c0 藏宝图发行版不能在背包里直接用：发行包没有 manifest.json 时按新源认；专项补发行包无清单段

## 验证

- 本机：xiyou_treasure_batch（41/41）、xiyou_treasure_map、xiyou_item_bag、xiyou_bulk_pills、xiyou_percent_pills 全过（背包里直接用的丹药、淬元丹一起回归）。
- 反向验证：2 项都咬住。
- `语法检查.py` 926 个 .gd 0 问题；`工具回归.py` 全过。
- 云端选测（选测.py 选中 6 个：event_compare a～d、treasure_batch、treasure_map）：全过（提交 17a5ca5c0，2 片，最长 2.7 分钟）
- 发行模式：已确认 dev480 发行 pck 里没有 manifest.json（证据），专项用不存在的清单路径模拟发行包；没在真发行包上点（要出包，车道不出）。改动不碰天启篇空壳。
- 没跑 --oracle：没改原版移植逻辑本身，只改「认不认新源运行时」的探测。
