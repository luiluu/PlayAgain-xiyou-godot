# 交付：cc/ui-newsrc3（换源追平界面第四段：人物图鉴、说明卡特效排序与成长措辞）

- 车道／工作者：界面 DE（cc）
- 状态：可合并
- 说明：到 40% 交接线停手；①② 已做，③ 只核了 pets、status_power_panel，gear_search 重量与 power_panel 重取、④ 认领未做（见「接续要点」）。交回集成分支 `cc/newsrc-switch`（不合 main）。
- **合并顺序**：先合 `cc/wukong-newsrc9`（54ae6b10，切片加 179，导出流萤 SV／脸图／行走图），再合本单并重同步；否则 `xiyou_actor_book` 的 179 立绘一项会挂。
- 依据：派单第十四批 DE 节＋协调追加的 gear_search 三项。从 `cc/newsrc-switch` 21cd90eb 切。
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
- **参照**：`ui_reference/review_actor_book.js` 多记 `bitmap`（状态窗实际画的图，URL 末段）；上一棒在新源重取时 `sprite` 记的是 battlerName，168、173～177 的逐帧图因此对不上。`actor_book_oracle.json` 只补了 `bitmap` 一键（其余与重取的一致），测试改为图名比 `bitmap`、battlerName 比 `sprite`。
- 测试：`xiyou_actor_book` 跟目录换算（`index_ids().find`）、立绘几何乘 bookScale、截图加 179；`xiyou_actor_book_review` 记 `actor_id()`；`xiyou_help_card` 的 O-049 出售价断言改成量排版之前的行（v0.43 排版把两种价格并成一行两列，原断言一直挂）。

## 交接板

- 下一步：
  - 179 流萤的战斗图 `Codex_Liuying_SV` 在本单产物里没导出，`xiyou_actor_book` 只挂这一项；悟空 `cc/wukong-newsrc9`（54ae6b10）已补切片，合进来重同步即过。
  - help_card 10326「成长：」行（角色车道）。
  - gear_search、status_power_panel 的 `power_panel_oracle.json` 要在新源重取，见接续要点。
- 用户试玩说明：人物图鉴的目录里看不到 7 个隐藏角色；带光环的角色状态页分四列；流萤在图鉴里能看到技能表。装备说明卡的特效行按品质从高到低排。谷雨、屠苏、璇技能说明的「成长：」用新写法。
- 需要用户决定：无。

## 优化登记

- O-待定·特效排序：`XHelpCard.EFFECT_SORT_V041`（关＝不排序），测试 `xiyou_help_card` 的 gear 段（v0.62.12 参照）。是跟新源的显示改动，开关只为回退。

## 接续要点（给下一位）

1. **gear_search 重量**（协调追加）：`tests/fixtures/gear_search_oracle.json` 是 v0.28 浏览器手量，背包 21 件实例的名字／备注／能力照搬进重制；第 20 件「队员死霸装」的实例备注是 v0.28 的（闪避、爆伤 5%），新源防具 130 模板已是 50%（备注与 traits 都改了），所以 detail 判成「随机 / 附加」、战力 2400 对 1410，挂 sort_power、row_small_power、detail_rows 三项。要在新源上按同样 21 件（实例名、备注、描述、能力照夹具覆盖，第 20 件备注换新模板的）打开「装备词条检索」面板（仅背包）重读 sorts／cats／queries／quality／small／detail 等。没有现成驱动：可照 `review_actor_book.js`＋`headless_button.cjs`（`?battle_ref=1&…`）写一页，DOM 读法照夹具 `source` 说明。
2. **status_power_panel**：`power_coverage_oracle.json` 上一棒已重取；`power_panel_oracle.json` 还是 v0.28 DOM 手取（#cq-modal 带文字元素的 [标签, class, 文字, x, y, 宽, 高]），新源上照样过，派单要求重取，同样缺驱动（可与 1 共用一个 CDP 取 DOM 的脚本）。该场景现在只挂 179「天火轰击」（角色车道）。
3. **pets**：本分支云端 `xiyou_pets` 通过（上一棒已在新源重取核过，夹具不用换）。
4. **④ 界面失败项认领**：总装还没发整轮失败表，未认领。候选 hud、party、hangup、hangup_options、item_bag。
5. 集成分支同步完成后：重克隆 `generated/` 等，重跑 `云端选测.py upload`，再复测本单场景与 `事件空绿扫描.py --check`。

## 可优化（流程／工具／效率）

- 已做：`review_actor_book.js` 记 `bitmap`（回退＝删那三行，夹具多一键无害）。
- 建议：`云端选测.py` 的 workflow_dispatch `scenes` 要写 `.tscn` 后缀，不写时计划步骤把场景全滤掉、静默跳过（本单第一次因此白跑）。plan 遇到交集为空时报错、或自动补后缀（工具车道，省一次空跑）。
- 建议：本机测试槽被同步（4 槽）占几个小时时，车道只能走云端；`并行测试.py` 排队时可提示「共用槽被同步占用，预计 X 分钟，可改云端」。

## 验证

- 云端（workflow_dispatch 指定场景，提交 c1291188，运行 42249644555，33 个场景＝`选测.py cc/newsrc-switch --list` 24 个＋gear_search、status_power_panel、inlay_book、tusu_ui、xuan_bind、xuan_chart、guyu、equipment、item_bag）：挂 8 个。
  - 本单的：actor_book（「确认查看全部」颜色，已改；179 立绘缺图，见上）、help_card（3 件装备特效与穿透行先后，已改；O-049 断言，已改；10326 只列）。
  - 待重量：gear_search（3 项，见接续 1）、status_power_panel（只剩 179，角色车道）。
  - 集成分支上同样挂（7520680b 整轮失败表里也有，复核见下）：equipment（affix_revert_reference_present）、item_bag（tp.consumable.menu）、event_compare、growth_help（41/41 但有 SCRIPT ERROR）。
  - 复测（提交 5af0bac2，运行 42250947313，9 个场景）：actor_book 21/22（只剩 179 立绘缺图，待合 wukong-newsrc9）、help_card 1072/1073（只剩 10326，角色车道）；cat_help、demon_crown、weak_challenge、inlay_book 通过。
  - 集成分支 21cd90eb 同场景对照（运行 42250982942）：equipment（data_identity、affix_revert_reference_present）、item_bag（tp.consumable.menu）、event_compare、growth_help 一样挂，不是本单引起；help_card 在集成分支挂 13 项（成长措辞 11、3 件装备排序），本分支降到只剩 10326。
- `事件空绿扫描.py --check`：空绿 96 在基线内；另报 5 个预设用例「event_states.json 没量」，是产物克隆于同步之前（八戒三的预设已合、产物还没跟上），重克隆后复跑。
- `语法检查.py`：通过。

## 待交叉核查

- `ui/actor_book.gd`（index_ids、actor_id、_aura_columns、is_aura_note、179 技能、BOOK_SCALE）、`core/appearance.gd`（Codex_Liuying_SV 档）、`ui/help_card.gd`（sort_effects、_plain41、调用位置）、`ui/character_help.gd`（成长措辞）、`ui_reference/review_actor_book.js`（bitmap）、`tests/fixtures/actor_book_oracle.json`（只加 bitmap）。

## 本分支提交

- 见 `git log 21cd90eb..cc/ui-newsrc3`
