# 交付：cc/tianqi-pet-hide

- 车道／工作者：天启篇·隐藏宠物系统／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.494）切出，不依赖待合的分支；和 cc/tianqi-alien-affix 不碰同一文件，先合哪条都行。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇存档隐藏宠物系统（dev.待定）

- 按设计仓库《天启篇序章_四线异化与异化装备重构 v0.8》第 2.4 节（Kyo 2026-11-08 已确认：天启篇里宠物系统整个不出现，西游照常；做法是隐藏不是删代码）。只认天启篇存档（`XTianqiLine.open_for`，发行构建里还要 `XTianqi.RELEASE_OPEN`）。
- 新模块 `core/tianqi_pet_hide.gd`（XTianqiPetHide，开关 `ENABLED`），照 `XAlienHide` 的口子：
  - 主菜单没有「宠物」（`XMenu.commands`）；地图事件里公共事件 169 的 `SceneManager.push(Scene_PetSystem)` 不开宠物页（`mv_script.gd`）。
  - 战斗：开战不掷可捕捉，敌群 1 也不强制，敌人不会变「宝宝」，也就没有第 5 回合逃跑（`XPetCapture.roll_battle`）。
  - 神秘生物：不刷新，已开的刷新点关掉（`XPetCapture.check` 走 `stop`）。
  - 物品：捕获道具（用公共事件 173 的：捕获网、捕获巨网、捕获器、大师级捕获器）、魔兽要诀（公共事件里调 `ComEveLearnSkill` 的，69 本）、宠物口粮（`Star_PetUpLevel` 的五种）从数据库算出来，得不到（`XState.gain_item` 数量为正时挡下，掉落、事件、商店都经这里）、背包和出售列表不列（`XItemMarks.apply_list`）、商店不上架（`XItemMarks.shop_goods`）。
  - 星级仓库：分类只剩「装备」，宠物那一格不画、选不到（`ui/star_warehouse.gd`）。
- 新专项 `tests/xiyou_tianqi_pet_hide`（21 项）。
- 玩家可见：开发版天启篇存档里看不到宠物菜单、捕获道具、魔兽要诀、宠物口粮、神秘生物和「宝宝」敌人，星级仓库只有装备；西游存档照旧。发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_pet_hide.gd` `XTianqiPetHide.ENABLED`；`core/xstate.gd`（得到）、`core/item_marks.gd`（列表、商店）、`ui/menu.gd`（菜单）、`map/mv_script.gd`（公共事件 169）、`core/pet_capture.gd`（捕捉、神秘生物）、`ui/star_warehouse.gd`（仓库分类）各接一处 | 原版有宠物系统（菜单、捕捉、神秘生物、魔兽要诀、口粮、仓库宠物页） | 天启篇存档里宠物系统的入口全部隐藏 | Kyo 11-08 定天启篇隐藏宠物系统（v0.8 第 2.4 节） | `XTianqiPetHide.ENABLED = false`：天启篇存档也照常有宠物系统 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：设计稿 2.4 节说的「图鉴、成就等提到宠物的地方」要全量搜一遍（本单没做）；宠物合成入口在宠物页里，跟着宠物页一起藏了。
- 用户试玩说明：开发版开一档天启篇：主菜单没有「宠物」；去黄金大厅星级仓库只有「装备」；商店里看不到捕获网、魔兽要诀；开西游存档对照，这些都还在。
- 需要用户决定：无。

## 进度账

- 天启篇（扩展账）：宠物系统隐藏 0 → 菜单、捕捉、神秘生物、物品、星级仓库已藏；图鉴、成就里提到宠物的地方未盘点。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_pet_hide`：21/21。
- 相关专项（Mac，本工作树，`并行测试.py`，18 个场景，439 秒，全部通过）：`xiyou_tianqi_pet_hide`、`xiyou_alien_hide`、`xiyou_event_compare`、`xiyou_event_compare_b`～`_d`、`xiyou_item_list`、`xiyou_pet_capture`、`xiyou_pet_synth`、`xiyou_pets`、`xiyou_shop_buy`、`xiyou_shop_stock`、`xiyou_star_warehouse`、`xiyou_warehouse`、`xiyou_determinism`、`xiyou_tianqi_party`、`xiyou_tianqi_title_flow`、`xiyou_tianqi_opening`。
- 没跑的：`xstate.gd`、`item_marks.gd` 让选测判出四百多个场景；本单在这两处各只加一行受开关和天启篇存档门控的过滤（原版档 `plain_*`、开关 `off_*` 覆盖），其余请总装合并时按选测照常跑。
- 反向验证（`反向验证.py`，单跑本专项）：菜单不藏、得到不挡、照掷捕捉、神秘生物照刷、仓库照两格、口粮不藏，6 处全部咬住（神秘生物那条第一版靠真实时钟没咬住，已改成固定时钟并加原版档对照）。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇隐藏宠物系统：菜单、捕捉、神秘生物、宠物物品、星级仓库宠物页；专项
- 神秘生物断言改固定时钟；交付单
