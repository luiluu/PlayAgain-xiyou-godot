# 交付单 cc/rules-gaps9（八戒，战斗内公共事件覆盖）

执行者：cc（八戒）　分支：`cc/rules-gaps9`（scratchpad 克隆里做的，已推回本库；主工作区没碰）　开发编号：dev.待定
状态：可合并（八戒提交 f0e7901b6 写明「可合并」；总装三十九补这一行让合并工具认）


## 结论

内容覆盖报的「只在战斗里跑的公共事件」232 个，原来 troop 例里玩家只普攻，基本一个都跑不到。现在每个都有原版对照：troop 探针尾部加 381 例（237 个 CE，按原版数据算，比切片多 5 个），Godot 新场景 `xiyou_troop_events_sce`／`_sce_b` 逐例比，全部通过。查出的真缺一处（战斗里的角色技能脚本整段跳过），已补；原版无限连放一处，写在「需要决定」。

## 做了什么

- `mv_oracle/troop_event_probe.cjs`：尾部 SKILL_CE 用例。战斗专用 CE＝场合「战斗」的技能／物品效果 44 起点可达、地图页与别的场合调不到（同 内容覆盖检查.py 的算法，读原版 data 不读切片）。每 CE 一个起点（优先只有一个效果 44 的，不然 28／104／1316 跑的是别的 CE）；
  CE 里有「111 角色会技能 K」时分 met／unmet 两例，否则一例 plain。敌群 2，全员 HP 加 999999999；使用者＝CE 里第一个「111 角色在队」的角色（再取 111 角色条件、339 强制角色，都没有取 1 号），
  队伍放进 CE 里 111／313／339 提到的其余角色（原版 339 对不在队的角色照样强制，重制只认在队的），addActor 被拦的高号角色直接写 `_actors`。
  记行动序列、CE 开跑时刻、CE 里 313／333 提到的状态的快照（事件后下一个非强制行动开始时，或回合结束前）。有选项的消息选最后一项（CE1627 流派菜单选别的会 119 跳回菜单无限循环）。
  另：无场景引擎里 `Graphics.playVideo`／`isVideoPlaying` 没有 video 元素时按放完处理（CE1516 天照的 261 原来报错停下）；只影响原来会抛错的路径，旧 1051 例理应不变（没逐字节比，见验证）。
  用例带 party，键 (troop, paid, variant)，variant＝`ce<号>.<met|unmet|plain>`。
- `tests/xiyou_troop_events.gd`：`_skill_ce_case`，比预约的 CE、强制行动［行动者, 技能］（参照记换前技能，按 0.5 过 change_to）、关注状态、没有跳过的指令；规则流全 0.5，敌人 `added_params[0]` 撑住。
  新开关 `skill_ce_only`，新场景 `xiyou_troop_events_sce.tscn`／`_sce_b.tscn`（parts 2）只跑这些，原五个场景跳过它们（本机满载时五段已到 480～536 秒）。排查开关 `XIYOU_CE_ONLY=号,…`（同 XIYOU_TROOP_ONLY，会打印每例）。
- 真缺 `battle/battle_event_runner.gd`：355 脚本里有 `$gameActors.actor(` 的（火法天下第一 CE942～946 的 `$gameParty._targetActorId`、CE1501 逐个角色学 7321 等）原来在战斗里整段记跳过；
  改走地图那套 `MVScript._target_actor_script`（整段认得才执行，认不得照旧跳过），提示记 toast。那边是协程，这些写法没有真等待，经 Callable 调用。

## 需要决定（按默认继续）

- **CE1365 三咒凝魄无限连放（原版 bug）**：强制的 6930「三魔术*火」自己带效果 44 → 1365，会心法 6927 时原版一直强制下去（参照 2 万帧里放了 714 次还没完），说明写的是「额外释放一次」。
  重制现在靠 `XBattleCommonEvent.CHAIN_LIMIT`（64）截停，测试只比前 64 个。建议按「原版 bug 要修」做成只额外放一次（开关＋O 号），请总装派号；本车道没改。

## 验证

- 原版尾部新例：`XIYOU_PROBE_FROM=1051`、两段 `XIYOU_PROBE_SHARD`（占槽.py），381 例无 error，按序号交错拼到 clone 的 generated/oracle/troop_events.json 后面本地跑。
- 本机 `并行测试.py`：`xiyou_troop_events*`（7 段）全过，`xiyou_battle_common_events`、`xiyou_battle_common_event_child` 过；`_sce` 27 秒、`_sce_b` 35 秒。
- 合 main（eb6ab526b）后本机选测 22 个场景全过（1023 秒）：xiyou_battle_common_events、xiyou_battle_events、xiyou_battle_start_event、xiyou_cond111、xiyou_event_compare*（4 段）、xiyou_movie、xiyou_random_streams、xiyou_script_census、xiyou_script_gaps、xiyou_status_power_panel、xiyou_rules、xiyou_rules10、xiyou_troop_events*（7 段）。
- `工具回归.py` 全过（64 秒），`语法检查.py` 过。
- **没跑同步**（clone 不是工作树，没留产物指纹）：总装合并时同步会整份重跑 troop 探针；新例在尾部，旧 1051 例理应逐字不变，但没逐字节比过，合并同步后请看 troop_events 前 1051 例有没有变。
- 选测里其余 xiyou_rules_d*（63 个）没跑：它们归 troop_probe 组是因为同组，但不读 troop_events.json（rg 只有 xiyou_troop_events.gd 读）。
- 没另造「_targetActorId 已选中角色」的例子：现在原版和重制都在 actor 为 null 处停下，只证明了不再整段跳过；942～946 实际加成的数值没对照。

## 待交叉核查

- 甲：`mv_oracle/troop_event_probe.cjs`（探针）、`battle/battle_event_runner.gd`（战斗事件，355 路由）
- 乙：`tests/xiyou_troop_events.gd`、`tests/xiyou_troop_events_sce*.tscn`

## 可优化

- troop 探针每例 setupNewGame 约 2 秒，381 例单进程 16 分钟；同步里分段照常并行。
- 敌群 2 打不死靠参照加 HP；以后可考虑把 SKILL_CE 挪进独立探针，免得每次改 troop 探针都整份重跑这 381 例。

## 状态

可合并
