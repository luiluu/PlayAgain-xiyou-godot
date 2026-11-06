# 交付：cc/platform-android5

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DP 单）
- 状态：可合并
- 基于：`cc/platform-crash1` 头 4f5a6714（切分支时 DK 还没合进 main；main 那时是 f08efa7c）。本分支只加了这张交付单，没改代码，**要等 DK（cc/platform-crash1）合入后再合**，或者跟它一起合。

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】安卓发行包冒烟：本机做不了，写了缺什么和真机清单；跨平台扩展账基线草稿（dev.待定）

- ① 安卓冒烟本机做不了：`~/Library/Android/sdk` 里有 `platform-tools/adb`，但 `adb devices` 一台设备都没有；模拟器配置 `~/.android/avd/kyo_qa`（android-35、google_apis、arm64-v8a）还在，可它要的 `sdk/emulator/` 程序和 `sdk/system-images/android-35/google_apis/arm64-v8a/` 系统镜像都不在了（多半是 11-05 磁盘清理时删的）。要在本机做，需要用 `sdkmanager` 重新下载这两样（大约 2 GB，从 Google 官方源下），得 Kyo 同意才能下；或者 Kyo 用 USB 接一台开了 USB 调试的真机。下面写了真机测试清单。
- ② 跨平台扩展账基线草稿（PC／安卓 × 9 项）见下面「扩展账基线」一节，只写现状和依据，**不写完成度数字**，交给审查 51 核定。

## 安卓冒烟：缺什么、怎么补

- 缺：设备（真机或模拟器）。模拟器要补 `emulator` 包＋`system-images;android-35;google_apis;arm64-v8a`（`sdkmanager` 从 Google 下，约 2 GB），AVD 配置 kyo_qa 现成，不用重建。
- 有了设备以后，思路照 `发行入口冒烟.py --keys`：`adb install -r <apk>` →`adb logcat -c` → `adb shell am start -W -n <包名>/com.godot.game.GodotAppLauncher` → `adb shell input keyevent 66`（回车）、`62`（空格）、`38`（J）、`4`（返回）→ `adb shell pidof <包名>` 看进程还在 → `adb logcat -d` 里搜 `SIGSEGV`、`FATAL`、`Fatal signal`。
  - 要验的是**发行**包：11-06 那类空指针只有发行模板会崩，验收包（调试模板）只报错不崩。「安卓 发行」的正式 keystore 是空的，要先拿调试 keystore 签一份发行包（只给测试用，不发布）。
  - 游戏自带的按键钩子（`--smoke-keys`，DK 加的）在安卓上怎么传命令行参数我没核实，所以这里用 `adb shell input keyevent` 从系统层按键，不依赖钩子；这样反而更接近真按键。
- 建议这件事归平台车道下一单：等设备有了，把上面的步骤做成 `发行入口冒烟.py --platform android --keys`。

## Kyo 真机测试清单（安卓）

先在手机上开「开发者选项 → USB 调试」也行，不开也能做，只是出问题时我拿不到日志。

1. 装最新的安卓包（总装导出后给的 apk），点图标打开：应该直接进西游标题，标题右下角显示「再刷一把：天启篇」和版本号。
2. 在标题上点「新的游戏」：进开局地图，不闪退。（这一步就是 11-06 Mac 上闪退的那条路。）
3. 地图上用左下摇杆走几步，右下「确定」「取消」各按几次：消息能翻页，取消能打开、关掉菜单。
4. 手机返回键：在地图上按一次＝取消（开关菜单）；回到标题后按一次出提示「再按一次返回键退出」，两秒内再按一次退出游戏。
5. 打开主菜单 → 选项 → 最下面「手机按键设置」：调大小、透明度，退出再进游戏，设置还在。
6. 地图上按右上「存档」键存一次档；进商店页时右上不应该有存档键。
7. 游戏开着时切到别的应用，过半分钟再切回来：画面、声音都正常，触屏键没卡住。
8. 任何一步闪退了：记下是哪一步、按了什么，手机连电脑时我可以用 `adb logcat` 取日志。

## 扩展账基线

只写现状和依据，不写完成度。「做了」＝代码和测试都在 main，「部分」＝做了一部分或只在 Mac 上替身验证过，「没做」＝还没动。PC 指 Windows（Mac 是原平台，不算在扩展账里）。

| 范围项 | PC（Windows）现状 | 依据 | 安卓现状 | 依据 |
| --- | --- | --- | --- | --- |
| 导出预设 | 做了：「Windows 验收」（调试、带 tests/、控制台包装 exe）、「Windows 发行」（排除 tests/），x86_64 | dev.365 BA 跨平台一期（`export_presets.cfg`、`测试导出过滤.py`） | 部分：「安卓 验收」「安卓 发行」都在（arm64-v8a、不用 Gradle、横屏），但发行档的正式 keystore 是空的，出不了能发布的发行包 | dev.368 BH 安卓二期；cc_platform-android2 交付单 |
| 图标与名称 | 做了：exe 产品名「再刷一把：天启篇」、256 图标；冒烟查 VERSIONINFO 与图标组 | dev.367 BI 正式入口；dev.374 云端导出冒烟 | 做了：应用名「再刷一把：天启篇」（验收包带「（验收）」）、天穹巨眼图标（main_192、自适应前景／背景）；冒烟查 versionCode、versionName、图标 | dev.367 BI；dev.368 BH；dev.374 |
| 存档位置 | 部分：走 `user://`，发行包目录 `KYO/再刷重制`（去掉「_开发」）；Windows 上应在 `%APPDATA%\KYO\再刷重制`，没在 Windows 实机看过 | dev.365 盘点；O-200（dev.368） | 部分：应用私有目录；标题页导入／导出存档走系统文件选择器（导入前备份、只搬存档）；没上真机 | O-200；dev.371 平台三期（O-206、O-208） |
| 输入：键鼠 | 做了：键位照原版补全、Alt+Enter／F11 全屏、鼠标点选／右键取消／滚轮、地图右键菜单、按住左键拖着走；替身验证，没在 Windows 实机按过 | dev.365；dev.372（keys1～3）；dev.374 Windows 窗口核对 | 不适用（手机上没键鼠） | — |
| 输入：手柄 | 部分：照原版 gamepadMapper 做了（A／B／X／Y／LB／RB、十字键、摇杆），只在 Mac 上测，Windows 上没接过手柄 | dev.372（`xiyou_pad`） | 部分：代码同一套，安卓上没接过手柄 | dev.372 |
| 输入：触屏 | 不适用 | — | 做了：摇杆、确定／取消／跑步／隐藏键、两指取消、返回键（顶层两次退出）、手机按键设置页、刘海安全区、存档键只在地图和主菜单；都是桌面上模拟手机测的，没上真机 | dev.368、dev.369（O-202）、dev.371（O-207）、dev.372、dev.376（O-211）、cc_platform-size1（商店页存档键） |
| 分辨率与 DPI | 部分：逻辑 1280×720、keep 比例留黑边、窗口按屏幕可用区 90%；高 DPI 用 Godot 默认（开）；没在 Windows 高 DPI 屏上看过 | dev.365 盘点；dev.374 Windows 窗口核对 | 部分：横屏、keep 比例，19.5:9 手机会有左右黑边（没改 expand，盘点里写的是先只做 keep）；安全区已处理 | 跨平台适配.md 盘点表；dev.371 |
| 音频 | 部分：Godot 音频平台无关，BGM 降到 96k；没在 Windows 实机听过 | cc_platform-size1（O 待定·audio_96k） | 部分：同上；切后台回来有没有声音还没验（盘点里列成二期要验） | 跨平台适配.md「切后台」「音频」两行；cc_platform-size1 |
| 包体 | 做了：发行 exe＋pck 630.8→479.0 MB（贴图 WebP 最高档 O-210、BGM 96k） | cc_platform-size1 | 做了：验收 apk 482.1→331.0 MB；再小要动画质，要 Kyo 定 | dev.374 包体调查；cc_platform-size1 |
| 发行冒烟 | 部分：「Windows 发行」导出后，exe 资源查名字和图标；GDScript 用同名 macOS 发行模板跑 .pck，入口＋按键冒烟 9/9；没在 Windows 上跑 exe | dev.365；cc_platform-crash1（`发行入口冒烟.py --platform windows --keys`） | 部分：只有「安卓 验收」包的结构检查（apksigner、aapt2）和 pck 用 macOS 调试模板跑；发行包按键冒烟本机做不了（没设备，见上） | dev.368、dev.374（云端导出冒烟）；本单 |
| 真机验收 | 没做：没有 Windows 机器；要看的列在跨平台适配.md 第三节末（双击启动、DPI、全屏、中文输入法、存档目录、杀毒／SmartScreen） | 跨平台适配.md | 没做（记录里没有 Kyo 装过真机的结果）：清单见上「Kyo 真机测试清单」；size1 留了一份验收 apk 等 Kyo 装 | cc_platform-size1「真机由 Kyo 装」；本单 |

注：任务单列的是 9 项，我把「输入」按键鼠／手柄／触屏拆成三行，方便审查分平台核定，所以表里是 11 行。

## 交接板

- 下一步：等 Kyo 定要不要下载安卓模拟器镜像（约 2 GB）或接真机；有了设备后平台车道做 `发行入口冒烟.py --platform android --keys`。
- 用户试玩说明：无（没改游戏）。
- 需要用户决定：安卓发行包冒烟要设备：①同意下载模拟器和系统镜像（约 2 GB）；或②用 USB 接一台真机；或③先只照上面清单手动试。

## 进度账

- 无（扩展账完成度交审查 51 核定）

## 可优化（流程／工具／效率）

- 建议：安卓「发行」档用调试 keystore 另出一份只给测试的发行包（不发布），这样空指针一类只在发行模板出现的问题手机上也能测到（归平台车道）。
- 建议：AVD kyo_qa 的配置还在，以后清理磁盘时把 `~/Library/Android/sdk/emulator`、`system-images` 列成要保留的，或者在清理清单里注明删了要重下约 2 GB。

## 验证

- 只改了这张交付单，没有代码改动，没跑测试。环境检查：`adb devices` 空；`ls ~/Library/Android/sdk` 没有 `emulator/`、`system-images/`；`~/.android/avd/kyo_qa.avd/config.ini` 指向 `system-images/android-35/google_apis/arm64-v8a/`。

## 本分支提交

- 交付单 cc_platform-android5（本提交）
