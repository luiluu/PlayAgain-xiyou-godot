# 交付：cc/platform-gaps1
- 车道／工作者：平台／cc（FB 第十五批）
- 状态：可合并

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】三平台缺口盘点、Windows／安卓发行包验收清单草稿、云端真 Windows 跑发行 exe（dev.待定）

- ① 盘点：[跨平台适配.md](../../03_再刷重制_Godot/00_设计/跨平台适配.md) 加第六节「缺口盘点」，以换源后的 main 为准，把还差的分三类：能自动验证（真 Windows 跑 exe、真安卓系统跑 apk）、只能真机（窗口／全屏／高 DPI／多屏、输入法、手柄、帧率发热、声音、文件选择器）、要 Kyo 定（Windows 代码签名、安卓发行 keystore 与上架、首次启动旧存档提示、长屏 expand、后台真挂机、发布渠道）。11-06 扩展账基线九项现状不变。
- ② 验收清单草稿：新文件 [Windows 发行包验收清单](../Windows发行包验收清单.md)（22 步：exe 与 pck 同目录、`%APPDATA%\KYO\再刷重制` 备份、SmartScreen「仍要运行」、杀软、版本号与文件属性、窗口九成居中、100%／150% 缩放、Alt+回车／F11 三次、Alt+Tab、多屏、闪退复测、键鼠、中文输入法、Xbox 手柄拔插、流程照 Mac 清单 5～16、存档目录不出现 `_开发`、退出无残留进程、崩溃时 godot.log 与事件查看器）、[安卓发行包验收清单](../安卓发行包验收清单.md)（27 步：调试签名包说明、机型、装包、横屏与刘海、闪退复测、长屏黑边、摇杆／确定取消连发／点按与滑动／两指取消／隐藏键／手机按键设置／存档键、返回键两次退出、切后台、切后台被杀后标题「继续」、后台挂机补跑、导出导入存档不要权限与坏文件、流畅与发热、声音被打断后恢复、蓝牙手柄、卸载前导出）。11-06 DP 交付单里那份 8 步安卓真机清单合并时随交付单删掉了，这次重写补全。
- ③ 云端真 Windows（第一批能自动验证的）：`.github/workflows/export-smoke.yml` 的 Windows 那条在 Linux 上另导出「Windows 发行」，经 Actions 缓存（只有本仓库工作流能读，不做附件；跑完删）交给新任务 `windows-run`（windows-latest）。新脚本 `07_开发环境/Windows实机冒烟.py` 在真 Windows 上跑发行 exe：无头进标题（只有 entry.tscn、退出码 0）；照 `发行入口冒烟.py` 的四组按键（空格／J／回车开新游戏、一串确认取消）每组新进程，退出码 0、有 SMOKE_DONE、新游戏几组停在地图，`0xC0000005` 一类退出码记成闪退；存档目录写到临时 `%APPDATA%\KYO\再刷重制`、没有 `_开发`（O-200）；`--try-window` 用 ANGLE 开窗口进一次标题，只提示。每次运行用临时 APPDATA／LOCALAPPDATA。环境登记 cloudExport 加 `windows_release_x86_64.exe` 模板和「Windows 发行」的 release 改写。
- 测试：新 `测试Windows实机冒烟.py` 9 项（假 exe：全过、写进 `_开发` 判失败、按键闪退判失败、标准输出收不到时读 godot.log、缺 pck、不改本进程 APPDATA、按键组／标题／地图与发行入口冒烟一致、存档目录名与 project.godot 一致、Windows 闪退码识别），进 `检查.sh` tools 组和 `工具回归.py`；`测试导出冒烟.py` 的预设改写断言 2→3 处。
- 顺手修：`导出冒烟.py` 的 Windows 版本号检查一直拿导出后的 `0.398.0.0` 去比预设占位 `0.0.0.0`，云端「导出冒烟（windows）」从 dev.385 起每次误报失败；改成 XDesktopVersion 开着时按开发编号比（关着才比预设），`测试导出冒烟.py` 跟着改（占位没被改写仍判失败）。
- 验证：语法检查 0 问题；工具回归全过（81 秒）；云端选测 8f66aaad51 五个场景全过（xiyou_entry_release、xiyou_event_compare、xiyou_pause_save、xiyou_platform、xiyou_ui_input，[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42384993694)）；云端导出冒烟 ci-export/cc/platform-gaps1 三个任务全过（[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42386029067)）。windows-run 首轮（42385139483）真 Windows 上：发行 exe 104 MB＋pck 453 MB，进标题 7 秒、退出码 0，四组按键都到地图、17/17 步，存档写到 `%APPDATA%\KYO\再刷重制`、没有 `_开发`，ANGLE 开窗口也进了标题；传包缓存跑完已删（`gh cache list` 没有 winrel）。

## 2026-11-07 【cc·平台·未经审查】事件里开的战斗不再存开战前检查点：读回自动存档不会「东西扣了、仗没打」（审查第 52 期 P2-1，dev.待定）

- 问题（审查 52 P2-1，来源 cc/platform-fix3）：解释器 301、小猫试炼、真气闭关开打前调 `XAutoSave.battle_checkpoint(host, true)`，存在事件做了一半的时刻；存档不带解释器进度，读回来事件不会重跑。Map207 奇兽地事件 3 先扣奇兽捕捉许可证再打敌群 319，战斗里被杀、从标题「继续」读回来：证没了、仗也没了；Map046、Map147 事件 1 连战中间扣奖碑同理。
- 修法（审查给的二选一里取第二种）：`modes/xiyou/core/auto_save.gd` 加 `XAutoSave.EVENT_BATTLES`（默认 false）：`in_event` 的检查点一律跳过（`skip:in_event`），自动存档留在更早那份（事件开始前，如进主菜单时的检查点、切后台那份）；随机遇敌开战前照旧存。只改 auto_save.gd，三个调用处（`mv_interpreter.gd`、`mv_script.gd`、`zhenqi_retreat.gd`，八戒车道独占）不动。没选「事件开始时拍快照」：要在 run_event 里插钩子、改八戒车道的文件，收益只是事件战斗前多一个存档点。
- 回退：`XAutoSave.EVENT_BATTLES = true`（同 dev.393，事件里开的战斗也存、busy 不算阻挡）。并在优化登记 O-221 行（说明与恢复方法），不另开号。
- 测试 `xiyou_pause_save`：原 event_battle_checkpoint_saves 改成真跑「先扣 100 金、再 301」的事件：开打时 `skip:in_event`、金钱已扣到 400，自动存档里还是事件前的 500（event_battle_no_checkpoint、event_battle_auto_keeps_pre_event）；回退开关打开同一事件，存下的是 400（event_battle_rollback_saves_after_deduct，证明断言咬得住）；in_event_skipped_by_default、event_battles_default_off；in_event_ignores_busy 改在回退开关下测。
- 玩家可见：手机上在事件里开的战斗（奇兽地、连战、小猫试炼、真气闭关）中被系统杀掉，从标题「继续」读回来是事件开始前的进度，扣掉的许可证、奖碑都还在。

## 2026-11-07 【cc·平台·未经审查】安卓后台挂机补跑：开变速齿轮时补够离开的时长（dev.待定）

- 界面车道 FD 发现（cc/ui-gaps1 交付单「可优化」）：`core/platform.gd` 补跑时 `_catch_up_left -= delta`，delta 含变速齿轮的 1.6，开齿轮时只补了离开时长的 1/1.6。改成按平常速度的秒数扣：`delta / 基准倍率`（基准是开始补跑时记下的 time_scale）。没用 FD 的 `XSpeedGear.real_seconds`：那个函数在 cc/ui-gaps1，还没进 main，这里只用补跑自己记的基准，结果一样。
- 测试 `xiyou_platform` 加 catch_up_counts_base_seconds（齿轮 1.6、补 10 秒，一帧 delta＝12.8 只扣 8 秒）。
- 玩家可见：手机开着变速齿轮挂机、切后台再回来，补跑补够离开的时间（以前只补约六成）。

## 交接板
- 下一步：平台第二批——云端 Linux（KVM）起 x86_64 安卓模拟器装 apk 跑入口、返回键、切后台；apk 只有 arm64-v8a，靠镜像的 ARM 转译，不行就云端单独导一份带 x86_64 的冒烟包。
- 用户试玩说明：无（只有工具和文档）。Kyo 有 Windows 机器或安卓手机时照两份新清单点。
- 需要用户决定：无。Kyo 11-07 15:01 定了第六节四项：Windows 不买签名证书、首次启动不提示旧存档、发布＝Kyo 自己发 QQ 群（不上架）、安卓 keystore 正式发布时再定；已写进跨平台适配.md 第六节。

## 进度账
- 扩展账「跨平台（PC／安卓）」：依据加一句「真 Windows 上跑发行 exe 已进云端导出冒烟（windows-run）」，完成度仍交审查核定。

## 可优化（流程／工具／效率）
- 已做：导出冒烟里 Windows 包经 Actions 缓存交给 Windows 机器，不当附件（仓库公开）；回退＝删 windows-run 任务和导出发行包那两步。
- 建议：云端安卓模拟器冒烟（平台下一批，Actions 不限分钟，免得本机重下 2 GB 模拟器）。

## 本分支提交
- db5807bc 缺口盘点、两份验收清单草稿
- 3807506b、ec5a51d0 Windows实机冒烟.py、工作流 windows-run、测试
- 91151942 审查 52 P2-1 事件战斗不存检查点
- 15d7ff87 补跑按平常速度的秒数扣
- ea4de576 记 Kyo 11-07 定的四项
- 8f66aaad 合 main 2443a7b0
- 最后一个：导出冒烟 Windows 版本号按开发编号比
