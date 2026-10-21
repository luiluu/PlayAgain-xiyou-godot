# 交付：claude/bajie-43

- 车道／工作者：C 规则·机制／八戒（Claude，重制_八戒_40 起、重制_八戒_41 接力）
- 状态：可合并

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】状态效果阶段钩子第一期：战斗边界分发接口与诊断（dev.待定）

- 依据悟空提案（提案_状态效果阶段钩子_20261021）与沙僧核查（核查报告_20261021_状态效果提案，结论「需改」），按审查收窄的第一期：只做接口、诊断与专项，不执行任何新翻译；现有 mul／user_param_damage 执行点不动、不双跑；不碰 battler.gd、damage.gd、转换器、切片。**不宣称全部 phase 已接齐。**
- **phase 一览**：已接 battle、turn_start、regenerate、turn_end、action_start、initiate、select、deselect、conclude、victory、escape、defeat；照原版不接 action_end（OTB 绕过，原版不触发）、crit（原版无触发插件）；留第二期 confirm、react、respond、establish（随完整伤害链，现有 mul／user_param_damage 执行点不动）与 apply、remove、leave（随 battler.gd 生命周期与 FIX 语义）。
- **有效调用链参照**：新探针 `mv_oracle/state_effects_probe.cjs`（14 例，登记进同步探针表与只增接受键）。往冻结版注入测试状态（复制中毒 4 的已解析字段，每个 customEffectEval 槽只调用记录函数、不改 value），在真实 BattleManager／Game_Action／Scene_Battle.start（dsPassiveSkill 包装在外）里记 phase、状态、持有者、Battler 版与 Action 版的 a／b，以及 startAction／endAction／apply／addState／removeState 等边界。实测：
  - 开战：原 onBattleStart 后我方（含后备）、再敌方逐成员跑 battle；dsPassiveSkill 开战标签加状态（995）在其后。
  - 行动：action_start 在 startAction 前；每目标一次 apply：initiate（行动者）→ select（目标）→ confirm → react → respond → establish → deselect（目标）→ conclude（行动者）。未命中只有四段动作 phase；魔法反射时目标是行动者自己；反击时行动者是反击方；防御也对自己 apply 一次（四段、无伤害段）；强制行动同普通。
  - **OTB 行动结束不触发 Custom Action End**（OTB.endAction 绕过 YEP_BuffsStatesCore 的 endAction 包装），印证审查结论。
  - 回合：turn_start 在 onTurnStart 内；回合末逐成员 regenerate → turn_end。**KRZ 热缓存**：一回合到期的状态在 regenerateAll 里先 remove＋leave，随后的 regenerate 与 turn_end 仍按旧的 typestates 列表对它触发；加状态不 refresh 时 turn_start 仍用旧列表，refresh 后才更新。
  - 自然到期 remove→leave，驱散只 remove。胜／逃／败只对我方，在原 endBattle 之前。
  - 夹具说明：反击用例跑完后参照引擎的 `location` 会变成 undefined（反击路径上有插件动它），放在最后跑；回合结束条件要求 inBattle，夹具显式设上。
- **接口**：新增 `core/state_effects.gd`（`XStateEffects.run(phase, holder, ctx)`／`run_unit`）：按持有者当前状态快照与状态顺序分发；Battler 版（battle、回合、再生、action_start、胜逃败）与 Action 版（initiate／select／deselect／conclude，ctx 带 attacker／defender／item）分开；js 块记进未翻译诊断（同键一次，不静默跳过），HANDLED_ELSEWHERE（mul、user_param_damage）不算；NEVER_FIRED 登记 action_end（OTB 绕过）与 crit（无触发插件）。每个状态每次调用生成完整上下文（`context_for`：phase、state_id、holder、origin；Battler 版 user＝target＝持有者，Action 版 user＝attacker、target＝defender、item），压进上下文栈、返回后弹出，嵌套分发后外层原样恢复（`current()`），不用静态 acting 代替 user／origin；origin 取持有者身上该状态的来源（共用既有 `state_origins`，不另建来源表），没有或失效时回退持有者。测试用 observer 钩子。
- **FIX 重复施加与嵌套抑制**：属 apply 生命周期，第一期不接 apply，只在接口注释登记；`XBattler.add_state` 对已有状态只续回合（与 FIX 一致），第二期接 apply 时照「已有状态不重复 apply、加状态期间再次 addState 被全局锁拒绝」做，不做递归层数。
- **接线（battle_logic.gd）**：battle（setup 中、开战标签前，我方 state.members() 再敌方）、turn_start（start_turn 内、标脏／refresh 前）、regenerate→turn_end（turn_end_battler，不看存活）、action_start（execute 开头与防御分支）、initiate／select／deselect／conclude（apply 包住 _apply；导入平衡禁用的行动不跑；防御分支对自己补四段）、victory／escape／defeat（`end_battle(result)`：胜利先去战斗状态再跑，逃败直接跑）。`battle_scene.gd` 三处 `end_battle` 传 0／1／2（独占范围外的最小改动，仅传参）。
- **新测试** `xiyou_state_effects` 42/42：同形测试状态＋observer，按用例比分发序列（参照滤掉第一期未接的 phase；状态编号按参照 fixture 名字映射）。开战只比我方（Godot 敌人在 setup 内才建），另查开战标签加的 995 不跑本次 battle；action_end 双方都没有；热缓存差异（回合用例里到期状态的 regenerate／turn_end 两行）单列核对、打印，不算通过。另查上下文：两套 user／target、origin 回退与来源、嵌套分发后栈恢复。
- **停在设计（未做）**：
  - KRZ typestates 热缓存：要所有战斗者（含角色）的 need_refresh／refresh 时点跟踪，在 battler.gd（第一期不占）。Godot 第一期按当前状态分发，差异见上。
  - confirm／react／respond／establish 与 apply／remove／leave：第二期随生命周期与完整伤害链一并迁（现有 mul／user_param_damage 留原位）。
  - 导出漏块：13 个畸形结束标签状态（1743、2530～2538、2550～2552）在转换器，运行时诊断看不到。
  - 回合末基础再生与状态到期的先后：原版 regenerateAll 内先基础再生、后状态计时／到期；Godot 现为先 _tick_states 后 _regenerate（既有行为，第一期未改，phase 分发位置按原版放在两者之后）。

## 验证

- 已合 main（0e1c530，main 带进来的只有文档与开发编号，未碰切片／转换器／探针，不用补齐）。
- 专项（并行测试.py，全部通过、无偶发）：`xiyou_state_effects` 42/42；`xiyou_battle*`（battle／battle_events／battle_options／battle_ui／battleback_save）；`xiyou_combat`、`xiyou_rules*`、`xiyou_shield`、`xiyou_imported_balance`、`xiyou_transform_params`、`xiyou_troop_events`、`xiyou_action_sequence`、`xiyou_random_streams`、`xiyou_smart_ai*`、`xiyou_floor*`、`xiyou_zhenqi`、`xiyou_determinism`、`xiyou_review_fix`、`xiyou_custom_damage` 共 38 个场景。
- 参照：`state_effects_probe` 产物在本工作树已同步（专项的 same_source 与 oracle_clean 通过）；总装合并时需在 main 跑同步生成 `state_effects.json`（新探针，只增）。未跑全量（按车道规则）。

## 交接板

- 下一步：Codex 核查第一期（分发位置与原版有效链、两套上下文、诊断）。第二期需占 battler.gd（热缓存与 apply／remove／leave）、damage.gd（伤害段统一）后再派。
- 用户试玩说明：本期无玩法变化（只分发与诊断，不执行新效果）。
- 需要用户决定：OTB 下 Custom Action End 在原版从不触发（数据里 2 块），是否作为可回退优化补触发？本期照原版不触发。

## 进度账

- 不调整（框架与诊断）。

## 本分支提交

- 67baae4 第一期：参照、XStateEffects、接线与专项
- e132d20 WIP：交付单草稿
- 3ca51b7 每次调用的完整上下文与上下文栈、origin 回退，专项 42/42
- 0e1c530 合并 main
