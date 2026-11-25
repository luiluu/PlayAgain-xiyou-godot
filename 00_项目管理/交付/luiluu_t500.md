# 交付：luiluu/t500

- 车道／工作者：T500 加急排查与修复／小A（Neon＋high，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【小A·T500·未经审查】根治跨底包升级残留 active.json 卡 0.485 死循环与换整包版本误算（dev.待定）

- 原因核实：老玩家此前在旧底包（如 v0.01/v0.03 补丁线底包 `477`，或 `470`/`473`/`480`/`482` 等任意旧底包）装过热更后，共享用户目录 `user://updates/active.json`（Windows 发行包为 `%APPDATA%\KYO\再刷重制\updates\active.json`）残留 `base=477, code=485, confirmed=true`。换装 v0.04（`base=889`）后，`03_再刷重制_Godot/01_Godot工程/core/boot_patch.gd:122-124` 检测到「底包不符」仅返回 `loaded=false` 不清理；`03_再刷重制_Godot/01_Godot工程/core/update_install.gd:327-336` 的 `registered_code()`/`pending_code()` 不校验底包直接返回 `485`；`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/update_page.gd:374-380` 见 `pending > 0` 跳过联网直接弹「新版本 0.485 已下载……立即重启」（`core/update_check.gd:68-70` 因 `485 < 889` 回退为 `0.485`），且因 `loaded=false` 隐藏「退回安装包自带版本」按钮，导致重启死循环。另总装实测发现两条同源问题：`register()` 写 `prev` 未校验底包会把 `477/485` 带进新底包 `prev`；`evaluate()` 在 `state==FULL`（换整包）时按旧底包 `release_base` 换算版本号，把 `892` 算成 `0.01.415`。
- 改动（仅西游档发行自动更新逻辑，天启篇无关）：
  - `03_再刷重制_Godot/01_Godot工程/core/boot_patch.gd`：`prepare()` 遇到旧底包残留跳过不误写 `rolled_back.json`；`apply()` 检测到「底包不符」时调用 `_cleanup_stale_base()` 清理过期 `active.json` 与 `patch_<非本底包>_*.pck/.part/.chunk`（保留当前底包补丁、存档与 `save_backup`）。
  - `03_再刷重制_Godot/01_Godot工程/core/update_install.gd`：`registered_code(expected_base)` 与 `pending_code(expected_base)` 校验 `cur.base == 当前底包`，不符当 `0` 并自动清理过期 `active.json` 与旧底包补丁，且对 `confirmed=true` 但本次启动未载入的失效登记自动清掉防卡死；`register()` 写入 `prev`（含 `elif` 继承分支）仅保留 `base == 当前 base` 的记录；`rollback()` 拒绝恢复异底包 `prev`，底包不符直接退回底包自带内容。
  - `03_再刷重制_Godot/01_Godot工程/core/update_check.gd`：`evaluate()` 在 `state == FULL`（要换整包）时直接使用清单 `latest.version`（非空时），不再用当前旧底包的 `release_base` 调 `version_of(code)` 换算。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/update_page.gd`：`_ready()` 与 `show_forced()` 显式传 `XUpdateClient.base_code()` 查询 `pending_code`，只认当前底包的待重启补丁。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_boot_patch.gd`、`tests/xiyou_update_install.gd`、`tests/xiyou_update_check.gd`：补 477/485 残留、470/475 与 482/485 等其他旧底包残留、更新页不卡 0.485、`register`/`rollback` 跨底包隔离、正常当前底包连续更新（889→891→892 同构流程）不受影响，以及 `477` 底包遇 `892`（`0.04.03`）换整包正确显示 `0.04.03` 等专项用例。
- 生效边界与已卡死玩家处理：
  - **热更（`.pck` 补丁）可生效**：`core/update_install.gd`、`core/update_check.gd`、`modes/xiyou/ui/update_page.gd`（保护已装上新补丁的客户端后续不再污染 `prev`、不再误算换整包版本号、不再被异常登记锁死）。
  - **仅新整包可生效**：`core/boot_patch.gd`（首个 autoload，在 `load_resource_pack` 之前运行，热更补丁无法替换已发出的 889 底包内嵌脚本）。
  - **已卡死在 0.485 的 v0.04（889）玩家**：因旧客户端点「检查更新」直接短路不联网，普通非强制热更无法覆盖，需二选一：① 手动删除 `%APPDATA%\KYO\再刷重制\updates\active.json`（macOS 为 `~/Library/Application Support/KYO/再刷重制/updates/active.json`；不动上一级 `modes` 存档目录）后重开检查更新；② 换装含本次 `boot_patch.gd` 修复的新整包。（另已实测验证一条线上备选通路：若清单设 `min_playable >= 891/892`，已发 889 客户端走强制更新 `show_forced()` 因 `485 < min_playable` 可绕过死锁并覆写 `active.json`，代价是同步强拦停在老底包 477 的玩家，是否采用由 Kyo 决定。）
- 玩家可见：修复旧版本玩家换装新整包后点击「检查更新」反复提示旧补丁（如 0.485）且重启无效的问题，并修复旧整包提示换新整包时目标版本号显示异常的问题。
- 验证：
  - 本机专项（`--headless --audio-driver Dummy`）：`xiyou_boot_patch.tscn` 23/23、`xiyou_update_install.tscn` 64/64、`xiyou_update_check.tscn` 95/95、`xiyou_force_update.tscn` 55/55、`xiyou_t369_update_skin.tscn` 60/60。
  - `发行空壳.py check`：退出码 0（84 个脚本，825 个函数都有）。
  - `语法检查.py`：退出码 0（1225 个 `.gd`，0 个问题）。
  - 云端选测：通过（提交 `d668f2dbdc`，整轮 811 个场景、16 片，最长一片 21.4 分钟；1 个已知并行偶发 `xiyou_tianqi_gear_params.tscn` 单跑通过算通过；运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45601667933）。

## 交接板

- 下一步：
  - 已卡死在 0.485 的 PC v0.04 玩家发群自救步骤（删 `%APPDATA%\KYO\再刷重制\updates\active.json`，不动 `modes` 存档目录），或随下次整包一并根治。
  - 后续出补丁可将本分支合入补丁线（生效 `update_install.gd`、`update_check.gd`、`update_page.gd`），下次整包自动带入 `boot_patch.gd`。
- 用户试玩说明：旧版换装新整包后不再卡在旧补丁（如 0.485）重启死循环，换整包提示的版本号直接显示新整包版本名。
- 需要用户决定：是否通过线上清单设置 `min_playable`（如 `892`）远程解救已卡死的 v0.04（889）老玩家（代价：同时强拦仍停在老底包 477 的玩家）；不设则维持公告删 `active.json` 自救或等下次整包。

## 进度账

- 无（自动更新线上缺陷根治，不改动重制/天启篇进度百分比）

## 可优化（流程／工具／效率）

- 建议：监控长耗时云端整轮（15~20 分钟）时，`gh run watch` 默认每 3 秒调用一次 REST API 容易触发 403 限流；`云端选测.py wait <sha>` 走 `git ls-remote` 不耗 API 限额，建议在车道模板中允许 `gh run watch` 撞 403 时无缝转 `云端选测.py wait`（归流程规则维护）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `BootPatch.prepare` | 12 处（`git grep -nE '(BootPatchScript\.prepare|^\tprepare)[[:space:]]*\(' -- '*.gd'`） | 调用方 12 处逐处结论：`core/boot_patch.gd:31` 启动自调；`tests/xiyou_boot_patch.gd:90` 新增旧底包残留用例；`tests/xiyou_update_install.gd` 共 10 处均在同底包下验证启动计数与自动退回，同底包路径行为完全不变，仅跳过旧底包残留避免误写退回提示。 |
| `BootPatch.apply` | 12 处（`git grep -nE '(BootPatchScript\.apply|result = apply)[[:space:]]*\(' -- '*.gd'`） | 调用方 12 处逐处结论：`core/boot_patch.gd:32` 启动自调；`tests/xiyou_boot_patch.gd` 共 11 处。仅在「底包不符」分支增加清理过期 `active.json` 与 `patch_<非本底包>_*.pck/.part/.chunk`，不影响测试夹具 `p.pck` 与同底包载入分支。 |
| `XUpdateInstall.register` | 11 处（`git grep -nE 'XUpdateInstall\.register[[:space:]]*\(' -- '*.gd'`） | 调用方 11 处逐处结论：`modes/xiyou/ui/update_page.gd:867` 安装登记；`tests/xiyou_update_install.gd` 共 10 处。新增 `cur.base == base` 约束仅拦截跨底包污染 `prev`，同底包连续登记与保留上一份行为不变。 |
| `XUpdateInstall.registered_code` | 2 处（`git grep -nE '[^[:alnum:]_]registered_code[[:space:]]*\(' -- '*.gd'`，不含定义） | 调用方 2 处逐处结论：`core/update_install.gd:354`（`pending_code` 内部调用）与 `tests/xiyou_update_install.gd:394`。新增默认参数 `expected_base := -1` 向后兼容，底包不符返回 0 并清理残留。 |
| `XUpdateInstall.pending_code` | 13 处（`git grep -nE 'XUpdateInstall\.pending_code[[:space:]]*\(' -- '*.gd'`） | 调用方 13 处逐处结论：`core/update_client.gd:116`（撤回判断）、`modes/xiyou/ui/update_page.gd:374,405`（更新页与强制更新页）、`tests/xiyou_force_update.gd:266`、`tests/xiyou_update_install.gd` 9 处。新增默认参数 `expected_base := -1` 向后兼容，所有调用处均期望只识别当前底包未生效的新补丁。 |
| `XUpdateInstall.rollback` | 10 处（`git grep -nE 'XUpdateInstall\.rollback[[:space:]]*\(' -- '*.gd'`） | 调用方 10 处逐处结论：`core/update_client.gd:117`、`modes/xiyou/ui/update_page.gd:396,898`、`tests/xiyou_update_install.gd` 7 处。仅在 `rollback(false)` 恢复 `prev` 前增加同底包校验，防止被污染的异底包 `prev` 写回 `active.json`，同底包退回和 `rollback(true)` 不受影响。 |
| `XUpdateCheck.evaluate` | 30 处（`git grep -nE '(XUpdateCheck|C)\.evaluate[[:space:]]*\(' -- '*.gd'`） | 调用方 30 处逐处结论：`core/update_client.gd:114` 线上唯一业务调用、`tests/xiyou_force_update.gd` 12 处、`tests/xiyou_update_check.gd` 17 处。仅修改 `state == FULL` 时 `out["version"]` 直接取清单 `latest.version`，`PATCH` 与 `LATEST` 分支保持原逻辑，全部专项与云端 811 场景通过。 |

## 本分支提交

- `27ab3932a` T500：根治跨底包升级残留 active.json 导致检查更新卡死 0.485 死循环
- `d668f2dbd` T500：state==FULL 换整包提示直接读取清单 latest.version，避免旧底包算出 0.01.415
