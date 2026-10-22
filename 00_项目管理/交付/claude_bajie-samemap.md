# 交付：claude/bajie-samemap

- 车道／工作者：B 界面·工具（解释器遗留）／八戒（Claude，重制_八戒_48）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒_48·未经Codex检验】同图场所移动不重建事件（dev.待定）

- **原版**：`Game_Player.performTransfer`（rpg_οbjects.js 7654 起）只在新地图 ID 与当前不同或 `_needsMapReload` 时 `$gameMap.setup`；同图只 `locate` 玩家（跟随者 synchronize、makeEncounterCount），事件对象连同位置、朝向、强制移动路线与索引、当前页、事件自己的解释器和地图解释器都保留。启用插件里没有在同图时重建事件的（MapTransferPlugin 只在 performTransfer 后解锁地图；Codex_StabilityPerformancePatch 的 requestMapReload 只用于已删除地图的读档回退；Scene_Map.start 的包装只处理亮度、提示与按钮）。
- **参照**：`review_fix_probe.cjs` 新增 2 例（放在可败战斗之前，旧 38 例逐条不变）。`transfer.sameMap.events`：Map008 事件 3／6 改位置、朝向 8、挂 4 步强制路线推进到第 2 步，事件 3 另挂一个停在 230 等待里的解释器（模拟并行事件），由事件 7 的解释器执行同图 201 到 (28,26) 朝左；事件对象是同一个，全部字段不变，等待解释器的索引和剩余帧不变，地图解释器也是同一个。`transfer.otherMap.events`：换到 Map004 再回 Map008，事件重建，回到初始位置、朝向 2、无强制路线。同步 `--accept-additions` 只新增这 2 例。
- **Godot**：`map_scene.gd` 的 `load_map` 在新地图与当前相同时不再释放图块与事件节点，只重放玩家与跟随者，镜头重新挂到玩家；地图名、自动播放、传送按钮重设、遇敌步数、MapTransfer 解锁、清获得提示照常（对应 Scene_Map 重建与 locate）。原 load_map 后半段拆成 `_place_party`／`_clear_treasure_popups`，换图路径行为不变。dev.129 的 `XState.erased_events` 同图保留、换图清空不变；战斗背景同图保留不变。
- **测试**：`xiyou_interp_review` 加 transfer 两例（11→13 项），逐字段对照参照：事件节点同一个、位置／朝向／页／强制路线与索引、玩家和跟随者位置朝向。为免淡入淡出期间路线自己往前走，两个事件先停处理（参照引擎同样不推进帧）；MV 未强制时 `_moveRoute` 是页面自主路线，Godot 按 `page.moveRoute` 取长度。参照里的事件解释器（并行事件）Godot 无对应，不比：切片地图里没有并行（触发 4）事件。
- **未完成／已知问题**：存档不存事件位置、朝向与路线（原版 `$gameMap` 整个进存档），读档后事件回到初始位置，这是旧差异，本批没改；以后要做需改存档格式，先提案。切片地图共有 40 处同图 201（如 Map008 事件 7、Map034 事件 13／14／22），楼层流程测试全过，未见依赖旧「同图重建」行为的事件。

## 交接板

- 下一步：删掉 dev.129「同图场所移动 Godot 仍重建全部事件」这条未改项；新增（低优先）「存档不存事件位置／朝向／路线，读档后事件回初始（原版整个 $gameMap 进存档），要改存档格式，先提案」。
- 用户试玩说明：同一张地图内的传送（如副本里的传送点）后，地图上已经移动过的事件、被消除的事件保持原状，不再全部回到初始位置。
- 需要用户决定：无。

## 进度账

- 不调整完成度（原版一致性修复）。

## 验证

- 参照：worktree 跑 `同步正式西游.py --accept-additions` 两次：实现前一次，测量变化只有 review_fix.json 新增 2 例（已接受）；合 main 后补齐再跑一次，测量不变，留下产物指纹。
- 专项（并行测试.py，并行 2、共用上限 4）：xiyou_interp_review 13/13；xiyou_review_fix 60/60、xiyou_review_fixes 16/16、xiyou_review_regressions 29/29、xiyou_transfer 38/38、xiyou_battleback_save 5/5、xiyou_dungeon 6954/6954、xiyou_map 175/175、xiyou_event_compare 5/5、楼层 xiyou_floor_run 273/273、_b 332/332、_c 558/558、xiyou_floor16_dungeon 25/25、floor28_dungeon 93/93、floor30_gifts 30/30、floor30_seeker 27/27、floor31_bosses 67/67。无偶发。
- interp_review 首轮 transfer.otherMap 一项因测试取路线长度口径不同失败（Godot 未强制时 `_route` 为空），改测试口径后单跑 13/13；游戏代码未改。
- 合 main（哈基米 dev.131 等）无冲突，新提交未碰本车道文件，未重跑专项。车道不跑全量。

## 本分支提交

- 1dd9fdd review_fix 参照：同图场所移动 2 例
- 同图场所移动不重建事件的实现、interp_review 测试与测试口径修正
- 合 main、交付单
