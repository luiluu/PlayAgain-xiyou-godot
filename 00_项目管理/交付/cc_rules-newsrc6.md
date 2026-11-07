# 交付：cc/rules-newsrc6（换源失败表 rules：run 42343228257）

- 车道／工作者：规则（cc，项目线程「完成再刷西游Godot引擎重制」），总装失败表
- 状态：**可合并**（state_effects 两项、param_states 1768.self 都已修）。合回集成分支 `cc/newsrc-switch`，**不进 main**。
- 基于：`cc/newsrc-switch` 3948463f。产物、导入缓存从集成工作树 recursing-shamir（同一提交）`cp -c` 克隆。
- 分支名说明：`cc/rules-newsrc5` 已被之前的会话用过（热缓存复活那单），本单用 newsrc6。

## 场景 → 用例 → 根因 → 修法

### xiyou_state_effects · action.counter.sequence（2792 反击序列）

- 根因：新源 YEP_BattleEngineCore `invokeAction`（第 2098～2108 行，v0.35 注释「enemy retaliation follows the incoming hit」）改了逻辑：**敌人**判中反击时，先对它正常生效（invokeNormalAction）；如果挨打的还是它（没被掩护）、它还活着能行动、出手者也活着，再反击。**角色**照旧是反击代替挨打。参照里 a1 的阶段全走完以后，才是 e0 对 a1 的那一组。
- 修法：`battle/battle_logic.gd` 的 `_invoke` 拆出 `_counter_attack`、`_invoke_normal`（后者记下 `_last_receiver`）。敌人反击走「先生效后反击」，由 `XBattleLogic.COUNTER_AFTER_HIT`（默认 true＝新源，false 回旧源 v0.28）控制。这是复现新源，不登 O 号。
- 验证：state_effects 32813/32813；把开关改成 false，`action.counter.sequence` 就挂（已核）。

### xiyou_state_effects · rest.costume.undefined_note（226／66 换装）

- 根因：备注两版相同。新源参照里 remove66、remove_only 没有 `raw`（`_battlerName` 是 undefined），但 `battlerName()` 退回了角色数据库的图 gxysv2；旧源读出来是 undefined。这条断言原来写的是旧源的现象。
- 修法：只改断言。改成「raw 没了、显示的是 costumeBase」，跟重制 `remove_without_prev` 退回本来的图一致。代码不改。

### xiyou_param_states · 1768.self.repeat／save（翻倍）——已修（第二棒）

- 场景：角色身上带 1768（Conclude 给自己加能力值），生命已经是 0，自己对自己出手两次。
- 用例：`xiyou_param_states` 的 `1768.self`。参照（v0.62.12）repeat、save 只加一次（10/30），重制加两次（20/60）。
- 根因（新源探针逐步打点，临时脚本 `mv_oracle/.sandbox/s1768.cjs`，不入库）：第一次 Conclude 的 addParam(0,10) → refresh → 生命 0 → die → clearStates；dsPassiveSkill 的 clearStates 包装在 `_states` 清空的那一刻重建被动缓存，顺手把 krz 的 states() 缓存算成 []、need_refresh_states 置假。之后 addNewState(1)、外层 refresh、addParam(1,30) 都没人标 krz need_refresh（krz 没包 addParam），typestates('concludeState') 一直是 []，第二次 Conclude 不跑。跟 **O-待定·热缓存复活** 是同一个原版缓存缺陷（持有者热的时候死亡，列表冻成空表直到下一次脏刷新）。
- 上一棒冻不住的原因：冻结分支本身走到了，但重制的 `XParamPlus.add` 每次都 `param_mark_dirty()`，把 effect_dirty 置真。于是外层 `XResourceContext.refresh` 的「was_dirty 且这次死了」分支把冻结的快照作废，第二个 addParam 又按 states() 重建成 [1,1768]。原版 addParam 不标 need_refresh。
- 修法：并进 O-待定·热缓存复活（同一开关 `XBattler.o_hot_cache_revive`，不另开 O 号）。
  - 默认（true，修好）：不变，照常再加一次，20/60。
  - 回退支（false）：`param_plus.gd` 的 `add` 在持有者原本热的时候，标完参数缓存后把 effect_dirty 放回假（照原版 addParam 不标 need_refresh），死亡冻成的空表留住，repeat、save 照参照 10/30。
- 测试：`conclude` 每个 1768 例跑两遍，回退支（字面量 `= false`）逐行比参照；默认支 `1768.self` 断言 repeat、save 为 conclude 的两倍，repeat 的 trace 照样两次 addParam。测试里设 `hot_at_apply = true`（原版 offApplyStateEffects 在 Game_Action.apply 里，持有者此刻热）。
- 验证：`xiyou_param_states` 792/792、`xiyou_state_effects` 32813/32813；把 `param_plus.gd` 的改动撤掉，回退支 5 项红（repeat 的 plus／param／trace、save 的 plus／param），放回就过。`语法检查.py` 通过。默认支代码路径没变（新代码只在开关为假时生效）。

### 敌人热缓存不复活

- 集成分支 3948463f 上已经做了：**O-待定·热缓存复活**，`XBattler.o_hot_cache_revive`（默认复活），state_effects 里关开关逐例比参照 32 行，开开关断言 13 行复活。优化登记已有这一行（执行者 rules newsrc5，状态「待用户确认」）。本单没有重复做。

## 优化登记草稿

无新 O 号。1768.self 并进已有的 O-待定·热缓存复活（`XBattler.o_hot_cache_revive`）：总装合并时在那一行的说明后补一句「回退支连带：addParam 不标 krz need_refresh（`XParamPlus.add`），1768.self 自杀后第二次 Conclude 不跑」。

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】新源：敌人反击跟在挨打之后、换装断言随新源（dev.待定）

- 新源 v0.35 起，敌人判中反击时先挨这一下再反击（`XBattleLogic.COUNTER_AFTER_HIT`），角色照旧；state_effects 2792 序列对上。
- 换装 226／66 的断言改为新源行为（battlerName 退回数据库的图）。
- param_states 1768.self 翻倍：根因是新源死亡时 states 缓存成空表（同 O-待定·热缓存复活）。默认照常加两次；回退支 addParam 不再标脏，照参照只加一次。

## 交接板

- 下一步：无（本单收完）。
- 用户试玩说明：敌人反击时，玩家这一下照样打中，然后敌人再反击。
- 需要用户决定：无。

## 待交叉核查

- cc/rules-newsrc6：COUNTER_AFTER_HIT（甲档：battle_logic `_invoke`）；`XParamPlus.add` 回退支不标 effect_dirty（甲档：存档账本／缓存）

## 进度账

- param_states 1768.self：已修（默认修好，回退支照参照）。

## 可优化（流程／工具／效率）

- 集成分支上的车道分支名已经撞过一次（rules-newsrc5）。派单时写明分支名，或者在交付单 README 里登记已用的名字，可以免得重名。

## 验证

- 本地专项：`xiyou_state_effects` 32813/32813、`xiyou_param_states` 792/792（Mac，并行 2）。`语法检查.py` 623 个 .gd 0 问题。
- 没跑云端选测：反击那项（第一棒）上一棒本地已过；本棒的改动只在 `o_hot_cache_revive=false` 时生效，默认支行为不变。合回集成分支后随集成的选测一起跑。

## 本分支提交

- fa02eccb 反击与换装
- 1768.self 回退支与交付单（第二棒，本提交）
