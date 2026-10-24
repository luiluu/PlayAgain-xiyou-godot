# 交付：claude/bajie-pets-source-97efd5

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：进行中

## 范围清单：宠物从哪来（期二）

冻结 v0.28 查到的全部来源。原版宠物＝那只 `Game_Enemy` 实例本身（`$gameParty.Pets`），重制存 `XState.pets.list`（见 `core/pets.gd` 文件头），`XPets.create(敌人, 神话, 字母)` 已照 `Star.PetSystem.GetingPet` 造宠物（八戒_56）。缺的只是「什么时候调它」。

| # | 来源 | 原版入口 | 数据 | 存档字段 | 现状 | 分期 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **战斗捕捉**（唯一真正产出宠物的入口） | 物品 200 捕获网 40%／315 捕获巨网 50%／316 捕获器 60%／317 大师级捕获器 80%（仅战斗、单个敌人）→ 公共事件 173 `Star.PetSystem.PetGet()` | 324 个敌人备注 `<Capture: N%>`；`Scene_Battle.start` 每个敌人按 N% 掷「可捕捉」，名字加「宝宝」；可捕捉的敌人第 5 回合结束还活着就「敌人逃跑」（die＋hide）；PetGet：`随机×100 ≤ 物品成功率` 且目标可捕捉 → GetingPet 入列、目标 die＋hide、提示「捕捉成功」；目标不可捕捉 → 提示「不可捕捉」并退还那件道具；否则「捕捉失败」 | 新增：无（宠物进已有的 `pets.list`；「可捕捉」只在战斗里） | 重制战斗不处理物品的公共事件效果（code 44），用网只扣道具 | 期二 b：要在 `battle_logic.gd` 加挂点（见「提案」），先问总装 |
| 2 | 神秘生物（地图） | 插件参数 PetMap 1～4、12～15；新游戏／读档后每 5 分钟 `isrefreshGTEveWar`（真实时钟每小时 0～4、30～34 分窗口内随机挑一张图开事件独立开关 A；窗口外全关）；地图事件 Map10 EV11、Map12 EV23、Map29 EV3、Map47 EV15、Map64 EV3（PetMap 1～4 的 A/B 图）、奇兽 Map92／93／94／105 → 敌群 1 战斗（`Game_Troop.setup(1)` 强制可捕捉，并记 PetRefDay/Hour/Minute 表示本窗口已打过）；敌群 1 的敌人 ID 由刷新时从 PetEneId 里随机改写 `$dataTroops[1]`（不存档） | Map070 EV2 `$gameParty.PetRef_Capture = true` 后只刷奇兽 12～15（猴山、鹿吴山、猛虎岭、洛水河），否则只刷 1～4 | 新增：`pets.ref_capture`、`pets.ref_day/hour/minute`（`$gameParty.PetRef*`）；事件独立开关用已有的 self_switches | 未做；敌群 1 照数据是嘤嘤怪 | 期二 c（依赖 1：不能捕捉时只是一场普通战斗）。Map92～94／105／70 不在切片（悟空的地图），只做 PetMap 1～4 与开关逻辑，奇兽那几张图等切片 |
| 3 | 宠物仓库（跨存档） | Map041 黄金大厅 EV1 `Scene_StarSaveWarehouse`／`Scene_StarWarehouse`；Map060 荣耀殿堂 EV2 `SavePetToConfig` | `ConfigManager.GetPet`（跨存档，存在 config 里） | 跨存档全局，非存档字段 | Map041／060 不在切片 | 不做，等切片放这两张图再做（地图归悟空） |
| 4 | 宠物合成 | `Star_PetSynthesis` | 两只满级合一只 | 已有 | 已做（八戒_56） | — |
| 5 | 商店／事件奖励／蛋 | **没有**直接给宠物的商店、事件或蛋；商店只卖捕捉道具（Map4 EV6 阿卡拉卖 200／315／316，Map73 卖 316），Map4 EV1 奥尔夫尼开局送 100 个捕获器 | — | — | 生成地图里都在 | — |
| 6 | 宠物相关脚本（不是来源，捕到后才用得上） | 魔兽要诀 物品 343～508 → 公共事件 190～292 `Star.PetSystem.ComEveLearnSkill(技能)`（出战宠物学技能，次数满或已会则退还 `$gameParty._lastItem`）；经验糖果公共事件 241～243（没有物品引用，不做） | — | 已有 `ls`／`ls_max` | 地图上用要诀会记进 skipped | 期二 d（小，脚本分支归八戒） |

另外：捕获器的说明里成功率写死 40%～80%，与 successRate 一致；物品 372「高级灵根」指向公共事件 218（＝高级灵甲术 1673），217「高级林根」(1672) 没有物品引用——原版数据错，记作优化候选（O-098，见下）。

## 提案（期二 b 战斗捕捉要碰 battle_logic.gd，等总装答复）

捕捉逻辑全部放新文件 `core/pet_capture.gd`（XPetCapture），`battle_logic.gd` 只加三处单行挂点：
1. `setup` 建完敌人后 `XPetCapture.roll_battle(self)`：按 `<Capture>` 掷可捕捉（敌群 1 强制可捕捉）。
2. 回合结束（`BattleManager.endTurn` 位置）`XPetCapture.end_turn(self)`：第 5 回合可捕捉且活着的敌人逃跑（die＋hide）。
3. `_apply_effect` 加 `44:` 分支 → 只认公共事件 173 时调 `XPetCapture.capture(self, u, t, item)`（其余公共事件效果仍不处理，和现在一样）。
- 随机数：原版用 `Math.random`。重制不用战斗的 rule 流（会让所有战斗对照的抽取顺序错位），从本场 `master_seed` 派生一条独立的 "pet" 流。
- 名字「宝宝」后缀在 `XEnemy` 显示名或战斗画面取名处加一行。
- 原版缺陷（O-098 候选）：PetGet 读的是全局 `Star.PetSystem.Game_Action`＝本回合**最后一个**调过 setItem 的行动，同一回合有两个角色用道具时，先出手的那张网会用后一件道具的成功率与目标序号判定（目标可能是错的敌人或角色序号）。重制默认按这次行动自己的道具与目标判定，开关可回原版。

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
