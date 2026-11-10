# 交付：cc/tools-probe-scope1

- 车道／工作者：工具·探针影响面声明校验／哪吒（cc，GC10）
- 状态：可合并

## 变更记录草稿

## 2026-11-10 【cc·哪吒·未经审查】事件状态探针影响面声明：最新条目的键必须真有变体用到（dev.待定）

- 审查 76 P3-2：`probe_change_scope.json` 里 `presetKeys` 拼错（如 `actor`）或数字键没写 `*`（如 `actors.79`），以前等于「不影响任何变体」，该重跑的变体被原样取回。现在 `mv_oracle/event_state_probe.cjs` 读声明后，对 to＝当前探针 SHA 的那条，逐键查是否出现在 `event_presets.json` 全部预设（不只本次选中的前缀）的键路径里，有一个没出现就报错退出。只查最新那条：旧条目对应的预设可能已删改。空数组照旧表示不影响任何变体。
- 本次改了探针本身，声明里补一条 28525cfc…→当前 SHA、`presetKeys: []`（校验在用例执行前，applyPreset／runCase 未动），已有事件状态产物原样取回，不整份重量。
- 测试：`测试事件探针分段.py` StateScopeTests 原「nonexistent 键全部取回」改为空数组；新增 `nonexistent`、`actor`、`actors.79`、`actors`＋`nonexistent` 四种都报错；不在当前链上的旧条目键对不上不报错，且 `actors.*` 照常让带 actors 的变体重跑。
- 说明同步写进 `07_开发环境/长任务与增量同步.md`。
- 验证：`python3 -m unittest 测试事件探针分段.StateScopeTests`（经 占槽.py，2 项通过，约 130 秒）；`工具回归.py` 全部通过（72 秒）。选测.py 因改了探针列出 70 个 Godot 场景（xiyou_event_compare*、xiyou_rules*、xiyou_status_power_panel），未跑：这些场景只读探针产物、不执行探针，本次声明 `[]` 让产物逐字不变（测试里 o3 与原产物逐字相同已验）。

## 交接板

- 下一步：无新增
- 用户试玩说明：无（工具改动，玩家不可见）
- 需要用户决定：无

## 进度账

- 无变化（工具）

## 可优化（流程／工具／效率）

- 建议：`补跑事件状态探针.py` 的「探针相对 main 改过→增量全部作废」守卫不看 `probe_change_scope.json`，本分支声明了 `[]` 仍提示要整份重量、`--补齐` 跳过补跑。可改为：当前 SHA 能沿声明链折回 main 的 SHA 且最新条目 presetKeys 为空时不拦（预计省一次误报与人工确认，归工具车道）。

## 本分支提交

- 见 `git log main..cc/tools-probe-scope1`
