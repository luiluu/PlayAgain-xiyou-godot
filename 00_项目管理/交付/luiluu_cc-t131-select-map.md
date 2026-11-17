# 交付：luiluu/cc-t131-select-map

- 车道／工作者：T131 选测对照（cc，Sonnet＋medium，丙档机械活）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·未经审查】T131 选测对照：没有代码读的 tianqi_data 表不再判成整轮（dev.待定）

- 起因：T116 交付单提到改 `tianqi_data/brand.json`（没有任何代码或测试读它）时，`选测.py --affected` 落到 `mode_data` 组的 `fallback: FULL`，判成整轮 658 场景，本机跑一小时没完。
- `选测对照.json` 新增 `tianqi_data` 组和一条规则 `modes/xiyou/tianqi_data/*`（排在 `modes/xiyou/*.json` 之前）：refs＋loaders 照旧找引用它的测试，再固定加数据校验场景 `xiyou_json_cache`、`xiyou_text_batch23`、`xiyou_tianqi_balance`，没有 fallback、不整轮；检查 guards。实测改 brand.json 只选 3 个场景。
- 新表自动归本组（通配，不用逐个登记）；`测试选测.py` 加两条：孤表／有引用表／新加未登记表都不整轮；真实对照表下 tianqi_data 每个文件都归这一组、组内场景都真实存在（被更早规则抢走或场景改名会红）。
- 玩家可见：无。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`mode_data` 组本身对「没人读的 modes/xiyou/*.json」仍 fallback FULL，同类孤表以后出现再按此例开小组（预计收益：免整轮；归选测对照维护车道）。

## 本分支提交

- 见 git log
