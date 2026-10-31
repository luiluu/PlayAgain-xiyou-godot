# 交付：cc/bailong-jingliu1

- 车道／工作者：E 角色专属／白龙_8（cc，项目线程「做渡鸦第三期战斗机制」）
- 状态：同步与选测在跑（跑完改「可合并」）
- 分支从 cc/bailong-raven3b 末端 738b7468 切出（raven3b 未合时一起带进来）。

## 变更记录草稿

## 2026-10-31 【cc·白龙_8·未经审查】镜流第一期：入切片、技能整理、星魂、公式、伤害钩子、月魄（dev.待定）

照原版 installNativeYomiJingliuRuntime.js 的镜流部分（W.CodexJingliu：常量与 J.damage 第 6～113 行，paramBase 第 115～127 行，
itemHit／itemEva 第 191～204 行，numRepeats 第 254～265 行，meetsSkillConditions／paySkillCost 第 264～283 行，apply 第 334～351 行，
endAction 第 376～421 行，startTurn／endBattle 第 422～450 行，normalizeJingliuSkills／setup 第 453～484 行，伤害钩子第 740～752 行），
重制 `XYomiJingliu` 镜流第一期：

1. **入切片**：`xiyou_slice.json` 的 actors 加 170；转换器 `formula_program.py` 把 `CodexJingliu.damage(a,b,10187～10193)` 记成模块公式 jingliu，`formula_execution.gd` 调 `XYomiJingliu.j_formula`。招募（公共事件 9005 的 `CodexJingliu.recruit()`）黄泉第一期已接好，`xiyou_actor_p0` 的招募表补 9005。
2. **技能整理**（`XActorModules.setup` → `XYomiJingliu.setup`，即 setup 包装的 normalizeJingliuSkills）：10187～10196 按解锁等级学／忘，忘掉 10197～10199，进阶 ≥1 学 10200～10202。之后升级照职业习得表（参照证实各级技能一致）。
3. **星魂**（学了命途：毁灭 10194 且到级）：新挂点 `XActorModules.param_base`（`XActor.param_base` 末尾）——20 级、40 级各再加一份最大生命基础值，35 级再加一份攻击基础值。
4. **公式** `j_formula`：(攻击×r0＋最大生命×r1)×剑势均衡(0.85＋0.15×小/大，生命按 17463/136584 折算)×月魄(1＋0.06×(月魄−2.5)，用付费前的月魄)×印记(霜痕 2628、裂隙 2629 各 +0.1)×守势；守势在伤害计算里恒为 1（CodexDamage.isCalculating），计算外按目标防御另乘（参数 calculating）。
5. **伤害钩子** yomi-jingliu 的镜流部分（`XYomiJingliu.damage_ops` 分派到 `j_damage_ops`，capture 不用改）：剑技物理；戴月魄剑匣（技能类型 4 除外）普通伤害 +0.25；寒冰伤害：星魂 25 级寒冰 +1，10187／10189／10191 星魂 30 级 ×2，强化剑技星魂 45 级 ×2，10192 学了 10202 ×1.1。原版 makeDamageValue 包装被 installDamageElementRuntime 换掉不生效，同黄泉不移植。
6. **战斗**（共用黄泉的挂点，battle_logic 另加四行）：剑技必中不闪避（`sure`）；段数固定 {1,3,2,5,2,7,1}（`begin_action`）；月魄 0～3：开回合满 3（`start_turn`）、强化剑技 10188／10190／10192 要 ≥1（`meets`）、付费时开施放帧并扣 1（`pay`）、10187／10189／10191 命中或 10193 打到敌人后 +1（25 级学了朔望盈满 10195 时前三个 +2），10187 命中给主目标霜痕、10189 给裂隙（`j_applied`／`j_finish`），结束战斗清零。
- 第二期（未做，约 90 行）：放血（强化剑技扣队友生命 3%／5%／8%、累计倍率）、昙华绽放（10193 后的 10192 ×1.0666）、强化剑技的追加段与去印记（10188 霜痕追加、10190 裂隙扩散、10192 全体）、裂隙演化（学了 10201：目标防御 ×0.89、寒冰抗性 +0.0111）、月魄到 2 与放血后的追加行动（OTB 插队）、开战清放血累计、读档时技能整理（extractSaveContents）。
- 不做：星魂说明行（HelpExtend，界面）、技能图标与立绘、Map132 号角（已由 dev 早期的 Map132 商店期接好）。
- 参照：新探针 `mv_oracle/jingliu_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5）15 例：各级技能与能力值 9、忘掉 10194 1、公式 112 行 1、招募 1、战斗月魄与印记 2（45 级、20 级）、伤害钩子比值 1。产物拷成 `tests/fixtures/jingliu_oracle.json`，**不接全量同步**。探针里战斗外 addState 附加不上印记，公式例直接写状态表；剑技要求武器类型，战斗例给一把能装的剑（编号 2）。
- **帧内 gainHp（审查第 14 期 P3，总装八加派）**：`XBattleLogic.gain_hp(b, 值)` 走资源上下文的 gain（宿傩伤口、异化 wrapHp 帧内逆祷归零／烈变加成、连命／嫁祸／空壳路由、首领扣血上限），渡鸦收割／回响（`XRaven._direct`）与米拉劫火追加（`XMira.end_turn`）改用它，不再直接写 hp。xiyou_raven_battle 356/356、xiyou_mira_battle 287/287 不变（普通敌人上两条路结果相同）。**原版用例「逆祷者穿着时收割为 0」没做，挪到下一期**：重制的逆祷帧（`_action_frames`）只在 apply 里压栈，收割在 endAction 之前、apply 之外，帧可能已经弹出；原版那一刻有没有帧要用探针实测（要在参照里给渡鸦穿上带逆祷词条的异化装备），实测前不好断言归零。
- 专项 `tests/xiyou_jingliu`（104 项）：技能、八项能力值、paramBase 逐级比；公式 112 行逐条比（1e-9）；招募；战斗每步月魄、霜痕／裂隙、强化剑技能不能用，非强化剑技的扣血段逐条比目标并比比值；剑匣与星魂的伤害比值。

## 优化登记草稿

优化登记草稿：无（本期没有改原版行为的地方）。

## 验证

- 专项 xiyou_jingliu 104/104（本机单跑）；xiyou_raven_battle 356/356、xiyou_yomi_battle 142/142（单跑，确认改动没碰坏）。
- 反向验证两轮，都已还原：①星魂 20 级不加、印记不加成、命中只回 1、剑匣不加、段数改 1 一起改，26 项失败；②剑匣不加、段数改 1、月魄 0 也能用强化剑技，10 项失败（battle 7、hook 3）。
- 同步一轮（`同步正式西游.py --accept-additions`）：在跑。
- 角色相关专项与选测：待同步完再跑。

## 交接板

- 下一步：镜流第二期——放血、绽放、强化剑技追加段与去印记、裂隙演化、追加行动、开战清放血、读档整理（约 90 行，本期的施放帧 `_j_frame` 已留好主目标与命中）。
- 用户试玩说明：镜流现在能在号角招募后入队出战：剑技必中，每回合开始月魄满 3 层，强化剑技每次耗 1 层，落霜剑／断月剑／无罅飞光命中回月魄（25 级起回 2 层），落霜剑给敌人挂霜痕、断月剑挂裂隙，带印记的敌人挨剑技更疼。强化剑技的放血和追加段下一期才有。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：镜流（installNativeYomiJingliuRuntime.js 760 行里镜流约 260 行）完成度 0 → 0.5（入切片、基础与战斗主干；剩第二期战斗机制与界面），角色约 +0.7 个百分点（260×0.5÷8817×50≈0.74）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 发现（工具，给哪吒参考）：`godot --headless --path . --check-only --script res://<文件>.gd` 在本工程能报出**解析错误**（常量重名、类型推断这类）和行号，只是解析过了之后会因为 GameApp 自动加载没载入报一串 Compile Error；看第一条 Parse Error 就够用。garou3 交付单说「没法单独查语法」，其实先看这一条能省一整轮测试槽。可以做个包装脚本只打 Parse Error。

## 待交叉核查

- 原 Codex 核心文件：`modes/xiyou/battle/battle_logic.gd`——新函数 `gain_hp`（`_state_remove` 之前）；`start_turn` 加 `XYomiJingliu.start_turn(self)`；`act` 在黑闪收尾之后、渡鸦收尾之前加 `XYomiJingliu.j_finish`，`_force_action` 同位置加一行；`_invoke` 普通 apply 之后加 `XYomiJingliu.j_applied`。必中、段数、能不能用、付费、结束战斗走黄泉已有的挂点（函数里加了镜流分支）。没碰 note_costs、经验奖励、防御 TP（悟空）与甚尔（八戒）。
- `modes/xiyou/core/actor.gd`：`param_base` 末尾改成 `return XActorModules.param_base(self, i, v)`；`actor_modules.gd`：IDS 加 170、setup 加 `XYomiJingliu.setup`、新挂点 `param_base`。
- `actor_damage_hooks.gd` 没改。`raven.gd` 的 `_direct`、`mira.gd` 的 `end_turn` 改用 `gain_hp`。
- 切片：`xiyou_slice.json` actors 加 170；转换器 `formula_program.py` 加模块公式映射。

## 本分支提交

- 5bfa51e2 镜流第一期接线
- （常量去重）
- 1670004d 参照 jingliu_probe 与专项 xiyou_jingliu
