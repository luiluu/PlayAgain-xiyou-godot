# 交付：cc/platform-android2

- 车道／工作者：跨平台（工程＋界面＋工具）／BH（cc，第九批 BH，接 BA 线程）
- 状态：可合并
- **合并顺序**：本分支已合进 `cc/entry-release1`（BI，安卓发行要它的图标与 `tianqi_release` 特性），请先并 BI 再并本分支；BI 的交付单不在本分支删。

## 变更记录草稿

## 2026-11-05 【cc·BH·未经审查】安卓二期：触屏、返回键、切后台补跑、安卓导出（dev.待定）

- 本分支从 cc/platform-pc-android1 切出（一期还没并进 main 时），合了 main；一期的交付单 `cc_platform-pc-android1.md` 也在本分支里，两张一起并。
- 本机：引擎便携设置 `editor_settings-4.7.tres` 填了 `export/android/java_sdk_path`（`~/Library/Android/jdk/jdk-17.0.21+9/Contents/Home`；SDK 路径 Godot 自己认出了 `~/Library/Android/sdk`）；用 keytool 生成了 Godot 默认位置的调试 keystore（`引擎/4.7.2-stable/editor_data/keystores/debug.keystore`，CN=Android Debug、口令 android，在 .gitignore 的引擎目录里）。改前的设置备份在 `.git/tangseng/editor_settings-4.7.tres.bak-bh`。没建、没碰正式签名证书。
- `export_presets.cfg` 加「安卓 验收」（调试签名、带 tests/、包名 `local.kyo.remake.verification`、应用名「再刷一把：天启篇（验收）」）、「安卓 发行」（排除 tests/、包名 `local.kyo.remake`、应用名「再刷一把：天启篇」（Kyo 16:06 定）、正式 keystore 留空）：arm64-v8a、不用 Gradle、沉浸全屏、只要 WAKE_LOCK。`测试导出过滤.py` 加这两档。
- `project.godot`：`display/window/handheld/orientation=4`（横屏）；`application/config/custom_user_dir_name.release="KYO/再刷重制"`（O-待定，见优化登记草稿）。
- 新 `core/platform.gd`（XPlatform，GameApp 建在自己下面）：两指点按转一次右键（游戏里右键＝取消，与 MV TouchInput 同一路），第二指不往下传；返回键当取消、入口菜单上退出；切后台松开虚拟键；挂机中不锁屏；挂机中切后台回来按离开时间 8 倍速补跑，最多 30 分钟游戏时间，点屏幕停（O-待定）。`XHangUp.current_active()` 新增，`map_scene._ready` 把它设成 `XPlatform.idle_probe`。
- 新 `core/touch_controls.gd`（XTouchControls，只在触屏设备由 GameApp 建）：摇杆、确定、取消、跑步、隐藏按键，按住 24／6 帧连发，按键上的触点和转出的鼠标事件都吃掉；补跑时显示剩余时间。
- `导出冒烟.py --platform android`：导出「安卓 验收」→ apksigner verify、aapt2 看包名／arm64-v8a／横屏、包内关键文件 → apk 的 assets/ 用新的 `07_开发环境/打包pck.gd` 打成 pck，放到 macOS 调试模板旁跑 `xiyou_mac_export`、`xiyou_flow`。`测试导出冒烟.py` 加 3 个离线用例。
- 新专项 `tests/xiyou_platform`（桌面上用 `XPlatform.force_mobile` 当成手机测）。
- 接 BI（Kyo 16:06 定应用名、16:17 定图标）：安卓验收包名「再刷一把：天启篇（验收）」；安卓发行加 `custom_features="tianqi_release"`、`package/name="再刷一把：天启篇"`、导出文件 `builds/android/再刷一把_天启篇.apk`；两档都用 `content/app_icon/` 的天穹巨眼（`main_192`、自适应前景／背景 432）。合 BI 时 `export_presets.cfg` 冲突一处（Windows 发行的名字与图标），按 BI 的为准；合 main 时 `project.godot` 冲突一处（main 被编辑器重写过，去掉了几行默认值），取 main 版本加回本分支两行。
- 设计与盘点更新在 [跨平台适配](../../03_再刷重制_Godot/00_设计/跨平台适配.md) 第五节。

## 优化登记草稿（总装合并时换成实际 O 号）

- O-待定 发行包存档目录去掉「_开发」：`project.godot` 的 `config/custom_user_dir_name.release="KYO/再刷重制"`，调试包与编辑器仍是 `KYO/再刷重制_开发`。恢复方法：删掉这一行。状态：已做（总装 14:55 定，Kyo 09:21 授权）。
- O-待定 安卓后台挂机：`XPlatform.BACKGROUND_IDLE = true`，挂机中切后台、回前台按离开时间 8 倍速补跑，最多 30 分钟。原版是前台服务真在后台跑；重制没有原生插件，做不到一样。恢复方法：`XPlatform.BACKGROUND_IDLE = false`（切后台就停）。状态：已做（同上），测试 `xiyou_platform` 的 background_idle_off 覆盖回退支。

## 交接板

- 下一步：安卓真机验收（装验收包、触屏按键、两指取消、返回键、切后台补跑、横屏、帧率）；三期：按键大小／透明度／位置、设置页触屏选项、存档导出导入、刘海安全区、原生前台服务（真后台挂机，要 Gradle 构建）。
- 用户试玩说明：Mac 上没有变化。安卓验收包在 `04_验证/本地结果/导出冒烟/20261105_175905_android/再刷重制_验收.apk`（桌面名「再刷一把：天启篇（验收）」）（调试签名，和原版包名不同，可以并排装），`adb install` 或拷到手机装。
- 需要用户决定：安卓真后台挂机（通知栏常驻）要不要做原生插件；发行签名用的 keystore 由 Kyo 自己建和保管。

## 进度账

- 跨平台：安卓 0% → 二期一轮（导出＋离线检查＋触屏一期）完成，待真机

## 可优化（流程／工具／效率）

- 已做：导出冒烟 `--platform android` 不用真机就能验安卓包的内容（回退：不带 `--platform` 行为不变）。
- 建议：`project.godot` 改了版本号以外的行，选测按「整轮」处理；车道没跑全量，总装合并时按规矩跑（或在选测对照里给 `display/`、`config/custom_user_dir_name` 这类设置行分个窄档，归工具车道）。

## 验证

- 专项（`并行测试.py`）：xiyou_platform（新，29/29）、ui_smoke、xiyou_flow、xiyou_panels、xiyou_mac_export、xiyou_map、xiyou_map_hotkeys、xiyou_options_basic、xiyou_event_compare、xiyou_determinism、xiyou_airship_fly、xiyou_dungeon、xiyou_hangup、xiyou_hangup_auto 全过。xiyou_platform 第一轮挂了 8 项，是测试注入触摸没按无头窗口（64×64）换算坐标，改测试后通过；按键代码没改。
- 没跑：`选测.py` 因 `project.godot` 改了版本号以外的两行判成「整轮」，`map_scene.gd` 一行列了 107 个场景；车道不跑全量，`map_scene` 那一行只是设一个静态回调（不改地图逻辑），地图、挂机、确定性专项已跑。请总装合并时按影响面补跑或并进当天全量。
- `工具回归.py` 全过；`语法检查.py` 0 问题；`测试导出冒烟.py`（10 例）、`测试导出过滤.py` 通过。
- 安卓导出冒烟：签名（apksigner，调试证书）与包结构（arm64-v8a、横屏 userLandscape、WAKE_LOCK）通过，包内 xiyou_mac_export 12/12、xiyou_flow 49/49（报告 `04_验证/本地结果/导出冒烟/20261105_175905_android/`，验收包留在同目录）。
- 接 BI 后：用调试签名导出「安卓 发行」预设看了一眼（发行签名没有，只验名字与图标）：标签「再刷一把：天启篇」、包名 `local.kyo.remake`、启动图标是天穹巨眼（自适应图标，解出 xxxhdpi 看过）；验收包再跑导出冒烟全过（报告 `20261105_181340_android/`，验收包留在同目录）。发行入口（直达西游标题）只有 release 模板才走，本机没有发行签名导不出 release 安卓包，`--report-entry` 留给有签名后或真机。
- 接 BI 后补跑：（见下一行）
- 测试期间总装在合并别的车道、BF 在跑探针同步，等槽约一小时；本分支没碰切片、转换器、探针。

## 待交叉核查

- 甲：无（没改战斗、存档读写；存档目录只在发行包里换名）。乙：`core/platform.gd`、`core/touch_controls.gd`、`game_app.gd`、`map_scene.gd` 一行、`hang_up.gd` 一个函数、`project.godot` 两行、`tests/xiyou_platform`。丙：`导出冒烟.py`、`打包pck.gd`、`测试导出冒烟.py`、`测试导出过滤.py`、`export_presets.cfg`。

## 本分支提交

- 77af07ef 安卓二期：平台模块、触屏按键、后台补跑、安卓预设、导出冒烟 --platform android
