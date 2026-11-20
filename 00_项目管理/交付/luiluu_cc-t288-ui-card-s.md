# 交付：luiluu/cc-t288-ui-card-s

- 车道／工作者：cc（Opus＋medium，P8），T288 新界面卡 S：长说明卡分节
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T288·未经审查】新界面卡 S：长说明卡分节（dev.待定）

- 依据：私密设计仓 `重制设定/界面风格提案_v0.7/T254_剩余页细节设计.md` 第四节 4.1、卡 S；6批-1（分节）、6批-2（看完整说明）Kyo 未改，按稿默认做。
- `ui/help_card.gd`：`XHelpCard.section_tags(rows, obj)` 给 content()／detail_rows() 的每一行算节标记（head／desc／base／info／formula／growth／now／effect／affix／price／gap）；`skin_card_data(rows, obj)` 把行变成详情牌（牌头、两列格子、带小标题的节）。行的字、次序、代入的数一律不动（content() 输出没变，旧专项不受影响）。新界面下浮动说明卡（战斗「详情」、还在用旧浮动卡的页）改用 XSkinCard 分节画；开关 `XHelpCard.SECTIONS`（关＝旧画法）。
- `ui/skin/skin_card.gd`：分节多 `cells`（两列「名 值」）、行的 `dim`、节的 `size`；`fold` 开时放不下：牌底字渐淡＋「Y 看完整说明 ▾」，按 Y 或点这一条向左展开成 2 倍宽、整高（`expand_bounds`），再按 Y／点一下／取消收回；展开后还放不下能滚（拖、滚轮、上下键，右边细滚动条）；换牌自动收起。fold 关（默认）时画法同旧。
- `ui/character_help.gd`、`growth_help.gd`、`liuying_help.gd` 只加节标记常量／函数（`SECTION_BY_CODE`、`section_of`／`SECTION_NOW`／`SECTION_GROWTH`、`LOCKED_ROW`），不改行文。
- `ui/skin/skin_skill_page.gd` `_sync_card`（协调准，选项 A）：右牌改用分节＋fold；保留本页「类型 · 消耗」小字；SECTIONS 关时一字不变。
- 专项 `xiyou_help_card_sections`（新，31 项）；工具场景 `t288_card_shots`（截图，不是专项）。
- 玩家可见：天启篇新界面里，技能页右牌和战斗「详情」说明卡按「基本信息／伤害怎么算／成长／效果／这一场」分节；太长时牌底写「Y 看完整说明」，按 Y 或点一下展开。

## 交接板

- 下一步：小A 审「文字」节的新字；卡 H、卡 P 接 skin_card（见「给后续卡」）。
- 用户试玩说明：天启篇存档、新界面开着：技能页选一个长技能（如流萤天火轰击），右牌底部「Y 看完整说明」，按 Y／点一下展开、再按收回；战斗里战技列表点「详情」看说明卡。
- 需要用户决定：无

## 文字（玩家可见新字，待小A 审）

- 节小标题：「基本信息」「伤害怎么算」「成长」「效果」「这一场」（「自带」「词条」沿用已有）
- 牌底：「Y 看完整说明 ▾」（触屏：「看完整说明 ▾」）；展开后：「Y 收起 ▴」（触屏：「收起 ▴」）

## 给后续卡（卡 H、卡 P 接 skin_card）

- 喂说明卡的行：`var d := XHelpCard.skin_card_data(XHelpCard.content(obj, kind, false, 宽) 或 detail_rows(obj, 宽), obj)`，得 `{title, title_color, icon, subtitle, desc, sections}`；页面自己有小字就覆盖 `d.subtitle`，再 `card.fold = true; card.setup(d)`（或 set_card 把 desc、sections 带上）。
- 节的格式：`{title, tag, size, rows: [{text, color, dim}]}` 或 `{title, tag, size, cells: [[名, 值], …]}`；tag 是 `XHelpCard.SECTION_ORDER` 里的名字；只要标记不要排法用 `XHelpCard.section_tags(rows, obj)`。
- XSkinCard 新接口：`fold`、`expand_bounds`（画布坐标上下沿，默认 TOP／BOTTOM）、`expand_wide`（false＝展开不加宽，战斗详情用）、`border_color`、`natural_height(宽)`、`can_expand()`、`set_expanded()`、`expanded_rect()`、`strip_rect()`、`scroll_by()`、信号 `expanded_changed`。Y 在 `_input` 里收（只在 fold 且放不下或已展开时；Y 一律不放行给页面），展开时确定键也收下不落到列表；fold 由真切假时展开自动清掉；页面别的地方也用 Y 的（如装备页）开 fold 前要先看冲突。
- 物品页、装备页（`skin_item_page`／`skin_gear_detail` 的 `help_sections`）本卡没动，仍是 CORE_V2 的「自带／词条／套装／说明」。

## 小A 核查返修（P2×3）

- P2-1：见上「浮动卡战斗里」；`skin_card.gd` 加 `expand_wide`、`_input` 里 Y 一律收下、展开时收下 `ui_accept`；`help_card.gd` 战斗里设 `expand_wide=false`，去掉 `y_pass_on_collapse`。提示字「Y 收起 ▴」不改。
- P2-2：`XSkinCard.setup` 里 fold 为假时清 `_overflow`、展开的牌收掉（`_sheet` 藏起），Y／取消回到页面。
- P2-3：专项节标记覆盖改成全库：技能 7008、武器 1123、防具 2305、物品 2363（共 12799 条）0 错，整个专项 25 秒，不用分段。
- 新断言：fold.accept_swallowed、fold.y_not_passed、fold.accept_passes_when_collapsed、fold_off.clears_expanded、battle.no_widen（专项 35/35）；拿掉对应修法逐条反向验证过，都会挂。

## 给卡 H／P 的 P3（小A 核出，本卡没改）

- P3-1：`help_card.gd` `skin_card_data` 的 `title_color` 用 `XQuality.list_color`，没走 `XUiSkin.quality_color`；页面接时按页面自己的名字色覆盖（技能页 T287 已用 name_color）。
- P3-2：`skin_card.gd` `_draw_sheet` 的底部渐淡用上一帧的 `_max_scroll`，刚展开第一帧可能判错是否在底（视觉小瑕疵）。
- P3-3：`help_card.gd` 纯治疗／护盾技能的公式行也落进「伤害怎么算」节（标题字面不准，可考虑按行首「基础治疗／基础护盾」改叫「怎么算」，要小A 定字）。
- P3-4：`skin_card.gd` 牌头小字（subtitle）超宽直接截断，没换行也没省略号。

## 没做／偏离

- 「消耗行进牌头小字」：没挪。消耗和别的施放信息常在同一行（`段数：1\col[50]消耗：…`），拆行会动行的内容；技能页小字本来就有消耗，基本信息里仍留一格。
- 「伤害怎么算」后的灰字「＝现在 ×4.48」：没做（要新算数，派单说代入的数不动）。
- 「还没到」注明：只有流萤「解锁：进阶N阶」这类行画暗字（TEXT_3），没加「还没到」字样（currentHelpText 已把没到阶的分支去掉，留下的只有流萤这一种）。
- 节的次序按稿（基本信息→伤害怎么算→成长→效果；装备 自带→成长→这一场→词条），行在各节里保持原先后；原 v0.43 排版里「效果」在「成长」前，稿里反过来，按稿。
- 「右下胶囊也能点」：没单独画胶囊，牌底整条可点。
- 浮动卡战斗里（小A核 P2-1 返修）：展开只在详情卡自己那一栏往上下长、不加宽（`expand_wide=false`，卡已是最高时就是在原处滚动），不盖住战技列表和角色；Y 只做展开／收成小卡，不再顺带关「详情」；展开时确定键被牌收下，防误放技能。副作用：说明卡放不下时，键盘 Y 关不了「详情」（点「详情」胶囊照旧关；放得下的卡 Y 照旧开关详情）。另：520 宽的卡（如天火轰击）在战斗里本来就被 place_near 放到列表右边、压住列表右侧消耗列和队伍栏一角——这是旧摆法（新旧画法一样），本卡没动，留给战斗界面卡看。
- 截图里技能页、独立牌那几张是非天启篇存档的技能行（天启篇技能重构会改写部分专属技能的行，比如渡鸦 10122 天启篇下没有成长行）；战斗那张是天启篇存档。
- 与 T287（卡 E）在 `skin_skill_page.gd` `_sync_card` 相邻行：本卡只改 rows 行与 set_card 第二行（desc／sections），`title_color` 那行没碰；合并时保留 T287 的 `name_color`。
  交付时 T287 只在本机 main（74af966bc，dev.782）、还没到 github/main，照协调只合了 github/main；交付自检对本机 main 试合并报这一处冲突（只有一块）。解法：取本卡的 help／rows／split／sd／card.fold 几行，set_card 第一行用 T287 的 `"title_color": name_color(sk),`，第二行用本卡的（带 `"desc"` 和 `sd.sections if split else …`）。

## 验证

- 选测：`选测.py main --list` 列出的 44 个 xiyou_* 场景全跑（并行 2，681 秒）：41 过；`xiyou_ui_skin_4b` 的 help_card_skin_new 是本卡引起（分节路径不经 _paint，画布 clean_text 没设），已修（_apply_sections 设上）；`xiyou_battle_ui`（action_log_shown）、`xiyou_pets`（退出时对象泄漏）两轮都在并行负载下失败，单独重跑都过——我猜是负载偶发，没在 github/main 上对照跑过。
- 合 github/main（37f246709）后重跑 11 个：xiyou_help_card_sections 31/31、xiyou_help_card、xiyou_growth_help、xiyou_liuying_help、xiyou_character_help_dyn、xiyou_character_help_cost、xiyou_skill_page、xiyou_ui_skin_1b、xiyou_ui_skin_4b、xiyou_ui_skin_battle、xiyou_battle_ui 全过。
- 各 xiyou_*_help 专项一行没改（content() 输出不变）；`工具回归.py` 全过；`语法检查.py` 0 问题；`发行空壳.py check` 718 个函数都有。
- 回退：`XHelpCard.SECTIONS=false` 时浮动卡旧画法、技能页右牌一节无标题且行＝help_rows（专项 float.off_old、page.off.unchanged）；皮肤关时不分节（float.skin_off_old）。
- 截图：`03_再刷重制_Godot/04_验证/本地结果/T288_截图/`（本机，不入库；`*_s.png` 是 800×450）。重出：`godot --audio-driver Dummy --path 01_Godot工程 res://tests/t288_card_shots.tscn -- --out=<目录>`（战斗两张分别 `--only=09old`／`--only=09new`）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log（T288 WIP 与交付提交）
