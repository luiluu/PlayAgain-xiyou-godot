# 交付：cc/ui-skin-p1fix

- 车道／工作者：B 界面·新皮肤 P1 三条必改＋组图标 u4 接入＋主菜单两级与助力位卡／cc（Opus＋medium，派单定：改皮肤层共用组件，影响全部新界面页）
- 分支：`cc/ui-skin-p1fix`（从 main fa0562032 切出，已合 main，无冲突）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·天启篇·未经审查】新界面 P1 三条必改：选中条加厚三态、4:3 上下留边、战技列表躲行动条（dev.待定）

- 玩家可见：天启篇新界面里选中行一眼能看出来（整行实心暗红底、不透明朱红框、加粗左光标＋淡金小三角），按下有压暗下沉；平板 4:3 不再挤成三栏叠在一起；战斗战技满 8 行时说明行不再被行动顺序头像盖住。只在天启篇新皮肤生效，重制版旧界面不变。
- 依据：小A审 v0.7（私密设计仓 `重制设定/界面风格提案_v0.7/小A审.md`）P1-1～3，Kyo 11-15 晚「修」。
- P1-1 选中态（`ui_skin.gd` `draw_select`／`SELECT_V2`；`skin_select_style.gd`、`skin_select_bar.gd`、`skin_button.gd`、`skin_battle.gd`、`skin_list.gd`、`skin_main_menu.gd`、`skin_party_strip.gd`、`skin_target_list.gd`）：
  - 加厚版常量组 `SEL2_*`：左光标 4→6px、上下只缩 2；外框 1px 45% → 2px 不透明；底光从「68% 处掉到 8%、右端透明」改成整行实心暗红（左 `#761c14` → 右 `#4e1410`，94%）；光标中点加淡金小三角作形状锚点。
  - 三态分开（`XUiSkin.SelState`）：悬停＝同样式 45%、不画光标；焦点＝全画；按下＝底色压暗 42%＋整体下沉 1px（按钮字也下沉 1px）。Godot 的 Button 把 focus 叠在 pressed 上画，`XSkinButton.wire_press` 按住时把 focus 换成按下态。列表（XSkinList、主菜单、队伍条、目标列表）点下去 `XSkinSelectBar.press()` 闪 0.12 秒按下态。
  - 红套红：`XUiSkin.sel_text` 把选中行上的红字（神话红、朱红一类）换亮珊瑚 `#ffa094`（XSkinList 已接）。
  - 旧 v0.7 四个常量（`BAR_W` 等）原样保留，`SELECT_V2 = false` 整套回旧画法。
- P1-2 平板 4:3（`skin_layout.gd`）：`request_wide` 改按窗口比例选拉伸方式——比 16:9 宽才 `KEEP_HEIGHT` 横向铺满，16:9 及更窄用 `KEEP`（视口 1280×720、上下黑边、不重排）；窗口改大小时跟着换（`aspect_for`／`view_for` 纯函数）。开关 `XSkinLayout.NARROW_LETTERBOX`。顺手：离树途中重排读视口不再报 `!is_inside_tree`。
- P1-3 战斗遮挡（`skin_battle_list.gd`、`skin_otb_bar.gd`）：`XSkinOTBBar.occupied_rect()` 给出行动条占的矩形（POS 上方再留 11，覆盖审稿量的 x≈452～565、y≈627～712）；`XSkinBattleSkillList.place_for_actor` 与它重叠时把底边收到条顶上方 4px。只改纵向位置，列表右边离角色 37 不变，2A／2B 布局不动。开关 `AVOID_OTB`。
- 测试：`xiyou_ui_skin` 加 select_v2 参数、红字换色、按钮三态／按住换样式／v0.7 回退、主题三态、按下闪、4:3／16:9／20:9 拉伸方式与视口、窗口变 4:3 跟着换；`xiyou_ui_skin_battle` 加 8 行列表在 6 个站位都不碰行动条＋关开关会碰（咬得住）；`xiyou_ui_skin_menu` 宽屏断言改成按窗口比例；新增截图场景 `xiyou_ui_skin_p1fix`（无头只跑断言）；战斗测试加 `--tablet`（1024×768）。

## 2026-11-15 【cc·天启篇·未经审查】主菜单组入口图标 u4 定稿接入（dev.待定）

- 玩家可见：天启篇新主菜单环上六个大类换成 co 画的 u4 图标（药瓶、短剑、肖像牌、锤砧、雪花书、钢盾），清晰不糊；选中换带朱红圆底的选中版。
- 素材：`content/ui_skin/group_icons/` 28 张（`{items|equipment|character|party|workshop|codex|system}_{normal|selected}_{64|32}.png`，导入无损、无 mipmap），源在 `gpt-tianqi-teaser` 工作树 `local_art/UI_Icons/u4/`；审图件、源图、脚本没进工程。`content/ui_skin/*` 早已在发行 DENY 与三个预设排除里。
- 接入：`XUiSkin.GROUPS` 各组加 `art` 键（宠物组暂无，u4 的 party 号角留着备用）；`XUiSkin.group_icon(art, selected, px)`；`XSkinRingNav.group_item` 带上 `art_normal／art_selected`；环上 u4 贴图画在一个最近邻子画布项里，64 原生大小、位置取整、选中只换贴图不缩放（原来 40px×1.16 非整数拉伸）。圆盘半径 33／选中 38.28 不变。
- 不叠两层红：选中贴图自带朱红圆底，这时选中球外晕改淡旧金 30%、描边改旧金（没 u4 的环——装备栏位、物品分类、战斗指令——照旧红）。
- 32 版目前没有地方用（页签条不画图标），文件先进工程。
- 开关 `XUiSkin.GROUP_ICONS_U4`（默认开）：关了回旧图标号和旧画法。
- 测试：`xiyou_ui_skin_menu` 加 28 张都在且尺寸对、六组都有贴图、绘制 64×64 且位置为整数、选中换贴图、关开关回旧图标号、宠物组无 art。

## 2026-11-15 【cc·天启篇·未经审查】主菜单两级操作＋右栏助力位卡（dev.待定）

- 玩家可见：天启篇新主菜单改成先选大类、再进子项：环上换大类时中间栏只列该大类的子项（预览，不亮选中条），确定才进子项列表；取消从子项回到环上，再取消回地图。右栏队伍下面加第 5 张「助力」卡（出战栏第 5 格；空着写「助力位 · 空」），队伍框拉到和中间栏底边对齐。
- 依据：Kyo 11-15 晚看主菜单截图「先选大类……大类确认后进入子类菜单」「右边队伍下面空出来一块有点奇怪」「不是还有助力位置吗」。
- 两级（`skin_main_menu.gd` `TWO_LEVEL`、`level`）：
  - 第一级：方向键（上下左右都是换大类）／Q E／点环换大类；只一项的大类（物品、装备）中间栏写组名＋一句说明「……。确定直接打开」，确定直接开页；多项大类确定进第二级。
  - 第二级：上下在本大类子项间循环（按住不跨头尾）、Q E 换大类（留在第二级）、确定打开、取消回第一级。从页面返回仍在第二级原处。
  - 触屏：点环上别的大类＝选中并进第二级（只一项的直接打开）；点中间栏子项（或说明行）＝直接打开。
  - 记忆：`XSkinMainMenu._mem` 记上次的大类和每个大类各自的子项（按键名，不按下标；记的项被藏了回第一项），重开菜单停在那个大类的第一级，再进第二级落在记住的子项。
  - 按键提示随层级：第一级「确定 进入／取消 回地图／Q E 换组」，第二级「确定 打开／取消 返回／Q E 换组」，选人照旧。
  - 子项、可见组照旧全走 `XUiSkin.GROUPS`＋`visible_groups`。
- 助力位卡（`skin_main_menu.gd` `HELPER_CARD`；`skin_party_strip.gd`）：天启篇（`XTianqi.active`）时队伍条显示顺序＝其余队员在前、助力位的人（`XState.helper()`）挪到最后并带「助力」角标（略暗底＋旧金细边）；没人时末尾一张「助力位 · 空」占位。卡高把队伍框填到中间栏底边（均分，60～120）；人少时卡在上、框照样拉齐。选人（技能／装备／状态）时按显示顺序走、跳过空位，助力位的人可选。非天启篇、或开关关：照旧随人数排、行高 60、框高随内容。
- 测试：`xiyou_tianqi_e2e` 的 `_menu_cmd` 改两级走法（开关关着时走旧的下键遍历）；`xiyou_ui_skin_menu` 旧一级断言在开关关着时照跑；新加两级流转（环→子项→上下循环→取消回环→记忆→打开页面→返回仍在第二级→单项直开→点环进第二级→点子项打开→重开记忆→第一级取消关菜单）与助力卡（天启篇开、空占位、底边对齐、选人跳空位、关开关回旧、有人时卡挪到最后带标）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.SELECT_V2` | v0.7 打磨版选中条：4px 光标、1px 45% 外框、底光 68% 处掉到 8% 右端透明，悬停／焦点／按下同一个 | 加厚版：整行实心暗红底、2px 不透明框、6px 光标＋淡金三角；三态分开、按下压暗下沉；选中行红字换亮珊瑚 | 小A审 v0.7 P1-1，Kyo 11-15「修」 | `XUiSkin.SELECT_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_layout.gd` `XSkinLayout.NARROW_LETTERBOX` | 新页面一律 KEEP_HEIGHT，4:3 视口被压成 960 宽 | 比 16:9 窄用 KEEP（1280×720 上下黑边），宽才 KEEP_HEIGHT，窗口改大小跟着换 | 小A审 v0.7 P1-2（方案第二节第 4 条） | `XSkinLayout.NARROW_LETTERBOX = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_battle_list.gd` `XSkinBattleSkillList.AVOID_OTB` | 战技列表只收在画面里，8 行时压住左下行动条 | 与行动条重叠时底边收到条顶上方 | 小A审 v0.7 P1-3 | `XSkinBattleSkillList.AVOID_OTB = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.GROUP_ICONS_U4`；`skin_ring_nav.gd` | 主菜单组入口用旧 RPGMV 图标号，40px×1.16 非整数拉伸 | u4 定稿贴图，64 原生、最近邻、整数位置、选中只换贴图；选中球外晕／描边改旧金 | Kyo 11-15「图标定稿」 | `XUiSkin.GROUP_ICONS_U4 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_main_menu.gd` `XSkinMainMenu.TWO_LEVEL` | 一级分组列表：六组全列、选中组展开，上下跨组 | 两级：环上选大类、中间栏只列该大类子项（预览），确定进子项；记住位置 | Kyo 11-15 主菜单截图意见 | `XSkinMainMenu.TWO_LEVEL = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_main_menu.gd` `XSkinMainMenu.HELPER_CARD`；`skin_party_strip.gd` | 队伍条随人数排、框高随内容，下面空一大块 | 天启篇加第 5 张助力位卡（空时占位），框对齐中间栏底边、卡高均分 | Kyo 11-15「不是还有助力位置吗」 | `XSkinMainMenu.HELPER_CARD = false` | cc | 保留 |

## 截图（本机，不入库）

目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_p1fix/`（`xiyou_ui_skin_p1fix` 与 `xiyou_ui_skin_battle` 窗口模式 `-- --out=` 生成）：

- P1-1 选中前后：`p1_select_board_{16x9,20x9}_compare.png`（列表含神话红行、弹窗选项、按钮常态／悬停／焦点／按下；左 v0.7、右加厚版），另有 `_v07`／`_v2` 单张；`p1_select_menu_*`、`p1_select_equip_*` 同理。
- P1-2 平板：`p1_tablet_4x3_{menu,equip,altar}.png`、`battle_2a_*_4x3.png`、`battle_p1fix_list_8rows_4x3.png`（视口 1280×720，截图只截视口所以看不到黑边）。
- P1-3 战斗：`battle_p1fix_list_8rows_{16x9,20x9,4x3}.png`（8 行满屏、下排站位）。
- u4：`u4_menu_{16x9,20x9}.png`（常态）、`u4_each_selected_{16x9,20x9}.png`（六组各选中一张拼图）。
- 两级＋助力：`menu2_l0_actor_helper_empty_*`（第一级停角色、助力位空）、`menu2_l0_workshop_*`（第一级停工坊）、`menu2_l1_actor_zhenqi_*`（第二级选中真气）、`menu2_helper_filled_*`（5 人、助力位有人）；16:9 与 20:9 各一套。

## 验证

- 语法检查：937 个 .gd 0 问题。
- 本地单跑专项（前台、一次一两个）：`xiyou_ui_skin` 104/104、`xiyou_ui_skin_menu` 91/91、`xiyou_ui_skin_battle` 66/66（16:9、`--wide`、`--tablet` 窗口模式各一遍也全过）、`xiyou_ui_skin_p1fix` 窗口 40/40、`xiyou_ui_skin_1b`、`xiyou_ui_skin_offshot`、`xiyou_battle_ui` 182/182、`xiyou_tianqi_title` 46/46。
- 云端选测：提交 406e3174a（三条必改＋u4）整轮 628 场景 16 片全过，偶发 1 个 `xiyou_pet_capture`（单跑通过，与本单无关）；运行页 actions/runs/43742669754。350efeaab（两级＋助力卡）另跑一轮选测 9 场景：`xiyou_tianqi_e2e` 挂（它的 `_menu_cmd` 按旧一级菜单一路按下键找子项），已改成两级走法（环上右键到大类、确定、下键到子项、确定），本地重跑 90/90；改后再跑云端，结果见 worker_done。
- 工具回归全过；`发行空壳.py check`：62 个脚本 534 个函数都有（警告是既有的照搬 return true 名单，与本单无关）。
- 只在新皮肤生效：`wide_skin_off_noop`、`xiyou_old_menu`、`skin_off` 等既有断言照过；`SELECT_V2`／`GROUP_ICONS_U4`／`TWO_LEVEL`／`HELPER_CARD` 都只在 `XUiSkin.on()` 的新组件里读。

## 交接板

- 下一步：核查（乙档界面 → cc Sonnet 代核：小A自己审出的问题，换人核）；审图页给 Kyo 看截图（选中前后、u4、两级、助力卡）。
- 用户试玩说明：天启篇新界面选中更明显、按下有反馈；平板不挤；战斗战技不被头像挡；主菜单新图标、先选大类再进子项、右栏有助力位卡。
- 需要用户决定：无（u4 的 party 号角暂不用，宠物组放开时再定图标）。

## 进度账

- 无（天启篇新界面打磨，不涉及移植进度）。

## 可优化（流程／工具／效率）

- 建议（小A审其余 P2／P3，拆批给界面车道，本单没做）：
  - P2-1 同屏多处红光：已部分做——主菜单两级后同屏一个焦点、u4 选中球改旧金。剩下：装备／物品页焦点进列表时左环选中球改旧金细圈；七印祭坛等底部按钮组只有焦点停留的那颗实心红，其余暗底旧金边（`skin_template_page.gd`、`tianqi_skin_altar.gd`、`skin_card.gd`）。约半天，B 车道。
  - P2-2 触屏：顶栏页签去 `MOUSE_FILTER_IGNORE` 可点；`XSkinList` 拖拽惯性滚动；X/Y/C 快捷功能做成可点胶囊；物品页「丢弃」离「使用」远一点或二次确认。约一天，B 车道。
  - P2-3 法阵像素小人、背景裂纹层、地图 HUD 旧按钮混搭、物品页旧说明卡越界、挂机页叠字。美术＋界面各一单。
  - P2-4 色弱与近亲色（祭坛环上加形状区分、下降橙与传说橙拉开、`TEXT_3` 提到 4.5 以上）。约 2 小时。
  - P3-1 20:9 中间单列上限收到 520～560；P3-2 物品分类数量换行；P3-3 队伍条血条加粗、层数字 14；P3-4 详情牌截断提示。合一单约半天。
- 已做（流程）：截图场景 `xiyou_ui_skin_p1fix` 前后对比自动拼图（Godot 里 `Image.blit_rect`，本机没有 PIL 也能出对比图），以后改皮肤常量可直接重跑出前后图。回退：删场景即可。

## 本分支提交

- 332b163bc 界面皮肤 P1 三条必改：选中条加厚三态、4:3 上下留边、战技列表躲行动条
- d89605198 截图场景 xiyou_ui_skin_p1fix、战斗测试加 --tablet、离树重排不报错
- 406e3174a 组入口图标 u4 定稿接入
- 350efeaab 主菜单两级操作＋右栏助力位卡
- （本提交）xiyou_tianqi_e2e 菜单导航跟上两级
