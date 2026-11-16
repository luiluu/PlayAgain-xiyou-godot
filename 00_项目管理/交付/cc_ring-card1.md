# 交付：cc/ring-card1

- 车道／工作者：B 界面「T029 装备环卡 1：环纹数据口子＋3 套样板接入」（cc 车道，Orca task_19924f0f4446，Opus＋medium P8：动新界面绘制层序和设置项接线）
- 状态：可合并

依据：私密设计仓 `重制设定/天启篇_装备环样式设计_v0.2.md`（v0.2.1，a491070）「卡 1」节；第 5.1 层序、第 7 节接口、第 8 节 D94～D102；小A 抽看 8cb0693 第三节两条提醒。界面底子是 main 上的 v7（dev.634）。

## 独占文件（实际改动）

- 新：`modes/xiyou/core/tianqi_ring_style.gd`（`XTianqiRingStyle`）、`modes/xiyou/tianqi_data/ring_styles.json`、`tests/xiyou_tianqi_ring_style.gd/.tscn`
- 改：`modes/xiyou/ui/skin/skin_ring_nav.gd`（只加环纹层，选中缩放逻辑没动）、`modes/xiyou/ui/skin/skin_equip_page.gd`（环纹接线、环心框、环下说明；没碰选中态）、`modes/xiyou/core/xconfig.gd`（`codexRingStyle` 一项）、`modes/xiyou/ui/options_scene.gd`（设置行）、`modes/xiyou/ui/skin/skin_options_page.gd`（设置分组＋说明一句）
- 和 T024（全局选中放大）可能在 `skin_equip_page.gd`／`skin_ring_nav.gd` 撞行：我只在 `_init`、`_draw` 开头的法阵／光带段、球循环末尾的栏位名段、`advance` 末尾加了东西；`item_scale`、`_ease_scales`、`label_layout`、`select` 一行没动。球框和小点都按 `item_scale(i)` 走，T024 改倍数自动跟上。

## 结论

- 卡 1 五条全做了：数据＋解析（规则含微亮三条、刻印、双持、七印神器全队一件）；环控件按 5.1 新建 `_band_ci`（behind parent）／`_orb_ci`／`_label_ci`，球框小点不进 `_art_ci`；装备页槽位→环项按 `items[i].key`、环心框画在 `ring_top` 的最近邻子画布 `_center_ci`、环下说明过 `fit_text`、缓存键加出战顺序、只演亲手换装；设置项「装备环纹」；开关、空壳、内容审计。
- 美术没到：用程序画的同尺寸灰圈占位跑通（`XTianqiRingStyle.placeholder`：环身 288 主圈 112＋100／138 细边；环心 96 框 33～38、12 点尖到 46；球框 56 灰阶框身 21～24、斜角到 28），图放进 `content/tianqi/ring_style/<同名>.png` 就自动换，不改代码。
- **关掉等于没做（逐像素）**：用 main 版本的五个界面／配置文件和本分支分别出图比对，6 张全部 0 个像素不同：装备页（开关开、身上没有环纹件）16:9／20:9 触屏 130%、装备页（穿黑印 5 件、`ENABLED` 关）两比例、主菜单两比例。做法：临时截图脚本（只用两边都有的接口），本分支跑一次 → 五个文件 `git show main:` 覆盖 → 再跑一次 → `git checkout` 还原 → 逐像素比。临时脚本没提交。
- 小A 两条提醒：① `_orb_ci` → `_label_ci` → `_art_ci` 在 `_init` 里按这个顺序建、都不设 `draw_index`，ring_top 之后才 add_child，天然在它们之上（专项 `page_layer_order`）；② 环心框起点 `(c − ts/2).round()`（`center_frame_rect`，专项 `page_center_frame` 断言整数位置）。
- 旧配置读入：没有 `codexRingStyle` 键 → 开；存成 false → 关；存成乱值（字符串、0）→ 开，不报错（照「只有存成 false 才关」那组处理）。这是配置文件 `options.json`，不是存档，存档格式没动。

## 7.5 逐行对应

专项 `xiyou_tianqi_ring_style`：无头 84/84；带窗口（`--out`）115/115（多出截图、正红、对比度 31 项）。反向验证跑了 8 项，7 项咬住（小点挪回屏幕右上 45°、小点朝环心、七印神器不看全队、槽位号直接当序号、ENABLED 失效、名字不挪层、残缺不压暗）；没咬住的是「小点相对径向偏 −90°」——那个位置本来就不压字，测试照实通过，不算断言漏。

| 7.5 那一行 | 用例 |
|---|---|
| 规则 | `rule_set4_no_band`、`rule_set5_band`、`rule_swap_one_back`、`rule_mixed_3_3_dots`、`rule_glint_jingyin3`、`rule_glint_jingyin2_no`、`rule_glint_old_line_no`、`rule_glint_hooks_default_false`、`rule_glint_orig_set`、`rule_glint_runeword`、`rule_glint_switch_off`、`rule_seal_over_glint`、`rule_relic_full`、`rule_relic_half`、`rule_artifact_solo_*`、`rule_artifact_two_first_only`、`rule_artifact_reorder`、`rule_artifact_backup_off`、`rule_artifact_backup_inactive`、`rule_whitelist_no_center`、`rule_weapon_one_orb`、`rule_engrave_orb`、`rule_dual_two_tints`、`rule_item_tag_orb`、`rule_enabled_off_empty`、`rule_setting_off_empty`、`rule_not_tianqi_empty` |
| 槽位映射 | `page_slot_map_offhand`（副手那颗亮、序号 ≠ 1）、`page_slot_map_not_artifact`、`cat_first`、`cat_weapon_orb`（178 没副手，不出错） |
| 关掉等于没做 | `page_enabled_off_plain`、`page_default_plain`；逐像素见上「结论」 |
| 不压字 | `nooverlap_{std,cat}_{key100,touch100,f130}` 6 项：每项轮流选中＋全部未选中；名框一律取 `label_layout(i).rect`；① 名框到环心圆距 > 38、不碰 12 点 ±15° 38～46 扇形；② 球框圆 24k＋斜角 28k 不碰别的名框、武器那颗框身不碰本名框；③ 防具 6 颗小点 8×8×k 不碰名框、别的球、连线（半宽 2.3＋1.5）；层序 `page_layer_order` |
| 字看得清 | 带窗口 `contrast_{hei,mo,death,death_half,glint,hong,xun}`：名字隐去（`hide_labels`）后名框 90 分位亮度，选中 ≥ 7、其余 ≥ 4.5，红印、殉印各测 |
| 不出正红 | 无头 `tex_no_red`（全部贴图×染色，含 7 色球框）、`tex_hong_circle_tinted`；带窗口 `red_added_zero_*`：环区环纹开比关新增正红像素 0（排除选中红框圆环 ±4 与头像圆 33 内——头像立绘自己的红眼睛随头像缩到 33 会变位置） |
| 位置没动 | `page_positions_same` |
| 不变卡 | `page_cursor_no_resolve`（挪 13 格 resolve 0 次）、`page_order_resolves`（换出战顺序重算 1 次）、`page_cursor_cost`：无头实测挪光标一格 styled 3.8 ms／plain 4.2 ms（同一页、无头抖动大，没测出增量） |
| 动效档位 | `motion_simple_intro_plays`、`motion_simple_intro_done`、`motion_full_fade_half`、`motion_off_one_frame`、`motion_fx_off_one_frame`、`page_intro_on_equip` |
| 截图 | `03_再刷重制_Godot/04_验证/本地结果/ring_style/`（本地结果目录不入 Git）：hei／mo／death／death_half／glint × 16:9、4:3、20:9 触屏 130%，hong／xun 16:9，共 17 张 |
| 设置项 | `setting_default_on_no_file`、`setting_load_*`（4 种旧配置）、`setting_saved`、`setting_row_after_motion`、`setting_row_onoff`、`setting_row_hidden_xiyou` |
| 占位图尺寸 | `tex_placeholder_sizes`、`tex_center_bounds`、`tex_orb_bounds`、`tex_seal_tints_7` |

## 验证

- `语法检查.py` 通过；`发行空壳.py check` 通过（64 个脚本，`XTianqiRingStyle` 按 `XTianqi*` 前缀自动换空壳，空壳 `resolve` 给 `{}`，装备页按空结果走默认环）；数据 `tianqi_data/*`、图 `content/tianqi/*` 已在发行 DENY／导出排除里。
- 本机选测 20 个全过：`xiyou_tianqi_ring_style`、`xiyou_ui_art_phase01`(214)、`xiyou_ui_skin`／`_1b`／`_1c`／`_3a`／`_3b`／`_4a`／`_4b`／`_5c`／`_close`／`_menu`／`_p1fix`／`_offshot`、`xiyou_battle_options`、`xiyou_graphics_options`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_notice_options`、`xiyou_hangup_options`。
- `选测.py main --list` 结论「整轮」：因为改了 `xconfig.gd`（205 个场景引用它）。我只加了一个默认键和一条读法分支，没跑那 205 个，交总装按影响面定；事件对照四份同理没跑（界面改动，不碰事件）。
- `工具回归.py` 全过。
- 冷启动 SCRIPT ERROR：无头与带窗口两次运行日志里 0 条。

## 我不同意的地方

1. **法阵染色和稿子 7.1 示例不一样。** 稿子示例黑印 `circle_tint: #ffffff`，但实测 `hei.png`、`xun.png`、`mo.png` 原图都有正红区（白色染色下 21198／23194／445 个正红像素），D97「不出正红」过不了。我把 hei／xun／mo 的 `circle_tint` 改成 R ≤ 0xc6 的暖灰（`#c6b48c`／`#c6b8a0`／`#c0b4cc`），乘完 R ≤ 198。屏幕上法阵本来就只有 0.24～0.28 透明度，看着差不多；请小o 出图时也按这个口径看。
2. **印色没用 `qiyin_show.json` 的 color。** 那里红印 `#E8582A` 过正红门、黑印 `#2A2A30` 太暗当不了小点。`ring_styles.json` 新增 `seal_tints` 七色（按 2.3 节方向：骨白、暗锈红、黄铜、灰绿、月白、暗靛、默紫灰），请小A／Kyo 过目。
3. **「每帧多出的绘制 ≤ 6 次」这条按贴图算。** 一人最多：环身 1＋法阵替换 0（替掉通用的）＋环心 1＋球框 ≤ 2（双持）＝ 4 次贴图；套装小点 ≤ 6 颗是纯色矩形（每颗 2 个），全满时多 12 个矩形命令。稿子写 ≤ 6 次，如果矩形也算就超了；矩形开销很小，我没为此合并，没加断言，交核查方判。
4. **有环身图时外圈细线（R+10.5）也不画。** 稿子 7.3 只说光带、主圈、虚线三样不画；那圈细线正好压在环身图 100～138 的装饰带中间，留着会在图上多一道线，所以一起关了。
5. **「补画选中红框」会让红框抗锯齿边多几个像素过正红门。** 同一圈画了两遍（父层一遍、`_orb_ci` 一遍），这是稿子要求的；正红测试按稿子「排除选中项红框」扣掉选中球 ±4 的圆环。

## 没做的（不在卡 1）

- 4.2 说明里加句（套装 5 件那行、遗物／神器／毕业武器说明尾句、候选「凑满 5 件」小环标记）、祭坛「印记外观」弹窗放环身图：卡 1「做什么」没列，没做。
- 其余 5 印、3 线、七印神器环心的图（卡 2 第二批）；主菜单（D102）；真印；预显。
- `orig_set_full`、`runeword_active` 两条只留了 `orig_set_full_hook`／`runeword_hook` 两个口子，养成线重做落地的车道接上即可。

## 小A 文字审（玩家可见文字，待审）

- 设置行名「装备环纹」；说明：「穿齐七印套装、戴上骑士遗物或毕业武器时，装备页的栏位环换成对应的纹样。只改外观，不影响数值；关掉后所有人都用默认的环。」（`skin_options_page.gd` DESC）
- 环纹名（`ring_styles.json` name）：白印…默印、死亡遗物／战争遗物／饥荒遗物／瘟疫遗物、七印神器；后缀「（残）」「（未生效）」；环下说明「身上 n 件 · 黑印 · 死亡遗物（残）」。

## 变更记录草稿

## 2026-11-16 【cc·环纹卡1·未经审查】天启篇装备环纹：数据口子、解析、环控件层序、3 套样板（占位图）接入、设置「装备环纹」（dev.待定）

- 设计仓《天启篇_装备环样式设计 v0.2.1》卡 1：新增 `XTianqiRingStyle`（`tianqi_data/ring_styles.json`），按身上穿的出环身（七印满 5 件、1～30 层旧金微亮）、环心（骑士遗物，残缺压暗；七印神器全队只第一个戴的人亮）、单颗球框（毕业武器、刻印专属武器、备注 `<ring_style:键>`）、套装小点（2 件起）。
- `XSkinRingNav` 按 5.1 层序新增环身（behind parent）、球框小点、栏位名三个子画布项，加 `style_art`／`orb_frames`／`orb_dots`／`motion`／`play_intro`；没有环纹时栏位名照旧画在原循环，和以前逐像素一样。装备页槽位按 `items[i].key` 换环项序号、环心框画在头像之上的最近邻子画布（有框时头像缩到 33）、环下说明接环纹名、缓存键加出战顺序、只有本页亲手换装才演 0.6 秒铺开。
- 美术没到用程序灰圈占位；`content/tianqi/ring_style/` 放同名图即替换。
- 设置页新增「装备环纹」（默认开，新界面开着时列在界面动效后）。
- 回退：`XTianqiRingStyle.ENABLED`、`GLINT`（O-待定）。
- 验证：专项 `xiyou_tianqi_ring_style` 无头 84/84、带窗口 115/115；界面与设置专项 19 个本机通过；关掉开关与 main 逐像素比 6 张 0 差异。
- 玩家可见：天启篇装备页穿齐七印套装、戴骑士遗物或毕业武器时栏位环换纹样（现为占位灰圈，正式图待卡 2）；设置页多一行「装备环纹」。
- 提交：（合并时填）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定-1 | `modes/xiyou/core/tianqi_ring_style.gd` `ENABLED`；`skin_ring_nav.gd`、`skin_equip_page.gd` 环纹层 | （天启篇新界面）装备栏位环所有人同一个样子 | 跟身上穿的换环身、环心、球框、套装小点（环纹） | 装备环样式设计 v0.2.1 卡 1，D94～D102 | `XTianqiRingStyle.ENABLED = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_ring_style.gd` `GLINT` | （天启篇）1～30 层环身不变（路 B） | 本线第三档净印／原版重做套装穿齐／生效符文之语时环身旧金微亮（路 A） | D94 路 A | `XTianqiRingStyle.GLINT = false` | cc | 保留 |

## 交接板

- 下一步：卡 2（小o）四张样板图到了直接放 `content/tianqi/ring_style/`（`ring_band_hei.png`、`ring_band_mo.png`、`ring_center_death.png`、`ring_orb_frame.png`），跑 `xiyou_tianqi_ring_style` 带窗口截图看；文字过小A。
- 用户试玩说明：天启篇装备页，穿齐 5 件同印七印套装 / 神器栏戴骑士遗物 / 武器栏穿毕业武器，栏位环会变（现在是灰色占位圈）；设置 → 画面「装备环纹」可关。
- 需要用户决定：无（「我不同意的地方」1、2 的配色请小A／小o 顺带看）

## 进度账

- 天启篇界面：装备环纹卡 1 完成（口子＋占位图），卡 2 美术待出

## 可优化（流程／工具／效率）

- 建议：逐像素「关掉等于没做」这次靠临时脚本＋手动覆盖 main 文件比对，可做成工具（`像素对照.py <场景> <要回退的文件…>`，自动 `git show main:` 覆盖、出图、还原、比对），以后界面车道都能用；预计每单省 15 分钟，归工具车道。

## 本分支提交

- db6700dc4 WIP: 环纹卡1 数据口子、解析、环控件层序、装备页接线、设置项
- 401ae6ea1 WIP: 环纹专项、法阵去红染色
- 944c8863d WIP: 专项头注释写数据路径（选测能对上）
- （本交付提交）
