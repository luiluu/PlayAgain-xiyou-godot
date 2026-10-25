# 交付：claude/bajie-pets-source-97efd5

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：可合并（截至 42078423＋本交付单提交）

## 范围清单：宠物从哪来（期二）

冻结 v0.28 查到的全部来源。原版宠物＝那只 `Game_Enemy` 实例本身（`$gameParty.Pets`），重制存 `XState.pets.list`（见 `core/pets.gd` 文件头），`XPets.create(敌人, 神话, 字母)` 已照 `Star.PetSystem.GetingPet` 造宠物（八戒_56）。缺的只是「什么时候调它」。

| # | 来源 | 原版入口 | 数据 | 存档字段 | 现状 | 分期 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **战斗捕捉**（唯一真正产出宠物的入口） | 物品 200 捕获网 40%／315 捕获巨网 50%／316 捕获器 60%／317 大师级捕获器 80%（仅战斗、单个敌人）→ 公共事件 173 `Star.PetSystem.PetGet()` | 324 个敌人备注 `<Capture: N%>`；`Scene_Battle.start` 每个敌人按 N% 掷「可捕捉」，名字加「宝宝」；可捕捉的敌人第 5 回合结束还活着就「敌人逃跑」（die＋hide）；PetGet：`随机×100 ≤ 物品成功率` 且目标可捕捉 → GetingPet 入列、目标 die＋hide、提示「捕捉成功」；目标不可捕捉 → 提示「不可捕捉」并退还那件道具；否则「捕捉失败」 | 新增：无（宠物进已有的 `pets.list`；「可捕捉」只在战斗里） | 已做（`core/pet_capture.gd`；挂点见「战斗挂点」） | 期二 b |
| 2 | 神秘生物（地图） | 插件参数 PetMap 1～4、12～15；新游戏／读档后每 5 分钟 `isrefreshGTEveWar`（真实时钟每小时 0～4、30～34 分窗口内随机挑一张图开事件独立开关 A；窗口外全关）；地图事件 Map10 EV11、Map12 EV23、Map29 EV3、Map47 EV15、Map64 EV3（PetMap 1～4 的 A/B 图）、奇兽 Map92／93／94／105 → 敌群 1 战斗（`Game_Troop.setup(1)` 强制可捕捉，并记 PetRefDay/Hour/Minute 表示本窗口已打过）；敌群 1 的敌人 ID 由刷新时从 PetEneId 里随机改写 `$dataTroops[1]`（不存档） | Map070 EV2 `$gameParty.PetRef_Capture = true` 后只刷奇兽 12～15（猴山、鹿吴山、猛虎岭、洛水河），否则只刷 1～4 | 新增：`pets.ref_capture`、`pets.ref_day/hour/minute`（`$gameParty.PetRef*`）；事件独立开关用已有的 self_switches | 已做（`XPetCapture.check/refresh/tick`，地图场景每 5 分钟查一次）；Map10／12／29／47／64 的事件已在生成地图里 | 期二 c。Map62／70／92～94／105 不在切片（悟空的地图），奇兽线（ref_capture）要等切片放 Map070 |
| 3 | 宠物仓库（跨存档） | Map041 黄金大厅 EV1 `Scene_StarSaveWarehouse`／`Scene_StarWarehouse`；Map060 荣耀殿堂 EV2 `SavePetToConfig` | `ConfigManager.GetPet`（跨存档，存在 config 里） | 跨存档全局，非存档字段 | Map041／060 不在切片 | 不做，等切片放这两张图再做（地图归悟空） |
| 4 | 宠物合成 | `Star_PetSynthesis` | 两只满级合一只 | 已有 | 已做（八戒_56） | — |
| 5 | 商店／事件奖励／蛋 | **没有**直接给宠物的商店、事件或蛋；商店只卖捕捉道具（Map4 EV6 阿卡拉卖 200／315／316，Map73 卖 316），Map4 EV1 奥尔夫尼开局送 100 个捕获器 | — | — | 生成地图里都在 | — |
| 6 | 宠物相关脚本（不是来源，捕到后才用得上） | 魔兽要诀 物品 343～508 → 公共事件 190～292 `Star.PetSystem.ComEveLearnSkill(技能)`（出战宠物学技能，次数满或已会则退还 `$gameParty._lastItem`）；经验糖果公共事件 241～243（没有物品引用，不做） | — | 已有 `ls`／`ls_max` | 已做（`XPets.learn_book`、`mv_script` 分支；物品页记 `last_item`） | 期二 d |

另外：捕获器的说明里成功率写死 40%～80%，与 successRate 一致；物品 372「高级灵根」指向公共事件 218（＝高级灵甲术 1673），217「高级林根」(1672) 没有物品引用——原版数据错，记作优化候选（O-098，见下）。

## 战斗挂点（总装 2026-10-25 批准；沙僧以后改 battle_logic.gd 时请保留）

改 battle_logic.gd：2 行挂点，均调用 XPetCapture；另 1 行在 battle_scene.gd。捕捉逻辑全在 `core/pet_capture.gd`（XPetCapture）。
1. `battle_logic.gd` `end_turn` 开头（小猫剑圣包装之后、各成员回合结束之前）`XPetCapture.end_turn(self)`：第 5 回合可捕捉且活着的敌人逃跑。
2. `battle_logic.gd` `_apply_effect` 的 `44:` 分支 → `XPetCapture.item_event`。**战斗中物品的公共事件效果（code 44）只接了 173（捕捉），通用的还没做**，其余公共事件照旧不处理，留作后续。
3. `battle_scene.gd` `setup` 里 `logic.setup` 之后 `XPetCapture.roll_battle(logic)`：开战掷可捕捉。原批准是放在 `battle_logic.setup`；原版这一步在 `Scene_Battle.start`（画面层，不在 `BattleManager.setup`），放在 logic 里会让只建 logic 的规则测试也掷骰、敌人名字带「宝宝」（`xiyou_battle_events`、`xiyou_combat` 按参照名字对照，参照不跑 Scene_Battle.start），所以挪到画面开场，更贴原版，battle_logic 也少一处。
- 挂点单独一个提交（42078423；首版挂点曾随 7cdb9c4e 进来，42078423 是挪位后的定稿）。
- 另外两处小改：`core/enemy.gd` 加 `capture` 字段、`display_name` 加「宝宝」；`battle_scene.gd` 的 `_play` 认 `toast` 记录与 `enemy_change` 的 `vanish`（被捕／逃跑的敌人隐藏），命中记录带的 `events` 接着播。
- 随机数：原版 `Math.random`。照现有独立流的做法在 `XBattleRandom` 注册命名流 "pet"（`derive(本场种子, "pet")`，快照多一项 `pet`；旧快照没有时按种子派生），rule／reward 取数顺序不变（专项 `pet_stream_separate`、`xiyou_random_streams`、规则难度 1 四段）。
- 第 5 回合逃跑（参照一例 `order`）：逃的是**每只**可捕捉且活着的敌人（不是全体），各弹一次「敌人逃跑」；原版包装链从外到内 Hubris → Heartsteel → BlackFlash → Mira → Raven（这几个是角色专属的前置代码，重制还没有）→ **Star 逃跑** → YEP → 原版 endTurn（各成员 onTurnEnd：毒伤、再生、状态回合）。所以逃跑先于毒伤：中毒的可捕捉敌人直接逃走、不扣血；中毒的不可捕捉敌人照常扣 10%。重制顺序 XCat → 逃跑 → turn_end_battler，一致。
- 被捕或逃跑的敌人照原版是「HP 0＋阵亡状态＋隐藏」：不算阵亡也不算活着，不给经验、金钱、掉落，全灭判定照常成立（专项已核）。
- 原版 PetGet 读全局 `Star.PetSystem.Game_Action`（最后一个 setItem 的行动）。OTB 下轮到谁谁才输入并立刻行动，读到的就是这次行动本身，重制直接用这次行动的道具与目标，不算缺陷、不登记。
- 学习次数上限（extraLSMax）原版在建敌人时掷，重制捕到时掷（分布相同，只是取数时机不同）。
- 参照：`03_转换工具/mv_oracle/pet_capture_probe.cjs`（只写 `.sandbox/`）→ 夹具 `tests/fixtures/pet_capture_oracle.json`（记 Star_PetSystem.js 的 SHA，正式版改了要重跑）；不在 `同步正式西游.py` 的 PROBES 里。

## 优化登记草稿（O-098，三项，都可回退）

- O-098a 神秘生物刷新提示：原版提示开关 `$gameParty.PetShowTextT` 没有任何地方打开，「天生异象，第X层疑似出现神秘生物！！！」永远不弹，玩家无从得知。重制默认弹（`XPetCapture.SHOW_REFRESH_TEXT`），设 false 恢复原版。
- O-098b 第 5 回合逃跑只算活着的：原版判「不算阵亡」，隐藏成员也算——已被捕走的敌人会再弹一次「敌人逃跑」，还没出现的隐藏成员也被「逃跑」掉、之后 335 出现的是 0 血尸体。重制只让活着的逃跑（`XPetCapture.FLEE_ALIVE_ONLY`），设 false 恢复原版。
- O-098c 物品 372「魔兽要诀:高级灵根」：原版指向公共事件 218，教的是 1673 高级灵甲术（与 373 相同），217「高级林根」(1672) 没有物品引用。重制用 372 时改学 1672（`XPets.BOOK_FIX_372`），设 false 恢复原版。

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】宠物来源：战斗捕捉、神秘生物刷新、魔兽要诀（dev.待定）

- 盘点冻结源的宠物来源（交付单范围清单）：唯一产出宠物的是战斗里用捕获网（公共事件 173 PetGet）；神秘生物是按真实时钟刷出的敌群 1 战斗（也要捕）；跨存档宠物仓库所在地图不在切片；没有商店、蛋或事件直接给宠物。
- 新 `core/pet_capture.gd`（XPetCapture）：开战按 `<Capture>` 掷可捕捉（名字加「宝宝」），第 5 回合可捕捉的敌人逃跑，捕捉道具成功造宠物入列／失败／不可捕捉退还，被捕和逃跑的敌人 die＋hide 不给奖励；神秘生物每 5 分钟检查（每小时 0～4、30～34 分），开对应地图事件的独立开关、改敌群 1 的敌人。挂点：battle_logic.gd 2 行、battle_scene.gd 1 行（总装批准，见交付单「战斗挂点」）；`XBattleRandom` 加 "pet" 流。
- 战斗中物品的公共事件效果只接了 173，通用的还没做。
- 魔兽要诀（公共事件 190～292 `ComEveLearnSkill`）：出战宠物学技能，失败按 `last_item` 退还；物品页使用道具时记 `last_item`。
- 优化 O-098 三项（可回退）：神秘生物刷新提示照弹、只让活着的敌人逃跑、物品 372 改学 1672。
- 验证：新专项 `xiyou_pet_capture`（对照 `pet_capture_probe.cjs` 参照）；相关专项见交付单。
- 提交：见交付单「本分支提交」

## 交接板

- 下一步：宠物出战加成接进角色能力仍归沙僧 actor-bonus 期；战斗中通用的物品公共事件效果未做；奇兽线（Map070／92～94／105）与宠物仓库（Map041／060）等切片放图后再接。
- 用户试玩说明：大厅奥尔夫尼送的捕获器、阿卡拉卖的捕获网，在战斗里对名字带「宝宝」的敌人使用即可捕捉，捕到的在主菜单「宠物」里；可捕捉的敌人撑到第 5 回合结束会逃跑。每小时整点和半点后 5 分钟内，五层／八层／十三层／十九层会刷出神秘生物（火焰图标，调查开战）。魔兽要诀可以给出战宠物学技能。

## 进度账

- 养成·宠物：宠物从「拿不到」变成可经捕捉获得，菜单、出战、喂养、合成、学技能整条线可走通；完成度由总装按进度账口径定。

## 可优化（流程／工具／效率）

- 建议：只产出测试夹具、不进 `同步正式西游.py` PROBES 的探针（如 otb_probe、本次 pet_capture_probe）也算进转换工具指纹（tools_digest 统计 03_转换工具 下全部跟踪文件），改一个这样的探针就要整轮同步（约 11 分钟以上）。可在 `READ_ONLY_TOOLS` 或单独名单里排除「夹具型探针」（或放到 `mv_oracle/fixtures/` 子目录统一排除）。预计每次省一轮同步；归哪吒（D 工具）。
- 建议：测试里「跑单个场景、出结果或脚本错误就停」的小脚本（我在临时目录写了一个）可做进 `并行测试.py --one <场景>`：现在单跑一个场景要么等并行队列、要么手写 godot 命令，脚本报错时 headless 不退出会一直挂着。归哪吒。

## 验证

- 新专项 `xiyou_pet_capture` 42/42（对照 `pet_capture_probe.cjs` 冻结 v0.28 参照：324 个门槛、开战掷骰与「宝宝」名、敌群 1、第 4／5／6 回合、逃跑先于毒伤一例、捕捉成功／失败／不可捕捉、神秘生物刷新 12 种时钟情形、魔兽要诀 5 种；外加 pet 流不动 rule／reward、快照往返、战斗里实际用网与第 5 回合逃跑）。
- `并行测试.py`（合 main dev.170 之后，42078423）：xiyou_pet_capture、xiyou_pet_synth（⚠ 并行时偶发失败一次，单跑通过，累计 1 次）、xiyou_pets、xiyou_random_streams 484/484、xiyou_battle*、xiyou_combat、xiyou_troop_events／_b、xiyou_otb、xiyou_determinism、xiyou_drop_record、xiyou_drop_dh、xiyou_settlement、xiyou_enemy_book、xiyou_item_use、xiyou_script、**xiyou_event_compare 5/5**、**xiyou_rules 难度 1 四段**（101600／101542／101385／101422 全过）、xiyou_floor_fortress029、xiyou_smart_ai 四段、xiyou_interp_review、xiyou_map*：除下条外全过。
- ✗ `xiyou_battle_events` seal1691 三条（开战加状态卸封印装备）失败：把工作树的游戏代码临时换回 main（dev.170）单跑同样失败 105/108，是 main 上的既有问题，与本车道无关（请总装转给相关车道）。
- 第一次跑时 `xiyou_battle_events` names.elite_mixed、`xiyou_combat` elite_name／plain_params_oracle 因开战掷骰放在 logic.setup 而带上「宝宝」；挪到战斗画面开场后都过。
- 没跑 `同步正式西游.py`：新探针只产测试夹具、不在 PROBES，转换产物不变；但它是 03_转换工具 下的跟踪文件，工具摘要会变（见「可优化」第一条）。
- 临时输出：测试日志与单跑脚本都在会话临时目录，未写进仓库；`mv_oracle/.sandbox/pet_capture.json` 是探针产物（.sandbox 不入 Git）。

## 本分支提交

- b1f85f01 交付单：宠物来源范围清单与战斗捕捉挂点提案
- 7cdb9c4e 宠物来源：战斗捕捉与神秘生物刷新（XPetCapture）、参照探针与专项
- d24e6afd 神秘生物 5 分钟刷新接进地图、魔兽要诀学技能（O-098c）、物品页记 last_item
- 883e2e90 WIP: 交付单补提案与优化登记草稿
- 72b7ee2d 合并 main（dev.170）
- 8368e4e1 pet 随机流注册进 XBattleRandom、第 5 回合逃跑先于回合结束的参照一例
- 42078423 挂点：battle_logic.gd 两行＋battle_scene.gd 一行，均调用 XPetCapture
