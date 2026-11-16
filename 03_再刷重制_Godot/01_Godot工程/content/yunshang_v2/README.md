# 云裳重绘样板 u1（T113）

**D164后续完整动作与游戏接入见 [u2说明](u2/README.md)，当前运行时使用u2；下文保留u1审样历史。**

供 Kyo 审样，未定稿、未接线，不可直接替换完整游戏资源。执行者 co；交叉核查待审查。

依据 ff8ea7b7c 的方案 v0.2（只读，没有合并该分支）、五条悟当前定稿、米拉与宿傩 README，以及 01d9cfcf7 的宿傩提示词。小A PlanA/PlanB 仅作比较，没有把未定稿当定稿。

## 文件

- `$Yunshang_u1.png`：144×192，48格，四方向各三帧。
- `Yunshang_SV_sample_u1.png`：576×384，64格；仅 wait（motion 1，第二行前三格）及 thrust（motion 6，第一行第4～6格），其余48格刻意空白。
- `battle_sample.png`：3×2 六帧便览；对应 `_4x` 为最近邻放大。
- `Yunshang_Face_u1.png`：576×288，第一格144头像；另有 `face_144.png`。
- `battle_comparison.png`、`battle_comparison_2x.png`：云裳、米拉、五条悟、原版 Actor1_1 与 Actor1_2，统一原大像素比例、脚底基线的战斗舞台合成预览，**不是实机截图**，未套游戏归一缩放。
- `idle.gif`、`attack.gif`、`walk_down.gif`：动作放大预览。
- `raw/` 保留生成母图；`references/` 保留所用参考；`build.py` 为本目录离线后处理，`validation.json` 为尺寸及外接框证据。

## 我不同意的地方

方案第六节仍有“云裳先试A3”的旧评估，与该节更新结论冲突。这里服从新版结论，直接参考重绘，避免将旧高清图的柔光缩成杂色。

本单先审样再铺开，不为了填满54格复制待机冒充动作。行走按方案是48格；64格基准用于战斗。

## 提示词与工具

使用内置 image_gen，透明背景选项为 true，没有调用付费 API/CLI。三类母图分别生成，战斗另做一次去雾编辑；以下记录生成规格和实际使用的提示要点（英文表述整理，非工具原始请求逐字导出）。

共用：`Gentle young woman Yunshang, very long silver-white hair in a loose bun, gold hairpin and navy tassel, blue eyes, white Chinese robe with navy collar sash and flowing long sleeves. Keep full long robe, not short skirt. About 2 heads tall. Sharp clustered high-end 32-bit JRPG pixel art, blue violet shadows, selective dark local-color outlines, upper-left light, restrained cool rim. Large deliberate clusters, at most 3 tones per material, no dithering, texture, glow, ground shadows, text or borders. True transparent RGBA background.`

战斗参考顺序：旧图待机/攻击六帧、五条悟待机仅风格、旧头像仅身份。尾段：`Exactly 3 columns by 2 rows. Row 1 three subtle idle gestures facing left. Row 2 windup, thrust left with small cyan weaving shuttle held once, recovery. Preserve reference pose sequence, every sprite isolated with wide transparent gutters. Intended final 64x64 cells. Landscape 3:2 layout.`

去雾编辑：`Precisely preserve these six sprites, their identity design pose size layout and pixels. Remove ALL grey haze, vignette, backdrop, glow and ground shadow behind them. Only character silhouettes should have alpha, everything surrounding them must be alpha zero including gaps between sleeves and body. Crisp opaque pixel-art sprites on completely transparent background. No haze whatsoever. Keep exact 3 columns 2 rows sheet.` 生成器预览仍显示雾状低alpha RGB，但128阈值后外缘干净；没有把雾当人物保留。

行走参考顺序：旧行走全图、五条悟待机仅风格、旧头像身份。尾段：`Exactly twelve sprites, 3 columns 4 rows. Row1 facing down left step stand right step. Row2 facing left step stand opposite step. Row3 facing right step stand opposite step. Row4 facing back with NO face step stand opposite step. Equal regularly spaced cells generous transparent margins. Intended final 48x48 per cell. All foot baselines equal. Portrait 3:4 sheet.`

头像只参考旧头像：`Redraw same woman in clean anime cel-shaded bust portrait, head and upper shoulders. Body turned slightly viewer left eyes toward viewer, gentle confident smile. Clean dark line art flat colors exactly one hard edged shadow tone small highlights hair and eyes only. Upper left light. No gradients no painterly texture no glow no particles. Fully transparent RGBA background nothing behind character. Head top near upper edge shoulders cut by bottom centered. 1024 square single character no text no frame.` 实际母图1254方形，按144格导出。

## 后处理与未做到的部分

按方案4.3记录：①检查alpha，母图有真实透明，战斗低alpha雾经阈值清掉；②切格并查跨格，行走生成行距不等，人工指定y边界0/350/700/1050/1448后通过，未机械均分；③行走共用倍率，站姿46px，宽约33；战斗待机60px；④先BOX到目标4倍，再BOX到目标；⑤样板统一脚底y=45/61、水平居中，没有逐格复刻旧图偏移；⑥精灵alpha只0/255；⑦不硬量化；⑧四邻一致孤点清理；⑨原图已有选择性描边，未自动补边，以免白发轮廓增粗；⑩拼标准图，SV只拼本次六帧；⑪原大、4倍、并排及动作GIF已出，未出新旧对照GIF。

**需继续改进**：攻击伸梭总宽会挤出64格，所以攻击组三帧共用较小倍率（可见高53px），待机组三帧共用60px倍率；这偏离“同母图统一倍率”，动画切换会显小，正式扩动作前应重出更紧凑的攻击姿势，不能直接投入游戏。行走发髻顶边无透明余量，但没有裁失像素。头像仍有多于一层局部阴影，未完全满足严格单阶赛璐璐。行走裙摆比旧图显短，待 Kyo 审样。没有生成图标与装备，本单不含它们。

## 验证与交付

`build.py` 成功运行，逐格透明外接框检查通过，输出见 validation.json。人工查看行走4倍与五人并排图；待跨模型美术审查与 Kyo 拍板，未自标定稿。无游戏代码修改，不跑Godot全量，工程逻辑与接线交总装后续处理。生成产物只在本目录，旧素材保持原样。

工具快速回归22项全部通过（102秒）；尺寸、SV非空六格、二值alpha专项断言通过，git暂存差异空白检查通过。
