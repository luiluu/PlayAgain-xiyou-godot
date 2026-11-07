# 交付：cc/nezha-tools82

- 车道／工作者：工具／哪吒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：main 02a1798c（合并 tools81 之后）。没改共用文件。

## 变更记录草稿

## 2026-11-07 【cc·哪吒·未经审查】长任务 launchd 在 ~/Documents 下起不来：stderr 改落临时目录，起不来时退回子进程（dev.待定）

- **原因查清了**：不是 python 没有隐私权限，是 launchd 自己打不开作业的 stderr 文件。tools81 的 start 先在日志旁边建好空的 `<日志>.start.err`，再把它设成作业的 StandardErrorPath。日志在 ~/Documents 下时，launchd 打开 Documents 里已存在的文件被隐私保护拦下。系统日志原文是 `Service could not initialize: Unable to open stderr path (…/t82x.err), error 0x1 - Operation not permitted`，作业 last exit code 是 `78: EX_CONFIG`。又因为设了 LaunchOnlyOnce，失败的作业立刻被移除，start 只看到「作业没了」，err 是空的。对照实验：同一个已存在的 err 文件放在 /private/tmp 能起来；不预先建、由 launchd 自己新建（哪怕在 Documents 里）也能起来；launchd 起的 python 读、列、写 Documents 都正常。所以这台机器不用给任何可执行文件授权，也不需要换 `launchctl asuser`（那要 root）。
- **改法**（`07_开发环境/长任务.py`）：
  - 作业的 stderr 落在每用户临时目录（`$TMPDIR/<作业名>.err`，不受隐私保护）。run 起来后用 dup2 把 stderr 接回 `<日志>.start.err`，再删掉临时文件。
  - 去掉 LaunchOnlyOnce，起不来的作业会留下来，start 能读到 last exit code 再卸掉。
  - 作业没写出本轮状态就结束（或登记 5 秒还没起来）时，start 打印「launchd 作业没写出状态就结束（last exit code…；作业 stderr；EX_CONFIG 时附一句常见原因），退回子进程方式」，再用 start_new_session 子进程重起一次，照常等状态。退回后 run 自己报的错（比如同一日志已有任务在跑）照样报出来。
  - 清扫旧作业时一并删掉临时 err。
- **新测试**（`测试增量同步.py`，都在本工作树也就是 ~/Documents 下跑）：
  - `test_start_with_log_under_documents_uses_launchd`：日志在 Documents 下，launchd 起得来，没有退回，状态里有 launchdLabel，任务的 stderr 进了日志。tools81 的版本在这种路径下就是总装报的「任务未能启动：」、返回 2（开工时用 main 复现过）。
  - `test_launchd_job_that_vanishes_falls_back_to_subprocess`：真实的 launchd 作业，只是换成一个一起来就报错退出的程序。start 打印原因（`last exit code = 3`，作业 stderr），退回子进程，任务跑完，状态里没有 launchdLabel。
  - 说明：Documents 下 EX_CONFIG 那种失败本机能复现（单跑 5 次都复现），但放在整套测试里跑过一次没复现，launchd 那次打开了文件。隐私拦截看起来时有时无，所以固定用例改用上面这种稳定的失败；Documents 那种我手工复现过，系统日志原文见上。

## 交接板

- 下一步：本分支合并后，起长任务不用再加 `XIYOU_LONG_TASK_LAUNCHD=0`。要是以后在别的机器上碰到 launchd 起的 python 没有 Documents 权限，start 会自动退回子进程并打印原因，不会卡住。
- 需要用户决定：无。不用 Kyo 授权任何东西。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：上面的退回机制（回退开关仍是 `XIYOU_LONG_TASK_LAUNCHD=0`）。

## 验证

- 工具专项：`测试增量同步.py` 73 项全过（含两个新用例，没有跳过）。
- `工具回归.py` 全过。
- 手动：本工作树日志路径 `start` → `wait` 返回 0，状态带 launchdLabel，stderr 接回日志。

## 本分支提交

- 见 git log（cc/nezha-tools82）
