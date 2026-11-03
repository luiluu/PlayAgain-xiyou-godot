# 交付：cc/nezha-tools50

- 车道／工作者：D 工具／哪吒（cc）
- 状态：进行中（额度到线，WIP 停手；已做的 7 个可单独合并，见接续）

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】探针五乘区存量清理（一期，7 个）（dev.待定）

- 分支基于 cc/nezha-tools49（尚未合进 main 时先合它）。
- 对 7 个探针（boss_output、formula_rest、guyu、shield、stage50_review、state_merge_context、state_operation）加 `w.eval('CodexZones.ENABLED=false;')`；每个都先跑一次原样、再跑一次加开关，产物（去掉 sourceIdentity）逐字相同，所以 fixture／参照不变；从 `探针五乘区存量.json` 删掉这 7 行（剩 43）。
- 未改任何 fixture，未跑 Godot 专项（产物没变）。

## 交接板

- 下一步：接着清存量剩下的 43 个（见接续）。
- 用户试玩说明：无。
- 需要用户决定：无。

## 验证

- `探针登记检查.py` 通过（存量 43）、`测试探针登记检查.py` 通过。其余只靠上面的前后产物比对；没跑全量、没跑选测（总装 15 号收尾通知说不用）。

## 接续

- **passive_content_probe 受五乘区影响**：关掉后 baseline/damage 的 growth 0.6437→1，伤害如 619→961、1052→1634。我已 `git checkout` 回去没改，要做：加开关、重跑、更新 `tests/fixtures/passive_content_oracle.json`、跑对应 Godot 专项（passive_content 相关，选测.py 会列），看断言。
- 已加开关但中途被打断、未比对，已还原：skill_change_to、toji、nanoha_kill、nanoha2。
- 没比对：boss_react、boss_sequence、boss_state_origin、boss_output_context（产物名里有 `--smoke` 三元式，旧脚本没认出；`drop_record_probe` 不走 finish，直接写文件，需手动对比）。
- 做法：临时脚本在 /private/tmp/claude-501/s/zone.py（插入开关→前后各跑一次→比对产物；可能被清，思路就是这样）。大件如 slice_probe、state_effects 最后做。
