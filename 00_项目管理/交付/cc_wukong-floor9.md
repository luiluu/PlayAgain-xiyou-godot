# 交付：cc/wukong-floor9

- 车道／工作者：A 内容·楼层／悟空（cc，协调派：从「事件没执行到的簇」挑主线楼层补参照预设）
- 状态：进行中（预设已备好，等总装排本机槽跑参照探针）
- 说明：从 cc/wukong-floor8（d9d1c7ae）切出，含 floor8、floor7（及 floor4～6）。

## 接续要点（换会话从这里接）

1. 换源后的覆盖表：`xiyou_event_compare.gd` 加了 `@export print_coverage`（true 时照 --coverage 记，结尾分段打 `COVERAGE_PART=` 行，并故意记一条失败让云端上传日志）。用法：临时加一个场景 `xiyou_event_compare_cov.tscn`（同 xiyou_event_compare.tscn，节点上加 `print_coverage = true`），`云端选测.py run --base HEAD~1 --no-upload --skip "<其余被选中的场景>"`，约 25 分钟；`gh run download` 拿 logs-shard 里的 `xiyou_event_compare_cov.log`，把 COVERAGE_PART 拼成 `{"executed": [...]}`。用完删场景（本单已删）。
2. 这次的覆盖（云端 2c4a4d1f，209415 条）：`事件写法覆盖.py --missed 126,128,212,302,318` 没执行到的 896 个、578 簇（11-05 报告是 8789）。挑主线楼层 39/43/44/48/49/54/80/85/111/163/166/169/170/198 的 77 个簇（`04_验证/事件预设轮次/f9_簇.json`），`事件祖先预设.py --tag f9 --min 1 --targets` 合成 47 个变体（`event_presets.json` 的 f9_*，目标表 `04_验证/事件预设轮次/f9_targets.json`）。主体是守关／副本完成事件第 5～8 页重置副本时「退还邀请函」（开关 107 → 给物品 179）与「变量 107 == 1 → 212」两支。
3. 下一步：总装给槽后在本工作树跑 `python3 03_再刷重制_Godot/07_开发环境/补跑事件状态探针.py`（增量、不加 --force）；再云端跑事件对照（改了 event_presets.json 会选上）；新变体不一致的先查是重制还是参照的问题；最后用临时覆盖场景再拿一次覆盖表，`事件祖先预设.py --prune --cur <覆盖> --tag f9 --targets 04_验证/事件预设轮次/f9_targets.json --states <event_states.json>` 剪掉没走到目标的。
- 工作树已补：generated、.godot、mv_oracle/node_modules 从 sharp-kapitsa 克隆，Godot 软链已补。

## 变更记录草稿

（待写）

## 验证

（待填）
