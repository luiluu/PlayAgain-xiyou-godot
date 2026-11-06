# 交付：cc/ui-newsrc1（换源追平：B 界面 18 个＋说明卡新排版）

- 车道／工作者：界面 CV（cc）
- 状态：**进行中（到 40% 交接线停手），交回集成分支 `cc/newsrc-switch`（不合 main，不标可合并）**。第一段：分类表＋数据／文案类追平；第二段：总装二十七批了三项改版，①说明卡已做，②③未动（见「接续要点」）。中途合了集成分支 3ac4cc74。
- 依据：派单第十四批 CV 节、`cc_newsrc-switch.md` 失败表「三」B 界面 18 个。从 `cc/newsrc-switch` 81cfd9af 切。
- 工作树 `.claude/worktrees/ui-newsrc1`：`generated/`、`.godot`、`mv_oracle/.sandbox` 用 APFS 克隆自集成分支工作树（新源产物，manifest v0.62.12，同提交 81cfd9af，未重跑同步）；跑测试带 `--skip-generated-check`。探针一律 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 分类表（本机 81cfd9af 上 18 个全部复现）

| 场景 | 现象 | 类 | 状态 |
|---|---|---|---|
| sve_visual | 敌人普查数 2000→2027、SV 186→202、呼吸 1814→1825、武器 44／刺 142→50／152；逐行规则全对 | 普查数 | ✓ 已追平 |
| vsfx | 新状态 2756「道翼」带动画 994 | 普查数 | ✓ 已追平（加 id.2756、anim994） |
| change_clothes | 神话角色 64→65（新角色 179 流萤）；原版参照 v0.28 | 普查数＋参照重取 | ✓ 已追平（`review_system_pages` 在新源重取 12 张） |
| costumes | 夹具 v0.28 | 夹具重出 | ✓ `costume_probe` 新源重出 |
| inlay_book | 原版参照 v0.28；另原版 v0.43 把「全武器伤害+N%」显示成「装备武器时，技能伤害+N%」 | 参照重取＋文案 | ✓ 重取（`--inlay-all`＋4 张）；`XHelpCard._terms` 跟 `installEquipmentDetailV041Runtime` 的 CodexDisplay.text |
| guyu_ui | 归根／待绽／生长→替倒／待发／平时；赠春／还春→交出储备／收回储备；给出说明改写 | 文案 | ✓ 已追平（只改文字） |
| options_basic | 设置页多「Boss状态面板」一行 | 开关翻转 | ✓ O-204 `XBossStatusPanel.TOGGLE` 翻成 true（集成分支；回退改回 false），boss_status 测试同改 |
| growth_forge | 夹具 v0.28；新源狂妄原件备注写「物理伤害忽略18%」，原版开机时 U.describe 才改成「物防穿透18%」 | 夹具重出＋移植缺口 | ◐ 夹具重出；`XDB.table("Armors")` 开机对四件成长装备原件做 describe（原版 isDatabaseLoaded 包装，v0.28 起就有，只是旧数据看不出）。**剩 forge.0 心之钢 6 项：v0.35 巨人吞噬改成「第 2 回合可用、冷却 2 回合」（按回合，不再按行动次数），是战斗机制，归 C** |
| status_power_panel | 角色 148 技能改名「碧天独行」等；两份夹具是 v0.28 浏览器手取、无脚本 | 参照重取 | ○ 待做（可用新加的 `headless_button.cjs` 思路，但原取数没有页面按钮，要先写取数脚本） |
| actor_book | 夹具 v0.28 浏览器手取 | 参照重取＋图鉴跟新源 | ◐ 参照已在新源重取（新加 `ui_reference/headless_button.cjs`，`?battle_ref=1&actor_book_review=1`）。剩 5 项是重制图鉴没跟上：目录名单（index_names）、被动标签「【光环】」、状态页「主动」列宽 225、新角色 168／173～179 的立绘、179 技能表 |
| enemy_book | 目录多 850／823、百分比 99%→299%；两份夹具由 `item_list_ref` 手工拼 | 参照重取（百分比要看是不是口径变） | ○ 待做 |
| svpngfd | 原版 v0.51 dsPassiveSkill 每次 refresh 先清缓存再解析，战斗中加状态 SvPngFd 会生效（cache 2）；重制仍「只在开战时算一次」 | 机制（被动缓存刷新） | → 转 C（会碰 passive 缓存，不是界面） |
| gear_search | 战力排序／战力数 | 等 rules 穿透口径 | ⏸ 派单要求等 |
| help_card | 说明卡新排版（`installPanelLayoutV043Runtime`） | 页面改版 | ✓ 已做（1057/1073）。剩 10 个角色专属技能的「成长：」措辞（谷雨、云裳等，10326 还有数值不同，归角色技能／C）和 2 件随机词缀装备（穿透行与 v0.41 特效按品质排序，等穿透口径） |
| zhenqi | 修行页改版（`installNativeGuidanceRuntime` 240→365 行：挑战评估、必备属性、建议编号、「修行·详细」第二页） | 页面改版 | 📋 待批 |
| guide | 向导里程碑／修行建议改写、区段表 ATLAS 变（同一个 Guidance 运行时） | 页面改版（随 zhenqi） | 📋 待批 |
| hangup_auto | 挂机卖出页多「保留词条品质」 | 页面＋机制（`installSafeSellRuntime` v0.40～v0.53.01：九档词条门槛、专属法宝可卖、0 金币带别的货币可卖等） | 📋 待批 |
| item_marks | 一键出售多「保留词条：不朽及以上」档、档位 q0～q15＋锁 | 同上（Safe Sell） | 📋 待批 |

小计：已追平 7 个（sve_visual、vsfx、change_clothes、costumes、inlay_book、guyu_ui、options_basic），growth_forge 只剩归 C 的一处；参照重取待做 3；转 C 1；等口径 1；页面改版 5（help_card、zhenqi、guide、hangup_auto、item_marks）。

## 页面改版计划（待总装批）

### 1. 说明卡新排版（help_card.gd，动全部说明卡）

前后对照：`03_再刷重制_Godot/04_验证/本地结果/CV说明卡/对照.png`（按原版 v0.28／v0.62.12 说明卡逐行读数画的示意，不是游戏截图）。原版 `installPanelLayoutV043Runtime.view(item, width)` 只改显示副本：

- 块顺序：标题 → 头（「品质：X　类型」合一行，17 号）→ 白字属性两列（`\col[50]`，18 号）→ 元信息两列（伤害属性／目标／命中／暴击／消耗／武器限制，17 号 #e3eaf3）→ 正文（效果、蓝字，18 号，装备按原顺序、技能按 bodyRank）→ 条件两列 → 背景说明（15 号 #a9b4c2，挪到最后）→ 价格两列（15 号）。块之间插 4 像素空行。
- 每行（居中标题除外）在颜色头后插 `\lock[1]`：之后本行忽略 `\c[n]`，一行一种颜色；新转义 `\col[N]`（跳到本行 N%）、`\rgb[N]`（十进制 RRGGBB）。
- 两列只在两格都不超过半宽时合并（units 计宽：全角 2、半角 1）。消耗行去重、「纯粹伤害：否」这类旧行去掉（照原版 META／bodyRank 表）。
- O-205「白字排蓝字上」被这套排法包含，`WHITE_STATS_FIRST` 并入新开关。

做法：`XHelpCard` 加 `LAYOUT_V043`（默认开，O 号待分配，回退＝关，关时就是现在 v0.28 排法），照原版函数一一移植 `view()`；`XMVText` 加 `\lock`／`\col`／`\rgb` 三个转义；说明卡测得两边都测。影响面：help_card、cat_help、growth_help、weak_challenge 说明行、以及所有比说明卡行的专项（约 15 个，先 rg 列全再动）。装备界面右侧的「装备详情／属性对比／插槽与镶嵌」三页（v0.41～0.43 同一批）不在 18 个里，单列为后续。

### 2. 修行页＋向导（zhenqi、guide）

跟 `installNativeGuidanceRuntime` 新版：修行页第一页改成「路线·层数／挑战评估／境界／突破条件／天道加持／结算伤害／必备属性／编号建议／详细数据见第二页」，原对照表挪到「修行·详细」第二页；向导里程碑与修行建议文字、区段表照新源。先 diff 出逐段差异清单再动 `zhenqi` 页与 `guide.gd`。

### 3. 一键出售与挂机卖出（item_marks、hangup_auto）

跟 `installSafeSellRuntime`（v0.40～v0.53.01）：保留词条门槛九档（含神话★／★★／★★★）、专属法宝按普通装备卖、0 金币带其他货币可卖、只筛装备等。是**卖不卖哪件装备**的规则，玩家可见、会影响背包；建议当机制做（登 O 号），界面两处跟着加行。

## 第二段已做（总装二十七批）

- ① 说明卡：`XHelpCard.LAYOUT_V043`（默认开，**O-待定·说明卡排版**，关＝v0.28 排法），照 `P.view` 一一移植（`panel_view`）；`layout()` 认 `\lock`（之后忽略 `\c[n]`）、`\col[N]`、`\rgb[N]`；`content()` 多一个 width 参数（`show_for` 传卡宽−8）。万剑诀少的两行**是原版有意不画**：`tidy()` 删「防御按攻防比例结算」（注释写明「游戏内文字规则：不显示通用的…」），`DROP` 删「纯粹伤害：否」「武器／装备限制：无」。
- 另跟了两处只改显示的：`installUniqueEffectMarkRuntime`（v0.56，备注 `<KyoUnique:…>` 的特效行前加「◆唯一 」，`XHelpCard.unique_mark`）；`_js_trim` 照 JS trim 去全角空格。
- O-205 `WHITE_STATS_FIRST`、O-203 `XBossHpBar.RANGE_V037` 都翻成 true（测试两头测）。O-204 第一段已翻。
- 比「排版之前的行」的专项（black_flash_ui、character_help_cost、guyu_ui 的法宝两项、help_card 白字块）在调用处临时关 `LAYOUT_V043`：它们的参照量的是 characterHelpView，在 readableView 之前。

## 接续要点（给下一位）

1. ② zhenqi＋guide：跟 `installNativeGuidanceRuntime`（新 365 行／旧 240 行，先 `diff` 冻结源两版）。修行页第一页改成新版（挑战评估、必备属性、编号建议、「详细数据见第二页」），旧对照表挪到「修行·详细」第二页；旧两页写法留回退开关（总装要求）。参照 `generated/oracle/zhenqi.json`（新源）、`guide.json`；`tests/fixtures/zhenqi_page_ui_oracle.json` 是 v0.28 手取，也要重取。
2. ③ item_marks＋hangup_auto：跟 `installSafeSellRuntime`（v0.40～v0.53.01，文件头逐版注释），当机制登 **O-待定·安全出售**、带回退开关；挂机卖出页加「保留词条品质」行、一键出售加「保留词条：…」档。参照 `oracle/item_marks.json`、`oracle/sell_rewards.json`、`oracle/hang_up.json`。
3. 参照重取：pets（新排版让说明卡位置变了，`review_system_pages.cjs … pet` 重取 `pet_oracle.json`；本树 pets 只挂 skill_list 的卡位置）、status_power_panel 两份、enemy_book 两份；actor_book 剩 5 项图鉴代码。
4. 交付前：`事件空绿扫描.py --check`、`工具回归.py`、`语法检查.py`、`选测.py cc/newsrc-switch --list` 的场景；本树测试带 `--skip-generated-check`。
5. 已知与本单无关：yunshang_shop 在集成分支 27ccba6a 上也挂（p8 清层账本），不是这里引起的。

## 转出

- C：心之钢 v0.35 巨人吞噬按回合冷却（growth_forge forge.0 的 6 项、growth_help 的心钢行同因）；svpngfd（dsPassiveSkill v0.51 refresh 先清后解析）。
- 未翻的换源开关：O-203 `XBossHpBar.RANGE_V037` 仍是 false（不在本单 18 个里，翻了要同改 boss_hp 专项）。

## 可优化

- 原版参照手取的夹具（actor_book、status_power_panel 两份、enemy_book 两份、gear_search、zhenqi_page_ui）都没有无头驱动，换源只能手点。建议工具车道把 `review_system_pages.cjs` 的 CDP 驱动抽成通用的「起服务→evaluate→写 JSON」，再给 actor_book 等补一页（本车道做 actor_book 时会先抽）。
- `review_system_pages.cjs` 现在多记 `sprite.frameCount／fref`，旧夹具没有，重取后多两个键（测试不比，无害）。

## 验证

- 本机：`并行测试.py --skip-generated-check`：sve_visual、vsfx、change_clothes、costumes、guyu_ui、options_basic、boss_status、boss_hp_bar、inlay_book、cat_help、black_flash_ui、character_help_cost 全过；growth_forge 538/544、growth_help 只挂心之钢（C）；help_card 1057/1073（见表）；actor_book 17/22（见表）；pets 挂 skill_list 卡位置（待重取参照）。
- 未跑：事件空绿扫描、工具回归、选测（交付前补）。

## 待交叉核查

- `xdb.gd`（开机 describe 四件成长装备）、`guyu.gd` 文字、`boss_status_panel.gd`／`boss_hp_bar.gd` 开关默认、`help_card.gd`（`_terms`、`panel_view`、`unique_mark`、`layout()` 新转义、`WHITE_STATS_FIRST` 默认）、`ui_reference/headless_button.cjs`。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/ui-newsrc1`
