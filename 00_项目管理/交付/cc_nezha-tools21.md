# 交付单：cc/nezha-tools21（哪吒_10，工具车道）

- 状态：可合并
- 执行者：cc（哪吒）；自 tools20 末端切，须在 tools18～20 之后合。验证：测试合并工具、测试云端准备、测试选测、测试记录工具，未跑 Godot；云端部分用桩（gh 桩）测

## 变更记录草稿

## 2026-10-31 【cc·哪吒】云端 report 没起来时本机算、解析错误不再空等、--branch 指定车道分支（dev.待定）

- **待核查分档**：`待核查分档.json` 加 `modes/xiyou/ui/` → 乙（总装六定）。
- **云端 report 没起来但分片全过**（run 41167600311 的情形：report 任务被 spending limit 挡了）：`云端选测.py wait` 在「结果 ref 不在、运行已结束」时先 `gh run download` 取 `plan` 与 `result-shard-*` 工件，plan 的提交号对得上、每个分片都有结果才在本机跑 `cmd_report`（不 --publish、不写 refs/ci/results），按通过(0)／失败(1)返回，输出里注明「report 由本机用云端各片结果工件算出」。工件不全（缺片、提交号不符、下不到）才判没结果：额度被挡返回 4，其它返回 3，`检查.sh --cloud` 照旧提示改本机。**回退**：删掉 `cmd_wait` 里 `local = local_report(sha)` 那三行即回到原行为。
- **Parse Error 空等 600 秒**：等的是 `并行测试.py` 的 `run_with_rusage`——Godot 遇脚本解析错误不退出，要等单场景超时才杀（云端 shard 与本机都经这里；`检查.sh` 只是调它）。读输出改成边读边存，出现 `SCRIPT ERROR: Parse Error: …` 或 `ERROR: Failed to load script "…" with error "Parse error"` 行（`FATAL_LOAD`）就立刻杀掉，退出码 143，输出末尾加「提前终止」。测试正文里打印的 "JSON Parse Error" 之类不匹配。顺带：被杀后孙进程攥着管道时最多再等 2 秒收尾巴、不再阻塞在 close 上。**回退**：`run_one` 里去掉传给 `run_with_rusage` 的 `FATAL_LOAD`。
- **app 自建工作树分支名与派单不一致**：`合并车道.py` 加 `--branch <分支>`（任务名仍写交付单名；交付单按 `<前缀>_<任务>.md` 找）；不给时找不到 `cc|claude|codex/<任务>` 的报错里列出交付单名对得上的分支并提示用 `--branch`。
- 自测：`测试合并工具.py` 216/216（新增 2：解析错误提前终止、`--branch`），`测试云端准备.py` 15/15（新增 3：本机算 report 通过／失败、工件不全判没结果），`测试选测.py` 55/55，`测试记录工具.py` 14/14（分档用例改用 ui 为乙）。

## 交接板

- 无需登记。

## 可优化

- 本机算 report 用的是已有的 `cmd_report`，云端 report 任务若因 spending limit 起不来，合并路径现在能自己继续；根因（额度）仍要另处理。
- `新建工作树.sh`／车道须知对「车道就在 app 给的工作树里从指定提交切分支」的适配这期只做了合并工具一侧（`--branch`）；工作树守卫不许写派单旧工作树的部分我没动。
