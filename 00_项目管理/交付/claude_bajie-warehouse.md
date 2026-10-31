# 交付：claude/bajie-warehouse

- 车道／工作者：B 界面·规则／八戒（Claude，八戒_91）
- 状态：可合并

## 方案修订（对 `提案_星级仓库_20261027.md` 第二节，按沙僧第七期 Q1～Q3、审查第 1 期 B1～B3、C1）

0. 编号：O 号候选按代码与优化登记写成 O-待定-1～5（见下文「变更记录草稿」第 3 条）。
1. **Q1 跨档实例编号**：取出时去掉实例原来的 `instanceId`，交 `register_gear` 按本档 `next_gear_id` 重编号（原版 `Star_Warehouse.js` 取出时也是 `id = $dataWeapons.length` 重分配）。验收：A 档存入 `xg:1`，B 档已有 `xg:1`，取出后两件编号不同、`gear_query` 不漏件。
2. **Q2 防复制**：照原版甲「不防」，乙不做（乙只能处理「读入档与仓库同时有同号」，挡不住「A 存→B 取→读 A 旧档」）。交接板「需要用户决定」不再列。
3. **Q3 声音**：订正提案「存取都不出声」。原版列表继承 `Window_Selectable`，确定时先放普通确定音（Decision1）再调 handler；分类确定、列表确定（含存入失败、点出战宠物、点空格）都只有这一声确定音，没有装备音效也没有蜂鸣；取消放取消音。探针实测每次确定都是 playOk 一声。
3a. **新发现：原版宠物一半用不了**（浏览器参照实测）：宠物是 `Game_Enemy`，没有 `note`；列表选中宠物时 `updateHelp`→`Sprite_ItemHelp`→HelpExtend `getItemExtraDescParams` 读 `item.note.split` 抛 TypeError，正式版在场景 update 里抛出，Olivia_AntiPlayerStress 的 `catchException` 打印错误并 `SceneManager.stop()`——进宠物列表就停机。重制登记 O-待定-5：宠物不出说明卡、照常存取。
3b. **说明窗**：HelpExtend 把 `Window_Help` 换成物品说明卡（帮助窗只剩 400×1、不显示），所以分类窗在 y=1、列表 y=65～720；装备选中时出说明卡（同物品页 `XHelpCard`），提案第一节第 4 条「两行说明窗」作废。
4. **B1 跨档装备带本档引用**：登记 O 号「跨档异化装备」：存入时清掉异化配置（`alien.config = {}`，`actorId`／`partnerId`／`skillId`／`donorId` 都在里面），取出时按本档账本换一个新 `uid`（`alien-<sequence+1>`），玩家到工坊重配。回退开关 `XStarWarehouse.o_alien_reset = false`：照原版原样带走（取出后说明卡显示「配置失效」）。验收：存入后配置为空、取出后 uid 不与本档已有的异化装备相同；开关关掉时配置原样。
5. **B2 供体／异化／锁定装备**：原版存放直接 `delete $gameParty._weapons[id]`，不经 `loseItem`，只挡 `<PushDct>`。重制：
   - 异化装备本身：照原版能存（配置按第 4 条处理）。
   - 锁定装备（名字带「[锁定]」）：照原版能存（锁定只防卖、分解，搬去别的档不是毁掉）。
   - 被吞器占用的供体、正在待选重抽的异化装备：登记 O 号挡下，提示「不可存放」（同 PushDct）。理由：供体存走后吞器下场开战即卸下；待选重抽的装备存走后账本里的待选永远落空、工坊卡住。回退开关 `XStarWarehouse.o_block_bound = false`：照原版放行。
   - 身上穿着的不列（照原版，只列背包）。
6. **B3 宠物序号**：`rg` 过全工程 `XPets.`／`.pets` 用法：持久按序号记的只有 `pets.war`（出战序号），`release` 已修正；`team_a` 是出战栏位序号；宠物页的合成选择用对象引用（`is_same`），且仓库画面打开时宠物页不在。宠物字典只有本只的数据（敌人 ID、加成、技能、经验），跨档不带本档引用。存宠物走 `XPets.release`；取出 append 到末尾。
7. **C1 PH 仓库存供体**：原版 `PH_Warehouse.js` 先 `deposit` 再 `loseItem`，供体被 Adv:88 挡下就留在背包、仓库里也多一份（复制）；重制 `XWarehouse.deposit` 照常移走。补登记 O 号，回退开关 `XWarehouse.o_reserved_no_dup = false`：供体存入后背包里照样留一件（复制一份进仓库）。
8. **存取立即写盘**（Kyo 默认）：登记 O 号。回退开关 `XStarWarehouse.o_save_now = false`：存取只改内存，等下一次局外配置写盘（`XConfig._write`）时一起写，照原版。
9. **不做期二**：Map060 荣耀殿堂经悟空 c75e 盘点是死图、不移植，所以「设为给予装备」「通关存入」（提案第一节 B、C）不做；通关加成 D 也不做。

## 变更记录草稿

## 2026-10-31 【Claude·八戒_91·未经审查】星级仓库（通用跨存档仓库）期一；Map041 黄金大厅入切片（dev.待定）

1. **星级仓库**（Star_Warehouse 的 A 部分；方案 `提案_星级仓库_20261027.md`，按沙僧第七期 Q1～Q3、审查第 1 期 B1～B3／C1 修订，修订见本交付单「方案修订」）：
   - 数据 `XStarWarehouse`（`modes/xiyou/core/star_warehouse.gd`）：跨存档文件 `<存档目录>/star_warehouse.json`（`{version, mode, gear, pets}`，整份存装备实例与宠物字典；按路径只读一次，损坏按空处理，先写 .tmp 再改名，跟随 `XSave.dir_override`）。存入只收背包装备（防具在前，各按本体、编号）与非出战宠物；`<PushDct>` 提示「不可存放」；取出时去掉原实例编号按本档重编号（Q1），宠物追加在末尾，存宠物走 `XPets.release` 修正出战序号。复制照原版不防（Kyo 默认甲）。
   - 画面 `XStarWarehouseScene`（`modes/xiyou/ui/star_warehouse.gd`，`save_mode` 一个画面两用）：分类窗 (0,1,1280,64)「装备／宠物」，列表 (0,65,1280,655) 两列、行高 36、17 行；装备图标＋品质色名字，宠物只写名字（存放列 `XPets.pet_name`，带「[出战]」；取出列原名、不去稀有度标签）；只有普通确定音；装备出说明卡，宠物不出（O-待定-5）。
   - 入口：`mv_script.gd` 认 `SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse)` 两句脚本，`map_scene.gd` 加 `open_star_warehouse(save_mode)`；同一句写成插件指令照原版无操作；`PHWarehouse create <通用仓库>` 照旧建出用不到的 PH 仓库。
   - `xiyou_slice.json` 加 Map041（EV1 管理员、EV2 回 Map040），说明里那句「41 等星级仓库」改掉。
   - `mv_event_core.gd` `_plugin_command` 加一支：Map041 EV1 误写成插件指令的 `SceneManager.push(Scene_StarSaveWarehouse)` 认作无操作（原版也没插件认它；覆盖检查原报「未翻译」）。`xiyou_event_compare` 的宿主加 `open_star_warehouse` 记场景名（新用例 m41e1p0）。
2. **参照**：新探针 `mv_oracle/star_warehouse_probe.cjs`（入同步表 `star_warehouse.json`）在正式引擎建出两个画面，用列表 `processOk` 逐件存入（普通、PushDct、锁定、吞器供体、吞器异化）、宠物（出战、普通）、换局后取出、空格确定，记列表、背包、仓库、声音、提示、`ConfigManager.save` 次数（0）；浏览器参照页 `ui_reference/review_system_pages.js` 加 `star_warehouse`（9 态，压成 `tests/fixtures/star_warehouse_oracle.json`，`review_system_pages.py` 身份表加 Star_Warehouse.js）。
3. **优化登记**（都可回退，`优化登记.md` 末五行）：O-待定-1 存取立即写盘（`o_save_now`）；O-待定-2 跨档异化装备存入清配置、取出换 uid（`o_alien_reset`，审查 B1）；O-待定-3 挡下吞器供体与待选重抽的异化装备（`o_block_bound`，审查 B2）；O-待定-4 PH 仓库存供体不复制（`XWarehouse.o_reserved_no_dup`，审查 C1，补登记）；O-待定-5 宠物列表不报错（原版进宠物列表即停机）。
4. **专项 `xiyou_star_warehouse`**（78 项）：画面 9 态逐字对浏览器参照（文字、坐标、宽、字号、颜色、窗口矩形、光标、说明卡有无、仓库／宠物数据）；存取 18 步对探针（三开关切原版时全同；默认开时只有供体一步不同，另断言）；Q1 两档同号取出不撞号、gear_query 两件都在；待选重抽挡下与回退；写盘重读、损坏、路径；o_save_now 关时不写、`XConfig._write` 时才写；PH 仓库存供体两态；Map041 的三行脚本只开两次画面（存放、取出）。
   - 反向验证：去掉取出时的重编号 → `q1_renumbered`、两支 `renumbered_unique` 共 3 项失败；三个开关各有原版支与优化支的断言互为反证。已还原。
   - 审查 B3（`rg` 宠物序号）：持久按序号的只有 `pets.war`（`release` 已修正）；`team_a` 是出战栏位序号；宠物页合成选择用对象引用；宠物字典不带本档引用。

## 交接板

- 下一步：星级仓库期一已交；期二（设为给予装备、通关存入、通关加成）随 Map060 荣耀殿堂，悟空 c75e 盘点为死图、不移植，不做。
- 用户试玩说明：黄金大厅（方桌大厅往上 Map040 进去）的通用仓库管理员能存放／取出装备和宠物，跨存档共用；存入后立即写盘。带异化配置的装备存入时配置清空、取出后到工坊重配；被吞器占用的供体存不进去。
- 需要用户决定：O-待定-1～5 去留（默认都开）；复制问题照原版不防（Kyo 默认甲，不再列）。

## 进度账

- 地图：切片加 Map041 黄金大厅。
- 系统：星级仓库（通用仓库）期一完成；期二不做（随 Map060 不移植）。

## 可优化（流程／工具／效率）

- 已做：无。
- 建议：`ui_reference/review_system_pages.js` 的各页读数要手工压成 fixture（这次照角色仓库手写了一段压缩），可以给 `review_system_pages_compare.py` 加一个「按页名压成 tests/fixtures/<页>_oracle.json」的子命令，省每次手写（预计每页省一刻钟，归工具车道）。

## 待交叉核查

- 新文件：`core/star_warehouse.gd`、`ui/star_warehouse.gd`、`tests/xiyou_star_warehouse.gd`、`mv_oracle/star_warehouse_probe.cjs`。
- A 车道文件（小改，请总装留意）：`core/mv_event_core.gd`（`_plugin_command` 一支无操作）、`tests/xiyou_event_compare.gd`（宿主一个方法）。
- 改动：`core/warehouse.gd`（`deposit` 的 O-待定-4 原版支）、`core/xconfig.gd`（`_write` 开头一行 `flush_pending`）、`map/mv_script.gd`、`map/map_scene.gd`、`xiyou_slice.json`（Map041）、`同步正式西游.py`（探针表一行）、`ui_reference/review_system_pages.js／.py`。没改原沙僧核心文件。

## 验证

- 合 main（fa29dc7c，带来 mira_battle_probe 与同步表改动，`同步正式西游.py` 自动合并无冲突）后，`新建工作树.sh --补齐` 与 `同步正式西游.py --accept-additions` 都通过（「新增用例，已接受（不登记）」：events 5806→5808，Map041 两个事件），留了产物指纹。
- `内容覆盖检查.py`：Map041 原报新问题 1（上面的插件指令），认作无操作后 new 0，已 `--update-baseline`（登记无变化）。
- 本机选测 17 个场景：`xiyou_star_warehouse`（78/78）、`xiyou_warehouse`、`xiyou_rules`／`_d1b`／`_d1c`／`_d1d`、`xiyou_pets`、`xiyou_alien_workshop`、`xiyou_alien_config`、`xiyou_actor_warehouse`、`xiyou_global_vars`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_floor_reach040`、`xiyou_transfer`、`xiyou_gear_search` 通过；`xiyou_event_compare` 首轮因新用例 m41e1p0（测试宿主没有 `open_star_warehouse`）退步 1 项，补上宿主方法后 `--only=m41,m40` 7/7 一致、5/5 通过（其余用例首轮已全一致，改动只加了宿主方法）。
- 反向验证：见变更记录草稿第 4 条。
- 没跑全量与非 Godot 检查。

## 没做／差异

- 原版仓库里捕获来的宠物名字后带「宝宝」（`Game_Enemy.Capture`，Star_PetSystem 1178）；重制宠物不记这个标记，取出列表不加「宝宝」。
- 原版存入、取出后光标停在原格，即使那格已空（照做，没有改）。
- 存档时什么也不做：仓库独立于存档（与原版同）。

## 本分支提交

- 2b77df7c 交付单方案修订
- a7afd1d8 原版探针 star_warehouse_probe
- 995d4c15 XStarWarehouse／画面／脚本入口／参照页与专项；Map041 入切片
- d2f565bd O-待定-1～5 登记、交付单草稿
- 1870a488 Map041 插件指令那一行认作无操作
- （本提交）event_compare 宿主补 open_star_warehouse；交付单可合并
