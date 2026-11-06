# 交付：cc/ui-newsrc3（换源追平界面第四段：人物图鉴、说明卡特效排序与成长措辞）

- 车道／工作者：界面 DE（cc）
- 状态：可合并
- 说明：DL ③ 心钢技能卡与 zhenqi page.* 第三棒已做（工作树 `.claude/worktrees/musing-mclaren-41e4ab`，本地分支 `cc/musing-mclaren-41e4ab`，推到 GitHub `cc/ui-newsrc3`）；流萤说明按阶生成与技能名色也做了（总装追加，先合了 wukong-newsrc9 fd0f53b4）；m234 等第二次同步后复查。①②③ 已做（第二棒补了 gear_search 重量、power_panel 重取，另写了新源 DOM 取数驱动）；④ 失败表认领、help_card 10622／10623（总装二十八加）等第二次同步后再做（见「接续要点」）。
- 第二棒工作树 `.claude/worktrees/fervent-shirley-617455`，本地分支 `cc/fervent-shirley-617455`（`cc/ui-newsrc3` 还挂在上一棒的工作树上，没动它），推到 GitHub 的 `cc/ui-newsrc3`。交回集成分支 `cc/newsrc-switch`（不合 main）。
- **合并顺序**：本分支已合 `cc/wukong-newsrc9` fd0f53b4，总装照旧先合悟空、再合本单即可（原写：先合 `cc/wukong-newsrc9`（54ae6b10，切片加 179，导出流萤 SV／脸图／行走图），再合本单并重同步；否则 `xiyou_actor_book` 的 179 立绘一项会挂。
- 依据：派单第十四批 DE 节＋协调追加的 gear_search 三项；总装二十八 11-06 追加 DL 单（手量夹具换无头重取＋说明卡 v0.43 版式），①② 已做，③ 心钢技能说明卡冷却没做（到 40% 停手）。从 `cc/newsrc-switch` 21cd90eb 切。
- 工作树 `.claude/worktrees/peaceful-lalande-9fc698`：`generated/`、`.godot`、`mv_oracle/.sandbox`、`node_modules` 用 APFS 克隆自集成树（21cd90eb，**集成分支重同步之前**的产物）；同步完要重克隆一次再复测。本机测试槽被同步占满，测试全在云端跑（workflow_dispatch 指定场景，产物快照 `refs/ci/generated/cc/ui-newsrc3`）。

## 变更记录草稿

## 2026-11-06 【cc·界面·未经审查】换源追平界面第四段：人物图鉴跟新源、说明卡特效按品质排序、专属技能成长措辞（dev.待定）

- **人物图鉴**（`ui/actor_book.gd`，跟新源的显示改动，不设开关）：
  - 目录去掉 `CodexV029.hiddenActors`（141、146、152、157、160、161、166，installIntegratedV029Runtime v0.30 的 Window_ActorBookIndex.refresh 包装；「？？？」占位留着）。目录位置不再等于角色号，状态页、立绘、抬头、技能详情都按 `index_ids()` 取角色（v0.35 `Window_ActorBookIndex.actor()`）。
  - 状态页：本角色基础技能里有 `<CodexAura>` 光环时排成「主动／被动／光环／其他」四列（Star_ActorsBook v0.29）：列宽 floor(932/4)＝233，文字宽 225，技能 22 号、行距 30，每列最多 floor((684−首行 y−行高×6)/30) 行，多出的写白字「确认查看全部」；掌握段跟在最长一列后面。
  - 技能详情：光环技能标签写「【光环】」；179 流萤补技能表（10622～10632，加备注 `<CodexLiuyingPassive:` 的）并进「未解锁」名单。
  - 立绘：Codex_MiraRavenMultiFrame v1.06 的流萤 128px 档 `Codex_Liuying_SV` 登进 `XAppearance.PROFILES`（战斗归一也用这一档）；v1.07 图鉴倍率 `XActorBook.BOOK_SCALE`（流萤 0.8，只在图鉴里乘）。
- **说明卡特效按品质排序**（`XHelpCard.EFFECT_SORT_V041`，默认开，**O-待定·特效排序**，关＝原顺序）：照 installEquipmentDetailV041Runtime 的 CodexDisplay.equipmentRows 包装，装备的特效行（去色码后以「混沌神话／混沌／神话／太古／mod特效」或「特效／效果／成长」开头，或带 `\c[1-9]`）只在原位置之间按品质从高到低换位；品质取备注里该行前最近的 `<quality:N>`（`XSafeSell.rank`），不是备注带来的按模板品质，混沌 111、神话 110、mod 93、太古 91。排序放在元素／穿透行插好之后、◆唯一 标记之前（与原版包装次序一致）。另删 v0.41 旧存档里留的「效果：持有…时，造成的技能伤害＋」「效果：持武增伤作用于」。
- **专属技能「成长：」措辞**（`ui/character_help.gd` nowGrowthRows，跟 v0.62.12）：谷雨 10290、10292、10293、10298；屠苏、璇 passive.relay、10321、10335（治疗系数）、10336、10339、10358、10359、10361、10362 的字头改成新源写法（受赠消耗、追加伤害、护盾系数、技能倍率、物防魔防共享、触发加快等；10359 换成贯日／敕令倍率、盾形态受到伤害、目标伤害降低四行）。新源另加的 **10326** 一行（护盾系数 20%／保底 13.1%，数值与重制不同）按派单只列不改，归角色车道。
- **DOM 面板参照重取**（第二棒）：新写 `ui_reference/dom_ref.cjs`（只读服务＋本机无头 Chrome，在 `?battle_ref=1` 页面里执行一个取数脚本，结果写到给定文件）和两份页面脚本：
  - `gear_search_ref.js`：内存新局，背包按旧夹具的 21 件模板各得一件（得装备时随机数固定 0.5，不出随机词缀；带 `<Prefixes>` 的取再生成的那件），名字／描述／能力照旧夹具覆盖，备注用新源实例自己的；面板「仅背包」逐项操作读 sorts／cats／queries／quality／type／term／small／detail／itemList。v0.28 上重跑与旧手量夹具**逐键相同**。新源上变的不止死霸装：解放前的斩月、麒麟对剑两把、绣冬、贽殿遮那、真我之钥、斩月、斩月-虚、花与鸟之矢、队员死霸装 10 件模板都改了（专武成长、数值×10、KyoUnique 等），备注随之换新；`gear_search_oracle.json` 重出。
  - `power_panel_ref.js`：队伍 1/2/23/85，状态页 openPower，读 #cq-modal 带文字的元素（自身文字节点）与工具条按钮、面板／详情／底栏框。v0.28 上与旧手取逐行同文字、坐标差 ≤0.52（strong 行内框）；新源读数文字与 v0.28 完全相同；`power_panel_oracle.json` 重出。
- **DL 单（第二棒）**：
  - 状态页（`status_page_oracle.json`）、修行页（`zhenqi_page_ui_oracle.json`）夹具在 v0.62.12 无头重取：新页面脚本 `ui_reference/status_page_ref.js`（包住 drawText／drawFace／drawIcon／drawGauge／drawHorzLine 记调用；条的填充宽取实际画的渐变条宽，YEP 描边时少 2；可选 pageList／variables／zhenqi 与逐屏滚动）。v0.28 上重跑与两份旧手量夹具逐键相同。
  - 状态页测试：选页窗 5 项（240／252）改成直接比夹具（项矩形、光标、文字），不再按 Window_HorzCommand 公式推；v0.28 的 4 项常量另断言。
  - **武器类型加成「生效／未持有」**（`XStatusPage.WTYPE_HOLD_V041`，默认开，**O-待定·武器类型生效**，已写进优化登记）：新源 installEquipmentDetailV041Runtime 包 calcWeaponBonus，加成后缀「 生效」（isWtypeEquipped，用 `XBattleLogic.wtype_equipped`）／「 未持有」；重取的夹具第 2 页因此挂 4 项，已跟。
  - 修行页测试：抬头、文字行起点、表头四列改比新源第 5 页「修行·详细」（「项目／难度影响／不含难度／实际」），另比橙色 warn、第 4 页抬头 panelHead；旧一页写法的四列位置照同一份夹具比。
  - growth_help：心钢／狂妄说明卡也按品质排特效行（原版 H.describe 末尾调 RJO.HE.getDescParams，v0.41 排序在里面），放在 `XGrowthHelp.rows` 分组之前，挂在 `EFFECT_SORT_V041` 下（O-待定·特效排序，这次也补进优化登记）。测试 `fix.*` 段自 v0.43 起找「成长：」行越界（行首多了 `\lock[1]`），一直没跑到断言、只报 SCRIPT ERROR；改成去掉 lock 再找，外层包装的装备战力／穿透行另核。现在 77/77、无 SCRIPT ERROR。
- **DL ③ 心钢技能说明卡**（第三棒，`XGrowthHelp.skill_view`，跟 `XHeartsteel.TURN_CD_V035`，O-待定·心钢按回合冷却，关＝v0.28 没有这张卡）：照新源 H.skillHelpView（Window_BattleSkill／Window_SkillList.updateHelp 包装），巨人吞噬 10227／利维坦 10228 的说明卡换成深拷贝，备注 APs 行全删、重写：目标／命中／消耗、伤害（按角色身上对应的心钢／利维坦的阶，没装或装的是另一件就按原件）、战斗中「状态：巨人吞噬已就绪／冷却，还需 n 回合／蓄力，还需 n 回合」、效果／条件「第2回合起可用」／冷却 2 回合。拷贝标 `skill_copy`，元素包装不插技能的伤害属性（同原版 isSkill 为假）。战斗技能窗 `battle_scene._help`、技能页 `skill_scene._update_help` 接上。参照：`growth_help_probe.cjs` 加 `skills` 11 例（v0.62.12 量），`growth_help_oracle.json` 只多 `skills` 一键（cases／powerOnly 不变）；`xiyou_growth_help` 逐行比文字／字号／颜色／对齐／y／卡高，另断言开关关时原样返回。顺手修测试里卸装写成 `change(…, {})`（实际不卸，`{}` 在背包里找不到）→ `null`。
- **zhenqi page.* 12 项**（第三棒，不改代码）：集成分支 `generated/oracle/zhenqi.json` 的 6 个 `page.*` 用例是探针加「修行·详细」（0250eacc）之前出的，没有 `detail`；本机用 v0.62.12 重跑 `zhenqi_probe.cjs`（24 分钟），只这 6 例变了、多出 `detail`，换上后 `xiyou_zhenqi` 200/200。第二次同步重出 zhenqi.json 后自然消失（同步后复查一眼 `page.default` 有 `detail`）。
- **流萤技能卡**（第三棒，总装追加：流萤运行时清单 13、15；先合了 `cc/wukong-newsrc9` fd0f53b4，冲突只在优化登记两边各加的行，全留）：
  - 15 说明按进阶生成：新 `ui/liuying_help.gd`（`XLiuyingHelp`，照 L.skillLines／refreshText）：10622 天火轰击、10623 完全燃烧按流萤（179）当前进阶重写备注 APs 行（2 阶起天火 8 段；完全燃烧 3 阶冷却 3 回合、加 33% 不进冷却、去掉「消耗：当前全部护盾」、效果改增盾上限 50%；2 阶前加「解锁：进阶2阶」）。接在 `XHelpCard._content` 开头，只改出卡用的拷贝（原版改 $dataSkills，看的也是 179 的阶，结果相同）。原版流萤的 setItem 包装在元素包装之内，会把元素包装删插的「伤害属性」行冲掉，卡上留备注写法「伤害属性：火焰·物理」；照搬（这两张卡跳过 `_element_wrapper`）。新源行为，不设开关。
  - 13 技能名品质色：重制技能页／图鉴的名字本来就按 `XQuality.list_color`（品质）上色，与包装的 QualitiesColor[品质] 逐个相同（14 个技能），不用改；专项里断言。战斗技能窗照旧白字（重制原有口径）。
  - 没跟：10623 三阶清空 customCostText——重制技能列表还没有 `<Custom Cost Display>`（所有技能都没有，不只流萤），列表右侧只画 MP／TP／HP 等，另算一项。
  - 参照：新探针 `mv_oracle/liuying_help_probe.cjs`（进阶 0、1、2、3、再回 0 各量两张卡＋14 个技能名颜色），`tests/fixtures/liuying_help_oracle.json`，新专项 `xiyou_liuying_help` 34/34。
- **参照**：`ui_reference/review_actor_book.js` 多记 `bitmap`（状态窗实际画的图，URL 末段）；上一棒在新源重取时 `sprite` 记的是 battlerName，168、173～177 的逐帧图因此对不上。`actor_book_oracle.json` 只补了 `bitmap` 一键（其余与重取的一致），测试改为图名比 `bitmap`、battlerName 比 `sprite`。
- 测试：`xiyou_actor_book` 跟目录换算（`index_ids().find`）、立绘几何乘 bookScale、截图加 179；`xiyou_actor_book_review` 记 `actor_id()`；`xiyou_help_card` 的 O-049 出售价断言改成量排版之前的行（v0.43 排版把两种价格并成一行两列，原断言一直挂）。

## 交接板

- 下一步：
  - 179 流萤的战斗图 `Codex_Liuying_SV` 在本单产物里没导出，`xiyou_actor_book` 只挂这一项；悟空 `cc/wukong-newsrc9`（54ae6b10）已补切片，合进来重同步即过。
  - help_card 10326「成长：」行（角色车道）。
  - help_card 10622／10623（流萤技能卡按进阶阶数生成说明）：等第二次同步后按实际挂的对。
  - 总装失败表里的界面项（候选 hud、party、hangup、hangup_options、item_bag）。
- 用户试玩说明：人物图鉴的目录里看不到 7 个隐藏角色；带光环的角色状态页分四列；流萤在图鉴里能看到技能表。装备说明卡的特效行按品质从高到低排。谷雨、屠苏、璇技能说明的「成长：」用新写法。
- 需要用户决定：无。

## 优化登记

- O-待定·心钢按回合冷却（已登记，悟空 newsrc8）：总装合并时把「技能说明卡」补进该行：位置加 `ui/growth_help.gd` `skill_view`，新行为加「技能说明卡照 H.skillHelpView 带就绪／冷却／蓄力状态行」，关＝没有这张卡（同 v0.28）。测试 `xiyou_growth_help` 的 `skill.*` 与 `skill.v028`。

- O-待定·武器类型生效：`XStatusPage.WTYPE_HOLD_V041`（关＝只写百分比），测试 `xiyou_status_page` `wtype_hold_switch`。已写进 `00_设计/优化登记.md`（连同特效排序）。

- O-待定·特效排序：`XHelpCard.EFFECT_SORT_V041`（关＝不排序），测试 `xiyou_help_card` 的 gear 段（v0.62.12 参照）。是跟新源的显示改动，开关只为回退。

## 接续要点（给下一位）

1. **gear_search 重量**：已做（第二棒，见变更草稿「DOM 面板参照重取」）。本机 `xiyou_gear_search` 60/60。
2. **status_power_panel**：`power_panel_oracle.json` 已重取；本机只挂 `coverage_all_actors` 的 179「天火轰击」（原版记「当前条件不可用」，重制记成未完整评估，归角色车道／悟空 DF）。
3. **pets**：本分支云端 `xiyou_pets` 通过（上一棒已在新源重取核过，夹具不用换）。
4. **④ 界面失败项认领**：总装还没发整轮失败表，未认领。候选 hud、party、hangup、hangup_options、item_bag。
5a. **DL ③ 心钢技能说明卡**：已做（第三棒，见变更草稿）。
5b. **zhenqi page.* 12 项**：已查（第三棒）：参照旧，不是代码问题；第二次同步后复查。
5c. **还是手量／v0.28 的界面夹具清单**（DL ① 要求列）：
   - 已有按钮页面脚本、可直接用 `headless_button.cjs` 在新源重取：actor_advanced、actor_warehouse、battle_costume、star_warehouse、warehouse（review_system_pages.js）。
   - 已有自己的驱动（加 XIYOU_APP／参数即可）：battle_transition（battle_transition_ref.cjs）、popup_anchor（popup_anchor_ref.py）。
   - 页面里手点或手敲 JS 量的，可写 dom_ref 页面脚本（调现成的 `__ilr`／`__dhRef`）：item_list、orb_ui、orb_shop_ui、shop_stock_ui、save_page（要 localStorage 存档两份，临时 Chrome 目录里可做）、window_rects、drop_dh、enemy_state_icon、state_overlay、status_power（战力条 fillRect／drawText，照 status_page_ref 的包法）。
   - 故意留 v0.28 的：zhenqi_page_rows_v028（PANEL_V062 关的回退参照），不重取。
5. **help_card 10622／10623**：说明按阶生成已做（第三棒，`XLiuyingHelp`，新源 0～3 阶逐行对上）。第二次同步出了含 179 的 help_cards 参照后再跑一次 `xiyou_help_card` 确认（参照是新局 0 阶）。
5d. **m234 五个预设**：`事件空绿扫描.py --check` 仍报 m234e22／e26／e45／e46／e49 的 `#a1`「event_states.json 没量」，产物来自同步之前；第二次同步完成、重克隆产物后复跑即可（不是本单改动）。
6. 集成分支同步完成后：重克隆 `generated/` 等，重跑 `云端选测.py upload`，再复测本单场景与 `事件空绿扫描.py --check`。

## 可优化（流程／工具／效率）

- 已做：`ui_reference/dom_ref.cjs` 通用 DOM 取数驱动（页面脚本是一个 async 函数，返回 JSON），以后 #cq-modal 一类 DOM 面板的参照都可以无头重取，不再浏览器手量（回退＝删三个文件，夹具不受影响）。
- 已做：`review_actor_book.js` 记 `bitmap`（回退＝删那三行，夹具多一键无害）。
- 建议：`云端选测.py` 的 workflow_dispatch `scenes` 要写 `.tscn` 后缀，不写时计划步骤把场景全滤掉、静默跳过（本单第一次因此白跑）。plan 遇到交集为空时报错、或自动补后缀（工具车道，省一次空跑）。
- 建议：本机测试槽被同步（4 槽）占几个小时时，车道只能走云端；`并行测试.py` 排队时可提示「共用槽被同步占用，预计 X 分钟，可改云端」。

## 验证

- DL（提交见本分支，本机，产物克隆自集成树 21cd90eb）：`xiyou_status_page` 47/47、`xiyou_growth_help` 77/77、`xiyou_gear_search` 60/60；`xiyou_help_card` 只挂 10326（角色车道）；`xiyou_status_power_panel` 只挂 179 天火轰击；`xiyou_zhenqi` 本单的 page_ui_* 全过，仍挂 page.* 12 项（失败表原有，见接续 5b）。`语法检查.py` 通过；`回退开关覆盖.py` 没报本单两个开关（缺口只有 O-209，人工确认几项都是旧的）。


- 第二棒（提交 4e0c7e5d，本机，产物克隆自集成树 21cd90eb）：`xiyou_gear_search` 60/60；`xiyou_status_power_panel` 10/11（只挂 179 天火轰击，角色车道）。`语法检查.py` 通过；`事件空绿扫描.py --check` 同上一棒（空绿 96 在基线内，m234 五个预设没量，产物克隆于同步前）。


- 云端（workflow_dispatch 指定场景，提交 c1291188，运行 42249644555，33 个场景＝`选测.py cc/newsrc-switch --list` 24 个＋gear_search、status_power_panel、inlay_book、tusu_ui、xuan_bind、xuan_chart、guyu、equipment、item_bag）：挂 8 个。
  - 本单的：actor_book（「确认查看全部」颜色，已改；179 立绘缺图，见上）、help_card（3 件装备特效与穿透行先后，已改；O-049 断言，已改；10326 只列）。
  - 待重量：gear_search（3 项，见接续 1）、status_power_panel（只剩 179，角色车道）。
  - 集成分支上同样挂（7520680b 整轮失败表里也有，复核见下）：equipment（affix_revert_reference_present）、item_bag（tp.consumable.menu）、event_compare、growth_help（41/41 但有 SCRIPT ERROR）。
  - 复测（提交 5af0bac2，运行 42250947313，9 个场景）：actor_book 21/22（只剩 179 立绘缺图，待合 wukong-newsrc9）、help_card 1072/1073（只剩 10326，角色车道）；cat_help、demon_crown、weak_challenge、inlay_book 通过。
  - 集成分支 21cd90eb 同场景对照（运行 42250982942）：equipment（data_identity、affix_revert_reference_present）、item_bag（tp.consumable.menu）、event_compare、growth_help 一样挂，不是本单引起；help_card 在集成分支挂 13 项（成长措辞 11、3 件装备排序），本分支降到只剩 10326。
- `事件空绿扫描.py --check`：空绿 96 在基线内；另报 5 个预设用例「event_states.json 没量」，是产物克隆于同步之前（八戒三的预设已合、产物还没跟上），重克隆后复跑。
- `语法检查.py`：通过。

- 第三棒（本机，产物克隆自集成树 21cd90eb，合 wukong-newsrc9 后按 v0.62.12 重跑转换器＋导入；zhenqi.json 用本机新源重跑的）：`xiyou_growth_help` 101/101、`xiyou_liuying_help` 34/34、`xiyou_help_card` 1073/1073、`xiyou_actor_book` 22/22、`xiyou_zhenqi` 200/200、`xiyou_liuying` 144/144、`xiyou_liuying2` 188/188、`xiyou_liuying3` 50/50、`xiyou_heartsteel` 676/676、`xiyou_battle_ui` 155/155、`xiyou_skill_page`、`xiyou_cat_help`、`xiyou_character_help_cost`、`xiyou_status_power_panel` 11/11 全过；合并前另跑过 `xiyou_battle_log`、`xiyou_black_flash_ui`、`xiyou_determinism` 372/372、`xiyou_list_paging`、`xiyou_skill_mastery` 全过。`xiyou_skill_menu_events` 10/10 但有 SCRIPT ERROR（mv_interpreter 调已释放的对象），去掉本单改动（f4daf906 两个文件）一样有，不是本单引起。`选测.py` 列 118 个（battle_scene 一行改动带出整片楼层／地图场景），没全跑：改动只是技能说明卡的入口（只对 10227／10228 换卡），楼层与地图事件不经过它。`语法检查.py` 通过。`事件空绿扫描.py --check`：空绿 96 在基线内，另报 m234 五条没量（见接续 5d）。

## 待交叉核查

- 第三棒：`ui/growth_help.gd`（`skill_view`、`damage_text`）、`ui/help_card.gd`（skill_copy 标记、XLiuyingHelp 接入、流萤跳过元素包装）、`ui/liuying_help.gd`、`battle/battle_scene.gd` `_help`、`ui/skill_scene.gd` `_update_help`、`mv_oracle/growth_help_probe.cjs`（skills）、`mv_oracle/liuying_help_probe.cjs`、`tests/xiyou_growth_help.gd`（_skill）、`tests/xiyou_liuying_help.gd`、两份夹具。
- DL：`ui_reference/status_page_ref.js`、`ui/status_page.gd`（WTYPE_HOLD_V041）、`ui/growth_help.gd`（rows 里排序）、`tests/xiyou_status_page.gd`、`tests/xiyou_zhenqi.gd`（_page_ui）、`tests/xiyou_growth_help.gd`（_fixed）、两份夹具。
- 第二棒：`ui_reference/dom_ref.cjs`、`gear_search_ref.js`、`power_panel_ref.js`，`tests/fixtures/gear_search_oracle.json`、`power_panel_oracle.json`（重出）。
- `ui/actor_book.gd`（index_ids、actor_id、_aura_columns、is_aura_note、179 技能、BOOK_SCALE）、`core/appearance.gd`（Codex_Liuying_SV 档）、`ui/help_card.gd`（sort_effects、_plain41、调用位置）、`ui/character_help.gd`（成长措辞）、`ui_reference/review_actor_book.js`（bitmap）、`tests/fixtures/actor_book_oracle.json`（只加 bitmap）。

## 本分支提交

- 见 `git log 21cd90eb..cc/ui-newsrc3`
