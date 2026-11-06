# 交付：cc/ui-newsrc1（换源追平：B 界面 18 个＋说明卡新排版）

- 车道／工作者：界面 CV（cc）
- 状态：**进行中，交回集成分支 `cc/newsrc-switch`（不合 main，不标可合并）**。本单是第一段：分类表＋数据／文案类追平；页面改版只出计划，等总装批。
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
| status_power_panel | 角色 148 技能改名「碧天独行」等；两份夹具是 v0.28 浏览器手取、无脚本 | 参照重取 | ○ 待做（要写取数驱动） |
| actor_book | 角色名、技能列表、图标都随新源变；夹具 v0.28 浏览器手取（`review_actor_book.js` 只有按钮，无无头驱动） | 参照重取 | ○ 待做（照 `review_system_pages.cjs` 写无头驱动） |
| enemy_book | 目录多 850／823、百分比 99%→299%；两份夹具由 `item_list_ref` 手工拼 | 参照重取（百分比要看是不是口径变） | ○ 待做 |
| svpngfd | 原版 v0.51 dsPassiveSkill 每次 refresh 先清缓存再解析，战斗中加状态 SvPngFd 会生效（cache 2）；重制仍「只在开战时算一次」 | 机制（被动缓存刷新） | → 转 C（会碰 passive 缓存，不是界面） |
| gear_search | 战力排序／战力数 | 等 rules 穿透口径 | ⏸ 派单要求等 |
| help_card | 说明卡新排版（`installPanelLayoutV043Runtime`） | 页面改版 | 📋 计划见下，待批 |
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

## 转出

- C：心之钢 v0.35 巨人吞噬按回合冷却（growth_forge forge.0 的 6 项、growth_help 的心钢行同因）；svpngfd（dsPassiveSkill v0.51 refresh 先清后解析）。
- 未翻的换源开关：O-203 `XBossHpBar.RANGE_V037` 仍是 false（不在本单 18 个里，翻了要同改 boss_hp 专项）。

## 可优化

- 原版参照手取的夹具（actor_book、status_power_panel 两份、enemy_book 两份、gear_search、zhenqi_page_ui）都没有无头驱动，换源只能手点。建议工具车道把 `review_system_pages.cjs` 的 CDP 驱动抽成通用的「起服务→evaluate→写 JSON」，再给 actor_book 等补一页（本车道做 actor_book 时会先抽）。
- `review_system_pages.cjs` 现在多记 `sprite.frameCount／fref`，旧夹具没有，重取后多两个键（测试不比，无害）。

## 验证

- 本机：`并行测试.py --skip-generated-check`：sve_visual、vsfx、change_clothes、costumes、guyu_ui、options_basic、boss_status、inlay_book 全过；growth_forge 538/544（剩心之钢 6 项，见上）；help_card、cat_help 只挂新排版（预期）。
- 未跑：事件空绿扫描、工具回归、选测（交付前补）。

## 待交叉核查

- `xdb.gd`（开机 describe 四件成长装备）、`guyu.gd` 文字、`boss_status_panel.gd` 开关默认、`help_card.gd` `_terms`。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/ui-newsrc1`
