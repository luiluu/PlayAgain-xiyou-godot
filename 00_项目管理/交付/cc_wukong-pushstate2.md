# 交付：cc/wukong-pushstate2

- 车道／工作者：C 规则／悟空（cc）
- 基线：从 cc/wukong-pushstate1 末端 8ebdbffa 切出。
- 状态：进行中

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】伤害／治疗时挂状态二期：时机、装备、反射／反击／掩护、逆祷（dev.待定）

- **时机**：参照 `order.1580`（钩住 addState 与 onReactStateEffects）：原版挂状态在 React 之前。重制改由 `XDamage.finish` 在 Confirm、固定减伤之后、React 之前调 `ctx.after_confirm`（`battle_logic._damage_value` 只在 `_apply` 的结算里挂这个回调，`push` 参数），不再在整段结算后挂。
- **装备**：参照补两例：新局角色 1 能穿的 1706 无极西瓜刀（`<PushState0521: 100%>`）、4966 纯美的赞诗（防具，`<RecPushState1734: 100%>`，治疗友方）；重制缓存原来就收装备，专项按装备栏位穿上实例比，对上。
- **反射／反击／掩护**（参照 `invoke.*`，走 BattleManager.invokeAction）：魔法反射回行动者自己时，目标就是行动者，161 挂给自己；反击由反击者结算，挂给被反击的敌人；掩护挂给代受者。重制 `_invoke` 的三条路径都经 `apply → _apply`，结果一致，没改代码（反射那例一开始看着像「不挂」，是角色被反射伤害打死了；把生命加厚后确认会挂）。
- **逆祷两层**：原版逆祷的 makeDamageValue 包装在 Codex 之外，算预算时对另建的 heal 动作调内层（Codex 给那个结果挂 `_after`，但它不进外层动作的结算），外层直接返回数值、没有 `_after`。所以逆祷的治疗不挂状态。重制 `_damage_value` 的逆祷分支与内层调用都不带 `push`，不挂。**这一条是读码判断，没有探针**：逆祷要整套异化战斗环境（alien_affix_probe 的 battle()），没在本期搭。
- **云裳拆段**：云裳 174 不在切片，重制没有拆段（`result._parts`），只记：上线云裳时整体挂一次。
- **参照与专项**：`pushstate_probe.cjs` 12 → 18 例（加装备 2、order 1、invoke 3）；`xiyou_pushstate` 69/69。

## 交接板

- 下一步：云裳上线时补拆段整体挂一次；逆祷挂状态要不要补探针，看审查。
- 用户试玩说明：穿带「造成伤害时附加」「治疗时附加」特效的装备也会生效了；被魔法反射时，自己的特效挂到自己身上（同原版）。

## 优化登记草稿

优化登记草稿：无。

## 进度账

- 战斗规则：完成度不变。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`pushstate_probe` 18 例无报错。
- 专项：`xiyou_pushstate` 69/69。反向：待写
- 相关战斗场景：待写
- 改动的原沙僧核心文件：`battle_logic.gd`（`_damage_value` 加 `push` 参数与回调、`_apply` 调用改一处、`_push_states` 改收 sign）、`damage.gd`（`finish` 在 React 前调 `after_confirm`）。

## 本分支提交

- 10f4c153 装备两例
- （时机）挂状态挪到 React 前、逆祷内层不挂
- （反射／反击）invoke.*
- （掩护）invoke.cover
