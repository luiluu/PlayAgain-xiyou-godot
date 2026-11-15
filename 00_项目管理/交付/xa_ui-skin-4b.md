# 交付：xa/ui-skin-4b

- 车道／工作者：新界面 4B 换皮／小A（ag）
- 状态：可合并

## 开关与回退

- 全局皮肤开关：`XUiSkin.ENABLED`（`modes/xiyou/ui/skin/ui_skin.gd`，仅在天启篇存档且非发行门时为 `true`，重制版／西游存档与 `ENABLED = false` 时一律走原版旧界面，零改动）。
- 4B 新增提示条／横幅／弹窗／设置汉化全部随 `XUiSkin.on()` 切换，不再另设独立开关。

## 改动文件清单

| 分批 | 文件（相对 `03_再刷重制_Godot/01_Godot工程/`） | 内容 |
| --- | --- | --- |
| 批1 | `modes/xiyou/ui/message_box.gd`、`modes/xiyou/ui/choice_window.gd`、`modes/xiyou/ui/mv_canvas.gd`、`modes/xiyou/ui/mv_text.gd` | 对话框（消息框／名字框／选项列表／数值输入）、独立选项窗换黑面板＋细线、红乙选中条、思源黑体／宋体／数字窄体、按键提示让位与宽屏居中适配 |
| 批2 | `modes/xiyou/ui/toast.gd`、`modes/xiyou/ui/autosave_notice.gd`、`modes/xiyou/ui/power_notice.gd`、`modes/xiyou/ui/prestige_notice.gd`、`modes/xiyou/ui/skill_notice.gd`、`modes/xiyou/ui/achievement_popup.gd` | 漂浮提示条、自动存档提示、战力变动通知、至臻入手通知、技能升级通告、成就弹窗（含 142/143 徽章适配）黑面板胶囊／金边／干净字重排 |
| 批3 | `modes/xiyou/map/difficulty_notice.gd`、`modes/xiyou/map/map_scene.gd`、`modes/xiyou/map/treasure_popup.gd`、`modes/xiyou/map/designation_plate.gd` | 难度横幅胶囊化与 2B 遗留（首领血弧让位 `XSkinBossArc.arc_bottom() + 48.0`，地图快照 `XMapScene._snapshot()` 开皮肤时隐藏不烤进战斗背景）、地名横幅、拾取浮字（保持 `text()` 为 `"x"` 契约、显示 `_display_text()` 用 `"×"`）、称号铭牌 |
| 批4 | `modes/xiyou/ui/map_transfer.gd`、`modes/xiyou/ui/item_scene.gd`、`modes/xiyou/ui/skin/skin_item_page.gd`、`modes/xiyou/ui/skin/skin_card.gd`、`modes/xiyou/ui/skin/skin_template_page.gd`、`modes/xiyou/ui/help_card.gd`、`modes/xiyou/ui/hang_up_options.gd`、`modes/xiyou/ui/hang_up_sub_page.gd` | 传送页全套换皮与 20:9 宽屏动态列宽/鼠标坐标；午前记账 `item_bag_return` 提示条并入 `XSkinItemPage` 右侧详情牌 `XSkinCard.notice`（关闭老 `help_card` 遮挡）；`XHelpCard` 暗底可读配色映射与 `place_near` 宽屏安全区；挂机设置主/子页仅在 `XUiSkin.on()` 下将 `open`/`Open`/`YES`/`NO`/`ON`/`OFF` 汉化为「进入／是／否／开／关」 |
| 专项 | `tests/xiyou_ui_skin_4b.gd`、`tests/xiyou_ui_skin_4b.gd.uid`、`tests/xiyou_ui_skin_4b.tscn` | 4B 全项功能开关对比、2B 首领血弧让位、新旧并排 16:9 / 20:9 截图 |

## 新增可见文字

（注：设计仓 `xiyou-design-docs` 位于本工作树之外无法直接读取，以下按协调指示基于 `cc_ui-skin-p0.md`、1B 模板页及既有文案口径处理，拿不准的已在下节标出。）

| 文字 | 位置 | 说明 |
| --- | --- | --- |
| `进入` | `XHangUpOptionsScene` / `XHangUpSubPage`（天启篇） | 原 `open` / `Open` 的仅天启篇汉化 |
| `是` / `否` | `XHangUpOptionsScene`（天启篇） | 原 `YES` / `NO` 的仅天启篇汉化 |
| `开` / `关` | `XHangUpSubPage`（天启篇） | 原 `ON` / `OFF` 的仅天启篇汉化 |
| `确认传送至 %s？` | `XMapTransferScene` 确认框（天启篇） | 原 `是否传送至 %s?`，改用全角问号统一语气 |
| `确定 继续` / `确定 确认传送` / `取消 重选地图` / `确定 掉落详情` / `← / → 换位` / `↑ / ↓ 调数` | `XMessageBox` / `XChoiceWindow` / `XMapTransferScene` 的 `XSkinKeyHints` | 沿用 `XSkinKeyHints` 与 1B 按键提示口径 |
| `%s × %d` | `XTreasurePopup._display_text()`（天启篇） | 原 `x` 改展示 `×`，内部 `text()` 保持 `x` 以兼容 `xiyou_flow` |

## 拿不准待确认项（因设计仓不可读）

1. `XPrestigeNotice` 闪屏色：目前在皮肤开启时用 `XUiSkin.GOLD` 替代原版 `FLASH_COLOR`，如需保持原版浅金 `#ffdb82` 一行可调。
2. `XHelpCard._skin_color()` 映射：将原版蓝/亮黄映射到 `XUiSkin.MP_TEXT` / `XUiSkin.GOLD_LIGHT`，`robe_card` 边框用 `XUiSkin.HP`，请结合实机观感微调色阶。
3. 挂机设置主/子页除 `open/YES/NO/ON/OFF` 汉化与字体切 `XUiSkin` 外，未重做成模板三栏页（本批只要求汉化 ON/OFF）。

## 变更记录草稿

## 2026-11-15 【ag·小A·未经审查】新界面 4B 换皮（dev.待定）

- 完成天启篇 4B 批界面换皮（全项随 `XUiSkin.on()` 生效，重制版与皮肤关闭完全走原版路径）：对话框 `XMessageBox`、独立选项窗 `XChoiceWindow`、漂浮/存档/战力/至臻/技能/成就提示与弹窗、难度横幅（含 2B 遗留：避让 `XSkinBossArc` 与地图快照隐藏）、地名横幅、拾取浮字、称号铭牌、传送页。
- 顺带两项：物品页 `item_bag_return`「已生效…」提示条接入 `XSkinCard.notice` 并在 `XHelpCard` 补充暗底配色映射与宽屏 `place_near`；挂机设置主/子页 `open`/`Open`/`YES`/`NO`/`ON`/`OFF` 仅在天启篇汉化为「进入／是／否／开／关」。
- 玩家可见：天启篇存档下对话、通知、传送、地图浮标与挂机设置开关改为红乙暗底风格并适配 20:9 宽屏，重制版保持原貌。

## 交接板

- 下一步：总装运行 `--affected --cloud`（含事件对照、`xiyou_flow`、`xiyou_ui_skin_battle` 及长测试）并合并进 `main`，顺带做新旧截图肉眼复核。
- 用户试玩说明：在天启篇存档下触发对话、物品使用通知、传送页面、拾取/称号与挂机设置即可见到红乙暗底新界面。
- 需要用户决定：无（上述拿不准项已做成随 `XUiSkin.on()` 微调的展示参数，可随时按截图反馈调色）。

## 进度账

- 新界面换皮：4B 批（9 项范围 + 2 项顺带 + 2B 首领血弧让位遗留）完成，待总装合并与审查。

## 可优化（流程／工具／效率）

- 建议（非本车道范围，不改动共用测试）：`tests/xiyou_help_card.gd` 未调用 `TestEnv.isolate()`，会受本机真实 `user://options.json` 的 `codexPowerEnabled` 开关影响（本机运行 `xiyou_help_card.tscn` 时因环境配置返回 949/1075，缺「装备战力：」行）；建议后续在测试车道补上 `TestEnv.isolate("xiyou_help_card")` 以保证与宿主配置解耦。

## 验证

- `语法检查.py`：929 个 `.gd`，0 个问题。
- `发行空壳.py check`：61 个脚本，528 个函数全部通过。
- 前台单项通过：
  - `tests/xiyou_ui_skin_4b.tscn`（无头）：67/67。
  - `tests/xiyou_ui_skin_4b.tscn`（有窗口截图）：78/78；新旧并排截图已保存至 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_4b/`（9 张 16:9 `2564×720` + 2 张 20:9 `2884×720`，共 11 张）。
  - `tests/xiyou_ui_skin_offshot.tscn`：29/29。
  - `tests/xiyou_ui_skin.tscn`：89/89。
  - `tests/xiyou_ui_skin_5c.tscn`：79/79。
  - `tests/xiyou_ui_skin_1b.tscn`：85/85。
  - `tests/xiyou_transfer.tscn`：53/53。
  - `tests/xiyou_hangup_options.tscn`：57/57。
  - `tests/xiyou_item_bag.tscn`：160/160。
  - 批2／批3 回归：`xiyou_autosave.tscn` 10/10、`xiyou_achievement_badge.tscn` 34/34、`xiyou_difficulty_notice.tscn` 25/25、`xiyou_designation_plate.tscn` 2/2、`xiyou_hud.tscn` 34/34。
- 留给总装（`--affected --cloud`，按派单未在本地跑超过 2 分钟的全套／跨模块长测试）：
  - `选测.py main` 完整受影响集（含 `xiyou_event_compare*.tscn`、`xiyou_flow.tscn`、`xiyou_ui_skin_battle.tscn`、`皮肤关闭对照.py` 全量逐像素比对）。

## 本分支提交

- `23ce817f5` 新界面4B：对话框与选项窗换皮（dev.待定）
- `1caafe5ca` 新界面4B：提示条、通知与成就弹窗换皮（dev.待定）
- `a18202ccc` 新界面4B：难度横幅、地名横幅、拾取浮字与称号铭牌换皮（dev.待定）
- `bde474b02` 新界面4B：传送页、物品通知、说明卡与挂机设置换皮（dev.待定）
- `8650e66b3` 新界面4B：补充4B专项测试与新旧并排截图对比（dev.待定）

## cc 乙档核查（cc 核查车道，2026-11-15）

结论：**通过**（P1 0、P2 1、P3 5）。本工作树只读，没改游戏代码。

**跑了的**（前台，`并行测试.py --full`，独立 HOME）：`xiyou_ui_skin_4b` 67/67、`xiyou_ui_skin` 89/89、`xiyou_ui_skin_1b` 85/85、`xiyou_ui_skin_5c` 79/79、`xiyou_help_card` 1075/1075。

**核了规则本身（读 diff＋跑测试）**
1. 皮肤关闭：`XUiSkin.on()`＝`ENABLED` 且 `XTianqiLine.open_for` 且设置页选新界面；重制版／西游存档恒为假。逐文件读过，关闭分支都回旧画法：难度横幅字体／尺寸／位置、地名牌（补了 `size`、`font`、`clean_text` 复位）、拾取浮字、铭牌、toast、power／skill／achievement、帮助卡 `_paint` 的 `font`／`clean_text` 复位（默认字体同为 `XUI.font()`，与 main 等价）。挂机设置的「进入／是／否／开／关」只在 `on()` 下出现，重制版仍是 open／YES／NO／ON／OFF，4B 专项有 `hu_*_en`／`hu_*_cn` 两侧断言。
2. 首领血弧：**真正起作用的是快照隐藏**——开皮肤时 `_snapshot()` 临时隐藏难度横幅、战后恢复；开战前 `difficulty_notice.hide()`、`can_paint` 在 `_in_battle` 时为假，战斗中横幅本来就不画。`_boss_arc_bottom()` 让位只在「战斗节点与横幅同层且血弧可见」时生效，真实流程里走不到，测试是用造的 `XBattleScene` 节点验的（`diff_yields_to_boss_arc`），算兜底。快照隐藏只动难度横幅、地名牌、对话框，与原有隐藏同位置同方式，存档截图（存档缩略图另走）不受影响（没看到存档截图代码用 `_snapshot`，只读判断）。
3. 通知触发时机：toast／autosave／power／prestige／skill／achievement／treasure／designation 的改动都在绘制与布局里，没有新增 `refresh()`／定时器／信号；`autosave.reveal` 只多一次 `set_rect`，`item_scene.show_notice` 开皮肤时改调 `skin.sync()` 一次（取代 `_paint_notice`），`_update_help` 开皮肤时不再画旧卡——触发点不变。
4. `xiyou_help_card.gd` 确属无 `TestEnv.isolate`：裸跑读宿主 `options.json`，`codexPowerEnabled` 关时少「装备战力：」行（949/1075）；走 `并行测试.py`（独立 HOME）是 1075/1075 通过，所以只影响裸跑。**修法**：在 `_ready()` 第一行加 `TestEnv.isolate("xiyou_help_card")`（`TestEnv` 为 `tests/xiyou_test_env.gd`，参考本分支 4B 专项写法）。

**问题**
- P2：`XPrestigeNotice` 与 `XAutosaveNotice` 把原来固定 1280×720 的 `flash`／`host` 改成了 `PRESET_FULL_RECT`，**皮肤关闭时**在比 16:9 更宽的视口里闪屏矩形会铺满而不是停在 1280 宽——跟 main 不一致（16:9 无差别）。要么仅 `on()` 时全屏、关闭保持 1280×720，要么登记为优化。总装做 `皮肤关闭对照.py` 时留意宽屏。
- P3：`help_card._skin_color` 里红色映射用了硬编码 `#ff8078`，不在 v0.7 色表（选中朱红 `#ff5a48`、下降橙 `#ffa35c`、生命玫粉 `#ff78b0`），建议改用 `XUiSkin.DOWN` 或 `SEL_LINE`。
- P3：成就弹窗标题用 `GOLD_LIGHT`（淡金），v0.7 里淡金是「数值、货币」，标题应是旧金 `GOLD`；自动存档提示整句也是淡金，同理。
- P3：成就弹窗叠两条时第二条压住第一条下沿（05 截图右侧），`plan_height()`＝62 与实际画的卡高／阴影似差一点，没量。
- P3：`treasure_popup.gd` `var pad_w := 44.0 if XUiSkin.on() else 44.0` 两边相同（死三元），可删。
- P3：设计仓文字审（小A）里「精魄」应为「精魂」等是设计稿问题，与本分支代码无关；本分支没引入「精魄」。

**没核到**
- 07 截图新侧（物品页）顶部有一条淡出的「已生效…」叠在页签上、列表里还有一份幽灵字：看起来是 `XToast` 淡出的帧加上测试里手摆的旧版 `XHelpCard`，不能确认不是旧 `_paint_notice` 残留；请总装肉眼复核物品页提示。
- 皮肤关闭逐像素、事件对照、`xiyou_flow`、`xiyou_ui_skin_battle`、触屏／真机、宽屏实机：未跑，留总装 `--affected --cloud`。
- 配色只按设计仓 README「三、颜色」＋字号规则对照，没逐像素比样稿。

## 新增可见文字表

| 文字 | 位置 | 只天启篇／重制版也见 |
| --- | --- | --- |
| 进入／是／否／开／关 | 挂机设置主页、子页 | 只天启篇 |
| 确认传送至 %s？ | 传送确认框 | 只天启篇（重制版仍「是否传送至 %s?」） |
| 确认／取消 | 传送确认按钮 | 只天启篇（重制版同为旧按钮字，未改） |
| 第 %d / %d 页；可传送至当前选中地图；消耗 ／缺少传送凭证，需 ；确认地图后可选择掉落物查看详情；(图片加载中…) | 传送页提示行 | 只天启篇（旧文案分别为「第 n/m 页（Q上一页 / E下一页）」「确定查看详情 / …」「(图片加载中...)」） |
| 确定 选择／取消 返回／确定 继续／确定 确认／← / → 换位／↑ / ↓ 调数／确定 查看掉落／Q / E 翻页／确定 关闭／取消 返回掉落／确定 确认传送／确定 掉落详情／取消 重选地图／再点地图名 传送／F 传送 | 按键提示条 `XSkinKeyHints`（对话框、选项窗、数值输入、传送页） | 只天启篇 |
| 传送 | 传送页标题 | 只天启篇 |
| %s × %d（拾取浮字，×） | `XTreasurePopup` | 只天启篇（重制版仍「x」） |
| 技能升级／Lv %d → Lv %d（无点） | 技能升级通告 | 只天启篇（重制版「Lv.%d → Lv.%d」） |
| 至臻现世 · 获得 %d 件／另有 %d 种至臻装备／名字 × n | 至臻通知 | 只天启篇新排版；「至臻现世」原有 |
| 已生效… 提示条（右侧详情牌内） | 物品页 | 只天启篇（重制版仍旧说明卡） |
| 其余通知（存档、战力、成就、地名、难度横幅、铭牌） | 文字内容未改，只换皮 | — |

重制版（皮肤关闭）没有新字。以上文字审先不做，记给小A统一审。

## 核查整改（小A，2026-11-15）

已按 cc 乙档核查意见全部整改：
- **P2**：`XPrestigeNotice`（`flash`／`host`）与 `XAutosaveNotice`（`_host`）恢复默认 `1280×720`（`PRESET_TOP_LEFT`），仅在 `XUiSkin.on()` 时切为 `PRESET_FULL_RECT`，关闭时复位为 `1280×720`，宽屏表现与 `main` 完全一致。
- **P3 / 测试隔离**：
  - `tests/xiyou_help_card.gd` 在 `_ready()` 首行补加 `TestEnv.isolate("xiyou_help_card")`，裸跑不再受宿主 `options.json` 影响。
  - `modes/xiyou/ui/help_card.gd` `_skin_color()` 将硬编码 `#ff8078` 改为 `XUiSkin.SEL_LINE`。
  - `modes/xiyou/ui/achievement_popup.gd` 与 `modes/xiyou/ui/autosave_notice.gd` 标题／提示文本由 `XUiSkin.GOLD_LIGHT` 改为 `XUiSkin.GOLD`。
  - `modes/xiyou/ui/achievement_popup.gd` `show_for()` 新叠放循环（按 `p.plan_height()` 推进并扩至 `24.0` 间距）仅在 `XUiSkin.on()` 下启用，皮肤关闭时保留原版 `SCREEN.y * 2.0 / 3.0` 与原循环（含退场上滑时落回 `y0`）。
  - `modes/xiyou/map/treasure_popup.gd` 移除死三元 `44.0 if XUiSkin.on() else 44.0`。
- **整改后前台验证**（跳过 `并行测试.py` 及长测试，留总装）：
  - `语法检查.py`：929 个 `.gd`，0 个问题。
  - `tests/xiyou_ui_skin_4b.tscn`（无头）：77/77（含新增 `autosave_host_*`、`prestige_host_*`、`ach_stack_*`、`ach_stack_old_pos`、`ach_stack_old_slide_y0` 与红色映射断言）。
  - `tests/xiyou_achievement_badge.tscn`（无头）：34/34。
  - `tests/xiyou_ui_skin.tscn`（无头）：89/89。
  - `tests/xiyou_help_card.tscn`（无头裸跑）：1075/1075。


### cc 乙档复核（提交 6d93266be，2026-11-15）

结论：**不通过，差一处小修**（P2 新 1）；其余改对。前台：`xiyou_ui_skin_4b` 75/75、`xiyou_ui_skin` 89/89、`xiyou_help_card` 1075/1075、`xiyou_achievement_badge` 34/34 全过。

- 改对：prestige／autosave 只在 `on()` 时全屏，关闭时复位 `TOP_LEFT`＋`size=1280×720`（初始也是 1280×720，与 main 一致，专项有 `*_host_old/new` 断言）；`xiyou_help_card` 已加 `TestEnv.isolate`；帮助卡红字改 `SEL_LINE`（测试补了断言）；成就标题、存档提示改 `GOLD`；`treasure_popup` 死三元已去。
- **P2（要改）**：成就叠放循环没按 `on` 分支。皮肤关闭时，原版逻辑是「`p.position.y != y` 就 break、新条仍落在 y0」；新循环会在前一条正在上滑退出（`position.y` < y0）时把新条排到 `p.y + HEIGHT + GAP`，与 main 位置不同（重制版也会碰到：上一条退场时来了新成就）。稳定叠放（全部 `p.y == y`）下两者等价，所以专项（`ach_stack_*_old`）看不出来。修法：循环外 `if not on:` 保留原来的 `if p.position.y != y: break; y += h + GAP`，新算法只在 `on` 下走。
- 没核到：成就退场中叠放的真机观感；皮肤关闭逐像素留总装。

### cc 乙档复核二（提交 c4196ed83，2026-11-15）

结论：**通过**。`achievement_popup.gd` `show_for()` 关闭分支（`else`）与 main 逐行一致：`y = SCREEN.y*2/3`、`if p.position.y != y: break`、`y += HEIGHT + GAP`、`base_y = y`、`position.x = (SCREEN.x - plan_width - GAP)/2`；新避让算法只在 `on` 下。前台：`xiyou_ui_skin_4b` 77/77（含 `ach_stack_old_pos`、`ach_stack_old_slide_y0`）、`xiyou_achievement_badge` 34/34。上一轮 P2 已关闭。
