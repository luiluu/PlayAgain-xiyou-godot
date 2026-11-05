# 交付：cc/entry-release1

- 车道／工作者：BI 正式入口／cc（BI，派单第九批 1105）
- 状态：进行中

## 变更记录草稿

## 2026-11-05 【cc·BI·未经审查】正式入口：发行包直达西游标题、应用名「再刷一把：天启篇」、天穹巨眼图标（dev.待定）

- 依据：Kyo 11-05 16:05「游戏需要一个正式入口」（16:05「对的，就是这个意思」确认总装的理解）；16:06「应用名改为再刷一把：天启篇」；16:17 给图「用这个当图标」。
- 入口：新增 `core/release_entry.gd`（`ReleaseEntry`）。发行构建（release 模板，`OS.is_debug_build()` 为 false）启动时 `entry_menu.gd` 不建界面、直接 `GameApp.enter_mode("xiyou")` 进西游标题；标题不放「返回版本选择」，右下角显示「再刷一把：天启篇」；`GameApp.return_to_menu()` 在发行构建回标题；窗口标题设成应用名。调试构建（编辑器、测试、「macOS 验收」包）全照旧。只按构建类型区分，不认命令行参数（`--report-entry` 只让游戏打印进了哪个场景，给冒烟用，不改流程）。测试模式解锁文件不受影响（照旧只在 Kyo 本机生效、发行预设本来就排除）。
- 名称：「macOS 发行」预设 `application/name` 改「再刷一把：天启篇」，导出文件 `builds/再刷一把_天启篇.zip`（Windows 不认冒号，文件名用下划线；包内 .app 名带冒号）。bundle id 不变（`local.kyo.remake`），存档目录（`config/custom_user_dir_name`）不动。Kyo 指定的名字取代原版名（原版 `package.json` `product_string`「再刷一把：西游（mod_KYO）」、`System.json` gameTitle「再刷一把」，只作出处记录）。
- 图标：`content/app_icon/`（有 `.gdignore`，不进游戏包，只给导出预设读）放 Kyo 给的原图 `原图_天穹巨眼.jpeg`（2048²）和生成物；新工具 `07_开发环境/生成应用图标.py`（调 `生成应用图标.gd` 用 Godot 处理图片，`iconutil` 出 icns，自己写 PNG 内嵌的 ico）：一张原图 → `icon_source_1024.png`、`icon.icns`（Mac 按系统规格：824 居中、圆角外透明）、`icon.ico`（16～256）、`icon_256.png`、安卓 `android_main_192.png`／`android_foreground_432.png`（画面缩 0.85 居中，主体在安全区）／`android_background_432.png`。`--trim` 把原图贴边的白外边和圆角灌成暗底再裁掉。`来源.json` 记原图 SHA-256 与参数。macOS 验收、发行两档预设的 `application/icon` 都指向 `icon.icns`。
- 换图步骤：`python3 03_再刷重制_Godot/07_开发环境/生成应用图标.py <新图> [--trim]`，然后照常导出，预设不用改。
- 验证：待写

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 正式入口（`core/release_entry.gd` `direct_title`；`scenes/entry_menu.gd`、`modes/xiyou/entry.gd`、`core/game_app.gd`） | 原版只有西游一个游戏，打开即标题 | 发行构建跳过重制的模式选择、直达西游标题，标题不放「返回版本选择」；调试构建保留入口菜单 | Kyo 11-05「游戏需要一个正式入口」 | `ReleaseEntry.direct_title = false` | cc（BI） | Kyo 已确认方向 |

## 交接板

- 下一步：BH（`cc/platform-android2`）合并后，Windows、安卓发行预设补图标与名字（见下「给 BH」）；Kyo 实机双击发行包看一眼 Dock 图标与菜单栏名。
- 用户试玩说明：导出的发行包打开直接是西游标题，没有「选择你的世界」；应用名「再刷一把：天启篇」，图标是天穹巨眼。调试／验收包照旧先到入口菜单。
- 需要用户决定：无（O-待定 默认开）。

### 给 BH（Windows、安卓预设在 BH 分支，这里没改）

- 入口不靠预设：任何平台用 release 模板导出都会直达标题，BH 的 Windows／安卓发行预设不用为入口做任何事。
- 名字和图标：Windows 发行预设 `application/icon="res://content/app_icon/icon.ico"`、`application/product_name` 与 `application/file_description`「再刷一把：天启篇」、导出文件名 `再刷一把_天启篇.exe`；安卓预设 `package/name="再刷一把：天启篇"`、`launcher_icons/main_192x192="res://content/app_icon/android_main_192.png"`、`launcher_icons/adaptive_foreground_432x432="res://content/app_icon/android_foreground_432.png"`、`launcher_icons/adaptive_background_432x432="res://content/app_icon/android_background_432.png"`。
- `导出冒烟.py --platform windows` 若能跑发行包，可加 `-- --report-entry` 看输出里只有 `ENTRY_SCENE=res://modes/xiyou/entry.tscn`。

## 进度账

- 发行准备：新增「正式入口、应用名、图标」一项，Mac 完成，Windows／安卓待 BH 预设。

## 可优化（流程／工具／效率）

- 建议：`project.godot` 的 `config/icon` 目前为空（共用文件，车道不改）；总装合并时可设成 `res://content/app_icon/icon_256.png`，让 Windows／Linux 运行时窗口左上角也是新图标（Mac 用包内 icns，不受影响）。注意 `content/app_icon` 有 `.gdignore`，设 config/icon 要先去掉 `.gdignore` 或另放一张进包的 png。
- 建议：`新建工作树.sh --补齐` 的导入等槽这次等了 20 多分钟（别的车道占着测试槽），车道开工时间不可预期；可考虑让导入不占测试槽或单独给一个槽（归哪吒工具车道）。

## 本分支提交

- 待写
