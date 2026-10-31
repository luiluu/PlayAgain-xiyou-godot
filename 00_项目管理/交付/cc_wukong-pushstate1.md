# 交付：cc/wukong-pushstate1

- 车道／工作者：C 规则／悟空（cc）
- 基线：从 cc/wukong-battle-gaps3 末端 d38414b7 切出；实现前合了 main（含 gaps3、rollback2）。
- 状态：进行中（实现与专项已做，相关战斗场景在跑）

## 接手要点（给下一位悟空）

- **原版解析**：`js/plugins/dsPassiveSkill.js` 1108～1190 `refreshPassiveCache`，对象是 `this.equips().concat(this.skills(), this.states())`（装备→技能→状态），按 note 正则逐条收：
  - `<RecPushState(\d+):\s*(\d+)%?>` → `cache.recPushStates`（恢复时给目标）
  - `<PushState(\d+):\s*(\d+)%?>` → `cache.pushStates`（伤害时给目标）
  - `<PushsubState(\d+):\s*(\d+)%?>` → `cache.pushSelfStates`（伤害时给自己）
  - 状态号 parseInt（`0161` → 161）；% 可省（4458 写 `100`）；概率只认整数（4680 `0.2%` 不进缓存）。
- **原版生效点**：`js/codex/runtime/installDamageElementRuntime.js` 约 270 行，`Game_Action.prototype.makeDamageValue` 包装：`sign = result.value`，`result._after.push(fn)`；fn 在 `actor(subject)` 且不是异化虚空攻击（`CodexAlienation.has(subject,'void') && isAttackDamage`）时：`sign<0` 用 recPushStates、`sign>0` 用 pushStates，逐条 `Math.random()*100 < probability && !target.isStateAffected(id)` 才 `target.addState(id)`；`sign>0` 再按 pushSelfStates 给 subject。`_after` 在结算 `part()` 里执行（约 26586 字处，onPreDamageStateEffects 的结算链里）；拆段（云裳）时在整体上执行一次。dsPassiveSkill 自己 makeDamageValue 里的旧版（有 `target.isActor()`、`isDamageType`）被 Codex 盖掉、不生效。
- **治疗不看阵营**：照原版（Kyo 10-31：线上那个 bug 不归我们管），`rec.6706.enemy` 参照就是治疗打敌人照样挂。
- **重制挂点**：被动缓存在 `actor.gd` 的 `passive_cache()`（只有角色有；原版 dsPassiveSkill 只挂 Game_Actor）；伤害数值在 `damage.gd`；`battle_logic.gd` 的 `_apply` 确认段加一行钩子（八戒 toji1、白龙 jingliu1 也在改 battle_logic，只加一行一行的钩子）。重制全工程原来没有这三种标签（rg 只有 Start* 开战标签）。
- **二期再做**：异化虚空例外、云裳拆段整体挂一次、与反射／掩护的交互。
- 装备上的标签走同一缓存，但新局角色 1 穿不上带这类标签的武器（canEquip 假、refresh 时卸下），探针只用技能量；实现时装备那支用重制自己的缓存单测，或另找能穿的防具补参照。

## 参照（已做）

`mv_oracle/pushstate_probe.cjs`（只写 `.sandbox/pushstate.json`，拷成 `tests/fixtures/pushstate_oracle.json`，不接全量同步），12 例。每例：新局、难度 2，角色 1 清技能／装备／状态后学被动，角色 8 生命 1 当友方目标，敌群 1 第一只当敌方目标；行动技能公式定 1000、无浮动不暴击；`makeDamageValue` → `onPreDamageStateEffects`，期间 `Math.random` 固定成用例的 rnd；记 value、confirmed、前后状态与回合数、缓存三类条数。

| 用例 | 被动 | 行动 | 目标 | rnd | 原版结果 |
| --- | --- | --- | --- | --- | --- |
| push.1580.hit | 1580 蔷薇刺鞭（PushState161 60%） | 技能 1 | 敌 | 0.5 | 敌挂 161（5 回合） |
| push.1580.miss | 同上 | 技能 1 | 敌 | 0.7 | 不挂 |
| push.1580.already | 同上 | 技能 1 | 敌（已有 161，回合定 1） | 0.1 | 不重挂，回合仍 1 |
| push.6510.hit | 6510（161 100%） | 技能 1 | 敌 | 0.99 | 挂 161 |
| pushsub.1491.hit | 1491 先祖赐福（PushsubState42 20%） | 技能 1 | 敌 | 0.1 | 自己挂 42 |
| pushsub.1491.miss | 同上 | 技能 1 | 敌 | 0.3 | 不挂 |
| pushsub.4458.noPercent | 4458（`<PushsubState0309: 100>`） | 技能 1 | 敌 | 0.99 | 自己挂 309 |
| pushsub.4680.decimal | 4680（`0.2%`） | 技能 1 | 敌 | 0 | 不进缓存、不挂 |
| rec.6706.ally | 6706 蔷薇进阶（RecPushState1561 100%） | 技能 8 治愈 | 友（角色 8） | 0.99 | 友方挂 1561 |
| rec.6706.enemy | 同上 | 技能 8 | 敌 | 0.99 | 敌挂 1561（不看阵营） |
| rec.6706.damage | 同上 | 技能 1 | 敌 | 0.1 | 伤害为正，不挂 1561 |
| rec.6706.already | 同上 | 技能 8 | 友（已有 1561，回合定 1） | 0.1 | 不重挂 |

## 下期清单（二期）

- 云裳拆段时整体挂一次（原版 `result._parts` 时 `_after` 在整体上执行）。
- 挂的时机挪到 Confirm 与 React 之间（XDamage.finish 里），和反射／掩护的交互。
- 异化逆祷（prayer）走 `_damage_value` 两层，`_push_sign` 取的是内层治疗值；原版 Codex 包装在逆祷包装之内，要定向参照再定。
- 装备那支：新局角色 1 穿不上带这类标签的武器，参照里没有装备用例；可找能穿的防具或换角色补一例（缓存代码同一条路径）。

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】伤害／治疗时挂状态（PushState 一期，dev.待定）

- **原版**：dsPassiveSkill 被动缓存收技能、装备、状态备注里的 `<PushStateN: p%>`（伤害为正时给目标）、`<RecPushStateN: p%>`（为负时给目标）、`<PushsubStateN: p%>`（伤害为正时给自己）；正式版生效的是 installDamageElementRuntime 的 makeDamageValue 包装（`result._after`），只认角色行动者，异化虚空的攻击伤害除外，逐条 `Math.random()*100 < p` 且目标没有该状态才挂。冻结源共 399 条（技能 175、武器 119、防具 105），重制原来全没有，蔷薇刺鞭破防、各种「造成伤害时为自己附加」都不生效。
- **重制**：
  - `actor.gd` `refresh_passive`：被动缓存加 `recPushStates`／`pushStates`／`pushSelfStates`，对象同原版（装备＋技能＋状态），正则同原版（状态号 parseInt、% 可省、概率只认整数）。
  - `battle_logic.gd`：`_damage_value` 记下 CodexDamage.calculate 的值（`_push_sign`）；`_apply` 在算完伤害后加一行 `_push_states`，按正负挂，掷骰用本场规则流（`push_state`／`push_self_state`），目标已有不挂；行动者不是角色、值为 0、异化虚空攻击都不挂。治疗挂状态不看阵营，照原版（Kyo 10-31）。
- **时机差一点**：原版在 Confirm 之后、React 之前挂，重制在整段结算（含 React）之后挂；只影响「受击方 React 效果读刚挂上的状态」这种组合，留二期核。
- **参照与专项**：`mv_oracle/pushstate_probe.cjs`（12 例，不接全量同步）→ `tests/fixtures/pushstate_oracle.json`；新专项 `tests/xiyou_pushstate.gd` 逐例比缓存条数、正负、挂给谁、已有不重挂（回合不被重置），52/52。

## 优化登记草稿

优化登记草稿：无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`pushstate_probe` 12 例无报错（正式冻结 v0.28）。
- 专项：`xiyou_pushstate` 52/52。反向：去掉 `_push_states` 钩子 46/52；去掉「目标已有不挂」51/52（already 用例回合被重置）；复原后全过。
- 相关战斗场景（本机）：待写
- 选测：`选测.py main` 选出 185 个场景（改了 actor.gd、battle_logic.gd），交总装合并时跑。注意：这套原来不生效，带这些被动的角色战斗结果会变，六难度对照（xiyou_rules*）若有带标签的角色可能要重看。
- 改动的原沙僧核心文件：`actor.gd`（`refresh_passive`）、`battle_logic.gd`（`_damage_value` 两行、`_apply` 一行、新 `_push_states`）。

## 本分支提交

- 36a3736a 参照探针与接手要点
- 8241fbe8 合并 main
- fc82a1df 被动缓存收三种标签、_apply 挂状态
- e5cfd62c 专项 xiyou_pushstate
