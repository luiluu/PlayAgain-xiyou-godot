# 交付：cc/wukong-floor9

- 车道／工作者：A 内容·楼层／悟空（cc，协调派：从「事件没执行到的簇」挑主线楼层补参照预设）
- 状态：进行中（周额度 96% 收工线停下，11-08 04:00；参照探针已跑完、云端事件对照已过，剩查 f9 为什么没走进目标分支）
- 说明：从 cc/wukong-floor8（d9d1c7ae）切出；已合 main 到 ef489a59（floor8 已合进 main，本分支只剩 floor9 自己的提交）。

## 接续要点（换会话从这里接）

1. 换源后的覆盖表：`xiyou_event_compare.gd` 加了 `@export print_coverage`（true 时照 --coverage 记，结尾分段打 `COVERAGE_PART=` 行，并故意记一条失败让云端上传日志）。用法：临时加一个场景 `xiyou_event_compare_cov.tscn`（同 xiyou_event_compare.tscn，节点上加 `print_coverage = true`），`云端选测.py run --base HEAD~1 --no-upload --skip "<其余被选中的场景>"`，约 25 分钟；`gh run download` 拿 logs-shard 里的 `xiyou_event_compare_cov.log`，把 COVERAGE_PART 拼成 `{"executed": [...]}`。用完删场景（本单已删）。
2. 这次的覆盖（云端 2c4a4d1f，209415 条）：`事件写法覆盖.py --missed 126,128,212,302,318` 没执行到的 896 个、578 簇（11-05 报告是 8789）。挑主线楼层 39/43/44/48/49/54/80/85/111/163/166/169/170/198 的 77 个簇（`04_验证/事件预设轮次/f9_簇.json`），`事件祖先预设.py --tag f9 --min 1 --targets` 合成 47 个变体（`event_presets.json` 的 f9_*，目标表 `04_验证/事件预设轮次/f9_targets.json`）。主体是守关／副本完成事件第 5～8 页重置副本时「退还邀请函」（开关 107 → 给物品 179）与「变量 107 == 1 → 212」两支。
3. 下一步：总装给槽后在本工作树跑 `python3 03_再刷重制_Godot/07_开发环境/补跑事件状态探针.py`（增量、不加 --force）；再云端跑事件对照（改了 event_presets.json 会选上）；新变体不一致的先查是重制还是参照的问题；最后用临时覆盖场景再拿一次覆盖表，`事件祖先预设.py --prune --cur <覆盖> --tag f9 --targets 04_验证/事件预设轮次/f9_targets.json --states <event_states.json>` 剪掉没走到目标的。
- 工作树已补：generated、.godot、mv_oracle/node_modules 从 sharp-kapitsa 克隆，Godot 软链已补。

## 现状（11-08 04:00 停在这里）

- 参照探针跑完（总装给的槽，增量）：47 个 f9 变体都在 `generated/oracle/event_states.json` 里、都跑完。注意新工作树的 `mv_oracle/.sandbox` 没有上次结果，增量会退成整份重量；这次是从主工作区 `.sandbox` 克隆了 `event_states.json`、`event_states.keys.json`、`event_state_keys.json` 再跑的（约 40 分钟，大半在等槽）。
- 云端 39bf5c99（--skip 没生效，跑了选测全部 269 个场景）：`xiyou_event_compare` 过，即 47 个新变体 Godot 与参照一致；唯一失败 `xiyou_splash_autosave` 是 main 刚合的 ui-gaps3 新专项，本分支没碰它的文件，未查。
- **问题：47 个变体在参照里都没走进目标「退还邀请函」**（开关 107「有票」→ 给物品 179）。轨迹都到「副本挑战完成，已自动重置！」那句提示，紧接着的 `111 开关 107 为 ON` 不成立。预设里开关 107 是开的；页内只在别的分支（第 239 条）关 107，CE1430 链里也没有。怀疑是参照探针执行 201 时真的 `performTransfer` 进了目标图（大厅等），某个插件在换图时把 107 关了；Godot 事件对照的替身不真换图，结果却也一致，所以也可能是我理解错了门的位置。下一位先查清这个（读 `event_state_probe.cjs` 第 375 行附近的换图、搜插件里换图时改开关的地方），再决定：能开门就改预设重跑探针；开不了就把 f9 整批 `事件祖先预设.py --prune` 掉，簇登记成「换图后门关」。
- 还没做：剪枝、用覆盖场景再量一次、交付单的变更记录与验证。

## 变更记录草稿

（待写）

## 验证

（待填）
