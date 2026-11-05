# 交付：cc/nezha-diff2

- 车道／工作者：难度验收／哪吒（cc，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】难度 7～9 角色侧与整敌群对照，掉率探针提速（dev.待定）

- **探针提速**：`difficulty_enemy_probe` 5 分 12 秒 → 23 秒，432 例产物逐例不变（逐字段比过）。真瓶颈不是 accept2 交付单猜的掉率二分（`makeDropItems` 每次约 0.05 毫秒，二分合计十几秒），是每例一次 `newGame`（约 0.7 秒 × 432）；改成每难度只开一次新局，难度、开关、出战成员照旧每例重设。分段概率九个难度都留着（只多几秒，覆盖不降）。`xiyou_difficulty_enemy` 加断言总数守卫（每例 9 项，总数对不上就挂），现 3889 项全过。
- **难度 7～9 角色侧**：查清原版来路——Map001 只给 1～6；灭世 7 只能从天灾在大厅 Map004 EV41 第 2 页（1 层）进，洪荒 8 在第 6 页（13 层，接 CE1442 选五个诅咒）再开；混沌 9 只在 31 层后的 EV62 第 4 页（关掉全部难度开关、只改怪物属性 SetID 9，另可整组学「灭世难度debuff」6250～6253，318 actor 0 只给队伍）。新探针 `mv_oracle/difficulty_actor_probe.cjs`（登记 PROBES，产物 `difficulty_actor.json`）两边跑同一段原版事件：天灾开局（Map001 EV1 天灾支＋天道使者变量＋大厅 EV20 增减技能＋CE1319）再接 EV41／EV62，6 例（天灾、灭世、洪荒、混沌、混沌＋灭世 debuff、天灾直接混沌）。新专项 `tests/xiyou_difficulty_actor` 比每段应答数与解释器 skipped、难度号、17 个难度开关、18 个变量、8 个样本角色（队伍四人＋2、52、12、30）的全部技能、状态、1 级能力、开战 StartPushState 与开战能力：**875 项全过，没查出差异**。
- **整敌群**：新探针 `mv_oracle/difficulty_troop_probe.cjs`（登记 PROBES，产物 `difficulty_troop.json`）走原版 BattleManager.setup＋startBattle＋dsPassiveSkill 开战加状态，难度 6～9 × 10 个敌群（含 boss 备注的首中尾 3 个＋切片等距 7 个，共 76 个成员）；新专项 `tests/xiyou_difficulty_troop` 走 `XBattleLogic.setup`，逐成员比敌人号、隐藏、神话、等级、HP／MP、状态、param／xparam／sparam／属性、行动表：**1034 项全过，没查出差异**，无需改游戏代码、没用 O 号。
- 反向验证（`反向验证.py`）6 处都咬住：角色侧（开战阈值、SetID 少一档、不跑 EV41／62）、敌群（难度 8 倍率读成 7、等级浮动、行动表）。

## 交接板

- 下一步：难度验收这半项敌人侧、角色侧都已 9 档有原版对照；仍缺的只剩刷怪掉落的实际抽样分布（按概率比过，不比单次），可不再派。
- 用户试玩说明：无（只增测试与探针）。
- 需要用户决定：无。

## 进度账

- 楼层、副本与剧情内容：难度验收半项补齐 accept2 记的「仍缺」两条（难度 7～9 角色侧、整敌群），建议该行再 +0.5 点左右；依据：两条都有原版事件／真实开战对照且全过。

## 验证

- 合过 main（394786de），之后 `新建工作树.sh --补齐`＋`同步正式西游.py --accept-additions` 跑完（exit 0，三个难度探针都在同步里重量过）。
- 专项：`xiyou_difficulty_enemy` 3889／3889、`xiyou_difficulty_actor` 875／875、`xiyou_difficulty_troop` 1034／1034。
- 选测：`选测.py main --list` 列出的 22 个场景（含 `xiyou_rules` 抽样 16 段、`xiyou_event_compare`、`xiyou_global_vars`、`xiyou_status_power_panel`）全部通过（本机并行 2，33 分钟，无偶发）。
- `语法检查.py` 通过（558 个 .gd，0 问题）；`工具回归.py` 全过（65 秒）；`探针登记检查.py` 通过。
- 反向验证：两份清单 6 处改坏都咬住（见变更记录草稿）。

## 待交叉核查

- `difficulty_actor_probe.cjs`：天灾开局只拼了原版事件里与难度相关的几段（不跑存档位、取名、开局剧情），是否漏了影响角色被动的段；EV62 第 4 页两个选项窗在原版被插件并成一个 8 项窗，picks 按并后序号写。
- `difficulty_troop_probe.cjs`：开战加状态照 dsPassiveSkill 手写（只加 StartPushState／StartAEPushState／StartWTPushState，随机目标的三种只记不加，专项要求为空）；原版 Scene_Battle.start 其余部分没跑。
- 未改任何游戏代码（battle_logic／actor 等核心文件未动）。

## 可优化（流程／工具／效率）

- 已做：`difficulty_enemy_probe` 每难度只开一次新局（回退：把 `newGame()` 挪回每例开头）。
- 建议：别的探针也有「每例 newGame」的写法（`host.cjs` 的 newGame 约 0.7 秒），例数多的（几百例）可照这次改，先逐例比产物不变再换；预计同步里探针总时长能省几分钟，归工具车道。派单里的提速估计最好先量一次再定方向（这次估计的瓶颈不对）。

## 本分支提交

- 见 `git log main..cc/nezha-diff2`
