# 交付：cc/tianqi-patches

- 车道／工作者：C 规则·机制／cc（天启修补）
- 状态：可合并

审查线开工单的甲、乙两组（天启篇设计总览 v0.2 第四、五节；Kyo「ok开工」）。只对天启篇存档生效，原版档不变；合进本地，不推玩家。号卷（权能书、遗忘符）不在本分支。

## 变更记录草稿

## 2026-11-14 【cc·天启修补·未经审查】天启篇难度挂钩修补：牢妲、强者名单、难度名、修行页、高阶必出行、洪荒奖励与女皇店、副本档系数、路线系数（dev.待定）

- 起因：影响审查查出天启篇里还有一批原版难度挂钩没跟上五档（设计总览 v0.2 第四节 6～11 条、第五节）。新模块 `core/tianqi_trim.gd`（`XTianqiTrim`），只认天启篇存档。
- 牢妲（大厅 Map004 EV062，O-待定-1 `LAODA`）：天启篇里由 `XTianqiTrim.run_laoda` 接管，菜单只剩打过的 34～36 层（`XTianqiSummit.rechallenge`，从 `run_rechallenge` 拆出来）、30～33 层守层者（敌群 466～469）、兑换商店（1060）。难度 debuff 开关、选择怪物难度属性、花肝帝积分开启都不出；原版进菜单那一下会关掉全部难度开关（含洪荒 2483），也一起没了。
- 破阵·投影名单（O-待定-2 `ROSTER`）：强者、超强者名单改读 `XTianqiSkills.ids`，说明换成天启篇的档位出伤和各档超强者上限（寻常 0…证道 3）。
- 难度名（O-待定-3 `DIFF_NAME`）：地图左下（`XMapHud.difficulty_text`）和难度变化提示（`XDifficultyNotice`）显示五档档名；在副本里接副本档，如「九死·王者」。
- 修行·详细页的「高阶词条概率」一段在天启篇不显示（O-待定-4 `HIDE_AFFIX_RATE`，`XAffixRate.detail_rows`）。
- 必出的高阶行（O-待定-5 `XTianqiAffixRoll.SKIP_HIGH_ROWS`）：`skips_row` 加参数 `table`（`XGear.roll_item` 传），必出行里整行都是神话／混沌神话的也跳过。全库 18 行、7 件，含落芸之力（专项里核了数）。
- 洪荒（O-待定-6 `NO_HONGHUANG`）：36 层的洪荒通关奖励不跑（`XTianqiSummit._honghuang`）；大厅 EV065 洪荒女皇、EV066 兑换大厅传送、EV068 强者的礼物不出现（`MVEvent._find_page`）；混元星河剑 4555、黎明—破晓 5199、技能书免疫转换 1991 任何店都不上架，仙道模式 5198 并进人族首领 EV054 的神武页（指令 302 的货单经 `XTianqiTrim.shop_goods`）。
- 副本档系数（O-待定-7 `XTianqiCombat.DUNGEON_TIER`）：副本里敌人血量、攻击、魔攻在本档难度倍率上再乘副本档系数，普通 0.5、冒险 0.75、勇士 1、王者 1.5（`balance_table.json` 的 `dungeon_tiers`，标 draft，待数值线定）。
- 路线系数（O-待定-8 `ROUTE_TABLE`）：`balance_table.json` 新加 `routes`，按吸收的旧路线映射：真气路线系数 1/1/2/5/13（`XZhenqi.route` 返回同系数的旧路线、名字用档名）、流萤残核前四档 3% 证道 6%（`XLiuying.core_rate`）、星爆书前四档 1/66 证道 1/33（`XStarburstBooks.immortal_rate`）、开局抽奖被动上限变量 9 为 5/5/10/17/22（`XTianqi.opening_commands`，写在借来的难度之后）。
- `balance_table.json` 新加的两节放在 `assist_slot` 后面、`difficulties` 前面，读法 `XTianqiBalance.route`、`dungeon_tier`，避开金钱线改的难度行和 `difficulty()`。
- 专项 `xiyou_tianqi_trim` 44 项。
- 只登记不做：开局不发难度被动（「普通难度」「难度适应」「天道诅咒」还在发，牵数值底数，留给数值线）。
- 我的读法（审查可挑）：牢妲在天启篇不再收肝帝积分，31 层起直接能用挑战菜单（付费只是为了开难度开关，开关没了就不收）；30～33 层守层者照原版不看进度；难度提示在副本里带副本档是我加的。
- 玩家可见（只在本地）：天启篇大厅牢妲只剩挑战守层者；左下角显示「九死」这类档名；洪荒女皇不出现；人族首领神武页多一件仙道模式；副本按档变强。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_trim.gd` `XTianqiTrim.LAODA`；`map/map_scene.gd` run_event；`core/tianqi_summit.gd` rechallenge | 牢妲菜单有难度 debuff 开关、怪物难度属性，进菜单关掉全部难度开关 | 天启篇只剩挑战守层者（34～36 层、30～33 层、兑换商店），不收积分 | 设计总览 v0.2 第五节「不用拍板、建议直接修」 | `LAODA` 设 false | cc | 保留 |
| O-待定-2 | `XTianqiTrim.ROSTER`；`map/mv_script.gd` showRoster | 破阵·投影名单读原版档位 | 天启篇读天启篇档位表，说明换成天启篇规则 | 同上 | `ROSTER` 设 false | cc | 保留 |
| O-待定-3 | `XTianqiTrim.DIFF_NAME`；`map/map_hud.gd`、`core/difficulty_notice.gd` | 显示原版难度名「普通」 | 天启篇显示五档档名，副本里带副本档 | 同上 | `DIFF_NAME` 设 false | cc | 保留 |
| O-待定-4 | `XTianqiTrim.HIDE_AFFIX_RATE`；`core/affix_rate.gd` detail_rows | 修行·详细页有高阶词条概率 | 天启篇不显示 | 同上 | `HIDE_AFFIX_RATE` 设 false | cc | 保留 |
| O-待定-5 | `core/tianqi_affix_roll.gd` `XTianqiAffixRoll.SKIP_HIGH_ROWS`；`core/gear.gd` | 必出行照合（落芸之力带混沌神话行） | 天启篇整行神话／混沌神话的必出行也跳过 | Kyo 11-13 落芸之力「不留」 | `SKIP_HIGH_ROWS` 设 false | cc | 保留 |
| O-待定-6 | `XTianqiTrim.NO_HONGHUANG`；`core/tianqi_summit.gd` _honghuang、`map/mv_event.gd`、`map/mv_interpreter.gd` 302 | 36 层给洪荒通关奖励；洪荒女皇店卖 4 件独有货 | 天启篇取消奖励、女皇与兑换大厅不出、三件不上架、仙道模式并进人族首领 | Kyo 11-13 23:05 洪荒奖励取消、女皇店「该删删」 | `NO_HONGHUANG` 设 false | cc | 保留 |
| O-待定-7 | `core/tianqi_combat.gd` `XTianqiCombat.DUNGEON_TIER`；`tianqi_data/balance_table.json` dungeon_tiers | 天启篇敌人不跟副本档变 | 副本里再乘副本档系数 0.5／0.75／1／1.5（draft） | Kyo 11-13「副本档位也跟着变强」 | `DUNGEON_TIER` 设 false | cc | 保留 |
| O-待定-8 | `XTianqiTrim.ROUTE_TABLE`；`balance_table.json` routes；`core/zhenqi.gd`、`liuying.gd`、`starburst_books.gd`、`tianqi.gd` | 五档都落在原版「普通」 | 按吸收的旧路线取真气、流萤残核、星爆书、抽奖被动上限 | Kyo 11-13 路线映射「可以」 | `ROUTE_TABLE` 设 false | cc | 保留 |

## 交接板

- 下一步：数值线定副本档系数（现 draft）；开局不发难度被动（只登记，牵数值底数）；号卷线另做权能遗忘符上下架。
- 用户试玩说明：天启篇档 31 层后找牢妲，只剩挑战守层者；左下角显示档名。只在本地。
- 需要用户决定：无

## 进度账

- 天启篇：不改完成度（修补已定未落实项）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 54210e893 天启篇难度挂钩修补（甲、乙两组）
- f0a124a35 WIP: 天启修补：summit 专项跟上洪荒奖励取消、牢妲用例；交付单草稿（另加本机复跑 `xiyou_tianqi_summit` 79/79、`xiyou_tianqi_trim` 44/44 全过与 `.gd.uid` 补齐）
