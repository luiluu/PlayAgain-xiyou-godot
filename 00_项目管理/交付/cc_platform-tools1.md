# 交付：cc/platform-tools1

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DZ 单）
- 状态：可合并
- 基于：main 841f1e4c（dev.383）。
- **改了共用文件 `project.godot`**：只加了 `[editor_plugins]` 一段（启用 `res://addons/xiyou_export/plugin.cfg`），没动版本行。合并时请留意。

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】发行入口冒烟加安卓；补齐脚本整轮重导入不再被 5 分钟掐断；安卓版本号按开发编号（O-待定，dev.待定）

- **① 发行入口冒烟加安卓**（`07_开发环境/发行入口冒烟.py --platform android [--keys] [--apk <包>]`）：导出「安卓 发行」。发行 keystore 没配时，用本机 Godot 编辑器设置里的调试 keystore 通过 `GODOT_ANDROID_KEYSTORE_RELEASE_*` 环境变量签名，并在输出里说明「只给冒烟和试装，不能上架」；预设和文件都不改。
  - 静态检查（`apk_*`）：签名、包名、架构和横屏（沿用 `导出冒烟.android_layout(debug=False)`），应用名「再刷一把：天启篇」，版本号（见③），入口与资源文件（project.binary、西游标题 entry.tscn、build_info、System.json），包里没有 tests/。
  - 桌面替身：把 apk 的 assets/ 用 `打包pck.gd` 打成 pck，放到 macOS 发行模板旁跑入口，加 `--keys` 再跑四组按键。查的是包里的数据能不能进标题、按键会不会闪退，不是安卓系统本身。
  - 模拟器：`adb devices` 里有在跑的 `emulator-*` 就装上、启动，20 秒后看进程还在不在。没有就打印「没有在跑的安卓模拟器：只做了静态检查和桌面替身运行，没在安卓上装机启动」。连着的真机只提示、不往上装。
  - Windows 分支的「macOS 发行模板当替身」抽成 `release_runner`，两边共用；`导出冒烟.parse_android` 多读一个应用名。
  - 新测试 `测试发行入口冒烟.py`（6 项，离线）：只认模拟器、真机不装、入口文件清单、命令行认 android 和 --apk、keystore 查找。进 检查.sh tools 组和 工具回归.py。
- **② 补齐整轮重导入**（`07_开发环境/新建工作树.sh --补齐`）：新工具 `导入超时.py` 按各 .import 文件写的 ctex 路径，数 `.godot/imported` 里缺多少。缺的超过两成，或者 `.godot/imported` 没有、是空的，就算整轮重导入：改用 `长任务.py start` 脱离会话跑 `占槽.py -- godot --import`，不设 300 秒上限，脚本每 540 秒等一次；脚本自己被 Bash 十分钟上限掐掉时，导入照样在后台跑完。普通补齐照旧 `alarm 300`。新测试 `测试导入超时.py`（6 项，离线）：判断规则，以及脚本里整轮那一支不带 alarm、普通那一支带。进 检查.sh tools 组和 工具回归.py。
- **③ 安卓版本号按开发编号**（O-待定·安卓版本号）：新导出插件 `addons/xiyou_export`（`project.godot` 启用）。导出安卓时用 `_get_export_options_overrides` 把 `version/code` 改成开发编号的数字（dev.383 → 383），`version/name` 改成「0.<数字>」（0.383）。规则写在 `XAndroidVersion`（`android_version.gd`，要 `@tool`：不带的话编辑器里静态变量是空的，第一次导出就这样没生效，被冒烟查出来了）。回退：`XAndroidVersion.AUTO = false`，用预设里的 1／0.0.0。`导出冒烟.py` 比版本号时改看 `expected_android_version`，插件开着就按开发编号比。新测试 `xiyou_android_version`（12 项）。

## 交接板

- 下一步：无（工具类）。以后导安卓包直接 `发行入口冒烟.py --platform android --keys`。
- 用户试玩说明：以后的安卓包在手机「应用信息」里显示版本 0.<开发编号>，版本码跟着开发编号只增不减，新包总能覆盖装在旧包上（安卓不许装比已装的版本码小的包）。之前给 Kyo 的 dev.383 包版本码是 1，比以后的都小，直接覆盖装就行（签名是同一个本机调试 keystore）。
- 需要用户决定：
  - 正式上架用的版本号（versionName／versionCode 怎么排）和正式签名 keystore。现在是 0.<开发编号>，用调试 keystore 签名。
  - O-待定·安卓版本号的默认值（现在开着）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：上面②（DX 单提的那条）。
- 已做：上面①（DX 单提的那条）。

## 验证

- `发行入口冒烟.py --platform android --keys`：12/12 通过（apk_layout、apk_label、apk_version 383／0.383、apk_entry_files、apk_no_tests、入口、正常退出、四组按键、没有新崩溃报告）。本机没有模拟器，输出里已写明没有装机。修 `@tool` 之前那一轮 10/12，版本号两项挂（这就是旧行为会挂的证据）。
- `发行入口冒烟.py --platform windows`：4/4（`release_runner` 抽出来以后 Windows 没坏）。
- Godot 专项（并行）8 个全过：xiyou_android_version、xiyou_mac_export、xiyou_entry_release、xiyou_platform、xiyou_flow、ui_smoke、xiyou_key_smoke、xiyou_pause_save。`选测.py` 因为 addons 和 project.godot 给的是「整轮」；车道不跑整轮，插件只在编辑器里加载，游戏运行时不加载，所以只选了跟导出、入口、平台相关的场景。
- `工具回归.py` 全过（含新加的两项、回退开关覆盖）；`测试导出冒烟.py` 14 项、`测试导出过滤.py` 都过；`语法检查.py` 0 个问题。
- ②实跑：把本工作树 766 张 ctex（四分之一）挪走后跑 `--补齐`：判成整轮、走长任务，导入 7 分 19 秒（超过旧的 300 秒上限）后成功，ctex 回到 3065 张、199.7 MB，后面的步骤照常跑完。

## 本分支提交

- 743a69d7 WIP：补齐整轮重导入走长任务
- cacd36c4 WIP：发行入口冒烟加安卓、安卓版本号
- WIP：优化登记 O-待定·安卓版本号
- 交付单 cc_platform-tools1（本提交）
