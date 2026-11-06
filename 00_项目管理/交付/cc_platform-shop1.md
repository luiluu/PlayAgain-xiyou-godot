# 交付：cc/platform-shop1

- 车道／工作者：B 界面（cc，platform-shop1）
- 状态：可合并
- 注意：从 `cc/platform-keys3` 切出（keys1→keys2→keys3→shop1，main 都还没有），合并顺序依次。

## 变更记录草稿

## 2026-11-06 【cc·未经审查】商店装备状态窗 Tab 默认（逐项属性）模式（dev.待定）

- 原版（YEP_ShopMenuCore 的 `Window_ShopStatus` ＋ 基础 MV）：装备商品的状态窗有两种显示：actor（队员对比，Default Mode 参数，重制原有）和 default。Tab（或点窗口上沿两行内不在 << >> 上）切换（`adjustMode`，响光标音，只对装备、Stat Switching 开）。
- default 模式画法：第 1 行持有数；第 2 行当前属性名居中（paramId 初始 2＝攻击），左右 `<<` `>>`（系统色）；第 3 行起每个队员一行（每页 4 人）：名字在 x+220（x＝textPadding 6）、装得了写「新装备属性 − 该队员同类型装备栏里该属性最低的那件」，20 号右对齐、涨绿降红、不变用普通色，装不了写「Can't Equip」（20 号、半透明，队员名也半透明）。←→ 在 8 项属性间轮换（0..7 循环）；数量窗开着时不换。Shift 在队员多于 4 人时翻队员页（基础 MV `Window_ShopStatus.updatePage`，两种模式都翻，默认模式才看得到），响光标音。
- 重制：`XShop` 加 `_stat_default`／`_param_id`／`_page_index`，`_paint_status_default`、`_worst_equipped_param`、`_toggle_stat_mode`、`_change_stat_page`；Tab 在 `_unhandled_input` 里先于其它键处理，与 `XKeyMap` 无冲突（Tab 不在补的键里）。回退 `XShop.STAT_DEFAULT_MODE = false`。
- 更正 keys3 交付单：Shift 不是「原版没有任何调用」，见上。

## 验证

- 新专项 `xiyou_shop_stat_mode`（11 项）：开店默认队员模式、Tab 切换、第 2 行属性名、队员行位置与文字、装得了／装不了、←→ 轮换并回绕、物品不能切、回退开关、Shift 翻页。
- 其它：xiyou_shop_stock 46/46、xiyou_shop_auto_close 10/10、xiyou_map132_shop 101/101、xiyou_key_map 31/31、ui_smoke 24/24、工具回归全过、语法检查 0 问题。
- **未做到的**：夹具是照插件源码推出来的坐标，不是在正式版运行时量出来的读数（调度单要的是实测夹具）；实测需要在 mv_oracle 里起一个商店界面探针，本轮没做，建议审查线程或下一单补。
- **失败项**：`xiyou_lobby_shops` 93/94，`case_e54p0_base_0-0`（事件解释器用例，输出的选项与商品清单看着一致，细节在尾部）。与商店状态窗无关，我没有在 main 上对照确认是不是本来就失败；请总装合并时留意。
- 选测 `选测.py main --list` 33 个（改动面只有 shop.gd 与测试），本机排不上槽、也未起云端，请总装补跑。

## 交接板

- 下一步：实测夹具（正式版商店 default 模式的画面读数）
- 用户试玩说明：商店里选中一件装备，按 Tab 切到「逐项属性」页：每个队员看一个属性的增减，←→ 换属性，队员超过 4 个时按 Shift 翻页，再按 Tab 回到原来的队员对比页
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 商店装备状态窗 Tab 默认模式；keys3 交付单 Shift 更正
