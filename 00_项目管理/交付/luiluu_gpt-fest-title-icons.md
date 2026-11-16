# 交付：T068 庆典称号专属图标 v2

- 车道／工作者：小o（gpt-6.1-sol＋medium，P6）
- 状态：可合并
- 分支：luiluu/gpt-fest-title-icons

## 变更记录草稿

## 2026-11-16 【co·未经审查】庆典称号六张像素图标候选（dev.待定）

- 按 Kyo 二轮意见将六张全部重画为像素风，32×32 母格、nearest 四倍放大为 128×128 RGBA；透明底、深色描边、有限色阶。
- 冠军之路改为大厅庆典同款银龙杯（银杯身、两侧龙、红底座）；一穿四改为剑翼连胜徽记，含闪电拖尾与四枚星火，金／橙／金红三色同题材。
- 观赛票保留缺口和眼睛，签到章保留大勾与章边。
- 修正预览目录：从仓库根 `04_验证` 移至 `03_再刷重制_Godot/04_验证/本地结果/t068/`，旧版改名 preview_v1.png，二轮为 preview_v2.png。
- 玩家可见：本单只提交素材候选；Kyo 定稿、后续接线后才影响游戏。

## 文件清单

`03_再刷重制_Godot/01_Godot工程/content/fest/`：
- Fest_Icon_Road.png
- Fest_Icon_OneFour_Gold.png
- Fest_Icon_OneFour_Orange.png
- Fest_Icon_OneFour_Red.png
- Fest_Icon_Watch.png
- Fest_Icon_Attend.png

`03_再刷重制_Godot/04_验证/本地结果/t068/`：preview_v2.png、validation_v2.txt；preview_v1.png 与 validation_v1.txt 为首版历史对照。

## 设计判断

- 遵照最新意见，银龙杯明确覆盖首单“无仙侠元素”的限制；大厅参考图只读。
- 剑翼连胜徽记用更锐利轮廓区别普通圆奖章，四枚星火表示连胜四场；32 格中剑和翼为主识别特征。
- 观赛票加深两侧缺口、放大眼睛；签到章放大勾，32 像素能辨认票与章。
- 从原 IconSet 四格测得 10／15／19／24 种实色，本次每图最多 24 实色，保留硬边与离散高光；128 可精确还原 32 格，无平滑采样。

## 生成方式与提示词

使用内置 imagegen，未用 API CLI。先读大厅 Fest_Trophy.png，并提取原 IconSet 四格作为像素风参考。
共同提示：true low-resolution 32x32 RPG Maker MV pixel art, nearest-neighbor enlarged, hard aliased square pixels, dark indigo one-pixel outlines, 3–4 discrete shades per material, tiny white highlights, limited palette, transparent background, no text/numbers/brands, no smooth rendering。
- Road：reference trophy exact design, silver bowl and stem, two symmetrical silver dragon handles, rectangular red pedestal。
- Gold：anime winning-streak insignia, upright gold sword, angular wings, lightning tails, dark central diamond and gold star, four top sparks, primary #ffd700。
- Orange／Red：基于 Gold 同一原图仅改调色板为 #ff8c00／#ff4500，保持剑翼、四星火、拖尾构图。
- Watch：cyan admission ticket, deep side notches, gold border and large eye。
- Attend：green scalloped seal, gold rim, huge ivory checkmark, no aura。
生成后按本单整数放大要求，以 nearest 采样到 32 母格，限制最多 24 色与二值 alpha，再 nearest 放大到 128；没有手绘替代 imagegen。

## 验证

- 图像专项：validation_v2.txt，逐图断言 128×128 RGBA、alpha 仅 0／255、实色不超过 24、32→128 nearest 像素完全一致；另查看 preview_v2.png 中真实 32 与 128 对照。
- 工具回归：本轮 22 项全部通过（106 秒）。
- 语法检查沿用首轮：984 个 .gd 零问题；二轮未改任何代码。
- 选测.py 对未登记 PNG 路径保守报 full；本单仅未接线美术，按车道规则未跑全量或战斗专项，请总装按影响面判断。
- 提交后运行交付自检，再向总装回报结果；不合 main、不接线、不自标核查完成。

## 交接板

- 下一步：cc 将正确目录的 preview_v2.png 交 Kyo 二轮定稿，再开接线卡。
- 需要用户决定：美术定稿。

## 可优化（流程／工具／效率）

- 已做：保留 32 格整数放大与不超过 24 色的规格检查，减少下一轮风格漂移；回退可恢复上一版提交。

## 本分支提交

- a77ec4c84：首版六图与预览。
- eed8ae058：首版收尾。
- 6c01ae089：二轮六张像素图、正确目录预览、首版预览迁移与规格验证。
