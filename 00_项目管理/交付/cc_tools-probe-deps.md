# 交付：cc/tools-probe-deps

- 车道／工作者：C 工具／哪吒（cc，GC8 起、GC8b 续完）
- 状态：可合并

## 变更记录草稿

## 2026-11-09 【cc·哪吒·未经审查】增量同步按探针实际依赖算 helper 键、helper 影响面声明、clone 车道合并（dev.待定）

- 增量同步：探针缓存键里的 helper 不再是公共键，改按探针实际依赖（静态 require 图＋字面量读取＋运行时记录 `probe_dep_recorder.cjs`）；以前任一 helper 改了 96 个探针全跑，现在 hboot／fs_guard／manual_sandbox／source_identity 仍 96、shared/host 61、其余 2～4。旧条目按输入明细换键，换算法本身不重跑；`incremental_sync.py` 改按修订号进分片探针的键。回退 `XIYOU_PROBE_HELPER_DEPS=0`。
- 审过的 helper 影响面声明 `03_转换工具/helper_change_scope.json`（回退 `XIYOU_HELPER_SCOPE=0`）：首条是 interp8 的 hboot 改动，只让 event_probe、event_state_probe 重跑；声明要甲档核查。
- 运行时依赖记录随 `--carry-cache` 带进车道、随 `--from-worktree` 补回主工作区；同步内等槽的探针按「已占过槽的其余段→估计耗时长的→先来先得」排队（回退 `XIYOU_SYNC_SLOT_ORDER=0`）。
- `合并车道.py`：车道不在 git worktree 里（scratchpad clone）时读交付单「车道路径」，核对分支头与干净后给同步取车道产物（回退 `XIYOU_LANE_PATH=0`）。
- 说明：`07_开发环境/长任务与增量同步.md`、`03_转换工具/mv_oracle/README.md`、交付单 README。
- 验证：`测试增量同步.py` 88 例、`测试合并工具.py`、`测试角色同步提速.py`、`测试事件探针分段.py`、`工具回归.py`、`语法检查.py` 通过；没跑真实同步。

## 交接板

- 下一步：合并后第一轮同步看 `CACHE_MISS`／`upgraded`，预期只 event_probe、event_state_probe 重跑；审查线程甲档核 `helper_change_scope.json`。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## interp8 的 hboot 改动影响面（结论）

- 静态 require 图：96 个同步探针全部经 `shared/host.cjs` 或直接 require 到 `hboot.cjs`，所以按文件算依赖也挡不住 hboot 改动，整份重量在文件级是「真依赖」。
- 实际影响：新代码只改同步 `file://` GET XHR。开机时只多读一次 `js/plugins/Drill_GlobalVariable.js`（原版 AntiCheatDetector 读来查作弊签名，读不到和读到都是 isCheat=false，开机结果相同；单次 boot 实测，占槽跑）。会变的只有用到 `CodexGuide.releaseInfo／changelogEntries` 的：Map004（大厅）事件里的 `CodexGuide.injectChangelog`，即 `event_probe`、`event_state_probe`（后者还把 hboot.cjs 内容哈希写进产物）。其余 94 个产物预期逐字不变（未整份重量核实）。
- 所以 ① 另加了「审过的 helper 改动影响面」声明（见下），以后这类改动在声明里写 rerun 只列这两个，别的不重跑。

## 改动（GC8 期，全部在本分支）

- `03_转换工具/incremental_sync.py`
  - ① `XIYOU_PROBE_HELPER_DEPS`（默认开，=0 回旧）：公共键去掉 `helpers`；依赖＝探针起的静态 require 图＋字面量 `path.join(__dirname,…)` 读到的 mv_oracle 文件＋运行时记录（`.sandbox/probe_deps/<探针>.json`）。认不出的写法（非字面量 require／拼路径）且没记录时带全部 helper（现有 96 个里只有 slice_probe、shared_system_probe、event_state_probe 三个）。实测各 helper 被依赖数：hboot／fs_guard／manual_sandbox／source_identity 96，shared/host 61，其余 2～4（以前任一 helper 改都 96 个全跑）。
  - 旧格式条目升级：`upgrade()`／`_compatible()` 按存下的输入明细比，相容就换新键，**换算法本身不触发重跑**。
  - 分片探针 TOOLING 里 `incremental_sync.py` 改成 `SHARD_TOOLING_REVISION`（=1），旧条目的整份哈希算作修订 1（以前改这个文件就让 smart_ai／slice／event 整份重跑）。
  - `helper_change_scope.json`（`XIYOU_HELPER_SCOPE`，默认开）：`{file, from, to, rerun, why}`，不在 rerun 里的探针把 to 当 from；格式错直接报错。**声明要交叉核查（甲档）**。文件本身还没建（没有就等于空）。
  - `record()` 先把逐进程记录并成一份再重算键（与 commit 一致）。
- `03_转换工具/probe_dep_recorder.cjs`（新）：同步给探针 `--require` 预加载，记读过／require 过的 mv_oracle 文件，只写 `.sandbox/probe_deps/`。
- `03_转换工具/同步正式西游.py`
  - ① `run_node` 经 `with_dep_recorder` 加预加载（记录器文件不在就不加）。
  - ③ `XIYOU_SYNC_SLOT_ORDER`（默认开）：本同步内等槽的探针进程内排队，一次只让第一个去抢共用槽；次序＝已有段占到过槽的探针其余段优先 → 估计耗时长的先（`.sandbox/probe_durations.json`，取本次与旧值八成的较大者；没有按 SLOW_PROBES）→ 先来先得。不抢已占的槽、不改跨工作树排队。
- `07_开发环境/测试增量同步.py`：改 1 例（helper 不再一律全失效），加 13 例（依赖图、开关回退、旧条目升级、动态读取＋记录、字面量读取、影响面声明＋开关、TOOLING 修订号、记录器真跑 node、同步加记录器、槽次序、耗时估计）。

## 续（GC8b）补的

- ① `incremental_sync.carry_probe_deps`：`--carry-cache`（`新建工作树.sh --补齐`）把主工作区 `.sandbox/probe_deps/` 里车道没有的记录文件逐个带过去（已有的不覆盖＝按文件取并集；记录目录或文件含符号链接拒绝携带）。`同步正式西游.py --from-worktree` 克隆车道产物后，同样把主工作区缺的记录从车道补上（报告 `fromWorktreeProbeDeps`）。
- ② `合并车道.py`：车道不在 `git worktree list` 里时读交付单 `- 车道路径：<绝对路径>`（`lane_path_from_delivery`），核对该处 HEAD 等于交付提交、干净、不是主工作区，通过就作为 `syncFrom` 给同步的 `--from-worktree`／`--state-prev-from`（旧 state 没有 `syncFrom` 时用 `worktree`）；任何一项不符只提示、照旧完整同步。`XIYOU_LANE_PATH=0` 不读。清理工作树仍只认 `worktree`，clone 不会被 `清理工作树.sh` 动。交付单 README 加了这一行的写法。
- ③ `helper_change_scope.json`：只写本次 hboot 那条（`mv_oracle/hboot.cjs` ae5d841f…→1a4184bd…，0486c72a9；rerun＝`event_probe.cjs`、`event_state_probe.cjs`）。**这条声明要甲档交叉核查**：核对 from／to 是 0486c72a9 前后的整份 SHA-256，且除这两个外没有探针读 `CodexGuide.releaseInfo／changelogEntries` 或把 hboot.cjs 内容进产物（我 grep 过：`hboot.cjs` 文件名进产物的只有 event_state_probe；guide／zhenqi／affix_rate／honghuang_reward 用 CodexGuide 但不碰这两项；interp8 车道整份探针只 m4e71p0 变）。
- `_compatible` 折算影响面：声明之前已用新 helper 跑过、条目记了 to 的（interp8 之后同步过的车道），按声明折算后与本次相同就换键接着用，不因加声明重跑（单测覆盖）。
- 说明：`长任务与增量同步.md` 加「按探针实际依赖算 helper 键」一节，改了「改 incremental_sync.py 让分片探针整轮重跑」那句；`mv_oracle/README.md` 那句「改 helper 全部探针重跑」改成按依赖。
- 回退开关覆盖：`回退开关覆盖.py` 只扫 Godot 里带 O 号的开关，这几个是工具环境变量（`XIYOU_PROBE_HELPER_DEPS`、`XIYOU_HELPER_SCOPE`、`XIYOU_SYNC_SLOT_ORDER`、`XIYOU_LANE_PATH`），不在它的范围；各自 `=0` 的回退在单测里都有用例。
- 修了 GC8 的 WIP 漏改的旧测试：`测试角色同步提速.py` 两例按旧语义（helper 是公共键）断言，改成新语义＋`XIYOU_PROBE_HELPER_DEPS=0` 回旧；`测试合并工具.py` 一处源码断言跟着变量名改。

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/测试增量同步.py`：88 例全过（78 秒）。
- `测试合并工具.py`：整份 326 例，第一次 2 例挂（`同步正式西游.py` 新加的补记录在测试夹具里参照目录不在仓库下时 relative_to 报错），修后 SyncStampTests 8 例全过、新加 `test_clone_lane_path_in_delivery_feeds_from_worktree` 过；没再整份重跑（其余 324 例第一次已过，修改只在那一处）。
- `测试角色同步提速.py`、`测试事件探针分段.py`：全过。
- `工具回归.py`：第二次全过（85 秒）；第一次「安卓实机冒烟」挂，单跑与重跑都过，算偶发（第一次，见 flaky 记录）。
- `语法检查.py`：通过。
- 选测：`选测.py main --list` 因改了转换工具目录列 71 个 Godot 场景（event_compare、rules 各难度、global_vars、status_power_panel）。**没跑**：本次只改同步／缓存／合并工具代码与一份影响面声明，不改转换器输出、探针或 Godot 代码，generated 不变，这些场景比的正是 generated；派单写明不跑整份同步。总装合并时同步会按新键走一轮，看 `CACHE_MISS`／`upgraded` 是否只剩 event_probe／event_state_probe 重跑。
- 没跑：真实同步（排队效果③仍只在单测里看过）。

## 接续

无。分支 `cc/tools-probe-deps` 已 merge main（70c22c2e2）。

## 合并时注意

- 本分支改了 `incremental_sync.py`，但分片探针按 `SHARD_TOOLING_REVISION`（=1）进键，旧条目算作修订 1，不会因此整轮重跑；新算法第一次跑时旧条目按输入明细「升级」换键（日志 `upgraded`）。
- 预期第一轮：event_probe、event_state_probe 因 hboot 改动重跑（interp8 已经在车道跑过、main 用的是克隆产物，main 的缓存条目还是 hboot 旧版），其余探针命中。不是的话看 `CACHE_MISS` 原因再说，别直接 `--full`。

## 待交叉核查

- 甲档：`03_转换工具/helper_change_scope.json`（声明内容，见上③）；`incremental_sync.py` 的 `_compatible` 折算、`carry_probe_deps`。
- 丙档：`合并车道.py` 车道路径、`同步正式西游.py` 补记录、`probe_dep_recorder.cjs`、槽次序。

## 可优化

- 影响面声明的生成可以做成小工具：给 helper 新旧版本＋人工填 rerun，自动算 from／to。
