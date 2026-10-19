# 交付：codex/rng-rework

- 车道／工作者：规则返工／沙僧（Codex，重制_沙僧_10 接手沙僧_9）
- 分支与工作树：`codex/rng-rework`，`.claude/worktrees/rng-rework`，从main 0ea5c5c新建；辅助补齐和Godot导入已结束；沙僧8核对进程后开始游戏侧返工。
- 开工时main由唐僧合八戒_27：C车道已从交接板删掉，原车道干净且交付可合并，只有A悟空_23仍写代码。可接本RNG车道；不得改A转换器／切片或抢改battle_logic、XBattler.recover_all。main的开发编号／交接板等尚在唐僧未提交的合并收尾中，不要替他提交。

## 变更记录草稿

## 2026-10-19 【Codex·沙僧·未经Claude检验】RNG返工开工与接力

- 游戏侧返工已实施：普通档不再序列化或恢复运行时随机流，忽略dev.099旧random字段，orb_seed／rom六字段及既有装备实例原样保留；运行时主种子由独立熵生成。
- debug replay升到schema2，显式记录预约后、setup前的runtime和本场rule/reward起点，重播直接恢复，不依靠普通读档或结束游标；严格引擎／内容／构建版本校验保留。
- 遇敌、地图事件／脚本随机、真气、挂机接world；NPC随机走动与打字音各自独立原生RNG。实战公式所有不可用返回统一告警并保存有界诊断，纯预览不记录。
- 已完成核心专项：随机流482项、确定性与画面干扰372项、公式资源链908项、敌人装备公式1804项。日志`04_验证/本地结果/20261019_RNG返工/核心专项.log`。尚未跑最终完整检查，不宣称可合并／增加进度。
- 楼层流程测试存读后显式恢复测试夹具的runtime以保固定场景，另断言普通读档时流未恢复；游戏行为不走该测试接口。

## 交接板

- 第一优先：完成用户dev.099返工。普通存档不再严格匹配Godot引擎串，异串可读且重建随机流；unsupported实战公式告警并留诊断；同档重打可刷不同结果，普通档只保留原版固定的装备实例、rom池与游标、orb_seed及已有内容，battle/world/装备现掷流不随档固定；debug replay每场保存种子并显式恢复，仍可拒绝异版本。
- 游戏侧接流：遇敌、事件脚本随机、真气、挂机接world；地图随机走动和打字音各自独立RNG。world按用户默认不随档固定。插槽／强化等现掷不能因equipment RNG随存档续跑而重新固定。八戒_26的测试调整已在main。
- 验收：异引擎串档能读／运行时流重建；unsupported告警；同档两次真战出现不同结果；rom数组／全部游标和既有实例逐字不变；显式replay复现；预览／走动／音效／画面不推进规则流；并行完整检查下xiyou_floor_run_c连续两轮通过；检查.sh --oracle全部通过。规则参照先于实现，不碰真实存档／源。
- 代码定位：XState._ensure_random_master目前从orb_seed派生，所以仅删除random序列化仍会固定；to_dict/random_save、from_dict及XSave.valid_data目前严格引擎串；replay目前靠initial普通档隐式重建同一battle，切分后须独立保存／恢复边界runtime及setup前本场seed，不能恢复结束游标或走普通读档重新随机；run_item执行入口对多种不可用原因早退，需统一实战告警／诊断，纯预览不告警。mv_script的RomGet也调用MVInterpreter.random_int，接world时应保留其预掷语义与池数据。
- 独立后续任务：缓存核查问题修复在`codex/review-backlog-20261019-followup`；不要混入RNG分支。converter-write-changed仍归A独占，未做。可选老积压最后处理。
- 需要用户决定：无新增；按10-19已定可刷与world默认继续，不重复询问。

## 进度账

- 不增加。前轮沙僧4～6的`codex/review-backlog-20261019`（12aa60f）已有可合并核查交付，尚未并入main，不能覆盖或自核其Codex补丁；其中dev.087／090的战斗61%建议等唐僧登记。

## 本分支提交

- 9344b8d／f43f59d：RNG返工接续与沙僧8开工。
- 本次提交：普通档随机边界、显式重播、world／演出接流与核心回归。

## 沙僧7其余工作与正在运行的检查

- `codex/review-backlog-20261019-followup`，工作树`.claude/worktrees/review-backlog-20261019-followup`，头dc14416，干净，只有交付文档。已核32个登记探针依赖：无Python依赖，读generated者仅formula_program／formula_equipment／event，当前(a)放宽无漏项。真实Node＋真实ProbeCache复现(b)漏洞：旧party用例value1→2，首轮退出2，第二轮缓存命中退出0，第三轮--full也退出0；因比较基线取已被覆盖的generated/oracle，非单纯缓存问题。**尚未修**，需独立保留已接受基线（oracle＋源manifest），拒绝后缓存可复用但比较不能换基线；最近三份备份淘汰不能删该基线。需补拒绝连续重跑、只新增后显式接受、变化撤回、全量／车道克隆回归。30项既有工具回归全过（930fd759b7b04277818b439511395dac）。P0拒收、bab1981二进制日志、敌人双向上下文已在main并留回归；旧Codex实现仅核实存在，不替代Claude核查。
- 上述分支完整检查正在运行：`03_再刷重制_Godot/04_验证/本地结果/20261019_缓存复核/完整检查.log`，基线main368cf18，runId见.status.json。证据同目录有复现测量基线.py/json与探针依赖清单.json；仅临时夹具，无真实数据。**先用等待任务.sh读取结束，不重复开检查；等待器超时124不是被测任务失败。** 原PTY session70192只作辅助，结束以日志状态为准。
- `codex/framework-docs`，工作树`.claude/worktrees/framework-docs`，头4700681，干净。已完成现状／历史拆分（六段原文逐字保留）、11备注转换期解析／12 XSession／13模块挂点接口、八例覆盖矩阵与含466→538的可执行缺口清单、用户10-19非持久运行时RNG目标；仅文档。当前八例过滤2651、缺剩余回合／待行动／完整队列等如实标注。预检旧链接补battle-events稳定锚点。完整检查正在运行：`03_再刷重制_Godot/04_验证/本地结果/20261019_框架文档/完整检查.log`，基线main368cf18，PTY13061，结束以日志状态为准。合并工具模拟能提取1条框架／3条复核记录，无共用章节混入。
- main刚新增八戒_27合并0ea5c5c，唐僧正在收尾；以上两条检查只认证旧基线。结束后整理结果、小步提交，再等main收尾已提交后各自merge main，修正文档对“已知变身／Permanent问题仍待修”的过时描述；需要重新检查时按新main实际变化执行，不用旧结果冒充新基线通过。两条交付目前状态进行中，别提前写可合并。
- 收工仍按用户模板：交付二级标题原样，最后普通“- 状态：可合并”；游戏改动标题用开发编号占位；每次提交尾注“执行者: Codex（沙僧）／核查: 待Claude”。不改主交接板／记录／进度／编号／来源登记。源码与工具都等Claude交叉核查，不自销。

- 沙僧8已读交接板、主工作区及本车道status/log，确认主工作区未提交内容属于唐僧；原两条完整检查仍在跑，不重复启动。参照基线指纹在`04_验证/本地结果/20261019_RNG返工/参照基线.json`。

- 长操作：已执行`git merge main`，当前最新main0ea5c5c已包含八戒_27规则修复；即将启动完整`检查.sh --oracle`，日志`04_验证/本地结果/20261019_RNG返工/完整检查.log`。导入结束后再启动同目录`后段连续两轮.log`，在完整检查并行负载下顺序跑floor_run_c两轮。期间不改本分支被测源码；保留Claude核查。主工作区唐僧后续开发编号收尾尚未提交，交付前仍须再对账最新main。

## 沙僧8实现检查点与沙僧9接力（2026-10-20）

- 当前本分支游戏代码已实施，提交95a51c3；开工f43f59d，长任务登记b3017ce。未提交源码：无。沙僧8在此停止编辑，由下一会话独占接续。
- 核心专项5场景4794断言全部通过：determinism372、equipment1228、formula_effects908、formula_equipment1804、random_streams482。两个早期测试夹具错误（Map000 summary、把VM steps误写为body）已修；初测里的equipment续跑／隐藏setup同流旧断言也已改为普通档重建与显式debug续跑。最终核心日志是`核心专项.log`，不是两份初测日志。
- 实现文件：XState普通to_dict不含random、from_dict忽略旧random且lazy fresh master不由orb派生；runtime_random_snapshot／restore_runtime_random只用于显式调试。XSave不以旧random引擎拒档。XBattleLogic只加setup前的两个debug快照字段，不碰状态21、recover_all或八戒规则路径。XBattleReplay schema2保存预约后setup前的runtime和本场起点，比较finalRuntime。XFormulaExecution所有不可用返回统一push_warning和128条有界诊断，预览安静。MVEventCore静态随机接current.world、XZhenqi._random_int明确接s、挂机和遇敌接world；MVEvent和MessageBox各自原生RNG不碰全局。floor_run每次读档先断runtime为空，再显式恢复测试夹具runtime，固定测试场景不改变游戏存档行为。
- 本分支完整检查已在运行，PTY1779只是辅助：`04_验证/本地结果/20261019_RNG返工/完整检查.log`，runId `7447c881912045a78516aa775e300869`。记录基线main0ea5c5c，git merge main当时Already up to date。先用等待任务.sh等终态，**不再开一份完整检查，不在导入／测试中改本分支源码**。
- 后段连续两轮也已在运行，PTY37518只是辅助：同目录`后段连续两轮.log`，由同目录Python夹具先等本分支完整检查导入结束、进入并行测试后，顺序运行两次floor_run_c；每轮启动前断完整检查仍running。最后应有`TWO_CONSECUTIVE_ROUNDS_PASSED`，并由长任务包装器给退出0。接力时仍ROUND1，尚不能称通过。脚本和所有证据均被Git忽略，不是待提交文件；下一会话只读等待，不重复启动。
- 旧两条完整检查依然运行，位置／runId见上段；两者只认证main368cf18，不认证最新main0ea5c5c。已有进程在多个全量检查／main六并行／A专项共同负载下运行，部分rules/smart_ai可能达到600秒硬超时；须保留真实失败结果，不能写成已过。等结束后各分支merge已提交main再按最新代码验收，合理排队避免多份完整检查同时把机器打满。
- 主工作区唐僧仍在收dev.101，main最后所见0ea5c5c；所有main未提交变更都是他，不代交。交付前再看main是否已有收尾提交；若有新切片／转换器／探针才补齐生成，普通登记更新不要误重跑同步。A悟空_23仍占转换器／切片；converter只写变化产物任务继续等待A释放，未实施。
- 下一工作顺序：先等待本RNG两份验收，失败则定位后修稳，再按最新main交付；同时等旧cache／framework检查结束。RNG完整检查运行时可在已结束检查的独立缓存分支推进工具修复，不能改被测RNG源码。framework合0ea5c5c后把466→538／KNOWN_TRANSFORM_GAPS与Permanent“待修”语句改成八戒_27已修的真实边界（状态／队列等八例缺口仍保留），完整检查也要最新main。
- 缓存修复已读完实际_main与测试，尚未写代码。推荐小方案：在generated目录外（不能随clone删除）、最近三份备份以外保存“本次尚未接受前”的oracle＋manifest，原子初始化；拒绝、导入失败、来源失败／缓存发布失败均保留，后续普通／命中／--full／--from-worktree都对它比较测量及source_preserved；只有最终成功接受／撤回到旧测量且整轮成功后才清除，该时点下一轮才从当前已接受产物重新初始化。当前脚本取backup/oracle和old_manifest会把拒收结果当新基线，单改cache.commit不能治。注意clone预检失败应不写任何产物，baseline应在预检之后、备份淘汰／转换之前创建；路径不能放gen内部或自动同步日期备份里。
- 缓存回归落在`07_开发环境/测试增量同步.py`（CacheTests已有真实Node夹具）或`测试合并工具.py`（SyncRegistrationTests／SyncStampTests已有_main夹具）。至少验连续拒绝多于3轮且缓存确实命中、--full仍拒绝、只新增连续拒绝后显式accept、变化撤回成功、来源manifest更改仍连续拒绝、车道clone连续拒绝；source／import／cache失败不得提前换基线。现有证据脚本断言旧漏洞[2,0,0]仅用于记录，不能当新回归期望。工具文档`长任务与增量同步.md`也应写清缓存与接受基线的区别。此前30项工具回归原结果仍保留。
- 接力仍沿用精确交付标题、最后普通状态行。所有提交尾注Codex（沙僧）／待Claude；只能自测，不自销Claude核查，不改主交接板／编号／来源登记。老分支12aa60f交付保留不覆盖。

- 沙僧9接续：已读主规则、交接板与四份验收状态；主工作区仍属唐僧且未提交，不代交。RNG完整／连续两轮、旧缓存／框架完整检查均running，继续等待，不重复启动或改被测源码。

## 沙僧9检查点与沙僧10接力（2026-10-20）

- RNG游戏代码仍为95a51c3，沙僧9未改被测源码，当前未提交改动：无。双轮验收已确认终态：`后段连续两轮.log` runId d2391f21ebc648c9a8a01575d422948e退出0，两次floor_run_c各534/534，末尾TWO_CONSECUTIVE_ROUNDS_PASSED；两轮开始时完整检查均仍running。不要再跑一份双轮。
- RNG完整检查runId 7447c881912045a78516aa775e300869仍running，原路径不变；只读等待，不改代码、不重复开。core五专项4794与双轮都已过，但整轮尚未认证。基线main仍0ea5c5c，唐僧未提交的dev.101合并收尾都保留；交付前再读main提交，不代交。
- 缓存分支本轮有实际修复：`codex/review-backlog-20261019-followup`已merge main0ea5c5c（687168b），修复b8749f8、验证登记f07d889，工作区干净。同步覆盖前把oracle＋source manifest原子保存到generated／日期滚动备份之外的`04_验证/本地结果/同步基线/<gen路径摘要>/`；拒绝、命中、--full和clone均对同一接受基线；整轮成功后原子退役。失败及损坏不改边界，clone预检失败不动产物。
- 缓存真实Node／真实ProbeCache新增9例已过；修复后独立工具39/39，`修复工具回归.log`退出0；《测试合并工具》聚合93/93，`修复同步入口回归.log`退出0（此脚本忽略类名命令行参数并总是跑全套，末尾还聚合增量测试，不要再重复加检查.sh入口）。新回归先红（旧实现第二轮0!=2），再绿。最初夹具用party未知新增结构导致两例误拒，已换已登记events结构，最终9例与39／93均通过。
- 缓存旧完整检查58e57e785be84c9584d1e8de49367d40已结束、退出1，仅rules／smart_ai各600秒超时，其余Godot项、工具84/84、源守卫均过。日志保留；不把它当新main或修复后的通过。新完整检查尚未启动，等现有RNG／framework检查结束再排队，避免重新三份互相压超时。本次未跑实际生产同步，只在临时夹具验证同步；若要更新工具指纹供合并复用，应按规则实际同步，不能手写stamp。
- framework仍原头4700681、干净，旧完整检查仍running，原路径不变，只认证main368cf18；尚未merge新main。它的rules／smart_ai可能超时，按真实终态记录，不拿旧结果冒充。等结束再merge已提交main，改《框架维护约定》旧466→538与Permanent待修说法：main0ea5c5c已删除KNOWN_TRANSFORM_GAPS，troop专项严格比旧HP上限334回满、Permanent686及ATK／MAT／最终MHP；recover_all保留Permanent本来已实现。仍缺逐336/334步骤／完整队列／上下文／真实复活／schema及画面，八例矩阵其他缺口不删。原版其他能力值缓存不清的完整仿真没做，HP截断仍按新上限；当前11处形态新基础MHP不低于旧值，不扩大为所有变身全等。
- 下一步先读两份尚运行日志终态；RNG失败定位修稳，否则整理交付。缓存补新main完整检查／必要真实同步与指纹；framework合新main修文档后排队完整检查。仍保持三条分支分开、精确交付二级标题、最后普通状态行、Codex（沙僧）／待Claude尾注，均不自核。旧12aa60f核查交付与战斗61%证据保留，converter-write-changed仍等A悟空_23释放，未做。
- 沙僧9在检查点停止编辑，下一会话独占上述三条沙僧分支；主工作区只读。上下文接力不再询问用户。

- 沙僧10开工：已完整读主规则、车道交接、三条分支与运行状态；本分支完整检查仍running，仅只读等待，不重跑双轮；main仍0ea5c5c，唐僧未提交收尾保留。

- 状态：进行中
