# 交付：claude/bajie-alien-affix2b-b2f008

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_82 做实现，八戒_83 收尾）
- 状态：可合并
- 本期：异化词条效果期二·第①批「状态类」：疫囊、囚厄、绝缘、舍身。八戒_82 在 `claude/bajie-alien-affix2`（b780ea4f）做完实现后，10-29 为留额度以 WIP 暂停；八戒_83 从 b780ea4f 切出本分支收尾（查慢、合 main、同步、选测、登记 O-106）。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条效果期二①：疫囊、囚厄、绝缘、舍身（dev.待定）

- **内容**：照冻结 v0.28 installAlienationAffixes／Advanced 移植四个状态类词条。疫囊：pestStates 必中、不可抵抗、不可驱散，重复附加回合取较长，回合末（原 endTurn 之前）把身上的 pestStates 与减益传给全体活敌人。囚厄：队友得到的 jailStates 与减益转给囚厄者（回合取较长），接收的只能自然到期。绝缘：拒收外来的登记增益、jailStates、恢复、护盾、增益，拒绝外来驱散增益与复活。舍身：登记增益、生命恢复、护盾、增益转给绑定队友（队友倒下就作废）。
- **接点**：`battler.gd` add_state／_add_state／remove_state／clear_states／add_shield；`actor.gd` add_state（疫囊受保护状态绕过角色侧拦截）；`resource_context.gd` add_state（不判抵抗）、gain（拒收与转移）；`battle_logic.gd` state_rate、效果 21 抵抗、效果 33／34、sequence_buff（新参数 `alien_routed := false`）、sequence_add_state、end_turn 开头调 `XAlienBattle.spread_pest`。`alienation.json` templates 补 statePairs（19 对）、jailStates（172 个）。
- **O-106（优化，可回退）**：原版插件加载顺序让囚厄、绝缘对角色身上的减益失效，重制默认照词条说明生效；`XAlienBattle.o106_actor_debuffs = false` 恢复原版。已登记优化登记，待用户决定。
- **查慢**：templates 各表首次查询时转成集合（原先 jailStates 172 项每次 addState 都用 lambda 线性扫）；开战锁队时记下本场出战角色有没有这四个词条，没有就让所有期二①钩子第一步返回（附加次数也不记），普通战斗只多一次标记查询。
- **参照**：`alien_affix_probe.cjs` 加 battle.pest／jail／insulation／sacrifice 四例（共 7 例全干净）；`alien_config_probe.cjs` 导出 statePairs／jailStates。同步接受单 `04_验证/测量接受/claude_bajie-alien-affix2b-b2f008.json`。
- **验证**：见下「验证」节。

## 验证

- 合 main 之后、同步之后跑选测（不跑全量）：`并行测试.py --reuse --log-dir <scratchpad>/sel2 … xiyou_alien_ xiyou_module_hooks xiyou_actor_p0 xiyou_formula xiyou_smart xiyou_rules xiyou_param_states xiyou_battle xiyou_boss xiyou_state_ xiyou_shield xiyou_regen_popup xiyou_combat xiyou_determinism xiyou_random_streams xiyou_troop_events xiyou_review_regressions`，**68 个场景全部通过**，退出码 0（`xiyou_rules` 全 24 段都在内）。其中 `xiyou_alien_affix` 433/433，`xiyou_alien_config` 95/95。改到的四个核心文件每场战斗都会经过，它们的直接调用方就是上面这些战斗、状态、资源专项。
- 偶发 2 个：`xiyou_rules_d2b`、`xiyou_rules_d3d` 并行时 600 秒超时（rc=142），单独重跑都通过（189 秒），两个都是累计第 1 次。当时机器负载 15～30（别的车道也在跑），另有 5 段用时超过 300 秒，应该是负载造成的，不是本期改动。
- 第一次选测加了 `--quiet`，一小时没有输出，被长任务的空闲看门狗杀掉了，没有结果；去掉 `--quiet` 重跑的才是上面这轮（见「可优化」）。
- 墙钟共 5068 秒（并行 2，共用上限 4）。

## 查慢（xiyou_alien_affix 3→50～65 秒）

- **结论：主要是机器负载，不是代码**。同一份代码在不同负载下：八戒_82 记 50～65 秒；本会话负载 20～30 时 10.8 秒（只有 150 项，当时工作树的 oracle 还没有期二用例）；负载约 13 时，把 `alien_battle.gd`／`alienation.gd` 临时换回改前版本、用同步后的完整 oracle 单跑，433/433 用时 6.2 秒（user CPU 3.6 秒）。
- **仍按交付单怀疑点做了缓存与早退**（`alienation.gd` `_in`；`alien_battle.gd` `lock_party` 记 `status`、新函数 `status_battle()` 取代期二①各钩子里的 `battling()`，`on_reset_state` 也先看它）。
- **前后计时**（`/usr/bin/time -p` 直接跑 Godot，临时 HOME，看 user CPU；墙钟受负载影响太大不能比）：

| 场景 | 改前 | 改后 |
| --- | --- | --- |
| `xiyou_alien_affix`（433 项） | 墙钟 6.16 秒，user 3.56 秒 | 墙钟 3.76 秒，user 2.89 秒 |
| `xiyou_rules`（难度 1 首段，115637 项） | 墙钟 240 秒，user 204 秒（负载约 9） | 墙钟 348 秒，user 228 秒（负载约 14） |

  `xiyou_rules` 差的约 10% 在负载噪声范围内（同机 timings.json 历史 254 秒墙钟），看不出普通战斗因期二①变慢，也看不出缓存带来的提速：这些钩子在普通战斗里本来就不是大头。要更准，得在空闲机器上各跑几次取中位数。
- 没有大改钩子结构，不需要总装决定。

## 同步

- `同步正式西游.py --accept-additions` 第一次报「有变化，请人工查看」：alien_affix.json `/cases 长度 3→7`、`/hostScope`；alien_config.json `/export/templates/jailStates`、`/export/templates/statePairs`。
- 核对（备份目录旧 oracle 对新 oracle）：alien_config 的 templates 只多 statePairs、jailStates 两个键，原有键、export 其余字段和顶层都不变；alien_affix 旧 3 例逐项不变，hostScope 只是说明文字加上「期二①（疫囊、囚厄、绝缘、舍身）」。
- 按同步报告 changeCandidates 写接受单 `03_再刷重制_Godot/04_验证/测量接受/claude_bajie-alien-affix2b-b2f008.json`（两条，写了理由），第二次 `--accept-additions --accept-changes <接受单>`：「新增用例、显式接受 2 条既有用例改变，已接受（不登记）」，退出码 0，留下产物指纹。

## 待交叉核查（核心文件，请沙僧重点核）

- `battler.gd`：`add_state`（route_state 拦截／转移、记附加次数、after_add_state 囚厄转移）、`_add_state`（on_reset_state）、`remove_state`（blocks_removal、after_removal）、`clear_states`（keeps_state）、`add_shield`（route_shield）。
- `actor.gd`：`add_state`（疫囊受保护状态绕过 XQiyu／强弱分类拦截）。
- `resource_context.gd`：`add_state`（疫囊、囚厄不判抵抗，本次移除过也照加）、`gain`（route_gain）。
- `battle_logic.gd`：`end_turn`（spread_pest 在小猫之前）、`_apply_effect` 效果 21 抵抗与 33／34（blocks_buff_removal）、`sequence_add_state`、`sequence_buff`（新参数 `alien_routed := false`，调用处只有 alien_battle.gd 传 true）、`state_rate`。
- `alien_battle.gd` 文末「期二①」一节与 `status_battle()` 早退；`alienation.gd` `_in` 集合缓存。
- 早退的边角：`status` 只在开战锁队时算；战斗中途换上场、锁队时不在队的角色身上的期二①词条不会生效。原版 forActor 在战斗中只认锁队冻结的那份，按理一致，请一并核。

## 没做（留给后面）

- 舍身、绝缘对回合末再生的处理：`_regenerate` 直接写 `hp`，原版经 gainHp 包装（Adv:108-109）。
- 绝缘对 setHp 的处理（Adv:107）。
- 绝缘对云裳 wake／addActions／freeGift 的处理（Adv:194）。
- 疫囊者在阵亡 clearStates 时保留状态的边角。
- 囚厄、绝缘对 clearBuffs 的保留：重制阵亡时直接清零。

## 原版依据（文件:行）

- 疫囊：installAlienationAffixes.js:64-79（protectedState、stateRate／isStateResist／isStateAddable、addProtected、removeState 三件套、removeStatesAuto、resetStateCounts、clearStates、debuffRate、addDebuff、removeBuff、spreadPest、endTurn）。
- 囚厄：installAlienationAdvanced.js:154-175（receiving、stateRate／isStateResist／isStateAddable、addState 里转移、removeState 三件套、clearStates、addDebuff、removeBuff、clearBuffs）。
- 绝缘：Adv:91-92（source／external）、97（gainHp）、111-112（gainMp）、114（addShield）、160（addState）、169-175（removeState、clearStates、addBuff、addDebuff、removeBuff、clearBuffs）、194（云裳）、195（revive）。
- 舍身：Adv:93（supportTarget）、98（gainHp）、114（addShield）、163（addState）、171（addBuff）。
- 附加次数：installAlienationRuntime.js:82-83（resetStateCounts 计数、A.tryState）。

## 发现的原有差异（不归异化，交总装另派）

- 角色身上已有状态时挨减益，原版帧外读物攻不刷新（krz 参数缓存没包 addDebuff），重制会刷新。用不带词条的对照例实测：原版 424，重制 318（物防同理 400 对 300）。探针里的这个对照例已删，期二用例不读帧外物攻／物防。建议派给管参数缓存的车道，查 `sequence_buff` 的 `_refresh_battler` 与 krz dirty 的对应关系。

## 交接板

- 下一步：异化词条期二第②批（生命池类，交接板已排）；上面「没做」五条可以并进以后某期。
- 用户试玩说明：带疫囊、囚厄、绝缘、舍身异化装备出战时，这四个词条现在会生效（以前只有标记，没有效果）。
- 需要用户决定：O-106（囚厄、绝缘对角色身上的减益也生效，默认开，可关回原版）。

## 进度账

- 异化词条效果：已移植 2 个（逆骨、归墟）→ 6 个（加疫囊、囚厄、绝缘、舍身），依据：四例参照逐步对照通过。

## 可优化（流程／工具／效率）

- 已做：探针合成技能要在原对象上改字段（`Object.assign($dataSkills[13], …)`）。整个替换会丢掉 YEP 技能熟练度挂的字段，行动结束时插件报错并 `SceneManager.terminate`，jsdom 的 `location` 随之失效，后面的用例全挂。这条写在探针注释里，以后的探针照做。
- 已做：templates 表的集合缓存与期二①早退（见「查慢」；回退就是 revert 查慢那个提交）。
- 建议：`并行测试.py` 的名字参数是前缀匹配，`xiyou_rules` 会匹配全部 24 段（本会话误跑了 12 分钟才发现）。规则里已提醒「名字写全」，可以让工具在一个名字匹配超过 N 个场景时打一行提示（收益：少误跑；归维护工具的车道）。
- 建议：判断「专项变慢」时，并行测试只记墙钟，负载高时（本机常在 10～30）会差好几倍。可以让 `test_timings.json` 同时记子进程的 user CPU（`resource.getrusage(RUSAGE_CHILDREN)` 差值），比较时看 CPU（收益：查慢不用另外手动计时；归维护工具的车道）。
- 建议：长任务跑 `并行测试.py --quiet` 会一直没有输出，超过空闲时限（约一小时）就被看门狗当成卡死杀掉，白跑一小时（本会话踩过）。可以让 `--quiet` 模式也每几分钟打一行心跳，或者在车道须知里写明「长任务里别加 --quiet」（收益：省一小时；归维护工具的车道）。
- O-106：见「变更记录草稿」与优化登记。

## 本分支提交

- b31dae00 WIP：期二前置，alienation.json 补 statePairs／jailStates，alien_config_probe 一并导出（八戒_82）
- b780ea4f WIP：期二① 四个词条实现、O-106、探针与专项扩充（八戒_82）
- ded4ce77 WIP：查慢，templates 集合缓存与期二①早退（八戒_83）
- ebff519f 合并 main（无冲突）
- a608531f 同步测量接受单（八戒_83）
- bde3891a WIP：O-106 登记优化登记，交付单改名补全（八戒_83）
- （本提交）交付单补验证，可合并
