# 交付：claude/bajie-pets-source-97efd5-2

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：可合并（截至本交付单提交；已合 main 6a28e127）
- 本分支从 claude/bajie-pets-source-97efd5（期二 宠物来源，已标可合并）切出，含期二全部提交；合并时先合期二那张。

## 期一 换装卡战斗外观（八戒_70 提案 1）

- 原版：卡状态（1201 等）的 Custom Apply Effect 记 `_prevBattlerName` 后 `setBattlerImage(卡图)`，Remove Effect 还原；`installCostumePreferencesRuntime` 包装 `Game_Actor.battlerName`（战斗中有卡状态：启用＝卡图，关闭＝自身形态；阵亡等 clearStates 不跑 Remove Effect 时按 stale 分支回自身形态），并包装 `Mx.SuperSVMetaProvider`：卡图生效时去掉角色自身的 sv／SVspeed／SVzs*／Cfdz*／YCyy 标签。
- 重制不翻状态脚本：`core/appearance.gd` `for_battler` 的角色分支改走 `XCostumes.battler_name` 与新增的 `XCostumes.sv_meta`／`active`／`strip_sv`；新增 `XAppearance.battler_key`（「图名」或「图名|card」）与 `for_look`。
- 换图时机：`battle_logic.gd` `view_of` 多记一项 `look`（**纯画面读数，一行**，不影响规则），战斗精灵 `battler_sprite.gd` 每帧比显示中读数的外观键，变了就 `swap_look`（换 Sprite2D 身体的外观，动作与帧接着播；场景外观不换，目前没有角色登记场景外观）。这样换图和状态的显示同步，不会因逻辑先跑一步而提前换。
- 角色 173 饿狼的自身形态按阶段（Garou_Human／Garou_Cosmic）是 `CodexGarou` 的事，归白龙的新角色模块；这里取的是数据库 battlerName。173～175 是仅有带 `<sv:>` 标签的角色（云裳等），卡图生效时去标签已按参照核过（用 174）。

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】换装卡战斗外观接入（dev.待定）

- 战斗中角色带换装卡状态时，精灵显示卡图（设置「角色换装」关掉则显示自身形态）；卡图生效时去掉角色自身的逐帧 SV 标签；状态去掉或阵亡后换回。取法在 `XAppearance.for_battler`（经 `XCostumes`），精灵按显示读数里的外观键换图（`battle_logic.gd` `view_of` 多一项画面读数 `look`）。
- 参照：`costume_probe.cjs` 加 `battle_image`（角色 1 与 174：无卡／卡／关闭／去掉／阵亡／复活／地图上，battlerName 与 SV 标签）；`ui_reference/review_system_pages.js` 加 `battle_costume` 战斗页（原版截图与精灵读数）。
- 验证：`xiyou_costumes` 27/27、新专项 `xiyou_costume_battle`（图、格子、站位与原版一致，关闭换回）；成对截图 `battle_costume_card`。其余见交付单。
- 提交：见交付单「本分支提交」

## 交接板

- 下一步：期三（领袖旗标对位置）等 LeaderFlag 合进 main 的通知。
- 用户试玩说明：学了「变身——」换装卡的角色进战斗会变成卡上的形象（如深渊骑士）；设置「角色换装」里关掉该角色就保持原样。

## 进度账

- 界面·战斗外观：换装卡外观从「只有开关、看不到效果」到战斗里可见。

## 可优化（流程／工具／效率）

- 已做：`review_system_pages.cjs` 可只跑指定页（`node review_system_pages.cjs <目录> battle_costume`），战斗页单独跑不影响其他页；本次只加页，没改驱动。
- 建议：成对截图的 Godot 侧每次都要手写一个「开地图、开战、等指令窗、截图」的专项（xiyou_battle_ui、xiyou_costume_battle 结构几乎一样）。可抽一个 `tests/support/battle_fixture.gd`（地图 5、敌群 2、四人、`--out` 截图、`_until`／`_frames`），新的战斗截图专项只写场面设置与核对。预计每个新战斗截图专项省 60 行；归八戒或哪吒。

## 验证

- 合 main 6a28e127 之前（fa534aaa）：`xiyou_costumes` 27/27、`xiyou_costume_battle` 4/4（窗口模式截图 5/5）、xiyou_appearance 34/34、xiyou_battle*（battle_ui 70/70 等）、xiyou_sequence_visual 70/70、xiyou_mv_animation 21/21、xiyou_popup_overlap 8/8、xiyou_otb、xiyou_determinism 372/372、**xiyou_event_compare 5/5**、xiyou_random_streams 484/484、**xiyou_rules 难度 1 四段全过**、xiyou_pet_capture 42/42、xiyou_combat 34/34；✗ 仅 xiyou_battle_events seal1691 三条（main 上既有，见期二交付单）。
- 合 main 6a28e127（悟空 reach4，切片变了）并 `--补齐` 之后：xiyou_pet_capture、xiyou_pets、xiyou_costume*、xiyou_random_streams、xiyou_script、xiyou_battle_ui、xiyou_party 全过；`xiyou_event_compare` 2 条失败（oracle_cases_complete、no_new_oracle_errors m221e3p0／m4e8p1／ce1344）：主工作区的事件参照 `generated/oracle/events.json` 还是 10-24 22:37 的、reach4 合并后的同步当时正在跑，参照没跟上新切片；本分支没碰事件探针与切片。总装同步完成后按影响面复跑即可。
- 成对截图（标准级）：原版 `review_system_pages.cjs … battle_costume` → `battle_costume_card.png`＋读数；重制 `xiyou_costume_battle -- --out=` → `battle_costume_card.png`。两边狗逍遥都是 Enemy_General_M 侧视图、格子 64×64、站位 (819,230)，其余三人自身形态一致。截图在会话临时目录（已发给用户），未进仓库。
- Map207（奇兽地，reach4 新进切片）只有普通敌群战斗，捕捉走通用 `<Capture>`，期二已覆盖，无需另接。
- 已清理：参照服务已停；测试日志、截图、单跑脚本都在会话临时目录，仓库里没有临时输出。

## 本分支提交

- c8855af0 期一：XAppearance 经 XCostumes 取卡图与 SV 标签取舍，精灵按外观键换图；costume_probe 加 battle_image
- fa534aaa 期一：原版战斗截图页 battle_costume 与专项 xiyou_costume_battle
- 547b6ed5 合并 main
