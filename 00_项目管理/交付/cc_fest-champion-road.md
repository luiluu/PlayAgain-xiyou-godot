# 交付：cc/fest-champion-road

- 车道／工作者：冠军庆典·甲（活动总开关＋冠军之路），cc（Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】冠军庆典·甲：活动总开关 XFest＋冠军之路「一穿四」普通版／困难版（dev.待定）

- Kyo 11-15：为庆祝 BLG 夺得 2026 全球总决赛冠军做限时庆典，走在线补丁；方案在私密设计仓 `重制设定/冠军庆典活动_v0.2.md`（2.3 节、3.1 甲）。对手 Kyo 定为网吧队 → 银河战舰队 → 大魔王队 → 内战幻神队（决赛），不写真名、不用队标和选手；以后活动文案不带西游元素。D20 Kyo 定活动开半个月（15 天＋3 天收尾）。
- 新增 `modes/xiyou/core/fest.gd`（`XFest`）：活动总开关 `ENABLED`、开始日 `START`（默认 2026-11-15）、`DAYS=15`、`GRACE_DAYS=3`、`TODAY_OVERRIDE`（测试用）；`active()`／`in_grace()`／`visible()` 只看本机日期；贺词常量 `CONGRATS`；庆典币存在存档 `flags.fest_champion.coins`（不占物品号）；庆典称号号 41～44（冠军之路、一穿四〔金〕、冠军观赛团、全勤观众）与 `unlock_title`。乙车道（大厅庆典）与第 2 天的签到／兑换／成就都只读这个文件。
- 新增 `modes/xiyou/core/fest_road.gd`（`XFestRoad`）：
  - 四支五人队、四个敌群、辅助的群体治疗「应援」都在 `XDB.rec` 表外号段运行时追加（敌人 9300 起、敌群 9300 起、技能 19300），不改生成数据。每只敌人复制本档基准守层者（两档都是 26 层守层者金角，敌人 529）的特性与伤害抵抗被动，按「队强度 0.8／1.0／1.2／1.5 × 位置倍率」重算能力值，名字「网吧队·上单」，图用现成 sv_actors 角色图（中小体型，五只放得下），不掉东西、不给经验金钱、不变神话。
  - 五个位置：上单（血、防高，打人不疼）、打野（速度快、单体高伤）、中单（法术群伤）、下路（攻高身脆、连击）、辅助（「应援」全体回最大生命 4%）。站位：上单、打野、下路前排，中单、辅助后排。
  - 四关连战（中间不回大厅），血量蓝量阵亡带进下一关；四关都不能逃、输了不结束游戏。势如破竹：每胜一关我方伤害 ×(1＋10%×层)，最多三层，只在冠军之路战斗里生效（`XActorDamageHooks` 的 finalMultiplier）。整趟一次场间暂停：全队回三成血蓝、复活阵亡。输了回大厅队伍回满，可从输的那关接着打（不算不败）；两关之间也能退出。
  - 奖励（每个存档）：每关首胜庆典币 ×30（只发一次）；四关全胜称号「冠军之路」；从第一关起一次不败连穿称号「一穿四」（金）＋庆典币 ×100（只发一次）。称号全局解锁、永久。
  - 不强制五人（co 核查 P2，协调 11-15 裁定）：出战不满 5 人时报名先提示「冠军之路是五打五，建议满五人出战」，选「仍要出战」照常开打、选「回去整队」不动进度；方案稿同句已改成「建议五人」（设计仓 d35823f）。
  - 入口 `XFestRoad.enter(host)`／`talk(host)`（乙车道的报名处 NPC 调）：活动外、开关关、没组队、天启篇档都只说一句不开打。
  - 两档（Kyo 11-15 定，取代海选／正赛／巅峰三档）：普通版对标「天灾」难度 26 层守层者、困难版对标「洪荒」难度 26 层守层者。26 层那场是金角 529＋银角 530（敌群 462），以金角为基准；敌人固定吃本档难度倍率（天灾＝难度 6：血 ×750、攻魔 ×3、防 ×5、速 ×5；洪荒＝难度 8：血 ×3500、攻魔 ×10、防 ×20、速 ×30），不看玩家存档难度（`XBattleLogic.setup` 里 `XFestRoad.battle_setup`，改 `battle_logic.gd` 一行）。摊法「×1.0 的队≈26 层这一场」：每人血量＝金角 ×0.35×位置×队强度（×1.0 队五人合计约 1.82 只金角≈金角＋银角），攻击魔攻＝金角 ×0.4（五人合计约 2 只）；防御速度＝金角×位置×队强度。四队 ×0.8／1.0／1.2／1.5 两档各乘。敌人号普通 9300～9334、困难 9400～9434，敌群普通 9300～9303、困难 9310～9313。
  - 两档奖励分开、互不顶替（`XFestRoad.REWARDS`）：普通版每关首胜 30 币、全胜称号「冠军之路」（41）、不败「一穿四」（42，金）＋100 币，共 220 币；困难版每关首胜 50 币、全胜「冠军之路·洪荒」（45，橙）＋50 币、不败「一穿四·洪荒」（46，金红）＋150 币，共 400 币。存档分档记：`flags.fest_champion.road`（普通；改两档前的旧进度就在这个键，按普通版算）／`road_hard`（困难）。成就组（第 2 天）按档读 `XFestRoad.cleared(s, 档)`／`flawless_done(s, 档)`。
  - 庆典币总量：贺礼 50＋签到 140＋普通 220＋困难 400＝最多 810；兑换处有限购、全换完 400 币，资源总量由限购封顶（仍在「刷一两小时」以内），多的币只让打冠军之路的人不签到也换得完。
  - 敌人也不吃存档的 DCultyL1～5（Star_Warehouse 难度怪物属性，公共事件 714 置位，原会多乘 1～3 倍）：`battle_setup` 给冠军之路敌人打 `fest_road` 标记，`XEnemy.warehouse_rate` 见标记返回 1（改 `core/enemy.gd` 两行；co 核查 P2）。
  - 报名处先选档（「普通版（对标天灾难度 26 层守层者）」「困难版（对标洪荒难度 26 层守层者）」），再选从头打／接着打。
- 改：`core/enemy.gd`（warehouse_rate 认冠军之路标记）、`core/xdb.gd`（`rec` 表外入口一行）、`core/actor_damage_hooks.gd`（伤害钩子接 `XFestRoad.damage_ops`）、`core/designation.gd`（称号表活动期间列 41～44、结束后只列拿到的；总开关关掉不列）。
- 测试：新增专项 `tests/xiyou_fest_road`（46 项）；`tests/xiyou_designation`（逐例比原版参照）与 `tests/xiyou_event_compare`（比原版）开头关 `XFest.ENABLED`。工具：`tests/virtual_player/fest_road_probe`（基准队连打四关的数值探针）、`fest_road_shots`（四关战斗截图，要窗口）。
- 玩家可见：活动期间可以在大厅报名「冠军之路」，五打五连挑四支战队，打通拿限定称号「冠军之路」，一次不败拿金色称号「一穿四」。
- 验证：专项 `xiyou_fest_road` 63/63（存档 DCultyL 开关不影响冠军之路敌人属性；两档基准取金角×本档难度倍率、换存档难度不变，困难／普通比＝洪荒／天灾，困难敌群敌人号对、超号段为空，两档奖励各发一次互不顶替、打完困难还能拿普通、接着打的点不串档、两档读档往返、旧 road 进度按普通版、称号表列 45／46、选档文字写对标难度；不满五人提示与确认后可进、满五人不提示；四关顺序与队名、五人站位放得下、图在且不超 96 像素帧、逐关变强、位置特点、应援实算 4%、实建战斗五只都在、流程顺序与不能逃、势如破竹 0→3 层与实际伤害 ×1.3、暂停一次与复活三成、输了回满可接着打、接着打只给「冠军之路」、奖励只发一次、存读档进度在、活动外与收尾期不可进、15＋3 天窗口、天启篇档不开、开关关掉无痕）；`反向验证.py` 9 处改坏 8 处咬住（「接着打不清不败」是等价改动：输那一关时已经清了）。选测：`xiyou_designation*`、`xiyou_achievement*`、`xiyou_event_compare*`（四片 14/6/6/6）、`xiyou_actor_modules`、`xiyou_actor1_damage`、`xiyou_determinism`、`xiyou_tianqi_skills`、`xiyou_tianqi_sect_bing`、`xiyou_lobby_shops` 全过；`语法检查.py`、`工具回归.py` 通过。两档专项的反向验证 3 处改坏都咬住（不固定难度、困难用普通称号、两档共用进度）；改两档后选测 `xiyou_designation*`、`xiyou_determinism`、`xiyou_actor_modules`、`xiyou_actor1_damage`、`xiyou_tianqi_horsemen`、`xiyou_tianqi_sect_bing` 全过。截图：`03_再刷重制_Godot/04_验证/本地结果/fest_road/fest_road_normal_1_网吧队.png`～`fest_road_normal_4_内战幻神队.png`、`fest_road_hard_4_内战幻神队.png`（本地结果不入库）。
- 未完成／已知问题：①数值没实测。现成的守层者基准队探针只有天启篇弱者队，打不动按原版守层者定的数值，不代表原版档玩家；两档摊法见上，参数在 `HP_SHARE`／`ATK_SHARE`／`TEAMS[].mult`／`ROLES`，要有人拿原版档天灾／洪荒难度打得过 26 层的存档试打再调。②「打野专挑血少的」没做（现成敌人 AI 不挑目标）。③庆典成就（模块 G）第 2 天做，按档读 `XFestRoad.cleared`／`flawless_done`。④天启篇档暂不开放（天启篇守层者另有一套血量）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·冠军庆典总开关 | `modes/xiyou/core/fest.gd` `XFest.ENABLED`、`START`、`DAYS`、`GRACE_DAYS`；`core/designation.gd`；`tests/xiyou_fest_road.gd`、`tests/xiyou_designation.gd`、`tests/xiyou_event_compare.gd` | 没有限时活动 | 冠军庆典限时活动（本机日期 15 天＋3 天收尾），称号 41～44 | Kyo 11-15 庆祝 BLG 夺冠 | `XFest.ENABLED = false`（整件不存在） | cc | 保留 |
| O-待定·冠军之路 | `modes/xiyou/core/fest_road.gd` `XFestRoad.ENABLED`；`core/xdb.gd`、`core/actor_damage_hooks.gd`、`battle/battle_logic.gd`；`tests/xiyou_fest_road.gd` | 没有 | 冠军之路普通／困难两档四关五人队连战、势如破竹、场间暂停、奖励与称号 | Kyo 11-15 庆典方案 2.3 节 | `XFestRoad.ENABLED = false`（表外敌人敌群技能、伤害加成、入口都没了） | cc | 保留 |

## 交接板

- 下一步：拿原版档天灾、洪荒难度能打 26 层的存档各试打一轮，按结果改 `XFestRoad.HP_SHARE`／`ATK_SHARE`（不再补海选、巅峰）。
- 用户试玩说明：大厅报名处（乙车道接入后）选「从第一关开始」，连打网吧队、银河战舰队、大魔王队、内战幻神队；两关之间可以暂停一次回三成；打通看称号页多了「冠军之路」「一穿四」。
- 需要用户决定：无（Kyo 11-15 定两档与分档奖励；币量按「全拿完不超过刷一两小时」：普通 220、困难 400，在 `XFestRoad.REWARDS` 可改）。

## 进度账

- 无（限时活动，不进重制进度账）

## 待交叉核查

- **给总装：`core/designation.gd` 与乙车道 cc/fest-lobby（f82298326）改了同一处判断，合并会冲突。** 保留本分支写法即可：`var during := XFest.visible() and _fest_road_ready()`，条件 `(during or unlocked(id)) and 没重复`，即 `(XFest.visible() and XFestLobby.road_ready()) or unlocked(id)` 再去重；`_fest_road_ready()` 按名字找全局类 XFestLobby 调它的静态 `road_ready()`，没有这个类时当作开放，所以两条分支谁先合都不报错。乙那一行（`XFestLobby.road_ready() or unlocked(...)`）丢掉。
- 第三轮只复核：c1a92da64（冠军之路敌人不吃 DCultyL 仓库倍率；专项 `dcultyl_does_not_touch_road`：DCultyL2 开／关两种下首敌血、攻、xparam、sparam 都相同，同存档普通敌人仍吃 1.5；反向验证去掉标记即失败）。

- 交 co 甲档：`modes/xiyou/core/fest.gd`、`fest_road.gd`（新）；`core/xdb.gd`、`core/actor_damage_hooks.gd`（伤害钩子）、`core/designation.gd`、`battle/battle_logic.gd`（共用核心文件，各一两行）。**第二轮只核两档改动（9d91f902d）**：敌人固定吃本档难度倍率（`battle_setup` 改 `_rates` 后 `recover_all`）、两档奖励与进度分开只发一次、旧进度按普通版、称号 45／46。重点：表外号段会不会和别的表外追加撞号（敌人／敌群 9300～9399、技能 19300）；势如破竹只在 `in_road_battle` 时生效、战斗中途崩了会不会残留（静态变量，不进存档）；奖励只发一次。
- 合并建议：xdb.gd 改动让选测扇到约 494 个场景，总装 `合并车道.sh --finish --affected --cloud`。

## 可优化（流程／工具／效率）

- 已做：`tests/virtual_player/fest_road_probe`（任意层基准队连打冠军之路四关，记每关回合、输赢、剩几人）、`fest_road_shots`（四关战斗截图）；不进检查，删掉即回退。
- 建议：守层者基准队探针（`baseline_dps.gd`）只有天启篇弱者队，原版档的平衡没有自动化口径；要做原版档活动、副本时缺一个「原版档 N 层典型队伍」夹具（预计省一轮人工试打，归虚拟玩家车道）。

## 本分支提交

- 6a3efc739 活动总开关 XFest、称号 41～44 接进称号表
- d0eaba585 活动天数改 15（Kyo 定 D20）
- adb3e5221 冠军之路正赛档：XFestRoad、专项 42/42
- 1bf373af9 数值第一版降档、天启篇档不开、实伤断言、实测探针
- 719ea073b 应援补公式程序、四关截图脚本
- 8fd063469 庆典称号活动后只列拿到的；称号、事件对照关庆典开关
- a8566a18a 报名处入口 enter；开关注释 O-待定·名
- 9d9260df5 不满五人报名提示、确认后可进；专项 49/49
- 9d91f902d 冠军之路改两档（普通天灾／困难洪荒 26 层），两档奖励与进度分开、称号 45／46；专项 62/62
- 5cd6064da 交付单补两档；方案稿私密仓 c074b87 改两档
- c1a92da64 冠军之路敌人不吃 DCultyL；称号表接 XFestLobby.road_ready；专项 63/63
- （本提交）交付单补第三轮
