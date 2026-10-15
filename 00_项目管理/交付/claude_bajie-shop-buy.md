# 交付：claude/bajie-shop-buy

- 车道／工作者：B 规则／八戒（Claude，重制_八戒_5）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-shop-buy`
- 状态：可合并（已合 main 3dc15d6／dev.050，--补齐 后 检查.sh --oracle 全部通过）
- 任务（唐僧 2026-10-15 17:40 派）：商店用变量/物品买——YEP_X_MoreCurrencies `<Variable x Buy Price: y>`／`<Item x Buy Price: y>`：能否买、扣除、列表价格列、数量窗买入行、isDrawGoldCurrency 金币行省略。严格级参照探针逐例比对，界面标准级 ui_reference 对一张。
- 独占：ui/shop.gd 购买部分、core/item_marks.gd 价格解析、新探针与测试。预分配 O-031～O-033。

## 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】商店用变量/物品买（dev.待定）

- 照正式版补商店买入（YEP_X_MoreCurrencies）：<Variable x Buy Price: y>／<Item x Buy Price: y> 的能否买（各变量、物品都够，且金币够）、最多买几个（物品 9999−持有、独立装备 1，再按金币与各变量/物品取整）、扣除（金币、变量、物品×数量）；<Proxy Buy: x> 买到代购件（列表显示代购件名字图标，状态窗显示其持有数）。之前 Godot 只扣金币，这些商品基础价多为 0，等于白拿。
- 正式版 Scene_Shop.prepare 对商品表的改写（切片商店用到的）：Codex_PercentPills 商品里有 1693 时追加百分比药丸 2882～2887；installNativeRaceRuntime 旧版祝福进阶石换成正规 ID 并去重；installImportedBalanceRuntime 滤掉停用号角。进阶石另按进度层数（变量 20−1）解锁。
- 界面：购买列表价格列从金币左边画变量/物品买入价（数据库价格 0 时不画金币），买不起变灰；数量窗买入时画变量/物品三行（现有、−数量×单价、结算），有这类价格且数据库价格 0 时省略金币三行；金钱窗跟随选中商品画货币持有，同样省略金币。
- 严格级参照：新探针 mv_oracle/shop_buy_probe.cjs（已加进 PROBES）：切片 130 家店经正式 prepare 后 462 件商品 × 持有状态，记 isEnabled／maxBuy／doBuy 变化。标准级：ui_reference 浏览器记录正式版价格列、数量窗买入列、金钱窗的绘制调用。tests/xiyou_shop_buy 全部逐项比对。
- 验证：合 main 3dc15d6（dev.050）、--补齐 后 `检查.sh --oracle` 全部通过（48 项；xiyou_shop_buy 2571/2571、xiyou_item_marks 107/107）。
- 提交：86f280d、3a108aa、784bf39、9bbf147、f3bed19、8352603、0f8b51d、cd00fa1、160f299（合 main）及交付提交
- 未移植（切片商店新游戏状态下都不受影响，探针已证）：超强者伙伴号角限地狱及以上、轮回随机阵容限制、KMS_ShopInventory 库存、Map132 号角商店追加新伙伴号角、撤下宝珠。正式版获得旧版进阶石（任何途径）都换成正规 ID（Game_Party.gainItem），共用的 XState.gain_item 未改。
```

## 交接板

- 下一步：删掉「商店用变量/物品买」条目。可新增（待派，非本车道）：获得旧版进阶石时换成正规 ID（XState.gain_item，共用文件）；百分比药丸服用效果是否已实现待查。
- 用户试玩说明：大厅等商店里要用积分或材料买的商品，现在会显示并扣除对应积分／材料，不够时灰掉不能买（与原版一致）；买入数量窗显示积分／材料的现有、扣除与结算。
- 需要用户决定：无。O-031～O-033 未用。
- 待交叉核查：本分支提交（八戒）——核查重点：shop_goods 的改写顺序；can_buy 未移植的几层是否真的不影响切片；金钱窗跟随商品的清空时机（购买取消清、出售取消不清）。

## 进度账

- 规则缺口修补，不单独加进度（照实记初值，由沙僧复核）。

## 停在哪里（重制_八戒_5）

- 已做（严格级，xiyou_shop_buy 2567/2567）：
  - 参照探针 `mv_oracle/shop_buy_probe.cjs`（已加进同步正式西游.py 的 PROBES，输出 shop_buy.json）：切片 19 张图 130 家店经正式 Scene_Shop.prepare 后的 462 件商品 × 持有状态（全空／刚好够／差 1／很富，进阶石另量变量 20 前后），记 Window_ShopBuy.isEnabled、Scene_Shop.maxBuy、doBuy 前后变化、MoreCurrencies 买入价解析与代购。
  - `XItemMarks`：sell_rewards 加 buy_vars／buy_items；shop_rec、proxy_buy、shop_display、shop_goods（药丸 1693 追加 <CodexPill>、旧进阶石按 CodexRaces.legacyItems 换算并去重、滤停用号角）、stone_locked（进阶石按进度层数＝变量20−1）、can_buy、max_buy（物品 9999−持有，独立装备 1）、buy（扣金币、变量、物品，得到商品或代购件）。
  - 商店界面：购买列表用 shop_goods、按 can_buy 变灰、价格列从金币左边画变量/物品买入价（数据库价格 0 时不画金币）；数量窗买入时画变量/物品三行（现有、−数量×单价、结算），有这类价格且数据库价格 0 时省略金币三行；金钱窗跟随选中商品画货币持有（购买取消时清空）；代购商品显示代购件名字图标、持有数。
- 已做（标准级）：ui_reference 浏览器里跑正式版商店（金币 12,345、变量 206=5000、物品 182×400、2201×50；商品 2230／4375／732），记录购买列表价格列、数量窗买入列（×2）、金钱窗的 drawText／drawIcon；xiyou_shop_buy 逐项比对（4 项全过，共 2571/2571）。截图未落盘（参照服务截图写入与 Godot 窗口模式都没成功），对照以绘制调用为准。
- 交付（5 小时额度重置后）：合 main 3dc15d6、--补齐、检查.sh --oracle 全部通过。
- 发现、未移植（切片商店新游戏状态下都不受影响，探针已证）：超强者伙伴号角限地狱及以上（installBossDifficultyRuntime）、轮回随机阵容限制、KMS_ShopInventory 库存、Map132 号角商店追加新伙伴号角、installNativeOrbRuntime 撤下宝珠；另外 installNativeRaceRuntime 把**获得**旧版进阶石（任何途径）换成正规 ID（Game_Party.gainItem），XState.gain_item 是共用文件，未改，商店里已经不会买到旧 ID。
- 百分比药丸 2882～2887 现在能买到，但服用效果（Codex_PercentPills 角色属性加成）Godot 是否已实现未查。

## 本分支提交

- 86f280d 开工交付单
- 3a108aa 买入参照探针
- 784bf39 买入规则与 xiyou_shop_buy
- 9bbf147 商店界面接买入规则
- f3bed19 WIP 交付单
- 8352603 标准级界面对照
- 0f8b51d WIP 交付单
- cd00fa1 交付单草稿
- 160f299 合并 main（3dc15d6，dev.050）
- （本提交）交付单可合并
