# 交付：cc/review-33

- 车道／工作者：审查／cc（审查，Opus medium）
- 状态：可合并
- 基线：从 main `effc9fa4`（合并 xuan2，收尾提交之前）切出，只加本交付单。行号按这个基线。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 成长装备尾项二期、洪荒二期、璇战斗效果第一期、探针五乘区存量清理二三期

- 核查覆盖：cc/bajie-growth4（245e30ba）、cc/wukong-honghuang2（296a571a）、cc/nezha-tools50（44371eb1）、cc/nezha-tools51（a70c62bc）、cc/wukong-xuan2（effc9fa4）
- 结论：P1、P2 无；P3 四条（growth4 一条测试自比、honghuang2 一条弹字、xuan2 两条）。五条都通过。
- 验证：对着冻结 v0.28 读码；4 个原版探针（demon_crown 20、honghuang_curse_battle 34、honghuang_reward 44、xuan_battle 33 例）在本树重跑，产物与夹具逐例相等；专项见「验证」。没跑全量。

## 问题

### P3-1 谷雨归根那一例的 addedStates 是拿参照值填进去的，等于没比（growth4）

- 位置：`01_Godot工程/tests/xiyou_demon_crown.gd:261`，`rows.append([... want.rows[1][5] ...])`。
- 后果：`guyu.gd` 新加的 `push_state_result("addedStates", 1)` 没有任何断言，删掉这一行测试照样过。注释说专项没有行动结果上下文；其实可以给 `g.lifecycle_context` 临时放一个 `XResourceContext`，再读 `result(g).addedStates`。
- 代码本身我读过是对的：死亡挡下时补 `add_new_state`→`reset_state_counts`→`push_state_result`，同原版次序。

### P3-2 死而复燃复活时原版会弹出回血、回蓝数字，重制什么都不弹（honghuang2，只读码）

- 位置：`modes/xiyou/core/state_effects.gd` `_revive`。
- 原版 1270 的脚本在 `clearResult()` 之前先调 `target.startDamagePopup()`；`YEP_BattleEngineCore.js:3782～3800` 的 `startDamagePopup` 当场深拷贝结果进弹字队列，所以 gainHp／gainMp 之后的「+30% 血」「+满蓝」会弹出来，之后 clearResult 只清掉这一击本身的显示。
- 重制只做了 clearResult（`seed_result` 空结果），没有弹字。参照只比 `result.hp`（清过后是 0）、血蓝 TP 和状态，所以测不出来。纯显示，玩家看到的是敌人倒下又站起来，但看不到回了多少。
- `r.died` 那一行我核过：`died` 只在 `battle_scene.gd:1594` 用来藏血条，和 `sequence_player.gd:492` 决定要不要推结果，不影响击杀计数和奖励；改成「复活了就不算」对所有复活都成立，也符合原版（原版倒下与否看显示时的状态）。

### P3-3 定星只挂在资源上下文的 add_state 上，直接调 battler.add_state 的路径挡不住（xuan2）

- 位置：`modes/xiyou/core/resource_context.gd:31`。原版包的是 `Game_Actor.prototype.addState`（`installThreeGrowthRelicRuntime.js:239`）与 `Game_Battler.prototype.addState`（`installNativeXuanRuntime.js:332`），角色身上所有 addState 都过它。
- 重制里绕开资源上下文、直接调 `battler.add_state` 的有：异化舍身转移（`alien_battle.gd:921`）、囚厄接收（`:953`）、甚尔／饿狼形态、小猫标记。现在这些要么给敌人、要么加的不是可净化硬控，所以眼下没有实际差别；记下来是给第二、三期：以后若有直接给角色加硬控的路径，要记得也过 `blocks_state`，或者把钩子挪到 `battler.add_state` 的最外层（谷雨 protect 那一层）。
- 派单问的「blocks_state 放在 isStateAddable 之前」：对的。原版两层包装都在调 `old` 之前判断、返回，`isStateAddable` 在最里面的原 addState 里，所以本来会被抗性挡下的硬控也会先消耗定星。重制位置一致。探针 33 例里没有「被抗性挡下的硬控」这一例，建议第二期顺手补一例。

### P3-4 「定星挡住时的台词没接」这条已知问题，原版正常情况下其实也不写日志（xuan2，只读码）

- 原版有两层：外层 `Game_Actor` 包装（`installThreeGrowthRelicRuntime.js:239～245`）挡下时直接 `return`，**不写日志**；只有它没挡（例如璇不在出战成员里）时才落到 `Game_Battler` 那层（`installNativeXuanRuntime.js:336`），那层才 `log(CFG.lines.dingxing)`。
- 所以第二期补台词前先用探针量一下实际会不会出这句，别照交付单的说法直接加上。重制现在不写，正常路径和原版一样。

## 已查通过

- **cc/bajie-growth4（甲）除 P3-1 外通过。**
  - `add_new_state`／`reset_state_counts` 拆分后 `_add_state` 行为不变：死亡判定（已死、不死、抗性）仍在拆出去之前，`zq_pojia_rate` 仍只在 `_add_state` 里设。`_add_state` 是 battler 里唯一的调用处（另一个 `_add_state` 是 `state_effects.gd` 自己的函数）。
  - 交付单请重点核的次序：魔冠死亡钩子挪进 `add_new_state` 后，在 `_adding_state` 锁里、在 `reset_state_counts` 与 `XAlienBattle.after_add_state`／`XGuyu.after_add_state` 之前。`XDemonCrown.on_death` 只改账本与 bonus，不加状态，进锁没有副作用；它比异化、谷雨的 addState 后段先跑，同原版（魔冠包的是 addNewState，在 addState 里面）。
  - `guyu.root` 被挡下时补的三步同原版；`reset_state_counts(1)` 不传随机：死亡状态回合上下限都是 1，结果固定，但单点区间也会从世界随机流取一次（原版 `Math.randomInt(1)` 同样取一次 Math.random），回放时世界随机流会还原，不影响确定性。
  - 探针 20 例与夹具全等。
- **cc/wukong-honghuang2（甲）除 P3-2 外通过。**
  - `_revive`：条件、15%、30% 血、满蓝、TP 翻倍与 1270 原文一致；按 js 原文整段比对才生效，别的 js 块不受影响；随机为空（预览）时不复活。
  - 判定 `is_honghuang` 只看 2483／2463；`power_battle` 在 `setup` 覆盖、`end_battle` 记胜负、`_become_current` 清、回放前后还原（存的是旧字典引用，回放里的 `battle_started` 换新字典，不会改到它）。
  - `_fixed1` 只对 x.25／x.75 这两个真中点加 0.01，其余交给 `String.num`，和 JS toFixed(1) 一致。
  - CE1445 整段比对与普查删行对得上；`sync_native_tier` 改用共用查找，结果不变。
  - 探针 honghuang_reward 44 例、honghuang_curse_battle 34 例与夹具全等。
- **cc/wukong-xuan2（甲）除 P3-3、P3-4 外通过。**
  - `blocks_state` 的条件（本场数据、角色、还没有这个状态、可净化硬控、`until >= 回合`、过期不删）与原版两层包装一致；挡下时删记录、去标记状态。
  - 五处钩子位置：startBattle 在谷雨之后、绑定之前；MP 费用在谷雨之外、屠苏之内；`meets` 在心钢之后、屠苏之前；`user_effect` 在屠苏之前；endBattle 在护盾账本之后、绑定之前。都只对璇（177）或有本场数据时生效。
  - 探针 33 例与夹具全等。
- **cc/nezha-tools50、cc/nezha-tools51（丙）只看结论，通过。** 两条都没改测试脚本（diff 里没有 .gd），夹具只动数值；本树 `探针登记检查.py` 通过，存量 23 个，与交付单一致。

## 没查

- 没跑全量；没用真机试玩界面（死而复燃弹字、修行页权能行都只读码）。
- honghuang2 的诅咒加成券、权能掉落只看了代码与参照，没逐例对掉率表；xuan2 的蚀辉、棱光、璃壁数值只靠探针对比。

## 交接板

- 下一步：P3-1～P3-4 随手处理（P3-3、P3-4 可并进璇第二期）。
- 用户试玩说明：无（只加审查报告）。
- 需要用户决定：无新增。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 原版探针重跑（本树，`NODE_PATH` 指主工作区 node_modules）：demon_crown 20、honghuang_curse_battle 34、honghuang_reward 44、xuan_battle 33 例，与 `tests/fixtures/` 夹具逐例相等。
- 专项：（待填）
- `探针登记检查.py` 通过（存量 23）。
