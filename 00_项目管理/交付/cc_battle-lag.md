# 交付：cc/battle-lag

- 车道／工作者：战斗卡顿（cc，项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】战斗卡顿：行动之间不再每帧整份重算敌人读数、胜利结算少扫一遍武器表、超大数字不溢出（dev.待定）

- 起因：玩家反馈 v0.01.07「每个角色行动完之后卡 0.5 秒左右」「退出战斗也卡」「战斗伤害高了也卡」；截图是木桩 Boss，敌方异常 22 层、增益 10 层，画面上出现 9223372036854775808 这样的数。
- 量法：临时探针开真战斗场景（三人 99 级打木桩敌群 70／普通敌群 2），给敌人加 22 个、角色加 11 个带图标的状态，`--fixed-fps 60` 无头跑同样帧数，记每帧耗时；`logic.act`、行动序列、胜利结算逐行插计时（临时，已删）。本机负载约 7～10，数字偏大。
- 查到三处：
  - 行动之间每帧整份 `view_of`：`XBattleScene.view()` 不在演出中时现算 `logic.view_of`（状态格排序、能否行动、护盾、指示器……），敌人血条 `update_gauges`、名字淡入淡出 `_process`、`_paint_enemy`、Boss 血条 `hp_source` 每帧都调，每帧四五次。敌人身上状态多时一次 1 毫秒以上：22 层状态时帧耗中位数 5.2 毫秒（没状态 0.4 毫秒），手机上约几十毫秒一帧，行动与行动之间整个画面变慢。
  - 胜利结算 `XZhenqi.unlock_specs` 每场调 `weapon_types()`：扫全部 4005 件武器＋本命兵技能；第一次还要对全部技能备注逐条跑正则建 `_skills`，桌面 70 毫秒以上（第一次进背包加装备 `gain_gear` 另有约 25 毫秒的一次性初始化）。手机上是退出战斗那一下卡。
  - 超大数字：`XMenu._group`（敌人血条数字）、伤害数字回复分支、Boss 血条数字、侧栏护盾字用 `str(int(v))`，超过 9.22e18 时 int 溢出成 ±9223372036854775807／808。
- 改法：
  - O-待定-1 `XBattleScene.VIEW_LITE`：新加 `view_lite(b)`，只给血量、上限、倒没倒（同 `view_of` 的 `b.hp`、`b.mhp`、`b.is_dead()`），演出中照旧读快照；上面四处每帧读数改用它。
  - O-待定-2 `XZhenqi.WEAPON_TYPES_CACHE`：`weapon_types()` 按武器表、技能表、系统表（同一份对象）留一份结果、给副本；`skill_key` 建表时备注不含 `<CodexZhenqi` 的先跳过（正则只认这个前缀，结果相同）。
  - O-待定-3 `XMenu.BIG_INT_TEXT`：新加 `XMenu.int_text`，超出 int 范围按浮点原值写出全部整数位（`String.num(v, 0)`），以内照旧 `str(int())`；上面五处改用它。
- 结果（本机）：22 层状态时行动之间帧耗中位数 5.2→0.6 毫秒；`weapon_types` 20 次 38 毫秒→0.04 毫秒；1e22 显示成 10,000,000,000,000,000,000,000。
- 没修、另报：**每次行动本身的结算**。`logic.act` 一次普通攻击桌面 13～20 毫秒，22 层状态时约 47 毫秒，开始行动那一帧合计约 80 毫秒（手机约数倍，就是「行动完卡半秒」的大头）。拆开看分散在伤害公式、伤害钩子、TP 增益、扣消耗、画面快照里，根子是角色读一次能力值要走整条专属模块包装链：99 级角色读一次物攻约 0.3 毫秒、暴击 TP 率约 0.15 毫秒（没状态也这么慢，状态多再翻倍），一次行动读几百次。O-348 只读窗口只在单次读取里记，窗口一关就作废。要再快得把记忆延长到整次行动（写入都要能作废），动战斗核心、要严格对照，建议另开一条 C 车道做。
- 「伤害高了卡」：本机把攻击加到 1e30，打木桩的耗时和攻击 100 时一样（木桩的伤害被压住，没打出几百京），没找到随伤害数值变慢的循环；玩家那边更像是后期队伍状态、被动多导致上面那条变慢。
- 天启篇读表残留：这条路径上没碰到（`XTianqiSkills`、`XTianqiAffixTable` 已有读不到只读一次）；没有 v0.01.07 的 pck，没在真发行包上量。
- 专项 `xiyou_battle_lag`（新，16 项）：`view_lite` 与 `view_of` 三项相同、倒下实时、演出中读快照、两支开关；`int_text` 小数照旧、1e22／−1e30 不溢出、`_group`、伤害数字与 Boss 血条数字；`weapon_types` 缓存与现算相同、给副本、`_skills` 筛与不筛相同。回退值都是字面量赋值。
- 玩家可见：战斗里行动与行动之间不再越打越慢（敌人状态多时最明显）；退出战斗第一下卡顿减轻；超大数字显示正确的值。每次行动开始时的停顿只少了一部分。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/battle/battle_scene.gd` `XBattleScene.VIEW_LITE`；`view_lite` | 敌人血条、名字、Boss 血条每帧读一份整份画面读数（重制写法，原版直接读 Game_Enemy） | 只读血量、上限、倒没倒，演出中照旧读快照 | v0.01.07 玩家反馈行动后卡；敌方 22 层状态时帧耗 5.2→0.6 毫秒；专项 xiyou_battle_lag；Kyo 11-11 优化直接接受 | `XBattleScene.VIEW_LITE = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/zhenqi.gd` `XZhenqi.WEAPON_TYPES_CACHE`；`weapon_types`、`skill_key` | 每场胜利现扫全部武器与本命兵技能，技能备注逐条正则 | 按数据表留一份结果（给副本），备注先按字面筛 | 同上反馈退出战斗卡；20 次 38 毫秒→0.04 毫秒；专项 xiyou_battle_lag；Kyo 11-11 优化直接接受 | `XZhenqi.WEAPON_TYPES_CACHE = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/ui/menu.gd` `XMenu.BIG_INT_TEXT`；`int_text` | 原版 JS 数字原样转字符串（≥1e21 写成科学记数）；重制 int() 超 9.22e18 溢出 | 超出 int 范围按浮点原值写全部整数位 | 同上反馈画面出现 9223372036854775808；专项 xiyou_battle_lag；Kyo 11-11 优化直接接受 | `XMenu.BIG_INT_TEXT = false` | cc | 保留 |

## 交接板

- 下一步：进下一个在线更新补丁（v0.01.08 已出待推，或 0.01.09）；只在 Kyo 说「推」时推。另建议开一条 C 车道做「整次行动内能力值记忆」（见变更记录草稿「没修、另报」）。
- 用户试玩说明：打状态多的 Boss（木桩挂满异常）时，行动之间的画面应更顺；退出战斗那一下卡顿应轻一些；每次轮到下一位时的停顿还在（另做）。
- 需要用户决定：无

## 进度账

- 无（性能修复，不改完成度）

## 验证

- 语法检查通过（802 个 .gd，0 问题）。
- 并行测试（合过 main 后）：xiyou_battle_lag（新，16/16）及战斗、界面、真气相关共 32 个全部通过（xiyou_battle_lag、alien_battle、battle_bgm、battle_end_ce、battle_events、battle_log、battle_me、battle_options、battle_pace、battle_pixel、battle_speed、battle_transition、battle_ui、boss_hp_bar、boss_status、costume_battle、determinism、popup_multi、popup_overlap、regen_popup、side_status_order、tusu_battle、victory_text_flow、zhenqi、zhenqi_break、zhenqi_daofa、hp_gauge_visible、enemy_state_icon、party_status_panel、hud、power、gold_cap）。
- ⚠ xiyou_battle_pace 偶发：并行时 `pace_cycles` 回合交界差 1 帧（81 对 80），单跑通过；累计第 1 次。本分支不改等待与帧数（每帧读到的三项与原来相同），按本机负载（7～10）记。
- 选测.py 列了 164 个（battle_scene／menu 被很多场景引用，含事件对照、楼层专项）：本分支只改每帧读数的取法（三项与原来相同）、一个结果不变的缓存和超大数字的写法，跑了战斗、界面、真气相关的 32 个；事件对照与楼层专项留给总装按影响面选（云端）。
- 帧耗探针与逐行计时是临时脚本，已删，不入库。
- 安卓大厅截图（红圈摇杆左侧、箭头左上角）：这边拿不到图片，没看；需要的话把图发到本线程。

## 可优化（流程／工具／效率）

- 建议：把本轮的战斗帧耗探针（真战斗场景＋`--fixed-fps 60`＋给敌人挂状态）做成常备的性能专项，只打印不判，出包前看行动帧耗；归工具车道。
- 建议：整次行动内的能力值记忆（见上），预计手机每次行动停顿减半以上；归 C 规则车道，Opus。

## 本分支提交

- 3692a42d9 战斗卡顿三处修复＋专项 xiyou_battle_lag
- 补专项 uid、本交付单
