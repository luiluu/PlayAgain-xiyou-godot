# 交付：luiluu/orb-fx-bright-wire（T062，D121）

- 车道／工作者：cc（Sonnet 5.5＋medium，职级 P6），把小o 的七印、双星加亮画法移植进正式类。
- 状态：可合并
- 范围：`skin_orb_fx.gd` 的 image() 里 seal7、stars 两支；专项 `xiyou_tianqi_ring_style` 加 4 项断言。微光、灵焰、接口、缓存、帧数、STILL 均未动；`content/orb_fx_bright/` 草稿未带入。

## 变更记录草稿

## 2026-11-16 【cc·未经审查】球框七印封缄、双星巡轨改用加亮画法（dev.待定）

按 D121 定稿，把小o 在 gpt/orb-fx-bright（e8095236d）的加亮草稿移植进 XSkinOrbFx：七印 3×3 源字形每像素放 2×2、中心半径 23.5、七色提亮 22%、深蓝 171c32 四邻域 1px 描边、内圈四点半径 20 色 e2fff6；双星轨道 2px（96 采样、12 取 7）、拖尾提亮 25%、5×5 菱形星头、全部深蓝 1px 描边。64×64、中心 32、半径 28 硬裁切、二值 alpha、36 帧、STILL=9 不变。
- 玩家可见：装备页球框的七印封缄、双星巡轨更亮、更清楚。

## 验证

- 专项 `xiyou_tianqi_ring_style` 172/172 通过（含新增 fxbright_seal7/stars_36frames_clean、fxbright_*_has_navy_outline、fxbright_stars_head_centre_warm、fxbright_seal7_inner_dot；原有 fxframe_*_binary_alpha／within_28／no_red／animates 对 seal7、stars 仍过）。
- 36 帧条（seal7_36frames、stars_36frames）与小o 草稿产出逐字节一致；装备页暗图、亮图（图标同为 47／272 号）与小o 的 *_bright_dark／*_bright_light 逐像素一致，唯一差异是右下角 17×13 像素的版本角标，与球框无关。
- 截图（本地，已 gitignore）：`03_再刷重制_Godot/04_验证/本地结果/T062_shots/`，含 seal7／stars × bright_dark／bright_light（原尺寸与 4x）、36frames 条。

## 我不同意的地方

无。小o 提到的「双星覆盖面积变大、偏法器光环」是已定稿取舍，照搬。

## 交接板

- 待交叉核查：画法与小o 草稿一致性（可对照 draft.gd）；触屏尺寸未另截图。
