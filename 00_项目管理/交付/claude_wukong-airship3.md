# 交付：claude/wukong-airship3

- 状态：可合并
- 车道／工作者：A 内容·地图／悟空_70（Claude）
- 本期：天之上飞艇方案甲三（图像与表现），做完飞艇完整；顺带修了「角色上方」事件画在星号图块下面的老问题（影响面见下「优先级 2 事件层级」）
- 基线：从甲二交付末 e2918504 切出，交付前已合 main（528dba63，含甲二合并与八戒蚀术，没碰本车道文件）。

## 变更记录草稿

## 2026-10-30 【Claude·悟空·未经Codex检验】天之上飞艇甲三：飞艇升空、影子、改造包换图都看得见了（dev.待定）

- 起因：甲二能飞，但飞艇贴地画、没有影子和升空动画，改造包买了也看不到。本期照原版 `rpg_οbjects.js` Game_Vehicle 与 `rpg_sprites.js` Spriteset_Map 补齐画面。
- 高度：`MVCharacter.altitude`（Game_Vehicle._altitude），画面 y 减去高度（screenY）；升空、降落每帧 ±1（甲二已有），画面逐帧跟着。
- 影子：`system/Shadow1`，锚点底边中点，画在飞艇不算高度的位置（含行走图上移 6，物件图 0），透明度 255×高度÷48，层级在飞艇之上（原版 z 6 > 飞艇 5）；挂在飞艇精灵下。
- 层级：「角色上方」（优先级 2）的 z_index 从 1 改为 11，压在上层图块（10）之上，照原版 screenZ 5 > 上层图块 z 4。飞艇升空后因此画在树、星号图块之上。**对所有优先级 2 的事件都生效**，见下节。
- 飞艇精灵速度 6（Game_Vehicle.initMoveSpeed）：修甲二留下的问题——飞艇精灵每帧先抄玩家上一帧位置，再按自己的速度 4 走一帧，飞行中和玩家对不齐。
- 跟随者透明跟着玩家改到逻辑帧（`_physics_process`，原版 Game_Follower.update 每帧），进图放好飞艇后也同步一次：升空、降落中跟随者与玩家同帧隐藏（原来在画面帧里同步，会晚几帧露出来，读档后第一帧也会露）。
- 改造包：切片 `extraImages` 加 7 张行走图（Vehicle2、SF_Vehicle、SF_Vehicle2、Nature2_mvt、tg-cm03-chr-01、$Ravendel's Wyvern、!$occ01jp_mv03_georgette_tv；后两张原来就因别的事件导出，显式列上），CE487～500 的 323 换图在地图上马上显示、随档。
- 触控：拆出 `MVPlayer.click_cell`；飞行中点前方一格是飞过去（原版 triggerTouchActionD2 只对小船大船上下，事件被 canStartLocalEvents 拦住），不再当确认去降落；点脚下仍是降落（D1）。触屏（InputEventScreenTouch）原来就只设目的地，没动；寻路仍是重制原有的直线靠近（原版 findDirectionTo 是 A*，飞行中全图可过，结果一样）。
- 验证：新专项 `xiyou_airship_view`（57 项），截图对照原版三张（上艇、飞行、降落）一致；优先级 2 事件四张图前后对比，改后与原版一致。

## 优先级 2 事件层级（影响面单列）

- 改动：`mv_character.gd` `_sync_position`，优先级 2 的 z_index 1 → `ABOVE_UPPER_Z` 11（上层图块是 10）。走路规则、通行、触发都不变，只改绘制先后。
- 统计（脚本口径：切片 198 张图、按 keepEvents 过滤，事件任一页优先级 2 且有图）：**24 个事件、10 张图**：Map002 [3]、Map010 五层·群狼森林 [5–10，蝴蝶]、Map011 七层·科维努斯镇 [25–28]、Map014 哥布林英雄谷 [11–15]、Map024 哥布林王国 [1–3]、Map042 超越大厅 [3]、Map045 十七层·妖精湖 [9]、Map067 牛马关 [1]、Map071 恰兰吉尔 [20]、Map093 猴山 [1]。另有 1 个优先级 2 但无图的，不影响画面。
- 其中图像覆盖格（本格＋上一格，大图左右各一格）有星号图块、会看出前后差别的：**5 个**——Map010 EV5（11,16）、EV10（12,23）蝴蝶，Map067 EV1（42,43）图块 162，Map071 EV20（68,53）`!$fsm_Object04`，Map093 EV1（42,8）图块 48。会走动的（蝴蝶）静态统计只算初始位置。
- 前后对比（Godot 同一帧只改 z 重画，原版用 `ui_reference/serve.py` 同位置截图；`04_验证/本地结果/原版参照/airship3/pri2/对比_原版_改后_改前.png`，不入 Git）：
  - 牛马关 EV1、猴山 EV1 是「遮盖用」图块事件（盖住一截栅栏、一块暗格），原版压在星号图块之上；**改前被星号图块盖住，露出不该有的栅栏和暗块，改后与原版一致**——这是本改动顺带修好的两处显示错误。
  - 恰兰吉尔 EV20：改前改后与原版看不出差别。
  - 群狼森林蝴蝶：随机走动，两边位置对不上，只确认改后蝴蝶在树冠之上（原版同理）。

## 交接板

- 下一步：「天之上岛间移动」甲三已交，飞艇方案甲一～甲三全部完成。
- 用户试玩说明：天之上恰兰吉尔那块右下 (65,56) 的飞艇：确认键上艇，飞艇会慢慢升起、地上有影子；飞行时在树和建筑之上；到空地按确认慢慢降落。飞艇公司买的改造包（直升机、魔法巨龙等）买完马上换样子，存读档后还在。鼠标点飞艇前方是往前飞，点飞艇脚下是降落。另：牛马关大门左边、猴山右上原来多出来的一截栅栏和暗块没了（照原版）。
- 需要用户决定：无。

## 进度账

- 天之上／神魔战场岛间移动：甲一、甲二、甲三全部完成。

## 待交叉核查

- 优先级 2 层级改动影响全部「角色上方」事件（上节 24 个），请重点核有没有本该被上层图块盖住的。
- `map_scene.gd`：跟随者透明同步从 `_process` 挪到 `_physics_process` 并抽成 `_sync_followers_look`（走路时行为不变，只是更早一帧同步）；飞艇影子挂在飞艇精灵下（`z_as_relative = false`）。
- `mv_player.gd`：`click_cell` 拆出后走路时行为不变（`vehicle_speed <= 0` 分支与原来一样）。
- 没改原沙僧独占文件。

## 可优化（流程／工具／效率）

- 发现（约 1 行，归 B 车道）：原版网页里有插件用了全局变量 `i`，在页面内 JS 用 `var i` 写循环会被改掉（本期一个 4 步循环飞了 56 格）。建议 `ui_reference/README.md` 加一句「页面内 JS 循环用 let」。
- 发现：内置浏览器窗格在后台时原版页面连标题都起不来（requestAnimationFrame 停摆），要先手动推帧（`SceneManager.updateInputData/changeScene/updateScene/renderScene`）才到标题；README 只说了夹具里用 `__dhRef.pump`，而 `__dhRef` 只在 `?battle_ref=1` 下有。建议把 pump 挪到垫片公共部分。
- 发现（工具，归哪吒）：`并行测试.py --quiet` 把「等槽」进度行也压掉，经 `长任务.py` 启动时排队超过一小时就被看门狗判 stuck 杀掉（本期白等一小时）。建议 `--quiet` 仍打等槽心跳，或车道须知注明长任务里别加 `--quiet`。
- 建议（约半期，归 B 车道）：原版地图画面夹具做成 `?map_ref=1` 的一个按钮「到指定图与坐标、清提示消息窗」，本期是手敲的（提示消息窗清了数据但窗口没关，截图底部压着一条）。
- 原版对比发现但不归本期（备查）：Map069 天之上的远景（天空 parallax）重制是黑的；Map067 牛马关有一匹马（事件）重制里没有，可能是 keepEvents 没收。

## 验证

- 选测＋专项＋必跑项，没跑全量。
- 新专项 `xiyou_airship_view` 57/57：停泊默认图（System 的 Vehicle 第 3 格）；上艇逐帧采样高度 0→48 每帧 +1，每帧精灵位置＝格子位置−高度、影子在格子位置（−6）、透明度＝高度÷48、层级（停着 −1；升空后 11 > 上层图块 10、影子 12）、飞艇与玩家位置重合、跟随者透明与玩家一致；飞行中点前方一格飞过去不降落；空中存读档；323 换直升机（SF_Vehicle 3）马上显示、存读档后还是直升机；点脚下降落逐帧 48→0；降落中（高度 30）、升空中（高度 20）存读档读回高度一致并接着降／升；萌物（! 物件图）影子不上移。
- 截图对照（`xiyou_airship_view -- --out=<目录>` 非无头；原版 `ui_reference/serve.py`＋内置浏览器，静音）：`04_验证/本地结果/原版参照/airship3/`（不入 Git）。上艇高度 24、飞到 (65,52)、降落高度 24（已换直升机）三张，飞艇与影子位置、透明度、遮挡关系与原版一致；原版读数：高度 24 时 screenY 354、shadowY 378、透明度 127.5、screenZ 5；(65,52) 时 screenY 330、shadowY 378。第一次截图发现升空中跟随者露出来（原版跟随者随玩家透明），已修（见上）。
- 选测（`并行测试.py --full`，日志见下）：本期专项 `xiyou_airship_view`、`xiyou_airship_fly`、`xiyou_airship_state`；地图／事件 `xiyou_event_compare`（必跑）、`xiyou_map*`、`xiyou_floor_reach069`／`094`／`106`／`109`／`115`、`xiyou_floor_goblin024`（优先级 2 事件所在图）、`xiyou_floor16_dungeon`、`xiyou_floor_run*`、`xiyou_start_state_walk`、`xiyou_options_basic`（触控点按）、`xiyou_determinism`；传送、挂机、HUD：`xiyou_transfer`、`xiyou_hud`、`xiyou_hangup*`；存档：`xiyou_save_events`、`xiyou_save_page`、`xiyou_autosave`、`xiyou_battleback_save`、`xiyou_flow`、`xiyou_review_regressions`、`xiyou_loose_fixes`；其它：`xiyou_screen_fx`、`xiyou_message`；切片素材名单：`ui_smoke`、`xiyou_mac_export`。结果：39 个场景全部通过，无偶发（日志 `04_验证/本地结果/并行测试/20261030_054629_x18fdc_y/`）。第一次带 `--quiet` 跑时排队等槽一小时没输出，被长任务看门狗判成卡死（见「可优化」），去掉 `--quiet` 重跑。
- 切片只加 extraImages 七张图，不算「新地图、敌群、角色、技能」，没跑 `xiyou_rules`。
- 同步：`同步正式西游.py --accept-additions --accept-changes 04_验证/测量接受/claude_bajie-alien-erode.json` 通过（退出码 0，留了产物指纹）；输入只多 5 张飞艇图；接受的 alien_affix 27→28 是 main 上八戒蚀术那步，不是本车道改的，总装以 main 基线为准。

## 本分支提交

- 2b2590b2 WIP：高度偏移、影子、层级、触控、切片加图
- 114da96b WIP：影子挂飞艇精灵、飞艇速度 6、click_cell、新专项
- 合 main 528dba63
- 6bef65a5 WIP：专项加 --out 截图、交付单现状
- 122a2d59 WIP：跟随者透明改到逻辑帧并在进图时同步
- （本提交）交付单、可合并
