# 交付：cc/bailong-yunshang10

- 车道／工作者：E 角色专属／白龙_12（cc）
- 状态：可合并（在 yunshang9 之后合）
- 分支从 cc/bailong-yunshang9 末端 e089eb11 切出（总装十派单），**包含 yunshang9**，那张交付单照它自己的合。yunshang9 还没进 main，没合 main（总装十一：第六批推送后通知再合）。
- 范围：XState 加「装备离开背包」的统一出口 `lose_gear`；领取的云裳天衣被卖出、存进方桌仓库、分解时记进订单账本（原版 gainItem 包装），堵住「领取→卖掉→读领取前的档再领」。

## 变更记录草稿

## 2026-11-01 【cc·白龙_12·未经审查】装备离开背包统一出口；卖掉领取的天衣记进云裳订单账本（dev.待定）

照原版 installNativeYunshangRuntime.js 第 200～204 行（Game_Party.gainItem 包装）：

1. **统一出口** `XState.lose_gear(item, record := true)`：从背包拿掉这件实例。`record` 表示这一件是直接被失去的（原版 `$gameParty.loseItem(这件)`）；带 `_yunUid` 的云裳天衣这时记一条移除进订单账本（`XYunshangOrders.lost`，重放时由账本把它拿掉）。账本不可用时照常拿掉（原版会抛错、卖不掉）。
2. **改走出口的地方**（盘点见下）：商店卖出与一键出售 `XItemMarks.sell`（记）、方桌仓库存入 `XWarehouse.deposit`（PH_Warehouse 是 loseItem，记）、异化分解 `XAlienation.dismantle`（loseItem，记）、星级仓库存入 `XStarWarehouse.deposit_gear`（原版直接改 `$gameParty._armors`，不记）、按底子扣 `XState.gain_gear` 负数（事件增减防具、合成材料：YEP 的 getMatchingBaseItem→removeIndependentItem 不经这一件的 gainItem，不记）。
3. **照原版不记**：穿上、卸下（XEquipment.change，原版 tradeItemWithParty 设了 _yunEquipTrade）；专属角色招募时把法宝从背包装上（guyu、sukuna、toji、mira、garou、cat、yomi_jingliu 的招募，都是交换，没改，仍直接 `remove_at`）。
4. 效果：领取的天衣卖掉、存进方桌仓库或分解后，再读领取前的档，重放先发后移除，背包里没有；按底子扣、存进星级仓库的，读领取前的档照原版还在。
- 参照：`yunshang_probe.cjs` 加 p8.lose.sell／p8.lose.base（领取→穿上→卸下→loseItem(这件)／gainItem(底子,-1)→读领取前的档）。

## 盘点：直接改背包装备的地方（rg `gear.remove_at|gear.erase`）

| 地方 | 做什么 | 处理 |
| --- | --- | --- |
| `core/xstate.gd` gain_gear 负数 | 按底子扣（事件、合成、mv_script） | 走出口，不记 |
| `core/item_marks.gd` sell | 商店卖出、一键出售、挂机卖出 | 走出口，记 |
| `core/warehouse.gd` deposit | 方桌仓库存入 | 走出口，记 |
| `core/alienation.gd` dismantle | 异化分解 | 走出口，记 |
| `core/star_warehouse.gd` deposit_gear | 星级仓库存入（跨档） | 走出口，不记 |
| `core/equipment.gd` change | 穿上（背包→身上） | 不改（交换） |
| guyu／sukuna／toji／mira／garou／cat／yomi_jingliu 的招募 | 把法宝从背包装上 | 不改（交换） |
| `core/yunshang_orders.gd` remove_uid | 账本重放的移除 | 不改（出口内部用） |
| `core/star_warehouse.gd` 107 行 | 星级仓库取出（仓库里的列表） | 不是背包，不改 |

## 优化登记草稿

无。

## 验证

- 专项 xiyou_yunshang_shop 362/362（多 83 项）：p8.lose 四种——卖出（XItemMarks.sell）、方桌仓库存入（比参照的卖出那组，另查仓库里有这件）记移除，读领取前的档背包里没有、_yunSeq 3；按底子扣（s.gain_gear 负数）、星级仓库存入（比参照的按底子那组）不记，读档照样在；两组都先穿上再卸下（不记）。
- 反向验证 5 处全抓到：卖出不记、按底子也记、方桌仓库不记、星级仓库也记、出口不看天衣。
- 语法检查通过。
- 选测：`选测.py e089eb11` 因为改了 xstate.gd 选中 295 个（等于全量），车道不跑全量；改跑引用了改动模块的场景＋商店／挂机／物品／事件类，39 个写全名（CHECK_JOBS=3，和别的车道共用测试槽，51 分钟）全过、没有偶发：xiyou_actor_modules、xiyou_alien_affix、xiyou_alien_battle、xiyou_alien_config、xiyou_alien_workshop、xiyou_attack_query、xiyou_battle_ui、xiyou_bulk_pills、xiyou_common_scripts、xiyou_crafting、xiyou_event_compare、xiyou_gold_cap、xiyou_hangup、xiyou_hangup_auto、xiyou_hangup_options、xiyou_item_bag、xiyou_item_list、xiyou_item_marks、xiyou_item_use、xiyou_jingliu2、xiyou_map132_shop、xiyou_party_skills、xiyou_review_fixes、xiyou_script、xiyou_shop_auto_close、xiyou_shop_buy、xiyou_shop_stock、xiyou_star_warehouse、xiyou_super_acquire、xiyou_super_deploy、xiyou_system_evidence、xiyou_toji、xiyou_warehouse、xiyou_weapon_unleash、xiyou_yunshang、xiyou_yunshang_shop、xiyou_yunshang_ui、xiyou_equipment、xiyou_flow。

## 交接板

- 下一步：云裳剩下的都是显示：① 天衣、技能 10270～10287、号角、织神天梭、不朽天丝的图标（Yunshang_Icons，CodexQualityIcons.lookup 的 210012～210014 与技能映射，第 594～603 行）；② 织神天梭的显示（按等级成长的八项 relicDisplayParams、说明里「当前等级／法宝经验」两行，第 606～640 行）；③ 天衣说明文字刷新（refreshYunshangText：说明行照模板的 APs、去掉旧版行，第 641～653 行）与天衣名字粉色（第 664～672 行）；④ 针眼可选列表为空时原版也没有提示，重制照样空页（可考虑提示）。招募发的织神天梭原版也进账本（防读档再招募再领），重制一期按存档旗标，没改。
- 用户试玩说明：领取的天衣卖掉、存仓库或分解后，读领取之前的存档也不会再出现（照原版）；存进星级仓库的照原版不算。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：云裳完成度 0.97 → 0.98（卖天衣记账；剩图标与说明显示），按工作量估。

## 可优化（流程／工具／效率）

- 发现（工具）：`选测.py` 把 xstate.gd 的任何改动都算 game 组，引用它的场景 270 个，加一个函数就等于全量；可以考虑给 xstate.gd 按改动的函数名收窄（只找调用了新／改函数的测试），建议派给哪吒。

## 待交叉核查

- 共用核心文件：`core/xstate.gd`（新 `lose_gear`；`gain_gear` 负数改走它）、`core/item_marks.gd`（sell）、`core/warehouse.gd`（deposit）、`core/star_warehouse.gd`（deposit_gear）、`core/alienation.gd`（dismantle）。行为上只有带 `_yunUid` 的天衣多记一条账本，其余照旧。
- `core/yunshang_orders.gd`：`lost`。
- 留意：方桌仓库存入天衣也记移除（PH_Warehouse 就是 loseItem），所以存进去之后读更早的档，那份档里的天衣也没了——原版如此；不想要的话可以改成存仓库不记（登记优化）。

## 本分支提交

- 前面同 yunshang9（到 e089eb11）
- WIP：出口、p8.lose、专项 362/362
- 本提交：选测全过，交付单可合并
