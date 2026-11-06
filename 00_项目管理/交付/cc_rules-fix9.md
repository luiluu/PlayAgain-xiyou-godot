# 交付：cc/rules-fix9

- 车道／工作者：C 规则／cc（rules，接 BZ；修 BN 八戒 events11 查出的两处事件差异）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】升级提示先出 toast；地图上的「条件分歧：敌人」照原版读上一场敌群（dev.待定）

- **① m4e69p0 +10／+20 级顺序**：根因不在 355，而在 316 之后那条「显示动画 212 [-1, 741, 不等待]」。重制把 212、213 放在 `FLUSH_BEFORE`（一律先出待显示文字），原版 `command212／213` 只在勾了等待时 `setWaitMode`，不勾就接着执行，所以 355 的 toast 先出、升级文字等事件结束才出。改为 212、213 进 `FLUSH_IF_WAIT`（等待参数下标 2，同 225 的写法）。`MVEventCore` 是地图与战斗共用核心，战斗里同样照原版。回退：把 212、213 移回 `FLUSH_BEFORE`（注释里写了）。事件对照 m4e69p0#o4_2／o4_3 由不一致变一致，无回归；baseline 手改去掉这两条（不整份 `--update-baseline`，本轮产物期间总装在合并）。
- **② 111 条件类型 5（敌人）**：战斗里 `XBattleEventRunner` 早已实现；地图上原来整段跳过（记 skipped、取 false）。正式引擎实测（新探针 `mv_oracle/troop_condition_probe.cjs`，冻结 v0.28）：`command111` 读 `$gameTroop.members()[序号]`，战斗结束（Scene_Battle.terminate → onBattleEnd）不清空敌群，地图上读到的是**上一场战斗的敌人**：打赢后「0 号有状态 1（死亡）」为真、「出现」为假；逃跑后敌人活着、状态（连「战斗结束解除」的中毒 4）都还在；战斗中隐藏的成员结束后出现；新游戏为空，读档后 `$gameTroop` 也是新的空敌群。实现：`XBattleLogic.end_battle` 在敌群收尾时记 `XState.last_troop`（每个成员 {dead, states}，**不存档**，新局与读档为空），`MVInterpreter._condition_env` 读它。涉及的是 ce942、ce618、ce620、ce679、ce1598 这类技能公共事件里的「敌人 N 死亡」分支：在战斗里用照旧，从菜单在地图上用时，原版按上一场的敌人判定，重制现在一样。
- 新专项 `xiyou_troop_condition`（16 项）读夹具 `tests/fixtures/troop_condition_oracle.json`（探针产出原样复制，探针登记检查按夹具认），在重制里打同样四场逐项对，另测读档为空、212／213 有无等待。反向验证 4 处改坏 3 处咬住；「战斗结束时临时取消隐藏」那处没咬住，查明重制 `is_dead` 对隐藏成员本来就 false、原版隐藏成员也加不上状态，这行走不到，已删。
- 核心文件：改了 `battle_logic.gd`（加 `_record_last_troop`，end_battle 敌群收尾处调用一次）、`xstate.gd`（加运行时字段 `last_troop`，不进 to_dict）、`mv_event_core.gd`、`mv_interpreter.gd`、事件对照 baseline。请沙僧重点核前两个。

## 交接板

- 下一步：BN 交付单记的 ce942～946、ce618、ce620、ce679、ce1598 的 10 个 w1 变体（因「111 条件类型 5」跳过被剔）现在能跑，八戒下一轮可以加回（地图上敌群为空，取值 false，与探针一致）。
- 用户试玩说明：方桌大厅测试角色「+10级／+20级」先弹「角色等级+10！」小提示，再出升级文字窗口（同原版）。技能公共事件在地图上判断「敌人死亡」时按上一场战斗的敌人（同原版）。
- 需要用户决定：无（两处都是照原版，没有偏离，不登 O）。

## 进度账

- 事件解释器：两处已知与原版不一致消掉，事件对照已知不一致 5 → 3。

## 可优化（流程／工具／效率）

- 建议：`event_state_probe` 的预设加一个 `troop`（敌群成员与状态），事件对照就能直接量「地图上有上一场敌群」的变体，不用单独夹具（预计收益小，归事件车道 A）。

## 验证

- `xiyou_event_compare`（本地，合 main 前）：11 项过，m4e69p0#o4_2／o4_3 列入 nowMatching，regressions 空。
- `xiyou_troop_condition`（本地）16/16；`反向验证.py` 4 项：地图不认敌人条件、战斗结束不记敌群、212 照旧先出文字三处咬住，第 4 处（临时取消隐藏）没咬住、查明走不到后删掉。
- `选测.py main --list` 列 301 个（>40），走云端：合 main、再 `--补齐` 后 `云端选测.py run`，结论整轮 436 场景 15 片，**全部通过**（提交 5dc4d56107，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42153332638）。之后只改了本交付单。
- `工具回归.py` 全过（80 秒，含探针登记检查：新探针按夹具 troop_condition_oracle.json 认）；`语法检查.py` 0 问题。
- 没跑同步：新探针是冻结参照夹具式，不进 PROBES；没改切片、转换器或已登记探针。

## 本分支提交

- 61414ef5 212/213 不勾等待不先出文字；地图上条件分歧敌人读上一场敌群
- 65c4fb0a 专项读冻结参照夹具；baseline 去掉 m4e69p0 两例
- 1ad37d50 合并 main
- 5dc4d561 交付单草稿（云端选测通过的提交）
