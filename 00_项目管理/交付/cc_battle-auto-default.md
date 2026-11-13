# 交付：cc/battle-auto-default

- 车道／工作者：设置加「进战斗默认自动」、遇怪开关合成「定向遇怪」（QQ 群玩家反馈）／cc（战斗自动默认）
- 状态：可合并

从 main（6f8729768）切出，改 `xconfig.gd`、`battle_scene.gd`、`options_scene.gd`、`map_scene.gd`，新增 `encounter_target.gd`；专项 `xiyou_battle_options`、`xiyou_hangup_options`、`xiyou_options_misc`、`xiyou_options_basic`。原版档改动，不带天启篇内容，可进下一个在线更新。

## 变更记录草稿

## 2026-11-13 【cc·战斗自动默认·未经审查】设置加「进战斗默认自动」（dev.待定）

- 起因：QQ 群玩家问战斗左上角的「自动」能不能一直开着，不用每场点；Kyo 确认要的是「进战斗默认就开」。
- 做法（O-待定-1，`XBattleScene.AUTO_DEFAULT`）：设置页在画质设置后、手机按键设置前加一项「进战斗默认自动」，ON/OFF，确定取反、左右切换，存进 options.json 的 `codexBattleAutoDefault`（所有存档共用，同其他设置）。ON 时每场战斗开局自动按钮就是开（`XBattleScene.setup` 里 `logic.auto = force_auto or start_auto()`）；战斗里照旧可以点「自动」关掉，只影响这一场，不改设置。默认 OFF，不开就和原来一样开局为关（「自动」按钮本身是重制新增的 O-006，原版没有）。挂机走 XHangUp，不受影响。
- 专项 `xiyou_battle_options` 加 7 项：默认关、设置页有这一行且默认 OFF、确定后 ON 并存盘重读仍 ON、开局自动为开、战斗里点掉不改设置、回退 `AUTO_DEFAULT = false` 时开局为关且设置页不列。`xiyou_hangup_options` 的设置页行数与末行跟着改。
- 玩家可见：设置里多了「进战斗默认自动」，打开后每场战斗一开始就是自动战斗，想手动打时点一下左上角「自动」关掉即可。

## 2026-11-13 【cc·战斗自动默认·未经审查】遇怪三个开关合成「定向遇怪」（dev.待定）

- 起因：群里玩家说「极其稀有开着只遇到罕见」。原版三项「只遇稀有／只遇罕见／极其稀有」按遇敌表里的位置算抽签值，名字和效果对不上：极其稀有＋只遇罕见同开落到第二组（罕见）；只遇罕见单开几乎总是第一组普通怪；每次启动还要重开。Kyo：「设置里那几个遇怪的开关都优化一下」「整个到一个定向的功能」。
- 做法（O-待定-2，`XEncounterTarget`，新文件 `modes/xiyou/core/encounter_target.gd`）：设置页三行合成一行「定向遇怪」，占原「只遇稀有」的位子；确定往后切、左右切（到头停），档位：关／罕见／十分罕见／稀有／前所未见／亘古未有，存进 options.json 的 `codexEncounterTarget`。按敌群成员名字的【前缀】认档（精英算稀有、首领算前所未见、亘古未见算亘古未有；未知存在、洪荒、外界…等认不出的算普通）。选了某档就在本次可遇的敌群（已按区域过滤）里取不高于所选档的最高档，同档几组按权重抽（原来那次抽签值等比缩放，随机流不变），所以本层没有该档时退到最接近的低档，选「亘古未有」＝本层最稀有。关着照原版算法。挂机遇敌同走 `encounter_troop`，一样生效。禁用遇敌、步步遇敌不变。
- 专项 `xiyou_options_misc` 加 15 项：一行替换三行且位置对、确定／左右切换与到头停、存盘重读、存坏值夹到范围；十四层六档逐档全抽签值只出该档、关着与原版逐个相同；二层选前所未见退到十分罕见；四层两组稀有都能抽到；回退时三行回来、抽签照原版。原版对照部分（行序、304 次原版抽签）在回退支跑（`xiyou_options_misc`、`xiyou_options_basic` 开头设 `ENABLED = false`），`xiyou_hangup_options` 的行数跟着改。
- 玩家可见：设置里「只遇稀有／只遇罕见／极其稀有」换成一项「定向遇怪」，选哪档就只遇哪档的怪，本层没有就遇最接近的；重开游戏还记得。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/battle/battle_scene.gd` `XBattleScene.AUTO_DEFAULT`、`start_auto`；`options_scene.gd` `AUTO_OPTION`；`xconfig.gd` `codexBattleAutoDefault` | 原版没有战斗自动按钮；重制 O-006 加的「自动」每场开局为关，要每场点 | 设置「进战斗默认自动」（默认 OFF），ON 时每场开局自动为开 | 11-13 QQ 群玩家反馈「自动开关能一直开吗」，Kyo 确认要默认进战斗就开；专项 xiyou_battle_options auto_*；Kyo 11-11 优化直接接受 | `XBattleScene.AUTO_DEFAULT = false`（开局恒为关，设置页不列） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/encounter_target.gd` `XEncounterTarget.ENABLED`、`pick`；`map_scene.gd` `encounter_troop`；`options_scene.gd` `TARGET_OPTION`；`xconfig.gd` `codexEncounterTarget` | 「只遇稀有／只遇罕见／极其稀有」三项按遇敌表位置算抽签值，名字效果对不上、组合时乱，每次启动清空 | 合成一项「定向遇怪」，按敌名前缀认档定向，没有该档退到最近的低档，存进设置 | 11-13 群玩家反馈「极其稀有开着只是罕见」；Kyo 11-13「整个到一个定向的功能」；专项 xiyou_options_misc target_* | `XEncounterTarget.ENABLED = false`（原版三行与原版抽签） | Kyo | 保留 |

## 交接板

- 下一步：随下一个在线更新出（只在 Kyo 说「推」时推）。
- 用户试玩说明：设置里打开「进战斗默认自动」，进战斗应直接是「自动：开」；点掉后下一场仍是开。设置里「定向遇怪」选「前所未见」，在五层以上走几步应只遇【前所未见】。
- 需要用户决定：无（定向遇怪 Kyo 已定）。

## 顺带查的：「极其稀有」开着却遇到罕见

- 群里玩家说「极其稀有不是直接前所未见吗，我开着只是罕见」。设置里三项是：「只遇稀有」（Boss）、「只遇罕见」（BOSS）、「极其稀有」（boss），都只管随机遇敌抽哪一组敌人，本次运行有效、不存盘。
- 重制照原版 `Game_Player.makeEncounterTroopId` 一字不差（`map_scene.gd` `encounter_troop`）：「极其稀有」取本地图遇敌表的最后一组（大多数楼层最后一组是【前所未见】或【亘古未有】），说明本身没错。
- 玩家只遇到【罕见】的原因（推断，原版同样如此）：**同时开着「只遇罕见」**。两项同开时，原版算法会落到遇敌表第二组，而第二组一般就是【罕见】（例如 10 层：普通、罕见、十分罕见、稀有、前所未见，同开得到罕见）。另一种情况是地图本身遇敌表最后一组就是罕见类（如 3 层、6 层这类前几层没有前所未见怪），或站在有区域限制的格子上。
- 顺带发现：「只遇罕见」单开时，原版算法几乎总是落到第一组（普通怪），只有掷到最大值才是第二组；「只遇稀有」和「只遇罕见」同开也落到第一组。名字和效果对不上，原版就这样。
- 后续：Kyo 定合成「定向遇怪」，见上。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 语法检查通过；工具快速回归全部通过（119 秒）。
- 专项 16 个全部通过（464 秒）：xiyou_battle_options（含新加 auto_* 7 项）、xiyou_hangup_options、xiyou_graphics_options、xiyou_options_basic、xiyou_options_misc、xiyou_notice_options、xiyou_costumes、xiyou_battle_ui、xiyou_battle_speed、xiyou_battle_pace、xiyou_determinism、xiyou_flow、xiyou_platform、xiyou_test_mode、xiyou_power_hidden、xiyou_screen_fx。
- 定向遇怪：专项 14 个跑过，xiyou_options_misc、xiyou_hangup_options、xiyou_battle_options、xiyou_graphics_options、xiyou_notice_options、xiyou_floor_reach011／075／115／139、xiyou_floor_odds、xiyou_floor_run、xiyou_determinism 通过；xiyou_options_basic 先挂（行序对照原版），开头设回退支后通过；xiyou_flow 的 alt_enter_not_map_action 偶发挂一次（按键时序，与本改动无关），单跑重跑通过。
- 选测.py 列了 217 个（xconfig.gd、battle_scene.gd 被引用得广），没全跑：改动只是新配置键默认 false、开局多读一次它，其他场景用内存默认配置，行为不变；设置页行数只有 xiyou_hangup_options 按总数断言，已改。合并时请总装按影响面选测。

## 本分支提交

- 88cb374bf WIP: 设置加「进战斗默认自动」
- 075eb2b64 交付单
- （本提交）定向遇怪
