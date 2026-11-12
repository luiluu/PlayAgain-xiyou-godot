# 交付：cc/boot-splash

- 车道／工作者：去掉 Godot 启动画面（Kyo 11-12）／cc（项目线程）
- 状态：可合并
- 车道路径：/private/tmp/claude-501/-Users-kyo-Documents----------claude-worktrees-busy-ishizaka-506125/60356c0b-9cdf-41e9-a7b9-7bdd5f948fe8/scratchpad/splash

## 变更记录草稿

## 2026-11-12 【cc·线程·未经审查】启动时不再显示 Godot 引擎标志页（dev.待定）
- 起因：Kyo 11-12「游戏开始好像还会弹一些 godot 那个小页面，能否隐藏」。工程没设启动画面，Godot 默认在加载时显示引擎标志（灰底 Godot 图标）。
- `project.godot` 加 `application/boot_splash/show_image=false`、`boot_splash/bg_color` 纯黑：加载期间只显示黑屏，之后照常进标题。
- 只在整包里生效：启动画面在补丁（第一个自动加载 _init 才载入）之前就画了，修复补丁改不了，要等下一次出整包。不进 v0.01.02 补丁。
- 玩家可见：下一个整包起，开游戏不再闪 Godot 标志页。
- 未完成／已知问题：没出包实测；Kyo 说的「一些小页面」若不止引擎标志（比如安卓系统自带的图标启动页），要看截图再定。

## 交接板

- 下一步：下一次出整包时带上；出包后在安卓、Mac、Windows 各开一次看启动是不是直接黑屏进标题。

## 进度账

- 无

## 验证

- 只改两行工程设置，没跑 Godot 专项（设置不影响无画面测试）；`交付自检.py` 通过。

## 待交叉核查

- `03_再刷重制_Godot/01_Godot工程/project.godot`（boot_splash 两行；共用文件，只加设置、没动开发编号）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- （本提交）关掉启动画面；交付单
