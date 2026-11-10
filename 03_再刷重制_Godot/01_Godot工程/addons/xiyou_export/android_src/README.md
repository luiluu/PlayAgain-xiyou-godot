# XiyouBgIdle 安卓插件（后台挂机前台服务）

cc 平台 android-bgidle1（2026-11-09，Kyo 定 C：照原版做前台服务）。GodotPlugin v2，Kotlin。

- `XiyouBgIdlePlugin`：GDScript 里 `Engine.get_singleton("XiyouBgIdle")`。`setArmed(true)` 之后切后台（活动 onPause）就起前台服务；回前台（onResume）关服务，记下离开了多久（`SystemClock.elapsedRealtime`，含锁屏睡眠）。
- `XiyouIdleService`：通知栏常驻（计时）、点通知回游戏、「停止挂机」按钮。按了停止，离开时间只算到按的那一刻。
- 限制：Godot 切后台时渲染表面被收走、主循环停住，前台服务只保证进程不被杀；离开的时间在回到游戏时补跑（`core/platform.gd`）。

构建：`python3 03_再刷重制_Godot/07_开发环境/云端导出.py android-build --templates <模板目录>`（装 Gradle 构建模板＋编出 `addons/xiyou_export/android/xiyou_bgidle.aar`）。本机没装 JDK 17 时只能在云端（导出冒烟工作流）跑。
导出插件 `addons/xiyou_export/plugin.gd` 在 Gradle 构建开着且 aar 存在时才把它加进包。
