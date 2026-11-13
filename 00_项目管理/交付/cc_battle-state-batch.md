# 交付：cc/battle-state-batch

- 车道／工作者：C 规则·进出战斗卡顿续（cc，项目线程）
- 状态：进行中

## 变更记录草稿

## 2026-11-13 【cc·未经审查】进出战斗卡顿续：开战挂状态、收场拿状态时不重复算技能表与特性表（dev.待定）

- 起因：上一轮（cc/battle-enter-exit-lag，dev.555）之后开战、收场各还剩约半秒。根因没变：出战角色开战每人挂二十来个状态、收场逐个拿掉，每加减一个都整套 refresh，一场一百七十多次。Kyo 要求把剩下的卡顿消掉，结果不能变。
- 量法：同一份玩家存档副本（九名角色、出战五人各穿十五到十七件装备，开战后五人共 103 个状态、收场拿掉 73 个；放在会话临时目录，不入库），临时探针（已删）在同一进程里开关交替量 `logic.setup` 与 `end_battle(0)`，再给函数临时插计时（已删）。改之前开战约 280 毫秒、收场约 430 毫秒。收场每拿掉一个状态约 5 毫秒：重建被动缓存约 1 毫秒、卸装判断做两遍各约 0.7 毫秒、夹三项上限现算能力值约 1.3 毫秒、给测试留的快照约 1.2 毫秒。
- **没有照派单把 refresh 合成一次**，原因：逐步 refresh 和最后只 refresh 一次的结果并不总相同。例：身上同时有抬高生命上限和压低生命上限的战斗状态，原版逐个拿掉、每步夹一次生命，先拿掉抬高的那个时生命被夹到较低的值；只在最后夹一次，生命会停在更高的值。卸下的装备放回背包的先后也会变。所以 refresh 的次数、先后、每一步做的事全部照原版不动，只省每一步里重复的计算。
- 查到的事实（决定哪些计算能省）：
  - 角色的技能表只从状态的特性 43（加技能）里读状态；之后的心钢、云裳、异化、渡鸦／米拉、谷雨、屠苏／璇、吞噬、专武吸取、套装、法宝、真气与天启篇的技能视图都不读身上的状态、特性、能力值、HP／MP／TP。特性表读状态只在 `trait_objects` 的状态段。
  - 能力值链上的模块会读状态（如天启四骑士按减益个数压能力），所以能力值、三项上限**不留**，每步照算。
  - 这份存档开战挂的状态大多没有特性（只带确认、受击等时机的效果），其余多是行动次数、特殊能力、状态免疫这类特性，只有一个带能力值特性。
- 改法（三个开关，结果都和逐步重算相同）：
  - O-待定-1 `XActor.STATE_BATCH`：`XBattleLogic` 里开战挂状态（`_battle_start_states`）、开战与收场拿战斗状态的三段包成「批」。批里：
    - 加减状态按类别（`XBattler.state_class`）只作废会变的表。没有特性、没有挂上／拿掉／到期效果的状态不动技能表、特性表；有特性但不加技能的不动技能表，特性这组里只丢用到它那几个特性码的项（特性表整张丢；按码取的集合、「一件都不用卸」的结论只在码相交时丢）；加技能的、带挂上／拿掉／到期效果的、阵亡、破甲·真气照旧全部作废。
    - 留下的表按角色存到下一步用（`_carry`）。别的已知写入（`read_touch`、HP／MP／TP 写入、跑状态效果）照旧全部作废。每代首次取用先比指纹：会改技能表的状态、陈旧状态、层数、学会的技能、等级、职业、破甲倍率、每格装备对不上就全丢；带特性的状态有出入就按有出入的那几个状态的特性码丢。
    - 被动缓存延后：批里的 `refresh_passive` 只记「欠着」，读的时候（`passive_cache`）、跑状态效果之前、批结束时再建。中间没人读的重建本来就会被下一次重建盖掉。
    - 批没关好（中途出错跳出）时，下一次开战、收场、行动开始会复位并报错。
  - O-待定-2 `XActor.RELEASE_ONCE`：拿掉状态时原版判两遍卸装（`removeState` 里的 refresh 开头一遍，`Game_Actor.removeState` 末尾又一遍）。第一遍判完后状态、陈旧状态、层数、HP／MP／TP、等级、技能数、每格装备都没变，且该状态没有拿掉／到期效果时，第二遍的输入和第一遍判完时相同，跳过。批内批外都生效。
  - O-待定-3 `XBattleLogic.LIFECYCLE_LOG`：每次加减状态后给 `lifecycle_effects` 留的快照只有测试看，角色拍一次要现读三项上限，默认不留。敌人开着能力值缓存时读上限会把格子填上（影响之后读到的值），照旧每次都拍。
- 顺手补的作废点（只会少用缓存，不改结果）：`stale_refreshed` 清掉陈旧状态时、`XLiuying.after_refresh` 直接抹状态时各补一行 `read_touch`；`XGuide._snap` 改走 `passive_cache()`。
- 结果（同一份存档、首领敌群 70、同一进程开关交替三轮，本机负载 7～16）：`logic.setup` 约 280 毫秒→约 100 毫秒；`end_battle(0)` 约 430 毫秒→约 165 毫秒。开关两态下收场后全队的资源、上限、状态、回合数、被动缓存、装备数、背包件数和战斗随机流快照逐项相同。
- 没修、另报：
  - 收场剩下的约 165 毫秒里，约 60 毫秒是胜利效果（`XStateEffects.run_unit("victory")`，九名成员身上状态的胜利块，每次回血都要 refresh），约 60 毫秒是每拿掉一个状态夹三项上限时现算的能力值（一次约 0.4 毫秒、一场 248 次），其余是各模块的收场包装。能力值要再省，得先把能力值链上所有模块读状态的地方登记清楚，漏一条就会改结果，本轮没做。
  - 开战剩下的约 100 毫秒里，挂状态只占约 35 毫秒，其余是开战效果块、全员首次 refresh 和各模块的开战包装。
- 专项 `xiyou_battle_state_batch`（新，54 项）：状态分类与三种作废；全库 1000 多个状态逐个在批里加上、读一遍、拿掉、再读一遍，开关两态每一步读到的资源、上限、技能表、特性、五组特性集合、装备数、被动缓存相同；敌群 2、70 各两场（混着轻状态、带能力特性的、带装备类特性的、加技能的、带挂上／拿掉效果的，一场每挂一个读一遍、一场不读），两回合自动战斗、满血胜利收场，开关两态整份日志相同，开全程比对零不一致，三个开关各自单开也相同；先拿掉抬高上限的再拿掉压低上限的，开关两态生命相同；被动缓存欠着、读时补建、批末补齐、与当场重建相同；批没关时复位；第二遍卸装判断在没有资源上下文、带拿掉效果的状态时照判。回退值都是字面量赋值。
- 玩家可见：进入战斗和打完之后的停顿再短一截（装备多、开战自带状态多的队伍最明显）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/actor.gd` `XActor.STATE_BATCH`（`batch_begin`、`batch_end`、`state_touch`、`_carry_slot`、`_carry_fetch`、`refresh_passive`、`_passive_flush`）；`modes/xiyou/core/battler.gd` `XBattler.state_class`；`modes/xiyou/battle/battle_logic.gd`（`_battle_start_states`、`setup`、`end_battle`） | 每加减一个状态都整套 refresh，技能表、特性表、被动缓存每步重算 | refresh 的次数与先后不变；开战挂状态、开战与收场拿战斗状态时按状态类别只作废会变的表，被动缓存延后到读或批末 | 玩家存档副本上开战约 280→100 毫秒、收场约 430→165 毫秒（与 O-待定-2、3 合计）；专项 xiyou_battle_state_batch；Kyo 11-11 优化直接接受 | `XActor.STATE_BATCH = false`（`XIYOU_READ_VERIFY=1` 全程比对） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/actor.gd` `XActor.RELEASE_ONCE`（`remove_state`、`release_to_party`、`_release_repeat`） | 拿掉状态时判两遍卸装 | 第一遍判完后输入没变、状态没有拿掉／到期效果时跳过第二遍 | 同上；专项同上 | `XActor.RELEASE_ONCE = false`（`XIYOU_READ_VERIFY=1` 时照判第二遍比对） | cc | 保留 |
| O-待定-3 | `modes/xiyou/battle/battle_logic.gd` `XBattleLogic.LIFECYCLE_LOG`（`_finish_lifecycle_operation`） | 每次加减状态后都给 `lifecycle_effects` 留一份快照（只有测试看） | 角色默认不留；敌人开着能力值缓存时照旧 | 同上；专项同上 | `XBattleLogic.LIFECYCLE_LOG = true` | cc | 保留 |

## 交接板

- 下一步：进下一个在线更新补丁，只在 Kyo 说「推」时推。要再快，得先登记能力值链上所有读状态的模块（见变更记录草稿「没修、另报」）。
- 用户试玩说明：进战斗后行动条出来得更快，打完到出结算的停顿更短。
- 需要用户决定：无

## 进度账

- 无（性能修复，不改完成度）

## 验证

（待写）

## 待交叉核查

- 改了战斗核心文件：`modes/xiyou/core/actor.gd`（`skills`、`all_traits`、`traits_set`、`passive_values`、`refresh_passive`、`passive_cache`、`release_unequippable`、`release_to_party`、`remove_state`、`read_touch`、`read_reset` 与新加的整批一节）、`modes/xiyou/core/battler.gd`（`add_state`、`_add_state`、`remove_state` 的作废点与跑效果处，HP／MP／TP 写入器，新加 `state_class`、`state_trait_mask`、`_state_mark_dirty`、`_run_state_effect`）、`modes/xiyou/core/resource_context.gd`（`refresh` 末尾一行）、`modes/xiyou/battle/battle_logic.gd`（`setup`、`_battle_start_states`、`end_battle`、`_finish_lifecycle_operation`、`stale_refreshed`）、`modes/xiyou/core/liuying.gd`（`after_refresh` 一行）、`modes/xiyou/core/guide.gd`（`_snap` 一行）。
- 请重点核三件事：
  - 「技能表链上的模块不读身上的状态、特性、能力值、HP／MP／TP」这条审计（`XBattler.state_class` 上方注释列了模块）。以后给 `skills()` 链加读状态的包装，要把对应状态算进 `STATE_HARD`，否则批里会用到旧技能表（开全程比对会当场崩）。
  - 批里有没有不经 `read_touch` 的写入会改技能表或特性表（跑状态效果前后已补；模块钩子按编号把关的没补）。
  - 被动缓存延后：批里读 `_passive_cache` 都要走 `passive_cache()`。

## 可优化（流程／工具／效率）

- 建议：`云端选测.py run` 加一个带 `XIYOU_READ_VERIFY=1` 的选项。这轮又是另起临时分支把默认值改成开再推上去跑的（上一轮已提）。归工具车道。
- 建议：把「读入一份存档、指定敌群、打印开战／收场各段耗时」做成常备的性能探针（上一轮已提）；这轮的探针在会话临时目录，没入库。归工具车道。

## 本分支提交

（待写）
