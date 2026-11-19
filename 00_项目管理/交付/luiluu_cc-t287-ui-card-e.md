# 交付：luiluu/cc-t287-ui-card-e

- 车道／工作者：T287 新界面卡 E「往里一层的环」／cc（Sonnet＋medium，P6；机械改组件数据和画法、量小，按稿配置建议）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T287·未经审查】新界面卡 E：往里一层的环（设置分类、技能类型、装备空栏位、TP、精魂、技能名品质色）（dev.待定）

- 依据：`界面风格提案_v0.7/T254_剩余页细节设计.md` 第二部分 R5、R6、R7、R13、R15、R21 与「卡 E」一节。只动新皮肤（`XUiSkin.on()` 开着）；皮肤关时旧画面一像素不变。
- R5 设置分类环：七个球里写一个字（常、战、敌、画、声、挂、他），环心的「N 项」换成当前分类名。
- R6 技能类型环：球里写一个字，显式映射（战技→战、魔法→魔、功法→功、被动→被、其他→他、呼吸法→呼、鬼灭呼吸法→呼、伊莉雅被动→专、光环→环；表里没有的取第一个字），同一个环上撞字时后来的从名字第 2 字起避让（如同环有呼吸法与鬼灭呼吸法，后者→灭；r1 P2-1）；环心由圆头像改成像素小人（摆法同主菜单，`XSkinMainMenu.sv_frame`，没有侧视图时回头像），头像仍在左下队伍条里。
- R7 装备栏位环：空栏位不再写「空」，画该部位的压到 25% 亮度的装备图标（每种栏位取装备表里编号最小的带图标的装备，临时；等正式剪影出了换）。
- R13 技能名颜色：列表行与详情牌标题的品质色改走 `XUiSkin.quality_color(XQuality.show_grade(技能))`（「优秀」是调柔后的 #8fdc5a，不是荧光绿 #80ff1c）；没有品质标记的技能照旧。
- R15：只有主菜单、装备页的队伍条不显示 TP，血条蓝条各加宽（`XSkinPartyStrip.show_tp`，默认 true；主菜单的由队伍条自己认出祖先是 `XSkinMainMenu` 关掉——`skin_main_menu.gd` 不在卡 E 范围，装备页显式设 false）。技能页、战斗内我方状态详情弹窗（`skin_party_status.gd`）、个人状态页（`skin_status_page.gd:171` 自绘量条，归卡 H）照旧显示 TP（r1 P2-2、P2-4）。
- R21：技能页右上不再放精魂（`currencies = []`，同装备页）。
- 回退：`XSkinRingNav.INNER_V2 = false` 一个开关回旧画法（球里不写字、环心「N 项」、环心头像、空栏位写「空」、技能名旧色、主菜单／装备页队伍条三条量条、技能页右上精魂）。
- 玩家可见：设置、技能、装备三页的环更好认；菜单里不再有永远是 0 的 TP 条。

## 交接板

- 下一步：无
- 用户试玩说明：设置页七个分类球写字、环心写分类名；技能页类型球写字、环心是小人、右上没有精魂、技能名颜色柔和；装备页空栏位是淡色部位图；主菜单、装备页的队伍条没有 TP。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`07_开发环境/皮肤关闭对照.py` 起 Godot 没带 `--audio-driver Dummy`（本车道用临时副本加参数跑，没改原件）；预计收益：每次跑对照不出声、归总装／工具车道。
- 建议：`XSkinTemplatePage.set_categories` 只带 key／name／icon 三项，glyph 要各页事后补进 `ring.items`；若加一个 `glyph`／`icon_dim` 透传，三页的补丁就能删（该文件不在卡 E 独占内，归卡 H／模板维护者）。

## 文字（待小A 审）

玩家可见新字，都是一个字的草稿：
- 设置分类球：常（常规）、战（战斗）、敌（遇敌）、画（画面）、声（声音）、挂（挂机与操作）、他（其他）。环心：当前分类名（沿用原分类名，不新写）。
- 技能类型球：战、魔、功、被、他、呼（呼吸法、鬼灭呼吸法）、专（伊莉雅被动）、环（光环）；撞字避让用类型名第 2 字起（r1 文字审方案，已按报告改）。
- 装备空栏位：不写字。

## 验收对照

1. 截图（`04_验证/本地结果/card_e/`，不进 Git；800×450＝16x9、1000×450＝20x9）：
   - 设置七个分类各选中一次：`card_e_options_1_general`…`card_e_options_7_other`（`_16x9`、`_20x9` 各一张）
   - 技能页类型：`card_e_skill_type1`…`type5`（测试角色狗逍遥有 5 个类型：战技、魔法、功法、被动、其他；稿说四个，以代码为准）
   - 装备页空栏位 13 个：`card_e_equip_empty13`
   - 字体 130%：`card_e_options_font130`、`card_e_skill_font130`、`card_e_equip_font130`（16x9）
   - 旧画法对照（开关关）：`card_e_old_options`、`card_e_old_skill`、`card_e_old_equip`（16x9）
   - 主菜单不显示 TP：`card_e_menu_no_tp`（16x9、20x9）；装备页不显示 TP：`card_e_equip_empty13` 左上队伍条。
   - 20x9 截图实际 1000×450（r1 P1-1 修：窗口改宽后要把 `content_scale_aspect` 切 KEEP_HEIGHT 才铺开，专项里加了尺寸断言 `shot_size_*`；之前 13 张是 800×450 的 16:9 复本）。
2. 皮肤关时旧专项不变：见下「验证」；`皮肤关闭对照.py --base github/main` 32/32 SAME。
3. 一个开关可回退：`XSkinRingNav.INNER_V2`，专项 `_rollback` 段覆盖。
4. 文字：见上「文字」节。

## 验证

- 新专项 `xiyou_ui_skin_card_e`：headless 43/43，带窗口截图 112/112（r1 返修后；上一版交付单写的 45/45＋24 不准，r1 P2-3 指出）。
- 并行测试（13 个界面场景，全过）：`xiyou_tianqi_gear_params xiyou_tianqi_ring_style xiyou_ui_art_phase01 xiyou_ui_sel_scale xiyou_ui_skin xiyou_ui_skin_1b xiyou_ui_skin_1c xiyou_ui_skin_3a xiyou_ui_skin_5c xiyou_ui_skin_card_e xiyou_ui_skin_close xiyou_ui_skin_menu xiyou_ui_skin_p1fix`。
- 选测名单里另有 `xiyou_event_compare` 四个（地图事件对照）：没跑——本单只动 `ui/skin/` 五个新皮肤文件，不碰事件；总装合并时按影响面决定。
- 改了旧专项 `xiyou_ui_skin_5c` 一处断言：`opt_ring_center_count` 现在按开关状态判（开＝环心清空，关＝「N 项」）。
- `语法检查.py` 通过。工具回归没跑（没改检查.sh、选测对照、转换器）。
- 偏离稿：稿写「技能页四个类型」，测试角色实际 5 个；稿写主菜单「环心是像素小人」本来就是，不改。

## 本分支提交

- 见 `git log`

## 小A 核查 r1 返修（T287 退回）

- P1-1：20:9 截图重拍，真是 1000×450；专项加 16x9=800×450、20x9=1000×450 的尺寸断言；补主菜单无 TP 截图（真 XMenu，`card_e_menu_no_tp`）。
- P2-1：技能类型球改显式映射＋撞字避让（见上）。
- P2-2：`show_tp` 默认改回 true，只在主菜单（认祖先）、装备页（显式）关；战斗内我方状态详情弹窗、技能页、状态页保持显示。
- P2-3、P2-4：测试数与 R15 描述已改正。
- 工具 T289（单独提交）：`皮肤关闭对照.py` 起 Godot 补 `--audio-driver Dummy`，跑一遍 32/32 SAME 不变。
- P3（不做，后续卡）：
  - P3-1：`XSkinTemplatePage.set_categories` 透传 `glyph`／`icon_dim`，删设置页、技能页的 `_put_glyphs`（卡 H 或模板维护者）。
  - P3-2：`_put_glyphs` 注释写「icon 清掉」但没清（球里 glyph 与 icon 互斥画，不影响）；`_draw_cat_name` 没有直接渲染断言。
  - P3-3：`currencies` 只在 `_init` 读 `INNER_V2`（热切不还原）；开关关着时 `_ensure_sprite_layer` 的 0.2s Timer 仍空跑。
  - P3-4：技能类型截图停在 type 态，右牌没展示带品质色的技能。
