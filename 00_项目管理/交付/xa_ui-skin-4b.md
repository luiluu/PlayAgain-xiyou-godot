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
