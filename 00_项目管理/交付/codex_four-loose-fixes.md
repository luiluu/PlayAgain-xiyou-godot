# 交付：codex/four-loose-fixes

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_59）
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
