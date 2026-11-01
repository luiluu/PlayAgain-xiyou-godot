# 交付：cc/bailong-yunshang11

- 车道／工作者：E 角色专属／白龙_12（cc）
- 状态：可合并（在 yunshang10 之后合）
- 分支从 cc/bailong-yunshang10 末端 7ddac2d8 切出（总装十一派单），**包含 yunshang9、10**，那两张交付单照它们自己的合；没合 main。
- 范围：① O-135 回退支测试；② 云裳的显示：HD 图标、织神天梭说明、天衣粉色（名字、说明、说明卡窗口皮）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_12·未经审查】云裳显示：HD 图标、织神天梭说明、天衣粉色；O-135 回退支测试（dev.待定）

照原版 installNativeYunshangRuntime.js 第 594～772 行，`core/yunshang.gd` 文末加显示一节：

1. **图标**：原版最后装的 `Y.iconInfo`——技能 10270～10287（图标号 130270～130287）是 HD 图集 `Yunshang_Icons_HD_v1`（1254²，6×6 格）的第 0～17 格，天衣、织神天梭、号角、不朽天丝（图标号 210118～210135）是第 18～35 格；每格平滑缩到 112 放进 128 的透明方块正中，再按要画的大小平滑缩放，不改色。重制 `XUI.icon_texture` 认这两段图标号（之前这些图标号落在不存在的 IconSet_132 上，一个都画不出来），说明窗的 128 大图标（`XItemStatusPainter.large_icon`）直接用 128 那张。切片 `systemImages` 加了 `Yunshang_Icons_HD_v1`。早先装的 Yunshang_Icons 小图（210000～210013）与品质改色两层被这层盖掉、数据里也没用到那段号，不移植。
2. **天衣粉色**：15 件天衣的名字、描述、品质行与各列表里的名字用粉色 rgba(255,169,202,1)（`XQuality.color_text`，原版 normalcolor／namecolor 与 drawItemName 包装）；说明卡窗口皮换成按亮度改成粉色的 Window12（原版 coloredRobeSkin）。
3. **织神天梭说明**：八项显示成本身＋等级×每级成长（relicDisplayParams），「等级需求：1」后面插「当前等级：L / 888」「法宝经验：exp / 下一级所需」（满级写「（已满级）」）。
4. **没做的**：说明文字刷新 refreshYunshangText——换掉旧版本天衣备注里的说明行、描述与图标照模板；重制的天衣都照当前模板建，没有旧版本，不需要。说明卡的分隔线色（standardLineColor）——重制说明卡不画分隔线。装备列表图标外的品质描边（RJO.IQ.DrawOutline）——重制没有这层描边。
5. **O-135 回退支测试**：`xiyou_yunshang` 加 `_copy_turns`：stateCopy 来源身上没有、又没给回合数时，默认保留附加时掷出的回合数，`XYunshang.o_copy_turns = false` 时写成永不到期。`回退开关覆盖.py` 新缺口 0。
- 参照：`yunshang_probe.cjs` 加 p9（图标格号、织神天梭说明三种等级、天衣说明两件）。

## 优化登记草稿

无。

## 验证

- 专项 xiyou_yunshang_shop 418/418（多 56 项）：p9 图标格号 40 个（含两头各一个不是云裳的）、32 与 128 两种大小、四边透明与缩放比例、普通图标照旧走 IconSet；织神天梭说明三种等级逐行比参照（文字、字号、颜色）；天衣说明两件逐行比参照、粉色、说明卡用粉色皮、粉色皮像素公式；织神天梭与同号技能不算天衣。
- xiyou_yunshang 1593/1593（covers_all 算上 p9；O-135 两支）。
- 反向验证 7 处全抓到：回退支不写永不到期、天衣格号错一格、天衣不粉、不插等级经验、八项不加成长、皮按原色、图标不留边。
- 语法检查通过。
- 没在画面上看过（无界面环境跑不出画面）；图标、粉色只按像素与数据核对。
- 同步 `同步正式西游.py --accept-additions`：测量不变（留下产物指纹）；`内容覆盖检查.py` 新 0、解决 0，不用更新基线。
- 选测：`选测.py 7ddac2d8` 选 61 个，其中 xiyou_rules 24 段是因为改了 yunshang_probe.cjs（探针组）；这个探针不进同步、不进 rules 的参照，切片只改了图像名单，所以只留难度 1 四段，其余 20 段不跑。改跑 41 个全名（CHECK_JOBS=3，9 分钟）全过、没有偶发：ui_smoke、xiyou_actor_advanced、xiyou_actor_book、xiyou_actor_warehouse、xiyou_battle_ui、xiyou_book_capacity_ui、xiyou_change_clothes、xiyou_character_help_cost、xiyou_crafting、xiyou_enemy_book、xiyou_event_compare、xiyou_gear_search、xiyou_gear_ui、xiyou_gold_cap、xiyou_hangup_auto、xiyou_help_card、xiyou_inlay_book、xiyou_item_list、xiyou_item_marks、xiyou_mac_export、xiyou_magic_level、xiyou_message、xiyou_orb_shop_ui、xiyou_orb_ui、xiyou_panels、xiyou_pet_synth、xiyou_pets、xiyou_power_books_menu、xiyou_rules、xiyou_rules_d1b、xiyou_rules_d1c、xiyou_rules_d1d、xiyou_save_page、xiyou_shop_buy、xiyou_shop_stock、xiyou_star_warehouse、xiyou_transfer、xiyou_warehouse、xiyou_yunshang、xiyou_yunshang_shop、xiyou_yunshang_ui。

## 交接板

- 下一步：云裳都做完了（还差的只有用户试玩反馈）。
- 用户试玩说明：云裳的技能、天衣、织神天梭、号角、不朽天丝都有图标了；天衣名字是粉色，说明卡也是粉色框；织神天梭的说明会显示当前等级和法宝经验，八项按等级算。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：云裳完成度 0.98 → 1.0（显示做完），按工作量估。

## 可优化（流程／工具／效率）

- 发现（工具）：`选测.py` 把 mv_oracle 下任何探针都算 converter 组，连带 rules 24 段；不进同步的独立探针（yunshang_probe 这类，产物手工拷成夹具）其实只该跑引用那个夹具的测试。可以按「同步 PROBES 里有没有它」分开。

## 待交叉核查

- `core/yunshang.gd` 文末显示一节；`core/quality.gd`（color_text 认天衣）；`ui/xui.gd`（icon_texture 认云裳图标号）；`ui/item_status_painter.gd`（large_icon）；`ui/help_card.gd`（织神天梭两行与八项、天衣粉色皮）；切片 `systemImages` 加一张图。
- 测试：`xiyou_yunshang.gd`（_copy_turns、covers_all）、`xiyou_yunshang_shop.gd`（p9_display）。

## 本分支提交

- 前面同 yunshang10（到 7ddac2d8）
- O-135 回退支测试；p9 参照与切片；显示实现、专项 417；covers_all 与缩放检查
- 本提交：同步与选测通过，交付单可合并
