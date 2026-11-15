# 交付：cc/ui-art-phase01

- 车道／工作者：B 界面／cc（Orca worker，claude-opus-5-5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·天启篇·未经审查】新界面第一期正式美术接入＋装备 13 栏一页（dev.待定）

小o 交付的第一期正式美术（gpt-tianqi-teaser 工作树 `local_art/UI_Art/phase01_final/`，提交 ff5a9e92c；Kyo 11-15 看过审图页：正式美术通过）接进新皮肤。新类 `XSkinArt`（`modes/xiyou/ui/skin/skin_art.gd`），素材放 `content/ui_skin/phase01/`（`bg/` 15 张背景、`parts/` 8 张组件、`safe_areas.json`；`content/ui_skin/*` 本来就在 DENY 与三个发行预设里，不进发行包）。只在 `XUiSkin.on()` 时生效，四项各自开关，全关＝cc/ui-skin-close 的程序画法。

- 背景（`XSkinArt.BG`）：菜单底（`XUiSkin.menu_backdrop`，主菜单、各新页、选线卡、祭坛、异化工坊都走它）换成当前骑士线的背景：死亡／战争／饥荒／瘟疫（`XTianqiLine.current`），没选线、不在能玩的线、在大厅（Map004）、西游存档用通用版。按视口比例选最接近的那张（比值 <1.56 用 960×720、<2.0 用 1280×720、其余 1600×720），同高铺满居中、最近邻；视口改大小时重选；火星照旧叠在上面。
- 烟色面板（`XSkinArt.PANEL`，D50）：`XUiSkin.panel_style()` 与 MV 窗口框 `draw_panel` 换成 smoke_reading 九宫格（边距 16，内容边距照旧 16），高 <80 的用 smoke_secondary；`shadow_style()` 改空（烟底自己渐隐）。
- 选中条（`XSkinArt.SELECT`，D51）：`XUiSkin.draw_select`（列表滑动条、按钮、MV 光标框）换成 selection_wash 渐隐暗红底铺满行＋左外小箭头（行高 ≥40 用 2×、否则 1×，箭头右边离红底 8px 透明间隔，不进红底）；悬停只画淡底不画箭头，按下压暗下沉 1px。组页签（`XSkinTabStrip`）选中按 tab_selected_assembly 的几何画（箭头 1× 在页签左外 8px＋tab_selected_wash）。
- 环高亮（`XSkinArt.HALO`）：主菜单环上当前组的 u4 图标加 ring_selected_halo 外圈（64 图标配 96 圈、32 配 48，中心对齐、最近邻）；只给带 u4 贴图的项（主菜单组），装备栏位、物品分类、战斗指令环不加。
- 装备 13 栏一页（`XSkinEquipPage.ONE_PAGE`，Kyo「除了这个装备，我要所有栏位都在一页」）：13 栏排一圈（环半径 140、球半径 22，点按半径 26，相邻球心隔 68），不翻页，环下只写「身上 n 件」（去掉「栏位第 a / b 页」）；栏位名改写在环内侧（半径 98），选中的白字大一号；环心头像缩到半径 72。上、左＝逆时针一格，下、右＝顺时针一格（就是栏位显示顺序，走完 13 栏回第一栏），Q／E 换人；不能换的栏照旧变暗。
- 4:3：视口照 O-483（`XSkinLayout.NARROW_LETTERBOX`）锁 1280×720 上下留黑边，所以 4:3 屏实际用 16:9 那张背景、装备页和 16:9 同一个摆法（13 栏放得下，不用两列网格）；960×720 背景只在视口真是 4:3 时用上（NARROW_LETTERBOX 关掉时）。
- 测试：新专项 `xiyou_ui_art_phase01`（无头 74 项、带窗口截图 88 项）；`xiyou_ui_skin_1c` 栏位分页那几项改在 `ONE_PAGE = false` 下验（回退路径）。
- 发行空壳：`skin_art.gd` 登记进 `发行空壳.py` 的 MIXED_OK（只在 on() 的画法里调；缺图时 part()／bg_texture() 给 null、走程序画）。
- 玩家可见：天启篇新界面换上正式美术——菜单背景跟着你走的骑士线换图，面板变成无框烟色，选中行变成渐隐暗红底加左侧小箭头，主菜单当前组图标有一圈像素高亮；装备页 13 个栏位一页全显示，不用再翻页。

## 优化登记草稿

| 编号 | 位置 | 原版问题 | 优化 | 依据 | 回退 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.BG`；`ui/skin/ui_skin.gd` `menu_backdrop` | 新界面菜单底是程序画的冷黑径向渐变，不分线 | 按骑士线换正式背景（死亡／战争／饥荒／瘟疫，其余通用），按视口比例选 16:9／20:9／4:3 那张 | Kyo 11-15 审图通过；小o phase01_final | `XSkinArt.BG = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.PANEL`；`ui/skin/ui_skin.gd` `panel_style`／`shadow_style`／`draw_panel` | 面板是程序画的圆角黑块＋细线＋投影 | R2 无框烟色九宫格（smoke_reading，矮的 smoke_secondary），去投影 | D50 | `XSkinArt.PANEL = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.SELECT`；`ui/skin/ui_skin.gd` `draw_select`、`ui/skin/skin_tab_strip.gd` | 选中条是整行实心暗红底＋朱红框＋左光标 | 渐隐暗红底＋左外小箭头（8px 间隔），页签同一套 | D51 | `XSkinArt.SELECT = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.HALO`；`ui/skin/skin_ring_nav.gd` | 主菜单当前组只靠暗红圆底区分 | 当前组图标加 ring_selected_halo 像素外圈 | 小o phase01_final README | `XSkinArt.HALO = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_equip_page.gd` `XSkinEquipPage.ONE_PAGE`；`ui/skin/skin_ring_nav.gd`（`label_inner`） | 装备栏位环 13 栏分 7＋6 两页、要翻页 | 13 栏一圈同屏，栏位名写环内侧，不翻页 | Kyo 11-15 原话 | `XSkinEquipPage.ONE_PAGE = false` | cc | 保留 |

## 新增可见文字（给小A文字审）

- 没有新增文字。去掉了装备页环下的「· 栏位第 a / b 页」，只剩「身上 n 件」（原有文字）。栏位名照旧取数据库装备类型名（天启篇 17 叫「神器」）。

## 交接板

- 下一步：小A 乙档核查＋文字审（文字只有一处删减）。合并后可派：主菜单右下「助力位」卡片还有旧的旧金描边框（`skin_party_status`／主菜单自己画的），R2 无框风格下要不要也换烟底，待美术或 Kyo 看。
- 用户试玩说明：天启篇存档开新界面：菜单底随线换背景（大厅里是通用版）；面板是无框烟色；选中行左侧有小红箭头；装备页 13 栏一页。
- 需要用户决定：无（4:3 用的是 16:9 背景加上下黑边，这是 O-483 定的窄屏留边；要让 4:3 平板用 960×720 那张图得把新页面改成 4:3 重排，另起一单）。

## 进度账

- 天启篇新界面：第一期正式美术接入完成（背景、面板、选中条、环高亮）；装备页 13 栏一页。

## 验证

- `xiyou_ui_art_phase01`：无头 74/74；带窗口 88/88（含截图）。
- `xiyou_ui_skin_1c`：本地 78/78（栏位分页项改在 ONE_PAGE=false 下验）。`xiyou_input_handled` 本地 10/10。
- 云端选测（选测.py main 列的 20 个场景：event_compare a～d、tianqi_gear、ui_art_phase01、ui_skin、ui_skin_1b／1c／3a／3b／4a／4b／5c／battle／close／hud／menu／offshot／p1fix）：提交 929de654be 只有 `xiyou_ui_skin_1c` 挂（就是上面那 5 项旧分页断言），已改测试本地重跑通过；其余 19 个通过。
- 皮肤关闭对照（`皮肤关闭对照.py`，对 main 逐像素）：32/32 SAME。
- 语法检查通过；`发行空壳.py check` 通过（62 个脚本、534 个函数）；空壳工程冷启动 0 个 SCRIPT ERROR，强制加载 skin_art／ui_skin／skin_equip_page／skin_ring_nav／skin_tab_strip 都能编译。
- 工具快速回归全部通过。
- 截图（本地结果目录不入 Git，在本工作树 `/Users/kyo/orca/workspaces/再刷项目资料库/ui-art-phase01/`）：`03_再刷重制_Godot/04_验证/本地结果/ui_art_phase01/`——`menu_／items_／equip_` × `16x9／20x9／4x3`（4:3 另有 `_letterbox` 版＝960×720 窗口玩家看到的样子）、`equip_16x9_touch.png`、`bg_death／war／famine／plague_16x9.png`。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ef3a723a4 WIP: 第一期正式美术接入＋装备 13 栏一页（XSkinArt、专项 xiyou_ui_art_phase01）
- 929de654b WIP: 专项截图 4:3 加黑边版；第一期美术截图
- （本提交）1c 改验回退路径、发行空壳登记、交付单
