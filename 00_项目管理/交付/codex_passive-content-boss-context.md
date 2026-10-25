# 交付：codex/passive-content-boss-context

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_67）
- 状态：来源域与资源接口已实现草稿，两例原版对照及边界专项281项通过；完整参照与依赖验收进行中，尚不可合并。
- 基线：ec75a3b1（Boss普通输出78组、六场8588项全过；可合并交付见codex_passive-content-boss-output.md）。同树新分支，无在途任务；所有boss66-*临时输出已清理，原版.sandbox、旧证据、generated及整树全部保留。
- 开工额度：五小时92%、周44%；上轮从66%接手，95%时以WIP保存并停，不因额度高而漏交已经验收的普通输出。

## 下一小期范围与先取参照

1. 先取action.apply／executeDamage／applyPostDamageEval上下文中HP与MP的负gain、set下降、正gain／set上升、自身代价、域外目标与无上下文对照，区分count0／3、霸体开关、死亡复活缺2651图标。
2. 参照要保留请求值、资源前后、伤害结果槽与护盾；before结果数组必须深复制，不能复用原版实时_result数组。先用正伤害＋死亡复活／自身吸取小样确认无界面宿主，再扩矩阵，避免整轮后才发现宿主缺项。
3. 本期不同时包行动序列与状态来源。它们逐入口另采参照：processActionSequence的_targets、actionHp／MpModify的makeActionTargets；battler customEffectEval的stateOrigin；action customEffectEval仅reactState且1341／2550的特殊来源与受害人。

## 预设计（待参照验证，不是已实现）

- 将来源与目标域显式绑定到行动所属XResourceContext，避免根据BattleManager残留subject推测。现有battle_logic.apply为每次行动新建resources并恢复上层资源对象；嵌套行动的上下文同样独立。
- eligible只在来源Boss输出倍率>1、目标不是来源，且处于当前单目标／targets域时成立；纯gain／set入口只对损失生效。普通executeHp／MpDamage的非自身正值无论倍率是否1都floor，保留已交原版边界。
- settled按目标＋资源种类保护普通伤害入口，direct保护gain→set嵌套链；缩放发生在已有减伤与护盾之前。HP结算不能遮住嵌套MP，域外目标不能借用父栈目标。
- 作用域栈须成对恢复。先确认GDScript当前宿主能保证的正常返回／诊断退出路径；禁止将未支持脚本当成功、不能把同一个Dictionary长期挂进全局。对预览／克隆的来源与域也须留隔离验证。
- 已有XResourceContext.gain执行护盾、写结果槽，再set与refresh；silent_gain无结果槽。当前没有专用set入口，直接属性赋值不自动触发原版set语义。不得仅对gain加倍率就宣称set下降已完成。
- formula_execution.gd目前把已翻译副作用转给resources.gain；本轮只读确认此入口，未获交接，不改该文件。若set能力需要扩此宿主，先给明确诊断／保留项，不能绕过边界。state_effects的资源能力已有同一resources接口，可在授权文件内接线。

## 依赖与未完成

- 普通输出数值实现00524617；最终验收ec75a3b1。普通输出每次已缩放值在后续gain／set不可再次放大。
- 上一期Boss属性／生命周期04e54453及更早全部已交范围不重做；前期权能五本、容量满返书＋预约1317、PREE-ASUP、WPNM／SkEType与race-battle等接口沿用旧单。未交接formula_execution／mv_event_core、两块TP Apply、敌人永久账本继续留空。
- 所有本车道提交待Claude核查，不销自己的核查、不自评完成度；共用交接板／变更记录／步骤清单／当前状态只读。

## 可优化

- 普通输出已独立交付后才进入复杂上下文；后续新增参照先跑宿主冒烟小样，再扩矩阵。保留每次失败的精简原因和原版原件，不把测试快照错误归为数值差异或偶发。

## 额度停手（2026-10-25）

- 最后实查五小时95%、周45%；按用户95%保存停手规则收尾，本次不是上下文接力，不创建后续会话或automation。预设计72d612bc已WIP保存，本节提交后以最新HEAD为准；工作区干净，无在途长任务／前台等待。
- 普通输出可合并分支仍为codex/passive-content-boss-output（ec75a3b1），完整78组参照、六场8588项验证与待Claude核查均已交，不因当前设计WIP而撤销已交范围。当前分支codex/passive-content-boss-context，唯一工作树仍state-effects-2b，保留全部.sandbox和generated。
- 恢复时先实查额度；按本单先补行动直接gain／set新参照，再推进。不要重做旧29组／8场、78组／六场或338组；此次未新增数值规则，未产生新的同步需求。


## 恢复（2026-10-25，同会话）

- 用户明确继续；实查五小时0%、周45%，HEAD dc81efb9、工作区干净、无在途任务。沿用当前树／分支，先做原版入口冒烟样本，再扩参照。
- 本小期先交明确资源域框架与action.apply已有公式gain链；新增set资源接口按原版直接入口单独验。Godot尚无customPostDamageEval专门宿主、formula set编译能力亦未交接，不把原版入口采样等同于完整迁移这些宿主。


## 可优化补充（本车道外，交总装安排）

- 本次上下文原版3例冒烟在共用4槽外排队数分钟，其他车道两组整轮测试持续占满；需关注短专项在长批测续接时的等待公平性。当前只记录现象，不调大上限、不绕过共用槽、不终止他人任务。若确认后续批测长期抢先占槽，可由工具车道评估FIFO／等待者优先，保持内存并发上限与可回退。


## 沙僧66→67（同树自动接力，恢复后上下文接力）

- 用户已明确继续；五小时额度已重置，恢复开工0%、周45%，交接前实查7%、周46%。这次不是额度停手；上下文按既定40%接力。66创建67后停止，67唯一后续执行者。以本节最新提交HEAD为准，分支codex/passive-content-boss-context。
- 第一条及所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；只用此树，不在main写、不创建／清理worktree、不reset／cherry-pick、不建automation、不向唐僧或其他已有会话发消息。共用交接板／变更记录／步骤清单／当前状态只读，只登记本车道交付单。保留所有.sandbox、旧证据、generated和整树。
- 本次恢复新增原版入口boss_output_context_probe.cjs（3476b2b4、785bd1fe及本节最后筛选修正），**尚无有效新参照、尚无运行时代码改动**。入口--smoke仅3例，默认121例；--only REGEX只采所选例并写_selected，避免覆盖完整数据。每例CASE_START，YEP脚本意外诊断会判失败，预期测试throw仅允许boss-context-probe。
- **在途长任务只有boss66c-smoke.log**：路径03_再刷重制_Godot/04_验证/本地结果/任务/boss66c-smoke.log，runId898b9d6fcc0f4d78b56553b6b2a30df1。最后仍在等共用4槽（已等300秒），占槽包装器6671，尚未运行node；不要重复启动，先等待其状态／日志。用等待任务.sh --timeout 45，每次不超过60秒。其他车道两组整轮rules持续占满槽，不绕槽、不终止别人任务；公平性待观察项已写可优化，不碰工具车道文件。
- 当前新增未验证专项骨架tests/xiyou_boss_output_context.gd／.tscn已随本节WIP保存；**尚不能跑或导入**：它引用待实现的resources.boss_output.with_action／is_empty与set_resource，夹具boss_output_context_oracle.json尚不存在。只搭好回放骨架，不算通过。没有新uid；不要误把未导入说成已导入。
- 原版小样通过后先看caught／rows实际行为，必要时仅--only补宿主；再跑默认121例并保留失败原件。native setup是真实敌人6×3（a为Boss霸体、b目标、c域外或嵌套来源）、actorTarget用演员1；HP500／MP300受真实上限夹值，不替换参数。使用真实apply／executeDamage／applyPostDamageEval，只把测试脚本资源步骤放window.__bossStep；有无上下文、0／3人数、霸体开关、gain／set、损失／治疗／零／小数、域外／自身、护盾、嵌套／YEP捕获异常、普通伤害settled均有输入。目标b同时是Boss身份但不开霸体；c不开霸体，嵌套来源不应借a倍率。BattleManager._subject故意设c，不能作为来源。
- 测试骨架：HookBattle仅把给定资源步骤插入_calculate_damage的公式位置，数值伤害固定0；用于逐步核资源API及真实battle.apply作用域。post／execute只回放等价作用域，**不能因此宣称Godot customPre/PostDamageEval宿主已迁移**。还须另加至少两个真实XFormulaExecution effectful公式接入测试（compile_formula已确认b.gainHp(-7.9);0和b.gainMp(-7.9);0可编译）；不改formula_execution.gd。
- 建议实现：独立XBossOutputContext（或resource_context内小类）保存行动frames与settled/direct（按目标＋hp/mp）；XResourceContext持有此对象，嵌套battle.apply的新resources共享同一域对象，正常／诊断退出恢复上层。scope不做静态全局。gain负值在护盾前eligible时放大一次，set下降同理；gain进入set时direct防重复。普通executeHp／MpDamage用已交_boss_output_value，再用settled保护内层gain与set；nested同目标同kind不重缩放，不同资源不互相遮盖。只对HP／MP生效，TP不动。
- XResourceContext当前gain内部直接b.set+refresh，silent_gain只有TP调用；新增set_resource要保留set不写伤害结果槽、不标gain尾部dirty、YEP输入不变不refresh、护盾setter语义。别给旧gain日志额外插一层set行，否则旧formula_effects逐行回放会变。原版快照结果数组需深复制。
- 重要限制：GDScript没有JS try/finally；当前翻译VM用诊断返回，先验证正常／诊断路径恢复，不虚称能捕获任意GDScript致命错误。测试throw在native由YEP eval捕获，Godot骨架用返回false模拟受控诊断，不设resources.error阻断外层后续操作。完整任意异常生命周期若未保证，要明确保留。
- 已交普通输出ec75a3b1、实现00524617，78组＋六场8588项全过待Claude，不重做。上期Boss生命周期04e54453、29组＋八场42602项亦不重做。只跑新增专项＋直接依赖，先占槽导入无错误；长任务.py start、python3 -u、XIYOU_TEST_HEARTBEAT=30，交付后精简证据再清自己临时输出。先交小期再接序列／stateOrigin／1341／2550尾巴，各入口另采参照。
- 前期未完成、依赖、文件禁区见本单前文和普通输出交付，不重读大范围审查。五本权能／容量满返书与1317／PREE-ASUP／WPNM-SkEType→race-battle接口→全部完成且额度足再核他人。自己的提交全待Claude，不自销核、不自评完成度。95%才WIP保存停，周98%收尾。

## 沙僧67接手（2026-10-25）

- HEAD 29847686、工作区干净；实查五小时10%、周47%，继续本期。boss66c-smoke 已失败退出，未重复启动；两例成功，apply 缺 CodexYunshang._acted 战斗列表。仅补测试宿主数据、不替换原版方法；失败原件另存 .sandbox/boss_output_context_smoke_66c_failed.json，先 --only 定向确认。

- 67检查点：已有两例有效原版参照后，实现独立 XBossOutputContext、资源 set 入口及 apply／普通输出 settled 接线草稿；尚未导入／验收，不可合并。定向 apply 原版任务仍在共用槽排队；下一步先确认宿主，再全121例与真实公式测试。

- 67验证进展：boss67-import（runId b4d7df3d65354831b803dacf9842e3f6）退出0、无 SCRIPT ERROR／ERROR／Parse／Compile Error，新增域和专项UID已生成。文档／JSON／链接／编号通过，MV访问守卫16/16。原版定向任务先排、导入后排而导入先取得槽，原版已等360秒；公平性记录追加，不改工具。

- 可优化（67已在本车道执行）：--import 只证明导入扫描无报错，首次运行仍发现来源变量倍率的类型推断失败（boss67-godot-smoke，失败原件保留）。修为显式 XEnemy 转型后，新增先占槽 --check-only --script 新专项的编译关，再跑场景；不凭导入输出宣称脚本均可执行。工具车道可评估推广，不改其文件。

- 67定向apply补宿主第二步：原版已执行到AB_EnemyBook尾钩子，因行动仅覆写item取测试技能而内部_item为空失败；改用真实setSkill(1)初始化_item，测试副本仍由item getter提供。失败原件另存 .sandbox/boss_output_context_selected_67a_failed.json。--check-only单脚本模式缺GameApp autoload，虽rc0但编译日志报错，判不通过；该命令不适合本工程，撤销作为通用编译关的建议，继续用真实场景＋无SCRIPT ERROR验收（boss67-godot-smoke2在途），不改GameApp等无关文件。

- 67小样结果：真实setSkill补齐后，boss67-apply2定向apply原版1/1通过（runId 6f8aeb0ce75f4595be8ded18f7d0d77f）；Godot boss67-godot-smoke2两例＋边界281/281、无偶发。下一步启动boss67-full原版123例（原121＋HP/MP真实公式各1），四项直接依赖boss67-deps在途；不重采以前Boss普通输出／生命周期参照，不跑旧全量。
