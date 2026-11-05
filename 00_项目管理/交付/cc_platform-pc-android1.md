# 交付：cc/platform-pc-android1

- 车道／工作者：跨平台（工具＋导出）／BA（cc，第九批 BA）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·BA·未经审查】跨平台盘点＋Windows 一期（dev.待定）

- 盘点：只读解开原版 v0.62.09 二合一 apk，对照重制写了盘点表（平台判断、存档位置、窗口、全屏、按键、触屏、返回键、切后台、音频、字体、性能、权限、导出）和安卓二期设计，见 [跨平台适配](../../03_再刷重制_Godot/00_设计/跨平台适配.md)。重制里写死 Mac 的只有全屏组合键两处；`user://` 由 Godot 自动按平台放（Windows 是 `%APPDATA%\KYO\再刷重制_开发`）。
- `export_presets.cfg` 加「Windows 验收」（调试、带 tests/、带控制台包装 exe）、「Windows 发行」（排除 tests/），x86_64，exe 旁放同名 .pck，不签名；用已装的 4.7.2 Windows 模板。`测试导出过滤.py` 加上这两档。
- 全屏组合键按平台：`core/window_fit.gd` 新增 `fullscreen_uses_meta`（static var，默认 `OS.has_feature("macos")`）、`fullscreen_modifier_key()`、`fullscreen_modifier_held()`；macOS 照旧 ⌘Enter，Windows／其它 Alt+Enter，F11 都认。`mv_player.gd` 排除确定键改用 `fullscreen_modifier_held()`。`ui_smoke`、`xiyou_flow` 两种写法都测（不依赖测试机平台，云端 Linux 也成立）。
- `导出冒烟.py --platform windows`：导出「Windows 验收」→ 只读查 PE 头（x86_64、图形界面）、.pck 文件头、控制台包装 exe → 把 .pck 硬链接到 macOS 调试模板旁（同名；导出模板编译时关了 `--main-pack`）在隔离 HOME 里跑 `xiyou_mac_export`、`xiyou_flow`。本机不跑 exe。`测试导出冒烟.py` 加 4 个离线用例。
- 下载：JDK 17、安卓命令行工具这轮没下成（本机自动权限拦了 curl 下载），安卓预设和触屏是二期，不受影响。

## 交接板

- 下一步：Windows 实机验收（exe 启动、高 DPI、Alt+Enter／F11、中文输入法、存档目录、杀毒与 SmartScreen），没有 Windows 机器时先挂着；安卓二期等 JDK＋安卓工具到位后派（设计见跨平台适配第四节）。
- 用户试玩说明：Mac 上没有变化（⌘Enter 照旧）；新出 Windows 包可以用 `python3 03_再刷重制_Godot/07_开发环境/导出冒烟.py --platform windows --keep` 导出并留在报告目录。
- 需要用户决定：①JDK 17 与安卓命令行工具的下载被自动权限拦，要 Kyo 放行或自己下（Adoptium、Google 官方源）；安卓 SDK 许可协议要 Kyo 本人接受。②存档目录名「KYO/再刷重制_开发」发行时要不要去掉「_开发」。③安卓后台挂机（原版用前台服务）要不要做。

## 进度账

- 跨平台：无旧项 → Windows 一期（导出＋离线检查）完成，安卓 0%（设计已写）

## 可优化（流程／工具／效率）

- 已做：导出冒烟加 `--platform windows`，Windows 包不用 Windows 机器就能验内容（回退：不带 `--platform` 时行为不变）。
- 建议：Windows 包 518 MB pck，和 Mac 包一样大；以后发行可考虑把 `generated/` 里不用的大图排除或压缩（预计包小三成，归导出／工具车道，要先量）。

## 验证

- 专项：`并行测试.py` ui_smoke、xiyou_flow、xiyou_panels、xiyou_mac_export、xiyou_map、xiyou_map_hotkeys、xiyou_options_basic、xiyou_event_compare，8 个全过（139 秒）。
- `选测.py main --list` 另列了 59 个楼层／地图专项（因为改了 `mv_player.gd`），没跑：那处改动只是把 `Input.is_key_pressed(KEY_META)` 换成在 macOS 上等价的 `WindowFit.fullscreen_modifier_held()`，楼层专项不按修饰键；`xiyou_map`、`xiyou_map_hotkeys`、`xiyou_flow`、`xiyou_event_compare` 已覆盖地图输入。没有战斗核心类场景。
- `工具回归.py` 全过；`语法检查.py` 572 个 .gd 0 问题；`测试导出过滤.py`、`测试导出冒烟.py`（7 例）通过。
- Windows 导出冒烟：包结构通过，包内 xiyou_mac_export 12/12、xiyou_flow 49/49（报告在 `04_验证/本地结果/导出冒烟/20261105_154652_windows/`）。
- 测试时总装正在合并 cc/bailong-ravenfx（工具提示产物可能过期）；本分支没碰切片、转换器、探针。

## 待交叉核查

- 甲：无（没改战斗核心、存档）。乙：`window_fit.gd`、`mv_player.gd` 一行、两个测试。丙：`导出冒烟.py`、`测试导出冒烟.py`、`测试导出过滤.py`、`export_presets.cfg`。

## 本分支提交

- be13a9e0 Windows 导出预设两档；全屏组合键按平台
- f27bfe84 导出冒烟 --platform windows；跨平台盘点与安卓二期设计
- （本提交）交付单
