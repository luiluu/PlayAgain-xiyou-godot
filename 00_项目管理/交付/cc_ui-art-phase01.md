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
- v2（Kyo 11-15 看审图：字看不清、13 栏一圈太密）：
  - 可读性（`XSkinArt.READ`）：正式背景上整体压暗 28%、顶栏从上往下渐隐黑（132px，85%）、底栏从下往上渐隐黑（112px，88%）、左块环区一团椭圆暗角（62%）；直接写在背景上的字（页名、组页签、货币名、按键提示、环上项名、装备环下说明）次要灰提到暖骨灰 #d2ccc2、加 3px 深色描边，按键提示键帽垫 55% 黑底。面板里的字不动。
  - 装备 13 栏分支摆法（`XSkinEquipPage.LAYOUT`，只在天启篇 13 栏时用）：主环 8 个核心栏（武器 副手 头部 盔甲 护手 腰带 裤子 鞋子，半径 112、球 24），项链 戒指 法宝 坐骑 神器 从环上分叉成旧金细线连的枝丫；A 下垂三枝（饰品、坐骑、宝物三枝往下垂）、B 星座斜出（饰品、宝物往两个上角斜出，坐骑往右下）、C 挂主栏（每栏挂在相关的主栏上：神器←武器、法宝←副手、项链←头部、戒指←护手、坐骑←鞋子）；0＝上一版一圈 13 颗。键盘按深度优先走（绕主环，走到有枝丫的那栏先走完枝丫）。默认 C，等 Kyo 挑。
- 小A 核查返修（核查报告_ui-art-phase01_20261115.md）：
  - P2-1 外置箭头：主菜单行、模板页列表左边从 10／8 收到 28（2× 箭头收在烟底里）；双列列表列缝至少 26（右列箭头在缝里）；组页签缝 4→18；详情展开、队伍状态的横排页签改用页签画法（1× 箭头）、页签间 20、第一个右移 16。
  - P2-2 像素件硬边：箭头、选中横幅、页签横幅、助力签、七芒印都按最近邻预先放大到要画的尺寸（自写整数最近邻，Image.resize 的最近邻不是干净的 k×k 块），1:1、整数像素画；控件本身照旧线性过滤（字要平滑）。烟底九宫格只沿长边拉伸、渐隐方向不缩放，没有改。
  - P2-3 观感：烟底整体乘 0.85（secondary 0.88）透一点背景；大面板内缩 16 叠 smoke_grain_tile 颗粒（40%，四边 24px 渐隐不出硬边）；左右内容边距 16→24；正式背景上火星亮度减半；主菜单助力位卡去旧金描边，改 smoke_secondary 72%＋七芒暗印 64（原图 alpha 最高 28，照美术说明不再减透明，没按报告的 0.16）＋helper_tag 2×（64×24，暖白「助力」）。
  - P2-4：分支摆法与一圈 13 颗只在天启篇 13 栏（`XTianqiGear.on()`、栏数 ≤13）时用；19 栏照旧分页。
  - P3-1 注释改 72；P3-3 装备环下「身上 n 件」走背景字描边；P3-2 不改（照 O-483）。
- 玩家可见：天启篇新界面换上正式美术——菜单背景跟着你走的骑士线换图，面板变成无框烟色，选中行变成渐隐暗红底加左侧小箭头，主菜单当前组图标有一圈像素高亮；装备页 13 个栏位一页全显示，不用再翻页。

## 优化登记草稿

| 编号 | 位置 | 原版问题 | 优化 | 依据 | 回退 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.BG`；`ui/skin/ui_skin.gd` `menu_backdrop` | 新界面菜单底是程序画的冷黑径向渐变，不分线 | 按骑士线换正式背景（死亡／战争／饥荒／瘟疫，其余通用），按视口比例选 16:9／20:9／4:3 那张 | Kyo 11-15 审图通过；小o phase01_final | `XSkinArt.BG = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.PANEL`；`ui/skin/ui_skin.gd` `panel_style`／`shadow_style`／`draw_panel` | 面板是程序画的圆角黑块＋细线＋投影 | R2 无框烟色九宫格（smoke_reading，矮的 smoke_secondary），去投影 | D50 | `XSkinArt.PANEL = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.SELECT`；`ui/skin/ui_skin.gd` `draw_select`、`ui/skin/skin_tab_strip.gd` | 选中条是整行实心暗红底＋朱红框＋左光标 | 渐隐暗红底＋左外小箭头（8px 间隔），页签同一套 | D51 | `XSkinArt.SELECT = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.HALO`；`ui/skin/skin_ring_nav.gd` | 主菜单当前组只靠暗红圆底区分 | 当前组图标加 ring_selected_halo 像素外圈 | 小o phase01_final README | `XSkinArt.HALO = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_art.gd` `XSkinArt.READ`；`ui/skin/skin_tab_strip.gd`、`skin_key_hints.gd`、`skin_template_page.gd`、`skin_main_menu.gd`、`skin_ring_nav.gd`、`skin_equip_page.gd` | 正式背景上细灰字压在齿轮、塔楼、红裂纹上看不清 | 背景压暗＋顶底栏渐隐黑＋环区暗角，背景上的次要字提亮、加深色描边 | Kyo 11-15 看审图 | `XSkinArt.READ = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_equip_page.gd` `XSkinEquipPage.LAYOUT`；`ui/skin/skin_ring_nav.gd`（`custom`／`links`） | 一圈 13 颗太密 | 主环 8 核心栏＋5 栏分叉成枝丫（A／B／C 三种，默认 C 待 Kyo 挑） | Kyo 11-15「可以扩展一些不规则的分支子类」 | `XSkinEquipPage.LAYOUT = 0`（回一圈 13 颗） | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_equip_page.gd` `XSkinEquipPage.ONE_PAGE`；`ui/skin/skin_ring_nav.gd`（`label_inner`） | 装备栏位环 13 栏分 7＋6 两页、要翻页 | 13 栏一圈同屏，栏位名写环内侧，不翻页 | Kyo 11-15 原话 | `XSkinEquipPage.ONE_PAGE = false` | cc | 保留 |

## 新增可见文字（给小A文字审）

- 没有新增文字（v2：助力签上的「助力」是原有文字，只是换了底）。去掉了装备页环下的「· 栏位第 a / b 页」，只剩「身上 n 件」（原有文字）。栏位名照旧取数据库装备类型名（天启篇 17 叫「神器」）。

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

- v2／返修（a9fc063db）：`xiyou_ui_art_phase01` 无头 183/183、带窗口 205/205；本地 `xiyou_ui_skin`／`_1b`／`_1c`／`_close`／`_menu`／`_p1fix`、`input_handled` 全过；82624d45a 云端选测 21 场景全过；a9fc063db 云端与皮肤关闭对照见回报。
- v4（Kyo 11-16 选 C）：A／B 留作 `LAYOUT` 开关、默认 C。C 改三处：①连线改折线——根栏沿径向出到半径 148 拐一个旧金小菱形节点再斜接副栏；②副栏收近到离环心 172～176，各落在两颗主栏之间的空当；③项链从贴着头部挪到头部斜上方（156, −73），坐骑对称放鞋子斜上方，副栏名字都朝外写。专项新增三项：C 摆法名字互不相压／不压别的球／不出环区、连线是三点折线、副栏不超 180。
- 换环样式的口子（给「高品质装备改变主环样式」留的，这次没做功能）：`XSkinRingNav.style` 字典＋`DEFAULT_STYLE`，环描边色／线宽、光带、外圈虚线、刻痕菱形、枝丫连线与拐点菱形、球底与球描边都走 `sty(键)` 取值；换一张表就换样式，没给的键回默认。
- v4 截图：`…/v4/`（`equip_16x9`、`equip_16x9_touch`、`equip_20x9`、`equip_4x3`＋`_letterbox`；另有四种摆法对照）。
- v5（Kyo 11-16 看 v4）：连线改直角折线——从主栏沿径向伸出约 60 再拐，拐点（小菱形，只画在拐点上）离副栏比离主栏近；装备页环上不再画七颗七印刻痕（8 栏对不上 7，点没含义，`style.notches = false`）；坐骑名字改写在球下。专项加「拐点离副栏更近、直角」「无刻痕」两项。截图 `…/v5/`。
- v6（Kyo 11-16 看 v5：不要直角）：A 斜折（默认）——主栏沿径向伸出约 48 拐（菱形），约 125° 钝角斜接副栏，拐点在全程五成多；B 弧线——`XSkinEquipPage.LINK_CURVE = true`（环样式表 `link_curve`），径向出发的二次贝塞尔、不画拐点。副栏离环心 167～187（项链靠右边只能伸 32）。截图 `…/v6/`：`equip_16x9`／`equip_4x3`＝A，`equip_curve_16x9`／`equip_curve_4x3`＝B。
- v2 截图：`04_验证/本地结果/ui_art_phase01/v2/`；返修后 v3：`…/v3/`（同一套，另有 `equip_layout{0,1,2,3}_{16x9,touch}.png` 四种装备摆法）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ef3a723a4 WIP: 第一期正式美术接入＋装备 13 栏一页（XSkinArt、专项 xiyou_ui_art_phase01）
- 929de654b WIP: 专项截图 4:3 加黑边版；第一期美术截图
- 4fd30c259 1c 改验回退路径、发行空壳登记、交付单
- 82624d45a v2：可读性＋装备分支摆法 A／B／C
- a9fc063db 小A核查返修 P2×4、P3×2
