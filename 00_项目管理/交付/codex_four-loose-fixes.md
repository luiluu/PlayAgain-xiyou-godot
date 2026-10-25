# 交付：codex/four-loose-fixes

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_60）
- 状态：进行中
- 开工：2026-10-25 07:43 Paris；五小时1%、周0%；当前规则任务已显式使用high，机械收尾时再评估。
- 基点：`926f914fe8483950b3a021ab5df2a00c9be69ccd`（开工main）；工作区干净。50%审查分支`codex/stage-review-50-phase2`完整保留，尚未合main；本分支从main独立开始，不重复夹带审查交付。
- 范围：图鉴真实死亡接线；ConsumeReduce消耗折扣与cat旧豁免清除；F31阶段记录分别计上限；核b3ab53e6敌人元素own_bonus。四项交付后再接2g。既定任务完成且额度充足时继续核查待核项；只核他人提交，自己的实现仍交Claude。
- 只用现有state-effects-2b树；共用登记只读；保留未入Git原版证据、mv_oracle/.sandbox与generated。等待重置自动安排已暂停。

## 变更记录草稿

## 2026-10-25 【Codex·沙僧·未经Claude检验】四个零散项（进行中）

- 当前先定位原版调用边界与既有参照，再补专项和最小实现；尚无完成结论。

## 验证

- 本分支选测，合并及每日全量由唐僧安排；不重复50%审查已通过的同步与12场。

## 交接板

- 下一步：本分支四项完成后2g→rng-compare-review→actor-bonus→passive-content→race-battle；check-tiers归哪吒。
- 需要用户决定：暂无。

## 进度账

- 本期不自评完成度；代码与测试交Claude核查。

## 可优化

- 同步工具未来可提供显式“保留既有证据”开关，避免特殊保留工作树只能用调用包装器；属于哪吒／木吒工具范围，本车道不改。
- 本轮实际观察到白龙与悟空两轮同步同时在途、各自长期等共用槽；建议工具车道把“同步前人工pgrep排队”收进跨工作树的统一排队入口，避免两个开工检查同时通过。现有每树sync.lock不能实现跨树串行。本车道用一次性只读排队脚本解决本次等待，不改他人工具；总装可派工具车道设计可回退方案。

- F31原记录全阶段共64行的问题在本期开工main已按1047／1048分别计上限；本期确认来源并补边界验证，不重复改实现。

## 原版参照检查点

- loose_fixes 34例最终runId以本车道oracle-battle.log.status.json为准，来源前后一致、cases错误全空；消耗27种边界＋敌人不打折、死亡3条自然入口、932元素及重复／大小写标签3条。早期夹具Node数组及未初始化OTB结果不作游戏缺陷结论。
- F31分阶段计数已由`308927f8`实现（2026-10-23），本期仅补100＋100次反应的饥饿边界验证。

## 在途（2026-10-25）

- 已从开工main补齐转换产物和Godot导入（退出0；排槽约420秒）。最终注册探针enemy_book_defeat扩为38例（原4＋扩展34），runId以oracle-final.log.status.json为准，退出0、全部errors空，34例已精简入tests/fixtures/loose_fixes_oracle.json。
- 新专项`xiyou_loose_fixes.tscn`修前runId `3e597bbc32464e5db8db7f55c89b9eb6`，日志`four-loose-fixes/red.log`，仍在共享槽队列；没有第二份同专项任务。当前尚未应用生产补丁。
- 补丁脚本已准备在本树忽略目录`03_再刷重制_Godot/04_验证/本地结果/four-loose-fixes/apply_production.py`：先读完修前结果，修夹具错误后才认语义红灯，再执行此脚本；补丁包括图鉴真实本场弱引用绑定（覆盖直接阵亡／资源死亡，隔离预览）、消耗缓存与两次取整、敌人备注正则扫描、去cat的tpGap。必须再检查脚本替换结果，不冒称已经改完。

## 沙僧57→58（上下文接力）

- 本树分支`codex/four-loose-fixes`，基点main `926f914f`；本期提交05dca2a5、081383aa、a73bc373、3cb09268、aa56b006。生产文件尚无改动，只有原版参照、测试和交付登记。50%审查分支`codex/stage-review-50-phase2`保持`0b00c374`，交唐僧另合，不重复夹带。
- 原版最终注册探针runId `c007f95c1c134f6ca50e269b0c88c432`已退出0：enemy_book_defeat原4例＋shared/loose_fixes扩展34，共38例errors空，前后来源一致。不重跑早期原型。早期Node数组缺contains、KRZ缓存未刷新、OTB未setup均为夹具问题，最终已修；不能把这些记游戏缺陷或原版通过。
- 唯一在途专项：修前`xiyou_loose_fixes.tscn`，runId `3e597bbc32464e5db8db7f55c89b9eb6`，PID39842／childPGID39843，日志`03_再刷重制_Godot/04_验证/本地结果/four-loose-fixes/red.log`。最后完成0/1、等槽1、在跑无。用等待任务.sh日志 --timeout 540续等，单次工具阻塞≤60秒，124只是还在跑，不重复启动，不动别车道进程或并发。
- 新专项先核SCRIPT ERROR／夹具，再认可语义红灯；读取fixure已改为FileAccess而非XDB.load_json（XDB只接generated相对路径）。全部34例逐例errors空。若类型推导／夹具仍错，先修测试，只重跑该场。新test的uid若Godot生成要入Git。
- 生产补丁待执行脚本在本树忽略目录`03_再刷重制_Godot/04_验证/本地结果/four-loose-fixes/apply_production.py`；本目录必须保留到执行完毕。先读它再执行并核差异，尚未应用。它覆盖死亡直接入口与resource_context资源入口，XEnemyBook用弱引用绑定真实本场成员，setup先绑定、页面登记幂等，预览克隆不得写图鉴；不在is_dead观察处计数。消耗按原版装备→技能→状态meta、parseInt、特定技能→类型→All求和、仅上限100、两次floor；敌人不折扣。敌人own_bonus正则按原版扫描重复／大小写／前导零。最后去cat_probe atkk1817的tpGap及xiyou_cat跳过。脚本在被忽略目录，不入Git，后续不得先清理。
- 实测自然HP死亡→查询→复活→再死亡为1→1→2；显式阵亡重施仍1；自然死态刷新／变身后原ID1、新ID0。旧enemy_book四例的直接die后变身新ID1是另一入口，旧接口专项保留，不能混用这两种夹具。F31已由308927f8（2026-10-23）按阶段各64实现，只补100＋100压力证据，不重复修。
- b3ab53e6普通932火增伤原版0.16；重复标签期望0.46，大小写／无前导零期望0.36（含原行动表技能0.16）。现有meta只取末条，有边界漏算；完成后交付核查结论，Codex新修仍待Claude。
- 修完先跑新专项、cat／enemy_book及直接资源／状态／战斗依赖，按影响面补规则d1四段；只选测，不能全量。本期改了原版探针（已并入原有PROBES入口，无需碰哪吒同步工具），最终只做本期需要的一轮同步和导入，不能把旧50%审查同步又跑一遍。cat旧参照数值本来正确，只是去掉tpGap元数据；同步变化要精确核对。
- 摘要见`../核查范围/四零散_专项结果_20261025.json`，目前只保存原版通过与专项在途，不宣称四项完成。新一期仍有足够额度（五小时18%、周3%）；95%WIP停，周98%收尾。动态强度规则已在50%审查分支的原规则处，当前实际high；机械收尾可用平台接力设medium，不能只口头称切换。
- 用户最新授权：既定任务四项→2g→rng-compare-review→actor-bonus→passive-content→race-battle都做完，额度够就继续核查待核项；只核他人提交，自己的提交交Claude。全程只在同一state-effects-2b树，所有文件命令显式workdir；共用登记只读，自己交付单登记。保留旧原版证据、.sandbox和generated，不reset/cherry-pick，不改哪吒／木吒工具。等待重置自动安排automation已暂停，不能再开一份自动执行。

## 沙僧58接手（2026-10-25 08:11 Paris）

- 按同工作区授权接手，HEAD `de509453`、工作区干净；已读主库交接板与车道表，不改共用登记。五小时21%、周3%。
- 修前专项仍为原runId，已接前台等待；四槽由其他车道同步占用，保持队列与并发配置，不启动重复测试。补丁脚本已读，尚未执行。

## 沙僧58→59（同树上下文接力，2026-10-25）

- 本轮只有交付登记提交`a6990eb8`；生产补丁仍未应用，四项仍进行中。主库main仍为开工基点`926f914f`，没有新文件冲突；不重读或重做50%审查。
- 修前专项仍是唯一runId `3e597bbc32464e5db8db7f55c89b9eb6`（PID39842／childPGID39843），到07:35 UTC仍完成0/1、等槽1。三次前台540秒等待均124，原任务仍running；58当前第四次等待会话可自然到时，不代表另一个测试。先读status，再以前台等待脚本续等，单次工具阻塞≤60秒，不改并发、不碰其他车道进程、不启动重复专项。
- 排槽原因已只读核实：Python30753的node39238（悟空同步event_probe，1槽）与Python31858的node39722（main同步event_probe，3槽）占满4槽，07:35 UTC分别已跑约44／41分钟，仍有CPU活动。不能凭耗时当卡死。只读结果不要求59重查其他车道。
- 已静态预检`apply_production.py`：7个文件的每处替换都唯一匹配，未写生产文件；另外cat_probe的atkk1817标记替换也现场核对可匹配。原版dsPassiveSkill确认先基础消耗floor，再技能→类型→All求和、仅封顶100、再floor；当前转换数据168条ConsumeReduce标签均有可解析整数（Armors54／Skills103／Weapons11，States0）。这些是静态检查，不是Godot实测通过。
- 真实死亡两入口与弱引用绑定方案沿57交代；建议修前结果固定后，在新专项再补“克隆走非preview死亡入口不得写图鉴”“战斗结束后的旧实例不再写图鉴”“同名单on_battle_start重复绑定保留已记死亡”边界。现有预览例只覆盖preview=true，尚未增加上述测试。
- **同步证据保留例外**：现有同步工具无条件prune_manual_copies和prune_backups，会删旧沙盒副本／同步备份，与本树保留证据要求冲突。忽略目录four-loose-fixes里新增`sync_preserve_evidence.py`，已AST语法检查，尚未运行；用importlib加载原同步模块，仅把这两处prune调用替为返回空列表，再调用原main；不改哪吒／木吒工具文件，不改守卫和指纹。不绕过来源比较、探针、并发槽、导入或接受单。最终必要一轮同步可通过长任务start运行此包装器，照常--accept-additions及精确cat元数据接受单。同步开始前先遵守其他同步在途检查。
- 2g原交付已只读看过`git show bf585fdc:00_项目管理/交付/codex_state-effects-2g.md`：12/13场，formula_effects906/908；两capState_buffs仍需按原别名链修，未做代码改动。不提前混入四零散；后续顺序不变。
- 最近额度五小时30%、周5%；不是停手线。58创建59后停止，59是唯一后续执行者；继续原授权既定任务，四项完成才写可合并，自己的实现待Claude。

## 沙僧59接手（2026-10-25）

- HEAD `8e23c854`、工作区干净，按同树授权接手；五小时34%、周5%。仅本车道登记，共用文件只读。
- 唯一修前专项仍在排槽，沿runId `3e597bbc32464e5db8db7f55c89b9eb6`等待；已读预备补丁，尚未应用，四项仍进行中。

## 四零散修前实测（沙僧59，2026-10-25 08:59 Paris）

- 唯一修前runId已结束，exit1；121项88过、33个语义失败，无SCRIPT ERROR或夹具错误。消耗23个、死亡8个、元素标签2个；F31各阶段64／总128边界通过。修前证据固定后应用补丁。

## 首轮修后检查点（沙僧59）

- 生产修复`10da1d87`已应用并核过实际diff。新专项126/126、cat994/994、enemy_book52/52，runId `d83d3e639a6042dd9c3889e2650f5f63`，exit0。
- 新增克隆（非preview资源死亡／显式死亡）、同名单重登记和battle_end后旧实例两入口不写图鉴，共5边界全过。原版38例不重跑。
- b3ab53e6普通932火增伤正确；重复／大小写／无前导零边界确有漏算，本期已修。自己的实现仍待Claude，不自行销核。
- 交付前合main显示Already up to date，仍`926f914f`；12场直接依赖选测runId `c4f75cc514c24740b6e04ea2ea3949b1`在途。
- cat测量接受单仅删除chain.atkk1817的setup.tpGap；旧／新摘要已固定，未接受任何数值变化。最终必要同步等其他同步结束后再启动。

## 沙僧59额度收尾（2026-10-25，五小时96%、周15%）

- 严格按95%规则WIP保存后停止，不开新接力或自动执行。四零散仍进行中，**不可写可合并／完成**。
- 本轮实际生产提交`10da1d87`；修前121项88过／33语义失败，无脚本错误；修后新专项126/126、cat994/994、enemy_book52/52（runId `d83d3e639a6042dd9c3889e2650f5f63`）。5个新增死亡隔离边界全过。登记与精确cat接受单在`4251bb9d`。
- 12场直接依赖runId `c4f75cc514c24740b6e04ea2ea3949b1`已结束exit1，11/12通过；formula_effects908/908、formula_equipment1804/1804、formula_rest1352/1352、battle8/8、battle_options92/92、floor_run_c560/560、settlement11/11、state_effects19949/19949、rules_d1b105778/105778、d1c105608/105608、d1d105670/105670。rules基础段105855/105856，唯一`d1.dmg.enemy947.0.skill5557`，Godot467.775、旧原版参照0，首次与自动重跑一致，不是偶发。此问题开工交接板已明确归哪吒期六的目标资源污染；本期代码没有使数值变化。
- **上游现场已前进**：最后只读看到main `946df0b7`已合哪吒期六（slice_probe量完还原双方hp/mp/tp）；本树仍基于`926f914f`，未合这次新main。先前对926f的git merge main为Already up to date。需在本树power完成后合一次最新main（不修改哪吒工具），按新探针跑本期必要一轮同步／导入，然后重跑失败rules基础段。其他已通过测试不因无关main前进重复跑。
- **唯一仍在途的本期测试**：power runId `e17287b26ec844429fcd3449f7d9782e`，日志`03_再刷重制_Godot/04_验证/本地结果/four-loose-fixes/power.log`。启动后已接前台等待；停止时尚未取得结果。接手先查status再等，不重复启动。旧red已退出1、green-first已退出0、related已退出1，均无在途重复。
- **最终同步未启动**。最后只读看到main另一同步PID44378在跑，需等其退出，不能并行同步，也不要在本树power仍运行时改generated。本树同步仍用原有`sync_preserve_evidence.py`包装器，仅停用旧证据清理，遵守所有守卫／来源与槽位，不改工具源。cat接受单`04_验证/测量接受/四零散_cat去tpGap_20261025.json`只接受chain.atkk1817 setup.tpGap删除，oldDigest6dd559bc445b42f1/newDigest511862cf8879383d，数值不接受变化。合入哪吒修复后slice参照会有新变化，须复用总装已核精确接受单或逐条核实后单独接受，不能静默放过；不能重做50%审查那轮同步。
- 所有本期临时日志仍保留（尚未完成必要验证），旧原版证据、mv_oracle/.sandbox、generated及整树完全保留。不要清apply_production.py或sync包装器所在目录；生产脚本已执行，**不得再次执行**。完成后只精简／清本期four-loose-fixes输出，入Git证据见`核查范围/四零散_专项结果_20261025.json`。
- 下一步顺序不变：本四项真正交付→2g→rng-compare-review→actor-bonus→passive-content→race-battle。本轮仅只读复核2g刷新锁定位，没有修改2g或切换分支。自己的补修待Claude，未自行销核。

## 沙僧59恢复（用户继续，2026-10-25）

- 额度已重置：五小时1%、周15%；power原runId已退出0，137/137。
- 已无冲突合入main `545ebd37`，本树合并提交`30b7f97c`；只包含上游probe／工具／登记与seal1691测试修复，游戏规则文件未变。
- 本树旧slice与main已全量通过的新slice逐条比较，六难度均恰好一条854／947／5557数值修复，完全匹配哪吒已核六条接受单，其他字段无变化。最终同步将同时使用此单与本期cat元数据接受单。
- 其他车道同步在途，暂未启动本树最终同步；不重复任何已过专项或50%审查。

## 沙僧59→60（同树上下文接力，用户已继续）

- 当前仍为本期唯一执行者；59创建60后停止。HEAD在本节提交之后；分支codex/four-loose-fixes，沿state-effects-2b旧树，所有文件命令继续显式workdir。无生产未提交改动。
- 本轮恢复后已合main `545ebd37`（merge `30b7f97c`），无冲突；不必再次追无关main。power已137/137通过。上游六难度实际旧／新slice比较仅一条854/947/5557，全部与`claude_nezha-check-tiers-eac2f9-5.json`精确匹配；MV访问守卫16/16。
- 当前本树**没有在途测试或同步**。red、green-first、related、power均已终态；不再等／重启它们。唯一必补Godot是同步后rules基础段（旧参照0造成唯一失败），不是再跑之前所有11场。新专项与cat／enemy_book在同步后可按参照输出实际影响补测（新enemy_book含34扩展，cat只删metadata）；不要全量。
- 最后查到其他车道白龙和悟空同步在途，本树最终同步仍未启动；接手先pgrep核对，空闲才开。包装器已读且未运行`four-loose-fixes/sync_preserve_evidence.py`，只停prune_manual_copies/prune_backups，不改原工具；需长任务start＋前台等待，单次工具等待≤60秒。传--accept-additions，以及本期cat接受单和哪吒6条接受单两份--accept-changes。缓存照常沿用，不能--full；保留旧证据/.sandbox/generated。
- 同步必须查看报告：预期既有测量变化仅cat setup.tpGap删一条＋slice6条，新增enemy_book_defeat 34条；若还有变化先分析，绝不放宽接受。同步和导入退出0后重测rules基础段并核947已非0；精简结果入核查范围JSON，清理仅本期four-loose-fixes临时输出，再写可合并交唐僧（自己的修复仍待Claude）。不要再执行apply_production.py，生产已改`10da1d87`。
- 上轮额度96%已保存c05b5c26后停；本轮用户说继续，实际额度已重置到1%／周15%，并未使用赠送reset。不是额度停手，当前是上下文接力。继续四项交付→2g→rng-compare-review→actor-bonus→passive-content→race-battle；2g未改，旧branch bf585fdc现场仍保留；50%审查二期0b00c374交总装另合，完全不重做。不要创建自动任务或改共用登记。

## 沙僧60接手（2026-10-25）

- HEAD `419c5d29`、工作区干净；本树继续，五小时4%、周16%，未到停手线。
- 已核全部旧测试终态，不重启。其他车道白龙与悟空同步在途，本树最终同步继续排队；同步前先保存此检查点。
- 仅本期交付与核查证据可写，共用登记只读；保留旧原版证据、.sandbox、generated。生产补丁已应用，不再执行。

## 沙僧60同步排队检查点

- 文档／JSON／链接／编号检查exit0（dev.173）；原始检查日志在本期临时目录。
- 现有白龙与悟空同步未结束；一次性长任务`final-sync.log`先用pgrep每30秒只读核对，全部退出才调用既有证据保留包装器。排队脚本只在本期忽略目录，不改工具／守卫／槽位，不是automation。
- 启动后只等待此日志，不重复启动同步；两份接受单保持7条既有改变，预期新增enemy_book_defeat34例。同步含Godot导入，退出0并核报告后只补规则基础段与参照实际受影响专项。

- 同一final-sync任务runId `ebfcb32ee7d64a4fa4620b8e541fb27f`：前三次前台540秒等待均124（仅等待到时），本树同步尚未启动；白龙event_probe进程仍有CPU活动，悟空同步亦在途。不得重复启动。

## 沙僧60→61（同树接力，机械等待／收尾用medium）

- 当前分支仍`codex/four-loose-fixes`，本轮仅交付登记与核查范围JSON变化，没有生产改动。已提交检查点82375f84／5ac03faf／3541cbb6／0224f637／5a9a30e3，HEAD以本节提交为准。四项仍进行中，不可报可合并。
- **唯一在途**：`final-sync.log`，runId `ebfcb32ee7d64a4fa4620b8e541fb27f`，长任务PID3389／childPGID3394。它先运行本期忽略目录`queue_final_sync.py`，每30秒pgrep核对其他同步；全部退出后才调用已读`sync_preserve_evidence.py`。已启动，**不要再启动同步或另一个排队任务**。此任务不是automation。
- 当前三轮540秒等待均124，只表示尚未结束。第四次等待会话可自然到时；接手查status与日志尾，继续`等待任务.sh <final-sync.log> --timeout 540`。单次工具阻塞≤60秒（可functions.exec pragma yield60000＋write_stdin50000），减少空转推理，不重复叙述不变状态。最后仍白龙73004／悟空74882同步在途，白龙event_probe9013持续CPU约100%，不是卡死。不能动其他车道进程／槽位。
- 排队脚本已固定`--accept-additions`＋两份接受单（cat去tpGap一条、哪吒slice六条）；缓存沿用，不带--full，保留旧证据/.sandbox/generated。同步预计仅cat1＋slice6既有变化、新enemy_book_defeat34例（总38）；同步含Godot导入。拿到exit0后必须读报告，额外变化要分析，不扩大接受。
- 同步成功后只补`xiyou_rules.tscn`基础段及cat／enemy_book／loose_fixes三场（受参照输出更新影响）；此前另外11场依赖及power全部通过，不重跑整批／全量／旧50%审查。947/5557参照应已从0修正。完成后精简报告入JSON、交付单写可合并（自己的实现待Claude），只清本期four-loose-fixes临时输出。**apply_production.py已执行，不可再执行**；没完成前不清目录。
- 本轮只读定位2g，无任何修改／切支。以后2g仍bf585fdc现场：13场12过、formula_effects906/908，两capState_buffs MP夹值失败；按原最终链把resource_context add锁guard由仅XActor改成除XEnemy的基类分支，先跑formula_effects与state_effects_tp再定。生产文件在`01_Godot工程/modes/xiyou/core/`。formula_execution空结果槽预览问题与两个Apply宿主接口仍按2g原交付的停手范围，不混进本期。
- 机械收尾61创建时实际设medium，不虚称本轮已切；疑难2g按实际难度再提高。60创建61后停止，61唯一执行者。额度五小时17%、周18%，不是停手线。后续仍四项→2g→rng-compare-review→actor-bonus→passive-content→race-battle；自己的实现待Claude。50%审查二期分支0b00c374交总装另合。只用此已有树、所有文件命令显式workdir，共用登记只读，不新开automation。

## 沙僧61接手（2026-10-25）

- 本树HEAD2270aec7、工作区干净，继续唯一排队任务ebfcb32ee7d64a4fa4620b8e541fb27f；status仍running，未重复启动。其他白龙／悟空同步仍在途。
- 实际额度五小时20%、周18%，继续授权工作；共用登记只读，生产补丁不重复应用。同步成功且检查差异后才跑基础rules与三场受影响专项。

## 沙僧61最终同步已启动（2026-10-25）

- 接手后13轮540秒前台等待均只到时（exit124）；其他白龙／悟空同步已经退出，唯一排队任务自动输出SYNC_QUEUE_START，开始本树最终同步。没有重启或增加同步任务，没有改其他进程或槽位。
- 原runId仍ebfcb32ee7d64a4fa4620b8e541fb27f、status running；默认PROBE_PLAN executed53／reused0，未加--full。两份精确接受单及保留证据包装器不变，等待探针、比较、Godot导入终态。不能把“已启动”记为“通过”。
- 本轮文档段已exit0；当前额度五小时42%、周22%，继续等待后按原计划核报告与补测四场。其他车道结果只用于判定已退出，不代它们作验收结论。

## 沙僧61→62（同树自动接力，继续medium等待／收尾）

- 当前codex/four-loose-fixes，61仅改交付单与核查范围JSON；生产没有新修改，工作区以本节提交后为准。61创建62后停止，62唯一执行者。继续原授权四零散→2g→rng-compare-review→actor-bonus→passive-content→race-battle；不是额度停止（最后五小时42%、周22%）。
- **最新状态已改变：不再排队等白龙／悟空！** 两个外部同步已退出；原队列自动进入本树最终同步，日志有SYNC_QUEUE_START。同一runId ebfcb32ee7d64a4fa4620b8e541fb27f、PID3389／childPGID3394、status running。默认PROBE_PLAN 53执行／0复用，未加--full；不能因为0复用而重启／取消／另开同步。
- **已有7/53探针exit0，无失败**：slice六难度＋smart_ai。其余仍在执行或等槽；最近smart_ai seconds1619.567（含排槽）。61累计16轮540秒前台等待均124，只表示仍running；创建62前没有遗留前台等待会话，但长任务本身仍在跑。继续等待任务.sh final-sync.log --timeout540，单次工具阻塞≤60秒。可functions.exec pragma yield1000，循环write_stdin50000，再functions.wait50000，避免空转推理与频繁重读日志；别把脚本初次返回session_id当作退出码。
- 两份精确接受单不变：cat去tpGap一条、哪吒slice六条；预期既有变化仅cat1＋slice6，新enemy_book_defeat34（总38）。保留证据包装器只停两个prune，不改来源、守卫、槽位或工具。完成后必须exit0、核同步报告无额外变化；如有额外变化先分析，不扩大接受。同步包括Godot导入。
- 同步真正通过后仅跑rules基础段＋cat／enemy_book／loose_fixes四场。规则947／5557应从旧参照0变为非0；此前其余11场直接依赖、power137/137、新专项126/126、cat994/994、enemy_book52/52已过，不重跑整批／全量／旧50%审查。apply_production.py已10da1d87执行，绝不能重复。
- 完成后精简JSON、交付单写可合并交唐僧，自己的实现仍待Claude；只清本期four-loose-fixes临时输出（未完成前不清运行中的包装器目录）。旧原版证据、.sandbox、generated和整树永久保留，共用交接板／变更记录／步骤清单／当前状态只读。所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；不新建／清理工作树，不reset/cherry-pick，不追无关main。
- 2g仍bf585fdc未改，13场12过、formula_effects906/908；按最终别名链把resource_context.refresh add锁guard从仅XActor改为除XEnemy的基类分支，先跑formula_effects与state_effects_tp再判断。完整预览空结果槽／两个Apply宿主接口仍按2g原交付停手范围，不混四零散。50%审查二期0b00c374交总装另合，不重做。全局排队入口／证据保留开关优化建议已登记，不动哪吒／木吒工具。
