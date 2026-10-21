# 交付：claude/bajie-40-25f7f4

- 车道／工作者：C 规则·机制／八戒（Claude，重制_八戒_40）
- 状态：可合并
- 收尾验证：两次 git merge main（第二次解决 sequence_gain 一处冲突）后 `新建工作树.sh --补齐`、`同步正式西游.py --accept-additions`（测量不变，battle_events 两例新增已在本分支前两次同步接受），`检查.sh --oracle` 全部通过（105 个 Godot 场景，无偶发重跑；floor16 25/25、transform_params 249/249、battle_events 108/108），runId 1888eed87a634446a745f5137bfcf4da。

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】336 变身能力值惰性缓存（dev.待定）

- 依据沙僧 codex/transform-param-cache 交付单的 40 项预检与实施设计。另读冻结源 krz_state_re：Game_Enemy.param 在 inBattle 时走 _ParamCache2／need_refresh_param，refresh 只在 need_refresh 为真时让八格一起变冷；本轮在 .sandbox 用调用栈追踪确认原版 refresh 的时点（useItem 付费后、removeImmortal、Game_Unit.onTurnStart、onTurnEnd 内 regenerateAll、endTurn 的 refreshAllMembers、加减状态与 buff 内部）。
- 正式参照：battle_event_probe.cjs 新增独立例 command336.param-cache-466（敌群 466 敌人 534→538，难度 3，开战后），既有 8 例与顶层 fixture 不动，契约 battle_event_contract.py 登记新 id；同步 --accept-additions 只新增此例。内容：开战初始格子、九种预热组合、连续变身、22 个刷新边界（refresh／setHp／setMp／加减状态 4、clearStates 与 recoverAll 各带不带 77、addBuff／addDebuff／removeBuff、onTurnStart／onTurnEnd、显式 dirty、gainHp／Mp／Tp 非零与零、gainSilentTp）、5 组真实解释器序列（336→334、336→334→334、336→333 加 4／加 77／去 4→334）。每步只读原始格子与 dirty，规定位置才读 2～7 号参数。
- 实现：XBattler 加 param_cells（8 格，null＝冷格，0 也算命中）与 param_dirty（与格子有效分开）；XEnemy.param 战斗中经 cached_param 惰性填格。XBattleLogic.setup 最后（逃跑率读敏捷之后）param_cache_begin，end_battle 退出。接入：add_state 新附加才 refresh＋标 dirty（已有状态只续回合）；remove_state 有该状态才 refresh、总标 dirty；XResourceContext.refresh 开头消费 dirty；gain 按请求值非零在调用结束后标 dirty，silent_gain 与 gain(0) 不标；sequence_buff 的 addBuff／removeBuff 标 dirty、addDebuff 不标；useItem（含防御）付费后 refresh；行动序列 IMMORTAL 解除及无序列技能收尾对目标 refresh；回合开始标 dirty 后 refresh；回合结束拆成 turn_end_battler（前后各标 dirty、中间 refresh）再全员 refresh；333 补的截资源不当场消费刚标的 dirty。去掉 stale_caps：变身不标 dirty，334 回满直接读缓存上限（含 77 与变身旧形态两种旧上限）。
- 新测试 xiyou_transform_params（249 项）逐项比格子、dirty 与读数，另测克隆隔离（克隆读冷格不暖原对象）与战斗结束退出缓存。xiyou_battle_events 夹具 put() 按参照快照同步缓存（快照读全八项、夹具最后一步留 need_refresh）。
- 审查 XFormulaContext：effectful 路径按属性逐个读（_row 未被调用）；pure 路径按公式计划预读，计划跨三元分支收集，可能比原版多暖一格——只有之后未经 dirty 刷新又遇 336 才会显出差异，登记为残余风险，不改公式适配层。预览 clone_battler 深拷贝格子，隔离已测。
- 未仿真：角色的同类缓存（Game_Actor.param）、xparam／sparam 缓存、不受 inBattle 限制的 paramRate 缓存（334.hidden 参照在战斗外，靠它留住 77 的上限；Godot 用战斗内格子表达同一结果）、applyModifyBuffTurns 的 refresh。
- KNOWN_TRANSFORM_GAPS 已在 dev.101 删除；本轮把框架维护约定 battle_events.466_538 行「其他能力值旧缓存的完整仿真未实现」改为已实现及未仿真范围。

## 2026-10-21 【Claude·八戒·未经Codex检验】加状态后卸下封印类型装备（dev.待定）

- 原版实测（battle_event_probe 新增 actor104.seal-release-1691）：难度 3、角色 104 学 6168／5980／5548，开战按标签顺序附加 995／1691／1631；附加 1691（特性 54 封印 15 圣器／16 坐骑／18 宝宝／19 形态）时 addState 内部的 Game_Actor.refresh 先 releaseUnequippableItems(false)，布丁（宝宝）与特殊[变大]（形态）卸进队伍背包，生命上限 1250→800；战后 1691（Permanent、不随战斗结束解除）仍在，两件 canEquip 为假，不会自动穿回。
- 不登记优化：被动 5980「难度适应」的说明写明「无法装备宝宝，坐骑，圣器，形态」，难度 2～4 卸下且战后不能再装是原版设计，不是缺陷。
- 实现：XActor.release_to_party（release_unequippable 后刷新被动；只有 XState.current 里的本体才把卸下的件放回背包，战力预览等克隆只卸不入包），接在 add_state（新附加）、remove_state（有该状态）与 refresh_resources（Game_Actor.refresh）上。xiyou_rules 去掉 _mv_refresh 模拟，改走真实 add_state／refresh_resources；xiyou_battle_events 新增 seal1691 四项对照（开战前、开战后、战后、仍不能装）。
- 接入后对齐的测试夹具（都是夹具先前绕过了原版会做的卸装／刷新）：xiyou_combat 把指虎（武器类型 5）改给能用的修 8（狗逍遥 1 职业不能用，开战附加状态时会被卸）；xiyou_custom_params 对参照 direct 例（直接装上别的角色专属件，参照在实例上停掉 releaseUnequippableItems）设 XActor.keep_unequippable；xiyou_zhenqi_daofa 同参照在加／去 2705 后 refresh 再读防御（期一缓存）；测试共性验收的 battle_events 用例数改按契约 CASE_IDS。
- 观察未核实：参照直接调 $gameParty.onBattleEnd 后 1631（removeAtBattleEnd）仍在，Godot 战后会去掉；未经真实战斗结束流程确认，seal1691 战后对照不比 1631，留作后续查证。

## 2026-10-21 【Claude·八戒·未经Codex检验】十六层副本测试并行偶发（dev.待定）

- 没有可复现的失败现场：各工作树与本地结果里只留下通过的日志，flaky.jsonl 未记 floor16；本轮 4 份并发、--max-fps 6／8 降帧单跑都 25/25。改为按读码找出的两处负载相关竞态实修，而非重跑：
  - 首领战靠眩晕（1 回合、回合末解除）拖到第 4 回合，测试每个渲染帧补一次，战斗主循环按物理帧推进；负载高时一个渲染帧可补跑多达 8 个物理帧，回合末解除后到下回合角色出手之间来不及补，队伍会提前打死首领。改为眩晕剩余回合拉满，不再依赖补的时机。
  - 各段 90 秒墙钟等待上限在满负载并行时偏紧（单跑全程约 51 秒，首领战占一半），放宽到 300 秒（仍在单场 600 秒上限内）。
  - 各工作树共用同一 user://（工程名相同），存档／设置目录改按进程区分，免得同时跑的另一份删掉本份的文件。
- 与八戒_31（dev.106 首领宝箱改选「离开」）无关；那处是变量 106 的随机分支，本轮不动。根因无法用失败日志证实，若此后仍偶发须保留日志再查。

## 交接板

- 下一步：Codex 核查本分支三期（缓存接入点是否漏掉原版 refresh／dirty 时点，尤其行动中途与回合交界；卸装只放回队伍本体背包；floor16 竞态修法）。角色能力值缓存、paramRate 缓存与 1631 战后残留是否要仿真／查证另议。
- 用户试玩说明：变身首领（如三十层玉皇 466→538）变身前读过的能力值会留旧形态，直到下一次状态／回合刷新，与原版一致；难度 2～4 首战开打时，角色身上的宝宝／坐骑／圣器／形态装备会卸进背包，之后不能再装（原版设计）。
- 需要用户决定：无。

## 进度账

- 战斗规则：完成度不调整（既有缺口修复与测试稳定性），由 Codex 核查后再定。

## 本分支提交

- 85e772b WIP：探针新例、缓存与新测试
- a5409e9 336 变身能力值惰性缓存（期一）
- fe4d5ed 交付单：期一草稿
- 15b7caf 加状态后卸下封印类型装备（期二）
- adf8a1c 期二：seal1691 战后只比 1691 与装备背包
- 1817fd9 期三：xiyou_floor16_dungeon 去掉负载相关的竞态
- 2ad07da 合并 main
- eaa5191 全检修正：测试夹具对齐参照
- 8414298 再合并 main（sequence_gain 返回弹字值与 krz dirty 并存）
