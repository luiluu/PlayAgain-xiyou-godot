# 交付：cc/bailong-jingliu2

- 车道／工作者：E 角色专属／白龙_8（cc，项目线程「做渡鸦第三期战斗机制」）
- 状态：可合并
- 分支从 cc/bailong-jingliu1 末端 c502b4ba 切出（jingliu1 未合时一起带进来）。

## 变更记录草稿

## 2026-10-31 【cc·白龙_8·未经审查】镜流第二期：放血、绽放、追加段、裂隙演化、追加行动；渡鸦逆祷收割用例（dev.待定）

照原版 installNativeYomiJingliuRuntime.js 的镜流战斗包装（payBlood 第 285～296 行，apply 第 334～351 行，supplemental／queueJingliu 第 353～372 行，
endAction 第 374～421 行，startTurn／startBattle／endBattle 第 422～450 行，Game_Enemy.param 与 elementRate 第 167～183 行，extractSaveContents 第 485～490 行），
重制 `XYomiJingliu` 镜流第二期：

1. **施放准备**（`_invoke` 普通 apply 之前 `XYomiJingliu.j_before`，即 apply 包装里原 apply 之前那段）：剑技第一次打到活着的敌人时定主目标；10192 时用掉昙华绽放（伤害钩子 ×1.0666）；强化剑技放血——其余活着的出战队友各扣 min(floor(最大生命×3%／5%／8%), 生命−1)（走 `gain_hp`），累计进放血总量，本次伤害 ×(1＋min(累计/(5×最大生命), 上限−1))，上限 1.25／1.5／1.8（10192 学了 10202 为 2.5）；记下主目标当时有没有霜痕／裂隙。
2. **追加段**（`j_finish`，原 endAction 之前，返回追加段记录）：10188 主目标有霜痕再追一段并去霜痕；10190 主目标有裂隙时其余活着的敌人各追一段、主目标去裂隙；10192 全部活着的敌人各追一段、主目标去裂隙。追加段直接 `apply`（不再进 apply 包装），公式换进阶行（学了 10200～10202 各加一份），记录带 `supplemental`。
3. **裂隙演化**：10189 命中时目标记下「学没学 10201」；演化过且有裂隙时 `XEnemy.param(3)` floor(×0.89)（仓库倍率之外、首领倍率之内）、`XBattler.element_rate(3)` +0.0111。
4. **追加行动**：月魄从 <2 涨到 ≥2（每回合一次）、10192 真放了血且学了 10202（每回合一次）时，`act` 里行动次数加一之后 `XYomiJingliu.queue_extra` 把镜流插到本回合行动队首（本回合行动不到 5 次）；开回合重置两个标记。
5. **开战／结束／读档**：`start_battle` 清放血累计；结束战斗清全部战斗数据；`XState.from_dict` 末尾 `after_load` 按读进来的进阶次数整理技能（进阶 ≥1 学 10200～10202）、清放血累计。
6. **渡鸦逆祷收割（审查第 14 期 P3，上期挪来）**：探针实测原版——渡鸦穿逆祷异化武器（本体 1042）锁队后，鸦啄主伤害与狩猎收割、神话回响都扣不动敌人生命（wrapHp 帧内归零）。重制上期改成走 `gain_hp` 后同样为 0，专项补了这条用例和不穿逆祷的对照。
- 不做：星魂说明行（界面）、技能图标、追加段的战斗日志显示（记录带 `supplemental`，画面没接）。
- 参照：新探针 `mv_oracle/jingliu2_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5）14 例：四种连招 × 进阶 0／1 共 8、队友扣不动血 1、追加行动 1、读档 2、渡鸦逆祷与对照 2。产物拷成 `tests/fixtures/jingliu2_oracle.json`，**不接全量同步**。参照里 `eval('$gameParty._actors=[]')` 清队伍没生效，出战是新局的 1、8、9、10 加镜流五人，放血扣四个队友，专项照这个队伍比（探针注释已写明）。
- 专项 `tests/xiyou_jingliu2`（251 项）：扣血段（含追加段标记）逐条比目标与次序，数值比本例第一段的比值（1e-6）；每步月魄、绽放、放血累计、队友生命、霜痕／裂隙、敌人防御与寒冰抗性、行动队里镜流个数与两种追加行动标记逐项比；读档；渡鸦逆祷；开战清放血（只在重制，读码）。

## 优化登记草稿

优化登记草稿：无。

## 验证

- 专项 xiyou_jingliu2 251/251、xiyou_jingliu 104/104、xiyou_raven_battle 356/356（本机单跑）。
- 反向验证两轮，都已还原：①放血倍率不乘、10188 不追加段，100 项失败；②不插队、绽放不乘、裂隙演化不减防、读档不整理，42 项失败（只打出前 20 条：bloom、gap.r1、river.r1）。
- 相关战斗选测（本机，并行 2）：规则对照只比镜流（RULES_ONLY_ACTORS=170）xiyou_rules 与 d2～d6 共 6 个，343 秒全过；xiyou_jingliu2、xiyou_jingliu、xiyou_raven_battle、xiyou_mira_battle、xiyou_yomi_battle、xiyou_alien_battle、xiyou_battle、xiyou_battle_gaps、xiyou_otb、xiyou_custom_damage、xiyou_sukuna_battle、xiyou_garou_battle、xiyou_race_battle、xiyou_cat、xiyou_action_sequence、xiyou_battle_events、xiyou_actor_modules、xiyou_actor_p0、xiyou_save_events、xiyou_save_page、xiyou_raven_soul 共 21 个，71 秒全过（逐个看过日志都实际跑了），无偶发。
- 选测后合了 main（0bbb47fc，带进悟空 gaps3 的 battle_logic 改动与飞艇探针），无冲突；合后单跑 xiyou_jingliu2 251、xiyou_jingliu 104、xiyou_raven_battle 356 全过，其余没重跑。
- 没改切片、转换器、全量同步里的探针、界面，没跑同步。

## 交接板

- 下一步：镜流逻辑层做完，剩画面：星魂说明行（HelpExtend）、追加段的战斗日志（记录带 supplemental）、技能图标。
- 用户试玩说明：镜流的强化剑技现在会放血——扣其他队友少量生命换伤害加成；霜痕尽裂打有霜痕的敌人追加一段、碎月穿霜打有裂隙的敌人波及全场、寒川映月对全场追加；先放昙华生灭，下一次寒川映月更强；进阶后的断月剑让裂隙敌人减防、寒冰抗性变弱；月魄回到 2 层或寒川映月放血成功时，镜流本回合能再动一次。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：镜流约 260 行 0.5 → 0.85（战斗逻辑做完，剩界面），角色约 +0.5 个百分点（260×0.35÷8817×50≈0.52）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 发现（探针，给各车道）：`w.eval('$gameParty._actors=[];')` 在参照宿主里清不掉队伍（新局的 1、8、9、10 还在），几期探针注释写的「队伍 [角色, 1]」其实是五人。和队伍人数无关的机制不受影响；放血、群体治疗、掩护这类要照实际队伍比。要真清就改 `w.$gameParty._actors.length = 0`。

## 待交叉核查

- 原 Codex 核心文件：`battle_logic.gd`——`_invoke` 普通 apply 之前加 `XYomiJingliu.j_before`；`act` 与 `_force_action` 里的 `j_finish` 改成 `logs.append_array(...)`（追加段记录）；`act` 行动次数加一之后加 `XYomiJingliu.queue_extra`；`start_battle` 加 `XYomiJingliu.start_battle`。`enemy.gd` 的 `param` 包一层 `XYomiJingliu.enemy_param`；`battler.gd` 的 `element_rate` 返回值包一层 `XYomiJingliu.element_rate`；`xstate.gd` 的 `from_dict` 加 `XYomiJingliu.after_load`。没碰悟空 pushstate、八戒 toji2 的地方。
- `actor_damage_hooks.gd` 没改（绽放在 `j_damage_ops` 里）。

## 本分支提交

- 67c120e8 参照 jingliu2_probe 与夹具
- 5430dde7 第二期实现
- da8fc0aa 专项 xiyou_jingliu2
- d9df4275 交付单草稿
- 合并 main、补 xiyou_jingliu2.gd.uid、交付单可合并
