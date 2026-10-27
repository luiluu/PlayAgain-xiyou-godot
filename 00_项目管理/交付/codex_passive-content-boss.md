# 交付：codex/passive-content-boss

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_65）
- 状态：可合并
- 基线：eb6fff3f（普通被动静态首批）；同树新分支，不用cherry-pick。此前永久状态角色宿主7bfb4807、普通被动静态首批eb6fff3f各自仍可独立合并，交付范围与遗留不变。
- 开工：2026-10-25由64同树接手，工作区干净，实查五小时33%、周35%。只写本车道交付单，共用交接板／变更记录／步骤清单／当前状态只读。
- 本小期只交Boss八项属性快照与2651生命周期；**输出倍率尚未实现／尚未采新参照**，不把霸体说明里的输出当成已完成。

## 变更记录草稿

## 2026-10-25 【Codex·沙僧·未经Claude检验】Boss属性快照与偶数回合霸体（dev.待定）

- 战斗setup按当前出战超强者数快照，含隐藏敌人；名单（MOG_BossHP 569项）或备注识别Boss。每人八项最终属性增加20%，倍率在原生属性缓存外最后取整，初始化填HP／MP前先设倍率；重复读缓存不复合，战斗中换队不改快照。
- 第2／4／6等偶数回合解除并免疫控制、附2651，奇数回合及结束战斗关闭。原版出战超强者为0时同样有霸体，属性倍率为1。控制分类按restriction、BuffType及traits42／44，死亡1和2651排除；现有全部状态逐项比较。
- 普通驱散与自动移除不能去掉活着Boss的霸体；recoverAll补回2651。仍可受伤、属性削弱和死亡；死亡／复活、隐藏、HP0无死亡状态等照原版区分。变身保留人数、重判Boss，并按当前回合同步霸体，保留原版已读缓存及其逐次刷新顺序。
- 原版内部dropState对冻结源全部控制状态及2651都先尝试removeStateCompletely（非叠层不处理），随后直接eraseState：静默清ID／回合，不触发remove效果、刷新或标脏。新增专项抓到空移除和普通remove引入的缓存差异，已按此对齐；冻结源非叠层前提另有断言。
- 新专项5080项；与7场直接依赖共42602项最终全部首次通过，无偶发。全部本期实现待Claude核查，不自销核、不自评完成度。未改伤害公式／输出上下文、共用登记或开发编号。

## 验证

- 证据：[Boss属性霸体专项](../核查范围/Boss属性霸体专项_20261025.json)；夹具tests/fixtures/boss_lifecycle_oracle.json与原版.sandbox/boss_lifecycle.json逐对象相等，来源runtimeInputs与generated manifest一致。
- 冻结原版29组errors空：0／1／3／5人、普通敌人1／名单Boss6／备注Boss947；初始化HPMP、重复缓存、状态／队伍变化；0～3回合变身循环、六回合开关、三种移除入口、控制／recoverAll、死亡／隐藏／HP0／复活、普通承伤／攻击削弱／HP上限削弱。
- 最终8场：boss_lifecycle5080、troop_events6574、troop_events_b6450、troop_events_half2951、param_states582、state_effects19949、battle_events108、formula_effects908，总42602；最终各场单次通过、无偶发。半值严格场19组集合与19组额外伤害比较均保留。
- 占槽导入通过、无SCRIPT ERROR；检查.sh原文档／JSON／链接／编号检查通过，MV访问守卫16/16，git diff --check通过。未改切片／转换器，不重跑同步、前期338组或全量；按车道三级试行只跑相关专项与直接依赖。
- 前期失败如实保留：初轮原版15例缺精灵；补精灵后隐藏例缺OTB队列，第一次补队列名有误，再按真实_nextTurnActionBattlers修正，最终27／29例全无errors。三份初版原版JSON留.sandbox，不算有效参照。
- Godot迭代：初27组4845项中20项变身缓存失败；加不存在检查后剩2项，定位原版dropState的静默erase路径并修正。最终扩至29组5080项全过；失败／重跑的结果与耗时精简入证据，不称偶发。
- 验收时main已是HEAD祖先、没有新提交，未合无关main。最后实现73077a15；本期临时输出在精简证据入Git后清理，所有原版.sandbox、旧证据、generated和整树保留。

## 交接板／后续

- 本期可合并，交叉核查待Claude。总装按已有依赖顺序合：四零散b135ee33→2g026f6ee3→随机b495833a→actor-bonus7ef7584a→actor-bonus-states7bfb4807→静态首批eb6fff3f→本分支。50%审查二期0b00c374仍另合，不夹带。
- 下一小期从本期已验HEAD在同树新建codex/passive-content-boss-output，先取原版输出倍率参照，再分可验小期做；别为最难尾巴拖住已交属性／生命周期。
- 静态首批遗留仍未做：五本权能1654／1656／1674／1683／1718学习上限、禁止普通遗忘和专用入口；羁绊容量满（变量9）返本道具＋预约1317；PREE／ASUP开场几率；穿武器时WPNM／SkEType。原版权能污染初样与修正证据照旧保留，不复用污染样本。
- 然后race-battle等八戒接口；全部做完且额度足再核他人。未交接formula_execution／mv_event_core、2g两块TP Apply／完整预览空槽、敌人永久账本均保留。

## 可优化（流程／工具／效率）

- 已做：先交属性／生命周期，将输出行动与状态来源上下文拆下一小期；定向原版只扩新增边界，夹具不冗长展开，完整.sandbox原样保留，可回退格式而不改数据。
- 已做：内部清除不存在状态时不再调普通remove，既还原原版缓存语义也避免无用刷新。冻结源非叠层控制前提有断言，正式源统一更新时会显式暴露需重审的变化。

## 本分支提交

- c3057740／919e381a／36f20dcd：原版定向入口与无界面宿主补齐。
- 855323f6：出战人数快照、缓存外倍率、生命周期接线。
- 32b3e716：逐行原版夹具与专项、隐藏／死亡守卫。
- 75387a6b／a8b87421／73077a15：缓存边界修正、承伤削弱参照与静默清除。

## 沙僧65→66（同树自动接力）

- 本小期79f86dcc已可合并，本节提交后以最新HEAD为准。当前codex/passive-content-boss，工作区干净；本期所有长任务已终态、无在途长任务或前台等待。本次为上下文接力；65创建66后停止，66唯一后续执行者。最后实查五小时61%、周39%，95%保存停、周98%收尾，不假定重置。
- 第一条及所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；只用此已有树，不在main改、不创建／清理worktree、不reset／cherry-pick、不建automation、不向唐僧或其他已有会话发消息。开工只读交接板顶部／车道行、git status/log、get_usage_limits与本交付最后范围／本节。
- 65交Boss属性／生命周期：实现73077a15，29组冻结原版errors空，新专项5080，最终8场42602项全过、无偶发；main已是祖先，不需重复合无关main或重同步。精简证据已入Git，本期boss65-*临时输出已清，自动导入的其他车道battle_common_events.gd.uid已清；所有原版.sandbox、旧证据、generated及整树保留。不要重做29组／8场或前期338组／5场。
- 下一期同树新建codex/passive-content-boss-output。尚未取输出新参照，尚未实现boss_output_rate；先补冻结原版输出入口（installBossDifficultyRuntime.js后半context及scaled开始），分小期交普通executeHp／MpDamage，再接原始gain／set与序列、状态来源等难尾巴。设计／疑难上下文用high；66创建时显式传high，不虚称运行中已切；机械收尾用可用接口调medium，不可用就照实说。
- 当前实现入口在modes/xiyou/core/enemy.gd（所有Boss字段和属性倍率）、battle/battle_logic.gd（setup/start_turn/transform/end_battle）；并未改damage.gd／resource_context.gd／state_effects.gd的输出链。普通执行伤害入口execute_hp_damage／execute_mp_damage，XResourceContext.gain／silent_gain／refresh与XStateEffects资源能力可复用。不要动未交接formula_execution／mv_event_core或原两个TP Apply宿主。
- 输出边界：D.outputRate只看Boss身份＋boss_hyper_armor布尔，等于属性倍率；不要改成查2651图标（死亡复活后标志仍真而图标可能缺）。executeHp/MpDamage只放大正伤害、非自身，Math.floor(value*rate)，在已有角色平衡／护盾等旧链外；真实顺序先取参照，治疗／自身代价不放大。action.apply／executeDamage／applyPostDamageEval上下文里负gain与set下降才放大，目标必须匹配当前target／targets，settled/direct栈只结算一次；别用残留BattleManager subject猜来源。
- 后续难尾巴：BattleManager processActionSequence与actionHp/MpModify各自targets域；Game_Battler.customEffectEval用stateOrigin；Game_Action.customEffectEval只有reactState且1341／2550用特殊来源／受害人（1341取side.stateOrigin，2550 source=side,victim=action.subject）。要各自取原版参照；没有接的宿主明确诊断／遗留，别为难尾巴拖住可交小期。
- 本期最重要的缓存教训：倍率必须在param_cells外；sync(false)不存在状态不做任何移除。原版dropState调用removeStateCompletely对非叠层不生效，然后直接eraseState；冻结源全部控制与2651非叠层，静默清ID／turns、不refresh、不标dirty、不跑remove、不清origin。最终专项对此有非叠层前提断言。未来若动清除路径，需重跑新专项和变身依赖。
- 隐藏／HP0边界：Boss守卫用原版not hidden且含死亡1语义，不能用Godot更宽的is_dead；隐藏敌人add_state拒收，HP0无死亡1仍按原版可附加。recoverAll本期已会重补霸体。别回退这些已验行为。
- 前期未完成清单和依赖顺序见本单／codex_passive-content最后64→65；不自销核、不自评完成度。五本权能／容量满／PREE-ASUP／穿武器动态链→race-battle等接口→全部完成且额度足再核他人；50%二期审查另合。以后需合main用--no-commit再加执行者: Codex（沙僧）与核查: 待Claude尾注，不改历史。
- 长批python3 -u、XIYOU_TEST_HEARTBEAT=30，用长任务.py start脱离会话＋前台等待（单次不超过60秒以便进度沟通），先占槽导入无错误再专项。三级车道只相关专项与直接依赖，不跑旧全量／同步。新完整交付登记自己分支交付单。
