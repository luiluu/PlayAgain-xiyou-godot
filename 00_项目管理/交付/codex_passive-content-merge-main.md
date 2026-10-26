# 交付：codex/passive-content-merge-main

- 车道／工作者：集成／沙僧（Codex，重制_沙僧_77，接76）
- 状态：用户2026-10-26“继续吧”授权按建议补地图／菜单显式操作域，已恢复；仍未完成同步／引擎验证，不可按可合并收取
- 交付范围截至5761f01f；新分支从该点建立。PREE已独立保存至c5953948，未带入本分支。
- 本次合并本地main：9b140f365f93c2cfa4b19d85b6ddd72576830c16；不以远端覆盖本地。两父合并保留提交链。
- 用户明确要求先评判并执行Claude交代，原文留[只读交代证据](../核查范围/连续分支合main_Claude交代_20261026.txt)。方向合理，集成优先，PREE暂停；不自行销核或登记完成度。

## 冲突处理初稿（逐项待专项验证）

1. battle_logic.gd：保留资源域版_start_battle_effects（同样整队初始化TP后再Battle分发）；保留main的种族／异化开战及1320预约。减耗先dsPassive再外层XRaceBattle.cost（冻结安装先后）。Boss回合霸体同步＋main传入随机／变量上下文并存。HP接口保留main第五项item参数，异化outgoing外包Boss settled资源域，再导入平衡／护盾／实际损血记录；冻结main.js Boss在122、异化在128～131行，后装者在外。
2. actor.gd：权能书准入与XActorModules.can_learn同时保留；ConsumeReduce缓存扫描后再XActorModules.passive_cache。主线已有XTraining／XParamPlus及种族→小猫→角色模块挂点不回退；后续核查自动合并部分及专项。
3. battler.gd：死亡钩子只保留一处XEnemyBook.note_death，另保留XRaceBattle.on_death；状态时长继续用生命周期duration_key，并在其后同步异化腐蚀。
4. enemy.gd：缓存外先Boss属性倍率取整，再后安装的异化最大生命倍率；不预乘基础值。
5. enemy_book.gd：采用原分支更早bind_battle的真实实例弱引用边界，保留死亡→复活→再死亡逐次计数和既有结算补漏防重记；不叠加main第二个同名note_death。资源死亡统一经battler加阵亡，所以无第二份手工死亡计数。需要图鉴专项确认main的即时计数语义仍保留。
6. resource_context.gd：保留原分支add_state_with_context统一资源死亡路径，不复制main旧版手工清状态／计数路径；种族死亡清反攻由同一battler入口调用，不重复。
7. state_effects.gd：支持op集合取并集；永久加算、资源写入、预览边界与main叠毒／加状态／gain_steps／计数器等helper并存。poison_stack也服从execute守卫，emit并入合成inputs。新helper与既有资源域的交互仍须审视和专项，未凭文本无冲突声称语义已验证。
8. xiyou_export.py：保留永久属性整块翻译＋main叠毒／gain／计数器整块翻译，各函数保留各自return None，Python语法已过。
9. xstate.gd：本地main前进后新增的第九处冲突。读档先XPets.loaded(s)，随后保留main参数缓存标脏／刷新，两个职责都保留；待读档与宠物／角色模块专项。

## 一并交付的14张原交付单

- [codex_actor-bonus-states.md](codex_actor-bonus-states.md)
- [codex_actor-bonus.md](codex_actor-bonus.md)
- [codex_four-loose-fixes.md](codex_four-loose-fixes.md)
- [codex_passive-content-book-capacity.md](codex_passive-content-book-capacity.md)
- [codex_passive-content-boss-context.md](codex_passive-content-boss-context.md)
- [codex_passive-content-boss-output.md](codex_passive-content-boss-output.md)
- [codex_passive-content-boss-react.md](codex_passive-content-boss-react.md)
- [codex_passive-content-boss-sequence.md](codex_passive-content-boss-sequence.md)
- [codex_passive-content-boss-state-origin.md](codex_passive-content-boss-state-origin.md)
- [codex_passive-content-boss.md](codex_passive-content-boss.md)
- [codex_passive-content-power-books.md](codex_passive-content-power-books.md)
- [codex_passive-content.md](codex_passive-content.md)
- [codex_rng-compare-review.md](codex_rng-compare-review.md)
- [codex_state-effects-2g.md](codex_state-effects-2g.md)

- 树中另有codex_stage-review-50.md与codex_stage-review-50-phase2.md两张既有阶段审查单，未删除、未改结论；它们随既有祖先链存在，不把阶段审查算作上述14张中的新实现。总装收取时核对是否已登记并决定归档方式。

## 变更记录草稿

## 2026-10-26 【Codex·沙僧·未经Claude检验】连续交付与main集成（dev.待定）

- 截至5761f01f的14张交付单与本地main 9b140f36集成，实际九文件冲突采用两侧语义并存的初稿；验证尚待执行，不称完成。
- PREE不在本期；原版证据、全部.sandbox、失败／未完成样本、generated和整树保留。不改主工作区或共用登记。

## 验证与下一步

- 已做：九文件无冲突标记，git diff --check，xiyou_export.py编译检查。
- 未做：同步、测量差异接受审阅、Godot导入、检查.sh --affected main --oracle、14期与main冲突影响专项。禁止把初步合并当验证通过，禁止在验前标可合并。
- 先检查全局是否有同步进程；没有才用长任务.py start执行同步正式西游.py（python3 -u、XIYOU_TEST_HEARTBEAT=30），等待任务.sh每次--timeout45。不要--full，不绕共用四槽；源与切片变化按同步报告逐项检查，有既有测量变化必须接受单，不无条件接受。
- 固定main基准9b140f36后跑选测；已覆盖的原交付专项只列覆盖，不重复无意义运行，缺的补一次。仍含旧8项early_inventory_rule确定性失败时要区分继承／新增，不迁就测试或声称整轮全绿。
- 检查通过后由本分支推送github并向Kyo交付，交叉核查保留；总装才合入main和登记。然后回PREE，合入本集成分支再继续。

## 交接板

- 下一步：先完成本集成验证与交付，再恢复PREE；本单目前非可合并。
- 用户试玩说明：待集成验证通过后按原14张交付单汇总；本期不新增玩法。
- 需要总装决定：前述接口范围已由用户“继续吧”授权按建议补齐，不再等待该决定。原停手证据见[接口边界决定](../核查范围/连续分支合main_接口边界决定_20261026.md)；当前仍需新原版入口、同步与引擎验收，不可合并。

## 可优化

- 已做：以选测实际覆盖表去重原14期专项，保持覆盖不减少；回退方式为逐场重复运行。尚未运行所以不宣称节省实测时长。
- 共用槽等待改进仍留工具车道；本分支不修改并发上限或抢占他人任务。

## 沙僧75→76（同树上下文接力，非额度停手）

- 用户既定自动同工作树上下文接力；75创建76后停止，76唯一后续执行者。最新用户要求读取Claude交代、评判合理后执行，故当前任务已改为本集成期，PREE暂停，不要按早期“不合main”的旧任务范围撤回已授权合并。
- 当前分支codex/passive-content-merge-main，工作树仍/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；本节提交为HEAD。WIP合并d13da37e的父提交为5761f01f与本地main 9b140f365f93c2cfa4b19d85b6ddd72576830c16，已经git push github本分支成功。没有新PR，不要创建PR；没有改main工作区。
- 末次实查五小时25%、周35%，非额度停手。**本插队期**依Claude交代采用80%或上下文紧张时WIP推送收尾；原PREE的95%线先不套到本期。设计／疑难high，机械步骤只有真实接口才称切medium。所有提交仍待Claude，不自核／不自评完成度。
- 第一条及全部文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用已有树，不建／清worktree，不reset／cherry-pick，不改共用登记，不向其他已有会话发消息，不建automation。此次用户已授权在本分支merge本地main与push github，勿再询问该许可。
- 开工只读共用交接板顶部／自己车道行、git status/log、额度、本单完整内容（当前较短）、归档Claude交代txt；原14张交付单后续按专项清单读“最终／交付／验证”节，不重读全部接力历史。原文档路径为核查范围/连续分支合main_Claude交代_20261026.txt，不依赖/private/tmp。
- **九冲突已初步去标记并WIP提交，不代表完成**。各处具体合并方法见本单上方。除八个原交代文件，新增xstate.gd读档冲突已保留XPets.loaded＋main缓存刷新。重点审视自动合并与新op资源域：state_effects中新叠毒／gain_steps／add_state目前仍沿main helper实现，和旧生命周期资源域、Boss输出／结果槽的交互尚未验证；如必须大改别人接口，写具体参照与需要总装决定，按原交代停，不静默重构。
- **现有验证**：无冲突标记、git diff --check、xiyou_export.py py_compile过；尚未同步／导入／Godot专项，原分支generated仍旧，不能拿来验合并后工程。检查.sh原文文档块已实跑，exit1，仅两处失效链接：变更记录.md 3855／3856行的文字“破阵——变身萧萧（后缀a）”被识别为Markdown链接a。已逐字验证整份变更记录等于main 9b140f36，属于main继承文档问题，不是集成新增；共用变更记录只总装改，本期先如实报告，不迁就测试或静默修改。
- 两张阶段审查旧交付单不在14张实现名单中；main 9b140f36已经是“合并codex/stage-review-50-phase2”，总装收取时应避免重复登记，保留历史原文不自销核。
- **下一步顺序**：先审视九处合并上下文及自动合并部分，尤其actor的XTraining／XParamPlus／XActorModules、种族→小猫→角色模块；death hook只一次；新增状态op资源域。再检查pgrep同步正式西游.py，没有别的同步才长任务启动同步（普通增量，不加--full；遇测量变化先审report，按接受单逐条说明）。必须保留全部.sandbox／generated／失败和未完成原件／整树。工具默认备份只留近三份，此树证据不得人为清理。
- 同步用长任务.py start，python3 -u＋XIYOU_TEST_HEARTBEAT=30，共用四槽、等待任务.sh每次--timeout45（最多60秒）；不改工具／上限，不杀其他人。源冻结只读、不读真实玩家存档。注意同步正式西游.py --help也会经长任务包装；75的help任务5946c797a2b1458ca63b5aa819ed6e3e已done0，不是实际同步。
- 同步接受与导入后按用户交代跑检查.sh --affected main --oracle（固定目标main在本单记录，若main继续前进不得无限追逐合并；记录选测实际基准）。从14张原交付单收集专项，与选测实际已覆盖取并集去重；另含rules/cat、race/alien/magic_weapon、enemy_book、state_effects、actor_modules/help_card。没有全量授权要求，不重复全量；最终总装负责全量。旧8项early_inventory_rule确定性失败不夹带修复，不称整轮全绿。
- 当前**没有本车道在途任务**。PREE两项matrix2／entry2在用户改派后，已用childIdentity＋PPID验证后仅SIGTERM自有包装器，均failed143（有意暂停，不是采样规则失败）。原日志及暂停审计在本地结果保留，回PREE后另名采样，不重启旧日志。不要杀任何其他进程或启动旧日志。
- PREE封存分支codex/passive-content-preemptive停c5953948，新公式encounter.gd／xiyou_preemptive专项草稿及三原版探针不在本集成期，也没有有效fixture／实际游戏入口接线。完成本集成交付后再回PREE并merge本集成分支。PREE之前的discovery1例有效，matrix26中reserve与ability三例无效已留initial原件，entry首败渲染／初始化，matrix2／entry2被用户暂停没有运行出新样本；不要把旧matrix错误条件当最终参照。
- 容量期已可合并的验证记录与一次未定位偶发，仍见其交付单最终节，别重跑容量全过程。容量一次render2未回列表、根因未证实，保留Claude关注，第二次再现必须修；前期成功不能替代本次合并回归。

## 沙僧76开工与同步检查点

- 实查五小时30%、周35%；分支与HEAD吻合，tracked干净，未跟踪旧证据保留。九文件语义审视中，未把初稿标可合并。
- 准备启动普通增量同步（固定main 9b140f36，无接受开关）。同步自带手动副本和运行目录清理与本树证据保留例外冲突，故仅以本地启动适配器将本树.sandbox待删除文件／目录重命名归档，禁用manual淘汰；不修改同步工具、缓存键、并发槽或参照值。三份滚动同步备份仍按现有工具处理。启动器保留在本地结果/merge-main76/sync_preserve.py。
- 新状态helper与Boss来源域／嵌套生命周期的局部适配尚待验证，本轮先同步，避免旧generated掩盖合并问题。

- 首次同步启动与全局查询错误地同批执行，查询已显示悟空同步在跑；本车道随即核对runId eb37f6c0a09e455b808f3131873c7b58、childIdentity与PPID后只SIGTERM自己的包装器，最终failed143，尚在来源／基线前置阶段，没有转换／探针结果。现场与日志保留；待对方同步结束再另名启动，不重启旧日志。
- 新增独立state_merge_context_probe.cjs（未接同步PROBES）：12组原版最小交互，实际460叠毒、gain脚本、addState内层Apply，按0／3超强者及护盾0／20取样，正在共用槽排队；未生成有效结果前不改运行时。另发现旧TP专项硬编码437个未翻译块与main三批翻译后清单不兼容，待同步后按实际明细核对，不用放宽断言迁就。

## 沙僧76本轮收口：接口边界决定前停手（2026-10-26）

- 本轮结论以[决定报告](../核查范围/连续分支合main_接口边界决定_20261026.md)及[静态对照JSON](../核查范围/连续分支合main_接口边界对照_20261026.json)为准：原分支1334／1336为js，main与合并初稿均gain_steps，而事件313未接显式操作域；触发Claude原交代第55行，不自行扩改共享宿主。本期仍不可合并，不把WIP当完整交付。
- 两套Python翻译检查已实跑：8项1败、10项1败1错，均为两侧输出契约相斥，具体见报告；没有改测试迁就。冻结源静态盘点437／322／318，三块Battle TP仍采用2g的gain_resource，main其余gain_steps8块保留，永久4块保留。
- 本车道同步首试与新增原版交互探针均已仅停自有包装器并确认failed143，runId、原因和身份检查见报告；没有新在途任务，没有有效新增原版样本。sync_preserve.py、所有失败／暂停日志保留；未同步、未导入、未跑Godot选测。
- 选测只生成计划（SEL_FULL=0），固定基准9b140f36，已覆盖14期所列场景及main受冲突影响场景，未声称执行成功；决定后重生成计划并补新增交互场景。不给当前分支贴“可合并”。
- 建议先明确交接地图／菜单显式操作域小期；若选择继续保留两Apply为js，则须总装明确接受撤回main两块翻译。本轮两个方向均未擅自实施。PREE继续封存，不能先回PREE绕开本集成停手条件。
- 本轮代码改动只有尚未取得样本的独立原版探针，未接PROBES，未改生产运行时／exporter／共享登记。既有九文件初稿与全部证据保持。提交并推送本分支后报告Kyo，交叉核查仍待Claude。

- 收口文档检查首次发现3条失效链接：除main继承两条外，75接力节引用原文时也复制了同一Markdown链接语法。本轮已只改交付单引述为普通文字，主工作区变更记录不动；后续复查结果单列。MV守卫16/16、独立新探针node语法、git diff --check通过。

- 文档原块最终复查exit1，仅剩main变更记录继承的两条链接a（本交付单已无新增失效链接）；JSON有效、编号一致、守卫16/16和差异检查通过。停手原因为已定位接口边界需总装决定，非额度／排队／测试耗时。

## 用户授权继续（沙僧76，2026-10-26）

- 用户在接口决定报告后明确“继续吧”，本轮按上轮建议先补地图／菜单显式操作域，再恢复集成验收；前述停手现场保留为历史，不重复询问。实查五小时50%、周39%。
- 实际直接入口为MVEventCore事件313及菜单共享XBattleLogic._effect；地图／菜单页面无直接add_state／remove_state调用，战斗事件已另覆写313。计划复用现有XResourceContext、保留旧runtime_result、嵌套同域并publish／保存journal与快照，不改共享登记，不自行销核。先跑独立原版state_operation与state_merge_context两份探针；不注册同步PROBES、不覆盖旧原件。

- 测试契约先统一为精确并集：Python两套8＋10项已过；318盘点与两Apply为gain_steps、三Battle为gain_resource的清单断言已更新。没有放宽未知／畸形块边界；新Godot state_operation／state_merge_context骨架已写，原版仍排槽、fixture尚缺，引用待补接口，未导入／未运行，不能算通过。生产运行时尚未改。

- 已按既有状态／Boss原版参照写最小运行时草稿（尚未引擎验证）：XResourceContext统一加／去状态，313显式保存before／after／journal，菜单_effect新域种旧槽并publish，借用嵌套域时留给外层发布；新状态helper读取合成上下文，叠毒复用来源域但按原块弹字后清自身结果。原版新入口两探针仍排槽，草稿不代表新对照已通过，未导入／未同步。

## 沙僧76→77：用户继续授权后的同树自动接力（非额度停手）

- 用户最新“继续吧”是在76给出接口停手报告后发的，已明确按上一回复建议执行：先补地图／菜单显式操作域，再继续本集成。已恢复工作，不要再次要求用户／唐僧确认同一范围。旧接口决定报告已加后续授权说明，历史停手段落不要当成当前阻塞。
- 用户既定同工作树自动上下文接力；76创建77后停止，77唯一后续执行者。末次额度实查五小时59%、周40%，不是80%额度停手；仍按本插队期80%线及上下文吃紧WIP推送收尾。
- 第一条及全部文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用已有树，当前codex/passive-content-merge-main；本节提交为HEAD。main固定9b140f365f93c2cfa4b19d85b6ddd72576830c16，不无限追逐新main。原九文件文本合并d13da37e，PREE仍c5953948独立封存，本期验证交付后才回PREE。不得建／清树、reset／cherry-pick、改共享登记、建automation或向唐僧／其他已有会话发消息；不创建PR，直接push github本分支已获授权。所有.sandbox／失败／不完整样本／generated／整树保留。
- 新增两个**仍在运行／等共用槽的自有长任务**（不要重复启动、不要停掉）：本地结果/merge-main76/native-context2.log，runId a1fac1d487bb4684bf768284c0aff455，包装器87866、childPGID87867；执行state_merge_context_probe.cjs，预期.sandbox/state_merge_context.json共12例，实际460叠毒＋合成gain／addState内层Apply，0／3超强者与护盾0／20。另native-operation1.log，runId ceed918a02544b9b9b5dc002cbe67977，包装器87880、childPGID87881；执行state_operation_probe.cjs，预期.sandbox/state_operation.json共8例，真实事件313与菜单itemEffectAddNormalState／RemoveState，两Apply状态1334／1336、起始TP10／95，逐步保留旧结果／重复加／去／同结果禁重加／clear后加。两探针未入同步PROBES，尚无有效fixture。末段两项都等槽约9分钟；不得把等待当通过或采样错误。status文件有childIdentity，只有确需停止自有任务才核对身份与PPID后操作。
- 全局另一同步pgrep有悟空80414／80415，约31分钟，不是本车道，别杀别重启、别读私有临时日志。先等它结束，才启动本车道同步。不要把pgrep和启动放同一条未条件拦截的命令里；76曾误起sync1并及时停自己的包装器，failed143原件保留。首次暂停native-context也failed143，是旧任务；本轮context2／operation1仍在途，勿混淆。
- 代码草稿f4dff07e（**未导入、未Godot验证**）：XResourceContext增加add_state／remove_state公共入口，保留removedStates准入并经with_context跑Apply／Remove。MVEventCore._change_actor_state拥有一次资源域，种旧runtime_result、记录last_state_operation before／after／journal／error，嵌套借域只外层publish，预览提前返回。XBattleLogic._effect菜单共享入口种旧槽、发布／保存操作结果，借嵌套域时恢复previous；_state_add改经资源add_state。state_effects helper改用合成c，缺上下文的原main helper拥有小域；poison_tick复用Boss来源／清本成员结果，弹字后照原块clearResult。_add_state依资源准入，不再对被拒绝状态伪添addedStates。未顺手重构formula_execution／其他内容钩子。地图／菜单页面无直接add_state/remove_state，实际入口仅313＋菜单共享_effect，战斗事件有自己的313覆写。
- 测试契约5d909854已按精确并集更新：原三Battle607／609／857仍gain_resource，其余main gain_steps8块；两Apply1334／1336保留gain_steps并补宿主。两套Python翻译边界8＋10项已全过；未知／畸形块拒绝仍保留，不用任意op兜底。state_effects_tp盘点437→318（源静态实际值：原437、main322、合并318），两Apply为gain_steps；state_js只对3个明确ID期待gain_resource，其他仍gain_steps。exporter只改说明注释，未改变两边整块翻译逻辑。
- 新Godot骨架xiyou_state_operation／xiyou_state_merge_context两场在Git，引用fixtures/state_operation_oracle.json和state_merge_context_oracle.json，**fixture尚缺、资源API草稿未验，因此还不能当通过场景**。拿到原件先确认唯一ID、errors全空、sourceIdentity同冻结，再逐字节复制fixture（保留原件）并运行。operation比较两入口每步hp/mp/tp、状态／回合和旧结果槽；额外测借外域与预览不建槽。context比较12组原版before/after的资源、shield、dirty、状态与结果槽，显式／继承／无父域三模式，验证Boss域恢复。注意真实1334/1336 min/maxTurns1，Apply内全局add锁可能让TP夹值与普通gain不同，以原版实测为准，不预设上限；460原文popup后clearResult，故最终结果应空，不能把popup结果当最终槽。
- 接下来：等两原版任务（等待任务.sh --timeout45，每次≤60秒）→保留任何失败并按实测修探针／草稿；有效后补fixtures与先导入、只验两新场景及state_js／TP／Boss来源直接依赖。新源码可能有GDScript类型／语法问题，尚未导入，首次exit0也查Script／Parse／Compile错误；不使用无autoload的--check-only --script旧错误路径。导入占共用4槽；不要绕槽／改上限／杀别人。
- 本集成仍必须实际普通增量同步，generated是旧版不能作为合并验收。无其他同步后用本地结果/merge-main76/sync_preserve.py启动（本地适配器只把本树.sandbox待清理项重命名留档、禁manual淘汰；不改同步源码、缓存键或槽）。python3 -u＋XIYOU_TEST_HEARTBEAT=30经长任务.py start，另名sync2.log，不加--full，先无accept开关看差异；接受既有变化须逐条接受单，新增才--accept-additions，禁止无条件接受。自动导入后按固定9b140f36跑检查.sh --affected 9b140f36 --oracle；14原交付最终专项与实际选测覆盖取并集去重。旧selection.sh/selection.txt只是76原计划，新增两测试后要重生成。选测通常218左右场，范围大正常；仍不跑全量，最终总装跑。
- 原文档检查此前仅main变更记录两条链接a（本交付单抄录链接已改普通文字）；八个early_inventory_rule确定性继承失败有e1925bea独立基线，不夹带修复，不称全绿。75复制引述导致过第3条链接，76已修；源变更记录不动。新接力／源码后尚未重跑文档块，收尾再跑。原版守卫16/16、两新探针node语法、diff检查已过；JSON／编号目前一致，所有提交待Claude，不自核、不登记完成度。
- 当前新代码与原版未完成，都不标可合并。所有暂停失败、在途与全部证据都保留；本轮没有新同步／引擎成功结论。待真正完成集成才向Kyo“已交付”，再回PREE合本集成继续。不要重做容量／权能已交期，也不要用旧成功代替此次合并回归。

## 沙僧77接续检查点（2026-10-26）

- 开工核对HEAD f53f6a20与tracked干净；原版证据未跟踪目录保留。额度实查五小时62%、周40%。两项自有采样仍排共用四槽，未重复启动；悟空同步80414／80415仍在，未启动本车道同步。
- 已读当前交代及运行时／两新专项草稿；先将当前工程占槽导入，仅查解析与编译，不以旧generated作集成语义验收。原版样本有效后再补fixture并校准；14期专项与选测取并集去重。
- 更新选测计划：SEL_FULL=0，218场，32项新增／核心专项清单均被选中；仅是计划、尚未执行。77文档块复查exit1，仍仅main继承两条链接a。
- 静态发现待新采样确认：冻结index.html实际加载js/rpg_οbjects.js（希腊ο）；其command313每名目标操作后clearResult，菜单itemEffectAddNormalState／RemoveState则保留槽并makeSuccess。当前313草稿未清槽，需样本确认后校准；不修改仍在排队的探针。1334／1336时长均固定1，无随机时长豁免。
- 两原版任务已done exit0：context12例、operation8例均唯一ID／errors空，来源runtimeInputs与现manifest相等；两fixture已逐字节复制并保留.sandbox原件。实测确认313每步清槽且解除后的下一条可重加，菜单同结果槽解除后禁重加；据此仅给313补每目标clearResult。TP按实际max200比较，95＋25=120、95＋75=170，第二次新增可达200，不能假设上限100。
- draft-import1（f45957f312dc4a79810ecf4fd46050f8）exit0且无SCRIPT／Parse／Compile／ERROR，验证的是f4dff07e草稿解析；尚未按新增fixture跑场景、未同步，不充作合并语义验收。
