# 交付：cc/ui-skin-1b

- 车道／工作者：B 界面·新界面第 1B 批（模板页＋物品页 #22＋技能页 #26＋说明卡 #62）／cc（Opus＋medium，派单定：模板页是后面约 30 页的底，复杂接线）
- 状态：可合并
- **合并顺序**：本分支已合入 `cc/ui-skin-1a`（6c8a98368，用它的 `XUiSkin.icon()`／`face()` 图标缓存和 `XSkinMainMenu.hint_right()`；协调 11-15 说白块由 1A 修、这边用 `XUiSkin.icon()`），**先合 1A 再合 1B**。

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面第 1B 批：模板页、物品页、技能页、说明卡换皮（dev.待定）

- 玩家可见：无（新界面只在天启篇存档里开，天启篇没对玩家开放；重制版 0.01.x 与西游存档仍是旧物品页、旧技能页、旧说明卡，已逐像素对照）。开发版里进天启篇存档开物品页：左边五类小环（名字带数量，环心写当前类多少种／件），中间两列列表一屏 20 项（行高 48，名字放不下先缩字再加省略号，列表底下「第 a / b 页」），右边详情牌（名字、类别 · 持有、说明、效果、用法；对队友用的药写「给谁用」四人量条和预估回多少「+n／满」）；确定后在牌底弹操作菜单（使用、升级、镶嵌孔、置顶、出售锁定），使用时在「给谁用」里选人。技能页同样摆：左边技能类型小环（环心是角色圆头像）＋角色条，中间两列技能（右侧消耗：TP 青、MP 蓝、冷却橙），右边技能详情。说明卡（战斗、仓库等处浮出的那张）外框换成黑面板＋品质色细线。
- 依据：界面风格提案 v0.7 样稿 `items`、README 第一节「物品」、第四节实装清单「模板页」（私密设计仓 `重制设定/界面风格提案_v0.7/`）；第 0 期交付单「第 1～6 期拆批建议」1B 行；盘点清册 `xa/ui-audit` 35b648209（#22、#26、#62）；文字口径照小A文字审 ba1f7ed（精魂、按键提示套框；样稿的「丢弃」游戏里没有这个功能，没做）。
- 开关：沿用第 0 期 `XUiSkin.ENABLED`（O-467，同一开关不另开）：关掉或不是天启篇存档时 `XItemScene`／`XSkillScene`／`XHelpCard` 走旧代码，一行不变（`皮肤关闭对照.py` 对 main 12 张逐像素一致）。
- 新增（独占）：
  - `modes/xiyou/ui/skin/skin_template_page.gd`（`XSkinTemplatePage`）：**可复用模板页**——左小环分类（环心大数字＋小字）、中面板＋旧金小标题＋直列表（一列／两列、行高可设）＋底下页码（列表超一屏自动「第 a / b 页」）、右详情牌（可在牌下半截放「给谁用」目标列表、牌底弹操作菜单）、顶上页名＋组页签（当前组高亮）＋右上货币（默认精魂）、右下按键提示（让出版本号）。两种用法：自动导航（环→列表→取消回环→back，简单页面用）／手动（页面自己的状态机 set_focus，物品、技能页用）。`help_rows()` 把说明卡的行转成牌上的分节（去转义码、`\col` 两项用全角空格隔开、太暗的颜色提亮）。套用要点见下「模板页套用要点」。
  - `skin_target_list.gd`（`XSkinTargetList`）：「给谁用」目标列表（圆头像、名字、一条量条、当前/上限、右侧预估），可选人（红乙选中条）、全体对象整队选中。
  - `skin_item_page.gd`（`XSkinItemPage`）：物品页新布局。状态机、使用、升级、宝珠、批量服用、藏宝图、检索全部还是 `XItemScene` 原来的代码，这一页每次 `_refresh` 后按状态重画，方向键按两列网格／环走、其余按键交回旧代码，鼠标点哪儿翻译成同样的状态变化。批量服用数量窗、藏宝图数量窗、检索面板、遗忘页沿用旧窗口（第 0 期已换黑面板），宽屏时数量窗水平居中（点击坐标同步挪回）。「效果」只写回复生命／魔法／TP、附加／解除状态、学会技能，别的照说明卡；「给谁用」的预估＝(上限×比例＋定值)×受恢复效果×使用者药物知识，夹到缺的量，只显示、不改数值。
  - `skin_skill_page.gd`（`XSkinSkillPage`）：技能页新布局，同样只管画；类型环上左右也能换类型（旧页只认上下），Q/E 换人照旧（列表里 Q/E 仍是翻页，同旧页）。
  - `tests/xiyou_ui_skin_1b.gd`／`.tscn`（专项）。
- 改（本批界面文件）：
  - `tests/xiyou_ui_skin_menu.gd`（1A 的专项）：`wide_released_in_page` 改成 `wide_held_by_new_item_page`——1B 起天启篇的物品页按新稿排好、自己 `request_wide`，主菜单进物品页后视口仍铺满（计数 1）。
  - `ui/item_scene.gd`：`XUiSkin.on()` 时建 `XSkinItemPage`；`_refresh` 末尾 `skin.sync()`；按键先给新布局（方向键），点击在新布局时交给组件（数量窗、藏宝图窗的点击按宽屏偏移挪回）；`gear_shown()` 新布局时为假（装备详情由牌画）；加 `_effective_for(rec, t)`（「给谁用」变暗判断，同 `_effective`、不改 `_item`）。
  - `ui/skill_scene.gd`：同样四处挂钩（建页、`_refresh` 后 sync、按键、点击）。
  - `ui/help_card.gd`：加 `skinned()`；新皮肤开时 `_draw_frame` 画黑面板＋品质色 1px 细线、`_paint` 不再垫 #161c25 底；排版、字、位置不变。
  - 第 0 期组件（小改，都向后兼容）：`skin_list.gd` 名字放不下先缩到 16 号再加「…」（`fit_text`，协调 11-15 提醒陈列图「治疗药水(」被硬裁）、`active`（没焦点时不画选中条）、`badge`（图标左上小角标，物品「新」）、`min_font_size`；`skin_card.gd` 加 `reserve_bottom`（给目标列表留地方）、`rows` 分节（多行各自颜色、标题可空）、按钮 `disabled`、长名字缩字加省略号。
  - `tests/xiyou_ui_skin_offshot.gd`：关闭对照加技能页（`XSkillScene`）。
- **IconSet_2 白块查清**（第 0 期交付单「建议」那条）：不是 `.godot/imported` 缓存——本树重新导入后两份 `.ctex` 都对（像素和 PNG 一致；两份是 10-12、10-21 不同源路径留下的，无害），三棵树的 `.import` 也一样。真因是 `XUI.icon_texture` 每次新建 AtlasTexture、图集只靠它引用，新组件在 `_draw` 里临时取完就释放，到那一帧画的时候图集已卸掉→白块（旧 `XMVCanvas` 有 `_keep` 所以没事；IconSet_1 常被别处拿着所以多半不白）。本车道最小复现（一个 Control 在 `_draw` 里取 116、1725：全白；缓存图集后正常）后，协调告知 1A 已用同一结论修了（`XUiSkin.icon()`／`face()` 缓存），本分支改用它，自己的 `xui.gd` 修法已撤回，没重复改。
- 验证：见「验证」节。

## 优化登记草稿

无（沿用第 0 期 O-467，不新增）

## 新增可见文字（交付后派小A文字审）

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| 物品、技能 | 页名 | 现有入口名 |
| 第 %d / %d 页 | 模板页列表底下（超一屏时） | 样稿原文 |
| 种、件 | 物品页环心数字下（物品类「种」、武器护甲「件」） | 「种」样稿原文，「件」新写 |
| 物品／消耗品／重要物品 · 持有 %d | 物品牌名字下 | 类别名是现有分类名；样稿写「药剂 · 持有 6」，游戏里没有「药剂」这一类，用分类名 |
| 效果　回复生命 500／回复魔法 30%／回复 TP 10／减少生命 …／附加「状态」／解除「状态」／学会技能「技能」 | 物品牌「效果」行，多条用「、」连 | 「效果」「回复生命」「学会技能「割裂」」样稿原文，其余新写 |
| 用法　战斗中和菜单里都能用／只能在战斗中用／只能在菜单里用／不能使用 | 物品牌「用法」行 | 第一条、第三条样稿原文，其余新写 |
| 给谁用、给谁学 | 牌下半截目标列表标题（技能书用「给谁学」） | 样稿原文 |
| 满、+%d | 目标列表右侧预估 | 样稿原文 |
| 使用 | 物品牌按钮 | 样稿原文（样稿的「丢弃」没做：游戏没有丢弃） |
| 「技能名」 | 技能书牌里所学技能那节的标题 | 新写（技能名是数据） |
| 升级材料、镶嵌宝珠 | 升级、镶嵌时列表的小标题 | 新写 |
| （已筛选） | 武器、护甲列表小标题后（装备检索有条件时） | 新写 |
| %d %s（如「19 种」） | 物品页分类阶段牌上的小字 | 新写 |
| 类型名 · %d 个 | 技能页类型阶段牌上的小字 | 新写 |
| 确定 选择／取消 返回／取消 回分类／X 检索排序／Q / E 换人 | 右下按键提示 | 「回分类」「检索排序」样稿原文（套框）；「选择」「换人」新写（样稿物品页写「确定 使用」，这里确定是打开操作菜单，所以写「选择」） |
| 取消 回类型／Q / E 翻页 | 技能页列表态的按键提示（类型态「Q / E 换人」、选人态只有确定／取消） | 小A核查 P2 给的字 |
| 空 | 列表没有项时（`XSkinList.empty_text`），物品／技能牌没东西时的说明 | 第 0 期已有、复用 |
| 取下镶嵌物 | 镶嵌列表首行与停在那一行时的牌标题 | 插件原文（`YEP_X_AttachAugments` Remove Augment），复用 |
| LV.%1 | 技能名后的熟练度等级小字 | 插件原文（`YEP_SkillMasteryLevels` Text Format），复用 |
| 减少魔法 | 物品「效果」行（魔法为负的效果） | 同「减少生命」，衍生 |

操作菜单里的「使用 %1」「升级 %1」「道具置顶」「出售锁定」「取消」、孔位行、说明卡的行、物品名和说明都是游戏原有文字，没改。

## 交接板

- 下一步：1C（装备页等，详情牌用法见本交付单「模板页套用要点」）；5A／5B 小A套模板时照「模板页套用要点」。
- 用户试玩说明：无（天启篇没对玩家开放）。开发版里进天启篇存档开物品、技能页能看到新布局；截图见「验证」。
- 需要用户决定：无。

## 进度账

- 天启篇新界面：页面重排 1/83（1A 主菜单）→ 4/83（＋物品 #22、技能 #26、说明卡 #62 换皮）；模板页完成（第 5 期约 30 页的底）。

## 模板页套用要点（给 5A／5B 套模板用）

1. **开关与挂钩**：页面 `_ready` 里 `if XUiSkin.on():` 才建新布局，否则走旧页、旧代码一行别动。旧页本来就有状态机的（商店、仓库、存读档……）照物品页做法：
   - `_ready` 末尾 `skin = XSkinXxxPage.new(self)`、`add_child(skin)`；**还要沿用的旧弹窗（数量窗、确认窗）建完 skin 后 `move_child(弹窗, -1)`**，不然被新布局盖住；
   - 旧页 `_refresh` 末尾 `if skin != null: skin.sync()`；
   - `_unhandled_input` 开头 `if skin != null and skin.input(event): XKeyMap.handled(self); return`（**必须 `XKeyMap.handled`**，不然按键漏给底下的地图）；没用掉的按键照旧走旧代码；
   - `_gui_input` 新布局时直接 return（点击由组件接）；**右键取消**要自己接：页面类 `_ready` 里 `mouse_filter = Control.MOUSE_FILTER_PASS`，`gui_input` 收到右键调旧页的取消（模板根节点默认 IGNORE，见 `XSkinItemPage._on_gui`）。
   - 新页面类放 `modes/xiyou/ui/skin/skin_<页>_page.gd`，`extends XSkinTemplatePage`。
2. **配置**（在 `_init` 里设，`_ready` 前）：`title`（页名）、`group_key`（顶上高亮哪组，`XUiSkin.GROUPS` 的 key；**商店、仓库这类不在主菜单的页写 `""`，不画页签条**）、`columns`（1 或 2）、`row_height`（`XUiSkin.ROW_H` 46／`ROW_H_ITEMS` 48）、`left_w`／`right_w`（默认 300／336，中块自动变宽封顶 720）、`auto_nav`、`hint_list`、`currencies`（默认只写精魂；要写印屑等传 `[[名字, 数值字]]`）。
   - `show_ring = false`（不要分类环）：模板自动把默认焦点放到列表（1B 返工起）；左块仍占 `left_w`，要么往 `layout.left.add_child(...)` 放自己的东西（技能页放了角色条），要么把 `left_w` 设小（不能为 0，最少留 8）。
   - 页内会变的货币（商店买卖）：改 `currencies` 后调 `top_layer.queue_redraw()`；默认的精魂每次重画都现读，不用管。
3. **喂数据**（图标的类型要分清）：
   - **传图标号（int）也行、传 Texture2D 也行**：`set_categories` 的 `icon`、`set_items` 的 `icon`、`open_menu` 的 `icon`（组件内部走 `XUiSkin.icon()` 缓存）。
   - **只认 Texture2D**：`set_card` 的 `icon`、`show_targets` 每行的 `face`、`set_items` 的 `badge`。从 `XUiSkin.icon(号)`／`XUiSkin.face(头像名, 格)` 取（缓存过的）；**别在 `_draw` 里直接 `XUI.icon_texture()`／`face_texture()`**（取完就释放，画出来白块）。
   - `set_categories([{key, name, icon, count}], 当前)`（名字后自动带数量）；`ring_center = [大字, 小字]`；环心要放贴图（头像）时 `ring.draw.connect(你的画法)`，参考 `XSkinSkillPage._draw_face`。
   - `set_items([{text, icon, color, right, right_color, sub, disabled, badge}], 选中)`：**第二个参数不传或传 -1＝光标回第 0 项、滚回顶**；传号＝保留并选中那项。
   - `set_card({icon, title, title_color, subtitle, desc, sections, buttons})`：`sections` 三种写法 `{title, lines:[{left,right,color,right_color}]}`／`{title, rows:[{text,color}]}`／`{title, text}`，title 可空；说明卡的行用 `XSkinTemplatePage.help_rows(XHelpCard.content(...))` 转；`buttons` 是 `[{text, primary, disabled}]`。
   - 「给谁用」：`show_targets(行, 能不能选, 全体, 选中)`，每行 `{name, face(Texture2D), kind("hp"/"mp"/"tp"), cur, max, right, right_color, dim}`，标题改 `targets.title`（默认「给谁用」）；传空数组收起。
4. **简单页（没有旧状态机）用自动导航**：`auto_nav = true`，接 `item_activated(i)`（列表确定）、`card_button(i)`、`category_changed(i)`（换分类后重新 `set_items`）、`back`（顶层取消：关页）；按键在页面 `_unhandled_input` 里 `if handle_input(event): get_viewport().set_input_as_handled()`。
   - 自动导航只走「环 ⇄ 列表」：环上确定进列表、列表取消回环、环上取消发 `back`；环上时鼠标点列表行也会进列表（1B 返工起）。
   - **不会自己进详情牌**：要让玩家在牌上点按钮，在 `item_activated` 里 `set_focus("card")`（焦点到牌时自动落在第一个按钮，左右换、确定发 `card_button`，取消回列表）；鼠标点按钮不用切焦点。
5. **有旧状态机的页用手动**：`auto_nav = false`，`sync()` 里按旧状态 `set_focus("ring"/"list"/"card"/"targets")`；**要弹操作菜单时调 `open_menu(行, 选中)`**（它会显示面板、算位置并把焦点设成 menu；只 `set_focus("menu")` 不会显示菜单），不用了 `close_menu()`；旧页确定／取消逻辑照用。
   - 信号回调里先判 `_syncing`（sync 时 `select` 会发 `index_changed`，别回写成死循环）；鼠标点环／列表时先看旧状态允不允许（选人、操作时点环不跨态，见 `XSkinItemPage._on_ring_changed`）。
   - 列表数据有变化才 `set_items`（比一个 key），不然每按一下都重建会卡。两列网格走法用 `XSkinItemPage.grid_move()`。
6. **按键提示**：随状态变用 `set_hint_list()`，键名套框是组件画的；提示右边已让出版本号。按小A口径：确定／取消／Q / E／X 这类键名，说明写两个字左右。
7. **宽屏**：模板进树就 `request_wide`（KEEP_HEIGHT），离开自动还原。沿用旧窗口的弹窗（数量窗等）按 1280 坐标摆，宽屏时自己平移 `(视口宽−1280)/2`、点击坐标减回去（见 `XSkinItemPage.legacy_offset()`）。
8. **测试**：照 `tests/xiyou_ui_skin_1b.gd`：建天启篇存档（`s.flags["tianqi"] = {"rules": 1}`）开页，查旧窗口隐藏、焦点、按键走法、用一次东西数量／数值对；西游存档、`XUiSkin.ENABLED = false` 各开一次查走旧页；关闭对照把页加进 `tests/xiyou_ui_skin_offshot.gd` 的 `PAGES`，跑 `07_开发环境/皮肤关闭对照.py --base main`。
9. 文字：新写的可见文字列进交付单「新增可见文字」表；样稿有、游戏没有的功能（如物品「丢弃」）不做。

## 验证

- `tests/xiyou_ui_skin_1b.tscn`：无头 79/79；有窗口 92/92（多 13 张截图）。覆盖：
  - 两列名字放不下：短名不动、先缩字（≥16）、再加省略号且不超宽；两列网格走法 9 种（左右一格、行尾行首换行、按住不换行、上下一行、到头循环、短列）；
  - 模板：三块锚点（左 300、右 336、1280 下中块 564、上下沿 72／668）、环带数量、两列 10 行一屏 20 项、自动页码随滚动、自动导航（环→列表→取消回环→back）、牌按钮（disabled 不触发）、操作菜单在右块内、目标列表留位且在按钮之上、`help_rows`（去转义码、两项用全角空格）、默认货币精魂；
  - 物品页：天启篇存档建新布局、旧窗口全藏；五类环与件数；列表 20 项一屏；环上左右换类；确定进列表；两列左右一格、上下一行；治疗药的牌（效果「回复生命」、「使用」按钮）、「给谁用」预估（缺 100 的人 +≤100、满血写「满」）；确定→操作菜单→使用→选人→下移一人→确定：数量减 1、血加；留在选人；取消逐层回分类；鼠标点列表＝进列表并选中；武器类小标题、「件」；西游存档、`ENABLED = false` 都走旧页；
  - 技能页：建页、旧窗口藏、类型环、确定进列表、两列右移、牌名字＝技能名、取消回类型、Q/E 换人回类型环；西游存档旧页；
  - 说明卡：天启篇存档换皮、西游存档旧框。
- **开关关掉与 main 一致**：`python3 07_开发环境/皮肤关闭对照.py --base main --out 04_验证/本地结果/ui_skin_1b/关闭对照` → 主菜单、状态、物品、**技能**、装备、设置 × 「西游存档开关默认」「天启篇存档 `ENABLED = false`」共 12 张逐像素 SAME（基线 main c4e5a375a，本分支含 1A）。
- 截图（有窗口，git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_1b/`）：`ui_skin_1b_items_category_16x9／20x9`（分类环有焦点）、`items_list_*`（列表＋详情牌＋给谁用）、`items_action_*`（操作菜单）、`items_target_*`（选人）、`skill_type_*`、`skill_list_*`、`help_card.png`（说明卡换皮）；`关闭对照/base`、`关闭对照/branch` 各 12 张。截图里中间那张「药水弟 获得新成就」是测试给物品时触发的成就弹窗，不是本页的。
- 选测（本地，`选测.py main --list` 87 个去掉事件对照四片和 `xiyou_floor_reach041`：本批没碰事件、楼层；82 个）：78 个一次过；`xiyou_ui_skin_menu`（1A 的）1 项按本批改了断言（物品页现在自己铺满，见上「改」）后 51/51；`xiyou_battle_log`（indicator.outline-sync）、`xiyou_map_hotkeys`（touch_save_slot1）、`xiyou_star_warehouse`（星级仓库名字色）在 82 个并行时各挂 1～4 项、单跑三个都全过（77/77、36/36、99/99），按偶发记，没碰这三处的代码。日志 `04_验证/本地结果/并行测试/20261115_072608_27q8o2m_/`、`20261115_073410_rrl5r3jq/`。
- `工具回归.py`：全部通过（98 秒）。`语法检查.py`：0 个问题。
- `发行空壳.py check`：**不过，但不是本批的**——报 `XTianqiQiyin.shards` 没有发行值，来源是合进来的 1A `skin_main_menu.gd`（本车道的文件不调 `XTianqiQiyin`）；请总装合 1A 时处理（或派回 1A 在 `发行空壳特例.json` 补一条）。
- **核查后返工复验**（小A c02f2b70e 之后）：`xiyou_ui_skin_1b` 无头 85/85、有窗口 98/98（截图重拍，覆盖原目录）；`皮肤关闭对照.py --base main` 12 张全 SAME；`语法检查.py` 0 问题；`发行空壳.py check` 仍只报 1A 的 `XTianqiQiyin.shards`（本车道文件不调它，等 1A 处理）。
- 给总装：`合并车道.sh --finish --affected --cloud`（事件对照四片本地没跑：本批只动物品、技能页和说明卡画法，事件对照不开这些页）。

## 可优化（流程／工具／效率）

- 已做：`tests/xiyou_ui_skin_offshot.gd` 加技能页，关闭对照覆盖 6 页（回退：PAGES 去掉 `XSkillScene`）。
- 建议：数量窗（批量服用、藏宝图）、检索面板、遗忘页还是旧窗口样式（黑面板），第 5 期可按模板的「操作菜单」样式重做成牌内弹层；归 5A。
- 建议：技能类型、物品分类的占位图标（取该类第一个技能的图标／挑的旧图标）等 co 出分类图标后在 `XSkinItemPage.CAT_ICONS`、`XSkinSkillPage._type_icon` 换。

## 本分支提交

- acb7c88e7 WIP：模板页、物品页、技能页、说明卡换皮、专项测试
- 09545e386 WIP：操作菜单时收起给谁用、说明行两项用空格隔开、关闭对照加技能页
- 0091d4709 WIP：按键提示随状态、让出版本号
- a3f0895e6 1A 主菜单专项改断言、交付单验证
- 另有合并：cc/ui-skin-p0、main（dev.598）、cc/ui-skin-1a（6c8a98368）

## 核查后返工（小A 乙档 c02f2b70e）

- P2：技能页按键提示随状态换：类型「确定 选择／取消 返回／Q / E 换人」、列表「确定 选择／取消 回类型／Q / E 翻页」、选人「确定 选择／取消 返回」；「回类型」「翻页」补进文字表。
- P3-1：模板 `show_ring = false` 时默认焦点自动放列表。
- P3-2：物品页在操作／选人／升级／镶嵌时、技能页在选人时，鼠标点环不跨态（环弹回原类）；镶嵌列表停在「取下镶嵌物」时牌标题写「取下镶嵌物」、小字写孔里现在镶的；目标列表名字放不下先缩字（≥14）再加省略号。
- P3-3：文字表补「空」「取下镶嵌物」「LV.%1」「减少魔法」。
- 套用要点 1～5 按小A指出的五处重写（XKeyMap.handled、弹窗层级、右键取消；show_ring=false、group_key 空、货币重绘；图标类型、show_targets 行格式、set_items(-1)、sections 三种、环心贴图；自动导航点列表与牌焦点；手动用 open_menu）。
- 模板顺手两处（为了要点 4 写得通）：自动导航时环上点列表行会进列表；`set_focus("card")`（以及焦点在牌上时 `set_card`）落在第一个按钮。
- **接口兼容**（1C 从这棵切的）：没有改任何函数签名、信号、字段名；行为变化只有上面三处默认值（无环默认焦点、自动导航点列表切焦点、牌焦点落第一个按钮），手动导航的页（物品、技能、1C 装备）不受影响，除非它自己 `set_focus("card")` 后还按一次「右」去选第一个按钮——那现在会选到第二个，1C 若这样用请改成直接确定。
- 验证：`xiyou_ui_skin_1b` 无头 85/85（新增 6 项：牌焦点第一个按钮、自动导航点列表、无环默认焦点、技能列表／类型提示、选人时点环不跨态）；见「验证」节后补的返工复验。

## 小A 乙档核查

- **核查对象**：`cc/ui-skin-1b`（交付提交 `d6c36554e`，相对已合入的 `cc/ui-skin-1a` `6c8a98368` 的 19 个变更文件），执行者：小A（只读核查＋轻量前台无头验证，未改游戏代码）。
- **结论：不通过**（P1 0 条；**P2 文字／按键提示必改 1 条**：`XSkinSkillPage` 未随状态切换 `hint_list`，列表态仍显示 `Q / E 换人` 与实际翻页行为不符；另有 P3 提示 3 条、模板页套用说明不清处 5 点）。

### 核查项与核实深度（分清规则本身／只看代码）

1. **开关隔离与旧页行为不变（核了源码＋跑无头专项＋跑已有对照图 `--compare`）**：
   - 读代码核实：`item_scene.gd`、`skill_scene.gd` 仅在 `XUiSkin.on()` 时构建 `skin = XSkinItemPage.new(self)`／`XSkinSkillPage.new(self)`，并在 `_refresh` 末尾 `skin.sync()`、`_unhandled_input` 开头 `skin.input(event)`、`_gui_input` 截断鼠标点击；`help_card.gd` 仅在 `skinned()`（即 `XUiSkin.on()`）时改画黑面板与 1px 品质色描边。原 `XItemScene`（使用／给谁用／批量／藏宝图／升级／镶嵌／法宝吃装备／检索／遗忘）与 `XSkillScene`（类型／列表／选人／吸取／Q/E 换人与翻页）状态机与逻辑一行未动，`gear_shown()` 在 `skin != null` 时返回 `false`、关皮肤时照旧。
   - 实跑无头测试：`语法检查.py`（902 个 `.gd` 0 问题）、`xiyou_ui_skin_1b.tscn`（79/79，含西游存档与 `ENABLED = false` 回退旧页）、`xiyou_ui_skin_menu.tscn`（51/51）、`xiyou_ui_skin.tscn`（88/88）、`xiyou_ui_skin_offshot.tscn`（12/12）；对工程内既有 `04_验证/本地结果/ui_skin_1b/关闭对照/` 12 张图实跑 `--compare` 全部 `SAME`（12/12，含新增 `XSkillScene` × `xiyou`/`tq_off`）。
   - `发行空壳.py check` 仅报合入自 1A 的 `XTianqiQiyin.shards`，1B 新增／修改文件未触发问题（只看代码＋实跑自检）。
2. **「给谁用」四人量条 `+n/满` 预估（核了 `battle_logic.gd` 计算规则本身＋读代码）**：
   - 对照 `XBattleLogic._apply_effect`（`battle_logic.gd:3097-3108`）：`11/12` 为 `(t.mhp/mmp * v1 + v2) * t.rec * u.pha`，`13` 为 `v1`。`XSkinItemPage.preview_gain` 与 `target_rows`、`XItemScene._effective_for` 均为纯只读计算，不写 `XActor` 字段、不碰 `_action_resources`、不改 `XItemScene._use()`；`_effective_for` 临时替换并立即恢复 `_item` 仅用于只读判定 `dim`。
   - 细小差异（只看代码）：`battle_logic.gd` 对每条效果分别 `floorf`，`preview_gain` 先累加再 `floorf`（同一物品含多条同类回复时可能有 1 点舍入差）；无 `can_move` 角色时预览按 `pha=1.0` 算而实际 `_use()` 会蜂鸣拒绝；复数回复（同时回血回蓝）仅展示 HP 条与 HP 预估（受单条限制）。
3. **1A 专项 `xiyou_ui_skin_menu.gd` 断言修改（核了 `XSkinLayout` 计数机制＋读代码＋跑专项）**：
   - **正当的行为变化（非放松断言）**：1A 时物品页仍为旧 1280×720 布局，主菜单打开物品页会让出 `KEEP_HEIGHT`；1B 起 `XItemScene` 在天启篇下自建 `XSkinItemPage`（继承 `XSkinTemplatePage`，`_ready` 调 `XSkinLayout.request_wide(self)`），主菜单让出 1、物品页接上 1。新断言 `wide_held_by_new_item_page` 同时核 `page.get("skin") != null`、`KEEP_HEIGHT` 和 `XSkinLayout._wide_users == 1`，比原来更严且无泄漏（51/51 通过）。
4. **模板页套用要点 9 条对 5A／5B 可用性（读完组件与模板源码，站在后续使用者视角核对）**：
   - 整体思路清晰可用，但存在 **5 处说明不清／易踩坑点**（见下「模板说明不清处」），其中 `show_ring = false` 时模板默认 `focus` 仍为 `"ring"` 最易在 5A／5B 踩坑。
5. **文字审与两列名字截断（对照 `cc_ui-skin-p0.md`／`cc_ui-skin-1a.md` 所记 `ba1f7ed` 口径＋源码全量提取＋核对交付单表）**：
   - **两列名字截断**：已解决（读代码＋专项验证 `fit_short_keeps`/`fit_shrinks_first`/`fit_ellipsis`）。`XSkinList.fit_text()` 先将字号从 19 缩至最低 `min_font_size = 16`，仍超宽再按像素宽度截断并加 `…`（`XSkinCard` 标题亦同法缩至 20 号再加 `…`），第 0 期陈列图「治疗药水(」硬裁问题已消除。
   - **已有文字核对**：货币「精魂」、分类「种／件」、持有与类别名「重要物品／消耗品／物品 · 持有 %d」、效果／用法（`效果　回复生命 500` 等全角空格分隔）、「给谁用／给谁学」「满」「+n」「使用」「升级材料」「镶嵌宝珠」「（已筛选）」「第 %d / %d 页」「类型名 · %d 个」均符合 `ba1f7ed` 与 `v0.7` 口径（样稿有但游戏无的「丢弃」未做，正确）。
   - **文字必改 1 处（P2）**：见下问题清单与改好文字。

### 问题清单（P1/P2/P3）

- **P1**：无。
- **P2（文字／按键提示必改 1 条）**：`modes/xiyou/ui/skin/skin_skill_page.gd`（`L24` 及 `sync()`）未按 `scene.mode` 切换 `hint_list`，始终显示 `确定 选择／取消 返回／Q / E 换人`。实际在 `skill_scene.gd:516-519` 中，`mode == "list"` 时 `Q / E` 走 `XMenu.page_dir` 是**翻页**（不是换人），且 `取消` 是回类型环；`mode == "actor"` 时 `change_actor` 直接 `return`（`Q / E` 无效）。
  - **必改改法（给改好的字）**：在 `XSkinSkillPage.sync()` 中按 `sc.mode` 调用 `set_hint_list(...)`：
    - `"type"` 态：`[["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"]]`
    - `"list"` 态：`[["确定", "选择"], ["取消", "回类型"], ["Q / E", "翻页"]]`
    - `"actor"` 态：`[["确定", "选择"], ["取消", "返回"]]`
  - 同步把 `回类型`、`翻页` 补入本交付单「新增可见文字」表。
- **P3-1（模板页 `show_ring = false` 默认焦点隐患）**：`skin_template_page.gd:71,139` `focus` 默认 `"ring"`；若 5A／5B 设 `show_ring = false` 而忘手改 `focus = "list"`，首帧列表无选中条且方向键空打隐藏环、按取消直接退出。建议模板 `_ready()` 加 `if not show_ring and focus == "ring": focus = "list"`。
- **P3-2（鼠标点击环／列表与旧态拦截微差）**：`skin_item_page.gd`、`skin_skill_page.gd` 的 `_on_ring_changed` 未拦截 `actor`／`action`／`upgrade`／`augment` 态下鼠标点左环（会直接切回 `category`/`type`）；另 `skin_item_page.gd:229` 镶嵌列表停在「取下镶嵌物」（`rec` 为空）时右牌会退回显示分类统计标题而非「取下镶嵌物」；`skin_target_list.gd:127` 角色名 `name_w = 72` 直接限宽截断未用 `fit_text`（5 字以上角色名会硬裁）。
- **P3-3（交付单文字表小遗漏）**：1B 代码中复用的「空」（`XSkinList.empty_text`）、「取下镶嵌物」（`YEP_X_AttachAugments` 兜底）、「LV.%1」（`YEP_SkillMasteryLevels` 兜底）、「减少魔法」未单独写进上表（均为既有／衍生字，文字本身无问题）。

### 模板页套用要点（5A／5B）说明不清处

1. **要点 1 截断输入漏了 `XKeyMap.handled(self)` 与弹窗层级**：要点 1 写 `if skin != null and skin.input(event): return`（与要点 4 `set_input_as_handled()` 不一致；不调 `XKeyMap.handled(self)` 会漏按键给底层）；沿用旧弹窗（数量窗、确认窗）须在 `_ready` 建完 `skin` 后 `move_child(弹窗, -1)`；且模板页默认 `mouse_filter = IGNORE`，**右键取消**不会自动生效，需像物品／技能页那样自设 `MOUSE_FILTER_PASS` 接 `gui_input`。
2. **要点 2 漏写 `show_ring = false` 的焦点与左块安排**：设 `show_ring = false` 时必须同时设 `focus = "list"`（或等模板修 P3-1），且 `left_w` 默认仍占 300（需写明是 `layout.left.add_child(...)` 自放信息还是缩 `left_w`，以及 `group_key = ""` 用于商店／仓库等非主菜单页）；页内若会改货币（如商店买卖），需同步刷新 `currencies` 并调 `top_layer.queue_redraw()`。
3. **要点 3 图标／角标类型不统一、部分字段缺失**：写「图标用图标号」仅对 `set_categories`/`set_items`/`open_menu` 的 `icon` 成立；**`set_card({icon})`**、**`show_targets([{face}])`** 与 **`set_items` 的 `badge`** 均要求传 `Texture2D`（不能传 `int`）。另缺 `show_targets` 行字段格式（`{name, face, kind, cur, max, right, right_color, dim}`）与 `targets.title` 说明、未说明 `set_items(arr, -1)` 传 `-1` 会重置光标到第 0 项、未说明 `sections` 还支持 `{title, text}` 及 `ring` 中心放贴图需连 `ring.draw`／`center_texture`。
4. **要点 4（自动导航）缺鼠标点列表切焦点与 `"card"` 焦点说明**：`auto_nav = true` 时在 `"ring"` 态用鼠标点击列表行不会自动把 `focus` 切到 `"list"`；`auto_nav` 不会主动进入 `"card"` 焦点，且 `set_card` 会把 `button_index` 重置为 `-1`（`set_focus("card")` 后需按左右才会选中按钮 0）。
5. **要点 5 手动开操作菜单**：要点 5 只写 `set_focus("menu")`，实际手动模式打开操作菜单应调 `open_menu(rows, idx)`（`set_focus("menu")` 不会自动显示 `menu_panel` 与重算位置）。

### 没核到的（留给总装 `--affected --cloud`）

- 未重跑有窗模式的 `皮肤关闭对照.py --base main` 与 `xiyou_ui_skin_1b.tscn -- --out=...` 截图重拍（本次仅对工程内已有对照图运行了 `--compare`）；
- 未跑 `并行测试.py`、`选测.py` 全集、`工具回归.py`、`xiyou_tianqi_e2e`、`xiyou_virtual_player` 及事件对照四段（按派单要求留给总装 `--affected --cloud`）；
- 未在仓库外读取私密设计仓 `重制设定/界面风格提案_v0.7/` 原件，文字审对照 `cc_ui-skin-p0.md` 与 `cc_ui-skin-1a.md` 所载 `ba1f7ed` 核查口径完成。
