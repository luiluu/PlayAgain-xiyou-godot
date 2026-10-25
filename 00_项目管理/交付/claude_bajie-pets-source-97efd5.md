# 交付：claude/bajie-pets-source-97efd5

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：进行中

## 范围清单：宠物从哪来（期二）

冻结 v0.28 查到的全部来源。原版宠物＝那只 `Game_Enemy` 实例本身（`$gameParty.Pets`），重制存 `XState.pets.list`（见 `core/pets.gd` 文件头），`XPets.create(敌人, 神话, 字母)` 已照 `Star.PetSystem.GetingPet` 造宠物（八戒_56）。缺的只是「什么时候调它」。

| # | 来源 | 原版入口 | 数据 | 存档字段 | 现状 | 分期 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **战斗捕捉**（唯一真正产出宠物的入口） | 物品 200 捕获网 40%／315 捕获巨网 50%／316 捕获器 60%／317 大师级捕获器 80%（仅战斗、单个敌人）→ 公共事件 173 `Star.PetSystem.PetGet()` | 324 个敌人备注 `<Capture: N%>`；`Scene_Battle.start` 每个敌人按 N% 掷「可捕捉」，名字加「宝宝」；可捕捉的敌人第 5 回合结束还活着就「敌人逃跑」（die＋hide）；PetGet：`随机×100 ≤ 物品成功率` 且目标可捕捉 → GetingPet 入列、目标 die＋hide、提示「捕捉成功」；目标不可捕捉 → 提示「不可捕捉」并退还那件道具；否则「捕捉失败」 | 新增：无（宠物进已有的 `pets.list`；「可捕捉」只在战斗里） | 重制战斗不处理物品的公共事件效果（code 44），用网只扣道具 | 期二 b：要在 `battle_logic.gd` 加挂点（见「提案」），先问总装 |
| 2 | 神秘生物（地图） | 插件参数 PetMap 1～4、12～15；新游戏／读档后每 5 分钟 `isrefreshGTEveWar`（真实时钟每小时 0～4、30～34 分窗口内随机挑一张图开事件独立开关 A；窗口外全关）；地图事件 Map10 EV11、Map12 EV23、Map29 EV3、Map47 EV15、Map64 EV3（PetMap 1～4 的 A/B 图）、奇兽 Map92／93／94／105 → 敌群 1 战斗（`Game_Troop.setup(1)` 强制可捕捉，并记 PetRefDay/Hour/Minute 表示本窗口已打过）；敌群 1 的敌人 ID 由刷新时从 PetEneId 里随机改写 `$dataTroops[1]`（不存档） | Map070 EV2 `$gameParty.PetRef_Capture = true` 后只刷奇兽 12～15（猴山、鹿吴山、猛虎岭、洛水河），否则只刷 1～4 | 新增：`pets.ref_capture`、`pets.ref_day/hour/minute`（`$gameParty.PetRef*`）；事件独立开关用已有的 self_switches | 已做（`XPetCapture.check/refresh/tick`，地图场景每 5 分钟查一次）；Map10／12／29／47／64 的事件已在生成地图里 | 期二 c。Map62／70／92～94／105 不在切片（悟空的地图），奇兽线（ref_capture）要等切片放 Map070 |
| 3 | 宠物仓库（跨存档） | Map041 黄金大厅 EV1 `Scene_StarSaveWarehouse`／`Scene_StarWarehouse`；Map060 荣耀殿堂 EV2 `SavePetToConfig` | `ConfigManager.GetPet`（跨存档，存在 config 里） | 跨存档全局，非存档字段 | Map041／060 不在切片 | 不做，等切片放这两张图再做（地图归悟空） |
| 4 | 宠物合成 | `Star_PetSynthesis` | 两只满级合一只 | 已有 | 已做（八戒_56） | — |
| 5 | 商店／事件奖励／蛋 | **没有**直接给宠物的商店、事件或蛋；商店只卖捕捉道具（Map4 EV6 阿卡拉卖 200／315／316，Map73 卖 316），Map4 EV1 奥尔夫尼开局送 100 个捕获器 | — | — | 生成地图里都在 | — |
| 6 | 宠物相关脚本（不是来源，捕到后才用得上） | 魔兽要诀 物品 343～508 → 公共事件 190～292 `Star.PetSystem.ComEveLearnSkill(技能)`（出战宠物学技能，次数满或已会则退还 `$gameParty._lastItem`）；经验糖果公共事件 241～243（没有物品引用，不做） | — | 已有 `ls`／`ls_max` | 已做（`XPets.learn_book`、`mv_script` 分支；物品页记 `last_item`） | 期二 d |

另外：捕获器的说明里成功率写死 40%～80%，与 successRate 一致；物品 372「高级灵根」指向公共事件 218（＝高级灵甲术 1673），217「高级林根」(1672) 没有物品引用——原版数据错，记作优化候选（O-098，见下）。

## 提案（期二 b 战斗捕捉碰了 battle_logic.gd，已按此实现，等总装认可；不认可就撤掉三行挂点，其余不受影响）

捕捉逻辑全部在新文件 `core/pet_capture.gd`（XPetCapture），`battle_logic.gd` 只加了三处单行挂点：
1. `setup` 末尾 `XPetCapture.roll_battle(self)`：按 `<Capture>` 掷可捕捉（敌群 1 强制可捕捉、记下时间）。
2. `end_turn` 开头（小猫剑圣包装之后）`XPetCapture.end_turn(self)`：第 5 回合可捕捉且活着的敌人逃跑。
3. `_apply_effect` 加 `44:` 分支 → `XPetCapture.item_event`，只认公共事件 173（其余公共事件效果仍不处理，和以前一样）。
- 另外两处小改：`core/enemy.gd` 加 `capture` 字段、`display_name` 加「宝宝」；`battle/battle_scene.gd` 的 `_play` 认 `toast` 记录与 `enemy_change` 的 `vanish`（被捕／逃跑的敌人隐藏），命中记录带的 `events` 接着播。
- 随机数：原版用 `Math.random`。重制不占战斗 rule 流（否则所有战斗对照的抽取顺序会错位），从本场 `master_seed` 派生独立的 "pet" 流。
- 被捕或逃跑的敌人照原版是「HP 0＋阵亡状态＋隐藏」：不算阵亡也不算活着，不给经验、金钱、掉落，全灭判定照常成立（专项已核）。
- 原版 PetGet 读全局 `Star.PetSystem.Game_Action`（最后一个 setItem 的行动）。OTB 下轮到谁谁才输入并立刻行动，读到的就是这次行动本身，重制直接用这次行动的道具与目标，不算缺陷、不登记。

## 优化登记草稿（O-098，三项，都可回退）

- O-098a 神秘生物刷新提示：原版提示开关 `$gameParty.PetShowTextT` 没有任何地方打开，「天生异象，第X层疑似出现神秘生物！！！」永远不弹，玩家无从得知。重制默认弹（`XPetCapture.SHOW_REFRESH_TEXT`），设 false 恢复原版。
- O-098b 第 5 回合逃跑只算活着的：原版判「不算阵亡」，隐藏成员也算——已被捕走的敌人会再弹一次「敌人逃跑」，还没出现的隐藏成员也被「逃跑」掉、之后 335 出现的是 0 血尸体。重制只让活着的逃跑（`XPetCapture.FLEE_ALIVE_ONLY`），设 false 恢复原版。
- O-098c 物品 372「魔兽要诀:高级灵根」：原版指向公共事件 218，教的是 1673 高级灵甲术（与 373 相同），217「高级林根」(1672) 没有物品引用。重制用 372 时改学 1672（`XPets.BOOK_FIX_372`），设 false 恢复原版。

## 变更记录草稿

（待写）

## 交接板

- 下一步：（待写）
- 用户试玩说明：（待写）

## 进度账

- （待写）

## 验证

- （待写）

## 本分支提交

- （待写）
