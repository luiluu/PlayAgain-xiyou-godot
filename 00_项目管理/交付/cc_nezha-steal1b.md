# 交付：cc/nezha-steal1b

- 车道／工作者：C 规则／哪吒（cc，Sonnet）
- 状态：进行中

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】YEP_LifeSteal 技能吸血：112 个技能的吸血生效（dev.待定）

背景：`插件备注覆盖.py` 报 `<HP Life Steal: N%>`（112 个技能，全是伤害类型 1）、状态 `<DBHPLSteal: N%>`（11 个）「没读」，重制里这些技能打伤害不回血。

**参照探针**（新）`mv_oracle/life_steal_probe.cjs` → 夹具 `tests/fixtures/life_steal_oracle.json`（冻结参照，不进 PROBES；86 例，约 75 秒）。量到的原版行为：
- 吸血在 `Game_Action.executeHpDamage` 里，装在 YEP_DamageCore 之外、护盾账本／AbsorptionBarrier／各 codex 包装之内；读的是 `target._result.hpDamage`（外层减过的实际伤害，**不被目标剩余血量夹住**：目标 1 点血挨 1340 照吸 floor(1340×N%)），≤0（零伤、治疗）不吸。
- 吸血量 = floor(伤害 × N%)（浮点次序照原样 `1-(1-(1-(1-N×0.01)))`），再乘行动者每个状态备注 `<DBHPLSteal: N%>` 的 N/100（**必须带 %**，不带被插件忽略；最后才取整，72+2570 → floor(402×0.6×0.08)=19），≤0 什么也不做；回血不封顶，超出 mhp 的被夹掉（85000% 的技能一下回满）。
- 命中类型 0／1／2 结果一样；多段命中每段各吸；敌人当行动者也吸；反击里谁出手谁吸。
- 角色（敌人不掷）吸血时按 状态→装备→技能 的顺序，对每件物品备注里**第一条** `<RecPushStateX: P%>` 掷一次（`Math.random()*100<P`）挂状态给自己，**已有也再挂一次**，先挂状态后回血。吸血量算出来 ≤0 就不掷。
- 角色／职业／装备／状态层的 LIFE STEAL Rate／Flat／CUSTOM／GUARD／CANCEL、MP 吸血在冻结数据里一条都没有，不实现。

**转换器**：`xiyou_export.py` 新 `parse_life_steal`，技能与物品记录加 `lifeSteal`（`hpRate`／`hpFlat`／`allNull`／`hpNull`；冻结数据里只有技能的 `hpRate`，112 条），`插件备注覆盖.py` 这三个标签转为「已读」。

**运行时**：新 `core/life_steal.gd`（`XLifeSteal.amount`／`push_rows`）；`battle_logic.gd` `_execute_hp_damage_ledger` 在 `_execute_hp_damage` 返回后调 `_life_steal`（不碰回合结束段）。随机理由新增 `life_steal_push`。

**专项**：`tests/xiyou_life_steal.gd`，86 例逐条比（行动者／目标生命变化、行动者身上的观察状态；回满的比「也回满」；穿装备的 4 例伤害链与参照差一点〔装备加成，不是吸血的事〕，改比状态和「吸血＝自己这一下伤害×30%」）。反向验证：去掉钩子后 86 项失败。

**探针与测试里的坑（给后人）**：新局敌人没走过 `need_refresh=true` 的 refresh，krz_state_re 的 `need_refresh_lifesteal` 没建，敌人吸血在探针里会 TypeError（探针造局问题，已加 `need_refresh=true`）；新局角色 1 穿不上有等级门槛的装备（refresh／开战整理会卸下），探针用 `canEquip=()=>true` 绕过，Godot 测试开战后再塞。

**没改任何原版规则，没有新优化，不占优化号。** 所有 112 个技能现在照原版回血，敌人用到这些技能（424 条敌人行动）也会吸——原版也吸。

## 交接板

- 下一步：无
- 用户试玩说明：用带 `<HP Life Steal>` 的技能（如技能 182 30%）打怪会按实际伤害回血；高倍率的（几百倍）一下回满。敌人用这些技能打玩家也会给敌人回血。
- 需要用户决定：无

## 验证

- 专项 `xiyou_life_steal` 通过（341 项）；`语法检查.py`、`探针登记检查.py` 通过。
- 云端选测（141 个场景，基准 6e4b7096d7）：待补。
- 待交叉核查（改了的核心文件）：`battle_logic.gd`（`_execute_hp_damage_ledger` 末加一行钩子＋`_life_steal` 函数）、`xiyou_export.py`（`parse_life_steal`）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ebf82d07 WIP: 探针、转换器、模块、钩子
- 9d8e0da8 专项 xiyou_life_steal
