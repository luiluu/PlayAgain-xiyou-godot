# 交付：luiluu/t225

- 车道／工作者：C 战斗核心（玩家反馈：拳一连续拳开招卡顿）／cc（Opus＋medium）
- 状态：可合并

## 一句话

多段技能改成「演出演到哪一段才结算哪一段」（`XBattleStream.PER_SEGMENT`，O-待定）：认真连续拳开招那一帧 79～105ms → 约 4ms，之后每段 4～7ms 摊在各段的帧上；结算先后与原来逐条相同，开／关两种走法的结果和整次行动记录逐条一致（28 个用例、西游档＋天启篇）。R1 返修（小A 甲核退回）：补上至臻闪光的线程漏网，加统一线程保险 `XMainThread`，线程起不来时退回一次算完，倒下去重。

## 做法（为什么这样做）

- 派单 A 的直译是把战斗结算改成协程，但 GDScript 规定协程必须 `await` 调用（不 await 是解析错误，试过），`act`／`execute` 有上百处同步调用方（回放、参照对照、无界面测试、各专属模块的内部施放），全改成协程风险太大。
- 改成：`XBattleLogic.act` 照旧是同一份同步代码、同一个先后顺序，战斗画面开行动时把它放到一条**交接线程**上跑；主行动的根序列（`XActionSequence`）每条 ACTION EFFECT 之前停下（`gate`），画面演到要下一段的记录时（`pull`）再让它往下算一段。两条线程严格轮流（信号量交接），同一时刻只有一边在跑，所以结算顺序、随机数、状态与一次算完完全相同，只是摊到了各段的帧上。
- 画面拿到的记录是 act、execute、根序列三层记录数组（按引用登记）拼起来的前缀；每次交接都核对前缀只追加不改写（对不上 `push_error`，专项断言 0 次）。
- 只在战斗画面这一处（`battle_scene.gd` 主循环的 `logic.act`）开；无界面测试、回放、参照对照、敌群事件里的强制行动都不走，照旧一次算完。
- 派单「先想一想」提的「只把快照和命中被动推迟、公式仍开招算」：会改变结算先后（被动早于／晚于公式），要逐个对原版，且 T224 量过快照＋被动只占每段约 2.4/5.2ms，省不到单段水平，没有采用。

## 改的文件（独占）

- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_stream.gd`（新）：`XBattleStream`（开关 `PER_SEGMENT`、交接线程、gate／pull／finish、前缀核对、量数）。
- `modes/xiyou/battle/battle_logic.gd`：`_stream`；`act` 开头登记本层记录、主行动 `execute(..., stream_root=true)`；`execute` 加第 5 个参数 `stream_root`，根序列挂 `stream` 并登记记录。
- `modes/xiyou/battle/action_sequence.gd`：`stream`；`_run_list` 里 ACTION EFFECT 之前 `stream.gate()`。
- `modes/xiyou/battle/sequence_player.gd`：`feed`、`_has`（读到末尾时再结算一段；`_results` 不等，一条 ACTION EFFECT 的结算记录总是同批到）。
- `modes/xiyou/battle/battle_scene.gd`：主循环开 `XBattleStream`；`_play` 读到末尾再要一段、序列演出器接 `feed`、不走序列的行动先算完再往后看命中记录（渡鸦）；`_enemy_collapsed` 在结算没跑完时把掉落弹出留到行动结束；`_exit_tree` 收线程。
- `modes/xiyou/ui/toast.gd`、`modes/xiyou/ui/achievement_popup.gd`：不在主线程时 `call_deferred` 回主线程再建节点（结算线程上的提示、掉落进背包触发的成就弹窗）。
- R1：`modes/xiyou/core/main_thread.gd`（新，`XMainThread`：`defer`／`require`）；`ui/prestige_notice.gd`、`ui/autosave_notice.gd`、`ui/xsound.gd`、`ui/power_notice.gd`、`ui/skill_notice.gd`、`ui/movie_player.gd`、`core/difficulty_notice.gd`、`core/graphics_quality.gd` 入口加线程保险；toast、achievement_popup 改用同一个 helper；`battle_stream.gd` 线程启动失败回退；`battle_scene.gd` `_stream_collapsed` 去重。
- `tests/xiyou_state_effects.gd`：测试里覆写的 `execute` 跟上新参数（语法检查报父类签名不符）。
- 新专项：`tests/xiyou_battle_stream.gd`＋`xiyou_battle_stream.tscn`、`_b`～`_e.tscn`（按组拆，单场景 50～75 秒）；R1 加 `_f.tscn`（线程保险、启动失败回退、倒下去重，约 20 秒）。

## 量数（无头 Godot，本机，开招那一帧＝指令定下→开始演出；计时用例三次取中）

| 招（敌群） | 关：开招那一帧 | 开：开招那一帧 | 开：之后单帧最多 | 段数（停点） |
| --- | --- | --- | --- | --- |
| 9939 认真连续拳（80 黝石巨人） | 79ms | 4.2ms | 7.5ms | 16 |
| 9939 认真连续拳（2 嘤嘤怪×3，中途打死） | 105ms | 4.1ms | 7.1ms | 16 |
| 9938 认真一拳（单段，参照） | 10.9ms | 4.2ms | 6.2ms | 1 |
| 1098 神霄净世诀（全体 14 段） | 41.9ms | 3.4ms | 10.4ms | 4 |
| 9926 万剑归宗（全体 11 段） | 54.8ms | 3.9ms | 6.5ms | 11 |
| 1340 劲夫怒拳·乱打（253，带反击） | 57.1ms | 5.2ms | 11.9ms | 7 |
| 天启篇 9939（80） | 100.5ms | 4.3ms | 31.6ms（第一段，其余 4～6） | 16 |
| 天启篇 9938（单段，参照） | 51.4ms | 4.3ms | 33.2ms（第一段） | 4 |

- 西游档：认真连续拳最卡的一帧从约 80～105ms 降到约 7ms，与单段招（认真一拳关着时 10.9ms）同一水平。安卓按以往约 3～5 倍估，没实机量。
- 天启篇：每次行动第一段固定多约 25ms（单段招也一样，见上表），所以天启篇最卡一帧约 31ms，低于天启篇单段招关着时的 51ms；这 25ms 是天启篇自己的每次行动开销（没查是哪个模块，见「可优化」）。
- 没有分段的：甚尔（主技能在第一条里逐段打完，单帧 24ms，原来 28ms）、小猫剑圣剑技（`CAT STRIKE` 一条打完全部剑段，没有停点，16ms 不变）——都是原版插件把多段写在一条指令里，不拆。

## 验收逐条（派单 6 条）

1. ✓ 多段技能演到每段才结算这一段：根序列每条 ACTION EFFECT 一个停点，专项断言停点数＝实际跑的 ACTION EFFECT 条数。
2. ✓ 开关 `XBattleStream.PER_SEGMENT = false` 回到一次算完再演（专项 `rollback_no_stream`）。
3. ✓ 见上「量数」：认真连续拳 79～105ms → 约 4ms，另量了神霄净世诀、万剑归宗、怒拳·乱打、天启篇两招。
4. ✓ 结算代码与先后没改（无界面结算路径不经过 XBattleStream）；参照引擎启动检查与同源检查（`--oracle` 那两项）通过；云端选测 462 个场景含原版对照专项（`xiyou_rules*`、`xiyou_determinism`、`xiyou_battle_events`、`xiyou_event_compare*` 等）全部通过。
5. ✓（清单逐条见下）
6. ✓ 28 个用例（a 组 4、b 组 4、c 组 8、d 组 7、e 组 5；e 组为天启篇）；技能动画开／关、战斗速度两档轮流；不丢段、不重复算由「记录逐条相同＋停点数＝段数」保证。自动战斗走同一个指令入口（`_command` 返回指令后同一处 `logic.act`），没单独开自动战斗跑。

### 第 5 条清单（专项 `xiyou_battle_stream*`，每例开／关同种子各打一场，比行动后全员 HP／MP／TP／状态＋整次行动记录逐条）

| 项 | 怎么验的 | 结果 |
| --- | --- | --- |
| 中途打死目标后剩余段换目标／落空 | 拳一认真连续拳打嘤嘤怪×3（随机目标），断言记录里有倒下 | ✓ 相同 |
| 反击 | 劲夫怒拳·乱打打 253 巨型雪猿（反击 15%），断言记录里有反击 | ✓ 相同 |
| 追加、专属模块钩子 | 饿狼、宿傩、渡鸦、黄泉、镜流、甚尔、屠苏、璇、谷雨、云裳、米拉、奈叶、小猫、流萤、至尊宝各用职业里段数最多的招；天启篇饿狼、宿傩 | ✓ 相同 |
| 伤害数字与日志顺序 | 记录逐条相同（类型、伤害、命中、暴击、目标、日志行）；演出按记录顺序播 | ✓ |
| 七印派生 | 七印派生在行动收尾（根序列之后，最后一次交接里）算，先后不变；**没专门造带七印装备的场景** | － 没专项 |
| 五条悟 | 夹具里没过试炼、出手被挡（只有一条「行动」记录），换成天启篇饿狼 | － 没覆盖 |
| 掉落弹出 | 敌人倒下动画演完时结算可能还没跑到 resolve_collapses，掉落图标改在这次行动演完时弹（见「偏离」） | 画面时机变了 |

## R1 返修（小A 甲核 R0 退回：P1×1、P2×1、P3×2）

| 号 | 怎么改的 | 怎么验的 |
| --- | --- | --- |
| P1-1 至臻闪光在结算线程上建节点 | `XPrestigeNotice.ensure` 开头 `XMainThread.defer`：不在主线程就排到主线程再挂 | `_f` 组：工作线程上 `gain_gear` 至臻铠甲 → 当场没节点、下一帧挂上树、`count≥1`、孤儿节点数不增、Logger 收到 0 条 ERROR；实战逐段结算开着打嘤嘤怪×3（中途打死、掉落表定死为至臻铠甲、掉落动画开）→ 转主线程次数增加、闪光出现、0 条 ERROR、`require` 违规 0。**把这行保险去掉再跑**：7 条失败，复现核查报的 `get_node_or_null` 线程错误和 122 个 ObjectDB 泄漏，改回后 15/15 |
| P2-1 线程启动失败死锁 | `start` 检查 `Thread.start` 返回值，失败就当场同步 `logic.act`、`done=true`，不等信号量（`push_warning` 一条） | `_f` 组 `simulate_start_fail`：回退计数 +1、整场打完、停点 0、记录与关着同种子逐条相同 |
| P3-1 倒下→复活→再倒下重复弹掉落 | `_enemy_collapsed` 暂存前 `has` 去重 | `_f` 组：结算未完时同一敌人连报两次倒下，只记 1 个 |
| P3-2 用例数 | 统一成 28（a～e），`_f` 另计 4 项 15 条断言 | — |

### 结算线程能碰到场景树的入口（排查表，派单第 2 条）

排查办法：`logic.act` 走到的代码全是同步的 RefCounted 静态模块（`modes/xiyou/core/`、`battle_logic`、`action_sequence`），grep 确认：① 这些模块没有 Node 类型的成员／静态变量（0 处），没有信号 `emit`（0 处），存的 Callable 只有 `message_responder`（无界面 run_turn 用）、`XState.map_event_snapshot`（存档 `to_dict` 才调，结算里不存档）、`XGear.roll_fn`（纯随机数）；② 敌群事件、公共事件（`troop_events`／`_drive_events`）只在战斗画面主循环里调，不在 `act` 里；③ 地图事件的 `host.show_text`／`await` 一类不可能在同步的 `act` 里走到。所以结算线程碰场景树只能经过下面这组**静态界面入口**（grep `Engine.get_main_loop`、`get_tree`、`add_child`、`queue_free`、`get_node`、`AudioStreamPlayer`、`XSound`／`XAudio` 在非节点类里的全部出现处得出）。

| 入口 | 碰什么 | 结算线程走得到吗（调用链） | 处理 |
| --- | --- | --- | --- |
| `XToast.show_text` | 根节点建提示 | 走得到：`XAlienBattle`、`XDemonCrown`、`XHubris`、`XHeartsteel`、`XItemMarks`、`XGrowthForge`、`XGuyu`、`XTianqiBrand`、`XZhenqi` 等 | `XMainThread.defer`（R0 已转，R1 改用 helper） |
| `XAchievementPopup.show_for` | 建弹窗、放音效 | 走得到：`resolve_collapses`→`gain_drops`→`gain_item`→`XAchievement` | `defer`（同上） |
| `XPrestigeNotice.ensure` | `current_scene` 上 `get_node`／`add_child` | 走得到：`gain_drops`→`gain_gear`→`XTreasureBatch.note_gain`（**P1-1 漏网**） | `defer`（R1 新加） |
| `XSkillNotice.report` | 只记待报，`_flush` 用 `call_deferred` | 走得到：技能熟练度升级（`XSkillMastery`） | 原本就转主线程；`_layer` 加 `require`，`clear` 加 `defer` |
| `XSound.play`／`system` | `AudioStreamPlayer.play`、根节点挂播放器 | 结算核心不调（只在 `hang_up`／`mv_script` 地图侧、界面页、成就弹窗里；成就弹窗已转主线程） | `defer`（保险） |
| `XAutosaveNotice.saved`／`ensure` | `current_scene` 挂小字 | 不走：只在地图事件 Autosave 指令（`mv_event_core`） | `defer`（保险） |
| `XPowerNotice.notify` | 根节点挂提示 | 不走：只在装备页 | `defer`（保险） |
| `XGraphics.apply` | 窗口、视口 | 不走：设置页、开场 | `defer`（保险） |
| `XMoviePlayer.start` | 建播放节点（要返回节点） | 不走：战斗画面主循环、地图 | `require`：不在主线程报错返回 null |
| `XDifficultyNotice.ensure` | 建节点（要返回节点） | 不走：地图 | `require` |
| `XTianqiQiyinArt.silence_turn`／`dragon_cut`、`XTianqiQiyinArt.dress_battler` | 只在战斗者对象上 `set_meta`、改记录字典 | 走得到 | 不碰节点，不用转（精灵在主线程 `_process` 里读，两条线程严格轮流，不同时跑） |
| `XTianqiQiyinLook`／`XTianqiQiyinShow`／`XTianqiLook`／`XXuanTusuArt` 的节点函数 | 传进来的精灵／地图节点 | 不走：调用方都是精灵、地图、祭坛界面（要节点参数，结算里没有节点） | 主线程才会走 |
| `XAudio.*` | 播放器 | 不走：调用方全是战斗画面、地图、设置 | 主线程才会走 |
| 资源 `load`（`XAppearance.kept_load`、`XCatDamageHooks`） | 读资源 | 走得到 | Godot 4 资源加载可跨线程，不碰场景树 |

保险：上表 `defer` 的入口在非主线程被调时自动排到主线程（`call_deferred`，跨线程安全）再执行；要返回节点的入口 `require` 直接 `push_error`。以后新加的界面入口照这个写法；万一还有漏网，Godot 会报 `is_accessible_from_caller_thread` 错误，`_f` 组的 Logger 断言写法可以照搬。

## 偏离

- 掉落动画（MOG_TrPopUpBattle 开着时）：敌人在多段招中途倒下，掉落图标原来在倒下动画结束时弹，现在等这次行动演完才弹（掉落要等行动收尾的 resolve_collapses 才定，提前定会动随机数）。掉什么不变。
- 演出期间读实时状态的地方（侧栏、精灵待机姿势）看到的是「演到这一段时」的状态，原来是「整次行动算完」的状态；血条、状态栏都读记录里的快照，没受影响（云端 462 个场景里的界面、像素、节奏专项全过）。

## 变更记录草稿

## 2026-11-19 【cc·T225·未经审查】多段技能逐段结算：拳一连续拳开招不卡了（dev.待定）
- 战斗画面开行动改走 `XBattleStream`（`modes/xiyou/battle/battle_stream.gd`）：结算放到交接线程上，主行动根序列每条 ACTION EFFECT 前停下，画面演到要下一段时再算一段；两条线程严格轮流，结算先后、随机数、结果与一次算完相同。认真连续拳开招那一帧约 80～105ms → 约 4ms，之后每段 4～7ms；天启篇每次行动第一段另有约 25ms。
- 接线：`XBattleLogic.act`／`execute(stream_root)`、`XActionSequence.stream`／`gate`、`XSequencePlayer.feed`、`XBattleScene._play`／`_stream_pull`／`_stream_finish`／`_exit_tree`；敌人在结算没跑完时倒下，掉落弹出留到行动演完；界面静态入口（提示、成就弹窗、至臻闪光、技能升级通告、自动存档小字、战力提示、界面音效、画质）加线程保险 `XMainThread`：不在主线程就转回主线程；线程起不来时退回一次算完。
- 回退 `XBattleStream.PER_SEGMENT = false`。
- 专项：新增 `xiyou_battle_stream`、`_b`～`_f`（开／关同种子比结果与记录、停点数、开招耗时）；`xiyou_state_effects` 覆写签名跟上。
- 玩家可见：多段技能（如拳一「认真连续拳」、全体多段技等）出招不再卡顿；敌人在多段技中途倒下时，掉落图标将在整招放完后弹出。（小A 定稿）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/battle_stream.gd` `XBattleStream.PER_SEGMENT` | （重制）开招那一帧把整次行动全部段数一次算完再演，16 段的认真连续拳那一帧约 90ms | 演到哪段算哪段（交接线程、根序列 ACTION EFFECT 停点），结算先后与结果不变；掉落弹出留到行动演完 | 玩家反馈拳一连续拳卡顿（Kyo 11-19「217A」） | `XBattleStream.PER_SEGMENT = false` | cc（T225） | 保留 |

## 交接板

- 下一步：小A 甲核 T225；核过后随下一个玩家补丁推（推补丁等 Kyo 定）。
- 用户试玩说明：多段技能（如拳一「认真连续拳」、全体多段技等）出招不再卡顿；敌人在多段技中途倒下时，掉落图标将在整招放完后弹出。
- 需要用户决定：见回执「要 Kyo 定」（推玩家补丁）。

## 进度账

- 无（玩家反馈修补）。

## 可优化（流程／工具／效率）

- 建议：天启篇每次行动第一段固定多约 25ms（单段招也有，西游档没有），值得量一下是哪个模块（技能重构、词条、七印、弱者专属词条的每次行动开头）；修掉的话天启篇所有招开招都快，C 车道约 2 小时量清。
- 建议：天启篇战斗开场敌我 TP 不走种子（同种子关对关两场就不同；专项里先把 TP 定死绕过），影响回放与确定性对照，归战斗核心车道查一下（我猜是开场 initTp 用了没接种子的随机）。
- 已做：专项拆成五个场景（各 50～75 秒），避免单场景超 300 秒提示。

## 验证

- 语法检查：1052 个 .gd，0 个问题（合并 main 之后）。
- 云端选测（`云端选测.py run`，基准 4f97686faf）：提交 1048d94f9，462 个场景全部通过（运行页 actions/runs/44436850021）；之后两个提交只改了专项测试本身。上一轮 5a17aa714 挂的 7 个（`xiyou_battle_bgm`、`_me`、`_pace`、`xiyou_drop_record`、`xiyou_guyu_ui`、`xiyou_tianqi_doom_follow`、`xiyou_yunshang_ui`）是两个真问题：演出器的 feed 闭包抓了演出器自己成环，场景中途拆掉时协程还在跑（改成参数传入）；成就弹窗在结算线程上建节点（挪回主线程）。改后本机 7/7 通过。
- 本机专项（`并行测试.py`）：`xiyou_battle_stream` 44/44、`_b` 41/41、`_c` 40/40、`_d` 35/35、`_e` 46/46。
- R1（提交 615202512）：语法检查 1053 个 .gd，0 个问题；本机 `并行测试.py`：`xiyou_battle_stream` 44/44、`_b` 41/41、`_c` 40/40、`_d` 35/35、`_e` 46/46、`_f` 15/15、`xiyou_state_effects` 32816/32816；云端选测（基准 db6cc3776f）494 个场景全部通过（运行页 actions/runs/44444487985，含界面入口改动波及的提示、成就、存档、画质、音效、战斗专项）。`--oracle` 两项 R1 没重跑（R1 没动结算代码）。
- `--oracle` 两项：参照引擎启动检查 `{"db":true,"modulesFailed":[],"errors":[]}`，`验证西游来源.py` issues 为空。没跑全量 `检查.sh`（车道不跑全量，按规矩留给总装）。

## 本分支提交

- 615202512 R1：线程保险 XMainThread、至臻闪光转主线程、线程启动失败回退、倒下去重＋专项 _f

- e4d730194 多段技能逐段结算（XBattleStream）＋专项
- a4e4fbcf7 开关改名 PER_SEGMENT；专项扩到专属模块角色与天启篇
- 5a17aa714 xiyou_state_effects 覆写签名
- 1048d94f9 演出器 feed 不成环；成就弹窗回主线程；专项拆五个场景
- 5e13e09fc 专项加反击与中途打死断言
- a9e89aa33 天启篇例去掉倒下断言
