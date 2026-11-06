# 交付：cc/nezha-tools76

- 车道／工作者：工具／CF（cc，哪吒）
- 状态：可合并
- **合并顺序**：从 main 切出，已合过一次 main（含 tools75），无前置分支。

## 变更记录草稿

## 2026-11-06 【cc·CF·未经审查】合并工具三处坑：注释占位按「位置」认号、旧交付单冲突按删除、合并提示认合并工具在跑（dev.待定）

- **① 代码注释占位按草稿「位置」列认号**（11-06 ui16 三处、android4 两处，草稿首格写 `O-待定-1～3`，注释都写不带序号的，工具没认出、收尾 opt_audit 才拦）：`合并车道.py` 在 plan 阶段就查车道新增的代码行（不含 .md），和草稿首格对不上的占位按草稿行「位置」列写的文件认（可以写工程内路径的后半段，如 `battle/boss_hp_bar.gd`）：这个文件只有一条草稿就用那条的号；有几条时再看本行和它注的声明（接着的注释行加注释块后第一条代码行，遇空行停）里有没有哪条独有的识别键（开关名等）。认不出（同一文件几条分不出、或「位置」列没写这个文件）就在**合并前**停下、一次列全，提示车道把注释写成对应的 `O-待定-N`；准备阶段换号时同样认。草稿首格的写法照旧优先，原来的「同一占位几条草稿按识别键认」不变。没有草稿表的批次不查（照旧只提示未换号）。
- **② 车道改了 main 已归并删除的旧交付单**（11-06 shop1 改 keys3 的交付单）：plan 已会提示「不再并入」，但它还留在改动清单里、进了 versionPaths（交付单都带开发编号占位），合并时 modify/delete 冲突，按删除解决后报「编号占位文件已改变类型」，总装手改 state 才过。现在 plan 把它剔出改动清单、记进 `goneSheets`；合并冲突**只有**这些文件时自动 `git rm`、提示一句「按删除处理，车道补写的内容没并入」后照常提交合并；还有别的冲突照旧停下。另外 `replace_versions` 遇到 versionPaths 里已不存在的旧交付单（tools76 之前生成的状态文件，或总装手解冲突删掉的）就从 versionPaths 去掉、提示，不再报改变类型；本期交付单自己不见了照旧报错。
- **③「总装正在合并 tools74（阶段 merged）」提示**：读的是主工作区 `.git/lane-merge/state.json`（`参照批次.py flux`，tools59）。**不是没清的旧标记**：tools74 的合并从 01:32Z 合并提交到 02:33Z 收尾，整整一小时都在同步阶段（tools74 改了事件状态探针，同步里 event_state 整份重量，机器负载 14～24）；收尾后状态文件按批次删掉，提示就没了（tools75 车道 02:33Z 之后的几轮测试都没再出现）。真正的毛病是判定只看状态文件 30 分钟内动没动：同步超过 30 分钟时会把还在同步的主工作区当成定稿去比对，状态文件中途被改一下（接受单等）又会延长。现在合并工具还在跑（`running.lock` 的持锁进程在、启动时间对得上，同 take_lock 的判定）就算正在合并、不看时间；工具没在跑时照旧按 30 分钟认中断。提示里写明「状态 N 分钟前更新」和「合并工具在跑（pid）」或「没在跑，多半是总装在手改或解冲突」，车道一眼看得出是不是旧的。
- **④ 没做**（可选项，到交接线）：见「可优化」。

## 交接板

- 下一步：④ 合并推送成功后自动 `云端选测.py trust` 给收尾提交立锚点（可选，见下）。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议（④，归工具车道，小）：`合并车道.py` 的 `push_github` 推送成功后，若本批有云端或本机通过结果（收尾提交的 `验证:` 尾注不是「未检查」），对收尾提交跑 `云端选测.py trust <提交> --reason "合并推送后自动"`，免得选测基准一直停在 a7baef3ab 每次整轮。要注意：手补了代码、没有「手补已验」的收尾提交不该立（tools60 的规矩），立锚点失败只警告。
- 优化登记草稿：无

## 待交叉核查

- `07_开发环境/合并车道.py`（①：`opt_row_paths`、`comment_context`、`pick_by_location`、`check_orphan_placeholders`、`substitute_orphans`，`assign_opt_numbers` 记 `optRows`，plan 里调用；②：plan 的 `goneSheets`、`resolve_gone_sheets`、`gone_sheet`、`replace_versions` 去掉旧交付单）、`07_开发环境/参照批次.py`（③：`flux` 认合并工具在跑、`merge_tool_running`）。未改战斗核心文件。

## 验证

- `测试合并工具.py` 265 项全过；新增 6 项：①`test_bare_comment_placeholder_numbered_by_location_column`（ui16 三文件三条）、`test_same_file_two_drafts_bare_comment_stops_at_plan_and_lists`（android4：aux 那处分不出、合并前停下列出、main 不动，注在开关上的那处认得出不列）、`test_same_file_two_drafts_numbered_when_lane_writes_suffix`、`test_comment_placeholder_in_file_no_draft_mentions_stops`；②`test_lane_edit_of_sheet_deleted_in_main_merges_as_delete`（真走到 modify/delete 自动解冲突）、`test_old_state_with_gone_sheet_in_version_paths_is_dropped`。6 项在改动前的 `合并车道.py` 上全部挂（用备份字节还原）。
- `测试参照批次.py` 26 项全过（新增 `test_flux_old_state_counts_while_merge_tool_still_runs`：状态 60 分钟没动、锁里进程不在→放行；锁里是活进程→算正在合并、提示写 pid 与 60 分钟；pid 被复用→放行）。
- `测试选测.py` 133 项全过；`工具回归.py` 全过（`测试提交守卫.py` 里数 `env=MAIN_COMMIT_ENV` 的断言从 4 改成 5：多了旧交付单冲突按删除后的那次提交）。
- 没跑 `语法检查.py`：本工作树没补齐（没有 Godot 链接），本分支也没改 .gd。

## 本分支提交

- 见 git log
