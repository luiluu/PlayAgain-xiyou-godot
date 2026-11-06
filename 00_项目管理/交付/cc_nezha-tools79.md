# 交付：cc/nezha-tools79

- 车道／工作者：工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】同步探针失败时，已成功的探针结果暂存，下一轮不重跑（dev.待定）

- `03_转换工具/同步正式西游.py` `run_probes`：某轮有探针退出非零时，同轮已成功、产物核验通过（在、能读、没有新增或变化的错误，口径同发布前核验）的整探针，把产物和本轮缓存键存进 `mv_oracle/.sandbox/probe-stash/`（`index.json` 记键、命令、产物 SHA，不入 Git）。generated 照旧不动、增量缓存照旧不发布，失败的半轮不会被当成新结果。
- 下一轮该探针键没变、暂存产物 SHA 对得上，就不重跑：日志记 `STASH_HIT`，`PROBE_PLAN` 多一项 `stashed`，把暂存产物拷回 `.sandbox` 和新跑的结果一起照常核验、复制进 generated、记缓存；发布后清掉对应暂存。同步报告 `probes` 多一项 `stashed`。
- 不用暂存：`--full`；分片增量（`CACHE_PARTIAL`）的探针；键变了（探针、依赖、来源、种子等任一变化）；暂存文件被改过；产物带新错误的不进暂存。
- 起因：换源车道 11-06 一轮同步里 event_state_probe 挂了，其余探针全部白跑，重跑又是整轮约 3.5 小时（`cc_newsrc-switch.md`「可优化」）。
- 说明写进 `07_开发环境/长任务与增量同步.md`（缓存那段末尾）。
- 回退：`run_probes` 里 `stash = load_stash() if cache and not cache.force else {}` 改成 `stash = {}` 即不再用暂存；`.sandbox/probe-stash/` 可直接删。

## 交接板

- 下一步：无新增。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议（工具车道，小）：探针退出 0 但产物核验不过（新错误）时现在直接抛错，也不暂存别的探针；可以同样把其余通过的存起来。本轮按派单只做「探针失败」。
- 建议：暂存用 `shutil.copy2`，event 类大产物可改 APFS 克隆省空间。
- 优化登记草稿：无

## 待交叉核查

- `03_再刷重制_Godot/03_转换工具/同步正式西游.py`：新增 `stash_dir`、`file_sha`、`load_stash`、`save_stash`、`stash_usable`、`output_acceptable`；`run_probes` 计划阶段认暂存、执行跳过暂存探针、失败时存暂存、发布后清暂存、返回值加 `stashed`。未改战斗核心文件。
- `03_再刷重制_Godot/07_开发环境/测试增量同步.py`：CacheTests 加 `stash_run` 与 2 项用例。
- `03_再刷重制_Godot/07_开发环境/长任务与增量同步.md`：加一段说明。

## 验证

- `测试增量同步.py` 69 项全过；新增 2 项 `test_successful_probes_are_kept_when_another_probe_fails`（b 挂→a 进暂存、generated 不动；下轮只跑 b，a 用暂存，发布后两者都命中缓存、暂存清空）、`test_stash_is_not_used_when_inputs_change_or_full_or_output_is_bad`（a 输入改了、`--full`、产物带新错误、暂存被改，四种都照跑）。用改动前的 `同步正式西游.py` 字节跑，2 项都挂（1 失败 1 报错）。
- `测试角色同步提速.py` 27 项全过；`工具回归.py` 全过（59 秒）。
- 没跑真同步（3.5 小时），首次真同步里有探针失败时看日志里的 `PROBE_STASHED`／下一轮的 `STASH_HIT`。没改 .gd，没跑 `语法检查.py`。

## 本分支提交

- 见 git log
