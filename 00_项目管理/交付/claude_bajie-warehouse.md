# 交付：claude/bajie-warehouse

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_66）
- 状态：可合并
- 期一：角色仓库（上一期装备道具仓库 0ae13bff 另行合并）

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】大厅三界面：角色仓库（dev.待定）

- 生效链：Map4 EV8 第 1、2 页「角色仓库」都是脚本 `SceneManager.push(Star_Scene_ActorWarehouse);`（全游戏只这两处）。存取全在 Star_ActorWarehouse；退出时 Star_SkilsShare／Star_JiBanSiklls／Star_LeadActor 包了 `cancelNowScene` 刷新共享技能、羁绊和领袖技能；installImportedBalanceRuntime 让停用角色（143／144／145／157／160）在名单里名字半透明、不可确定（蜂鸣）。YEP「Lock First Actor」为 false，原版没有「主角不能存」，唯一限制是队伍只剩 1 人时不能存。
- 新 `core/actor_warehouse.gd`（XActorWarehouse）：存入＝编号进仓库末尾、从队伍去掉；存的是出战成员时原版 splice 掉 `_battleMembers`（变短），下一次按队伍前 5 人重建出战栏，所以候补会补上来；取出＝追加到队伍末尾（不重排、不进出战栏）；出战栏前 4 格全空时把队伍第 1 人放进第 1 格；仓库列表先滤掉已在队伍的编号。
- 新存档字段 `XState.saved_actors`（存档键 `saveactors`，同原版 `$gameParty._saveactors`），旧档没有为空仓库；角色本身一直在 `actors` 里随存档。沿用期二仓库「另起一个存档键、旧档读空」的做法，没有改期二的 `phwarehouse` 结构。
- 新界面 `ui/actor_warehouse.gd`（XActorWarehouseScene）：说明窗被 Sprite_ItemHelp 顶替（高 1、不显示），标题 (0,6,1280,64)「角色仓库」#FFFF00、指令 (0,81,1280,64)「存入／取出」、名单 (0,145,1280,575) 行高 36；名单一行与整队名单相同（`XPartyScene.paint_actor_row`，从整队页抽出共用）。名单跟着指令窗当前项显示，开场选第 1 行不活动；确定后光标不动，存掉最后一行时停在空行。
- 宠物：Star_PetSystem 出战／休息也给仓库里的角色学会／忘掉宠物技能，`XPets._apply_skills` 补上仓库里的角色。
- 优化 O-091（待用户决定）：光标在空行时确定，原版把 undefined 写进仓库或队伍（写坏存档），重制蜂鸣不动；只剩 1 人时原版是浏览器原生 alert，重制改成游戏内提示（同一句话）。
- 接线：`mv_script.gd` 认 `SceneManager.push(Star_Scene_ActorWarehouse)` 交宿主，`map_scene.gd` 新增 `open_actor_warehouse`（关闭后刷新队首行走图与事件页，同原版 `$gamePlayer.refresh／$gameMap.requestRefresh`）；`xiyou_event_compare` 记录宿主补 `open_actor_warehouse`。事件对照基线里没有 EV8 的条目（对照只走选项默认的第 1 项「装备道具仓库」，期二已删 m4e8p0），本期无需删基线。
- 参照：`review_system_pages.js` 新增 `actor_warehouse` 页（队伍 1/8/9/10/11/12、仓库 [13,143]，真按存入 8、存入最后一行 12、取出 13、停用 143 确定，7 个截图状态，附队伍、出战栏、仓库、名单数据与半透明读数），压成 `tests/fixtures/actor_warehouse_oracle.json`；成对截图目视一致。
- 验证：`xiyou_actor_warehouse` 26/26（7 个状态的全部窗口文字与矩形、光标、名字半透明、队伍／出战栏／仓库／名单；空行蜂鸣、只剩 1 人、停用角色、存候补不重建出战栏、取出追加、滤掉已在队伍的、前 4 格全空、存读档与旧档、宠物技能、EV8 两页脚本）；其余见下「验证」。
- 未做：退出时的技能共享、羁绊、领袖技能刷新——这三套系统重制还没有移植（整队页同样没有刷新），等它们移植时在整队完成与角色仓库关闭两处一起接；新游戏里事件加入停用角色时原版 Codex 拒绝入队、读档时把队伍里的停用角色挪进仓库（migrateParty），重制的 `XState.add_actor` 还没有这条判断，留作后续。

## 交接板

- 下一步：期三更衣（Map4 EV17 Scene_ChangeClothes，事件对照 m4e17p0／p1）；技能共享／羁绊／领袖技能移植后接到整队完成与角色仓库关闭；`add_actor` 拒收停用角色、读档迁移（migrateParty）。
- 用户试玩说明：方桌大厅仓库管理员「角色仓库」可以把队员存进仓库、再取回来，随存档保存；队伍至少留 1 人，停用角色不能取出。

## 进度账

- 界面：大厅未接界面 1.5 → 1（角色仓库已接；更衣未做）

## 本分支提交

- 4ea02596 角色仓库 XActorWarehouse／界面／参照页 actor_warehouse／专项
- （之后）专项画布替身签名修正；合并 main；交付单（本提交）

## 验证

- 已合 main（无冲突；带进来的提交没碰切片、转换器与探针，不重跑同步）。
- `并行测试.py` 相关专项全部通过：`xiyou_actor_warehouse` 26/26、`xiyou_party` 57/57（整队名单行抽成共用函数）、`xiyou_pets` 29/29、`xiyou_pet_synth` 26/26（宠物技能补仓库角色）、`xiyou_warehouse` 27/27、`xiyou_event_compare` 5/5、`xiyou_flow` 48/48、`xiyou_determinism` 372/372（存档新字段）。
- 成对截图：原版在工作树 `04_验证/本地结果/原版参照/角色仓库/aw_*.png`，Godot 同态在其下 `godot/`（`xiyou_actor_warehouse -- --out=<目录>`）；随工作树清理删除。
- 已清理：参照服务日志与来源身份临时文件、旧长任务日志已删，只留成对截图与读数。
