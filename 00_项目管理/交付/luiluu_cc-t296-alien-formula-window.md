# 交付：luiluu/cc-t296-alien-formula-window

- 车道／工作者：T296 战斗提速②·公式帧只在真改读法时作废只读窗口／cc 车道（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T296·未经审查】战斗提速②：公式帧进出只在改得了能力值读法时作废只读窗口；XEquipment.change 换装当场换代（dev.待定）

- 依据：T293 交付单性能一节：每次 `XDamage.calculate` 进出都 `XAlienBattle.push_formula／pop_formula`，各 `read_touch` 一次，只读窗口（O-348）整窗作废，外面包的窗口（智能选招 O-392、rawValue 窗口）每段伤害都从冷重算技能表、能力值、被动。
- `XAlienBattle.push_formula／pop_formula`：公式帧只改得了栈顶那一帧的行动者、目标的 param 读法，而且只对带逆骨（物攻／物防）、空壳（生命上限）、饕餮（MP 上限）词条的角色才改。现在每帧记一个「改得了」标记（行动者或目标带这三种之一；影子克隆按 actor_id 认本体，本体冻结的词条、克隆身上装备的标记都看），进出时只要进出前后的栈顶帧都改不了，就不作废；任一改得了照旧当场作废。缄默不看公式帧，不算。
- `XHubris.push_formula／pop_formula`（狂妄穿透帧）同理：进出前后都不打折（没穿狂妄或不是物理公式）就不作废。
- 开关 `XAlienBattle.FRAME_TOUCH_LAZY`（默认开），两处共用；关＝每次进出都作废（同原来）。
- `XEquipment.release_dual_exclusive`（旧档两把专武只留一把）：卸第二把时原来也没换代，外层开着只读窗口时（旧档双专武走 change、装备页窗口里预览第二把专武）后面的被动、能力值读旧缓存；卸下当场补 `read_touch`（Neon 核查 P2-1）。
- `XEquipment.change`：先换装备、后 `release_unequippable` 读特性，中间原来没换代；在只读窗口里调会读到旧特性表（T293 核查带来，正式流程现在没有在窗口里调的）。赋值后补一句 `XActor.read_touch()`，窗口外调用时只多一次换代计数，结果不变。
- 结果不变：同种子整场（西游档无词条／逆骨／空壳／饕餮、天启篇 4v5）开关开／关逐位一致；`XIYOU_READ_VERIFY=1`（窗口命中都重算比对）无不一致。
- 玩家可见：无（只提速）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/alien_battle.gd` `XAlienBattle.FRAME_TOUCH_LAZY`（`push_formula`／`pop_formula`；`core/hubris.gd` 的 `push_formula`／`pop_formula` 共用） | 公式帧（evalDamageFormula 包装、伤害计算整次帧）每次进出都把只读窗口整窗作废，每段伤害从冷重算技能表、能力值、被动 | 只在进出前后的栈顶帧改得了能力值读法（行动者或目标带逆骨／空壳／饕餮，或狂妄穿透帧）时作废 | T296 战斗提速：同窗口 calculate 约 3.1 → 1.3 ms，eval_formula 约 1.0 ms → 52 µs，4v5 自动选招平均 53 → 21 ms、最慢 76 → 25 ms；结果逐位不变 | `XAlienBattle.FRAME_TOUCH_LAZY = false` | cc（T296） | 保留 |

## 量出来的（验收 4）

本机 M1 Pro 无头，`--audio-driver Dummy`，不带 `XIYOU_READ_VERIFY`（带了每次命中都重算，数没有意义）。夹具同 T293：天启篇炼狱 4 人（1、100、131、107，60 级、学全部重构技）打敌群 394（5 个），每人穿一印全套＋真印武器、每件带词条、学了号卷一二四号。专项 `xiyou_tianqi_dmg_hook_lazy` 第四段的 `PERF T296` 行，两次跑：

| 项 | 关（原样） | 开 |
| --- | --- | --- |
| `XDamage.calculate`（带 rawValue，外面包一个窗口） | 3122／3059 µs | 1271／1284 µs |
| `XDamage.eval_formula`（同窗口） | 1023／1025 µs | 52／52 µs |
| `XDamage.calculate`（每次新窗口） | 3117／3134 µs | 3119／3133 µs（不变：窗口本来就是冷的） |
| 4v5 一次 `XSmartAI.choose` 平均 | 53.2／54.0 ms | 21.4／21.1 ms |
| 4v5 一次 `XSmartAI.choose` 最慢 | 76.7／75.9 ms | 25.2／24.6 ms |

- 和 T293 交付单的数不同：T293 量的「关」是 T293 三个开关的开关，那时公式帧照旧每次作废；本单 T293 开关全开，只拨 `FRAME_TOUCH_LAZY`。T293 估的「3.5 → 1.3 ms、选招 70 → 53 ms」是在没穿满的路径上量的，本单量到选招降得更多（选招里大量的估算走 eval_formula，进出都不再作废）。
- 真出手（不在外层窗口里）的单段 calculate 不变；同一行动多段、同一窗口里连续估算的才受益。

## 验证（验收 1、2、3、5、6）

- 新专项 `xiyou_alien_formula_window` 初交 61/61、返修后 72/72（`XIYOU_READ_VERIFY=1`，本机约 30 秒）：
  1. 作废时机：无词条时 calculate、eval_formula、敌打我进出都不换代，窗口里先读的物攻记忆留着且等于即时重算；逆骨／空壳／饕餮各一档：行动者带、目标带都换代，旁人（8 号打敌人）不换代；嵌套（外层改得了、里层改不了）进、出里层都换代；开关关掉每次换代。
  2. 读数：逆骨目标在物理帧里物防读 0、弹出读回；逆骨行动者用逆骨技能时物攻读物防，里层换成别人打敌人时读回原物攻、弹出里层又读物防，每步都等于即时重算。
  3. 影子克隆按本体认（含克隆身上卸掉异化武器）；缄默不算；狂妄：穿着打物理换代（单进帧也换代）、没穿／魔法不换代、开关关掉换代，穿透帧里目标（角色，进窗口记忆）物防打折且等于即时重算。
  4. `XEquipment.change` 在窗口里调：先热特性表、技能表，换一把有特性的武器，换后特性表等于即时重算且与换前不同，READ_VERIFY 无不一致。
  5. 整场同种子 5 回合：西游档无词条、逆骨、空壳、饕餮，天启篇 4v5，开关开／关每回合日志、HP／MP／TP／状态／护盾、随机流逐位相同；全程 READ_VERIFY 无不一致。
- 反向验证（`反向验证.py`，逐项改坏单跑专项）：XEquipment.change 不补 read_touch、`_frame_reads` 恒否、pop 不看新栈顶、克隆不按 actor_id 认、狂妄 push 不作废、狂妄 pop 不作废，6 项都咬住了。
- `xiyou_tianqi_dmg_hook_lazy` 40/40（`XIYOU_READ_VERIFY=1`；补 T293 核查 P3-1）：
  - 词条全不带「技能伤害」（`XTianqiAffixBattle` 不问 is_attack 那一支）：钩子开关全开／全关逐项相同。
  - 封技支：默印真印全套＋挂失魄（状态 64，封技能类型 1、2），普攻的七印钩子带上「封技普攻增伤」（和没挂时不同），开关全开／全关相同。
  - `memo_gojo_10634`：五条悟普攻号显式断言是 10634。
  - 命运骰整场：命运编织者 94（穿 4521 命运骰子、每回合放命运之手 6861）＋1、100，天启篇 6 回合，开关全开／全关逐位一致；断言放过命运之手且命运骰子重掷那一支走到了（`xtq_fate_reroll`）。这一场里只放成 1 次命运之手（其余回合 94 没出手或战斗节奏使然，没细查），重掷支已覆盖。
- 本机 `XIYOU_READ_VERIFY=1`（窗口与各记忆每次命中都重算比对，不一致当场崩）战斗核心一批 41/41 过（约 17 分钟）：xiyou_determinism、xiyou_alien_formula_window、xiyou_tianqi_dmg_hook_lazy、xiyou_alien_affix、xiyou_alien_battle、xiyou_rift_alien、xiyou_tianqi_alien_affix、xiyou_heartsteel、xiyou_smart_ai（含 b、c、d）、xiyou_tianqi_smart_ai、xiyou_tianqi_smart_ai_eval、xiyou_act_stat_memo、xiyou_battle_state_batch、xiyou_battle_enter_exit_lag、xiyou_battle_speed、xiyou_equipment_clone_state、xiyou_gear_query_cache、xiyou_demon_crown、xiyou_dual_exclusive、xiyou_formula_effects、xiyou_custom_damage、xiyou_module_hooks、xiyou_target_eval、xiyou_tianqi_qiyin_effects、xiyou_tianqi_affix_battle、xiyou_tianqi_trumpet、xiyou_tianqi_fate_copy、xiyou_gojo、xiyou_toji_battle、xiyou_tusu_battle、xiyou_xuan_battle、xiyou_yunshang、xiyou_guyu_battle、xiyou_liuying、xiyou_cat、xiyou_replace_attack_motion、xiyou_combat、xiyou_tianqi_skills。**没有**带 READ_VERIFY 跑 `选测.py` 的全部 266 个（云端不能传这个环境变量，本机整轮约要一个多小时）；验收 2 的「整轮」按这一批＋云端常规整轮算，请核查方判断够不够。
- 云端选测 3ef5e35acd（`选测.py github/main` 选中的 266 个场景、16 片：xiyou_rules 全部段、xiyou_smart_ai 全部段、xiyou_tianqi_*、事件对照、敌群事件等）：通过，没有偶发。选测名单不含 xiyou_determinism，已在上面本机批次里跑过。
- `工具回归.py` 全部通过；`语法检查.py` 1102 个 .gd 0 问题；`回退开关覆盖.py` 没有本单的新缺口（专项里有字面量 `XAlienBattle.FRAME_TOUCH_LAZY = false`）。
- 合并请带 `--oracle`（改了公式帧、装备更换的作废时机）。

## 核查返修（小A Neon 甲档，P1×0）

- P2-1 已改：`release_dual_exclusive` 每卸一把专武当场 `read_touch`；新用例 `dex_*`：刘备（13）旧档 2005＋2006 在外层窗口里 `release_unequippable`，卸下第二把后特性表、物攻等于即时重算且与卸前不同，READ_VERIFY 无不一致。反向验证（去掉这句）咬住。
- P2-2 已补跑：本机 `XIYOU_READ_VERIFY=1` 23/23 过（并行 2、走共用槽，约 19 分钟）：xiyou_smart_ai_e～p（12 段）、xiyou_yunshang_wraps、xiyou_garou_battle、xiyou_mira_battle、xiyou_raven_battle、xiyou_jingliu、xiyou_race_battle、xiyou_panels、xiyou_tianqi_plague、xiyou_tianqi_death、xiyou_tianqi_rewards、xiyou_tianqi_qiyin_dragon_run（xiyou_smart_ai_profile 小A 已补跑过）。连同前一批 41 个，带 READ_VERIFY 的共 64 个。
- P3-1 已补：`chg_rel_*`：刘备主手双持专武 2005、副手普通武器，主手换成不带双持的普通武器后副手那把被卸进背包；窗口里做与窗口外做，装备、背包、特性表、物攻逐项相同，READ_VERIFY 无不一致。整场对照加「穿狂妄」一场：角色 1 穿 7902、每回合放非纯公式的物理技 10140（走 run_item，压狂妄穿透帧），开关开／关 5 回合逐位一致；反向验证（狂妄 push 不作废）咬住。
- 新专项现为 72/72（`XIYOU_READ_VERIFY=1`）。

## 改了哪些核心文件（请核查方重点看）

- `modes/xiyou/core/alien_battle.gd`：`push_formula`／`pop_formula` 的作废条件、新 `_frame_reads`／`_top_reads`、开关 `FRAME_TOUCH_LAZY`；帧多了一个 `reads` 字段（别处只读 item／subject／target／formula／physical，不受影响）。
- `modes/xiyou/core/hubris.gd`：`push_formula`／`pop_formula` 的作废条件。
- `modes/xiyou/core/equipment.gd`：`change` 赋值后、`release_dual_exclusive` 每卸一把后补 `read_touch`。
- `modes/xiyou/core/battler.gd`：只改 `ATTACK_ID_MEMO` 上方注释里的换代来源。
- 前提（请核）：公式帧只经 `XAlienBattle.param`（逆骨 param 2／3、`hollow_param` param 0、`glutton_param` param 1）和 `XHubris.formula_param`（param 3）影响读数；我在全工程搜了 `_formula_frames`、`_frame_target` 的读处，只有这几处。以后谁加了读公式帧的包装，要把条件补进 `_frame_reads`，否则窗口里会读到旧值（`XIYOU_READ_VERIFY=1` 能抓到）。

## T293 附带建议的处理

- 已做：`XEquipment.change` 窗口内调用（验收 6）。
- 没做 `_replace_attack_raw` 换键：普攻号在窗口里已有 T293 的记忆（ATTACK_ID_MEMO），本单之后窗口不再每段伤害作废，记忆命中率大增，整串哈希只在窗口外（敌人、UI）付；按记录（表名＋id）换键要动 battler.gd 的普攻号查表和所有调用方的对象来源，收益小、风险不小，不划算。
- 没做 `_race_factors`、`dispatch` 深拷贝：都在 `damage.gd`／`module_registry.gd`，派单写「damage.gd 只在必须时改」；本单不需要动它们就达到了验收。建议另开单，见「可优化」。

## 交接板

- 下一步：无（本单做完）。
- 用户试玩说明：无可见变化（战斗里自动选招更快）。
- 需要用户决定：无。

## 进度账

- 无（性能优化，不涉完成度）。

## 可优化（流程／工具／效率）

- 已做：公式帧只在改得了读法时作废只读窗口（回退 `XAlienBattle.FRAME_TOUCH_LAZY = false`）。
- 建议（战斗核心车道，Opus＋medium）：现在同窗口 calculate 约 1.3 ms，剩下的大头是 `XDamage._race_factors`（约 150～175 µs）和 `XModuleRegistry.dispatch` 每个钩子帧深拷贝三次（约 250～300 µs），可在 damage.gd／module_registry.gd 里各省一截（T293 量的数）。
- 建议（工具）：云端选测不能带 `XIYOU_READ_VERIFY=1`；碰只读窗口的车道只能本机跑一批。工作流加一个 `read_verify` 输入把环境变量传给分片，就能整轮在云端验。

## 本分支提交

- 25fbb220b WIP: T296 公式帧只在改得了读法时作废只读窗口（FRAME_TOUCH_LAZY）＋XEquipment.change 换装当场换代；专项 xiyou_alien_formula_window
- d4faae212 WIP: T296 dmg_hook_lazy 补 P3-1（词条跳过支、封技支、五条悟 10634、命运骰整场）＋FRAME_TOUCH_LAZY 性能行
- 3ef5e35ac WIP: T296 新专项 uid
- 9ecd4011c T296：交付单
- 81ac2b753 T296 返修（Neon P2-1、P3-1）：release_dual_exclusive 卸专武当场换代；专项补窗口内旧档双专武、换装连卸、穿狂妄整场
- （本提交）T296：交付单补返修与 READ_VERIFY 补跑
