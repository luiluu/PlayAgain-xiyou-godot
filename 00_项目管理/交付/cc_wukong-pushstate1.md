# 交付：cc/wukong-pushstate1

- 车道／工作者：C 规则／悟空（cc）
- 基线：从 cc/wukong-battle-gaps3 末端 d38414b7 切出。
- 状态：进行中（第一步参照探针已做；实现等新会话的悟空接手）

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

## 下一步（实现，留给新会话）

1. `actor.gd` 被动缓存收三种标签（装备＋技能＋状态，顺序同原版），概率只认整数、% 可省。
2. `battle_logic.gd` `_apply` 确认段一行钩子：只认角色行动者，按 makeDamageValue 结果正负挂，用本场随机流掷（`random.*`，概率 `< p/100`），目标已有不挂。
3. 新专项（如 `tests/xiyou_push_states.gd`）逐例比 `pushstate_oracle.json`；反向验证（去掉钩子应失败）；再跑涉及被动的战斗专项。

## 变更记录草稿

（待写：实现完成后补）

## 优化登记草稿

优化登记草稿：无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`pushstate_probe` 12 例无报错（正式冻结 v0.28）。没改 Godot 代码，没跑 Godot。

## 本分支提交

- （见 git log d38414b7..HEAD）
