# 交付：cc/bajie-rules2b

- 车道／工作者：C 规则／八戒（cc，唐僧总装十八派 rules2，总装十九派 rules2b 接手收尾）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】护盾一族 7 个状态翻成原生实现（dev.待定）

- **原版行为**（`state_effects_probe` 新用例 `query.shield_blocks` 实测）：状态 105 神圣护盾、112 流沙护体、612 闪电护盾、614 真诚祷告、641 杏黄大阵、647 归心、1039 破阵——光明护盾的 Custom React Effect 同一模板。HP 伤害（类型 1／3／5）且 value>0 时：攻击元素不含本盾元素（8／4／5／10／4／9／8）就把伤害清零；**含不含都**播动画（204 或 241）并 `removeState(stateId)`——带本盾元素的攻击照常打进去，但盾也碎了。value≤0 或非 HP 伤害什么都不做。两盾同挂时按状态顺序逐个 React，前一个清零后 value＝0，后一个不触发、留着。Remove 块写 `user._bubbleWrapCooldown = 3`，冻结源 js 里没有任何地方读它。
- **转换器**（`xiyou_export.py`）：`SHIELD_BLOCK` 按整段 token 原文比对，只有元素号、动画号两处可变，认出后译成 `value_query`（`element_contains`、`present: false`、`remove_self: true`、`animation`）；`BUBBLE_WRAP_REMOVE` 整句比对译成 `noop`（注释写明冻结源无读者）。原有两条元素 1 的 `MEASURED_QUERY_BLOCKS` 不动。生成数据 `op: js` 315 → 301。
- **运行时**（`state_effects.gd`）：`value_query` 带 `remove_self` 时，先判 HP 伤害>0（清零前），执行时 `_break_shield`：动画记进命中记录 `state_anims` [[动画, 持有者]]，状态经行动资源上下文移除（removedStates 进结果槽，Remove 块的 noop 随之触发）。预览只清零、不破盾、不记动画。`battle_scene._hit_visual` 在本次弹字前播 `state_anims`。别族行为不变。
- **报数拆分**（rules1b 可优化第二条）：`xiyou_state_effects_tp` 的 `inventory.merged_315` 拆成 `inventory.costume_142`（换装 setBattlerImage）与 `inventory.untranslated_159`（真未翻，原 173 减护盾 14 块）。
- 测试：`xiyou_state_effects` 加 `_shield_blocks`（441 行单块执行＋预览、15 例两盾同挂走 `XStateEffects.run`、7 例真实 `XBattleLogic.apply` 两下）；`测试状态js翻译.py` 加 `ShieldTranslationTests`（整块比对与 14 个改一个记号就退回 js 的边界）。

## 交接板

- 下一步：未翻译状态块剩自动复活约 20（rules3）、其余约 95；护盾一族已做（rules2）。
- 用户试玩说明：神圣护盾、流沙护体、闪电护盾、真诚祷告、杏黄大阵、归心、破阵——光明护盾现在会挡下一次不带对应元素的伤害（播破盾动画后消失）；带对应元素的伤害照常打进去，盾也会碎。
- 需要用户决定：无。

## 进度账

- 战斗规则：未翻译状态块 315 → 301（真未翻 173 → 159）。

## 可优化（流程／工具／效率）

- 建议：`state_effects.gd` 现在的 `value_query` 一个 op 管了四种查询加破盾，下一族（rules3 自动复活）若也要「改值＋副作用」，可考虑把副作用拆成独立 op（如 `remove_self`、`start_animation`）按顺序跑，转换器一块译成多步。收益中等，归八戒 rules3 顺手评估。

## 验证

- 核草稿：逐项对过差异，转换器、运行时、`battle_scene`、探针、报数拆分、两处测试都真做了；生成数据 `op: js` 301 块，7 个盾的元素与动画号和草稿一致。
- 专项（本机）：`xiyou_state_effects` 20885、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_battle_events` 108、`xiyou_determinism` 372、`xiyou_param_states` 582，全过。
- 云端选测：提交 04d567669c，209 个场景 7 片，全过（Actions run 41741941422）；`xiyou_rules` 按选测抽样，没关抽样。
- 工具：`测试状态js翻译.py` 12 项过；`语法检查.py` 0 问题；`内容覆盖检查.py` hard 0、new 0（切片没改，不用 `--update-baseline`）。
- 同步：`同步正式西游.py --accept-additions` 退出码 0，只新增 `query.shield_blocks` 一个用例，未跑探针复用 78 个。
- 总装注意：这棵工作树的 `generated/` 之后被 rules3 改过（同一工作树接着做），产物指纹已不能用 `--from-worktree`；合并后照常重跑同步，只有 `state_effects_probe.cjs` 等少数探针要跑，本次约 3 分钟。

## 本分支提交

- 34e0e8dc WIP: rules2 护盾一族：探针 query.shield_blocks、转换器签名、运行时破盾、对照测试
- a24bb7b7 WIP: rules2 探针记出手前 dirty；破盾实战例按参照前置态布置
- e5b305bd Merge branch 'main' into cc/bajie-rules2
- 04d56766 WIP: rules2b 接手交付单草稿
- 本交付单收尾提交

## 待交叉核查（核心文件）

- `state_effects.gd`（`value_query` 的 `remove_self`、`noop`、`_break_shield`）、`battle_scene.gd`（`state_anims`）。
