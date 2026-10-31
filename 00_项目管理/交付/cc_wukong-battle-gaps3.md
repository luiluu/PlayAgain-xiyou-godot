# 交付：cc/wukong-battle-gaps3

- 车道／工作者：C 规则（A 车道接）／悟空（cc）
- 基线：从 cc/wukong-battle-gaps2 末端 6617e5de 切出；开工时合了 main 14fbc124（含 gaps2、review-13、nezha-rollback1）。
- 状态：进行中

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】降众天华按 7.5% 收费、飞艇原版参照、两处回退支与条件断言（dev.待定）

- **O-129 降众天华 7.5%（Kyo 10-31 定：做）**：`XBattleLogic.note_costs` 在 `o_decimal_mp_cost` 开着时，MP 比例认小数（`<MP Cost: 7.5%>` → 最大 MP 的 7.5%），TP、HP 比例仍只认整数；关掉＝原版（YEP 正则只认整数，比例 0，只扣基础 1000）。消耗缓存按开关分开存。`xiyou_battle_gaps` 的 7225 改成例外登记：回退支按参照（原版）比，默认支按 ⌊(1000＋最大MP×0.075)×mcr⌋ 比、且大于原版，说明卡同样。
- **难度经验／金钱倍率加回来（Kyo 10-31 17:21 定）**：`XBattleLogic.o_difficulty_reward`（默认开）。挂点照 Vitsuno_Difficulty 本来的位置：它包的是 `Game_Enemy.exp／gold`，所以是**每只敌人** `floor(exp()×经验倍率)`、`floor(gold()×金钱倍率)`（exp()／gold() 已含神话倍率），在 expTotal／goldTotal（passiveGRUP 累乘、金钱双倍）、套装和 makeRewards 的 ×8／×5 **之前**。倍率取难度表「Drop Rate」前两项（难度 1 为 1.5、2 为 3、3 为 4.5、4 为 6、5～9 为 10、10～12 为 1、13～15 为 1.2～1.6、16～20 为 1）。关掉＝原版（被 EliteEnemy 盖掉、不生效），与 gaps2 的结果完全一样。物品掉落不动（原版作者注掉了难度掉率那段）。测试：`xiyou_battle_gaps` 的 21 例 reward.* 关着比参照、开着按参照每只敌人的 exp／gold 重算比；`xiyou_zhenqi_break` 比参照时关掉；`xiyou_battle` 默认按 3×⌊20×4.5⌋×8，另断言关掉时 3×20×8。
- **O-117 回退支**：`XMapScene.SAFE_AIRSHIP_MENU` 从 const 改成 static var；`xiyou_airship_fly` 在飞行中切到原版，断言传送按钮可点、G 键开始挂机，再切回、断言又锁上。`回退开关豁免.json` 去掉 O-117 那条（回退开关覆盖.py 不再报它）。
- **条件分歧 9／10（审查 10-31 D3／P3）**：断言从 `xiyou_floor_reach075._gear_conditions` 挪进事件解释器单元专项 `xiyou_script`，确定性构造：开局四人，先把队员身上那件武器、防具的底材从背包清掉——只穿在身上：不含装备假、含装备真（武器、防具各一）；背包放一件：两种都真（各一）；都没有：两种都假。
- **飞艇原版参照（75% 审查建议）**：新探针 `mv_oracle/airship_probe.cjs`（不接全量同步，产物拷成 `tests/fixtures/airship_oracle.json`，10 例）：
  - `xiyou_airship_state` 加比：新局三种载具（loadSystemSettings 后的图号、坐标、朝向、图、BGM、高度、驾驶）、条件 13（走路全假；乘飞艇只有 2 为真）、Map003 EV4／CE240／CE1002／CE10 里写飞艇的 202 执行后的落点、变量指定 202＋323＋140＋不存在的载具号。
  - `xiyou_airship_view` 每帧画面按参照同高度一行比：精灵上移（screenY 相对停地 −高度）、影子位置（shadowY，含行走图 shiftY 6，物件图 0）、透明度（shadowOpacity÷255）；升空逐帧序列与参照的 0→48 相同、最大高度 48；降落比参照 48→0 序列的对应尾段。
  - 量不了的：层级（重制的 z_index 是 Godot 自己的分层，原版只有 screenZ 1／5，没法逐数比，仍是读码断言）；上下艇的收拢跟随、BGM 切换、存读档后的画面（要整个 Scene_Map 跑帧，参照引擎没有地图场景）。另：原版 getOn 一刷新就 priorityType 2（高度 0 那一帧已在上层），重制高度 0 时仍画在角色下方，只差上艇第一帧，没改。

## 交接板

- 下一步：伤害／治疗时挂状态（见下面盘点）请总装排期。
- 用户试玩说明：战斗经验、金钱又按难度表的倍率乘了（普通难度 4.5 倍、高难度 10 倍），乘完再照原版 ×8／×5。降众天华现在按最大 MP 的 7.5% 加基础 1000 收法力（原版只收 1000）。其余是测试与参照，玩家看不到变化。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-129 | 7225 降众天华 MP 消耗（XBattleLogic.note_costs） | 备注写 `<MP Cost: 7.5%>`，YEP_SkillCore 正则只认整数，比例为 0，只扣基础 1000 MP | MP 比例认小数，按 7.5% 收 | 作者显然想按最大 MP 收费 | `XBattleLogic.o_decimal_mp_cost = false` | cc（悟空） | 已做（用户 10-31 定） |

| O-待定 | 难度经验／金钱倍率（XBattleLogic.o_difficulty_reward，rewards） | Vitsuno 难度表配了各难度经验／金钱倍率，但后装的 EliteEnemy 改写 Game_Enemy.exp／gold、不调前面的链，倍率从不生效；结算只有 ×8／×5 | 照 Vitsuno 挂点每只敌人 floor(exp×倍率)、floor(gold×倍率)，再走 goldTotal、套装、×8／×5 | 作者配了难度倍率却被插件顺序吃掉（Kyo 10-31 定：加回来） | `XBattleLogic.o_difficulty_reward = false` | cc（悟空） | 已做（用户 10-31 定） |

（O-129 是登记表里已有的行，合并时把那行的「优化」「恢复方法」「状态」照上表改；没有新 O 号。）

## 伤害／治疗时挂状态盘点（本期不做）

- 原版：dsPassiveSkill 把技能、装备备注里的三种标签收进被动缓存（`refreshPassiveCache`）：`<PushStateN: p%>` 伤害为正时给目标、`<RecPushStateN: p%>` 为负（治疗或吸收）时给目标、`<PushsubStateN: p%>` 伤害为正时给自己；每条按概率、目标已有该状态就不挂。正式版实际生效的是 installDamageElementRuntime 的 makeDamageValue 包装（`result._after`，在确认段执行，只认角色行动者，异化虚空的攻击伤害除外，拆段的云裳在整体上挂一次）。
- 冻结源：技能 PushState 135／RecPushState 18／PushsubState 22 条，武器 88／7／24，防具 72／11／22，共 399 条（状态、角色、职业、敌人没有）。重制全工程没有这套。
- 分期建议：
  1. 一期（C 车道）：被动缓存收三种标签（技能＋装备），`_apply` 确认段按 makeDamageValue 正负挂；定向探针量几件典型（蔷薇刺鞭 1580／6510、一件 PushsubState 武器、一条 RecPushState），带固定 Math.random 比挂不挂、挂给谁、已有不重挂。
  2. 二期：异化虚空例外、云裳拆段整体挂一次、与反射／掩护的交互，跑 slice 里有这些标签的角色抽样。
  3. 原版治疗挂状态不看目标阵营（早期 dsPassiveSkill 有 `target.isActor()`），照原版移植（Kyo 10-31：线上那个 bug 不归我们管）。

## 进度账

- 战斗规则、地图载具：补参照与断言，完成度不变。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 待写

## 本分支提交

- 待写
