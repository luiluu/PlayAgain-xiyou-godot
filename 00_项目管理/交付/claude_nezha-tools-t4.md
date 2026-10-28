# 交付：claude/nezha-tools-t4

- 车道／工作者：D 工具／哪吒_7（Claude）
- 状态：可合并

## 变更记录草稿

## 2026-10-28 【Claude·哪吒·未经Codex检验】合并与测试工具五个坑（dev.待定）

背景：总装 10-28 合并时踩的坑，每个至少白跑一轮 50～90 分钟检查或要手改状态。分期做，每期单独可验收。

- **第 1 项 失败明细收尾单列**：`并行测试.py` 原本已有默认日志目录（`04_验证/本地结果/并行测试/<时间戳>/`）和逐场景「完整输出」路径，但它们夹在几百行进度与通过行中间，长任务日志里找不到。现在最后两类行固定是「✗ 失败场景 N 个：」和逐个「场景 → 日志」，`test_timings.json` 加 `failed`；设了 `CHECK_FAILED_FILE` 时写同样内容（每行「场景<Tab>日志」，全过时清空）。`检查.sh` 每个 `bad` 项和文档登记失败都记进 `FAIL_ITEMS`，Godot 失败按场景带日志路径展开，在 `== Git` 前打「== 失败项汇总（N 项）」；没写出场景（如崩在启动）仍列一项指向上方段落。只加收尾汇总，不改检查顺序与判定。`测试合并工具.py` 收尾每个失败用例另打 `FAILED_CASE=<id>`，并支持按名字片段只跑部分用例（第 4 项前半）。
- **第 2 项 重启残留锁自动作废**：`合并车道.py` 的 `running.lock` 改由 `take_lock` 拿，写入持锁进程 pid 与启动时间（`ps lstart`）。已有锁时：持有者在且启动时间对得上 → 照旧拒绝并报 pid；pid 已不在、或被别的进程复用（启动时间对不上）→ 作废重拿并打提示，state.json 等现场照旧接续；旧版空锁或认不出的内容早于本次开机（`sysctl kern.boottime`）的作废，开机后留下的认不出持有者、照旧拒绝并写明怎么确认。判定与替换在 `lock.guard` 的 flock 里做。只删自己拿到的锁。
- **第 3 项 旧交付单不再误判为附带交付单**：根因是交叉合并——八戒 attack-query2 从期一交付点切出、又合过 main，与 main 有两个合并基点（期一 f7eb5154 与 ce-fix2 db2d86b8），`git merge-base` 取到旧的那个，diff 带出期一与星级仓库交付单。现在 plan 里凡是 main 历史里删过、main 现在没有的交付单都不算附带交付单；车道上的版本与删前不同时打提示（补写内容请写进本期交付单）。拿真实历史核过：17ae102f 那次两张都会被跳过。
- **第 4 项 合并工具自测负载偶发**：先让 `测试合并工具.py` 收尾每个失败用例打 `FAILED_CASE=<id>`、可按名字片段选跑（随第 1 项提交）；再在负载 14～27 下多轮跑（槽位／并行测试类 18 轮、全量 3 路并发两次、SlotWeightTests 3 路×5 轮）抓到两项：
  - `test_queue_lets_other_process_in_while_batch_hogs_slots`：断言「不排队时来者等 >3 秒」本身是竞速（放槽与重抢谁先到），负载约 23 时实测 1.51 秒；哪吒_6 交付时负载约 16 下 171/172 推断就是它（当时没抓到名字）。改成 hog 用 Barrier 真占满所有槽才放来者（原来固定 sleep 0.5，负载高时 hog 还没起来），旧行为只打印对照不断言；排队后的上限 1.5 秒照旧断言（负载 27 下恒为 0.51 秒）。
  - `test_slot_cli_runs_command_and_sends_heartbeat_to_notice_fd`：固定等 0.8 秒就放槽，负载约 27 时子进程还没开始等槽，6 轮错 2 轮；改成读到「等槽」心跳行再放（最多 30 秒）。
  - 改后负载 17～27：全量 177/177、SlotWeightTests 15 轮全过。
- **第 5 项 单条 `--abort`**：main 上已有（17712cbf）。核过：`undo_sync` 按同步前备份还原 oracle／db／maps／manifest.json／slice.json、删 sync_stamp.json，并删本产物目录的同步基线（`04_验证/本地结果/同步基线/<产物目录 sha256>*`），下一次同步按还原后的产物重建；夹具 `test_single_abort_restores_main_generated_and_baseline` 正是 10-27 common_scripts.json 残余的场景，已断言基线目录清空。不用再做。

## 交接板

- 下一步：无新增（工具车道 D 本期五项收尾；第 5 项原已在 main）
- 用户试玩说明：无（只改合并与测试工具）
- 需要用户决定：无

## 进度账

- 无（工具）

## 验证

- RED→GREEN 用例：第 1 项 `test_failure_summary_is_last_and_written_for_checker`（测试合并工具）、`test_failure_summary_lists_scenes_with_logs`（测试选测，用真实 检查.sh＋替身）；第 2 项 `test_stale_lock_from_dead_runner_is_discarded`、`test_live_lock_still_refuses`、`test_empty_lock_older_than_boot_is_discarded`；第 3 项 `test_old_sheet_already_merged_is_not_extra_delivery`（交叉合并夹具，断言确有两个合并基点）。RED 均用改前版本实跑确认失败。
- 第 3 项另用真实历史核过：17ae102f（attack-query2）时两张旧交付单都会被跳过。
- 合 main（fd00ec47）后：`测试合并工具.py`（含增量同步）、`测试选测.py` 全过，合 main 后（负载约 18）：测试合并工具 177/177、测试选测 46/46；--补齐 完成。没跑 Godot 场景（未改游戏代码与测试场景），没跑全量 检查.sh（车道规则）。
- 改到 `检查.sh`：只在 `== Git` 前加「失败项汇总」，`bad` 多记一项，并行测试多传 `CHECK_FAILED_FILE`；检查顺序、判定、退出码不变，同步产物格式没动。

## 待交叉核查

- `合并车道.py`：`take_lock`（pid 复用判定、开机时刻判空锁、lock.guard 互斥）、plan 跳过 main 删过的交付单（只认 main 现在没有的；车道改过的只提示不并入）。
- `检查.sh` 失败项汇总；`并行测试.py` 收尾两类行与 `CHECK_FAILED_FILE`。

## 可优化（流程／工具／效率）

- 已做：合并锁失效自动作废（回退：take_lock 改回 O_EXCL 直建）；自测按名字选跑与 FAILED_CASE 行（回退：删 main 末尾那段）。
- 建议：SlotWeightTests 里 `test_stale_queue_ticket_is_ignored_and_removed` 仍断言 0.4 秒内拿到槽，本轮高负载没掉，若再掉就同样改成等状态（工具车道）。

## 本分支提交

- 23568e7d 第 1 项：失败场景与日志收尾单列、检查.sh 汇总、自测 FAILED_CASE 与选跑
- ec74ddc0 第 2、3 项：合并锁失效自动作废；旧交付单不算附带交付单
- 85aef9b8 合并提速工具.md 写明
- 7a2b483b 第 5 项核过（交付单）
- 22dda74a 第 4 项：负载偶发两项改成等真实状态
- 5cb71739 合 main（fd00ec47）
