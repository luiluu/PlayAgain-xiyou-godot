# 交付单：cc/nezha-tools25（哪吒_12，工具车道）

- 状态：可合并
- 执行者：cc（哪吒_12）；自 tools24 末端 87e31264 切，**须在 tools23、tools24 之后合**。没合 main（main 仍在合 bailong-garou2，state.json 在）；main 自分叉以来没碰本期两个文件，预计无冲突。只改 `07_开发环境/合并车道.py`、`测试合并工具.py`。
- 验证：`测试合并工具.py` 224/224（新增 1，先在旧代码上失败）；`测试参照批次.py`、`测试增量同步.py` 全过（确认已修项的回归仍有效）；未跑 Godot（只动合并工具）。

## 第 0 步核对（tools24 交付单留下的工具类剩余项）

逐条对照 tools24 末端代码与沙僧报告的复现，结论：只有 T2 真缺，其余早已在 main 修好、各有回归测试。

| 项 | 出处 | 现状 |
| --- | --- | --- |
| T1 撤回恢复到重试中间产物（第七期 T1／T3、第十七期补充） | `undo_sync` | 已修于 dev.223：12d1d79a 首轮同步前固定快照（`preSync`），按快照还原、删同步新建项，快照丢了拒绝声称还原 |
| parse_check 漏判导入失败（第七期 T3、第十七期 P3） | `parse_check` | 已修于 dev.223：d3b473de 对导入／加载退出码与导入 `ERROR:` 报错，有回归 |
| lsof 不可用时活动工作树保护失效（第十六期 P2） | `active_cwds` | 已修于 dev.223：d3b473de 返回 None，`lane_protected` 保守不删，有回归 |
| withdraw_baseline 误删无关基线（第十六期 P2） | `同步正式西游.py` | 已修于 dev.223：57a739ae 不能归因到撤出内容的删除拒收并列出，有回归 |
| 参照批次混批、同步戳丢失豁免（第十五期两条 P2） | `参照批次.py` | 已修于 dev.223：eeedc4df 逐份核对参照摘要；只认有效新戳 |
| **T2 解析失败后漏判已推送的合并（第七期 T2／P2）** | `abort_one` | **本期修**，见下 |

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】撤回合并不再只凭 mergeCommit 查远端（沙僧第七期 T2／P2，dev.待定）

- **问题**（沙僧第七期 T2／P2）：`合并车道.py --abort` 只在 state 里有 `mergeCommit` 时才查 `github/main`；合并后解析检查不过时 state 停在 planned、还没记 `mergeCommit`，这时若带错的合并已被推上去，`--abort` 照样退回 base、返回 0，远端留着那份提交。核实：tools24 末端代码里仍是这样，反例在旧代码上失败（退回成功）。
- **修法**：新增 `pushed_since(root, base, *commits)`：跟踪分支上 base 之后的提交与 HEAD／记下的合并提交 base 之后的提交有交集，就算已推送。`--abort` 拿 HEAD 和 `mergeCommit` 比，推上去之后又 amend 的（HEAD 不在远端、旧版在）也认得；`--abort-batch` 同样改用它，拿 HEAD、本批各条与当前 state 的合并提交比。没有跟踪分支时照旧当没推送。
- **回退**：恢复 `abort_one`／`abort_batch` 里原来的 `merge-base --is-ancestor <mergeCommit> github/main` 两段，删 `pushed_since`。
- 自测：`测试合并工具.py` 224/224，新增 `test_abort_refuses_pushed_merge_after_parse_failure`（解析失败→推送→`--abort` 拒绝且 HEAD 不动；amend 后仍拒绝；远端退回 base 后照常能撤）。

## 交接板

- 「沙僧第六～二十一期交回」工具项可整行划掉：T2 本期修（dev.待定）；T1、T2／parse_check、同步指纹与戳丢失豁免两项、withdraw_baseline 误删、lsof 保护已修于 dev.223（哪吒_10：12d1d79a、d3b473de、57a739ae、eeedc4df），交接板这行是过时的，审查线程按这几个提交销账即可。

## 可优化

- 优化登记草稿：无。
- 建议：交接板遗留清单又一次落后于代码（6 项里 5 项早已修）；总装合并修复时顺手划掉交接板对应项，能省下一轮核对。

## 本分支提交

- 5e399a08 合并工具：--abort／--abort-batch 不再只凭 mergeCommit 查远端（沙僧第七期 T2）
