# 交付：cc/platform-version1

- 车道／工作者：B 界面（cc，platform-version1）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·未经审查】右下角显示版本号，所有构建都有（dev.待定）

- Kyo 要求正式版右下角也显示版本号。新增 `core/version_label.gd`（`XVersionLabel`，CanvasLayer 125，高于触屏按键层 120），`GameApp` 启动时建；读 `project.godot` 的 `config/version`（开发编号），右下角 14 号半透明白字＋细黑描边，不挡鼠标。调试、验收、发行包都显示。回退开关 `XVersionLabel.SHOW = false`。
- 同一轮从 main（dev.377）加这个标签导出了「macOS 发行」包，覆盖 `/Users/kyo/Applications/再刷一把：天启篇.app`（旧 dev.368 包备份在 `05_发布/导出包/再刷一把：天启篇_dev368备份.app`，不进 Git）。发行入口冒烟 5/5。
- 合并后 dev 号会前进，下一次导出的包版本号随之变化；这次导的包里写的是 dev.377。

## 验证

- 新专项 `xiyou_version_label` 6/6；xiyou_key_map 31/31、ui_smoke 24/24、xiyou_platform 83/83、发行入口冒烟 5/5、语法检查通过。选测请总装按 `选测.py main --list`（改动面只有 game_app 加一个节点）。

## 交接板

- 下一步：无
- 用户试玩说明：右下角小字显示版本号，如 dev.377
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 右下角版本号
