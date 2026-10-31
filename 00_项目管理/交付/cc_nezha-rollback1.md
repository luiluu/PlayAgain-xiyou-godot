# 交付单：cc/nezha-rollback1（哪吒_12，回退支补测试 期一）

- 状态：可合并
- 执行者：cc（哪吒_12）；从 tools26 末端 6297765f 切出，**须在 tools23～26 之后合**。没合 main（main 还在合 bailong-garou2）。
- 本期补了 9 个开关的回退支测试：O-101、O-102、O-103、O-080、O-013、O-014、O-007、O-008、O-107。`回退开关覆盖.py`：覆盖从 24 升到 33，缺口从 37 降到 28（新增缺口 0）。

## 改了哪些文件

- const 改成 static var（默认值不变；rg 全工程连 tests 一起查过，全是读取，没有常量表达式或参数默认值引用它们）：
  - `modes/xiyou/ui/help_card.gd`：`MIN_FONT`、`PLACE_NEAR`
  - `modes/xiyou/battle/battle_scene.gd`：`POISON_HELP_NEAR`（只改这一行，不是战斗核心）
  - `modes/xiyou/core/pets.gd`：`SYNTH_CLAMP_SKILLS`
  - `modes/xiyou/core/map_transfer.gd`：`PREVIEW_FIXED_NORMAL`、`REQUIRE_UNLOCK`
- 测试：`tests/xiyou_pet_capture.gd`、`xiyou_pet_synth.gd`、`xiyou_transfer.gd`、`xiyou_help_card.gd`、`xiyou_battle_ui.gd`。每条都是：设成回退值，断言原版行为，再恢复默认值。
- `07_开发环境/回退开关豁免.json` 删掉这 9 项。

## 各开关的回退断言

| 编号 | 开关 | 断言依据 |
| --- | --- | --- |
| O-101 | `XPetCapture.SHOW_REFRESH_TEXT = false` | 对 mv_oracle 参照 `pet_capture_oracle.json` 的刷新例（参照是打开 PetShowTextT 录的）：开关和敌群 1 照参照；存档 `pets.show_text` 为假时一条提示都没有，为真时提示与参照相同 |
| O-102 | `XPetCapture.FLEE_ALIVE_ONLY = false` | ①参照的第 4／5／6 回合场景逐项与参照相同（倒下的那只本来就不逃）；②战斗里先捕走一只，第 5 回合三只都提示「敌人逃跑」（原版判的是「不算阵亡」） |
| O-103 | `XPets.BOOK_FIX_372 = false` | 用物品 372 学到的是 1673（高级灵甲术），提示是该技能名＋「学习成功」 |
| O-080 | `XPets.SYNTH_CLAMP_SKILLS = false` | 期望是用冻结 v0.28 `Star_PetSynthesis.js` 的原函数 `getRandomArrayElements` 在 node 里跑出来的：同一随机序列 0.7/0.2/0.9/0.4、两个技能要留 4 个时，原版结果是 `[undefined, 1374]`，取 4 次随机数；重制把空位记 0，即 `[0, 1374]`。默认开关下只取 2 次，结果是原来那两个技能 |
| O-013 | `XMapTransfer.PREVIEW_FIXED_NORMAL = false` | 同一只敌人预览 64 次，掉率只出现两种取值：0.2×1.33 和它乘以神话倍率；默认开关下固定按非神话 |
| O-014 | `XMapTransfer.REQUIRE_UNLOCK = false` | 未解锁（???）的 5 号图 `can_transfer` 为真，按 F 打开确认窗；恢复后照旧不能传送 |
| O-007 | `XHelpCard.MIN_FONT = 0` | 新建的卡 `min_font == 0`，同一物品的卡比默认的矮 |
| O-008 | `XHelpCard.PLACE_NEAR = false` | `place_for_row` 照优化登记「原版行为」栏写的 updatePos＋setItem 公式放置（三个锚点，含战斗）；技能书附卡间距 10 |
| O-107 | `XBattleScene.POISON_HELP_NEAR = false` | 移到没有毒鸡汤的敌人时卡片不收、旧文字留着；回到这只时，卡片从上一张卡的位置再按 setItem 修正挪一次 |

## 留给车道（本期不碰）

- `battle_logic.gd`（悟空 gaps2）：O-026 `ESTABLISH_TRUE_POPUP`、O-048 `SUBSTITUTE_NEEDS_MOVE`。
- O-117 `SAFE_AIRSHIP_MENU` 留给悟空。它在 `map_scene.gd`，同一文件里的 O-010、O-011、O-012、O-015、O-036 我也先不碰，等悟空交付后再派（同一时间一个文件只给一条车道改）。
- toji.gd、actor_modules.gd、garou.gd 里没有缺口项。
- 下一期可以接着做的（都不在别人的独占文件里）：O-016、O-017（hang_up.gd）、O-018、O-020、O-021、O-023（挂机）、O-022、O-024、O-030、O-031、O-042、O-076 的四个、O-078、O-085（xstate.gd，核心存档类，派之前先确认没人在改）。O-027 `TRANSFER_FIX`、O-100 `ACTOR_IMAGE_FIX` 在事件解释器和事件核心里，属于内容车道 A 的范围，派之前先划清文件。

## 验证

- 5 个直接专项全过：xiyou_pet_capture 65/65、xiyou_pet_synth 28/28、xiyou_transfer 43/43、xiyou_help_card 997/997、xiyou_battle_ui 155/155。宠物捕捉第一轮有一处类型推断写法错（`var captured :=`），修好后单跑通过（919c6747）。
- 选测其余 83 个场景（`battle_scene.gd` 被 77 个场景引用）全部通过，没有偶发。并行测试提示 xiyou_map186_b 用时 320 秒，超过上限的一半，那个场景不是本期改的，可另派拆分。
- `测试回退开关覆盖.py` 通过；`回退开关覆盖.py` 显示新增缺口 0。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】回退支补测试期一：宠物、传送页、说明卡、选敌毒鸡汤卡 9 个开关（75% 审查 G3，dev.待定）

- 9 个优化开关补了回退支测试（见交付单表）：设成回退值，断言原版行为，再恢复默认值。有参照的对参照（O-101、O-102 对宠物参照；O-080 用冻结原版插件原函数算出期望），没有参照的按优化登记「原版行为」栏写期望。
- `MIN_FONT`、`PLACE_NEAR`、`POISON_HELP_NEAR`、`SYNTH_CLAMP_SKILLS`、`PREVIEW_FIXED_NORMAL`、`REQUIRE_UNLOCK` 从 const 改成 static var，好让测试能改它们，默认值不变。
- `回退开关豁免.json` 删掉这 9 项：覆盖 24→33，缺口 37→28。
- 回退：测试是新加的段，删掉即可；static var 改回 const 不影响任何调用。

## 交接板

- 「下一步」：回退支补测试期二，从上面「下一期可以接着做的」那一节里取；map_scene.gd 那几个等悟空的 O-117 合并后再派。

## 可优化

- 优化登记草稿：无。

## 本分支提交

- ebbb16da、919c6747、c2183436，以及本交付提交
