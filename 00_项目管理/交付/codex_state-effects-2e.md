# 交付：codex/state-effects-2e

- 车道／工作者：翻译／核查 · Codex（沙僧，重制_沙僧_48，按40%规则接续47）。
- 状态：可合并
- 本单记录截至7c99d194的2e设计与参照；2026-10-22用户另行授权修复0b的战力预演与统一预约槽，补充交付单为`codex_state-effects-2e_0b.md`。追加修复不表示五个TP块已实现，也不表示状态预约脚本已进入第四期。
- 0b补充修复已验收可合并，两张交付单须一并归并。下文关于无Godot生产改动、旧双指纹等均指7c99d194前的设计参照阶段；本分支最终生产范围与最新双指纹以0b补充交付单为准。
- 位置：沿用`.claude/worktrees/state-effects-2b`，分支`codex/state-effects-2e`；未新开、重建工作树，未改main或其他车道。
- 本期交付类型：**资源上下文具体设计＋原版证据**。确认需要修改仍留给期三的`resource_context.gd`，按本期交代的停手条件收口；不交孤立TP数值、不进入永久加算／存档期三。五块仍JS，未翻译仍444，完成度不增加。
- 本批前段已合main fd975959（b0cbf868为祖先）；48开工只读主库交接板、两树status／log及brief，主库为6c0b3b71，车道为c545f83d，两树干净。实读额度开工61%／10%、收尾66%／10%，按95%收尾线；按一轮验收规则不反复追合后续main。

## 具体设计与停手原因

原件在[框架维护约定：状态效果2e生命周期资源上下文](../../03_再刷重制_Godot/00_设计/框架维护约定.md)目标节，尚未实现、待Claude核查：

- 保持`XActor.add_state(id, random)`虚方法签名，新增显式域包装入口；保存／恢复holder旧ctx，嵌套同域共享同一资源对象与随机流，跨holder显式传递，不用场景全局槽。
- 技能附加状态的Apply结果进入现有`_action_resources.result(target)`、同一日志与弹字出口；开战由logic单独持有资源槽和阶段结束快照，不能自动生成原版没有请求的弹字，也不把开战槽带入下一行动。
- `XResourceContext.refresh`必须区分类型外层工作、基础抵抗清除／截取、阵亡同步；不能统一“加状态时不刷新”。角色真实Apply允许TP暂超上限；敌人当场截取，但内部再次add阵亡仍受全局锁抑制。现资源层直接截TP／改状态数组，无法复现这一区别。
- 地图／菜单的直接add_state也需要所属state宿主持有根域及操作结果；只给battle_logic传ctx不足以把全库Apply块标为已支持。预览不得取真实默认域、资源、状态／参数与效果缓存、RNG、诊断或结果槽。
- Godot开战当前先Battle效果、后随机初始TP，启用607／857会被覆盖；新补充case单查真实Game_Unit.onBattleStart顺序，修正须与资源域一起交，不做孤立数值实现。
- 最少需把`resource_context.gd`作为**2e前置**明确交接；若角色刷新分层或地图／菜单根域必须改其他宿主，再先交接相应文件。交接板给沙僧期三的范围不能自动当成本期授权。本分支没有改actor、XState、resource_context、角色测试或任何Godot生产代码。

## 原版参照与原始证据

### 已保留的native22（不重复手动测量）

- 原22例的独立副本及native-v2.log保留；正式同步后的`mv_oracle/.sandbox/state_effects.json`已更新为26例，原22例以独立副本`04_验证/本地结果/state-effects-2e/native22-preserved.json`为准，SHA256 `24100228be3102a9dcca56fa0bb5ed9b08bbbd9b5819742308772c478876b0a0`。
- `tp.native_blocks`：140条直接执行边界（角色1／敌人、5块、初始TP -1/0/1/150/199/200/250、活／死），另4条真实连续addState两次。旧21例与2d最终参照相同，原22例errors=[]。
- 初值1的真实重加不会碰上限；140条直接调用不经过真实addState锁。不能用这些行声称自定义上限／刷新嵌套已经闭环。

### 新补充入口（可只跑本组，不跑native22）

`03_转换工具/mv_oracle/state_effects_tp_context_probe.cjs`独立执行只输出`.sandbox/state_effects_tp_context.json`；正式`state_effects_probe`复用同组case，追加在反击前。补充探针没有修改冻结源，所有原版写入受原有.sandbox守卫约束。

- `tp.guarded_apply`：8行，角色／敌人 ×1334／1336 ×正常HP／0HP未死。每行记录首次、重加、独立refresh。角色199→224／274，重加不再gain，独立refresh才回200；敌人首次即200。0HP未死两者都延后到独立refresh才加阵亡；两次重加共2次时长随机，若后续独立refresh加阵亡则合计3次。
- `tp.actor_custom_caps`：14行，合成技能经真实passiveEXTTP=-160／+100使角色上限40／300。5块直接执行与2块真实addState逐项记录，直接执行截上限，真实Apply可到64／114或324／374。不是替换maxTp函数，也不冒称覆盖全部上限机制。
- `tp.refresh_state_boundary`：4行，注入陈旧被抵抗状态后比较直接调用／真实addState。角色真实Apply保留该状态到独立refresh；敌人真实Apply当场清除。基础erase不写removedStates，也不新增Remove／Leave回调。
- 以上3例26行已在tp-context-native-v2.log退出0、errors=[]；原始副本`tp-context-native3-preserved.json` SHA256 `f705f6ab39b9ce057be49dd55e3cb6b725819bef3611d68f8fbf44c5a5985413`。
- `tp.battle_initialization`：新第四例，经真实Game_Unit.onBattleStart记录随机TP初始化与607／857的Custom Battle先后；tp-context-native-v5.log在共享0号槽取得占位后退出0，4例errors=[]。真实开战先17→12随机初始TP，再由607到200、857到62（角色8与敌人均62）；共7次随机抽取，其中包括本场其他成员。四例独立副本tp-context-native4-preserved.json SHA256 `a4844cba500477723f593b997a9517df9eef8d9fb310f398ce30a3630debe5b5`。

## 验证、失败与同步

- 新补充探针与主探针语法检查通过；现有状态整块翻译测试7/7通过。未改变转换器，五个TP块仍JS。
- tp-context-native.log失败根因：夹具把VM的_states替换为宿主Array，丢MV contains扩展；改为保留VM数组、清空并push内容。修后v2首次通过。失败原始输出保留，不算偶发，不改源算法。
- tp-context-native-v3.log在测量启动前失败：本地共享槽包装器上溯目录多一级，找不到并行测试模块；已修本地路径；v4轮询等槽4分53秒仍未启动node，核实本轮进程身份后仅停止该排队器（exit143），v5改为共享0号槽阻塞排队后首次运行第四例通过。未提高全局4槽上限，不算原版测量或偶发。
- 按车道规则不跑全量检查。没有Godot生产改动，收尾只跑state_effects专项与严格原版增量校验；主库由唐僧合并后统一检查。
- 932b4df后已执行交付前git merge main（Already up to date，fd975959）；最终正式同步`--accept-additions`（runId `cc997a743fba4cb18bc912c9b37cc4df`）于2026-10-22 23:25:09 Europe/Paris结束，exit0。沿用32组、重测14组（切片按六难度拆成6个命令，合计19条命令全exit0），耗时含共享槽排队。未重启同步，未提高并发上限。
- 正式只增比较：基线21→26例，只新增`tp.native_blocks`及本轮四例；`onlyAdditions=true`，`problems={}`、`changes={}`、`acceptedChanges=[]`。来源数据／运行时代码、数据库记录、地图、切片均无变化；来源核验1665项输入／382项运行时／1639项输出，issues=[]，Godot导入成功。没有写接受单放宽旧值。
- 本地`verify-final.py`于同步后exit0：保存的旧native22全部逐项相同；新增四例与独立测量相同（仅抵抗夹具动态ID归一化）；来源身份三方一致；正式26例errors=[]。五块仍JS、总未翻译444。最终26例文件SHA256为`7eff2c8a0c7632f25f9b419cfe5e2edb6e363094ee5f0ee6af57f2293a2160ad`。
- 本批证据目录为本树`03_再刷重制_Godot/04_验证/本地结果/state-effects-2e/`：`sync-design.log`及status.json、`final-validation.json`保留。正式同步报告／来源清单／导入日志在`04_验证/本地结果/自动同步/20261022_230421_367006_v0.28-v0.28/`（相对`03_再刷重制_Godot`）；原始失败输出亦保留。

- 同步后的来源与正式双指纹由本分支原同步模块重新计算一致，完整值写入下方变更记录草稿，随合并留存；正式stamp时间2026-10-22 23:25:08。之后只改交付文档，未改工具、探针或转换产物。
- 单槽Godot专项`xiyou_state_effects`于23:25:45～23:25:48首次实跑通过，`TEST_RESULT={"passed":19949,"total":19949}`，exit0，单场景2.481秒，`reused=[]`、`flakyRerunPassed=[]`，attempts仅1次。runId `543fa66de1fe4e2d924b5f942956029c`；日志为上述证据目录的`state-specialty.log`及`state-specialty/xiyou_state_effects.log`／`test_timings.json`。该专项验证既有状态效果与26例参照无错，不表示新增四例已有Godot逐项实现。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】2e生命周期资源上下文设计与真实Apply刷新边界参照（玩法未实施）

- 在[框架维护约定的2e目标节](../../03_再刷重制_Godot/00_设计/框架维护约定.md)为607／609／857／1334／1336五个纯TP整块补齐具体资源域、嵌套恢复、结果槽与宿主消费设计；原版测量发现角色真实Apply可暂时超TP上限、敌人当场截取，不能直接复用现资源refresh而忽略全局锁与类型差异。
- 需要修改本期未获范围的resource_context刷新层，按停手条件只交设计与参照；五块仍JS、未翻译444、完成度不变。没有永久addParam／存档实现，不算进入期三。
- 原版参照：正式基线21→26，仅新增`tp.native_blocks`与`tp.guarded_apply`／`tp.actor_custom_caps`／`tp.refresh_state_boundary`／`tp.battle_initialization`；保存的native22全22例原样，四个补充case与独立测量一致（只归一化动态夹具ID），26例errors=[]。覆盖TP边界、真实重加、角色／敌人刷新锁差异、自定义上限40／300、陈旧抵抗状态、HP0未死及真实开战先随机TP后Battle效果。
- 验证：本轮正式同步`--accept-additions`于2026-10-22 23:25:09 Europe/Paris exit0，沿用32组／重测14组，19条实际探针命令全exit0；`onlyAdditions=true`、`problems={}`、`changes={}`、`acceptedChanges=[]`，没有放宽接受单。冻结来源v0.28，1665项输入／382项运行时／1639项输出核验无问题，源、数据库、地图及切片不变，Godot导入成功；`verify-final.py`严格逐项校验通过。现有翻译测试7/7与两探针语法检查已过；单槽`xiyou_state_effects`首次19949/19949通过、exit0、2.481秒，无缓存沿用或重跑。新增四例尚无Godot逐项实现；车道按规则不跑全量，唐僧合并后统一`检查.sh --oracle`。
- 证据：保留`.claude/worktrees/state-effects-2b/03_再刷重制_Godot/04_验证/本地结果/state-effects-2e/`下native22／补充3例及4例副本、原始成功与失败日志、`sync-design.log`、`final-validation.json`、`state-specialty.log`和专项目录；正式报告在同树`04_验证/本地结果/自动同步/20261022_230421_367006_v0.28-v0.28/`。原始证据不入Git，未归档核查前不要删除本树；未改冻结引擎或其文件系统守卫。
- 文件SHA256：native22为`24100228be3102a9dcca56fa0bb5ed9b08bbbd9b5819742308772c478876b0a0`；独立补充4例为`a4844cba500477723f593b997a9517df9eef8d9fb310f398ce30a3630debe5b5`；最终26例为`7eff2c8a0c7632f25f9b419cfe5e2edb6e363094ee5f0ee6af57f2293a2160ad`。
- 来源规范化SHA256：完整身份`1ae5c84535eeb519e7110920edaaf0b3b6ed84def7938fbd1a2202594c46b224`，inputs为`7b3c911a8e9d645c9edc68c0bd6ef431a6f6853b897e58843eb0b6e5e3abc210`，runtimeInputs为`e40e0c9204a2e478a991e2447bae5bd42cae90a7e07369c90beebdbe2a994de0`；规范化使用UTF-8 JSON、sort_keys=True、separators=(',',':')、ensure_ascii=False，与原始文件SHA区分。
- 官方双指纹：toolsDigest=`45514c37c33712a890eaaf7b0efa4b641e7bf57e2432b97c4d5e08f16f81ad98`，outputsDigest=`60fe0aa4898ca6c2cedcef639e9708581afcf522b1d9f92943eb9e9c45cf39fc`，由原同步模块`tools_digest()`／`outputs_digest()`重算与正式stamp一致；stamp时间23:25:08。后续仅改文档。
- 提交：`codex/state-effects-2e`（设计／探针检查点26fe46f、3faf0cd、fb9f73d、9d249fb、932b4df、4b3700d、3f4e6c0、c545f83d；48接手76fff4b、同步与指纹b84f1a8及最终交付提交），全部待Claude交叉核查。未完成：五块TP生产接线及Godot同点对照；先把resource_context作为2e前置明确交接，必要的actor与地图／菜单宿主也须交接，再实现本期，之后才开永久加算期三。

## 交接板草稿

- 下一步：先交接resource_context给2e作必要前置，按框架原件分层刷新与共享结果槽完成五块、Godot逐项对照后再交2e玩法；此前不启动永久加算期三。若地图／菜单宿主未交接，Apply完整块不能仅靠战斗入口宣称完成。
- 用户试玩说明：本批只补设计与参照，玩家行为未变。
- 需要用户决定：无新增玩法取舍；范围交接由唐僧登记，本轮不自行借用期三文件。
- 待交叉核查：本分支所有提交，执行者Codex（沙僧），核查待Claude；不能由沙僧自核。
- 进度账：不变，原版参照或接口设计不计已实现。
- 清理：本树有未入Git的native22、补充原始测量与失败日志；未归档核查前不要删目录。

## 本分支检查点

- 26fe46f：恢复期二、已合main并补齐环境；native22保留。
- 3faf0cd：补充探针测量前检查点。
- fb9f73d：修正VM数组夹具、保留首轮失败记录。
- 9d249fb：保存26行补充证据、接入正式探针与可独立入口。

- 932b4df：显式资源域／分层刷新具体设计与停手边界，交付前已合main。
- 4b3700d／3f4e6c0／c545f83d：开战初始化顺序、根域结果槽接续及47接力点。
- 76fff4b／b84f1a8：48接手同一同步任务，保存正式严格只增与双指纹；最终设计参照交付以本分支HEAD为准。

## 47→48接力检查点（2026-10-22，历史现场，最终结果以上文为准）

- 按[会话接力与省额度](../规则/会话接力与省额度.md)40%约定在原树续接，身份仍沙僧。额度59%／9%，未到95%；未自核完成度，未接唐僧。
- 交接时最终sync-design.log仍运行，runId cc997a743fba4cb18bc912c9b37cc4df；32组缓存沿用、14组重测，六份难度切片已全exit0，后续探针继续单槽。交代不得重启同步或手动重复native22，48已遵守。
- 交接时新四例独立原版测量已经全过，尚无最终严格只增结论、双指纹或Godot专项结果；这些收尾结果已在48补齐。玩法仍未实施。
- 完整自足续作说明与已备好的verify-final.py在本树04_验证/本地结果/state-effects-2e/；下一步先等当前同步，再逐项比对22旧例＋4新增、核指纹、跑state_effects单专项，最后补齐设计参照交付。
- 原工作区开新会话前所有跟踪文件已提交，未入Git仅原始证据、日志和本地排槽包装器；不要清理本树。源主库共用文件未修改。

## 48接手（2026-10-22 23:21 Europe/Paris）

- 已依次只读主库交接板、两树Git状态／日志及本树brief；主库main为6c0b3b71，车道为c545f83d，两树均干净。保持沙僧身份，只在原树继续，不追合后续main。
- 实读额度五小时61%／周10%，未到95%收尾线。最终同步仍为同一runId，已完成输出均exit0，未重启、未另测native22。
- 接手范围保持为本批设计与参照收尾：同步结束后严格比对原22例与新增4例、核正式双指纹，再跑单槽state_effects专项。全部仍待Claude核查，不自行核查完成度。

## 48收尾（2026-10-22）

- 同一正式同步已exit0，严格只增、旧22例保留、来源／工具／产物指纹、单槽专项均通过；本单标可合并仅指设计与参照。本轮没有Godot生产／转换器／actor／XState／resource_context修改，完成度不增，未开期三。
- 只在本聊天报告可转唐僧，不自行跨聊发消息，不改主库共用登记；唐僧并入上述草稿、统一全量检查并保留待Claude交叉核查。本树证据未归档前保留。
