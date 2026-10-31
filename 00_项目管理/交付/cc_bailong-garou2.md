# 交付：cc/bailong-garou2

- 车道／工作者：E 角色专属／白龙_7（cc，项目线程「做饿狼第二期」local_f2e515ec）
- 状态：可合并

任务单没等到（唐僧总装六换班前排队中），照车道表那一行的范围做：形态能力倍率、行动次数，进阶（累计突破、神之触媒）与法宝进化逻辑层。

## 变更记录草稿

## 2026-10-31 【cc·白龙_7·未经审查】饿狼第二期：形态倍率、行动次数、累计突破与进阶、法宝进化（dev.待定）

照原版 installNativeGarouRuntime.js 的 paramRate／makeActionTimes 包装（第 174～182 行）、G.breakthroughs／reason／advance（第 12～13、90～137 行）、G.evolveRelic（第 18～70 行）、changeEquip 包装（第 191 行）、startBattle／creditVictory／processVictory（第 263～274 行）与 G.form 的 10269 门槛（第 386 行），重制 `XGarou` 第二期：

1. **形态能力倍率**（paramRate 包装）：`XActor.param_rate` 末尾乘 `XActorModules.param_rate` → `XGarou.param_rate`：生命、物攻、物防、魔攻、魔防、敏捷按形态 form_multiplier（赤发 1.11 起，星空生命 3.33、物攻／魔攻 5），魔法、幸运恒 1；没学 10269 破限成长按人类形态（全 1）。其他角色返回 1，不变。
2. **每回合行动**（makeActionTimes 包装）：`XBattleLogic.make_action_times` 对饿狼直接返回形态行动次数（四臂、星空 2，没学 10269 为 1），不再掷追加行动。
3. **累计突破与神之触媒**：`_garouBreakthroughs`／`_garouCatalystGranted` 存进 `XState.garou`，存档键 `codexGarou`（`{breakthroughs, catalyst}`；旧档没有该键＝0、没给过）。开战（`XBattleLogic.setup`）同步一次并记下出战栏里的饿狼与是否 Boss 战（敌群含隐藏成员有 MOG_BossHP 血条：插件参数 boss-N 列出的 556 个敌人）；胜利结算（`grant` 开头，原版 processVictory 之前）+1、Boss 战 +5，夹到下一形态门槛（33／66／99／166／266／333，星空 333）。四臂以上、50 级、333 突破的 Boss 战给一次神之触媒 2939，提示「饿狼突破神之境界，获得神之触媒×1。」存进 `XBattleLogic.victory_texts`（**画面还没接**）。同步时突破夹到当前门槛。
4. **进阶**（Scene_ActorAdvanced 两个确认包装）：`XAdvance.missing` 对饿狼先查 `XGarou.reason`（有下一形态、等级、累计突破、四臂进星空要神之触媒×1），不满足只给原因；`XAdvance.advance` 对饿狼走 `XGarou.advance`：确认的形态不是当前形态时作废，遗忘 → 学会 → 形态 +1 → 同步 → 星空扣 1 个神之触媒（进阶表里的 2939×1 不重扣）。熟练度继承重制没有熟练度、出错回滚 GDScript 没有异常，都不做。
5. **法宝进化**（G.evolveRelic，同步时）：戴着的破限之心换成当前形态的模板（7904～7911），保留实例相对旧模板的差值：能力值相加；特性按「代码:数据」归组，比率类（11／12／13／21／23）连乘求比、加值类（22／32／61）相加求差，差值追加在新模板特性后，其他特性按条带走；备注＝新模板备注＋多出的行；其余字段（说明、meta、equipment 等）实例没改过就取新模板；等级、经验保留；名字等于旧模板名的换新名，含旧名的替换。换装（`XEquipment.change` 末尾 `XActorModules.equip_changed`）后同步一次。法宝只给饿狼由备注 `<req_actors: 173>` 管（已有）。
- 原版的不合理处（不照搬，界面层）：describeRelic 每次同步往法宝备注写 `<CodexGarouHelp>` 说明块，进化时旧说明块的行被当成额外备注带走、再被正则半删，备注里残留旧形态说明行（如「当前等级:37 / 888」）。重制备注里不写说明块，所以没有这个问题；参照只量「新模板备注的各行都在」「额外行还在」。
- 不移植（第三期起）：进化／解析／反击／追击与伤害钩子 garou、itemCnt、技能使用条件、技能分类与指令窗、进阶界面的饿狼提示（重制走 `XAdvance.fail_text`，前面多「进阶条件未达成：」）、星空外观、法宝说明、读档时同步（原版 extractSaveContents 包装）。
- 参照：新探针 `mv_oracle/garou_progress_probe.cjs`（正式 CodexGarou，全内存新局；饿狼是超强者，招募要开挑战开关 2494）34 例：模块常量 1、各形态倍率／行动／能力值 7、进阶条件 9、进阶链 1（人类招募后改法宝实例，逐阶到星空）与缺触媒 1、换装进化 1、胜利 9、Boss 血条 1、同步夹突破 4。产物拷成 `tests/fixtures/garou_progress_oracle.json`，**不接全量同步**（同 battle_gaps_probe）。
- 专项 `tests/xiyou_garou_progress`（178 项）：逐例比上面各项；另核 `XAdvance` 分派、战斗挂点（开战记饿狼与 Boss 战、grant 两次只记一次、行动 2 次）、存档往返与旧档。
- 反向验证：倍率去掉 10269 门槛、行动次数恒 1、特性差值不追加、星空不扣触媒，四处一起改共 23 项失败（倍率与能力值 12、行动 3、法宝 6、触媒 2），已还原。

## 待交叉核查

- 原 Codex 核心文件：改了 `modes/xiyou/battle/battle_logic.gd`（make_action_times 开头分支；setup 记 `_garou`／`_garou_boss`、清 `victory_texts`；grant 开头 `credit_victory`）、`modes/xiyou/core/actor.gd`（param_rate 末尾乘 `XActorModules.param_rate`）、`modes/xiyou/core/xstate.gd`（`garou` 字段与存档键 `codexGarou`）。
- 共用挂点：`actor_modules.gd` 加 `param_rate`、`equip_changed`；`equipment.gd` change 末尾调 `equip_changed`；`advance.gd` missing／advance 开头对饿狼分派。八戒甚尔期一如果也加 `actor_modules.gd` 挂点，合并时两边各加的函数都留。

## 验证

- 专项＋相关选测（本机，并行 2）：xiyou_garou_progress、xiyou_actor_advanced、xiyou_actor_modules、xiyou_actor_p0、xiyou_advance_reads、xiyou_battle_gaps、xiyou_character_help_cost、xiyou_custom_params、xiyou_equipment、xiyou_equipment_admission、xiyou_equipment_clone_state、xiyou_formula_equipment、xiyou_help_card、xiyou_otb、xiyou_param_cache、xiyou_param_states、xiyou_raven_soul、xiyou_transform_params，18 个全部通过（308 秒），无偶发。
- 没改切片、转换器、全量同步里的探针，没跑同步与 xiyou_rules；没改界面，没跑事件对照。合 main（1816eaa2）只带进文档与工具，没重跑。

## 交接板

- 下一步：饿狼第三期——战斗内进化／解析层数、流水反击、神杀追击、伤害钩子 garou（physicalDefenseRate／magicalDefenseRate、skillMultiplier）、基础拳命中回 20 TP、itemCnt、认真一拳要琦玉模式、技能分类 [2,1,5,4] 与指令窗；画面车道接 `XBattleLogic.victory_texts`（神之触媒提示）与进阶界面的饿狼原因提示。
- 用户试玩说明：饿狼进阶后能力随形态变强（星空物攻 ×5），四臂起每回合行动两次；打赢一场得 1 点累计突破（Boss 战 5 点），够门槛才能在奉神老妪进阶；四臂 50 级 333 突破后打赢 Boss 得神之触媒，进星空要消耗它；破限之心随进阶换成新形态，等级、经验和强化保留。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：61.0% → 约 61.6%。依据：dev.239 核定表里饿狼 405 行的完成度 0.3 → 0.55（形态、进阶、突破、法宝进化做完，战斗内被动与画面没做），(2575.3＋101.3)÷8817×50＋46.4。按期数估，不是测量值。

## 可优化（流程／工具／效率）

- 建议：`等待任务.sh` 用 bash 调会报「A: unbound variable」（脚本是 zsh 的 `${0:A:h}`），说明里写明用 zsh 或改成可移植写法（收益小，归哪吒）。
- 建议：几个角色专属专项都在测试里手抄同一段「新局＋等级上限 99＋进阶次数＋改等级」夹具（raven_soul、garou_progress），可提成公共测试夹具（收益小，等下一个角色期顺手做）。

## 本分支提交

- 11f726ba 参照 garou_progress_probe 与夹具
- 23077729 XGarou 第二期与专项 xiyou_garou_progress
- 2069303f 合并 main
