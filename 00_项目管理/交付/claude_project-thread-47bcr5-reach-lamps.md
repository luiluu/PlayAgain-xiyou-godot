# 交付：claude/project-thread-47bcr5-reach-lamps

- 车道／工作者：A 内容·楼层／悟空_58（Claude，本机收尾云端分支「指路灯四图＋恰兰吉尔」）
- 状态：可合并（#13 已随 main 合入，本分支已合 main 3100604b）

## 变更记录草稿

## 2026-10-26 【Claude·云端＋悟空·未经Codex检验】切片接入指路灯能到的图：黑金村、肝帝之地、牛马关、牛马之森、恰兰吉尔及店铺／挑战者协会（dev.待定）

- 做了什么：`xiyou_slice.json` 的 maps／keepEvents 各加 13 张图，全部事件照原版放（"*"）：黑金村 68、肝帝之地 185、牛马关 67、牛马之森 138（指路灯四图），恰兰吉尔 71、72～74（店铺）、95～99（挑战者协会、图书馆等）。敌群、商店、公共事件由导出器从地图事件与遇敌表自动带入，不需另列。
- 专项 `tests/xiyou_floor_reach068` 在地图场景里真走一遍：指路灯公共事件传送、吞魂魔与涅斐莉入队、肝帝之地传送、牛马关马神残影与符文入口、牛马之森护卫／首领／宝箱、恰兰吉尔武器店／协会／食人魔颅骨换演武令；73／73 全过。南出口通天之上（Map069）未接，传送会读图失败，专项不踩。
- 参照修复：`mv_oracle/event_probe.cjs` 启动后补 `Input.clear()`。参照启动不走 `Scene_Boot` 的 `Input.initialize`，门事件里「玩家移动路线」经 `Game_Player.isDebugThrough` 读 `Input._currentState` 抛 TypeError（m71 EV15／18／26、m99 EV2），修后这 4 例正常跑完。已有用例的测量不受影响（要由同步确认）。
- 同步：`NODE_OPTIONS` 已存在时也给 node 加 10GB 堆上限（Mac 上无影响）。
- 同步（本机，合 main 3100604b 后）：`同步正式西游.py --no-register --accept-additions` 通过，只增新用例（events 107、maps 13、shop_buy 171、alien_battle 19、race_battle 31），既有测量逐条不变，包括 `Input.clear()` 之后的所有既有事件用例，无需接受单。
- event_compare：`FakePlayer` 补 `force_move_route`／`is_route_forcing` 空实现（门事件的玩家移动路线；参照只比指令序列与状态变化）。
- 验证：xiyou_floor_reach068 73／73、xiyou_actor_change 48／48、xiyou_event_compare 5／5、xiyou_rules 难度 1～6 全部 24 段全过；内容覆盖检查 hard 0／new 0，基线已更新（5518 页，未对照 983、出切片 12）；`检查.sh --affected main` 末次复跑结果见合并时的报告。

## 交接板

- 下一步：无新增。
- 用户试玩说明：指路灯能传到黑金村、肝帝之地、牛马关、恰兰吉尔；恰兰吉尔进武器店、挑战者协会与图书馆；牛马之森可打护卫与首领。
- 需要用户决定：无。

## 进度账

- 切片地图：155 → 168 张（+13，相对当前 main）。

## 可优化（流程／工具／效率）

- 已做：event_probe 补 `Input.clear()`（回退：删这一行）。
- 建议：车道的比对基线来自主工作区，主工作区没随 main 同步时，车道会把 main 里别的车道内容当成「既有改变」拒收（本次 地图 140／173／175／179／189、敌群 447～599 等）。总装每次合并后同步主工作区，或 `--补齐` 时提示基线是否落后 main（归总装／工具车道）。

## 本分支提交

- 87e5c5c3 WIP: 切片接入指路灯四图与专项 reach068 草稿
- 5d8e3298 WIP: 切片再接恰兰吉尔 71 与店铺、挑战者协会
- 1326e16b 同步：环境已有 NODE_OPTIONS 时也给 node 加 10GB 堆上限
- 53a412c4 WIP: event_probe 启动后 Input.clear()
