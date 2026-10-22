# 交付：claude/bajie-interp

- 车道／工作者：B 界面·工具／八戒（Claude，八戒_47）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】解释器三项：214 查原地图、暂时消除随存档、225 等待先显示文字（dev.待定）

- 起因：交接板「下一步」第 1 条云端审查（dev.049～081）转来的三项，原记在悟空名下，总装改派八戒。
- 先查有无「只靠 214 消除」的事件：冻结数据 237 页事件用到 214，其中 131 页不改任何开关、变量、独立开关，全是副本里的明雷怪（`!Flame`，如 Map008 海岸洞窟事件 3、Map035 破败城堡、Map044、深渊各图），打完 214 消失；公共事件里没有 214；全库没有指令 134（禁止存档），这些图上都能存档。原版 `Game_Event._erased` 随 `$gameMap` 进存档，同版本读档不重设地图（YEP_SaveCore `reloadMapIfUpdated` 只在版本号变了时重载），所以读档后怪仍不在；Godot 之前只在内存里记，读档后怪重新出现、可以反复刷。
- 参照（先补后改）：`mv_oracle/review_fix_probe.cjs` 新增 6 例。`erase.save`（Map008 以事件 3 身份跑 214，JsonEx 存读档后仍消除）、`erase.sameMap`（同图移动不 setup，仍消除）、`erase.otherMap`（去大厅再回来，恢复）、`erase.afterTransfer`（大厅里以事件 3 身份先 201 去 Map008 再 214：`isOnCurrentMap` 为假，Map008 的事件 3 不消除）、`flush.225.wait`／`flush.225.nowait`（316 升级提示进 `$gameMessage` 后，225 勾等待时下一条 122 在第 11 帧执行、等待期间消息已显示；不勾等待时第 1 帧同一帧执行）。旧 32 例逐条不变。
- 修改：
  - `mv_interpreter.gd` 指令 214 加 `map_id == state().map_id`（解释器起跑地图＝当前地图）才消除。冻结数据里没有先 201 再 214 的事件页，属防御性修正。
  - `XState.erased_events`（当前地图上被 214 消除的事件 ID）进存档 `erasedEvents`（旧档没有时为空）；`map_scene.erase_event` 记进去，`load_map` 换到别的地图时清掉、同图移动保留，建事件时按它直接置为消除。
  - `MVEventCore` 先显示待显示文字的判断由 `FLUSH_BEFORE` 再加 `FLUSH_IF_WAIT`（225 只在勾了「等待」时算会等待的指令）。冻结数据 225 共 31 条、勾等待 8 条，没有一条前面有待显示的升级提示，属一致性修正。
- 测试：新专项 `tests/xiyou_interp_review`（11 项）：erase 四例用真实 XMapScene、真实 XSave 存读档后重开地图、真实 transfer 与参照逐字比；flush 两例只推进解释器核心，比提示文字、等级，以及「122 执行前消息是否已显示」对上参照帧号是否大于 1。去掉本期修改时 erase.save、erase.sameMap、erase.afterTransfer、flush.225.wait.order 四项失败。
- 验证：`并行测试.py` 跑 `xiyou_interp_review` 11、`xiyou_battleback_save` 5、`xiyou_dungeon` 6954、`xiyou_event_compare` 5、`xiyou_floor16_dungeon` 25、`xiyou_review_fix` 60、`xiyou_review_fixes` 16、`xiyou_review_regressions` 29、`xiyou_save_page` 40、`xiyou_script` 17、`xiyou_troop_events` 3837／`_b` 3862，全过、无偶发。改了探针，已合 main（dev.128）后在本工作树跑 `同步正式西游.py --accept-additions`：结果「测量不变」、无问题（review_fix 新 6 例已先由探针产出放进本工作树 generated/oracle，同步重跑探针核对一致；总装合并时按指纹核或重跑 review_fix_probe 即得 6 个新增例）。
- 未完成／已知问题：同图场所移动时 Godot 仍重建全部事件（原版 `performTransfer` 同图不 `setup`，事件位置、朝向等都保留），本期只把「消除」这一项按原版保留，其余未改。

## 交接板

- 下一步：第 1 条「云端审查（dev.049～081）转来的小问题」里悟空那三项（214 原地图、225 等待、214 消除读档重现）划掉，写「八戒_47 dev.待定」；另记「同图场所移动 Godot 仍重建事件，原版保留位置朝向，未改」。
- 用户试玩说明：副本里打掉的明雷怪，存档再读档后不会重新出现（原版如此）。
- 需要用户决定：无。

## 进度账

- 无变化（小修）。

## 本分支提交

- WIP: review_fix_probe 补解释器三项参照
- WIP: 解释器三项修改与专项 xiyou_interp_review
- 合并 main（dev.128）
- 交付单：bajie-interp 一期可合并
