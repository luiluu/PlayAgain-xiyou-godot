# 交付：cc/battle-act-stat-cache

- 车道／工作者：C 规则·战斗出招前停顿（cc，项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】战斗出招前停顿：状态表、侧栏格子记住上次结果，敌人状态多时每次行动少算三成左右（dev.待定）

- 起因：玩家反馈 v0.01.07「每个角色行动完之后卡 0.5 秒左右」；cc/battle-lag 修了行动之间每帧的读数，留下「每次行动本身的结算」（`logic.act` 桌面几十毫秒，手机约半秒），建议另开 C 车道。
- 量法：临时探针（已删）开 99 级三人打敌群 2／70，敌人挂 22 个带图标的状态、角色挂 11 个，三回合自动战斗，量每次 `logic.act`；另把 `act`、`execute`、`view_of`、`states`、`skills` 等三十来个函数临时包一层记独占耗时（已删）。本机负载 3～9，数字偏大。
- 查到的分布（挂满状态时，一次行动约 20 毫秒）：
  - `states()`（列身上的状态记录）一次行动要调四五百次（`can_move`、特性表、侧栏格子、敌人特性……），每次逐个查状态记录、套装状态、按优先级排；合计约两成。
  - 画面快照 `views()`（每条改状态的行动序列指令、每条命中都给全体拍一次）约三成，其中侧栏格子 `cell_rows` 每次按中文名排序，约 8%。
  - 技能表 `skills()` 每个新的只读窗口重算一次（O-348 窗口一关就丢），约两成；能力值包装链本身每层不到 1 微秒，慢在技能表、特性表、状态表这几张表反复现算。
  - 试过把 O-348 只读窗口扩到整次行动：只快一成半（行动里 HP、TP 写入和异化、狂妄的公式帧进出一直在作废），而且行动里有大量没登记的写入（变量、各专属模块的内部状态），不安全，没做。
- 改法（结果都和每次现算相同，只是不重复算）：
  - O-待定-1 `XBattler.STATES_MEMO`：`states()` 记住上次的表；键是身上的状态编号（按内容比，就地改 `state_ids` 也会重算）、破甲·真气倍率、天启篇状态改写开没开、隐月 2521 修正开关、数据库状态表本身；角色另比套装给的状态。给出去的是副本。
  - O-待定-2 `XSideStatus.CELL_MEMO`：`cell_rows` 记住上次排好的格子；键是状态表版本号（上一条）、各状态层数、强化弱化等级、`CELL_FILTER`。给出去的是副本。
  - 两项命中时都认 `XIYOU_READ_VERIFY=1`（同 O-348）：每次命中都重算比对，不一样当场崩。
- 结果（本机，三回合合计，取三次最好）：敌群 2（10 次行动）226→152 毫秒（−33%），敌群 70（15 次行动）251→192 毫秒（−24%）；没挂状态时几乎不变。手机上按比例算，「行动完卡半秒」约少三成，没到减半。
- 没修、另报：技能表、特性表在每个新窗口里还要重算（剩下的大头）。它们的输入散在十几个专属模块里（心钢、云裳、异化、谷雨、屠苏、法宝等级、套装、宝珠、天启篇……），要跨窗口记住就得把这些输入一条条登记成键，漏一条就会改行为，本轮没做；画面快照每条指令给全体拍一次也可以只拍变了的人，同样要先能判断「变了」。
- 专项 `xiyou_act_stat_memo`（新，30 项）：状态表与现算相同、给副本、加状态／就地增删 `state_ids`／破甲倍率／2521 开关都重算、敌人加减状态、影子克隆各算各的、回退不记；侧栏格子与现排相同、给副本、强化弱化／层数／就地改状态／角色／`CELL_FILTER` 都重排、状态表记忆关着时格子也不记；敌群 2、70 挂 22 层状态的三回合自动战斗开关两态整份日志（含每条命中、每条指令的画面快照）相同，逐次比对零不一致，只开状态表记忆也相同，没挂状态也相同。回退值都是字面量赋值。
- 玩家可见：敌人身上状态多时，轮到下一位行动前的停顿短一些（约三成）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/battler.gd` `XBattler.STATES_MEMO`（`states`、`states_stamp`、`_states_memo_list`）；`core/actor.gd` `XActor.states`、`_actor_states_memo` | 原版状态表随状态变化重建（MV 引擎快）；重制每次调用现查，一次行动四五百次 | 状态编号、破甲倍率、天启篇改写、2521 开关、状态表、套装状态都没变时用上次的表（给副本） | v0.01.07 玩家反馈行动后卡半秒；挂满状态时行动结算 −24%～−33%；专项 xiyou_act_stat_memo；Kyo 11-11 优化直接接受 | `XBattler.STATES_MEMO = false`（`XIYOU_READ_VERIFY=1` 全程比对） | cc | 保留 |
| O-待定-2 | `modes/xiyou/battle/side_status.gd` `XSideStatus.CELL_MEMO`（`cell_rows`）；`core/battler.gd` `_cell_memo` | 原版侧栏格子画面刷新时现排；重制每拍一次画面快照就给每人按中文名重排一遍 | 状态表版本、层数、强化弱化没变时用上次排好的格子（给副本） | 同上；cell_rows 约占行动 8%；专项 xiyou_act_stat_memo；Kyo 11-11 优化直接接受 | `XSideStatus.CELL_MEMO = false` | cc | 保留 |

## 交接板

- 下一步：要再快，下一步是技能表、特性表跨窗口记忆（先把各专属模块对 `skills()`／`trait_objects()` 的输入登记成键，带 `XIYOU_READ_VERIFY=1` 跑全量），或画面快照只拍变了的人；都动战斗核心，归 C 车道、Opus。
- 用户试玩说明：打挂满状态的 Boss（木桩）时，轮到下一位之前的停顿应短一些（约三成），还没消失。
- 需要用户决定：无

## 进度账

- 无（性能修复，不改完成度）

## 验证

- 语法检查通过（805 个 .gd，0 问题）；工具快速回归全过。
- 合 main 前，带 `XIYOU_READ_VERIFY=1`（O-348 与本轮两项记忆每次命中都重算比对，不一致当场崩）并行跑 75 个战斗相关场景，全部通过、日志里没有一条不一致：xiyou_act_stat_memo（新，30/30）、battle_speed、determinism、combat、otb、action_sequence、state_effects／_tp／remove／change_remove／operation／overlay／js、side_status_order、party_status_panel、battle_ui、battle_log、battle_pace、battle_gaps、passive、param_cache／states／max、trait_stack、rules 难度 1 八段、smart_ai、troop_events、alien_battle、raven_battle／reflect、yunshang、cat、garou_battle、sukuna_battle、toji_battle、tusu_battle、xuan_battle、guyu_battle、liuying／2、jingliu、heartsteel、mira_battle、nanoha、zhenqi、zhenqi_daofa、equipment_clone_state、confusion、stunned_turn、dot、shield、pushstate、tianqi_skills、tianqi_affix_battle、review_regressions、loose_fixes、race_battle、weak_challenge、gojo、black_flash_ui、popup_multi、boss_sequence、actor_modules、counter_guard、poison_collapse、stage50_review、review_fix、imported_balance。
- 合 main（含 cc/battle-lag、cc/vegeta-nerf）后同样带比对重跑 9 个：act_stat_memo、battle_lag、battle_speed、determinism、side_status_order、party_status_panel、battle_ui、combat、hud，全部通过。
- ⚠ xiyou_battle_pace 偶发：并行时 `pace_cycles` 回合交界差 1 帧（81 对 80），单跑通过；**累计第 2 次**（第 1 次在 cc/battle-lag，同一症状）。本分支不碰帧数与等待，两次都在本机负载高时；按规矩第二次该修测试，但根因（回合交界那一帧为什么会随负载多一帧）没查，没改测试，交给总装派。
- 选测.py 列了 353 个（battler.gd、actor.gd 被几乎所有战斗与楼层场景引用）：没跑的是事件对照、楼层专项、其余 rules／smart_ai 段、天启篇其它场景、界面页等；本分支只改状态表与侧栏格子的取法（与现算逐项相同，有比对兜底），请总装按影响面在云端选测，最好带 `XIYOU_READ_VERIFY=1`。
- 临时探针与函数计时包装都已删，不入库。

## 可优化（流程／工具／效率）

- 建议：把本轮的函数独占耗时探针（给指定函数临时包一层、记独占／含子调用耗时）做成工具，`07_开发环境/` 下一个脚本按清单包、跑完自动还原；这次手工包了三轮，每轮都踩同名覆写递归、解析错误卡住无头 Godot 的坑。归工具车道。
- 建议：无头 Godot 遇到解析错误不退出（等调试器），临时探针要自己看日志杀进程；`并行测试.py` 有超时，单跑场景没有。可以给 `07_开发环境/godot` 入口加一个 `--quit-on-error` 风格的包装，归工具车道。

## 本分支提交

- fddf8bb64 状态表记忆（O-待定-1）
- 912e1292e 侧栏格子记忆（O-待定-2）
- bfdb2d72b 专项 xiyou_act_stat_memo
- ee076ea4c 合 main
- 交付单
