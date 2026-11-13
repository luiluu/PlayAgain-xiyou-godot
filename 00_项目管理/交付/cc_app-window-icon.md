# 交付：cc/app-window-icon

- 车道／工作者：平台·应用图标／cc（项目线程，Kyo 经协调派）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】运行时窗口图标换成天穹巨眼（dev.待定）

- 现象：Windows 版标题栏、任务栏和开发时运行的 Dock 显示 Godot 默认图标。原因是 `project.godot` 没设 `application/config/icon`，Godot 运行时就放默认图标；导出包本身的图标（Mac icns、Windows exe 资源、安卓启动图标）早在 11-05 就是 Kyo 定的天穹巨眼，没问题。
- 改动：新目录 `content/app_icon_runtime/`（不带 .gdignore，随包导出）放 `icon.png`（照 Mac 规格的 512 圆角图，从 icon.icns 取出）和 `icon.ico`（同 `content/app_icon/icon.ico`）；`project.godot` 加 `config/icon`、`config/windows_native_icon` 指向它们；两条 Windows 预设的 include_filter 加上这个 ico（不是资源，不加不进 pck）。
- 工具：`生成应用图标.py` 换图时同时写 `app_icon_runtime/`；`发行入口冒烟.py --platform windows` 加 `pck_window_icon_png`／`pck_window_icon_ico` 两项。
- 安卓：启动图标照旧由预设给；安卓没有窗口标题栏，不用改。
- 玩家可见：Windows 版窗口左上角和任务栏换成天穹巨眼图标；Mac 版运行时 Dock 图标也不再会被换成 Godot 默认图（之前打包版靠 bundle 图标，本来就对）。

## 交接板

- 下一步：无
- 用户试玩说明：Windows 包标题栏、任务栏图标是天穹巨眼
- 需要用户决定：无

## 进度账

- 无（平台细节，不进主表）

## 可优化（流程／工具／效率）

- 无

## 验证

- `发行入口冒烟.py --platform windows`：7/7 通过（含新加的两项 pck 图标检查、exe 256 图标）
- `发行入口冒烟.py`（macOS 发行）：6/6 通过，icns 未变
- 本机非无头启动 120 帧，无图标相关报错
- `工具回归.py` 全过；`并行测试.py` xiyou_mac_export、xiyou_input_handled 通过
- 选测给的是整轮（新图片文件和 project.godot 改动它拿不准）；本次只加两条项目设置和图标文件，没碰游戏逻辑，没跑整轮，请总装按每日全量覆盖

## 本分支提交

- f1d208462 运行时窗口图标：config/icon 与 Windows 原生 ico 用天穹巨眼，生成工具同步输出，Windows 发行冒烟查 pck
