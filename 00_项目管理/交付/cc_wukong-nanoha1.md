# 交付：cc/wukong-nanoha1

- 车道／工作者：A 内容·楼层／悟空（cc，悟空 nanoha1，Opus medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】奈叶 108 进切片、共享击杀；一护卍解说明改正（dev.待定）

- **奈叶 108 进切片**：`xiyou_slice.json` 的 `actors` 加 108。Map132 EV16 商店卖的伙伴号角：奈叶（物品 2817）用后调 CE1666（已在 `extraCommonEvents`），现在能招到人。CE1666 与钟离 1665 同构，走通用事件解释器，不加专门代码：变量 1335＝1（招过）时提示「已有该队友」、给魂灯 188；否则 `129 [108]` 入队、变量 1335＋1、提示；开关 2303（轮回）下再给 12 个号角、变量 898＋1，898＝4 时调 CE1391 清号角。`xiyou_actor_p0` 第六批招募表加 `1666: 108`。奈叶是超强者（`installBossDifficultyRuntime` 的 superStrongIds），开挑战开关 2494 才能出战，重制 `XItemMarks.SUPER_STRONG_IDS` 早已包括 108。
- **奈叶共享击杀**（`installNanohaSharedKillRuntime.js`，61 行）：新 `XNanoha`（`modes/xiyou/core/nanoha.gd`）。`apply` 包装：行动者是在出战队伍里的别的角色、奈叶学会并肩适应 10168 与适应 5683 且活着、也在出战队伍里时，打中 apply 前还活着的敌人就记进本次行动的目标表（同一目标只记一次）；endAction 包装（原 endAction 之后，放在米拉解放之后）：目标表里每个已死的敌人给奈叶 `add_param(0,10)`、`add_param(1,30)`（永久，存档 `mv_param_plus`）。奈叶自己的击杀照旧只由状态 1768 Conclude 给。目标表挂在本次行动上，只在 `act`／强制行动 `_forced_run` 的 `execute` 期间开着：原版追击、反击另建 `Game_Action`，不进 `BattleManager._action` 的目标表，重制也不记。读档补学 10168（`ensureLearned`）是给旧存档的，重制不迁移 MV 旧存档、新局按职业 1 级习得，不移植。
- **原版参照**：新探针 `mv_oracle/nanoha_kill_probe.cjs`（真实 `Game_Action.apply`／`BattleManager.endAction`，Math.random 0.5，13 例），产物拷成 `tests/fixtures/nanoha_kill_oracle.json`（不接入全量同步，同饿狼）：队友普攻杀一只 +10／+30、打不死 0、全体技能杀两只／三只 +20／+60、+30／+90；奈叶不在队、没开挑战（去替补）、阵亡、缺 10168 或 5683 都不给；奈叶自己杀只有带 1768 时 +10／+30（不重复）；第二次行动已死的敌人不再算。专项 `tests/xiyou_nanoha.gd` 逐例比，另一条本地断言「execute 之外的 apply 不记」；反向验证：去掉两行 add_param，39 项挂 4 项。
- **审查 27 P3-2**：一护卍解 Map213 EV2 在原版是死内容（变量 1309、1311 在冻结 v0.28 里无处写入，三页任何流程都满足不了）。切片 `keepEvents说明`、`tests/xiyou_floor_odds.gd` 头注释与 `_ichigo` 注释、`tests/xiyou_floor_run.gd` HIDDEN_EVENTS 注释写清「原版死内容、任何流程都没页，测试里是强行置变量」；只改说明和注释，不改行为。
- 改了战斗核心文件 `battle_logic.gd`（`act`、`_forced_run`、`apply` 三处挂钩，新增成员 `nanoha_frame`），请审查重点核。

## 验证

- 同步：工作树里一轮 `同步正式西游.py --accept-additions`（`长任务.py start`，约 36 分钟）：退出码 0，「新增用例，已接受（不登记）」，只增 108 的用例（slice 六难度、actor_passive、wtype、power、help 等重跑），没有既有用例改变；产物指纹已留。
- `内容覆盖检查.py`：hard 0、new 0、resolved 0，基线不用更新。`语法检查.py`：489 个 .gd 0 问题。
- 专项：`xiyou_nanoha` 39/39（反向验证：去掉 add_param 两行挂 4 项，已用备份还原）。
- 选测：`选测.py main --list` 列出的 123 个场景（战斗核心按抽样留 d1b／d2c／d3d／d3e／d4b／d5c／d6d，含 `xiyou_determinism`、`xiyou_actor_p0`、`xiyou_wtype`、`xiyou_floor_odds`、`xiyou_floor_run*`）＋扩角色要的含 108 能力值段 `xiyou_rules_d1d／d2d／d3d／d4d／d5d／d6d`，共 128 个，`并行测试.py --jobs 2`：全部通过（2066 秒，无偶发）；另补 `xiyou_help_card` 1054/1054（同步重跑了 help 探针，选测没选它）。
- 没跑全量 `检查.sh`（车道须知）。`xiyou_rules_d2d`、`d4d` 各 304 秒，过了上限一半（工具提示按场景拆分，原来就接近，非本期引入）。
- 没在游戏里实际点商店买号角试招募（招募走 CE1666 通用事件，`xiyou_actor_p0` 第六批覆盖）。

## 交接板

- 下一步：「角色·奈叶」簇一期已做（进切片、共享击杀）；二期见本单「遗留」：凰霞风暴／厄临星爆的自定义 MP 消耗＋伤害后多段、领域 1774 与身经百战 1780 的公共事件预约、小魔炮 5692 六选一（手动选择窗＋智能 AI 候选）。
- 交接板「一护彩蛋 962 是原版死内容……不做」那行由总装改成「已照原版放上，原版无页（1309／1311 无处写入）」（派单交代）。
- 用户试玩说明：Map132 商店买伙伴号角：奈叶，用了能招到奈叶（地狱及以上难度、开了挑战才能出战）；队友击杀敌人时奈叶的最大生命／魔法也会永久增长。奈叶的大招多段伤害、领域与身经百战的战斗内效果、小魔炮选档还没做（二期）。
- 需要用户决定：无新增。

## 进度账

- 角色：未入切片真缺 1 → 0（奈叶进切片）；奈叶专属模块（共享击杀）0 → 有，奈叶 C 类机制还缺四块（见遗留）。

## 遗留（奈叶二期）

1. 自定义 MP 消耗＋伤害后多段：5703／5704／5705、5706／5708／5709 的 `<Custom MP Cost>`（`cost = floor(user.mp*比例)`、`user._costmp`）与 `<Post-Damage Eval>`（每目标再 `gainHp(-value)` 重复 `_costmp-1` 次）；转换器现在把这两段解析成乱 meta 键，没翻译。
2. 状态 1774 `battle`（`reserveCommonEvent(2478)`）、1780 `action_start`／`action_end`（2481／2480）仍是 `op: js`；`action_end` 在 `XStateEffects.NEVER_FIRED`（OTB 绕过），要先用原版参照确认 1780 的 action_end 到底触不触发。
3. 小魔炮 5692（scope 11，CE 2483 六选一）：手动战斗的选择窗与 `smart_ai.gd` 的 `cannonOptions`（现在 `smart_ai.gd:479` 只是把 5692 排除）。
4. 共享击杀的包装次序：重制 `act` 里种族、异化的 endAction 后半段（原版在奈叶之外）排在奈叶结算之前；它们在 endAction 后杀死本次行动打中的敌人时，重制会多算。没见到这样的技能，只记下。

## 可优化（流程／工具／效率）

- 建议：车道须知「扩角色先单跑 slice_probe」——不带参数的 `node slice_probe.cjs` 六个难度串行、161 个角色，每个难度单跑约 6 分钟（同步里分难度并行，单份 337～990 秒），串行六份要 35 分钟以上、而且六份跑完才一起写文件；本期跑到 28 分钟停了，改由同步分难度并行跑。可以让 slice_probe 认一个 `XIYOU_PROBE_ACTORS`（只量新角色），单跑才真能先查问题；归哪吒。
- 已做：无。
- 建议：`xiyou_rules_d2d`／`d4d` 304 秒，过半上限，d2、d4 可像 d3 一样拆八份；归哪吒。

## 本分支提交

- 见 `git log main..cc/wukong-nanoha1`
