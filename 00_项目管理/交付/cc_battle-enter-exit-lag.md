# 交付：cc/battle-enter-exit-lag

- 车道／工作者：C 规则·进出战斗卡顿（cc，项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】进出战斗卡顿：一次 refresh 只算一遍技能表、备注扫描与被动缓存记住结果、智能选招整段只算一遍（dev.待定）

- 起因：玩家反馈 v0.01.08「战斗开始和结束还会卡几秒」，电脑、手机都卡。Kyo 给了两段视频和一份玩家导出的存档（九名角色、三十五级、出战五人各穿十五到十七件装备）。视频里电脑版进战斗后行动条空着停 4～5 秒，打死首领后停约 6 秒才出结算；手机版打完停 1.2 秒。
- 量法：临时探针（已删）在真战斗场景和真地图上逐帧记耗时，开战初始化、奖励、收场、存档各段单独计时，再用临时脚本给函数逐句插计时（已删）。自造的重数据档（1500 件装备、六十多名没穿装备的角色、发行包、读档后）只复现到零点几秒；读入玩家存档的副本（放在会话临时目录，不入库）才复现：`logic.setup` 1.2～3.8 秒，`end_battle` 2.4～3.5 秒。本机当时负载 20～100，绝对数字偏大，下面的对比是同一进程里开关交替量的。
- 查到的根因：出战角色的装备、技能带「开战挂状态」标签，开战时每人挂上二十来个状态，胜利收场时再逐个拿掉。每加减一个状态都整套 refresh 一遍，一场一百七十多次；一次 refresh 里：
  - `release_to_party` 逐件判断十几件装备还能不能穿，每件读两三次特性或被动标签，每次读取各开各的只读窗口、各算一遍技能表（五十多个技能）；拿掉状态时还要再判一遍。约占四成。
  - `refresh_passive` 对每件装备、每个技能、每个状态的备注各跑十一条正则，正则每次现编译；一次约 6 毫秒。约占四成。
  - 夹 HP／MP／TP 读三项上限、抹免疫状态读特性，每项又各算一遍技能表；HP／MP／TP 就算值没变也照写，写入器会作废只读窗口缓存，所以窗口合不起来。
- 另查到：自动战斗每次轮到角色时 `XSmartAI.choose` 要读几百次能力值，每次各开各的窗口，电脑上一次 0.25～0.8 秒（九十九级四人、没状态时也这么慢），手机上是一两秒。开战后第一下、之后每次行动前都停。前两轮（cc/battle-lag、cc/battle-act-stat-cache）只量了 `logic.act`，没量到选招。
- 改法（五个开关，结果都和逐次重算相同，只是不重复算）：
  - O-待定-1 `XSmartAI.CHOOSE_WINDOW`：`choose` 整段包进一个只读窗口（O-348 的机制）。估算里临时改写角色的三处（魔炮付费后的 MP、铺垫后视图的进出与代价、记下选中的候选）改写前后都 `read_touch` 作废。
  - O-待定-2 `XActor.SCAN_MEMO`：`_scan` 按（正则，备注）记结果、给副本；`refresh_passive` 用的十一条正则改成按备注一次取全（`_note_scans`）。每张表最多 8192 段备注，满了清空。`damage.gd` 里三处每次伤害结算的 `_scan` 也跟着受益。
  - O-待定-3 `XActor.RELEASE_WINDOW`：`release_unequippable` 的逐件判断包进一个只读窗口；真卸下一件时照旧当场作废。
  - O-待定-4 `XResourceContext.REFRESH_WINDOW`：一次 `refresh`（卸装判断、抹免疫状态、夹三项资源、同步阵亡、重建被动缓存）包进一个只读窗口；抹了状态、加减了阵亡、倒下标记变了、被动缓存换新都当场作废。HP／MP／TP 夹完值没变就不写（写入器只做「作废窗口」一件事，没变的写入不算写入；NaN 照写）。`release_to_party` 真卸了装备后补一次作废。
  - O-待定-5 `XActor.PASSIVE_MEMO`：`refresh_passive` 的输入（装备、技能、状态的备注与标签）和上次一模一样时用上次算好的表（给副本），专属模块的追加照旧每次做。备注逐段全文比对；标签表比 64 位哈希（标签是从备注解析出来的，就地改过的装备哈希会变）。`XIYOU_READ_VERIFY=1` 时每次命中都重建比对，不一样当场崩。
- 结果（玩家存档副本，首领敌群，同一进程开关交替三轮）：`logic.setup` 1.1～2.4 秒→0.40～0.66 秒；`end_battle` 1.8～2.7 秒→0.62～0.71 秒；战斗场景 `setup` 0.9→0.35 秒，胜利那一帧 2.9～3.2 秒→约 0.9 秒。智能选招一次 250～350 毫秒→13～35 毫秒（挑的技能和分数相同）。
- 顺手修：`XEquipment.preview` 换装后补 `XActor.read_touch()`。O-348 的只读窗口在装备页里包着预览，预览换了装备却没作废，带全程比对跑 `xiyou_panels` 会报特性表不一致（main 上就有，平时不开比对所以没暴露）；装备页的预览数值可能因此按换装前的特性算。并入 O-348，不另登号。
- 没修、另报：
  - 开战、收场各还剩约半秒（本机高负载下），手机上按比例仍会有一秒上下。剩下的大头：每个新窗口仍要现算一遍技能表（穿满装备的角色一次 0.5～2 毫秒，一场四百多个窗口）；`_finish_lifecycle_operation` 每次给测试用的 `lifecycle_effects` 留一份快照（读三项上限，约占一成）；拿掉状态后角色侧多判一遍卸装。要再快得做技能表跨窗口记忆（上一轮已说明风险），或把开战挂状态、收场拿状态做成成批处理、最后只 refresh 一次——后者改了 refresh 次数，要对照原版逐项核，归 C 车道、Opus。
  - 存档一次要 `JSON.stringify` 再 `parse_string` 校验一遍（`SAVE_GUARD`），1500 件装备的档 3.7 MB、电脑 0.25 秒，手机约一两秒；安卓随机遇敌开战前每 60 秒存一次自动存档就走这里。这份玩家档只有 0.7 MB，不是这次的主因，没动。
  - 开战初始化、收场都对全部已招募角色（含后备）各 refresh 一遍，是照原版 `onBattleStart`／`onBattleEnd` 写的；角色多的档会按人数涨。本轮的五项对每人都生效，没单独做跳过。
- 专项 `xiyou_battle_enter_exit_lag`（新，30 项）：`_scan` 记忆与现扫相同、给副本、空结果；`_note_scans` 与逐条相同、回退不记、命中是同一份；被动缓存记忆与重建相同、给副本、加状态／就地改装备备注／就地改标签都重建、回退不记；卸装判断开关两态相同（等级不够的那件被卸回背包、窗口关好）；敌群 2、70 各一场「四人穿装备＋每人挂十四个开战状态、三回合自动战斗、胜利收场」，开关两态整份日志（每次行动、画面读数、收场后全队的资源、上限、状态、被动缓存）相同，开全程比对零不一致，五个开关各自单开也相同。回退值都是字面量赋值。
- 玩家可见：进入战斗和打完之后的停顿明显变短（装备多、开战自带状态多的队伍最明显）；开着自动战斗时，每次轮到角色出手前的停顿基本消失。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/battle/smart_ai.gd` `XSmartAI.CHOOSE_WINDOW`（`choose`、`safe_damage`、`_followup_score`、`_choose`） | 原版 JS 引擎读能力值快；重制每读一项各开一个只读窗口、各算一遍技能表，一次选招几百次 | 整段选招共用一个只读窗口，临时改写角色处前后作废 | v0.01.08 玩家反馈进出战斗卡；选招一次 250～350→13～35 毫秒；专项 xiyou_battle_enter_exit_lag；Kyo 11-11 优化直接接受 | `XSmartAI.CHOOSE_WINDOW = false`（`XIYOU_READ_VERIFY=1` 全程比对） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/actor.gd` `XActor.SCAN_MEMO`（`_scan`、`_scan_now`、`_note_scans`、`PASSIVE_SCAN_PATTERNS`） | 重制每次现编译正则、现扫备注（原版 dsPassiveSkill 同样逐条匹配，引擎快） | 按（正则，备注）记结果，给副本；被动缓存按备注一次取十一条 | 同上；`refresh_passive` 约占 refresh 四成；专项同上 | `XActor.SCAN_MEMO = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/actor.gd` `XActor.RELEASE_WINDOW`（`release_unequippable`、`release_to_party`） | 逐件判断能不能穿，每次读取各算各的 | 逐件判断共用一个只读窗口，真卸下时作废 | 同上；卸装判断约占 refresh 四成；专项同上 | `XActor.RELEASE_WINDOW = false` | cc | 保留 |
| O-待定-4 | `modes/xiyou/core/resource_context.gd` `XResourceContext.REFRESH_WINDOW`（`refresh`、`_refresh_base`） | 一次 refresh 里各项读取各算各的；HP／MP／TP 值没变也照写 | 一次 refresh 共用一个只读窗口；值没变不写；改了东西当场作废 | 同上；专项同上 | `XResourceContext.REFRESH_WINDOW = false`（`XIYOU_READ_VERIFY=1` 全程比对） | cc | 保留 |
| O-待定-5 | `modes/xiyou/core/actor.gd` `XActor.PASSIVE_MEMO`（`refresh_passive`、`_pm_base`） | 每次 refresh 重建被动缓存 | 装备、技能、状态的备注与标签没变时用上次的表（给副本），专属模块追加照旧 | 同上；专项同上 | `XActor.PASSIVE_MEMO = false`（`XIYOU_READ_VERIFY=1` 命中时重建比对） | cc | 保留 |

## 交接板

- 下一步：进下一个在线更新补丁（0.01.09），只在 Kyo 说「推」时推。要再快，另开 C 车道做「开战挂状态、收场拿状态成批处理」或技能表跨窗口记忆（见变更记录草稿「没修、另报」）。
- 用户试玩说明：进战斗后行动条出来得更快，打完到出结算的停顿变短；开自动战斗时每次出手前不再停。装备多的队伍进出战斗仍会有不到一秒的停顿（另做）。
- 需要用户决定：无

## 进度账

- 无（性能修复，不改完成度）

## 验证

- 语法检查通过（821 个 .gd，0 问题）；工具快速回归全部通过。
- 专项 `xiyou_battle_enter_exit_lag` 本机单跑 30/30。
- 云端选测（提交 4e11ee29b，基准 main 528212f79）：344 个场景、16 片全部通过。
- 云端带全程比对再跑一轮（临时分支把 `READ_VERIFY`／`READ_VERIFY_FATAL` 默认改成开，只为这一轮，不合并）：344 个场景里 343 个通过、零不一致；`xiyou_panels` 报「只读窗口缓存不一致：all_traits」。查明是 main 上原有的问题（把本轮五个开关全关掉照样报）：装备页在只读窗口里调 `XEquipment.preview`，预览换装备 `b.equips[slot] = …` 没作废窗口，随后读到换装前的特性表。已在 `preview` 换装后补一行 `XActor.read_touch()`（只会少用缓存，不改结果）；补后本机带比对单跑 `xiyou_panels` 35/35。这一行是在云端两轮之后加的，没再推云端。
- 临时探针、逐句计时脚本、玩家存档副本都在会话临时目录，不入库。

## 待交叉核查

- 改了战斗核心文件：`modes/xiyou/core/actor.gd`（`_scan`、`refresh_passive`、`release_unequippable`、`release_to_party`）、`modes/xiyou/core/resource_context.gd`（`refresh`、`_refresh_base`）、`modes/xiyou/battle/smart_ai.gd`（`choose` 及三处作废点）、`modes/xiyou/core/equipment.gd`（`preview` 一行）。请重点核：只读窗口里有没有漏掉的写入（`_refresh_death` 前后、`XLiuying.after_refresh` 放在窗口外）、`PASSIVE_MEMO` 的标签表用哈希比对。

## 可优化（流程／工具／效率）

- 建议：性能问题先要玩家存档。这次自造的重数据档量了一个多小时都只有零点几秒，拿到存档十分钟就复现到了。标题页「导出存档」能直接导出，电脑版在用户目录的 `KYO/再刷重制/modes/` 下；可以写进反馈处理的说明里。归总装。
- 建议：把「读入一份存档、指定敌群、打印开战／收场／选招各段耗时」做成常备的性能探针（只打印不判），出包前跑一遍；归工具车道。
- 建议：`云端选测.py run` 加一个带 `XIYOU_READ_VERIFY=1` 的选项。这次是另起临时分支把默认值改成开再推上去跑的。归工具车道。

## 本分支提交

- 4e11ee29b 五个开关＋专项 xiyou_battle_enter_exit_lag
- 装备预览补作废点、本交付单
