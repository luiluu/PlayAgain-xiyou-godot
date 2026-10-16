# 交付：claude/bajie-item-list

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_9）
- 状态：可合并（检查.sh 结果见下）

## 变更记录草稿

## 2026-10-16 【Claude·八戒·未经Codex检验】物品列表一组：NEW 角标、「序号/9,999」、战斗物品窗口（dev.待定）

- 唐僧续派交接板第 5 项「物品列表一组」，按沙僧协助预检的定位先核对已有接入边界、不重写通用绘制。验证分级「标准」：用 ui_reference 新夹具 `?item_list_ref=1`（冻结 v0.28，内存新局，浏览器静音）取正式版运行时读数，存 `tests/fixtures/item_list_oracle.json`，新测试 `xiyou_item_list` 逐项比对（窗口模式 39 项含截图）。
- 正式版读数要点：
  - NEW（Galv）：物品页、装备页候选在列表激活时光标停上去即记看过，这一行等光标移开或列表失去焦点才重画——Godot 原有 `_pending_seen` 做法与之一致，保留；**类型 0 的装备**（如水果刀 wtypeId 0）Galv 认不出类型，从不画 NEW、也不记看过，Godot 原来会画 → 加 `XItemRow.new_tracked／shows_new`；同 ID 物品再得仍旧、同基础新实例为新、实例 ID 不复用、随存档（已一致）。**商店出售列表**画 NEW 但从不记看过（Window_ShopSell 不走 Galv 的 updateHelp），Godot 原来不画 → 接 XItemRow。**战斗物品窗口**不画 NEW 也不记看过（Olivia 换了 drawItemName，HelpExtend 直接赋了 updateHelp），Godot 已一致，补测试。
  - 「序号/9,999」：序号是在 `$gameParty.weapons()/armors()` 里的位置，YEP independentItemSort **按基础 ID**、同基础按实例先后；Godot 原来只按实例先后 → `XItemScene.bag_gear` 改排序（物品页、装备页、商店出售共用）。筛选（仅背包＋武器类型、仅已装备）、Codex 排序、换装后都不按显示序重编，身上的写角色名，读数与 Godot 逐行一致（含 Codex 默认排序的显示顺序）。商店出售列表不列身上装备、不走 Codex 排序，按背包原序写序号（Godot 原来按获得先后且不写序号 → 改）。
  - 战斗物品窗口（Window_BattleItem）：makeItemList 同样经 Star_ItemTop／Star_ShopOnekey → 改用 `XItemMarks.apply_list`（`XBattleScene.battle_item_order`；置顶逐个移到最前，名字带「[置顶]」「[锁定]」，O-030 只画在列表里，行动与说明卡用原记录）；不走 Codex 装备排序；名字宽改扣「×0,000」（原来扣「000」，文字区 30 起宽 315.56）、数量「×n」改千分位；打开时选上次用过的物品（selectLast，已一致）；PageUp/Down 照 Window_Selectable 只在还有下一页／上一页时翻，全部放得下时不动（原来会继续移光标）→ `XBattleList.page`（技能列表同用）。窗口 5 项 450×167、20 项 450×486（16 行）与正式一致。
- 文件：`ui/item_row.gd`、`ui/item_scene.gd`、`ui/equip_scene.gd`、`ui/shop.gd`（只改出售列表的行与装备顺序）、`battle/battle_scene.gd`、`battle/battle_list.gd`；`ui_reference/mac-preload-shim.js` 与 README；`00_设计/界面风格.md`；测试 `xiyou_item_list`（新）、`xiyou_battle_ui`（补置顶锁定顺序与不记看过）。
- 未用预分配的 O-033／O-039／O-041（本轮全部照原版，没有新的优化项）。
- 验证：专项 xiyou_item_list 39/39（窗口模式含截图）、xiyou_battle_ui 37/37、xiyou_gear_ui 46/46、xiyou_item_marks 107/107、xiyou_gear_search 57/57、xiyou_shop_buy 2935/2935；合并 main 后 `检查.sh` 全部通过；正式版截图 `04_验证/本地结果/原版参照/物品列表一组/`（item_weapon_new_carry、battle_item_window_20，PNG 头已查），Godot 截图 `04_验证/本地结果/物品列表一组_Godot/item_weapon_new_carry.png` 与正式版目视一致。
- 提交：2c86e4c、dc25346、8712819、46a83a0（及合并 main）
- 未完成／已知问题：战斗物品窗口的说明卡标题、宝珠镶嵌、主菜单灰显、设置余项不在本轮。

## 交接板

- 下一步第 5 项「逐页复现原版界面」：删去「NEW 角标与「序号/9,999」；战斗物品窗口做时接 `XItemMarks.apply_list`」一句，改为「物品列表一组已做（dev.待定：NEW 类型 0 不画、出售列表画 NEW 不记、序号按基础 ID 原序、战斗物品窗口置顶锁定与翻页）」；界面清单下一项建议：宝珠镶嵌（要随宝珠规则）或主菜单灰显逐项恢复。
- 待交叉核查加一行：本分支 4 个提交＋合并提交，执行者 Claude（八戒），核查 Codex。
- 用户试玩说明：物品页、装备页里水果刀这类「无类型」武器不再显示 NEW；装备右侧的「序号/9,999」改按装备种类（基础 ID）排；商店出售列表也显示 NEW 和装备序号；战斗中物品列表置顶的物品排在最前、名字带「[置顶]」「[锁定]」，数量带千分位，翻页键在一页放得下时不再乱跳。
- 需要用户决定：无。

## 进度账

- 界面页面：完成度 64% → 65%（建议初值，待沙僧复核），依据：物品页／装备页／商店出售／战斗物品四个列表的 NEW 与携带序号按正式运行时读数补齐，战斗物品窗口接置顶锁定与翻页规则；属已复现页面上的细节补齐，按约 0.3 页计。

## 本分支提交

- 2c86e4c 开工：建交付单
- dc25346 ui_reference 加 item_list_ref 夹具，存正式版读数（item_list_oracle.json）
- 8712819 NEW 类型判定、序号按基础 ID 原序、出售列表接 XItemRow、战斗物品窗口接置顶锁定与翻页
- 46a83a0 界面风格与 ui_reference README
- 合并 main（a66f807 沙僧工具车道，未涉及切片／转换器／探针，无需补齐）

## 检查

- 合并 main 后 `检查.sh`（worktree 并行 2）全部通过：各场景与工具回归全绿（含新 xiyou_item_list）。本分支未改战斗规则，未加 `--oracle`。
