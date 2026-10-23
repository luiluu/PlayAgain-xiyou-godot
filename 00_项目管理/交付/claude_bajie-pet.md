# 交付：claude/bajie-pet

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_56）
- 状态：可合并

本分支分两期：期一＝法宝图标等级字（本单，先交）；期二＝宠物系统菜单侧，期一合并后再做，规模与分期届时写在接续交付单。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_56·未经Codex检验】法宝图标等级字补全（dev.待定）

- **范围照原版核实**：CP_MagicWeapon 包的是 Window_Base.drawItemName（法宝在图标上写等级：16 号、textColor 12，`(x+2)+14`、`(y+2)−8`、宽 textWidth("00") 靠右）。参照里逐个窗口类查了 drawItemName 走哪条：**走 Window_Base 那条、会画的**是商店买入列表、装备槽、物品详情头（Window_ItemInfo）、怪物图鉴掉落、制作配方列表（后两处 dev.139／dev.142 已画）；**物品列表一系**（物品页、商店出售、装备候选、战斗物品）有自己的 drawItemName 链（品质色等包装），原版**不画**，所以不补。仓库（Star_Warehouse）重制还没有，不涉及。
- **补的三处**：商店买入列表（`ui/shop.gd`，含售完行）、装备槽（`ui/equip_scene.gd`）、物品详情头（`ui/item_scene.gd` paint_info）；共用 `XItemRow.paint_magic_level`。照原版的副作用：画完等级字把不透明度改回不透明（changePaintOpacity(true)），所以买不起的法宝那一行，价格与货币不再半透明（参照 shopBuy 第 0 行）。
- **参照与测试**：`tests/fixtures/magic_level_oracle.json`（冻结 v0.28 浏览器参照：商店 goods 防具 13 大罗剑胎、武器 73 麒麟对剑、防具 52 草帽的买入列表；角色 1 法宝槽强装大罗剑胎的装备槽；物品页选中大罗剑胎的详情头；各窗口类的 drawItemName 归属）；新专项 `xiyou_magic_level` 7 项。装备槽等级字 x 与原版差 0.21（Godot 槽名宽取整，图标本来就差这么多），测试对这一项放宽到 0.25。

## 交接板

- 下一步：本分支期二＝宠物系统菜单侧（宠物实例存档字段、列表、升级、合成、出战设定，主菜单「宠物」走公共事件 169）；捕获神秘生物（楼层事件，悟空）与宠物参战（战斗）不做，写接口与依赖。
- 用户试玩说明：商店买入列表、装备页的装备槽、物品页右侧详情里，法宝的图标左上角会显示等级数字（同原版）；物品页、出售列表照原版不显示。

## 进度账

- 界面页面：不另加（原版细节补全）

## 本分支提交

- 3799b997 法宝图标等级字补到商店买入、装备槽、物品详情头，参照与专项
- 合 main（悟空 Map186）＋补齐，交付单可合并

## 验证

- 相关专项（`并行测试.py`，11 个全过）：`xiyou_magic_level` 7/7（新）、`xiyou_shop_buy` 4936/4936、`xiyou_shop_stock` 46/46、`xiyou_gear_ui` 47/47、`xiyou_equipment` 1228/1228、`xiyou_dual_wield` 301/301、`xiyou_item_list` 38/38、`xiyou_item_marks` 108/108、`xiyou_orb_shop_ui` 27/27、`xiyou_enemy_book` 41/41、`xiyou_crafting` 43/43；合 main 并 `--补齐` 后重跑 `xiyou_magic_level`、`xiyou_shop_buy`、`xiyou_gear_ui` 仍全过。
