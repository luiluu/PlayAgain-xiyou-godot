# 交付：claude/bajie-shop-stock

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_14，中等努力）
- 状态：可合并（2026-10-17：已合并 main 902ff6c，`检查.sh --oracle` 全部通过）

## 变更记录草稿

## 2026-10-17 【Claude·八戒·未经Codex检验】商店限购 KMS_ShopInventory（dev.待定）

- 新增 `core/shop_stock.gd`（`XShopStock`），照框架维护约定「ShopInventory 限购」：`apply_group`（插件指令）、`open`（Scene_Shop.prepare：补货并取走待用组）、`remaining`／`available`／`max_buy`（只读）、`record_purchase`／`record_sale`（记账）、`plugin_command`（apply／supplySpeed／restockAll／resetAll）。组名用正式命令字符串；没 apply 的商店不限购。存档 `XState.shop_stock` 记剩余量（同原版容器），读档缺这一项全满；待用组 `XState.shop_pending` 不存档（$gameTemp）。
- 接线：解释器 `_plugin_command` 只加 ShopInventory 一个分支转交；`XMapScene.open_shop` 先 `XShopStock.open` 再判宝珠商店；`XShop` 可买＝`XItemMarks.can_buy` 且有库存，数量上限再与库存取小，买入先 `XItemMarks.buy`（货币、得物）再扣库存，卖回补库存（独立装备实例照原版不回）。货币仍只由 XItemMarks 扣。
- 商店页（标准级，正式版运行时读数 `tests/fixtures/shop_stock_ui_oracle.json`、截图 `04_验证/本地结果/原版参照/codex_shop_stock_reference.png` 对 `Godot_限购商店.png`）：售完行画名字（宽减 96）与右侧白字「售完」、按不可买半透明，不画价格；状态窗第 2 行「库存 剩余/上限」（插件参数名 `Stock display` 与读取的 `Show stock in status` 不符，按默认只画在状态窗）。O-043：装备商品原版这一行与「<< 队员 >>」重叠、字号 20，改到能力表下方（`XShop.STOCK_GEAR_BELOW`）。
- 二十层后索礼商店（Map116 群仙俯首 1912、Map147 天宫之寒 1916 等）与切片内其余 apply 商店（大厅人道碎片三家共用一组、特殊物品、神秘药贩 183 按游戏时间每 3600 秒补 1 等）都经同一入口生效。
- 参照：`mv_oracle/shared/stock.cjs` 补 3 例（独立装备 4279 买入扣库存、卖出实例不回；1912／1916 用正式组名买到售完、重开、别组不受影响），共 19 例。
- 验证：`tests/xiyou_shop_stock`（46 项）：19 例逐例一致（零库存、刚好买完、重开与卖回、共享组／不同组、预览与取消不耗、金钱不足、多货币（变量 206、物品 2898）与少 1、restockAll／resetAll、上下限、按时补货、不补货、supplySpeed 原版 NaN、待用组覆盖、存读档、计时器存读档、独立装备、两家索礼商店），400 件受管商品的上限／间隔／方式（含运行时写字段的 2902、4001），117 条指令的 apply 组名，解释器 356→302 转交，旧档全满，界面读数与操作（售完不可选、数量上限＝库存、买完变售完、不限购店不画库存）。worktree 跑 `同步正式西游.py`：测量无变化，只报 shop_stock 新用例未登记，已在 `common_oracle_contract.py` 登记三例并加完整性断言（`共性参照验收.py` 59 例通过）；随后 `godot --import`；相关专项（事件对照、楼层流程 1～25 层、物品列表、标记、宝珠坊、存档页、商店买入 3106 项、窗口矩形）全过；`检查.sh --oracle` 全部通过。
- 工程规则自查：缓存（`XShopStock._spec_cache` 只依数据库，键含类型与 ID）；预览不改状态（有测试）、不耗随机数（无随机）；弹窗输入与鼠标键盘沿用商店页原有处理；新存档字段缺省全满（有测试）。
- 已知差异：补货计时取 `XState.play_seconds`，重制版只在地图上累计（原版各场景都按帧走），菜单与商店里停留的时间不计；正式数据里只有 183、77 与一件 30 秒的商品按时补货。
- 提交：见「本分支提交」

## 交接板

- 下一步：删「审查 20%＋25% 遗留」里 KMS 商店库存／ShopInventory 限购一项（如有）；八戒下一个界面项待唐僧派。合并时 main 需重跑 `同步正式西游.py`（探针改了，测量应只增 shop_stock 三例）。
- 用户试玩说明：限购商店（大厅人道碎片、特殊物品、二十层后各层的被动书商人等）显示「库存 剩余/上限」，买完变「售完」，存档后保持。
- 需要用户决定：O-043（装备商品的库存行移到能力表下方）。

## 进度账

- 界面页面：67% → 68%，商店页补上限购显示与操作（初值，待沙僧复核）。

## 本分支提交

- 89bac06 限购参照：stock 探针补独立装备买卖、二十层后索礼商店两例；正式版商店库存显示读数夹具
- 86f5385 商店限购：XShopStock 接插件指令与商店页，售完／库存行，O-043；xiyou_shop_stock
- be181e1 O-043 登记、框架维护约定限购节改已实现、测试可存 Godot 截图
- f75a007 TEST_RESULT 通过数修正、交付单草稿
- ae97095 共性参照登记：限购新增三例及完整性断言
- 4cbc5e1 补 xiyou_shop_stock.gd.uid
- 1908a57 合并 main
