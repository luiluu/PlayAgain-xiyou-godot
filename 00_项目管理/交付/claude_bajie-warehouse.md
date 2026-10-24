# 交付：claude/bajie-warehouse

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_65）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】大厅三界面期一：装备镶嵌图鉴（dev.待定）

- 新界面 `ui/inlay_book.gd`（XInlayBook）复现 Star_EquipInlayBook 的 Scene_EquipInlayBook：方桌大厅魂灯商人 Map4 EV40 p1／p3「查看图鉴」（插件指令 `StarEIBook GetAll` 后 `SceneManager.push(Scene_EquipInlayBook)`）打开。类型窗 (0,0,320,100)「武器／防具」、目录窗 (0,100,320,620) 16 行、状态窗 (320,0,960,720)；武器 117 项、防具 115 项（Star_EquipmentMosaic 配方，即 XDB Runewords）。状态窗画模板八项能力（原版 textWidth 空格算式定横坐标）、模板备注 `<pos … text=…>` 的符石说明（drawTextEx 逐字、`\c[n]`、zidonghuanhang 换行、全伤→全属性伤害）、需求类型、镶嵌顺序（宝珠 drawItemName 每行 4 个）。操作：类型确定列目录并选第 1 项、目录无确定、取消清空目录与状态窗回类型窗、PageUp/PageDown 翻页、鼠标点选／滚轮／右键取消。
- 解锁：原版 `$gameParty.StarEMosaicOpt` 记形成过的符文之语，未形成的写「？？？」；但正式版三处入口（Map4、Map66、Map137）都先 GetAll，玩家永远看到全部，所以不新增存档字段、全部列出，`StarEIBook GetAll／RomGet` 认作无操作。
- 接线：`mv_script.gd` 认 `SceneManager.push(Scene_EquipInlayBook)` → `map_scene.gd` 新增 `open_inlay_book`；`mv_event_core.gd` 认 `StarEIBook`。
- 参照：`ui_reference/review_system_pages.js` 新增 `inlay_book` 页（4 个截图状态）与 `__sysRef.inlayAll()`（逐项读状态窗 drawText／drawIcon），`review_system_pages.cjs --inlay-all` 写出；压成 `tests/fixtures/inlay_book_oracle.json`。成对截图（原版／Godot 各 4 张）在工作树 `04_验证/本地结果/原版参照/大厅三界面/`，目视版面一致。
- 事件对照基线删 m4e40p1／p3（7 例 → 5 例），`xiyou_event_compare` 记录宿主补 `open_inlay_book`。
- 验证：`xiyou_inlay_book` 19/19（232 项状态窗逐条对照，坐标容差 0.15：类型名逐个累加 textWidth，Godot 与浏览器小数字宽每个差约 0.01）；`xiyou_event_compare` 5/5。

## 交接板

- 下一步：大厅三界面期二（仓库，Map4 EV8）、期三（更衣，可砍）由八戒_65 继续。
- 用户试玩说明：方桌大厅魂灯商人（第 15 层后出现）「查看图鉴」现在打开装备镶嵌（符文之语）图鉴。

## 进度账

- 界面：大厅未接界面 3 → 2（装备镶嵌图鉴已接）

## 本分支提交

- b503c77a 装备镶嵌图鉴 XInlayBook：原版浏览器参照、入口接线、专项
- （本提交）事件对照基线删 m4e40p1／p3、交付单

## 追加：期二（仓库·装备道具仓库）

### 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】大厅三界面期二：装备道具仓库（dev.待定）

- 查清生效链：Map4 EV8「装备道具仓库」走 PH_Warehouse（`PHWarehouse create <仓库:999>`／`show <仓库>`，参数 All Together 0、Stack Item Quantity 0）；Star_Warehouse 是另一套跨存档「通用仓库」（名字须为「通用仓库」，正式版事件没有用到），不覆盖 PH 的窗口；Mehmet_Warehouse 未启用；「角色仓库」是 Star_ActorWarehouse（另一界面，见下「未做」）。
- 新 `core/warehouse.gd`（XWarehouse）：create（容量缺省或 ≤0 为 50、已存在不动）、show、remove（「重置仓库」＝remove＋create，里面的东西清掉）、存入／取出一件、容量按件数、物品 9999 时取不出（仓库不变）。武器、防具是独立装备，仓库直接存实例（原版存实例 ID，实例仍留在数据库里），取出回到背包是同一件。
- 新存档字段 `XState.warehouses`（存档键 `phwarehouse`，同原版 contents.phwarehouse），旧档没有为空；读档时仓库里的装备实例也登记编号，新得到的装备编号不重复。当前仓库／取出储存／分类不存档（原版也是）。
- 新界面 `ui/warehouse.gd`（XWarehouseScene）复现 Scene_Warehouse：标题 (0,0,1280,64) crisisColor、选项「取出／储存」(0,64,1280,64)、分类「物品／武器／护甲／重要物品」(0,136,1280,64)、列表 (0,208,1280,440) 两列 11 行、信息「可用空间: 剩余 / 上限」(0,656,1280,64)；一格：图标、名字（品质色、宽 596−textWidth("×0,000")−36）、右侧字号 20：取出「×仓库数量」，储存为持有数（物品「×N」、装备「序号/9,999」）。储存列表同商店出售（不列身上装备、不走 Codex 排序、物品套置顶／锁定标记）。没看过的画 NEW 但从不记看过（原版这张列表没有说明窗）。分类没选中时列表为空。确定即存／取一件（装备音效，不行蜂鸣）、光标不动；仓库满了储存列表不可确定。
- 接线：`mv_interpreter.gd` 认 `PHWarehouse show` 交宿主（仓库不存在不打开），`mv_event_core.gd` 认 create／remove，`map_scene.gd` 新增 `open_warehouse`；`xiyou_event_compare` 记录宿主补 `open_warehouse`，基线删 m4e8p0（5 例 → 4 例）。
- 参照：`review_system_pages.js` 新增 `warehouse` 页（真实存入 5 件后 7 个截图状态，附仓库内容、背包、NEW 行读数），压成 `tests/fixtures/warehouse_oracle.json`；成对截图在工作树 `04_验证/本地结果/原版参照/大厅三界面/`（wh_*），目视一致。
- 验证：`xiyou_warehouse` 27/27（7 个状态全部窗口文字与矩形、光标、NEW、仓库内容与背包；容量满、9999 取不出、重置、存读档、EV8 指令）；`xiyou_event_compare` 5/5、`xiyou_inlay_book` 19/19、`xiyou_determinism` 372/372、`xiyou_flow` 48/48、`xiyou_equipment` 1228/1228、`xiyou_item_list` 38/38、`xiyou_global_vars` 17/17。
- 未做：「角色仓库」（`SceneManager.push(Star_Scene_ActorWarehouse)`，把队员存出队伍）。它连着 Star_LeadActor／Star_SkilsShare／Star_JiBanSiklls 的退出刷新与 installImportedBalanceRuntime 的停用角色判定，超出本期；现在选它仍无反应（与合并前相同）。

### 交接板

- 下一步：角色仓库（Star_ActorWarehouse）待定是否做；期三更衣（m4e17）。
- 用户试玩说明：方桌大厅仓库管理员「装备道具仓库」可以存取物品和装备，内容随存档；「重置仓库」会清空。

### 进度账

- 界面：大厅未接界面 2 → 1.5（装备道具仓库已接，角色仓库未做）
