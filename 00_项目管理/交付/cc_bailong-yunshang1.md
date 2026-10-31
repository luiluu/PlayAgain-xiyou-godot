# 交付：cc/bailong-yunshang1

- 车道／工作者：E 角色专属／白龙_9（cc，接白龙_8 的盘点）
- 状态：WIP（代码、参照、专项已写，等同步与选测）
- 分支从 cc/bailong-jingliu2 末端 8740add3 切出，白龙_8 盘点提交 10eaa282；白龙_9 在工作树 great-snyder-6f0aed 接手（heuristic-wing-4e9b42 改成游离 HEAD 让出分支，没有改动），合过 main（带进甚尔第一期）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_9·未经审查】云裳第一期：入切片、招募、技能同步、能力值、被动、公式、伤害钩子与本人战斗包装（dev.待定）

照原版 installNativeYunshangRuntime.js（W.CodexYunshang；配置第 5 行，sync／setup／levelUp 第 51～56 行，param 第 57～70 行，recruit 第 206 行，
meetsSkillConditions／itemHit／itemEva／itemCri／numRepeats／makeTargets 第 251～265 行，offensiveGrowth／refreshPassiveCache／formula 第 266～283 行，
startAction 记主目标第 394 行，伤害钩子 yunshang 第 749～773 行），新模块 `XYunshang`（`modes/xiyou/core/yunshang.gd`）：

1. **入切片**：`xiyou_slice.json` 的 actors 加 174；转换器 `formula_program.py` 把 `CodexYunshang.formula(this,a,b)` 记成模块公式 yunshang，`formula_execution.gd` 调 `XYunshang.formula`。
2. **招募**（公共事件 9010 的 `CodexYunshang.recruit()`，超强者门槛已有）：入队、同步；本档第一次给一件织神天梭 7935 进背包（只进背包、不装，存档旗标 `_codexYunshangRecruited`）；提示「云裳已加入队伍」。原版进阶次数取订单账本（独立文件），重制的进阶次数本来就在存档里，不另设；账本、订单、天衣铺是养成期。
3. **技能同步**（`XActorModules` 的 setup／level_up／level_down 挂点）：10270～10281 与天衣铺 10287 按 [等级, 进阶] 门槛学／忘；10282～10286 是天衣给的技能，不在这里学。
4. **能力值**（`XActorModules.param`）：最大生命／魔攻／敏捷 ×1.5（25 级）／2（30）／2.5（35 且进阶≥1）／3（40 且≥1）／4（50 且≥2），取整、夹上下限。
5. **被动缓存**（`XActorModules.passive_cache`）：学了云丝展幅 10276 时 n＝min(99,等级)−24，暴伤 +1.88n、终伤 +0.1888n；戴织神天梭终伤 +3。
6. **公式** `XYunshang.formula`：钉影 66.66／拆神 111.88／符针 33.33 ×max(0,魔攻−防×0.1)，收针 246.21×max(0,魔攻−防×0.05)×觉醒回合数（第一期 0），山河击 888.88×max(0,物防＋魔防−防×0.1)；伤害计算里防为 0，计算外取目标魔防。
7. **伤害钩子** yunshang 的 build（`XActorDamageHooks.capture` 加 `XYunshang.damage_ops`）：云裳的伤害行动定魔法；双针并行 10277 技能倍率 ×0.555；云丝展幅时单体行动打非主目标 ×0.77（银针织阵 10278）／0.66（双针）／0.5；戴织神天梭技能结算 ×1.99。原版 makeDamageValue 那层被后装的 installDamageElementRuntime 整个换掉，不生效，同黄泉／宿傩不移植。
8. **本人战斗包装**（battle_logic 六处一行）：云裳的伤害技能必中、不闪避；戴织神天梭会暴击的行动暴击率 +3（必暴击）；双针并行时伤害行动段数 ×2；云丝展幅时单体对敌伤害行动打主目标再打其余活着的敌人；主目标＝targets_for 后第一个（原版 startAction 包装的 _yunPrimary）；能不能用：没解锁不能用、敕衣点神 10273 要有活着的出战成员穿天衣、收针 10274 要有人觉醒（觉醒是第二期，现在一直不能用）。
- 第二期（未做）：觉醒（敕衣点神）、赊账、幽灵、借技能、赠行／储行、拆段 split、符针、御风敏捷 ×1.33、天衣 15 件各自的战斗效果（含六衡裁身、万法同裳 categoryMax）、自动战斗 AI。
- 不做（别的期）：订单账本、天衣铺页面、进阶、天衣图标与多帧立绘、说明行。
- 参照：新探针 `mv_oracle/yunshang_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5）24 例：各级×进阶的技能、能力值、暴伤／终伤 13，戴织神天梭 2，降级 1，公式 1（12 行），招募 1，战斗 6（20／25／30／30 戴梭／35 进阶 1／35 进阶 1 戴梭）。产物拷成 `tests/fixtures/yunshang_oracle.json`，**不接全量同步**。探针宿主的队伍清不掉（addActor 会补回 1、8、9、10），战斗例把 174 排到 `_actors` 与出战表 `_battleMembers` 第一位，并开挑战开关 2494（超强者才能出战）。
- 专项 `tests/xiyou_yunshang`：逐例比技能、八项能力值、暴伤／终伤；公式 12 行（1e-9）；招募；战斗每段技能／目标／暴击、伤害比值（1e-6）、每步六个技能能不能用。`xiyou_actor_p0` 的招募表补 9010。

## 优化登记草稿

优化登记草稿：无（本期没有改原版行为的地方）。

## 验证

（待补）

## 交接板

- 下一步：云裳第二期——觉醒与天衣各件的战斗效果（量大，建议按天衣分两批），以及赠行／储行行动来源（异化绝缘拦截等着它）。
- 用户试玩说明：云裳现在能用云裳号角招募入队（第一次招募送织神天梭进背包）。她的技能按等级与进阶自动学会；伤害技能必中、走法术；25 级起技能会扩散打全体（非主目标伤害减半），30 级起每次打两段；戴上织神天梭必暴击、技能伤害约 ×2。觉醒与天衣的效果下一期才有，敕衣点神与收针现在还用不了。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：云裳（installNativeYunshangRuntime.js 772 行，战斗与基础约 450 行）完成度 0 → 0.3（入切片、基础、本人战斗包装；剩觉醒与天衣战斗、养成与界面），角色约 +0.8 个百分点（450×0.3÷8817×50≈0.77）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 发现（文档）：白龙_8 写的「探针宿主清不掉队伍，改用 `_actors.length = 0`」这条也不对：`addActor` 会把 1、8、9、10 补回来（installBossDifficultyRuntime 的 enforceParty 之类），出战看的是 `_battleMembers`。要让新角色出战，得把它挪到 `_actors` 和 `_battleMembers` 前面，超强者还要开挑战开关 2494。可以在 `mv_oracle/README.md` 写一句，免得下个探针再踩。

## 待交叉核查

- 原 Codex 核心文件：`modes/xiyou/battle/battle_logic.gd`——`item_hit`／`item_eva` 加 `XYunshang.sure`；暴击率在小猫之后加 `XYunshang.cri`；两处段数外层套 `XYunshang.repeats`；`targets_for` 里 `_targets_for` 外套 `XYunshang.targets`（在异化 filter_targets 之内），末尾 `XYunshang.set_primary`（异化逆祷随机友方那条也记）；`can_use` 在甚尔前加 `XYunshang.meets`。
- `actor_modules.gd`：IDS 加 174、setup／level_up／level_down 加 `XYunshang.sync`、param 最外层套 `XYunshang.param`、passive_cache 加 `XYunshang.passive_cache`。`actor_damage_hooks.gd` capture 加 `XYunshang.damage_ops`。`formula_execution.gd` 加 yunshang 分支。`mv_script.gd` 接 `CodexYunshang.recruit()`。
- 切片：`xiyou_slice.json` actors 加 174；转换器 `formula_program.py` 加模块公式映射。
- 核查时可留意：原版 param 包装最后的取整夹值对**所有角色**都做（第 69 行），重制只给云裳做；前面各层已取整夹值，其余角色应无差别，没单独测。

## 本分支提交

- 10eaa282 白龙_8 盘点
- 0a1d3cb7 云裳第一期接线
- 合并 main
- WIP：主目标、参照与专项
- 本提交：交付单草稿
