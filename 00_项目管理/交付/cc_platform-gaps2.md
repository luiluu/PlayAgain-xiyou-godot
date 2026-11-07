# 交付：cc/platform-gaps2
- 车道／工作者：平台／cc（FB 第二批，接在 cc/platform-gaps1 之后切出；先合 gaps1 再合这条）
- 状态：可合并

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】云端安卓模拟器装发行包跑：返回键、新游戏、切后台都在真安卓系统上验了（dev.待定）

- Kyo 11-07 15:33：本机不起安卓模拟器，云端可以。`.github/workflows/export-smoke.yml` 的安卓那条另导出「安卓 发行」：CI 检出副本里只把这一档的 `architectures/x86_64` 打开（正式预设仍只有 arm64-v8a；模拟器用 x86_64 库，不靠 ARM 转译），拿那次运行现生成的一次性调试 keystore 当发行 keystore 签名（只给冒烟，不发布、不留附件），经 Actions 缓存交给新任务 `android-run`：ubuntu 开 KVM，`reactivecircus/android-emulator-runner@v2` 起安卓 14（API 34，google_apis，x86_64，swiftshader），跑新脚本 `07_开发环境/安卓实机冒烟.py`，跑完删缓存。环境登记 cloudExport 加 `android_release.apk` 模板和「安卓 发行」的 release 改写。
- `安卓实机冒烟.py` 查的：装包、清数据；启动 25 秒后活着；logcat 里有 ENTRY_SCENE 就核对是西游标题（启动参数走 intent 的 command_line_params，云端首轮没看到，只记 INFO）；标题按一次返回键还在、两秒内再按一次退出（O-202）；重开后按回车开新游戏（11-06 发行版闪退那条路）10 秒后活着；按 HOME 切后台 5 秒再拉起来是同一个进程；全程 logcat 里本包没有 FATAL EXCEPTION／Fatal signal／SIGSEGV／SIGABRT／ANR。只认 `emulator-*`，连着真机也不装。
- 测试：新 `测试安卓实机冒烟.py` 7 项（假 adb：全过、回车后闪退判两项失败、回前台换了进程判失败、按两次返回不退出判失败、只连真机时一条装机命令都不发、崩溃行按 pid 和包名认、包名与预设一致），进 `检查.sh` tools 组和 `工具回归.py`；`测试导出冒烟.py` 预设改写断言 3→4 处。
- 文档：两份验收清单的「自动部分」、跨平台适配.md 第六节两行改成已做。
- 验证：工具回归全过（66 秒）；云端导出冒烟 ci-export/cc/platform-gaps2 四个任务全过（[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42387331878)）：安卓发行包含 arm64-v8a 和 x86_64 两套库，模拟器上 7 项 PASS、ENTRY_SCENE 一项 INFO；windows-run 同一轮再次全过；两份传包缓存跑完都删了（`gh cache list` 没有）。没改 Godot 代码，不用跑 Godot 场景。

## 交接板
- 下一步：（可选）弄清 Godot 安卓怎么收启动参数，让 logcat 里能看到 ENTRY_SCENE、能在模拟器里跑 `--smoke-keys` 那四组按键；平台车道下一单。
- 用户试玩说明：无（只有工具）。
- 需要用户决定：无

## 进度账
- 扩展账「跨平台（PC／安卓）」：依据加一句「真安卓系统（云端 x86_64 模拟器）上装发行包跑已进导出冒烟（android-run）」，完成度交审查核定。

## 可优化（流程／工具／效率）
- 已做：安卓真系统冒烟放云端（Actions 不限分钟），本机不用重下 2 GB 模拟器；回退＝删 android-run 任务和导出安卓发行包那两步。
- 建议：导出冒烟现在一次跑四个任务约 10 分钟，只想看一个平台时用 workflow_dispatch 选 windows／android（已支持）。

## 本分支提交
- f0b99fd9 安卓实机冒烟.py、android-run、测试
- 最后一个：文档改成已做、本交付单
