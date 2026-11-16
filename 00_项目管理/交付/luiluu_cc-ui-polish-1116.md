# 交付：luiluu/cc-ui-polish-1116

- 车道／工作者：T095 新界面七处小毛病（cc，Opus＋medium；原车道 5h 额度满被停，换号续接）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·T095·未经审查】新界面七处小毛病＋追加五处（状态页列宽、工坊字体、法阵小人待机帧与居中、名牌去框、提示黄底、存档位光标；调查胶囊和键位提示能点、选项行高跟字号、选中放大不顶行、装备自带属性分色）（dev.待定）

- 依据：Kyo 11-16 晚截图（私密仓 `协作交接/附图/界面反馈_1116/` 01～11），派单 `协作交接/派单/T095_界面七处小修.md`。
- 01 状态页「武器 加成」列：新界面带「 未持有／ 生效」后缀时列宽按 `999% 未持有` 算，不再贴住右列「爆伤加成」（`ui/status_page.gd`；旧界面照原版压窄，不改）。
- 02 工坊页签：选中项只放大、不换成标题衬线体（`ui/skin/skin_main_menu.gd`），切换不再跳字体。
- 03 主菜单法阵小人：原先自己按 9×6 切第 0 行＝MV 的 walk；改按 `XAppearance.look_key／for_look` 取 wait 动作（新增只读的 `look_key`，不像 `battler_key` 会改宿傩状态），跟战斗同一套外观（米拉 u2 逐帧图、Mx_SuperSV、appearances.json 覆盖都认）。
- 04 法阵中心小人居中：按各待机帧不透明像素的并集居中、按实占大小定整数倍（小铃兰的格里人只占下半格，按整格居中就偏下）。
- 05 大厅名牌：新界面不再垫黑底框，称号＋名字改黑描边字（`map/designation_plate.gd`）。
- 06 提示框黄底：左边 3px 金竖条原先挂在 PanelContainer 下被撑满成整块金底，改挂外层 slot（`ui/toast.gd`）。
- 08 新建游戏存档位：摘要长时两列比屏幕宽、左列光标画到屏幕外；放不下就改一列（`entry.gd` `_fit_slot_grid`）。
- 追加（Kyo 11-16 同批反馈）：天启篇地图调查胶囊整枚能点（鼠标／触屏＝按确定，`map/tianqi_table.gd`）；桌面样式键位提示「键帽＋说明」整段能用鼠标点（开关 `XSkinKeyHints.CLICK_DESKTOP`，false 回到只看不点）；对话选项行高跟字体大小设置放大（130% 时不再挤在一起，`ui/message_box.gd`）；旧 MV 页选中放大时字高不超过行高 86%（`ui/mv_canvas.gd`）；装备说明「自带」属性按属性名分色（生命绿、魔法蓝……，开关 `XSkinTemplatePage.STAT_COLORS_ON`，`ui/skin/skin_template_page.gd`、`skin_card.gd`）。
- 测试：`xiyou_ui_skin_close` 加 `t095_sv_wait_row`（环心小人取第 1 行 wait）、`t095_sv_used_rect`（不透明范围在格内）、`hints_keyboard_plain` 改为桌面样式可点并核整段点击范围、`hints_keyboard_click_off`。新增工具场景 `tests/t095_ui_shots`（真窗口出修前修后截图，无头或不带 `--out` 时报跳过算通过）。
- 玩家可见：状态页武器加成两列不再挤；工坊页签切换不跳字体；主菜单法阵小人改成待机动作并居中；大厅玩家名没有黑框了；「存档成功」提示没有黄底；新建游戏选存档位左列也有光标；调查提示、底部键位提示能用鼠标点；字体调大后对话选项不再挤；装备属性分颜色。
- 验证：见下「验证」节。

## 验证

- 修前修后截图：西游档（xy）、天启篇（tq）两档都出了（工具 `t095_ui_shots`）；修后图逐张看过。受影响：01～05、08 只改新界面（天启篇档；西游档旧界面截图前后一致：旧主菜单无法阵、状态页照原版压窄、名牌旧样式）；06 提示框两档都用同一个提示控件，两档都去掉了黄底。截图里重复两条「天启篇的伙伴只从方桌大厅的通关招募来」是截图工具加角色时触发的提示，不是本单问题。
- `检查.sh --affected` 起跑后文档与登记、随机守卫、语法检查都过；它按 `选测.py main` 选了 285 个场景（entry.gd、appearance.gd 映射宽，没有战斗核心类），30 分钟只到 42/285，按车道须知停掉改跑选测，整轮留给总装合并后。
- 选测（本机，56 个场景）全过：`t095_ui_shots`（无头报跳过）、`xiyou_ui_skin*`（含 `xiyou_ui_skin_close` 新断言）、`xiyou_status_page`、`xiyou_designation_plate`、`xiyou_message`、`xiyou_ui_sel_scale`、`xiyou_save_page`、`xiyou_gear_ui`、`xiyou_font_size`、`xiyou_popup_overlap`、`xiyou_tianqi_sect_geng`、`xiyou_newgame_back`、`xiyou_input_handled`、`xiyou_appearance`、`xiyou_actor_looks`、`xiyou_map_hotkeys`、`xiyou_key_map`、`xiyou_transfer_touch`、`xiyou_sukuna_art`、`xiyou_costume_battle`、`xiyou_costumes`、`xiyou_mira_art`、`xiyou_mira_dragon_art`、`xiyou_actor_sv_compare`、`xiyou_battle_ui`、`xiyou_flow`、`xiyou_gojo`、`xiyou_tianqi_look`、`xiyou_entry_release`、`xiyou_tianqi_title_flow`、`xiyou_tianqi_opening`、`xiyou_save_events`、`xiyou_autosave`、`xiyou_ui_page_details`、`xiyou_ui_pixel`、`xiyou_orb_ui`、`xiyou_alien_workshop`。中途 `xiyou_input_handled` 咬住调查胶囊直接调 `get_viewport().set_input_as_handled()`，改成 `XKeyMap.handled(self)`。
- `语法检查.py` 通过。

## 交接板

- 下一步：无
- 用户试玩说明：同「玩家可见」
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- c0c0c23b3 WIP: T095 七处
- 9e1349236 WIP: T095 追加五处
