# 交付：cc/bajie-rules1b

- 车道／工作者：C 规则／八戒（cc，接另一账号八戒 rules1 的 a09f882f）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】审查 33 P3-1、P3-2 补上；战斗规则尾项盘点（dev.待定）

- **P3-1 魔冠归根例真比 addedStates**（a09f882f，另一账号八戒）：`tests/xiyou_demon_crown.gd` 谷雨归根那一例原来拿参照值 `want.rows[1][5]` 填 addedStates，等于没比。现在临时给谷雨挂一个 `XResourceContext` 当 `lifecycle_context.resources`，归根后读 `rc.result(g).addedStates` 跟参照比，再还原。删掉 `guyu.gd` 的 `push_state_result("addedStates", 1)` 这条断言会失败。
- **P3-2 死而复燃弹回血、回蓝、TP 数字**（a09f882f）：原版状态 1270 的 Custom Deselect Effect 在 `clearResult()` 前先 `startDamagePopup()`（`YEP_BattleEngineCore.js` 3782～3800 当场深拷贝结果进弹字队列），所以复活时「+30% 血」「+满蓝」「TP 翻倍」会弹出来；重制只清结果槽，什么都不弹。
  - `XResourceContext` 加 `started_popups` 和 `start_damage_popup(b)`：把此刻结果按 `popup_queue` 拷下来，之后 `seed_result` 清槽不影响。
  - `XStateEffects._revive` 在清槽前调它；`XBattleLogic._apply_core` 把这批弹字放进命中记录 `started_popups`，并排在 `popupQueue` 最前面；`battle_scene._hit_visual` 先弹这批（血、蓝、TP 各一次），再弹本次结果。资源上下文每次 `_apply_core` 新建，弹字不会带到下一击。
  - `tests/xiyou_honghuang_curse_battle.gd` 复活例加 `.popups` 断言：复活时三行（血 −floor(mhp×0.3)、蓝 −满蓝、TP −翻倍量），没复活为空。参照值沿用探针已有的 mp／tp，没改参照。
- **战斗规则尾项盘点**（交接板「下一步」第 6 条前五项）：逐项 rg 代码、测试，对冻结源插件，结论见交付单「盘点」节。五项里四项早已做完、交接板清单过时；剩下的只有未翻译状态块，按可达性分了类，找出护盾、自动复活两族真缺口，排给下一期。本期没改规则代码。

## 盘点：战斗规则尾项（11-03，基于 cc/bajie-rules1 a09f882f＝main b5f3a0ce＋两条 P3）

| 项 | 原版位置 | 重制现状 | 要不要做 | 归哪期 |
| --- | --- | --- | --- | --- |
| `additive_rate` 求和次序 | `js/codex/runtime/installDamageElementRuntime.js:64～77` `additiveRate`（`values.reduce((s,v)=>s+v-1,1)`） | **已做**：`battler.gd:620` 用 `sum = sum + v - 1.0`，同 JS 左结合；dev.151 改的，审查核过（变更记录 10-16～26 卷 2665、2943 行），`xiyou_enemy_book` 去掉 1e-9 容差严格比。这次再逐行对了一遍：免疫、敌人下限 `min(0.01, 连乘)`、吸收分支、被动 `/100` 都一致 | 不用做 | — |
| `recover_all` 保留 `<Permanent>` | `PermanentState.js`＋MV `recoverAll`／`clearStates` | **已做**：`tests/xiyou_recover_permanent.gd` 按冻结源内存实测四例（角色、敌人；Permanent、剩余回合、TP、buff 边界），夹具 `recover_permanent_review.json`（2849b076） | 不用做 | — |
| 两个 Apply 类 TP 块 | 状态 1334、1336「横霸千峰」Custom Apply Effect | **已做**：转换器把两块翻成 `gain_steps`（正式数据里 `apply` phase、op `gain_steps`），`xiyou_state_effects_tp` 的 `production.apply.1334／1336` 锁住 | 不用做 | — |
| 224 件装备 YEP Custom Parameters | `YEP_EquipCore` `evalParamPlus` | **已做**：转换器 `equipment_rules.py:112～` 解析成 `customParams`，`actor.gd:637` 读；生成数据里武器 51＋防具 173＝224 件全部解析出 params，没有标签在但解析为空的；唯一被忽略的是武器 78 的 `tp = user.level * 20`（tp 不是能力值，原版同样无效）。探针 `custom_params_probe.cjs` 每种写法一件、量 1／20／60 级与变量两组，Godot 侧 `xiyou_custom_params` 对照 | 不用做 | — |
| 未翻译状态块 | 各状态 `<Custom … Effect>`（YEP_BuffsStatesCore） | **部分**：生成数据里 `op: js` 共 315 块、分布在 204 个状态（`xiyou_state_effects_tp` 的 `inventory.merged_315` 锁数；原核定 318，奈叶二期翻掉 3 块）。分类见下表 | 分族做 | 见下表 |

未翻译 315 块的分类（`可达`＝数据里有技能／道具／装备／敌人／状态效果或备注、公共事件会加上这个状态；只是粗查，脚本口径见「验证」）：

| 族 | 块数 | 现状 | 要不要做 | 归哪期 |
| --- | --- | --- | --- | --- |
| 换装 `setBattlerImage`（apply／remove） | 142 | 不翻脚本，`costumes.gd`／`battler_sprite.gd` 按外观键原生换图（八戒_71） | 不用做（计数里留着是口径问题） | — |
| 死而复燃 1270 | 1 | `REVIVE_JS` 原文整段比对后由 `_revive` 执行（honghuang2＋本期弹字） | 已做 | — |
| **护盾**（react：HP 伤害>0 时，不含某元素就清零，播动画，移除自身） | 7（105 神圣护盾、112 流沙护体、612 闪电护盾、614 真诚祷告、641 杏黄大阵、647 归心、1039 破阵——光明护盾；技能 1112、2824 会加） | **没翻**：重制里这些护盾不挡伤害。同模板只差元素号（8／4／5／10／4／9／8）与动画号（204／241）。现有 `value_query: element_contains` 只认元素 1、不移除状态 | **要做**，最小最确定的一族 | 下一期（rules2）：转换器 `MEASURED_QUERY_BLOCKS` 换成按元素号参数化的签名＋`remove_self`；探针给每块一例（含元素、不含元素、伤害 0）；同步、`xiyou_state_effects` 对照 |
| 护盾 remove `user._bubbleWrapCooldown = 3` | 7 | 没翻；冻结源 js 里**没有任何地方读** `_bubbleWrapCooldown` | 翻成空操作即可（只为计数），随护盾一族做 | rules2 |
| **自动复活**（deselect：倒下时概率回血，`startDamagePopup`＋`clearResult`；有的另加状态、改变量、移除自身） | 约 20（114 龙涎、163 免死、252 七星续命、494 九命、1099、1178、1191、1255、1258、1683、1725、1733、1788、2560、2712 等） | 没翻：这些状态在重制里不会复活 | **要做**，但写法比 1270 杂（概率写法 `>`／`<`、ceil／floor、附带 addState／removeState(stateId)／变量） | rules3：把 `_revive` 改成参数化（概率、比较方向、回血比例与取整、回蓝回 TP、附带动作），一块一签名；先探针后实现。2712「权能·轮回不止」只由未移植的 `installReincarnationRandomRuntime` 加，暂不可达 |
| 其余可达块（伤害 react／confirm、regenerate 持续伤害、turn_start／turn_end、apply／remove 改属性或变量、reserveCommonEvent 等） | 约 95 | 没翻，`_diagnose` 记进未翻译清单 | 逐族评估，先挑切片里玩家会碰到的 | 后续按族排；建议先出一张「切片可达」清单（只看切片角色技能、切片敌群） |
| 不可达块 | 约 40 | 数据里查不到谁加这些状态（如 1840 武痴执念2 的 `user._tp += 50`） | 不做 | — |

## 交接板

- 下一步：第 6 条前五项改写为「`additive_rate`、`recover_all` Permanent、两个 Apply TP 块、224 件 Custom Parameters 已查实做完（rules1b 盘点）；未翻译状态块剩护盾 7＋7、自动复活约 20、其余约 95，护盾排 rules2、自动复活排 rules3」。界面尾项（丹药数量窗、设置页、战力面板路线比较）与 `battle_ce` 单槽不变。
- 用户试玩说明：洪荒诅咒「死而复燃」的敌人复活时会弹出回血、回蓝、TP 数字。
- 需要用户决定：无。

## 进度账

- 无变化（两条 P3 是审查尾巴，盘点没改规则）。

## 可优化（流程／工具／效率）

- 建议：交接板「下一步」第 6 条这类尾项清单常过时（这次五项四项早做完）。尾项写进交接板时带上「核到哪个提交」和查证方式（哪个测试锁着），下次盘点只看差量。归总装。
- 建议：`xiyou_state_effects_tp` 的 `inventory.merged_315` 把 142 块换装也算进「未翻译」，读数会误导。可以让它分两项（换装／真未翻）报数。归哪吒或下一期八戒，收益小。

## 验证

- 合 main（77180290，dev.296 收尾）后补齐；`语法检查.py` 511 个 .gd 0 问题。
- 选测 21 个全部通过（并行 2，892 秒，结果记在 5ce3b295 名下）：派单指定 `xiyou_demon_crown` 106/106、`xiyou_honghuang_curse_battle` 344/344（原 342，加了 2 例 `.popups`）、`xiyou_state_js` 1733/1733；按影响面加 `xiyou_determinism` 372、`xiyou_battle_ui` 155、`xiyou_state_effects`、`xiyou_state_effects_tp`、`xiyou_battle`、`xiyou_battle_gaps`、`xiyou_battle_log`、`xiyou_regen_popup`、`xiyou_popup_overlap`、`xiyou_sequence_visual`、`xiyou_action_sequence`、`xiyou_boss_output_context`、`xiyou_boss_sequence`、`xiyou_boss_react`、`xiyou_shield`、`xiyou_enemy_book`、`xiyou_guyu_battle`、`xiyou_rules_d4`。
- `选测.py main --list` 列出 209 个（`battle_logic.gd`、`state_effects.gd` 归战斗核心），没全跑；战斗核心类挑了 `xiyou_determinism`、`xiyou_rules_d4` 一段。请总装按影响面再选（主要是 `xiyou_rules*` 其余段）。
- 盘点口径：可达性用脚本粗查（技能／道具／装备／敌人／状态的效果 code 21、备注与状态 js 里 `addState(n)`／「状态 n」、公共事件 `addState(n)` 与 313 指令），没算插件里硬编码加状态的路径，所以「约」数只作排期参考。
- 没跑 `反向验证.py`；没开游戏看复活弹字（只读码＋断言弹字队列）；没跑全量。本期没做尾项里的规则改动：五项四项已做完，剩下最小的护盾一族要改转换器＋探针＋同步，留给 rules2。

## 本分支提交

- a09f882f 审查 33 P3-1 魔冠归根例真比 addedStates；P3-2 死而复燃弹回血回蓝 TP 数字（另一账号八戒）
- 5091a49d WIP: rules1b 交付单与尾项盘点
- 5ce3b295 合并 main（dev.296 收尾）
