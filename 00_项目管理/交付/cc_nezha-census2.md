# 交付：cc/nezha-census2

- 车道／工作者：D 工具／普查／哪吒（cc，重制_哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】事件普查剩余三项确认：122 读敌人数据与 PetGet 已有，补签只剩整个签到系统（dev.待定）

- 结论（先确认真缺，再动手）：
  - **122 读敌人数据 9 种**（变量 318、1341～1348，游戏数据 4＝敌人）：**已有**。`XBattleEventRunner._game_data` 与冻结源 `rpg_objects` 的 gameDataOperand case 4 逐行一致（0 HP、1 MP、2～9＝param(0～7)）；普查战斗版 `CENSUS_BATTLE` 9 条 miss 全空。原先没有读出值的断言，现补。
  - **PetGet 地图侧**：**不存在地图侧**。CE173 只被物品 200／315／316／317（捕获网类）的 44 效果调，使用场合＝战斗（occasion 1）；战斗里 `XBattleEventRunner` 355 分支 → `XPetCapture.pet_get`，有 `pet_capture_probe` 参照与 `xiyou_pet_capture` 专项。普查地图口径认不出只是因为地图解释器不跑它，已按「战斗原生」认下并从已知清单删掉。
  - **ConductItemMakeUpSign**（CE330 补签卡、CE373 补签，物品 632 补签信 使用场合＝菜单）：**真缺，但不是单点**。它依赖整个签到系统（`Star_SignBoard`：真实系统日期、`$gameParty.SignDay／SignMonth／SignDate／MakeUpSignMD`、`Scene_StarSignBoard`、连续签到奖励表），重制里没有签到系统（rg 无签到相关代码，清单里 `SceneManager.push(Scene_StarSignBoard)` 已是 F 类）。单独补这一条只能凭空造「今日未签到→提示并返还」的分支，没有参照也没有意义，**没做**。
- 改动：`tests/xiyou_script_census.gd`（读敌人数据值断言 `enemy_read_*`＋`enemy_reads_seen`；PetGet 并入战斗原生认下）、`tests/fixtures/script_census_known.json`（删 PetGet 一条，已知 142→141）。没改规则／切片／转换器／探针。

## 交接板

- 下一步：「事件普查剩余」一条改为：122 读敌人数据、PetGet 已确认已有；只剩 ConductItemMakeUpSign，它属于整个签到系统。
- 用户试玩说明：无玩家可见变化。
- 需要用户决定：**要不要做签到系统**（真实日期的每日签到＋补签卡／补签信＋7 日／31 日奖励；Mac 单机版是否保留这套联网无关但依赖系统日期的玩法）。不做则 CE330／373 与补签信 632 按「F 类、不适用」处理；做则单开一期，先拿 `mv_oracle` 参照（要能注入日期）。

## 进度账

- 无变动（普查清单收窄，不改完成度）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `语法检查.py` 0 问题；`并行测试.py xiyou_script_census` 18/18（普查 4230 种、认不出 141、原生再次释放＋捕获网 40）。`选测.py main --list` 只列出这一个场景；未跑全量。
- 只读：冻结源 `rpg_objects.js`、`Star_SignBoard.js`，没有写资料库、正式游戏、存档。

## 接续

- 无（三项都已确认；签到系统等用户拍板）。

## 本分支提交

- 见 git log
