# 交付：claude/nezha-tools-t3-d7b8a8

- 车道／工作者：工具车道／哪吒（Claude，哪吒_4）
- 状态：可合并
- 本期：合并与测试工具补漏（`合并车道.py`、`并行测试.py`、`oracle_additions.py`、`mv_oracle/README.md`），派单六项＋唐僧追加的第 7 项（合并后快速解析检查）都做了。
- 基线：已 `git merge main`（80212635）。

## 变更记录草稿

## 2026-10-28 【Claude·哪吒·未经Codex检验】合并与测试工具补漏：冲突标记拦截、单条 --abort、报错写清出路、合并后快速解析检查、并行测试默认日志、探针退出说明、接受单放行顶层字段（dev.待定）

1. **冲突标记拦截**（`合并车道.py`，10-28 唐僧踩到）：冲突接续时提交合并前扫已暂存文件新增行的 `<<<<<<<`／`>>>>>>>`／`|||||||`，有就拒绝并列出文件、不提交；唐僧自己 `git commit` 了带标记的合并，也扫 `合并前 main..HEAD` 拒绝往下。不认单独的 `=======`（Markdown 标题下划线）。
2. **单条 `--abort`**（10-27 ce-fix2 因 `common_scripts.json` 残余被拒）：`合并车道.sh <任务> --abort` 存备份引用后退回本条合并前的 main；跑过同步的，产物 `oracle`／`db`／`maps`／`manifest.json`／`slice.json` 按本次第一轮同步开头的备份还原，删 `sync_stamp.json` 与本产物目录的同步基线，删 `state.json`；车道工作树、`batch.json` 不动，拒未跟踪文件与已推送的合并。准备阶段第一次同步前在 `state.json` 记 `syncSince`，凭它找备份。同步基线格式未改。
3. **`--finish` HEAD 变化**：准备后的合并提交被 `git commit --amend`（父提交相同）修过时自动认，并同步 `state.json` 的 head／mergeCommit；另起提交仍拒，报错写明 `--also <路径>`、`--accept-doc-edits`、`git reset --soft <准备时 HEAD>` 三条出路。**main 有未跟踪文件**被拒时列出文件并提示可写进本地 `.git/info/exclude`。
4. **`并行测试.py`**：不给 `--log-dir`（或 `CHECK_LOG_DIR`）时日志写到 `04_验证/本地结果/并行测试/<时间戳>/`（留最近 10 份），结尾打印目录；失败的场景另打印完整日志路径（重跑过的指向最后一次）；`--quiet` 不打心跳与通过行，只打失败、偶发、提示与汇总。原脚本本来没有 `\r` 进度行（八戒说的「回车刷新」实为结果要等整轮结束按名排序才打、明细只截 8 行），非 TTY 下本来就是逐行输出。
5. **探针进程不退出**：新增 `03_转换工具/mv_oracle/README.md`，写明探针与临时检查脚本结尾必须 `process.exit`（jsdom 计时器挂住事件循环）。选写说明不改 `shared/host.cjs`：mv_oracle 下非探针 `.cjs` 是每个探针的缓存键，改它下一次同步全部探针整轮重跑；`.md` 不进缓存键也不进转换工具指纹。
6. **接受单放行探针顶层说明字段**（交接板工具坑）：`oracle_additions.compare_file` 对非列表的顶层字段改变（如 `scope`）也出变化候选（`collection` 为「顶层」、`key` 为字段名、`fields` 为 `["*"]`），`生成接受单.py` 照常生成、同步照常逐条核摘要；列表字段（未登记稳定键的整组用例）仍不出候选。
7. **合并后快速解析检查**（唐僧追加；10-28 wukong-challenge4 与 main 各加 `is_super_strong`，自动合并无冲突、工程整个 Parse Error，批末选测白跑 20 多分钟）：每次合并提交后（含 `--batch`）、同步与 `检查.sh` 前，①静态扫本次改动 `.gd` 同一作用域的同名 func；②`godot --headless --import`（增量）后用外置临时脚本 `load()` 全部 `.gd`，有算数的 `SCRIPT ERROR` 就停在准备阶段、根因排前列出文件（连带错误与 autoload 标识符不算）。真工程 393 个 `.gd` 16～35 秒。修好 `git commit --amend` 再跑同一命令；`--no-parse-check` 跳过本次。godot 短进程不占共用槽位。
8. 文档：`07_开发环境/合并提速工具.md` 加「工具补漏」节，`07_开发环境/README.md` 测试日志一条改写。

## 交接板

- 工具坑那条（单条撤出、接受单顶层字段）可删：两件都已做（见变更记录本条 2、6）。
- 下一步：无新增。
- 用户试玩说明：无（只改工具）。
- 需要用户决定：无。

## 规则文字（请唐僧改）

- [多会话并行](../规则/多会话并行.md) 合并步骤里写到撤出时：单条合并撤出用 `合并车道.sh <任务> --abort`（不要手动 `git reset`，否则同步产物与基线不跟着退）；批量仍是 `--abort-batch`。
- 同处「冲突接续」可加半句：接续前工具会拒带冲突标记的暂存文件。
- 同处合并步骤加：合并提交后工具自动做快速解析检查（同名 func＋godot 加载，约半分钟），不过就停在准备阶段，`git commit --amend` 修好再跑同一命令；`--no-parse-check` 只在卡住或确认误报时用。
- [车道须知](../规则/车道须知.md)「交付」里 `并行测试.py <godot> <工程> 名字前缀…` 后可加：不给 `--log-dir` 时日志自动写到 `04_验证/本地结果/并行测试/<时间戳>/`，失败项打印完整日志路径；管道给 `tail` 时加 `--quiet`。另加一句：写探针或临时 node 检查脚本结尾要 `process.exit`（见 `mv_oracle/README.md`）。

## 合并须知

- `并行测试.py` 的内容算在 Godot 测试沿用指纹里（文件头「沿用上轮结果」），本分支合并后第一次 `检查.sh` 不沿用上轮通过结果、整轮重跑 Godot 测试一次（之后照常沿用）。和下面第 6 项的同步指纹一样，挑当天本来就要跑全量的那次合并最省。

## 可优化（流程／工具／效率）

- 已做：本期六项全是（回退：`git revert` 对应提交即可，各项互不依赖；第 6 项单独一个提交）。
- 建议（本期实测发现，归工具车道）：**共用槽位对别的工作树不公平**。主工作区批测并行数＝共用上限（4）时，它的线程放掉一个槽后立刻在同一线程里重抢，而别处等槽的进程每 0.5 秒才轮询一次，几乎抢不到：10-28 07:28 起本车道 3 个小场景等了 1 小时以上一个都没占到槽，期间 main 的选测一直在跑（八戒的导入同样在等）。改法：等槽者在 `slots/` 下登记排队文件（pid＋开始时间，死进程的作废），单槽申请时若有更早登记的别的进程在等就让一轮（多槽进程照现有 heavy.lock 规则，不参加排队，免得与闸门互等）。要改 `global_slot`，得补 SlotWeightTests 同类的并发用例，本期没做。
- 建议：`oracle_additions.py` 属转换工具指纹范围（`同步正式西游.py` 的 `tools_digest`），本分支合并后，**合并前已在自己工作树同步过的车道**指纹对不上、`--from-worktree` 退出码 3，自动改跑一次完整同步（探针按缓存复用，只多转换器与比较的时间）。不想多跑就先合那些车道再合本分支，或先不合第 6 项提交（a684448d 单独可撤）。`oracle_additions.py` 只影响比较、不影响产物，可考虑把它列进 `READ_ONLY_TOOLS` 免得以后改比较规则也让指纹失效（本期没做：改 `同步正式西游.py` 同样一次性失效，留给总装定时机）。

## 验证

- 自测 `测试合并工具.py` 168/168，新增用例：`test_auto_merged_duplicate_func_stops_before_sync`、`test_parse_check_reads_godot_log_and_skip_flag`、`test_staged_conflict_markers_block_merge_commit`、`test_single_abort_restores_main_generated_and_baseline`、`test_single_abort_during_conflict`、`test_finish_accepts_amended_merge_and_explains_extra_commit`、`test_finish_extra_commit_hint_and_untracked_exclude_hint`、`test_default_log_dir_keeps_failure_detail_and_quiet`、`test_top_level_note_field_can_be_explicitly_accepted`。
- 复现旧问题→修后通过（都是临时 git 仓库夹具）：
  1. 冲突标记：同一用例在旧 `合并车道.py`（HEAD 版本拷到 scratchpad 跑）上失败——带 `<<<<<<<` 暂存后重跑返回 0、直接提交了合并；新版返回 1、列出 `modes/测试.gd`、HEAD 不动。
  2. `--abort`：夹具里的假同步按真同步顺序建基线→备份→写 `common_scripts.json`；`--abort` 后 HEAD 回到合并前、`common_scripts.json` 与 `sync_stamp.json` 没了、`manifest.json` 回到合并前内容、同步基线目录清空，车道重新合并、收尾通过。旧工具没有这个参数（只能手动 reset，残余即 10-27 现场）。冲突中 `--abort` 也能退干净。
  3. HEAD：amend 合并提交后 `--finish` 通过并提示「合并提交已修正」；另起提交时拒绝且报错含 `--also`、`git reset --soft`。未跟踪 `notice.tmp` 被拒时提示 `.git/info/exclude`，写进去后照常合并。
  4. 并行测试：假 Godot 夹具里 c 场景故意失败，不给 `--log-dir` 时 `本地结果/并行测试/<时间戳>/c.log` 有完整输出，屏幕打印「完整输出：…c.rerun1.log」与「日志：…」，输出无 `\r`；`--quiet` 不打 ✓ 行。真工程实跑见下。
  5. 探针退出：只调 `start()`＋`newGame()` 的脚本，不写 `process.exit` 90 秒后仍在（被 alarm 杀，rc 142）；加 `process.exit(0)` 6 秒结束。
  6. 接受单：`scope` 改了的参照原来 `change_candidates` 为空（只有问题「非新增用例字段改变：scope」）；修后出一条「顶层／scope」候选，按它写的接受单放行后无剩余问题；列表字段仍不出候选。
  7. 解析检查：临时仓库夹具里 lane 与 main 在同一 `.gd` 不挨着的两处各加 `is_super_strong`，git 自动合并成功（无 MERGE_HEAD）；旧 `合并车道.py` 跑同一用例直接往下合（返回 0，用例失败），新版返回 1，报「modes/marks.gd：func is_super_strong 重复定义（第 N、M 行）」，阶段停在 planned；amend 修好后同一命令接续、收尾通过。假 godot 夹具确认日志判读（autoload 与连带错误不算，真错误列出文件）与 `--no-parse-check`。**真工程**：本工作树 main 5c850de1 时的 `item_marks.gd`（两个 `is_super_strong`）放回去，解析检查 18 秒报出 52 条，第一条即「item_marks.gd：Function "is_super_strong" has the same name as a previously declared function」；还原成 80212635 的修好版本，393 个 `.gd` 0 问题（16 秒），无误报。
- **并行测试真工程实跑**（`并行测试.py` 不带 `--log-dir`，输出管道给 `tail -8`；`xiyou_gold_cap`、`xiyou_trait_stack`＋一个临时的故意失败场景 `zz_nezha_fail`，跑完已删）：结尾打印了 `日志：04_验证/本地结果/并行测试/20261028_072845_…`，每个失败场景都打印「完整输出：…<场景>.rerun1.log」，日志目录里每个场景首次与重跑各一份。另外两个场景当时也失败——原因正是 main 5c850de1 的 `is_super_strong` 重复定义（日志里看得到 Parse Error，正好印证第 7 项）；`--quiet` 单跑 `xiyou_gold_cap` 只打了失败与「1 个场景，有失败」汇总。合 main 后没再实跑这两个场景（共用槽位要排一小时以上，见「可优化」）。
- 其它自测：`测试增量同步.py` 56、`测试公式程序.py` 12、`测试选测.py` 45 全过；`测试合并工具.py` 最终 168/168。
- 未跑全量 `检查.sh`（车道规定）。

## 本分支提交

- 17712cbf 合并车道：冲突标记、单条 --abort、HEAD／未跟踪报错；并行测试默认日志目录与 --quiet（第 1～4 项同一提交：都在 `合并车道.py`／测试文件里交错，没拆开）
- 19831af5 mv_oracle README（第 5 项）
- a684448d 接受单放行顶层字段（第 6 项）
- 6cbfbafc 合并后快速解析检查（第 7 项）
- 其余：c95a2f4b 等文档与交付单 WIP、9b42e2a6 合并 main
