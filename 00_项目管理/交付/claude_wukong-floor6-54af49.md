# 交付：claude/wukong-floor6-54af49

- 车道／工作者：A 审查／悟空（Claude，重制_悟空_2）
- 位置：worktree `/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/wukong-floor6-54af49`，分支 `claude/wukong-floor6-54af49`
- 任务：进度审查 20%（界面与系统：dev.017～dev.031、dev.039）
- 状态：进行中——已审 dev.039，dev.017～dev.031 未开始；5 小时额度到 82% 时收尾（规则 90%，留余量写记录），05:00 重置后接着审

## 审查草稿

### 2026-10-15 【Claude·悟空】进度审查 20%（界面与系统，部分）

- 范围：dev.039（一键出售、出售锁定、道具置顶，八戒）已审；dev.017～dev.031 **尚未审**。
- 方法：只读对照正式 app.nw 的 Star_ShopOnekey.js、Star_ItemTop.js、installUnifiedQualityRuntime.js（sellUnifiedQuality）、YEP_ShopMenuCore / YEP_ItemCore / YEP_X_MoreCurrencies / KMS_ShopInventory 的 doSell 链、XdRs_HangUp.doSell，与 `core/item_marks.gd` 逐条比较；查正式数据库与转换产物里的卖价备注。

**发现（大问题，规则级，只记录未修）**

1. **商店卖出漏了 YEP_X_MoreCurrencies 的附加报酬**。正式版 Scene_Shop.doSellGold 被 MoreCurrencies 包了一层：先给金币，再按备注 `<Variable x Sell Price: y>` 给变量 x 加 y×数量、`<Item/Weapon/Armor x Sell Price: y>` 给对应物品 y×数量。Godot 的普通出售和一键出售（`XItemMarks.selling_price` → `gain_gold`）只给金币。
   - 影响面：正式库里 604 个物品、304 件武器、1147 件防具带这类备注（转换产物 db 里 note 都在，转换器和 Godot 都没解析）。常见的有：Variable 206（370 件防具、264 个物品）、Variable 201 不朽灵魂、Variable 199 不朽碎片、Variable 213 法宝积分、Item 188 魂灯（243 个物品，例如伙伴号角：里德/刘备/张飞，卖出各给魂灯 ×1）、Item 2898 啤酒·超大瓶。
   - 唐僧合并说明里「现切片无任何物品带 <Sell Price>」只看了 YEP_ShopMenuCore 的 `<Sell Price: n>`（确实没有），没看 MoreCurrencies 的写法。
   - 挂机自动卖出（XdRs_HangUp.doSell）在原版里只给金币、不走 MoreCurrencies，所以 Godot 挂机这边是一致的，不用改。
   - 建议：转换器解析四种 `<… x Sell Price: y>`（名字形式按「同名取 ID 最大」），出售时照 doSellGold 的顺序给报酬。按严格级先做 mv_oracle 参照：在 MV 里对若干物品/装备调用 Scene_Shop.doSell，记录金币、变量与物品变化，再逐项比对。一键出售同样走 doSell，修好普通出售也就一起修好。
   - 归属：商店出售属于界面/系统车道，按规则由唐僧派。

**观察（不改）**

2. 原版 makeItemList 的锁定、置顶判断不查类型：按 `_data[i].id` 查 ItemSpLock / TopItem，所以 ID 恰好相同的武器或防具（独立装备 ID 与物品 ID 撞上时）也会被加「[锁定]」或置顶。Godot 只对物品生效（`is_gear` 时跳过）。这算原版缺陷，Godot 的做法更合理，但没有登记成优化项；建议在 O-030 的说明里补一句，或另登记（编号由唐僧给）。
3. 一键出售的档位映射：原版 Star_ShopOnekey 写死了 15 行（Onekey6→7、Onekey7→13……），后被 installUnifiedQualityRuntime 改写成七档 `codexGrade g`，按 `Q.members(g).filter(ONEKEY)` 取旧档。Godot 的 `onekey_members` 取 0～14，与 ONEKEY（旧档 ≤14）一致；`meta.quality` 判断用 `is_valid_int`，原版用 `num()`，备注写成非整数时两边可能不同（切片里没有这种装备）。
4. KMS_ShopInventory 的 doSell 卖出时给商店加库存（买回用）。Godot 商店没有库存系统，只在有 `_inventory` 的商店生效；切片商店是否带库存没查，留作遗留。

**已修**：无（这次只发现了要先做参照的规则问题）。

**测试**：dev.039 有 `tests/xiyou_item_marks`（26 项），覆盖规则与窗口。缺一项：卖出报酬（随第 1 条一起补）。

**遗留**：①第 1 条 MoreCurrencies 卖出报酬；②第 4 条 KMS 商店库存；③dev.017～dev.031 未审（额度到 82% 停）。

**给沙僧（第 ⑤ 项完成度）**：dev.039 记的界面 57%→58% 本身合理；但第 1 条说明商店出售的规则还不完整，复核时请一并考虑。

## 本分支提交

- 审查开工交付单
- 本提交：审查草稿（部分，进行中）
