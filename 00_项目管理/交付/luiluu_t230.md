# 交付：luiluu/t230

- 车道／工作者：C 规则·机制／cc（T230 弱者专属词条批 2A：露茜、魔雷老人、波风水门、艾坤＋战斗角标；Opus＋medium）
- 状态：可合并

## 一句话

批 2 拆成两单（协调 11-19 同意）：本单做前四人的专属规则和战斗头顶角标、日志；张三丰、布兰德瓦登（`counter_rule`／`_guard` 按人屏蔽、受邀引导反击、护犊）归批 2B 另一单。四条 `w31`／`w23`／`w103`／`w3` **默认关**（Kyo 11-19：86 人做完统一开放，不接掉落、深渊商人、物品说明）。

## 独占文件（开工列）

- 新：`modes/xiyou/core/tianqi_weak_b2.gd`（XTianqiWeakB2，四条的规则）、`modes/xiyou/battle/tianqi_weak_badges.gd`（XTianqiWeakBadges，头顶角标）、`tests/xiyou_tianqi_weak_b2.gd／.tscn`
- 改：`modes/xiyou/tianqi_data/weak_affix_table.json`（加四条）、`modes/xiyou/core/tianqi_weak_affix.gd`（主目标、伤害百分比、root_skill 钩子、install）、`modes/xiyou/core/tianqi_skills.gd`（`end_action` 蓄雷、截球来两处；`formula` 读伤害百分比一处）、`modes/xiyou/battle/battle_logic.gd`（`_apply_effect` 效果 21 两处：催花结清、记施放者）、`modes/xiyou/battle/battle_scene.gd`（建角标节点三行）
- 共用表加一个状态：`modes/xiyou/tianqi_data/skill_rework.json` 的 `states`／`new_states` 加 `10830 刻印`（敏捷 −20%，2 回合，底号 26，同 10810 冰冷的写法）。不在派单独占名单里，只加两处键、没改别的；合并有冲突按「两边都留」解。

## 变更记录草稿

## 2026-11-19 【cc·T230·未经审查】天启篇弱者专属词条批 2 前四人：露茜催花、魔雷老人蓄雷、波风水门黄色闪光、艾坤一坤年之威；战斗头顶角标（dev.待定）
- 规则在 `modes/xiyou/core/tianqi_weak_b2.gd`（XTianqiWeakB2），表 `weak_affix_table.json` 的 `w31`／`w23`／`w103`／`w3`，**全部默认关**。地基（作用域、根、次数、派生）沿用批 0A。
- `w31` 露茜「催花」（设计稿 31）：施放治愈之歌 623 附加持续回复 55 时，队友身上还挂着**她上的** 55 → 剩余回合数 × 生命上限 × 每跳比例（读状态 55 的 HRG 特性，5%）立即结算，只过一次目标的受治疗修正（`rec`，坏死 −30% 实测按 ×0.7 算一次；再过四骑士疫病减半和 gain 里的禁疗、荒年者、烙印、裂伤等；R1 起不写这一根的结果槽、回春不转盾，日志报实际回复），移除旧状态，这一次不拿新的 55（仍照常掷一次随机，不挪随机流）；每目标每自然回合 1 次（同回合再放照原生刷新）；10% 即时治疗、妖精之羽照常。谁上的 55 记在本场数据（`note_state`）。
- `w23` 魔雷老人「蓄雷」（设计稿 23）：`XTianqiSkills.end_action` 里五雷那一行不再掷；本根原本有资格掷五雷就蓄 1 格，满格对本根主目标落一次五雷（原生追加、打满五段）后清零，落雷那一根不计格；满格数按当时追加几率 p（<50% 3 格，否则 2 格）；**落雷伤害＝原生五雷 × (p×满格数)%**（30% 档 90%、40% 档 120%、50% 档 100%、60% 档 120%）；每回合最多落 1 次（同原生追加的次数），满格留到下回合第一根落；主目标已倒：不落、格数保留。
- `w103` 波风水门「黄色闪光」（设计稿 103 整表替换版）：每自然回合第一次飞雷神 7089 这一根（含再释放、AgainUse）伤害 −30%（`XTianqiWeakAffix.cut`，`formula` 在单段上限之后乘 70%）；根收尾时这一根直接有效命中过的敌人在**下一回合**顺序里各后推 1 格（排得靠后的先推，相邻两个都中时不会互换回原位；每敌每回合 1 次；本回合顺序不动），挂刻印 10830（敏捷 −20%，2 回合；首领按普通减益向上取半 → 1 回合）；同回合第二次不扣不推。
- `w3` 艾坤「一坤年之威」（设计稿 3）：大灌篮后球来 4370 追加通过全部检查、即将结算时取消，传球库存补到 3（复用原生那一次抽样，占本回合追加次数）；队友主动根对至少一名敌人直接有效命中后（根收尾），艾坤对这一根的主目标打一次传球（球来整招 ×33%），库存 −1；每自然回合 1 次；主目标已倒不打不扣；没学篮球之神、没掷中都不入库。传球是专属派生：不连锁、打混子盾照扣但不记艾坤「打过混子」。
- 地基补三样（`tianqi_weak_affix.gd`）：`main_target`（这一根的主目标，`guide_targets` 记下第一个）、`cut`／`dmg_pct`（这一根伤害整数百分比）、处理对象的 `root_skill` 钩子；`start` 时 `XTianqiWeakB2.install()` 挂四条。
- 战斗头顶角标（`modes/xiyou/battle/tianqi_weak_badges.gd`，加在 BattleScene.fx 层，只读 `XTianqiWeakAffix.badges`）：只写状态（Kyo 11-19）：魔雷老人「蓄雷 2/3」、艾坤「传球 ×2」；战斗结束后不显示、没学天师真言术不显示（库存 0 不显示）；专属模块不在天启篇档时不建。
- 数值口径（附则 E，协调 11-19 定）：三处稿里的小数都改用整数百分比，表里可改：落雷 `p×满格数`%、飞雷神 `cut_pct` 70、传球 `pct` 33（三分之一取 33，比 1/3 少 1%）。
- 玩家可见：无（条目默认关）。

## 验收逐条（卡上 7 条，按拆单后的范围）

1. ✓ 四人按 v0.3.1 第三节（＋v0.3 第四节）逐条实装，默认关。张三丰、布兰德瓦登归批 2B（协调 11-19 同意拆单）。
2. ✓ 角标只写状态（`badge_state_only`、`badge_node_reads`）；格数（「蓄雷 n/满」「蓄雷已满，天罡五雷落下！」）、库存（「球来蓄势：传球 ×3」「艾坤传球！（剩 n）」）各有日志行；露茜、水门另有一行（「催花：… 的持续回复立即结算（剩余 N 回合，回复 X）」「黄色闪光：N 名敌人下回合行动后推 1 格」）。被护者、受邀者是批 2B 的。**没截图看实机**（只断言了角标节点读到的文字）。
3. －：归批 2B（张三丰、布兰德瓦登的 `counter_rule`／`_guard` 按人屏蔽）。
4. －：反击类归批 2B。本单四人没有反击、追击敌人这一步：传球、落雷都在根全部结算完以后出（传球在根收尾 `root_end`，落雷在 `end_action` 追加阶段，都在敌人这一招打完之后）。
5. ✓ 传球打混子：盾照扣、不记艾坤（`aikun_pass_hunzi_no_mark`，伪造瘟疫骑士混子夹具，同批 0A 专项的做法）。
6. ✓ 每人专项断言含开关关掉旧行为不变（`*_switch_off_native`）、别人戴不生效（`lucy_not_owner_native`）、西游档不生效（`xiyou_save_off`）；虚拟玩家 explore 14/14、短帧 climb 见「验证」。
7. ✓ 文字列在下面「文字」节，待小A 审。

## 文字（玩家可见；R1 起全部换成小A 甲核报告 R0 第四节定稿句）

- 头顶角标：`蓄雷 %d/%d`、`传球 ×%d`
- 战斗日志：`蓄雷 %d/%d`；`蓄雷已满，天罡五雷落下！`；`蓄雷已满，目标已倒下，暂不落雷`；`球来蓄势：传球 ×%d`；`艾坤传球！（剩 %d）`；`催花：%s 的持续回复立即结算（剩余 %d 回合，回复 %d）`（回复取实际回了多少）；`黄色闪光：%d 名敌人下回合行动后推 1 格`
- 状态 10830：名 `刻印`、说明 `敏捷 −20%`、类型 `减益`、右下小字 `被飞雷神刻印标记，身形变慢。`

## R1 返修（小A Neon 甲核 R0：P1×2 P2×4 P3×2，提交 a079501be）

- **P1-1 露茜结清**：`XTianqiWeakB2.heal_once`：起算量 `floor(mhp×每跳×剩余回合×rec)` 先过一次四骑士 `hp_damage` 的治疗分支（疫病减半、证道狂暴），再走 `gain`（禁疗、荒年者、烙印、宿傩裂伤等只在这里的修正）；用 `_operation_resources`（行动里就是这一根的结果槽），回血前后把结果槽的 `hpDamage`／`hpAffected` 存回去（不盖 10% 即时治疗的弹字），**不写 `r.hp`／`r.record_hp`**（回春的 `after_apply` 读 `r.hp`，不会把结清溢出转盾，也不算溢出治疗）；日志报实际回了多少（满血＝0）。比报告修法稳的一点：不自己重算 gain 里那一串修正，直接用 gain 的实际结果，以后 gain 里加新修正也跟得上。
- **P1-2 艾坤传球**：`XTianqiWeakB2.pass_cast` 拷一份球来（`skill_view` 后 `duplicate(true)`），各阶段序列过 `_seq_edit` 的 `clear_effect_args`，「action effect: enemies」只打传进去的主目标；共享 XDB 记录、关 w3 时的原生球来不动。实测三敌场主目标 6 段、另两敌 0 段。
- **P2-1**：魔雷角标按此刻几率实时算满格数（分子夹到满格），没学魔雷术那一行 `need_skill`（5083 天师真言术，读表不写死）不显示。
- **P2-2**：水门刻印 `_state_add` 后只在真挂上时写回合。
- **P2-3**：`skill_rework.json` 10830 的 `note_sub` 加两条：`<BuffType:减益>`、`<RightDownNote:"被飞雷神刻印标记，身形变慢。">`（「减益」已是现有类型，夜见镜流的负面名单认它）。
- **P2-4**：`XTianqiWeakAffix.badges()` 本场数据不在（`finish` 已清）就返回空、不重建。
- **P3-1**：`settle` 开头只认 `kind == ROOT`。**P3-2**：`turn_begin` 清残留帧时一并清 `cut`；补测大灌篮击倒目标不入库。
- 新增断言 12 条：`lucy_settle_no_rejuvenate_shield`、`lucy_settle_full_hp_logs_zero`、`lucy_settle_plague_halved_once`、`lucy_settle_gain_mods_logged`（裂伤 −30%，日志＝实际）、`lucy_settle_root_only`、`aikun_pass_main_only`、`aikun_slam_kill_no_stock`、`minato_mark_note`、`minato_resisted_no_turns`、`badge_molei_needs_5083`、`badge_molei_full_live`、`badge_hidden_after_end`。
- 没另做「终焉毒腺禁疗＝0」的夹具：禁疗、裂伤都在同一个 `gain` 里，裂伤那条已证明结清走 gain、日志报实际值。
- 验证（本机 `--headless --audio-driver Dummy`）：`xiyou_tianqi_weak_b2` 60/60、`xiyou_tianqi_weak_b1` 31/31、`xiyou_tianqi_skills` 245/245；影响面 `xiyou_tianqi_weak_affix` 101/101、`xiyou_tianqi_affix_battle` 86/86、`xiyou_tianqi_horsemen_battle` 142/142、`xiyou_tianqi_plague` 98/98、`xiyou_tianqi_skill_debt` 31/31、`xiyou_determinism` 372/372、`xiyou_battle_ui` 182/182、`xiyou_ui_skin_battle` 67/67、`xiyou_counter_guard` 27/27、`xiyou_tianqi_qiyin_effects` 63/63、`xiyou_text_batch23` 28/28，SCRIPT ERROR 0。⚠ `xiyou_json_cache` 102/106（tricky／corrupt／changed／off 四条，测试目录里出现了真实缓存文件），把 skill_rework.json 换回 R0 版本重跑同样 102/106，判本机缓存环境问题、与本单无关；没跑云端。

## 另查：七印击倒类在动作序列招上认不到击倒（T018 猜的，本单实测属实）

- 实测（专项里的 `_qiyin_seq_probe`，只打印不断言）：魔雷老人群体魔雷术 327、普攻 1（两者都是动作序列招）各打一个 1 血敌人，`execute` 完目标确实倒了，七印行动帧记了命中（hits 3／1），但 `killed` **没记**：`QIYIN_SEQ_KILL [{"skill":327,"seq":true,"dead_after_execute":true,"frame_hits":3,"killed_noted":false},{"skill":1,"seq":true,"dead_after_execute":true,"frame_hits":1,"killed_noted":false}]`。
- 原因（读码）：`XTianqiQiyinEffects.after_apply` 用 `t.is_dead()` 认击倒，序列招打的过程中目标是 immortal，序列收尾才倒下，那时 `after_apply` 早就过了。普攻也走序列，影响面比 T018 猜的大：送行连斩、溢出、击倒再动等「击倒」类七印效果在序列招上都不触发。**本单没修**，见「可优化」。

## 验证

- 专项 `xiyou_tianqi_weak_b2`（新）48/48：露茜 10（首放、结清移除、结清量、每人一行、同回合二放刷新、别人上的不结、坏死 ×0.7 只乘一次、满血浪费、开关关、别人戴）；魔雷老人 11（四档满格与百分比、落雷打主目标五段、第 3 根落、落雷根不计格、一回合只落一次＋满格留到下回合、防御不蓄、主目标倒不落格保留、百分比带到落雷、开关关原生照掷、戴着原生几率不掷）；波风水门 11（−30%、第一次标记、本回合顺序不动、下回合各推一格、刻印 2 回合、日志、第二次不扣不推、百分比只第一根、首领 1 回合、每敌每回合一次、开关关）；艾坤 12（没学不入库、截球来入库 3、自己出手不传、队友根传球、同回合不再传、主目标倒不传不扣、33%、补到 3、混子、开关关、换装清库存）；角标 5；西游档 1。
- 本机相关专项（`--headless --audio-driver Dummy`）：`xiyou_tianqi_weak_b1`、`xiyou_tianqi_weak_affix`、`xiyou_tianqi_skills`、`xiyou_tianqi_skill_debt`、`xiyou_determinism`、`xiyou_counter_guard`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_doom_follow`、`xiyou_tianqi_again_use`、`xiyou_tianqi_rewards`、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_balance`、`xiyou_json_cache`、`xiyou_text_batch23`、`xiyou_tianqi_phase4`、`xiyou_tianqi_ledger`、`xiyou_tianqi_ledger_p3`、`xiyou_otb`、`xiyou_tianqi_plague`、`xiyou_ui_skin_battle`、`xiyou_battle_ui` 21/21 全过。⚠ `xiyou_tianqi_skill_debt` 并行时偶发 1 次（`follow_full_matches` 里霸者连环斩随机三段的落点 [0,1,2] 对 [2,0,1]、球来 [6,5,4] 对 [6,5,5]，随机挑敌人的分布），单独重跑通过；累计偶发 1 次。本单改到 `end_action` 但条目全关时只多调一次没有随机的 `_follow_of`，不挪随机流，判断与本单无关。
- 虚拟玩家（本机，条目默认关，等于回归）：explore（种子 1）14/14、卡死 0、违规 0；短帧 climb（40000 帧，种子 1）9/9、卡死 0、违规 0、僵局 0、脚本报错 0（两局日志里 SCRIPT ERROR 0 条）。
- 云端选测（提交 a0d5ee1b84，基准 f172c3c65，457 个场景、16 片）：全部通过。之后的提交只动交付单、文件头注释和专项里只打印的七印探针（本机专项 48/48）。
- 工具快速回归：全部通过。

## 要 Kyo 定

- 无（数值口径协调已定整数百分比，不改设计）。

## 异议

- 协调回复里魔雷落雷写的是「原生五雷 × 160／220／180／220%」，我核了稿的推法：稿里 1.6／2.2／1.8／2.2 是**落雷的合计系数**（原生五雷合计 1.8），期望对平的公式是 1.8 × p × 满格数，换成「原生五雷的百分比」就是 **p × 满格数 = 90／120／100／120%**；照 160% 算会是稿的 1.8 倍。本单按 90／120／100／120 做（表里 `thunder` 可改），只是把稿的数原样用整数百分比表达。

## 交接板

- 下一步：批 2B（张三丰护犊、布兰德瓦登掷矛邀战：`counter_rule`／`_guard` 按人屏蔽原生触发、受邀引导＋反击、角标「受邀」、被护者），从合并本单后的 main 切，复用 `XTianqiWeakB2` 的日志排队、`XTianqiWeakBadges`；七印击倒类在序列招上不认击倒另派一单。
- 用户试玩说明：无（默认关）。
- 需要用户决定：无。

## 进度账

- 天启篇弱者专属词条：8 条样板 2/8 → 6/8（批 2A，默认关）。

## 可优化（流程／工具／效率）

- 建议：七印「击倒」类效果（送行连斩、溢出、击倒再动……）在动作序列招（含普攻）上认不到击倒（见上「另查」，实测属实）。修法建议在序列收尾（immortal 解除、倒下结算）之后补一次「这一根打倒了谁」给七印行动帧，或让 `after_apply` 把 immortal 且生命到 0 的目标算作击倒；归规则·机制车道，要跑七印、序列相关专项。
- 已做：本单专项里魔雷、艾坤的测试要每根出手前把敌人救满（等级 99 两根就清场、战斗结束 act 不跑），写在专项 `_act` 里，后批照抄。

## 本分支提交

- 4cad3ab11 WIP：四人规则＋头顶角标；专项 48/48
- a0d5ee1b84 WIP：新脚本 uid
- a20942989 交付单；文件头补第八节；专项加七印序列招击倒探针（只打印）
- a079501be R1 返修（P1×2 P2×4 P3×2＋定稿句）；专项 60/60
