# 交付：cc/wukong-tail2

- 车道／工作者：C 规则／悟空（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】被控回合逐模块量：敌人被控不减行动结束的回合，被控角色走绑定 validate（dev.待定）

派单：tail1「可优化」节的后续。`act` 里 `if started and not skipped` 对被控角色也拦了各模块收尾，原版被控角色照走 endAction，逐模块量。顺带补 P3-1 没单开例的屠苏、镜流、宿傩。都是照原版修，没有新优化，没有新回退开关。

**战斗核心，请重点核：** `battle_logic.gd` `act` 的 `skipped` 分支（`started = u.is_actor()`、`skill = null`）和 `XBinding.end_action` 的门。

### 一、原版怎么走

- 角色：OTB `processTurn` → `startOTBInput` → 不能输入 `makeActions`＋`startAction`。没有行动时外层 startAction 包装直接 `endAction`，`this._action` 为空。走 `onAllActionsEnd`，且 `_processTurn` 为假，**减行动结束的状态回合**。
- 敌人：YEP `processTurn`，没有行动不 startAction、不 endAction，`_processTurn` 为真，**不减**。

### 二、逐模块结果（新探针 `stunned_turn_probe`，真实 processTurn）

各角色先正常打一下，再上睡眠和行动结束减回合的状态，比这一回合前后的生命、魔法、TP、状态回合、增益、敌人生命，另记角色自身字段的变化。

| 模块 | 结果 | 重制 |
| --- | --- | --- |
| 饿狼、宿傩、镜流、甚尔、渡鸦、云裳 | 原版收尾遇到空行动直接返回，实测无变化 | 原来就不走，**没差异**，没改 |
| 黑闪 | 收尾同样空转；不能行动连闪归 0 在 processTurn 包装里 | 原来就有 `break_chain`，**没差异**。这轮没预置连闪层数，这一条靠读码＋原有专项 |
| 黄泉、璇、屠苏、谷雨、米拉、奈叶、普通角色 | 实测无变化（派单之外顺带量） | **没差异** |
| 绑定 startAction（回归当回合扣 1 点充能） | 走不到：外层包装没有行动就直接 endAction（`skip_return`，4→4） | 原来就不扣，**没差异** |
| 绑定 endAction（validate） | 照跑：宿主倒下，被控队友回合结束解绑（`skip_validate`） | **有差异，已修** |
| 行动结束减回合：敌人 | 不减（`enemy.sleep`，3→3） | **有差异，已修**：重制原来减成 2 |
| 行动结束减回合：角色 | 减（3→2） | 原来就减，没差异 |

被控时 `skill` 一律清成 null，下面所有包装看到的都是「没有行动」，和原版空 `_action` 一致。正常流程本来就传 null，这处是防调用方带技能进来；tail1 给璇单独写的 `{} if skipped` 随之去掉。

### 三、棱光目标补例（P3-1）

`xuan_auto` 加 `last_tusu`、`last_jingliu`、`last_sukuna`、`last_sukuna_all`：主目标 1 号敌，棱光都打 1 号敌；宿傩神灶·开（全体、行动结束才结算）记 makeTargets 的最后一个，打 2 号敌。重制全部一致，tail1 的修法不用动。

### 四、验证

- 专项：新 `xiyou_stunned_turn` 42 项、`xiyou_xuan_auto` 4441 项全过。
- 反向验证 3 项全咬住（敌人被控也减回合、被控角色不走 validate、被控仍带技能）。
- 探针 `stunned_turn`、`xuan_auto` 不进同步；`xuan_auto` 旧用例逐例比过没变。没动切片和转换器。
- 选测结果：云端 209 个场景全过（提交 384dec0a，基准 2985a786，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41763178954）。

## 交接板

- 下一步：无新增。
- 用户试玩说明：敌人被晕住的回合，身上按行动计时的状态不再多掉一回合。璇的宿主倒下时，被控队友的回合结束就会解绑。
- 需要用户决定：无

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 建议（下批规则车道，未量，别当成已确认的 bug）：`act` 门外的 `XHubris.end_action` 开头 `settle_deaths`、`XRaceBattle.finish`、`XAlienBattle.finish` 对敌人跳过的回合也照跑，原版那时不走 endAction。读码看多半只影响结算时机，没开例。
- 建议（工具）：`并行测试.py` 的 generated 落后检查，在总装合并正在同步时会把车道挡住（这轮连挡三次，main 的 oracle 刚更新），可以提示「主工作区有同步在跑」。归哪吒。

## 本分支提交

- 384dec0a WIP: tail2 交付单草稿
- 4ba5ce2f 敌人被控不减行动结束的回合；被控角色走绑定 validate；被控时不带技能（参照 stunned_turn、xuan_auto skip_validate）
- 67654e15 WIP: 被控回合探针 stunned_turn，xuan_auto 补 P3-1 三家例
