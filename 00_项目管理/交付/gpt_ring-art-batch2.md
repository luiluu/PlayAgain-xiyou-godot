# 交付：gpt/ring-art-batch2

- 车道／工作者：T042 装备环卡2第二批／小o（co，gpt-6.1-sol＋medium，P6）
- 状态：可合并
- 定位：执行出图待小A Carbon美术审，不自行标美术定稿。

## Carbon返修（本轮，以此节与最新测量为准）

完整审稿随交付提交：[小A美术审](gpt_ring-art-batch2_小A美术审.md)。本轮按给定RGB与16×8矩阵修改，不自行标定稿；待协调Opus对照P1复核再给Kyo。

| 审项 | 怎么改的 | 验证证据 |
| --- | --- | --- |
| P1-1 环心暗罩凿穿高光、三框撞色 | 删除共用五边暗罩；四冠分别逐格采用审稿的双叉火角／三珠疫结／仰口空碗／方印矩阵，x40～55镜像，y4～11，绝不写y≥12；四套框色逐项采用Carbon给的RGB | 四冠镜像断言通过，圆框y≥12原着色覆盖数均0；war/famine、war/qiyin、famine/qiyin主色欧氏距离52.69／49.07／58.45 |
| P1-2 白／殉撞脸 | 白印用冷银骨白、24宽冠齿、亮刃；殉印砍掉厚带，仅保留r120.5～122.5细灯丝，18簇倾斜暖杏烛舌和琥珀尖，采用报告公式 | 殉印r123～138不透明像素2744→1438；并排预览已重出，镂空外形与冷暖区别可直接看 |
| P1-3 红印外齿融底 | 采用暗锈／铜／旧金四色，30齿代替48齿；每齿斜刃内侧1.3px亮边，上金下铜；主圈加旧金内弦 | 外圈r123～138加权亮度≥150像素0→468，红色阈值像素仍0 |
| P2-1 震印裂缝 | 主圈13段裂口由phase .42～.50拓宽至.39～.55，两侧各.02暗封头；蓝靛亮色提亮，下半圈用(128,148,198) | 裂缝约8～9px，完整半径包络断言通过 |
| P2-2 灰印链眼 | 删除r120～132整带暗床，只画双股距离≤2.6暗壳、≤1.5骨色，交汇关节头加粗 | r123～138不透明像素7240→5816，链眼透底 |

新增色全部来自小A报告明确RGB覆盖，原来源参考与坐标保留在palette_sources.json；额外下半圈色、琥珀尖与铜色也有记录。七印全屏合成、标框图及两张总览均重出。P3的.import按派单留总装。工具回归本轮20项全通过（106秒）；交付自检退出0。审稿原件也位于交付目录，自检提示总装finish时加 `--also 00_项目管理/交付/gpt_ring-art-batch2_小A美术审.md` 处理原件，不将原件当第二份实现交付单。

## 变更记录草稿

## 2026-11-16 【co·美术·未经审查】装备环卡2第二批九张原生像素素材（dev.待定）

- 按Carbon报告返修三条P1及两条P2，重出本批九张与全部预览，审稿原件随交付。
- 玩家可见：装备环新增美术待审，尚未接入运行时。
- 样板四张保持字节一致；新增七印20:9触屏130%离线合成及栏位名矩形标注、两张全套总览。

## 文件清单与取色来源

统一路径：`03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style/`。

| PNG | 来源（qiyin下） | 调色／母题 |
| --- | --- | --- |
| ring_band_bai.png | circles/bai.png | 冷银骨白，双细线＋24连续宽冠齿 |
| ring_band_hong.png | frames/hong.png | 排除亮红后，以暗锈红＋旧金重配；连续锯齿 |
| ring_band_hui.png | circles/hui.png | 冷灰压向灰绿；连续交接骨节链 |
| ring_band_xun.png | circles/xun.png | 暖杏残烛；细灯丝＋18簇倾斜烛舌，静态底图不绘独立漂浮点 |
| ring_band_zhen.png | circles/zhen.png | 蓝白压成暗靛；错位断裂双轨；未吸frames/zhen亮红 |
| ring_center_war.png | badges_128/war.png | 暗锈红铜＋旧金；双叉火角剑冠 |
| ring_center_plague.png | badges_128/plague.png | 暗灰、橄榄绿；三向疫结缩写 |
| ring_center_famine.png | badges_128/famine.png | 枯麦冷灰铜；仰口空碗／秤盘 |
| ring_center_qiyin.png | circles/hei.png | 盛装旧金；平顶方印玺台，无龙 |

每个深／中／亮色的源坐标、源RGB、输出RGB见[palette_sources.json](gpt_ring-art-batch2_预览/palette_sources.json)。是源材质参考后的人工调色，并非声称逐像素原色照搬；亮度按已过样板的深壳、亮芯方法控制。原生逐像素绘制，无抗锯齿，无柔边alpha；程序负责法阵染色、殉印漂浮与残缺压暗。

## 验证

仓根运行 `/tmp/ring-art-venv/bin/python 00_项目管理/交付/gpt_ring-art-batch2_预览/build.py` 复出图，随后同解释器运行同目录 `verify.py`。脚本只写本批九张与本批预览，不覆盖样板。

量法：每个不透明像素以方格中心dx、dy求近缘 `hypot(max(abs(dx)-0.5,0),max(abs(dy)-0.5,0))`、远缘 `hypot(abs(dx)+0.5,abs(dy)+0.5)`，量整个方格，非只量像素中心。

| 环身 | 尺寸 | 完整方格半径包络 |
| --- | --- | --- |
| bai | 288×288 | 108.812～132.612 |
| hong | 288×288 | 108.812～132.593 |
| hui | 288×288 | 108.812～132.189 |
| xun | 288×288 | 108.812～132.966 |
| zhen | 288×288 | 108.453～130.668 |

四张环心均96×96，完整像素方格包络分别war 33.000～44.181、plague 33.000～44.045、famine 33.000～43.417、qiyin 33.000～43.290；主体完整方格≤38，超38仅12点±15°以内。全部9张红像素0、柔边alpha0；红色保守阈值为R≥120且R>1.6G且R>1.6B，全部alpha仅0／255。四张新环心各与20:9触屏130%全部13个栏位名矩形交叠0，测量与断言原文见[measurement.txt](gpt_ring-art-batch2_预览/measurement.txt)。样板hei、mo、death、orb四图与a2294d4a3逐字节比对一致。

- 选测main --list已跑：新增未知PNG保守触发整轮；本批无GDScript、战斗或存档变更，按派单的图像专项交付，不跑Godot全量。
- 工具快速回归20项全通过、退出0（见预览tool_regression.txt）；提交后交付自检通过、退出0（见delivery_check.txt）；快车道，无转换或同步产物变化。
- 按派单从样板a2294d4a3制作，未把main后续程序改动合入这次美术基线，预览继续使用Kyo已过样板的真实引擎底图。

## 合成预览

[七印环身并排](gpt_ring-art-batch2_预览/overview_bands.png)、[四线＋七印神器环心并排](gpt_ring-art-batch2_预览/overview_centers.png)。均以原生大小排布，不放大美化。

每印一张20:9触屏130%完整合成，另有同图标注全部栏位名外框：

- [白印](gpt_ring-art-batch2_预览/annotated_bai_20x9_touch130.png)
- [红印](gpt_ring-art-batch2_预览/annotated_hong_20x9_touch130.png)
- [黑印](gpt_ring-art-batch2_预览/annotated_hei_20x9_touch130.png)
- [灰印](gpt_ring-art-batch2_预览/annotated_hui_20x9_touch130.png)
- [殉印](gpt_ring-art-batch2_预览/annotated_xun_20x9_touch130.png)
- [震印](gpt_ring-art-batch2_预览/annotated_zhen_20x9_touch130.png)
- [默印](gpt_ring-art-batch2_预览/annotated_mo_20x9_touch130.png)

同目录composite开头的七张为未标注版。沿用样板bare／clean底图与layout_20.json，先环身、恢复球与焦点、33半径头像、环心框、武器副手球框、最后原始栏位文字层；没有重画文字或擦背景。此为离线合成，程序接线后需总装验收，不宣称运行时效果。

## 我不同意的地方

首轮担心的白／殉撞脸在Carbon审中得到证实，本轮按审稿拉开24宽冷冠齿与18簇暖烛舌；同意本轮全部P1／P2意见，无新增异议。瘟疫继续保留绿芯材质方向；最终1:1辨识度由协调复核。

## 交接板

- 下一步：协调Opus按Carbon报告逐项复核P1预览与verify.py，通过后给Kyo看；再由总装接入。
- 用户试玩说明：本批新增美术未接线。
- 需要用户决定：无新增。

## 可优化（流程／工具／效率）

已做：本批附复出图、源色坐标、尺寸／方格包络／红色／文字相交脚本；删本批预览目录即可回退，不改公共工具。

## 本分支提交

以分支HEAD为准；执行者co，核查待审查。
