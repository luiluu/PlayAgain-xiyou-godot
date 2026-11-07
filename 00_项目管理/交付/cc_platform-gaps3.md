# 交付：cc/platform-gaps3
- 车道／工作者：平台／cc（FB 第三单，接在 cc/platform-gaps2 之后切出；含 gaps1、gaps2）
- 状态：可合并

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】模拟器里也跑四组按键冒烟：启动参数写进 apk 副本（dev.待定）

- 查清原因：Godot 4.7.2 的 `GodotActivity.kt` 对导出的 Activity（桌面图标那个 `GodotAppLauncher`）一律删掉 intent 带的 `command_line_params`，只认不导出的 `GodotApp`，外部（adb）又起不了它。这是引擎防外部程序控制的设计，所以二批 `am start --esa` 传的 `--report-entry` 没生效。
- 改法：引擎另从 apk 的 `assets/_cl_` 读启动参数（`CommandLineFileParser`：小端 int32 个数，每个参数小端 int32 长度＋UTF-8）。`安卓实机冒烟.py` 复制发行包，把 `_cl_` 换成 `-- --report-entry`（基础那轮）或 `-- --report-entry --smoke-keys=<序列>`（四组按键各一个），去掉旧签名，`zipalign`＋`apksigner` 用现生成的一次性 keystore 重签（只给模拟器，原包不动，跑完删副本）。按键组同 `发行入口冒烟.py` 的 KEY_RUNS：清数据、启动、等 logcat 里的 SMOKE_DONE（游戏按完自己退出），新游戏三组要停在地图，logcat 无本包崩溃行。拿不到 build-tools 或 keytool 时退回原包，ENTRY_SCENE 只记 INFO、跳过按键组。
- 测试：`测试安卓实机冒烟.py` 7→12 项（`_cl_` 编解码与改写不留旧签名、重签后 ENTRY_SCENE 和四组都到 SMOKE_DONE、某组闪退判失败、不重签时 ENTRY_SCENE 只记 INFO、按键组与发行入口冒烟一致）。
- 验证：工具回归全过；云端导出冒烟 ci-export/cc/platform-gaps3 四个任务全过（[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42389133858)）：安卓模拟器 12 项全 PASS——进标题（ENTRY_SCENE 对上）、返回键、回车新游戏、切后台同一进程、无崩溃，四组按键空格／J／回车各 1/1 步到地图、长串 17/17 步到地图；windows-run 也全过；传包缓存跑完都删了。没改 Godot 代码。

## 交接板
- 下一步：无（平台自动冒烟三平台都在真系统上了：Mac 本机、Windows 和安卓在云端）。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账
- 扩展账「跨平台（PC／安卓）」：依据补「安卓模拟器上跑发行包四组按键冒烟」。

## 可优化（流程／工具／效率）
- 无

## 本分支提交
- 安卓实机冒烟 _cl_ 重签与按键组、本交付单
