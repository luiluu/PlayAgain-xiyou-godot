# 交付：claude/nezha-check-tiers-eac2f9-7b

- 车道／工作者：D 检查与合并工具／哪吒（Claude，重制_哪吒_1）
- 状态：可合并

## 变更记录草稿

## 2026-10-26 【Claude·哪吒·未经Codex检验】长任务停组接住 EPERM、同步等探针时打心跳（dev.待定）

- **长任务.py**：新增 `signal_group`：`os.killpg` 抛 `PermissionError`（macOS 上组里有发不了信号的成员时）就退一步逐个给进程表里属于该组的 pid 发信号，发不到的跳过；`stop()` 与失联接管（`recover_abandoned`）都改用它。`stop()` 不再抛异常、等待有上限，包装器随后照常写终态（status、`.exit`、日志末行 `TASK_RESULT`）。起因：悟空 sync11 的包装器在 `killpg` 处崩掉，同步跟着没了，状态文件却还写着 running。
- **同步正式西游.py**：等探针时每 `XIYOU_PROBE_HEARTBEAT` 秒（默认 60，0 关闭）为每个在跑的探针打一行 `PROBE_RUNNING={"probe":…,"command":[…],"seconds":…}`（含等槽时间），`event_probe` 整轮约 100 分钟一行不出也不会被 `长任务.py` 的无输出看门狗（默认 3600 秒）误判卡死。
- 文档：[长任务与增量同步](../../03_再刷重制_Godot/07_开发环境/长任务与增量同步.md)。
- 只改工具，不递增开发编号。（期七另两项 `--close-batch`、生成接受单草稿已随 `claude/nezha-check-tiers-eac2f9-7` 合入。）

## 交接板

- 下一步：无。
- 用户试玩说明：无。

## 验证

- 新增 `测试增量同步.StopAndHeartbeatTests` 3 项：`killpg` 抛 EPERM 时 `stop()` 不抛异常、把忽略 SIGTERM 的进程停掉；同样情况下卡死的任务照写 stuck／124 终态；真实路径（`长任务.py` 看门狗 1.5 秒 → `run_probes` → 3 秒不出声的 node 假探针）有 0.4 秒心跳判完成、日志里有 `PROBE_RUNNING`，关掉心跳同一探针判 124。
- `测试合并工具.py`（含 `测试增量同步.py`）连跑 2 次：146/146、146/146；`测试角色同步提速.py` 通过；`测试选测.py` 24/24。
- 车道不跑全量 `检查.sh`。

## 可优化（流程／工具／效率）

- 已做：见上（回退：`XIYOU_PROBE_HEARTBEAT=0` 关心跳；`signal_group` 退回直接 `killpg` 即原行为）。
- 建议：`等待任务.sh` 打印最后一行 `PROBE_RUNNING`／`等槽` 进度，车道等同步时一眼看到在跑哪个探针、跑了多久（收益小，归车道 D）。

## 本分支提交

- 见 `git log main..claude/nezha-check-tiers-eac2f9-7b`
