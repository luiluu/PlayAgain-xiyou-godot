# 交付：T068 庆典称号专属图标

- 车道／工作者：小o（gpt-6.1-sol＋medium，P6）
- 状态：可合并
- 分支：luiluu/gpt-fest-title-icons

## 变更记录草稿

## 2026-11-16 【co·未经审查】庆典称号六张专属图标（dev.待定）

- 新增奖杯、连胜徽章（金／橙／红）、观赛票、签到章六张透明底 128×128 RGBA 图标与新旧尺寸对照预览，等待 Kyo 美术定稿。
- 玩家可见：定稿并由后续接线卡接入后，庆典称号将使用对应物象图标；本提交不改变游戏显示。

## 文件清单

工程 `content/fest/` 新增：
- Fest_Icon_Road.png
- Fest_Icon_OneFour_Gold.png
- Fest_Icon_OneFour_Orange.png
- Fest_Icon_OneFour_Red.png
- Fest_Icon_Watch.png
- Fest_Icon_Attend.png

预览与证据：`04_验证/本地结果/t068/preview.png`、`validation.txt`。
预览六行按 fest.gd 当前 TITLES 图标索引提取旧图，分别给出原生 32 和 128 尺寸；旧图放大采用 nearest，新图缩小采用 Lanczos。

## 物象判断／我不同意的地方

- 四种题材合适。奖杯保留杯身、双耳、底座；连胜用中央胜利星与上沿四枚连珠，三色同构。
- 单纯空白观赛票与空白签到章在 32 像素下语义偏弱，因此票加大缺口与眼睛，章加大勾及扇贝边；没有文字和品牌符号。
- 原 Fest_Trophy.png 实图带龙形装饰，与本单“无西游仙侠元素”冲突，本单只借用金属高光，不沿用龙饰。
- 32 像素下“票／章／奖杯／奖牌”轮廓可辨；具体称号仍应由旁边文字说明，四连珠不会替代称号文字。

## 生成方式与提示词

使用内置 imagegen，未调用 API CLI。共同提示：transparent isolated game inventory icon, polished hand-painted RPG item, crisp dark outline, chunky silhouette readable at 32x32, metallic highlights, no text/numbers/brands/Chinese fantasy elements。
- Road：classic gold two-handle trophy cup, short stem, blank walnut pedestal。
- OneFour_Gold：gold medal #ffd700, central five-point star, four upper-rim studs, two ribbon tails。
- Orange／Red：基于 Gold 原图仅改主色为 #ff8c00／#ff4500，保持四珠、星、缎带、构图和透明底。
- Watch：cyan ticket, large side cutout notches, gold rim, central eye。
- Attend：green scalloped gold-rim attendance seal, huge ivory checkmark；去除外部光晕。
最终仅进行尺寸规整与对照拼版，原始高分辨率图留在 imagegen 默认目录。

## 验证

- 图像专项：见 validation.txt；逐张检查 128×128、RGBA、透明边缘及 32 像素对照。
- 工具回归：22 项全部通过（102 秒）。
- 语法检查：984 个 .gd，0 个问题（20 秒）；选测.py 对新增 PNG／预览路径未登记，保守输出 full；本单仅未接线素材，无战斗核心改动，按车道不跑全量规则未跑整轮，请总装按影响面判断。
- 不改 .gd／.json，不运行战斗专项或 oracle；不接线、不合 main。

## 交接板

- 下一步：项目经理 cc 将 preview.png 交 Kyo 定稿，再开接线卡。
- 需要用户决定：美术定稿；本交付仅素材候选，不自标核查通过。

## 可优化（流程／工具／效率）

- 已做：连胜三色以同一底图改色，便于识别同一成就系列；回退只需删除本次新增素材。

## 本分支提交

- a77ec4c84：六张图标、对照预览、图像验证与本交付单。
