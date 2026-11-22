# 交付：luiluu/t368

- 车道／工作者：T368 卡 G 装备检索重做成筛选小块（T254 R9）／cc 车道（Opus＋medium，P8）
- 状态：可合并（R2 热修 P1-3 已做，待小A 复核；R1 旧项小A 已确认修好）

## R2 热修（小A 核报告 `xiyou-design-docs/协作交接/派单/T368_核报告R2.md`，只修 P1-3）

- **P1-3**：输入态点右下「取消 收起」／触屏「收起」或左上「‹」，`gear_search._input` 先按「点在输入框外」收起，提示切成「取消 返回」，同一下点击再落到提示条／返回钮派 `ui_cancel` 把整页关掉。改法：`XSkinGearSearch.tap_outside_edit` 排除提示条里点中的那颗胶囊（`hints.hit`）和 `back_button` 区域，让它们自己的取消去收起输入框。
- 复现测试（专项 `xiyou_t368_gear_r9` 新增 7 条，`get_viewport().push_input(e, true)` 经真实视口按下＋松开）：`r2_p1_3_desk_hint_collapses_only`（桌面点「取消 收起」）、`r2_p1_3_touch_hint_collapses_only`（触屏点「收起」）、`r2_p1_3_back_collapses_only`（点「‹」）——都断言输入框收起、检索页仍在；换回旧代码三条各自失败（逐条单独跑过）。

## R1 返修（小A 核报告 `xiyou-design-docs/协作交接/派单/T368_核报告R1.md`，P1×2 P2×4 P3×2 逐条）

| 条 | 改法 | 复现测试（专项 `xiyou_t368_gear_r9`，开头 `XKeyMap.apply()` 照实机键位，经 `gs._input` 走） |
| --- | --- | --- |
| P1-1 X 关页 | `gear_search.gd` `_input`：没在输入时 KEY_X（含点「X 搜词条」胶囊合成的键）先于 `popup_cancel` 判成搜词条 | `r1_x_is_cancel_bound`、`r1_p1_1_x_opens_search`（换回旧 `_input` 实测失败：58/59，失败即收尾不挂住） |
| P1-2 打字 x/k/小键盘 0 关框 | 删掉 `or (page.typing() and ui_cancel)`，只走 `XKeyMap.popup_cancel` | `r1_p1_2_typing_keeps_88/75/4194438`；Esc、触屏「取消」仍收起：`r1_esc_closes_search_only`、`r1_action_cancel_closes_search` |
| P2-1 点别处 typing 卡住；Y 被牌拦 | 输入时点在输入框外先 `close_search()`（点击照常落到被点处）；`open_picker` 先收输入框；输入时牌 `set_process_input(false)`（展开的先收回），收起时还原 | `r1_p2_1_tap_chip_closes_search`、`r1_p2_1_keys_work_after`、`r1_p2_1_tap_inside_keeps`、`r1_p2_1_picker_closes_search`、`r1_p2_1_card_no_y_while_typing` |
| P2-2 挑选框箭头出框 | `_place_picker` 照模板页左留 28（`XSkinArt.select_on()`，否则 8） | `r1_p2_2_picker_margin`；截图 `7_picker_sort` |
| P2-3 点列表焦点不回 | `list.gui_input` 按下时焦点在筛选区／牌上就切 `list`（不接 `index_changed`，免得 `set_items` 内部回调误切） | `r1_p2_3_tap_list_focus`、`r1_p2_3_tap_list_from_card` |
| P2-4 30 种部位溢出 | 新 `type_chip_size`：按左块高减其余固定高（`FIXED_H`）算，放不下逐像素收小（最小 24）；少于 4 行仍 36 | `r1_p2_4_30_types_fit`（1/7/14/21/28/30/35 种）、`r1_p2_4_few_types_full_size`、`r1_fixed_h_matches_layout` |
| P3-1 文字 | 照小A：「⌕ 搜词条」→「搜词条」＋自画放大镜；「原序」→「默认」、「单项词条」→「词条」；占位「搜装备名或词条，空格隔开」；输入态提示「取消 收起」（可点） | `r1_p3_sort_names`、`r1_p3_search_text`、`r1_p3_typing_hint_tappable` |
| P3-2 字号、部位名预览 | 自画字号过 `XUiSkin.fs()`（输入框本来就用 `FS_AUX_MAX`＝`fs(17)`）；光标停在部位图标上，「部位」旁写「› 名字」，移开回到已选 | `r1_p3_type_preview`、`r1_p3_type_note_back`；截图 `c_type_cursor_preview` |

- 截图重拍：`00_项目管理/归档/交付截图/T368_装备检索/`（原 11 张全部重拍＋新增 `c_type_cursor_preview`）。

## T361 已做／R9 还差（开工对照表）

| R9 要求 | T361（dev.832）现状 | 本单 |
| --- | --- | --- |
| 左上「‹」返回 | 已做（P2-3） | 沿用（模板页自带） |
| 去掉「关闭 · Esc」、开发腔文案 | 已做 | 沿用 |
| 品质七枚色块、点一下生效 | 差：品质还是下拉，收在「筛选」面板里，要先点「筛选」再开下拉 | 做：七枚色块常驻左块，可多选 |
| 部位一排图标 | 差：下拉 | 做：一排图标（放不下折行），单选、再点取消 |
| 位置两枚 | 差：下拉三项 | 做：「已装备」「背包」两枚，都不点＝背包＋已装备 |
| 排序四枚 | 差：下拉 13～15 项 | 做：「品质」「词条数」「名称」「更多 ▾」，其余排序在「更多」挑选框 |
| 「搜词条」收成按钮、点了才弹键盘 | 差：搜索框常驻，开页就 `grab_focus`（安卓一开页就弹键盘） | 做：一枚按钮，点了才出输入框并聚焦；回车／取消收起，按钮写「搜：…」，✕ 清掉 |
| 结果用通用列表 | 差：自建 Button 行（XWebPanel） | 做：`XSkinList`（模板页中块，一列，翻页件） |
| 右详情牌 | 差：自建滚动框＋词条卡 | 做：`XSkinCard`（折叠、Y 看完整），牌底主按钮「按此筛选」 |
| 分类、指定词条 | （R9 没写）下拉 | 各一枚小块，点开挑选框（旧页每项都要取得到） |
| 20:9 | T361 版整块 1280 居中 | 模板页横屏锚点（XSkinLayout），中块变宽 |

## 变更记录草稿

## 2026-11-22 【cc·T368·未经审查】装备检索重做成筛选小块（T254 R9，卡 G）（dev.待定）

- 依据：Kyo 11-22 事项 19「两批一起开」；私密设计仓 `重制设定/界面风格提案_v0.7/T254_剩余页细节设计.md`（294eda1）§二 R9、卡 G；已做-3「重排成和别的页一个样，功能和筛选规则不变」。T361（dev.832）做过的返回钮、去关闭框沿用，只补上表「本单」一列。
- 新页 `modes/xiyou/ui/skin/skin_gear_search.gd`（`XSkinGearSearch`，套 `XSkinTemplatePage`，不要分类环、手动焦点）：左块筛选小块（搜词条按钮；品质七枚色块＋「★」旧档细分；部位图标；位置两枚；排序四枚；分类 ▾、指定词条 ▾；清空条件），点一下就重算结果；中块通用直列表（小标题「符合 a / b 件 · 排序：…」，没有结果时列表正中一句）；右块详情牌（名字品质色、品质与位置、能力格子、说明、按分类的词条，牌底「按此筛选」）；挑选框盖在中块上（分类、指定词条、更多排序、旧档品质多选）。按键：筛选区方向键走小块、确定切换、→ 到行尾进列表；列表 ← 回筛选区、确定到「按此筛选」；X 搜词条；取消依次收输入框 → 挑选框 → 牌 → 关页。条件与结果仍在 `XGearSearch.filter`／`results`，详情仍取 `XGearSearch.detail_blocks`（牌上一块不落）。
- `modes/xiyou/ui/gear_search.gd`：新开关 `XGearSearch.SKIN_PAGE_R9`（默认开，新皮肤下走新页；false＝回到 T361 版式，`SKIN_PAGE_V2` 照旧管 T361 版和网页换皮版）；新页时不整块居中、不画旧框，取消／方向键转给新页。皮肤关着一行不变。
- **单列请核查重点看**：`modes/xiyou/core/gear_query.gd` 的 `matches`（不在本单独占文件，协调 11-22 准 A 方案）：品质条件可写逗号分隔多个（七档号或 L＋旧档号），逐个 OR；单个值与原写法逐件相同（专项 `single_grade_0～6`、`single_legacy_12/14/15` 对照）；新增 `_quality_hit`。物品页、装备页拿到多选品质的条件照样筛。
- 测试：`tests/xiyou_t361_unslop.gd` 的检索段（量的是 T361 版式）开头关 `SKIN_PAGE_R9`、结尾还原，断言不变。
- 玩家可见：天启篇里装备检索换成左边一排排能点的小块（品质色块可多选、部位图标、位置、排序），中间是结果列表，右边详情牌；开页不再弹键盘，点「搜词条」才弹。

## 验收（卡上 6 条）

1. 对照表：见上「T361 已做／R9 还差」，只做「差」的部分。
2. 品质七色块（多选）、部位一排图标、位置两枚、排序四枚点一下生效：专项 `two_qualities*`、`type_on/off`、`scope_*`、`sort_*`、`sort_more_*`、`sort_param`；搜词条弹键盘前后：`no_keyboard_on_open`（开页输入框不可见、不聚焦）、`search_opens_edit`（点了才聚焦）、`search_closes`。
3. 截图（真窗口，`tests/t368_shots.tscn`，16:9＝800×450、20:9＝1000×450）：本机在 `03_再刷重制_Godot/04_验证/本地结果/T368_截图/`：`1_default_16x9`、`2_two_quality_one_type`、`3_search_before`、`4_search_after_typing`、`5_search_done`、`6_no_result`、`7_picker_sort`、`8_default_20x9`、`9_two_quality_one_type_20x9`；对照 `a_before_t361`（R9 关）、`b_skin_off`（皮肤关）。本机没有虚拟键盘，「弹键盘后」拍的是输入框出来、已聚焦、写了字的样子，真机键盘没拍。
4. 旧页每项新页都取得到：`old_options_all_reachable` 逐行走旧页六个下拉的每个选项（分类 10、部位全部、品质七档＋L12/14/15、位置三项、指定词条全部、排序全部含「单项词条」），用新页的点法设到同一条件；`card_has_every_detail_block` 逐件核详情块的字都在牌上。皮肤关对照：`skin_off_web`＋截图 `b_skin_off`；旧专项皮肤关时不变：`xiyou_gear_search` 60/60、`xiyou_power_hidden` 21/21、`xiyou_ui_skin_close` 71/71、`xiyou_ui_skin_1c`（云端）。
5. 一个开关可回退：`SKIN_PAGE_R9`（`rollback_r9_t361`）；通用件（模板页、列表、详情牌、按键提示）只用不改；`发行空壳.py check` 退出 0；云端选测前台等完（见验证）。
6. 文字：见下节。

## 文字（玩家可见新字，草稿，待小A 审）

- （R1 已照小A 文字审改，下列为改后）小块：「搜词条」（前面自画放大镜）「搜：<词>」「✕」「已装备」「背包」「品质」「词条数」「名称」「更多 ▾」「默认 ▾」「词条 ▾」「战力 ▾」（八项能力时写能力名，如「物攻 ▾」）「分类：全部 ▾」「指定词条：不限 ▾」「清空条件」
- 组名与说明：「品质」「部位」「位置」「排序」，组名后写当前选择（「全部」、多选品质用「、」连，如「精良、传说」）
- 输入框占位：「搜装备名或词条，空格隔开」
- 列表小标题：「符合 a / b 件 · 排序：<排序名>」；空列表：「没有符合的装备，放宽条件再找找。」
- 挑选框标题：「分类」「指定词条」「排序」「品质细分（可多选）」
- 牌：节名「能力」（其余节名、按钮「按此筛选」沿用 T361）
- 按键提示：「切换」「搜词条」「选择」「返回」「按此筛选」「返回列表」「关闭」「取消 收起」（输入态）；光标在部位图标上：「部位 › <名字>」

## 验证

- R2 本机（`--headless --audio-driver Dummy`，独立 HOME）：`xiyou_t368_gear_r9` 105/105；`xiyou_gear_search` 60/60；`xiyou_t361_unslop` 44/44；`语法检查.py` 0 问题；`发行空壳.py check` 退出 0；`交付自检.py` 可以交付。R2 云端选测（39451f1bb，6 个场景）：通过，`gh run watch` 前台等完 success（run 44971149713）。
- R1 本机（`--headless --audio-driver Dummy`，独立 HOME）：`xiyou_t368_gear_r9` 98/98；`xiyou_t361_unslop` 44/44；`xiyou_gear_search` 60/60；`xiyou_ui_skin_close` 71/71；`语法检查.py` 0 问题；`发行空壳.py check` 退出 0；`交付自检.py` 可以交付。R1 云端选测（4b1542c09，14 个场景）：通过，`gh run watch` 等完 success（run 44968469067）。
- 原单本机专项：`xiyou_t368_gear_r9`（新增）75/75；`xiyou_t361_unslop` 44/44；`xiyou_gear_search` 60/60；`xiyou_ui_skin_close` 71/71；`xiyou_power_hidden` 21/21。
- 本机：`语法检查.py` 0 问题；`工具回归.py` 全过；`发行空壳.py check` 退出 0；`回退开关覆盖.py` 只有旧的解析不了条目（与本单无关）。
- 云端选测（bd67df8037，19 个场景、3 片）：全过；`gh run watch` 前台等完，结论 success（选测.py 列的 19 个场景：含 xiyou_event_compare 四个、xiyou_ui_skin_1c／close／offshot、xiyou_gear_search、xiyou_gear_ui、xiyou_item_list、xiyou_gear_query_cache、xiyou_input_handled 等）。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇物品页或装备页按 X 打开装备检索，点品质色块（可多点）、部位图标、位置、排序，看结果；点「搜词条」才弹键盘。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议（归设计／小A 文字审）：部位图标取检索源里该部位第一件装备的图标（同 R7 先用现有图标），没有专门的部位图标；有正式部位图标后换掉即可（`XSkinGearSearch.type_icons`）。
- 建议：fixture 里有武器类型 0（类型名为空），部位名显示「武器 · 0」，旧下拉同样如此，没改。

## 本分支提交

- bd67df803 T368 卡 G 新页、开关、品质多选、专项与截图工具
- ffd35be5f 交付单
- 4b1542c09 R1 返修：P1×2 P2×4 P3×2、专项补 23 条复现、截图重拍
- b2027f108 交付单补 R1 云端选测
- （本提交）R2 热修 P1-3：输入态点提示条／「‹」只收输入框、专项补真实视口点击 3 处
