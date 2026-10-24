# 交付：claude/wukong-reach2（期二）

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_53）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·悟空_53·未经Codex检验】接入盘点三簇：剑气长城 Map139、兑换大厅 Map132＋8号当铺 Map204、信徒藏身 Map192（dev.待定）

- 切片加 Map139 剑气长城、Map132 兑换大厅、Map204 8号当铺、Map192 信徒藏身（keepEvents 全放）；放开入口 Map004 EV27（场所移动，页条件：玩家朝下才传，接触触发）与 Map064 EV5；`extraCommonEvents` 加 514（物品 1269「指路灯:剑气长城」的效果，乘坐载具或副本中提示不可用，否则传 Map139 (13,30)）；敌群加 768（Map192 EV4 超级嘤雄·幼年期）。没有缺指令、缺插件（内容覆盖 new 0，未对照 804→726）。Map139 出口 Map140／179／189 未接，仍是切片外提示。
- 新专项 `xiyou_floor_reach139`（46 项，无随机分支）：Map004 EV27 朝上不动、朝下进 Map132 (8,3)，兑换大厅 → 8号当铺 → 回大厅 → 方桌大厅门（朝下不动、朝上回 Map004 (14,29)）；公共事件 514 副本中不传、否则进 Map139 (13,30)，崔城接受传承置开关 1700 与独立开关 A，军需官离开；Map064 EV5 进 Map192 (6,27)，变量 20≥16 且变量 14＝1 时 EV4 战敌群 768、EV5 狗逍遥·心魔，EV1 回 Map064 (38,27)。
- **事件对照探针补一处**（`mv_oracle/event_probe.cjs` 加 2 行）：Map132 EV14「节日快乐」获得物品会触发成就奖励，原版 `Star.Achievement.Manager.ShowPopUp` 读未建的 `_items` 抛错；该管理器本应在 Scene_Boot.start 里 init，探针不走 Scene_Boot，这里照原版补一次 init（无回调、不改状态）。基线里原有用例都没走到这条路径，所以只多出新用例、旧用例测量不变（同步报告 events.json 只增 79 个用例）。
- `xiyou_event_compare` 基线登记一例已知不一致 m132e6p0：Map132 EV6 奉神老妪「进阶」会开 `Scene_ActorAdvanced` 界面，重制版还没做（同 Scene_ChangeClothes 等四处未接界面）；基线 note 同步改为 7 例。
- 说明：Map132 EV14「节日快乐」原版无条件一次性发 999 个物品 180／188 和一批物品（1675～2003 等），照原版放着，没有改；是否限制由用户之后决定。优化登记 O-090 本批未用（没有改原版行为）。

## 交接板

- 下一步：盘点簇表里剩余可接的簇（4 Map12 EV28 真火秘境需开关 2284、5 Map10 EV12 福地、6 Map6 EV11 伐木场等需先放开入口并清缺敌群）；`Scene_ActorAdvanced` 进阶界面未做（Map132 奉神老妪），可排给界面车道。
- 用户试玩说明：持有物品 1269「指路灯:剑气长城」在菜单使用可传送到剑气长城（神魔战场外围，六位传承 NPC 商店）；大厅 Map004 面朝下走入 (14,30) 的传送点进兑换大厅，里面有节日快乐领奖员；神魔之塔十三层（Map064）的信徒藏身门可进 Map192。
- 需要用户决定：Map132「节日快乐」无条件送 999 个物品要不要保留；奉神老妪进阶界面要不要做。

## 进度账

- 「楼层、副本与剧情内容」地图数 131/231 → 135/231（本期新增 4 张）。

## 验证

- 同步正式西游 `--accept-additions`（worktree，不登记）通过，新增 79 个事件对照用例；内容覆盖检查 new 0 / resolved 0，基线无需更新。
- 专项（并行测试.py）：xiyou_floor_reach139 46/46、xiyou_floor_run／_b／_c 273／332／560、xiyou_floor_abyss037 133/133、xiyou_floor_goblin024 96/96、xiyou_save_page 40/40；xiyou_event_compare 在更新基线后 5/5。未跑全量 检查.sh。
- 已清理：本车道 04_验证/本地结果 下的同步日志、同步基线与内容覆盖输出，以及 /tmp 下临时日志与脚本。

## 本分支提交

- 见 `git log main..claude/wukong-reach2`

## 追加：超强者获取限制（合并后 xiyou_shop_buy 失败的返工）

## 2026-10-24 【Claude·悟空_53·未经Codex检验】超强者伙伴号角／角色限地狱及以上难度获取（dev.待定）

- 原因：Map139 等新商店带来的新用例里，伙伴号角 245（女儿国王）、254（天海麒麟星）、274（苍龙破晓）、277（天剑 非天）在原版 exact／rich 状态下不可买，重制版可买。冻结源 `js/codex/runtime/installBossDifficultyRuntime.js` 的规则：超强者（`superStrongIds` 46 人）仅限地狱及以上难度获取，`superStrongEnabled`＝持久挑战开关 2494／2489／2487／2483／2461／2462／2463 任一开，或难度 ID 9（混沌）；`canAcquireItem(item)＝canAcquireId(recruitActorId(item))`，`recruitActorId` 依次取新原生号角表（2902→167 等 11 项）、备注 `<CodexRecruitActor: n>`、效果公共事件里唯一的一条「加入队伍」(129)。
- 实现（`core/item_marks.gd` 新增 `super_enabled`、`can_acquire_actor`、`recruit_actor_id`、`can_acquire_item`、`acquisition_notice`）：① 商店 `can_buy` 拦（Window_ShopBuy.isEnabled）；② `XState.gain_item` 得到数量大于 0 时不给（Game_Party.gainItem，原版不弹提示）；③ `XState.add_actor` 对未持有的超强者拦下并弹「超强者仅限地狱及以上难度获取。」（addActor；已持有的再加入不拦）；④ 物品页「使用」`_usable` 灰（meetsItemConditions）。冻结数据里招募角色在超强者名单内的号角共 45 件。
- 未做：各 `Codex*.recruit()` 入口（渡鸦等新原生接入，重制版无对应入口）、物品／商店帮助窗的「仅限地狱及以上难度获取与招募」文字（重制版是悬停说明卡，需界面参照）、战斗里的物品条件（`battle_logic.gd` 是沙僧独占，没动）。
- 新专项 `xiyou_super_acquire`（27 项）：招募角色解析、45 件计数、默认难度拦商店／得到／入队，七个挑战开关与难度 9 放行，减少与已持有不拦。`xiyou_item_use` 的「全部可用」扫描先开挑战开关 2494（否则 45 件号角按原版规则灰着）。
- 验证：xiyou_shop_buy 9613/9613；achievement、actor_book、alien_workshop、event_compare、flow、hangup、imported_balance、item_*、lobby_shops、orb*、party、save_page、shop_*、super_acquire、floor_* 共 46 个场景全过。未跑全量（全量 168 个场景在 worktree 里 18 分钟才完成 8 个）。

## 追加：超强者限制连带的测试前提与 fortress029 偶发（第二次返工）

- `xiyou_actor_p0` 的 `recruit_96／100`：原版 `addActor` 在地狱以下对未持有的超强者直接拦下（实测参照引擎：难度 3、挑战开关全关时 `addActor(104／96／100／141)` 一个都进不了队），actor_p0 的招募断言是 Godot 自己的流程检查、不是原版参照数值，所以按原版语义补前提：测试开头开挑战开关 2494。规则没放宽。
- `xiyou_battle_events` 的 `seal1691.*`：参照 `battle_event_probe.cjs` 是直接在角色对象 `$gameActors.actor(104)` 上做的，104 在原版里根本没进队伍（addActor 被拦）；Godot 测试走真实开战要队伍里有 104，所以临时开挑战开关 2494 把 104 编入再关掉，参照数值不变。
- `xiyou_floor_fortress029` 偶发（60 秒，快速失败，与上限无关）：复现到的是 `ice_snow_view`——换到 Map034 后只等一帧就读 `screen_fx._weather.visible`，天气层在物理帧里才刷新可见性，负载高时还没轮到。改为最多等 600 帧至可见。Map029／023／035／036 的 EV2 等随机只写 94／137／140 变量，不影响路线，宝箱页已在期一固定。
- 验证：xiyou_actor_p0 3212/3212、xiyou_battle_events 108/108、shop_buy 9613、item_use 11、lobby_shops 92、super_acquire 27、screen_fx 28，以及全部 floor_* 专项通过；fortress029＋lab111 并行 2 又连跑 3 次全过；另单独并行 12 次循环里改前复现 1 次 ice_snow_view 失败。
