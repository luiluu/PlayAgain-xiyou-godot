# 交付：claude/bajie-shop-buy

- 车道／工作者：B 规则／八戒（Claude，重制_八戒_5）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-shop-buy`
- 状态：进行中
- 任务（唐僧 2026-10-15 17:40 派）：商店用变量/物品买——YEP_X_MoreCurrencies `<Variable x Buy Price: y>`／`<Item x Buy Price: y>`：能否买、扣除、列表价格列、数量窗买入行、isDrawGoldCurrency 金币行省略。严格级参照探针逐例比对，界面标准级 ui_reference 对一张。
- 独占：ui/shop.gd 购买部分、core/item_marks.gd 价格解析、新探针与测试。预分配 O-031～O-033。

## 停在哪里（重制_八戒_5）

- 已做（严格级，xiyou_shop_buy 2567/2567）：
  - 参照探针 `mv_oracle/shop_buy_probe.cjs`（已加进同步正式西游.py 的 PROBES，输出 shop_buy.json）：切片 19 张图 130 家店经正式 Scene_Shop.prepare 后的 462 件商品 × 持有状态（全空／刚好够／差 1／很富，进阶石另量变量 20 前后），记 Window_ShopBuy.isEnabled、Scene_Shop.maxBuy、doBuy 前后变化、MoreCurrencies 买入价解析与代购。
  - `XItemMarks`：sell_rewards 加 buy_vars／buy_items；shop_rec、proxy_buy、shop_display、shop_goods（药丸 1693 追加 <CodexPill>、旧进阶石按 CodexRaces.legacyItems 换算并去重、滤停用号角）、stone_locked（进阶石按进度层数＝变量20−1）、can_buy、max_buy（物品 9999−持有，独立装备 1）、buy（扣金币、变量、物品，得到商品或代购件）。
  - 商店界面：购买列表用 shop_goods、按 can_buy 变灰、价格列从金币左边画变量/物品买入价（数据库价格 0 时不画金币）；数量窗买入时画变量/物品三行（现有、−数量×单价、结算），有这类价格且数据库价格 0 时省略金币三行；金钱窗跟随选中商品画货币持有（购买取消时清空）；代购商品显示代购件名字图标、持有数。
- 未做：界面标准级 ui_reference 对一张（大厅 Map004 EV054 的变量价商店：列表价格列、数量窗买入行、金钱窗）。
- 发现、未移植（切片商店新游戏状态下都不受影响，探针已证）：超强者伙伴号角限地狱及以上（installBossDifficultyRuntime）、轮回随机阵容限制、KMS_ShopInventory 库存、Map132 号角商店追加新伙伴号角、installNativeOrbRuntime 撤下宝珠；另外 installNativeRaceRuntime 把**获得**旧版进阶石（任何途径）换成正规 ID（Game_Party.gainItem），XState.gain_item 是共用文件，未改，商店里已经不会买到旧 ID。
- 百分比药丸 2882～2887 现在能买到，但服用效果（Codex_PercentPills 角色属性加成）Godot 是否已实现未查。

## 本分支提交

- 86f280d 开工交付单
- 3a108aa 买入参照探针
- 784bf39 买入规则与 xiyou_shop_buy
- 9bbf147 商店界面接买入规则
- （本提交）交付单写停在哪里
