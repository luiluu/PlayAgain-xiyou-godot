# 交付：luiluu/t196

- 车道／工作者：T196 战斗队伍栏展开收起＋头顶行动标记（cc，Opus＋medium）
- 状态：可合并

依据：Kyo 11-18 09:0x「队伍栏做成可以展开收缩，跟我们的团队看板一样。要有动效，三角标改到目前行动角色头上，做立体一点也要能动。队伍栏三角标去掉，然后缩小的队伍栏只显示目前行动的角色」。

## 变更记录草稿

## 2026-11-18 【cc·天启篇·未经审查】T196 新界面战斗队伍栏可展开／收起＋当前行动角色头顶立体宝石标记（dev.待定）

- 新 `modes/xiyou/battle/party_fold.gd`（`XPartyFold`）：右上队伍面板最上面加 26 高栏头（旧金箭头＋「队伍」）；点栏头（触屏点）、键盘 Tab、手柄 Back（View／Select）切换。各行搬进裁剪框：收起＝框高从全部行缩到一行、各行往上滚到焦点那一行，动效照团队看板折叠（0.25 秒，cubic-bezier(.16,1,.3,1)，箭头转 90°）；界面动效「关」时直接到位。收起时只露「焦点角色」＝最近一次轮到行动的我方角色（敌人行动时不换，不来回跳）；收起中换人时滑到新的一行、旧行淡出新行淡入；栏头右侧淡写「2 / 4」。展开／收起存设置 `codexPartyExpanded`（默认展开）。换人（助力位）时换上的人接替焦点。
- 新 `modes/xiyou/battle/turn_marker.gd`（`XTurnMarker`）：当前行动角色头顶一颗四面倒置宝石（冠部斜面＋台面＋倒金字塔亭部，每帧 3D 投影、按朝向打光；朱红／深红面、旧金边、淡金高光星、暖红呼吸光晕、右下落影当厚度）。动效「全部」慢转（3.6 秒一圈）＋上下浮 3px＋光晕呼吸；「简化」只浮；「关」静止。跟着精灵当前位置（出招走位也跟），换人时沿小弧滑过去（0.3 秒）；敌人行动时停 0.35 秒再淡出。放在 fx 层、z 比伤害数字低一级（数字盖在上面）；「某某 的回合」提示演出中、选我方目标光标停在它身上时先让开。
- `skin_side_status.gd`：轮到的那一行只铺红底、不再画左外红色小箭头（`draw_active`，标记开着且有正式美术时）；`row_pos` 让出栏头；面板底 `Back` 按折叠高度画、栏头下一道旧金细线。
- `battle_scene.gd`：建队伍行后 `XPartyFold.attach`、开战建 `XTurnMarker`；`_set_active` 通知两者；`party_rect` 折叠开着时取栏头＋露出的行（指令环、助力位锁定条按收起后的高度让开）；换人时通知两者。
- 协调核查返工（同日）：
  - P1-1 宝石压在指令环「攻击」高亮行右端、遮「某某的行动」：指令环（各项＋「某某的行动」，`XSkinBattleRing.item_rects`）或技能／物品列表开着且压到宝石时，宝石先往右挪出菜单（指令弧在角色左边，一般只差十几二十 px，最多 56），仍贴在这个角色头顶右上；挪不开（超 56 或出画面）才往上抬到菜单顶上（最多 170）；挪开时从尖画一道旧金虚线连回头顶。挪开／挪回平滑跟随，菜单关掉落回头顶。先试过「一律往上抬」，美娜开菜单时宝石被抬到后排罗琳胸口，像标的是罗琳，所以改成先往右。
  - P2-1 宝石放大约 1.2 倍（腰圈半径 15→18、亭部 24→29，原尺寸约 36×42 px），并给外轮廓加一圈 3px 深色描边：雪地是浅灰白，原来朱红亮面＋旧金边和背景对比不够，深描边在浅背景上最能把形状压出来；光晕也跟着放大。没再放更大：再大会压到头顶的「某某 的回合」提示和敌人血条。
  - P2-2（授权越界）`modes/xiyou/battle/tianqi_meter.gd`：死期小钟改由新 `doom_mark_rows()` 取行，跳过 `not row.is_visible_in_tree()` 的行（队伍栏收起时被藏的行不画）；专项加断言 doom_skips_hidden_row。
- `xconfig.gd`／`xconfig_transfer.gd`：加设置键 `codexPartyExpanded`（默认 true，归「可导出设置」）。
- 只在新界面（`XUiSkin.on()`）里有；旧界面不加（理由见下「没做／偏离」）。
- 回退：`XPartyFold.ENABLED = false`（没有栏头、不裁剪，各行原位）；`XTurnMarker.ENABLED = false`（没有头顶标记，队伍栏那一行的左外小箭头回来）。
- 专项：新 `tests/xiyou_party_fold`（52/52，含回退与旧界面断言）；`xiyou_ui_skin_hud` 按新结构改了找面板底的写法与面板高（栏头）。
- 玩家可见：新界面战斗右上队伍栏能收起成一行（点「队伍」或 Tab／手柄 Back），当前行动的角色头顶有一颗会转的红宝石标记。

## 交接板

- 下一步：小A 文字审（下面「文字」）；核查（新机制接线，建议小A 主核）。
- 用户试玩说明：天启篇新界面战斗中，点右上「队伍」栏头或按 Tab（手柄 Back）收起／展开；收起只显示正在行动的角色；行动角色头顶有红宝石标记。

## 没做／偏离

- 旧界面（原版风格）不做：旧界面队伍行是原版 1:1（行高 121、无栏头空间，轮到的人靠左移 48 表示，没有红三角），加栏头和标记会改原版画面、碰像素对照；卡上允许「旧界面若不合适可只做新界面」。
- 改了两个独占范围外的文件各一行：`modes/xiyou/core/xconfig.gd`（DEFAULTS 加 `codexPartyExpanded`）、`modes/xiyou/core/xconfig_transfer.gd`（SETTINGS 清单加同键；不加的话 xiyou_config_transfer 会报「新设置没归类」）。卡上要求「存设置」，没别的办法。
- 没有正式美术（`XSkinArt.select_on()` 假）时，轮到那行仍按旧 `draw_select` 画（那套左光标和淡金小三角是行本身的一部分）。默认有正式美术，玩家看到的是去掉箭头的版本。
- 死期小钟问题已按协调授权在本单修掉（见上 P2-2）。
- 头顶标记只标我方角色（`_active` 只给我方）；敌人行动时淡出，不挂到敌人头上。

## 文字（待小A 审）

- 栏头「队伍」；收起时栏头右侧「2 / 4」（当前焦点序号 / 出战人数）。
- 按键：Tab（键盘）、Back／View／Select（手柄）；画面上没写键名。若要加键位提示，请小A 定写法。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`选测.py` 对 `xconfig.gd` 一行改动选出 222 个场景，车道本机跑不动；可考虑对「只在 DEFAULTS 加键」这类改动只选 config_transfer＋options 类。归工具车道。

## 测试

- 本机选测 29 场景全部通过（并行测试 20261118_104216）：xiyou_party_fold、xiyou_ui_skin_hud、xiyou_ui_skin_battle、xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_ui_skin_4b、xiyou_ui_sel_scale、xiyou_config_transfer、xiyou_determinism、xiyou_battle_layout、xiyou_battle_actor_size、xiyou_big_form_sizes、xiyou_tianqi_swap_view、xiyou_tianqi_brand、xiyou_tianqi_doom_follow、xiyou_tianqi_real_swap、xiyou_tianqi_party、xiyou_battle_ui、xiyou_hud、xiyou_battle_pixel、xiyou_ui_pixel、xiyou_options_basic、xiyou_options_misc、xiyou_ui_skin_close、xiyou_ui_skin_offshot、xiyou_battle_options、xiyou_party_formation、xiyou_difficulty_notice、xiyou_party_status_panel。
- 返工后：xiyou_party_fold 72/72；再跑 xiyou_party_fold、xiyou_ui_skin_hud、xiyou_tianqi_doom_follow、xiyou_tianqi_brand、xiyou_ui_skin_battle、xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_tianqi_e2e、xiyou_determinism 9 场景全过（20261118_110458）。
- 偶发（首跑失败、单跑通过，各累计 1 次）：xiyou_ui_skin_battle_v07（list_grows_from_right，列表展开动画计时）、xiyou_tianqi_doom_follow（首跑 74/74 但退出码 1）。都不是本单文件。
- `选测.py main --list` 共列 274 个（xconfig.gd 牵出 222 个），其余没在本机跑，留给总装按影响面选测。
- 语法检查通过；工具回归通过。

## 附图（00_项目管理/交付/luiluu_t196附图/）

- `t196_队伍栏展开收起换人.gif`：右上队伍面板原尺寸裁切（420×300），展开→Tab 收起→收起中换人（修→罗琳）→点栏头再展开。
- `t196_头顶标记特写.gif`：头顶宝石原尺寸 160×160 特写（转＋浮＋呼吸光，指令环开着时已右挪、带连线），约 4 秒。
- `t196_菜单开着时标记让开.gif`：指令环先开在狗逍遥（上排）、再开在美娜（下排）时宝石让开菜单（右半屏原尺寸裁切 640×560）。
- `t196_menu_0_狗逍遥.png`～`t196_menu_3_美娜.png`：指令环分别开在四个站位不同的角色身上时的整屏截图（美娜那张＝返工前问题截图同角度）。
- `t196_mob_expanded.png`／`t196_mob_collapsed.png`：小怪战展开／收起静态截图。
- `t196_boss_expanded.png`／`t196_boss_collapsed.png`：首领战展开／收起静态截图。
