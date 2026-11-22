# 交付：luiluu/t379

- 车道／工作者：T379 七印 O1 规则图标、O2 套装武器效果图标接界面（K3）／cc（Sonnet 5.5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-22 【cc·天启篇·未经审查】T379 七印 O1 规则图标进祭坛「怎么玩」弹窗、O2 效果图标进装备说明卡（dev.待定）

- O1：`XTianqiSkinAltar.seal_rows` 每印带 `rule_icon`（`XTianqiQiyinArt.rule_icon(rule)`，键＝`qiyin_altar.json` 各印的 `rule`，310500 起 7 张）；祭坛「怎么玩」弹窗里当前印的规则行前画 48 格图标（32 格原图最近邻放大一倍），文字缩进让位。
- O2：8 个效果在战斗里没有 XState 状态对象（全是 `XTianqiQiyinEffects` 的单位内部计数），状态栏没有可挂图标的东西，所以走验收允许的「说明卡带图标」：`XTianqiQiyinArt.fx_text(fx)` 给疫、砝码、判决、陨月、天书页、连斩、缓期（效果码 `plague_stack`、`weight_stack`、`judgment`、`star_moon`、`star_pages`、`kill_chain_slash`、`cheat_death`）的效果文字前缀 `\I[3106xx]`；`XTianqiQiyinEquip.describe`／`make_artifact` 的效果行改调它。**龙血（310607）只映射键 `dragon_blood`，没接线**：它没有装备效果码，是龙隙奖励。
- 回退：`XTianqiQiyinArt.ENABLED = false`（O-366 原开关）＝规则图标不画、说明卡效果文字回原文。
- 玩家可见：七印祭坛规则弹窗里规则行前多一张图标；七印套装、武器说明卡里疫／砝码等效果前多一张小图。（文字不新增，不涉及待小A 审。）

## 交接板

- 下一步：K1b（战中规则条）可直接用 `XTianqiQiyinArt.rule_icon`；O2 若要战斗状态栏图标，需先给这些效果建状态对象，另开卡。
- 用户试玩说明：天启篇七印祭坛点「怎么玩」，选中一印能看到规则图标；七印装备说明卡里的疫、砝码等效果带小图。
- 需要用户决定：无。

## 进度账

- 部分：天启篇界面（七印 O1/O2 图标接线）；不改完成度数字，由项目经理cc 按卡折合（K3 卡面 +0.35）。

## 可优化（流程／工具／效率）

- 建议：旧皮肤（`XUiSkin` 关）祭坛没有页，规则只在 `XTianqiQiyin.choose_and_run` 进入时的一句消息里（`tianqi_qiyin.gd:356`），要加图标得改那一行（第 5 个文件，本单没动），归界面车道，约 10 分钟。

## 验收（派单 6 条）

1. ✓ 7 张，专项 `o1_rule_icons_in_altar_rows` 核键、号、图。
2. ✓（走说明卡）专项 `o2_effect_icons`、`o2_fx_text`、`o2_in_item_desc`、`o2_desc_off_plain`；战斗状态栏图标做不了，见上。
3. 部分：新皮肤 16:9／20:9 截图在 `00_项目管理/归档/交付截图/T379_七印图标/`；旧皮肤没有祭坛页，没有可截的 O1 画面（见可优化）。说明卡截图没拍。
4. ✓ 所有改动都在 `XTianqiQiyinArt.ENABLED` 与天启篇装备／祭坛页里，西游档不经过。
5. ✓ 专项 xiyou_tianqi_qiyin_art 68/68。
6. ✓ 云端选测 15 场景 3 片通过（提交 ca87ca518b，run 45029795176，gh run watch 前台等完）；交付自检结论「可以交付」；发行空壳 check 通过。

## 本分支提交

- 见 git log（T379）
