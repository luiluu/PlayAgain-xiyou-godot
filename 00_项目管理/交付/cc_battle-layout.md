# 交付：cc/battle-layout

- 车道／工作者：T126 战斗站位优化＋小怪血条＋触屏指令环跟角色（cc，Opus＋medium，P8）；基于 luiluu/cc-battle-ui-v07（T125 b2140b3eb），随 T096／T125 一起合
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·天启篇·未经审查】T126 战斗站位撑开、小怪糖果粉血条、触屏指令环改回跟着角色（dev.待定）

- 依据：Kyo 11-17「首领血条就用糖果粉，小怪血条也按这个风格做一个。现在界面可视范围很大。boss和角色站位再优化一下」；出样 A／B／C 三版后 Kyo 定：首领战用 A、小怪战用 B，里德退到他圈的位置，我方集体往右后退拉开距离，小怪血条用脚下那版；D171「改回去」：触屏指令环跟着角色。
- 站位（新文件 `modes/xiyou/battle/battle_layout.gd`，`XBattleLayout`）：在原版坐标上再「撑开＋放大」。首领战（敌群只有一名成员）首领站固定首领点 (215,470)（Kyo 圈的地面，800×450 截图上约 (132,283)），放大 2.2 倍、显示高封顶 260；我方放大 1.6 倍，两排点位前排 x 822、后排 x 1017。小怪战：敌群外框按 1.5 倍拉开但收在矩形 (120,335)～(540,605) 里（本来就散的 8 只怨念之魂不再拉），小怪放大到 1.8 倍但显示高封顶 170、原图就大的（狼、怨魂、沉沦魔）不缩不放；我方放大 1.9 倍，前排 x 811、后排 x 1029。脚底 y 都在 330～600，上排在右上队伍栏下面。设置页选「原版竖排」时我方不撑开不放大。
- `battle_scene.gd`：`_place_battlers`／`_make_enemy_sprite`／天启换人走 `XBattleLayout`；新增 `enemy_src_home`（原版脚底，含 Reposition 的 48）、`layout_solo`。`battler_sprite.gd`：新增 `layout_mul`（归一档角色 167 号起的缩放不读 `_base_scale`，另乘它；`width`／`height` 跟着乘）与 `rescale`（敌人先按原版大小 setup，再按显示高算倍数）。技能动画、受击、伤害数字、选择光标都跟着精灵位置与高度走；行动序列里按像素写的位移距离没有跟着放大。
- 小怪血条（新文件 `modes/xiyou/ui/skin/skin_enemy_hp.gd`，`XSkinEnemyHp`）：首领血弧同色系细胶囊条（高 6、宽为身体宽六成夹 72～120，底槽黑 65%＋1px 浅边、左浅 ffc0dc→右深 ff5c9e、2px 光晕、顶上一道高光，扣血先留橙色拖尾，拖尾跟原版显示值 30 帧追上），名字正下方，活着一直显示，不写数字；首领（顶上有血弧的）与 `<HIDE HP GAUGE>` 的敌人不画。代码里留了头顶样式（`STYLE＝HEAD`，Kyo 没选，按格子高定位、留白多的图会飘高）。
- 触屏指令环（D171）：`XUiSkin.TOUCH_RING_FIXED`（默认 false）从 TOUCH_V2 里单拆，只管指令环位置；false 时触屏也跟着当前行动的角色（`XBattleScene._ring_follow`，同环自己不固定那一支），照旧让开 A／B 键组与右上队伍面板；TOUCH_V2 其余各项不变。没改 `skin_battle_ring.gd`（T125 在改；它的 `fixed_corner()` 仍认 TOUCH_V2，battle_scene 摆完后改摆一次）。
- 回退开关：`XBattleLayout.ENABLED`、`XSkinEnemyHp.ENABLED`、`XUiSkin.TOUCH_RING_FIXED`（改 true 回到右下）。
- 测试：新增 `tests/xiyou_battle_layout`（窗口 72 项含截图与取像素、无头 66 项）：首领点与封顶、敌群矩形、我方右半场不压队伍栏、我方与敌人间距、2 人队、原版竖排不撑开、两个开关关掉回原版、指令环跟角色且在画面内、TOUCH_RING_FIXED＝true 回右下、血条尺寸、拖尾先拖后追上、脚下那一行是糖果粉、首领不画。800×450 定稿图在私密仓 `协作交接/附图/T126/定稿_*.png`，出样三版四宫格同目录。
- ~~原版对照专项关掉站位撑开~~（R2 撤掉，见下）。
- 验证：云端选测 169 场景（57af843431）162 过、7 个即上面这些对照专项，加关开关后本机单跑 7 个全过（182／791／28／74／140／8／73）；xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_ui_skin_hud 等云端已过；xiyou_battle_layout 窗口 72/72、无头 66/66。合并 main（解 xiyou_sv_smooth 开头与云裳 ART 开关的冲突，两行都留）后本机复跑 14 个相关专项全过（xiyou_battle_layout、xiyou_ui_skin_battle_v07、xiyou_battle_ui、xiyou_sv_smooth、xiyou_guyu_ui、xiyou_sequence_visual、xiyou_battle_pixel、xiyou_popup_overlap、xiyou_party_formation、xiyou_yunshang_art、xiyou_ui_skin_4a、xiyou_ui_skin_battle、xiyou_determinism、xiyou_ui_skin_hud），交付自检退出 0。
- 玩家可见：天启篇新界面的战斗里角色和怪物变大、拉开铺满画面，首领站到左边（西游档／原版界面照旧）；小怪脚下多了一条粉色细血条（扣血有橙色拖尾）；手机上战斗指令环改回跟着当前行动的角色。


- **R2 返修（小A 核查退回 71bb39aa0）**：
  - P1-1 站位撑开只在新界面生效：`XBattleLayout.spec()` 加 `XUiSkin.on()` 门控（西游档／设置页选原版界面＝原版站位与大小，不压旧 XSideStatus、旧指令窗，O-473 阵型照旧 x≤819）。`xiyou_battle_layout` 补 `old_ui_identity`（单元）与 `_xiyou_old_ui`（FORCE＝false 进 4 只小怪战与首领战：敌我都是原版脚底、layout_mul＝1、我方 x≤819、不画小怪血条，窗口模式出西游档截图）；反向验证：撤掉门控 6 项失败。
  - P1-2 七个老专项开头的 `XBattleLayout.ENABLED = false` 全部撤掉，不加回任何关法；本机单跑 xiyou_party_formation 74／guyu_ui 791／sv_smooth 140／popup_overlap 8／battle_pixel 28／sequence_visual 73／battle_ui 182 全过。
  - P2-1 选择光标随放大重算：`battler_sprite.gd` 抽 `_cursor_y()`（侧视图一格高×layout_mul，其余 height()），setup 与 rescale 都调；`_check_cursors` 核首领战、小怪战敌我光标都在放大后身高处；反向验证：撤掉重算两项失败（顺手修了该断言失败分支里 `x.name()` 不存在的报错）。
  - 截图：私密仓 `协作交接/附图/T126/R2_西游档_4只小怪.png`（旧侧栏、旧指令窗、原版大小与阵型）、`R2_新界面_首领战.png`（新界面不回归）。
  - 验证：xiyou_battle_layout 无头 78/78、窗口 85/85；xiyou_ui_skin_battle_v07 41/41；检查.sh --affected 71bb39aa0 见下行。
  - 验证：检查.sh --affected 71bb39aa0 选中 39 个 Godot 场景全过；非 Godot 只剩 1 项「发行空壳缺成员」：`modes/xiyou/ui/skin/skin_boss_arc.gd`（T125 b2140b3eb 的文件，本轮没动；引用 DENY 里的 hong.png）。本分支自己的 battle_layout.gd 也曾因 R2 头注释写「只在天启篇新界面」被认成天启篇专属，已改措辞（它在发行包里要用、恒走原版站位）。
  - **要总装登记**（共用文件，车道不改）：`发行空壳.py` 的 MIXED_OK 加 `'modes/xiyou/ui/skin/skin_boss_arc.gd': '首领血弧：只在 XSkinBattle.on()（XUiSkin.on()）时创建，发行包里恒为 false；铜印贴图走 ResourceLoader.exists 守卫，在 DENY 里不进包'`，加上后 检查.sh 即全过。
  - 合并（协调追加）：合 main（T100 字体 FONT_V00300）解 skin_battle_list／ring／boss_arc 冲突——取 T125／T096 的逻辑（详情胶囊、标题淡入 ta、INK_TEXT 描边宽），自绘字照 main 改走 `XUiSkin.ds`；T125／T096 新加的 9 处裸 draw_string（skin_battle、skin_battle_list、skin_battle_ring、skin_damage_popup、skin_turn_cue）也改走 `XUiSkin.ds`，过 xiyou_ui_skin 的 t100_no_raw_draw_string。再合 luiluu/cc-battle-ui-v07（T125 R2 141893e95、R3 88bad1661：首领头像去黄底、圆钮修正）无冲突，再合 main（b27ba2cab）无冲突。
  - 完整战斗画面（合完后）：私密仓 `协作交接/附图/T126/R2_新界面_首领战.png`、`R2_新界面_小怪战.png`、`R2_西游档_4只小怪.png`（800×450）。
  - 合完后验证：检查.sh --affected 3132281d0 选中 66 个场景全过（xiyou_battle_layout 78、xiyou_ui_skin_battle_v07 56、xiyou_battle_ui 182、xiyou_ui_skin_hud 110、xiyou_ui_skin_4a 57、xiyou_guyu_ui 791 等），本机补跑 xiyou_ui_skin 111、xiyou_party_formation 74、xiyou_sv_smooth 140、xiyou_popup_overlap 8、xiyou_battle_pixel 28、xiyou_sequence_visual 73 全过；窗口 xiyou_battle_layout 85/85。非 Godot 仍只差上面「要总装登记」的 skin_boss_arc 一项（发行空壳 check 与其工具回归是同一原因）。
  - P3：冲锋类行动序列像素位移不放大，小A 查实不做精灵横移、不会打空，不改。
## 交接板

- 下一步：合并后请小A／小o 实机看一眼放大后的冲锋类技能（行动序列像素位移没放大）和变身怪（换图后照新图大小重算倍数）。
- 用户试玩说明：进任意战斗看站位与小怪血条；手机上看指令环是否跟着轮到的人。
- 需要用户决定：无（指令环位置 D171 已定）。

## 进度账

- 天启篇界面：战斗站位与小怪血条完成，不改完成度数字。

## 可优化（流程／工具／效率）

- 建议：`skin_battle_ring.gd` 的 `fixed_corner()` 合并后改成 `TOUCH_V2 and TOUCH_RING_FIXED and touch()`，就能删掉 battle_scene 的 `_ring_follow` 改摆（T125 收口后由总装或小A 顺手做，一行）。
- 建议：出样图要加文字标签时本机 ffmpeg 没有 drawtext，可让工具车道装带 freetype 的 ffmpeg 或在 Godot 截图脚本里直接画标签。
