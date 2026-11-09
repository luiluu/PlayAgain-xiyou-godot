# 交付单 cc/tools-probe-deps（哪吒，工具车道）

状态：**WIP，不可合并**（Kyo 11-09 额度到 85% 叫停，按接续继续）

## interp8 的 hboot 改动影响面（结论）

- 静态 require 图：96 个同步探针全部经 `shared/host.cjs` 或直接 require 到 `hboot.cjs`，所以按文件算依赖也挡不住 hboot 改动，整份重量在文件级是「真依赖」。
- 实际影响：新代码只改同步 `file://` GET XHR。开机时只多读一次 `js/plugins/Drill_GlobalVariable.js`（原版 AntiCheatDetector 读来查作弊签名，读不到和读到都是 isCheat=false，开机结果相同；单次 boot 实测，占槽跑）。会变的只有用到 `CodexGuide.releaseInfo／changelogEntries` 的：Map004（大厅）事件里的 `CodexGuide.injectChangelog`，即 `event_probe`、`event_state_probe`（后者还把 hboot.cjs 内容哈希写进产物）。其余 94 个产物预期逐字不变（未整份重量核实）。
- 所以 ① 另加了「审过的 helper 改动影响面」声明（见下），以后这类改动在声明里写 rerun 只列这两个，别的不重跑。

## 改动（未提交前的 WIP，全部在本分支）

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

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/测试增量同步.py`：86 例全过（约 80 秒）。
- 没跑：`工具回归.py`、`测试合并工具.py`、`语法检查.py`、真实同步。

## 接续

- 分支 `cc/tools-probe-deps`，从 github/main eb6ab526b 切出，**还没 merge main**（main 上有 interp8 等未推送提交，交付前 `git merge main`）。头提交见 WIP 提交。
- 没有跑到一半的东西（补齐我在事件状态探针处停了，工作树 generated 是转换器新跑的，参照未完整，交付前要 `--补齐` 一次但避开总装合并时段）。
- 三件进度：
  - ① 约八成：还差 `carry_cache` 带上 `.sandbox/probe_deps`（不带的话车道里那 3 个动态探针键对不上会重跑，**必须补**，带法：目标没有就整目录复制，有就逐文件取并集）；合并时 `--from-worktree` 克隆产物也要把主工作区缺的记录补上（看 `clone_from_worktree` 之后有没有搬 `.sandbox`）；README／`长任务与增量同步.md` 写说明；回退开关覆盖登记（`回退开关覆盖.py`／豁免清单）。
  - ② 未开始：`合并车道.py` 的 `state['worktree']` 来自 `git worktree list`（`worktrees()` 约 464 行、734 行组 state），scratchpad clone 不在里面 → 交付单加一行「车道路径：…」，合并工具没找到 worktree 时读它（核对是同一仓库、分支头对得上），带给 `--from-worktree`／`--state-prev-from`（约 1416～1424 行）；`测试合并工具.py` 加例。
  - ③ 约七成：已实现并有单测；没在真实同步里看过排队效果。
- 下次从 ① 的 carry_cache 接，然后 ②，最后整体跑 `工具回归.py`＋`测试合并工具.py`＋`测试增量同步.py`＋`语法检查.py`。

## 可优化

- 影响面声明的生成可以做成小工具：给 helper 新旧版本＋人工填 rerun，自动算 from／to。
