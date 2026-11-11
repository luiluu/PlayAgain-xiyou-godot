# 交付：cc/update-install1

- 车道／工作者：自动更新（工具与平台）／cc（update-install1）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·update-install1·未经审查】自动更新第②批：补丁下载（多源、断点续传、校验）、登记、存档备份、启动失败自动退回、手动退回（dev.待定）

- 背景：方案 v0.2 第 3.3、3.4 节。本分支叠在 `cc/update-release1` 上，合并顺序：spike0 → check1 → release1 → install1。
- 做了什么：
  - `core/update_install.gd`（`XUpdateInstall`）：
    - 下载：依次试清单里的每个地址，边收边写文件。已下的字节留在 `.part`，重试、换地址、下次再点都带 `Range` 接着下；续传到一半又断线，那一截也留着。服务器不认 `Range` 就整份换上；404、占位页（200 但字节数不对）跳到下一个地址；跟随 302 跳转（Gitee 的 raw 地址会跳到带签名参数的地址），不从 https 降到 http。下完比字节数和 SHA-256，对上才改名成正式文件；内容不对删掉重来一次，再不对换地址。30 秒没有新字节算超时。可取消。
    - 登记：先把存档目录 `user://modes` 整个备份到 `user://updates/save_backup/`（留最近 3 份），备份失败就不登记；再写 `active.json`（未确认、上一份记在 `prev`），清掉用不到的旧补丁文件。
    - 退回：`rollback()` 回上一份或安装包自带内容，下次启动生效。
  - `core/boot_patch.gd`：加启动计数。新装的补丁每次启动计一次，主循环带着场景跑满 180 帧算启动成功（之后不再计数）；连续 2 次没成功，第 3 次启动前自动退回上一份（没有就退回安装包自带内容），留一条提示。
  - `modes/xiyou/ui/update_page.gd`：有补丁时「立即更新」→ 下载中（进度、可取消）→「更新已准备好，重启后生效」（桌面端「立即重启」自动重开，安卓「退出游戏」）；下载没完成给「再试一次」；已下好没重启时再打开直接显示已准备好。正在用补丁时页面下方有「退回安装包自带版本」（点两次才执行）。被自动退回或版本被撤回时在页面上说明。
  - `core/update_client.gd`：静默检查发现当前补丁在撤回名单里，直接退回上一份。
  - 为什么不用引擎自带的 `HTTPRequest.download_file`：实测断线时它把没下完的文件清掉，续不了；所以下载用 `HTTPClient` 自己写文件（读清单仍用 `HTTPRequest`）。
- 验证：
  - `tests/xiyou_update_install`（49 项，进程内的小 HTTP 服务器，不连外网，存档备份用假目录）：正常下载、已有文件不重下、断线后换地址续传、下不完留 `.part` 下次接着下、续传中又断线、取消、不认 Range、占位页和 404、302 跳转、已下内容损坏、SHA 与清单不符、开关；页面走一遍「立即更新→下载→备份→登记→已准备好」；存档备份只留 3 份且不动原存档；登记、待生效、启动计数、两次失败退回（到自带内容／到上一份）、确认后不再计数、手动退回、旧文件清理。
  - `xiyou_update_check` 54 项、`xiyou_boot_patch` 20 项照过。
  - `补丁叠加验证.py` 加两次运行（共六次，全过）：发行模板里新装未确认的补丁跑起来后登记自动变成已确认；登记成「已连续两次没起来」时启动前自动退回、照常进标题。
  - 手动用真 HTTPS 下了一个公开的小文件（Gitee raw，经 302 跳转，第一个地址故意给 404）：字节数与 SHA 对上。
  - `xiyou_entry_release`、`ui_smoke`、`xiyou_key_smoke`、`xiyou_platform`、`xiyou_determinism` 全过；`工具回归.py`、`语法检查.py` 通过。
- 没做、没验的：
  - 「启动成功」的判据是跑满 180 帧，**补丁让画面坏了但没崩的情况认不出来**，要靠撤回名单或玩家手动退回；想更准要在 `entry.gd` 进标题时确认（会和标题界面那个 PR 的接线撞，留到接线时一起改）。
  - 安卓「只在 Wi-Fi 下自动续传、流量下先问」没做（引擎拿不到网络类型，要改安卓插件）。下载都是玩家点了才开始，不会自己走流量。
  - 回退后存档比程序新的提示没做（要看存档里有没有版本字段，另起一批）。
  - 真 Windows、真安卓上没跑（第④批、第⑤批）；真补丁大小的下载没在慢网络下试过。
- 待交叉核查：`core/update_install.gd`（存档备份与文件删除，按甲档看；重点是 `_prune`、`_remove_dir` 只动 `user://updates/` 里的东西）、`core/boot_patch.gd` 的 `prepare`／`confirm`（每次启动都跑）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 重制行为 | 理由 | 回退方式 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·补丁下载 | `core/update_install.gd` `XUpdateInstall.ENABLED`；`core/boot_patch.gd` `prepare`／`confirm`；`modes/xiyou/ui/update_page.gd` | MOD 下载内容包后退出游戏、由安装器替换安装目录文件（Windows 上坏过两轮） | 游戏内下载补丁到用户目录，续传、校验、备份存档后登记，重启生效；启动失败自动退回 | Kyo 2026-11-11 批准自动更新开工；不写安装目录，三平台一套代码 | `XUpdateInstall.ENABLED = false` 检查更新页只提示去 QQ 群；`boot_patch.gd` 的 `enabled = false` 不认任何补丁 | cc（update-install1） | 保留 |

## 交接板

- 下一步：标题界面接线时（PR #29），除 check1 交付单写的三处外，建议在进标题处加一行 `XUpdateInstall.BootPatchScript.confirm(XUpdateInstall.state_path())` 之类的「到了标题才算启动成功」，并把 `boot_patch.gd` 里按帧数确认去掉（要不要改由接线的人定）。
- 下一步：第④批云端真 Windows、安卓模拟器上跑补丁载入；第⑤批实机（先不做）。
- 用户试玩说明：本批玩家仍看不到变化（按钮没接线，线上也还没有清单）。
- 需要用户决定：无。

## 进度账

- Windows／安卓扩展账：自动更新 约 50% → 约 80%（下载、登记、退回完成；剩真系统验证、标题接线、第一次真发版）。

## 可优化（流程／工具／效率）

- 已做：`补丁叠加验证.py` 增加启动确认与自动退回两次运行（回退：删掉 e、f 两段）。
- 建议：`选测对照.json` 的 `update` 组加上 `core/update_install.gd` → `xiyou_update_install`（同 check1 交付单的建议，归工具车道）。

## 本分支提交

- （见 git log cc/update-release1..cc/update-install1）
