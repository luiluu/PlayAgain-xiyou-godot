# 交付：cc/bailong-ui8b

- 车道／工作者：B 界面·只读盘点／白龙（cc，ui8b）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】战斗 HUD 与地图内界面盘点、滚轮／翻页实施清单 ui8b（只读，未改游戏代码）（dev.待定）

接 ui8：补盘战斗 HUD 与地图内界面，并把 ui8 的「滚轮／翻页」两条列成可直接照做的实施清单（ui9 用）。没有改任何游戏代码、测试或工具。结论：战斗 HUD 与对话框新截图和原版参照一致，只剩两条待核（胜利结算背景清晰度、商店买入列表无滚动）；实施清单见下，比 ui8 说的更细——**原版并非所有页都翻页**（技能类型窗、装备指令窗、状态窗的 Q／W 是换角色），清单已逐页标出。

## 怎么盘的（以及没盘到的）

- 原版真截图：`04_验证/本地结果/原版参照/`（主工作区本机已有）；Godot 截图用 `./godot --path ../01_Godot工程 res://tests/xiyou_<名>.tscn -- --out=<目录>`（battle_ui 28 张、message、map（全地图）、difficulty_notice）。
- 成对肉眼比对：战斗技能窗（41 ↔ battle_41）、攻击动画帧（48_attack_f30 ↔ battle_48）、胜利结算（46 ↔ battle_46）、对话框（30_msg_top ↔ message/msg_30_top）。画面差异只来自存档状态（等级、HP、行动顺序条、粒子）和已登记的有意差异（战斗「自动／变速」按钮 O-006、地图「存档备份／地图传送」按钮在测试场景里不建，原版在地图 HUD 上有，属夹具差异）。战斗里原版也有的灰色方块（地图快照里的瓦片阴影层）两边一样，不是缺陷。
- 其余战斗 HUD 项（伤害数字、Boss 血条、战斗日志、角色状态窗、敌人名窗、技能／物品窗）和地图内项（选项窗、数值输入、地图名、物品选择、提示弹窗）都有原版读数 fixture 或参照图在跑专项（`popup_anchor_oracle`、`hp_gauge_oracle`、`boss_output_oracle`、`xiyou_battle_ui` 的 40～54 号、`xiyou_message`、`xiyou_difficulty_notice`、`82_map221_name`），本次没有重复比，也没重开浏览器。
- **没做**：气泡（对话框气泡样式）和快捷栏（MKR_MapItemSlot）这两个没有找到 Godot 截图，也没找到原版参照图，只能列「待核」；地图内逐页的像素比对没做。
- 证据列：**实测**＝截图对过；**读码**＝对照原版 `rpg_windows.js`／插件与 Godot 脚本；**待核**＝只有线索。

## 差异表（战斗 HUD 与地图内界面）

| # | 页面 | 原版 | 重制 | 证据 | 要不要做 | 估计大小 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 商店买入列表 | `Window_ShopBuy` 是 `Window_Selectable`，长列表滚动、光标带着窗口滚（含鼠标滚轮） | `shop.gd` `_paint_list` 的 buy 分支从 `y = i * LH` 画全部商品，没有 `_buy_top`，`_move` 里买入模式也没有 `_scroll_to`（出售列表有）。一页放 14 行，商品多于 14 件的店，光标会跑出窗口 | 读码（`shop.gd:296-312`、`:573-576`）；**待核**：全游戏有没有商品多于 14 件的店（没统计，需要在 `XItemMarks.shop_goods` 上数一遍） | 先核再做；若有商品 >14 的店，这就是比滚轮更重的缺陷，先做 | 小：照出售列表加 `_buy_top`、`_scroll_to`、箭头 |
| 2 | 战斗胜利结算背景 | 背景是放大的战斗画面，明显偏糊（46_victory_window） | 同样放大但更清晰（battle_46） | 实测；**待核**：糊是不是插件有意（Olivia_VictorySequenceUI 里没搜到 blur，也许是缩放插值或 MV 渲染分辨率），要量像素再定 | 先核，不确定前不做 | 小到中 |
| 3 | 对话框（头像、名字框、选项、数值输入） | — | 一致 | 实测（30 ↔ msg_30_top），选项／数值输入有 `message_box` 专项 | 无 | — |
| 4 | 战斗角色状态窗、行动顺序条、技能窗、说明卡 | — | 一致（状态值不同是存档差异） | 实测（41 ↔ battle_41） | 无 | — |
| 5 | 伤害数字／攻击动画帧 | — | 有逐帧 fixture（`popup_anchor_oracle`、`attack_animation_oracle`） | 读码（fixture 在） | 无 | — |
| 6 | 地图名显示、难度提示、对话框背景 | — | 一致（`82_map221_name`、difficulty 夹具） | 读码＋专项 | 无 | — |
| 7 | 地图气泡、快捷栏（MKR_MapItemSlot）、地图 HUD 小按钮 | 地图 HUD 上有「存档备份」「地图传送」按钮，快捷栏插件在 | Godot 有地图 HUD 与按钮（`map_hud.gd`），气泡与快捷栏没找到截图证据 | **待核**，没比 | 先让 ui9 顺带在原版夹具截一张，没差异就关 | 小 |
| 8 | 战斗「自动／变速」按钮、选目标「返回」、角色指令窗「逃跑」 | 无 | 有，已登记（O-006、`界面风格.md`） | 实测 | 不用做 | — |

## 滚轮／翻页实施清单（ui9 照做，本期不改代码）

### 原版逻辑（`rpg_windows.js`）

- `processWheel`（1038）：窗口 `isOpenAndActive()` 时，`wheelY >= 20` → `scrollDown()`；`wheelY <= -20` → `scrollUp()`。`scrollDown`：`topRow + 1 < maxRows` 时 `setTopRow(topRow + 1)`（只滚窗口，**光标 index 不动**）。`scrollUp` 对称。
- 翻页：`processCursorMove`（1012～1016）里，窗口**没有**自己的 `pagedown`／`pageup` 处理时，`Input.isTriggered('pagedown'/'pageup')` 调 `cursorPagedown`／`cursorPageup`（951～）：
  - 下：若 `topRow + maxPageRows < maxRows`，`setTopRow(topRow + maxPageRows)`，`select(min(index + maxPageItems, maxItems - 1))`。
  - 上：若 `topRow > 0`，`setTopRow(topRow - maxPageRows)`，`select(max(index - maxPageItems, 0))`。
  - 在最后一页再按下不动（不回绕）。
- 原版键位：PageUp／PageDown 与 Q／W（`Input.keyMapper` 默认 33／34 与 81／87）。窗口自己接管 pageup／pagedown 的场景（`setHandler('pageup'…)`）：技能类型窗、装备指令窗、状态窗（换角色，`rpg_scenes.js:1331、1441、1551`，`HelpExtend.js:563、580`，`YEP_EquipCore.js:947`，`JAH_StatusMenuCore.js:1998`）、整队窗（`YEP_PartySystem.js:1679`）、地图传送（`MapTransferPlugin.js:1338` 翻页预览）。这些窗口**不**走通用翻页。
- 注意：`MK_Sanfu_KeyConfig` 能重配键位，默认值以 `plugins.js` 参数为准，ui9 不要改键位。

### 重制现状（`modes/xiyou/ui/`）

公共一处最合适：在 `menu.gd` 的 `XMenu`（已有 `_scroll_to`、`_move`）加一个 `page(top, index, count, rows, cols, dir)` 返回新 `[top, index]`，以及 `wheel(top, count, rows, d)`。各页只调用。

| 页面 | 文件／模式 | 变量 | 滚轮现状 | 翻页现状 | 要做 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 商店 | `shop.gd`：category（4 行）、sell（`_list_rows()`＝14）、buy | `_cat_top`、`_sell_top`、buy 无 top（见差异表 #1） | 无 | 无 | 加 `_buy_top`；三个列表接滚轮；sell／buy 接翻页，category 只 4 行也接 | 先修 #1 |
| 技能页 | `skill_scene.gd`：type（4 行，**原版 pageup/pagedown＝换角色，已做，勿动**）、技能列表（2 列，`_list_rows()`）、队员窗（4 行） | `type_top`、`top`、`actor_top` | 无 | 列表无；type 窗是换角色，正确 | 技能列表、队员窗接滚轮；技能列表接翻页（`maxPageItems` ＝行数×2） | 列表 2 列，`index ± rows*2` |
| 宠物页 | `pets.gd`：宠物列表（11 行）、底部指令（6）、喂养（4）、技能（4） | `top`、`cmd_top`、`feed_top`、`skill_top` | 无 | 无 | 四个窗口接滚轮；列表、喂养接翻页 | 宠物页是 Codex 自写，原版 `Star_` 系列未核 pageup，**待核**再决定翻页 |
| 物品页 | `item_scene.gd`（滚轮已有 1071） | `_top`、`_cat_top`… | 有 | 无 | 加翻页（category、list、upgrade、augment 四个列表） | 原版 Scene_Item 无接管，应翻页 |
| 存档页 | `save_scene.gd`（滚轮已有 317） | `top` | 有 | 无 | 加翻页 | YEP_SaveCore 未核，**待核** |
| 怪物图鉴 | `enemy_book.gd`（滚轮已有 495） | `top`、`drop_top` | 有 | 无 | 加翻页 | AB_EnemyBook 自写，**待核** |
| 设置页 | `options_scene.gd`（滚轮已有 301） | `top`、`ROWS=12` | 有 | 无 | 加翻页 | Scene_Options 无接管，应翻页 |
| 主菜单 | `menu.gd`（滚轮已有 223）：指令窗 15 行、队伍窗 5 行 | `_cmd_top`、`_actor_top` | 有 | 无 | 指令窗加翻页；队伍窗 5 行，选人时不翻 | 原版指令窗 `Window_MenuCommand` 无接管 |
| 制作 | `crafting.gd`（滚轮已有 629） | `top`、`pick_top` | 有 | 无 | 加翻页 | 自写页，**待核** |
| 仓库、星级仓库 | `warehouse.gd`（滚轮 283）、`star_warehouse.gd`（滚轮 225） | `top`（2 列） | 有 | 无 | 加翻页 | 2 列，`± rows*2`；`Mehmet_Warehouse`／`Star_Warehouse` 未核 pageup |
| 训练 | `training_scene.gd`（`INDEX_ROWS=19`） | `top` | 无 | 无 | 队伍成员 ≤19 时不需要；`members().size() > 19` 才有意义，暂不做 | 极少触发 |
| 其余（装备、整队、传送、成就、更衣、角色仓库、图鉴等） | 已有滚轮／翻页或原版自己接管 | — | — | — | 不动；ui9 回归时顺手确认 | 传送页 Q／E 已做（`map_transfer.gd:521`） |

### 测试建议

- 专项：在 `xiyou_window_rects` 或各页现有专项里各加「滚轮一次，top 增 1、index 不变」「PageDown 一次，top ＋ 行数、index ＋ 行数（到末项封顶）」「最后一页再按不动」三个断言；光标已在最后一页时 PageUp 的行为按原版（`topRow > 0` 才动）写。
- 反向验证：改完用 `07_开发环境/反向验证.py` 对每个新断言验一遍真咬得住。
- 选测名单：`选测.py main --list` 会列出相关场景；至少含 `xiyou_shop_buy`、`xiyou_skill_page`、`xiyou_item_list`、`xiyou_save_page`、`xiyou_options_basic`、`xiyou_enemy_book`、`xiyou_pets`。

## 交接板

- 下一步：ui9 先核差异表 #1（有没有商品 >14 的店），确认就连同滚轮一起修；再按实施清单做滚轮、翻页。#2（胜利背景清晰度）和 #7（气泡、快捷栏）先在原版夹具量一张，不确定不做。
- 用户试玩说明：本轮无玩家可见变化。
- 需要用户决定：无。

## 进度账

- 部分：界面零散细节 无新增完成度（只读盘点）。

## 可优化（流程／工具／效率）

- 建议：ui9 做滚轮／翻页时把行为收进 `XMenu` 公共函数，新页只声明行数与列数（同 ui8 建议）；归界面车道。
- 建议：给 `tests/` 加一个扫描型专项，列出所有含列表窗的 ui 脚本，断言都含滚轮处理；防止新页再漏；归界面车道，小。

## 本分支提交

- 本交付单（分支上除此文件外无改动）
