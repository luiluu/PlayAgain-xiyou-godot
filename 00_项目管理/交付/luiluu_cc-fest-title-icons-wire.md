# 交付：T072 庆典称号／成就新图标接线

- 车道／工作者：cc（claude-sonnet-5-5＋medium，P6）
- 状态：可合并
- 分支：luiluu/cc-fest-title-icons-wire（基于 luiluu/gpt-fest-title-icons，须在它之后合并）

## 变更记录草稿

## 2026-11-16 【cc·未经审查】庆典称号与成就改用新图标（dev.待定）

- `XQualityIcons` 新增号段 **6420～6425**（`FEST`，不与 6400～6417、9001、220000 起冲突）：6420 Road、6421 OneFour_Gold、6422 OneFour_Orange、6423 OneFour_Red、6424 Watch、6425 Attend，读 `content/fest/Fest_Icon_*.png`（128 RGBA 原色），取 32 时最近邻缩小，大图标取 128。入口沿用 `XUI.icon_texture` 里已有的 `XQualityIcons.info` 分流，称号选单 `\I[n]`、头顶名牌、成就界面都自动认。
- `XFest.TITLES` 六个称号：冠军之路 6420、一穿四 6421、一穿四·天灾 6422、一穿四·洪荒 6423、冠军观赛团 6424、全勤观众 6425；`XFestReward.ACHIEVEMENT_ICONS`：scene→6424、road→6420、one_four→6421、attend→6425。
- 活动总开关关着：称号表不列、成就定义不并，6420～6425 没人引用（沿用现有约定，已加断言）。
- 专项 `xiyou_fest_reward` 加 `_icons()`：六个称号 icon 都取得到 32×32 非空贴图、号互不相同且在号段内、成就图标映射、128 大图、开关关时成就定义为空。
- 玩家可见：庆典称号与庆典成就换成新像素图标（一穿四分金／橙／红三色）。
- 已知：已选中称号的老存档里 `designation.icon` 仍是旧号（1469／2506 等），头顶名牌显示旧图直到玩家在称号选单里重选一次；庆典 11-15 才开，影响面很小，未做存档迁移，需要的话另开一单。

## 验证

- `xiyou_fest_reward` 53/53、`xiyou_quality_icons` 7/7（带 `--full` 单跑）。
- 截图（Godot 窗口、Dummy 音频）：`03_再刷重制_Godot/04_验证/本地结果/t068/shot_achievement_fest.png`（成就「节日」页，图标 2 倍 64 显示）、`shot_titles_row.png`（六个称号 32 显示 nearest＋头顶名牌），边缘清楚不糊。

## 本分支提交

- fcdae3513 游戏：T072 庆典称号／成就改用新图标
