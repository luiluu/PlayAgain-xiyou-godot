# 交付：cc/bajie-probepath

- 车道／工作者：工具／八戒（cc，总装转派，原归哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】补跑事件状态探针认对预设路径：改了预设不加 --force 也会自己重量（dev.待定）

- `07_开发环境/补跑事件状态探针.py` 判断要不要重量时，依赖里的预设写成了 `mv_oracle/event_presets.json`（不存在），实际是 `03_转换工具/event_presets.json`（`event_state_probe.cjs` 读 `../event_presets.json`）。于是改了预设、产物比预设旧时它也说「不用补跑」，只能 `--force`（events8 时发现）。改成实际路径；依赖文件找不到时打一行 ⚠，不再静默。

## 优化登记草稿

- 无

## 交接板

- 下一步：无
- 用户试玩说明：无（玩家看不到）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 临时产物文件替身核 `needs()`：产物比依赖都新 → False；预设比产物新 → True（修之前第二种是 False，因为预设路径不存在）。
- `工具回归.py` 全部通过。没跑 Godot 专项（只改这个工具，`检查.sh` 每次调它）。

## 待交叉核查

- 依赖清单三项路径是否都对：`03_转换工具/event_presets.json`、`mv_oracle/event_state_probe.cjs`、`generated/oracle/events.json`。

## 本分支提交

- 本提交：路径修正＋交付单
