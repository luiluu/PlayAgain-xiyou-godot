# 交付：codex/state-effects-3-design

- 车道／工作者：状态效果·框架／Codex（沙僧，重制_沙僧_44～46）。
- 状态：进行中
- 整批范围：此前撤回的2b～2d状态翻译、第三／四期接口设计、三十一层流程夹具修复。只合本分支即可带入2b～2d；不要再按旧分支分别合。
- 最终组合基点：main 77f41c73（dev.134内容），本树e37d5660已合入，无冲突。main的未提交收尾只读；没有接总装或修改共用登记。
- 本批所有实现与夹具均待Claude交叉核查，不自核、不记完成度增量。第三期永久加算与第四期预约事件仍只有设计。

## 根因、原版参照与修复

- 2d正确翻译1047物理免疫后，原流程夹具四名队员的首武器均带元素1，三十一层女娲完整开场使1047进入热缓存，纯物理夹具无法推进。原合并态505／507、只临时停1047即558／558的因果隔离与还原摘要，见[返工分析](../返工分析_20261022_三十一层.md)。诊断隔离没有作为修复提交。
- 原版完整BattleManager两例保留Troop467全部开场、1397、强制6068／6055／6057／6051／8111、842=0和682 ON时的1053。add1047返回后缓存仍旧，add1053后含1047。公式1e20保证真实固定减伤后仍有正输入；元素1经React1047归零且实际hpDamage=0，元素2保留正值并实际扣HP。Godot同点React1460→1047→1108一致。只证明缓存与免疫分支，没有宣称整条非固定数值链逐值相等或原版整场重演。
- 最小修复只改tests/xiyou_floor_run.gd：仅F31临时让actor8修学习533「天罡五雷」，走正式ActSkill排前16回合；战后恢复排表、临时技能和旧observer。物理阶段由队友原普通攻击完成。不改敌人状态、不设842跳开场、不提高攻击、不放宽胜利断言。
- 新增两条断言：842=0且682 ON；实际正输入先见1047＋1050／1053的533，之后见1048＋1051且无1047的普通攻击1。组合前已560／560、floors[21,33]，最终组合结果见下。
- 首轮夹具559／560已胜到33层，失败来自新断言指定的技能200受技能类型限制未使用；收窄为只排533、第二阶段核实际普通攻击后通过。原始日志保留，不按偶发销账。夹具需总装／悟空交叉复核。
- 合hajimi时唯一冲突在伤害入口，aaa45557保留2b的_calculate_damage→统一finish与状态上下文，同时在calculate选项保留battleRound=max(1,turn)，不重复finish。之后dev.132～134无冲突合入。

## 验证与同步

- 车道不跑全量检查；总装合main后统一运行检查.sh --oracle。
- 首次正式同步sync-hajimi.log已exitCode0：旧17例按id逐项不变，只增bonus.native_blocks、damage.full_chain、value.native_blocks、query.native_blocks到21；其他测量不变、21例无错误，无接受单、cacheError或importError，来源核验通过。报告：04_验证/本地结果/自动同步/20261022_180454_467280_v0.28-v0.28/同步报告.json。
- 首次双指纹已复算：toolsDigest=60b06ba84d261ba09d13b7311c8e618d8107e3c25e8d4b487c9d362cd30cae3f；outputsDigest=8c7016669fbd2922948f7e113dd61dec4a350396399c23be5771e5332bc8c1c5。
- main后续修改转换器PNG正规化和review_fix探针，所以按规则合main后再次补齐、刷新最终同步指纹。refill-final.log通过，带入main状态17例和review_fix40例；pre-final-sync/保存比较边界。首次成功21例也从保留的原版产物存为verified-first-21.json。
- 最终同步sync-final.log已exitCode0（22:06:23 Europe/Paris），重跑4／复用41探针；17→21只增同四例、旧17不变、与首次21例按id完全一致、其他测量不变、来源与双指纹已核对。报告：04_验证/本地结果/自动同步/20261022_214400_831283_v0.28-v0.28/同步报告.json，独立核对：final-sync-verification.json。
- 最终指纹：toolsDigest=30d36d91fd4e6c766d5df19e4cdbdfbca9efd86fb97cec0dc0651afac7814509；outputsDigest=eac232bf2178fcd29aa7e229259d0bc45b7dd77b761183ec87601f861cc00d43。没有接受单、cacheError或importError。
- 22场景组合final-validation.log已开始，尚待结果。单槽使用同一个slots/0.lock，不突破全局四槽上限，不改正式测试工具或守卫；同步首个探针耗时含等待共享槽约20分钟，不能当探针自身性能。
- 22个专项：state_effects、battle*、combat、shield、imported_balance、custom_damage、drop_record、formula_effects、random_streams、transform_params、floor_run*、cat、actor_p0、help_card、sequence_visual、interp_review。最终结果未出前不能宣称全过。
- 本轮额外检查：翻译边界7项、公式程序12项通过；内容覆盖检查通过（1906页、new=0、resolved=0），未改覆盖基线。合入新主线后的日志为final-translation.log／final-formula-program.log／final-coverage.log。

## 原始证据与失败边界

- 本树04_验证/本地结果/state-effects-3-review/保留复现、因果隔离、原版冷缓存、连续前置、完整开场、Godot同点、首轮错误夹具及最终成功日志；未删除失败证据。
- mv_oracle/.sandbox/f31*的15份脚本／JSON已复制到同结果目录native-evidence/，manifest.json逐文件记录SHA256并核对复制一致。清理工作树脚本会归档本地结果，原始.sandbox文件也仍保留；复核前不精简。
- 早前pre-sync-comparison.json是跨版本只读比较，不是正式接受依据；最终接受只认本次正式同步报告与稳定用例键。
- state-effects-2b工作树当前检出2e，内有未入Git的native22与日志，本批不清理、不重测、不并入。

## 本次返工变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】状态效果2b～2d整批重交：保留女娲免疫双阶段（dev.待定）

- 三十一层流程回归来自正确启用1047物理免疫后，原纯物理夹具无法推进。已用完整原版BattleManager开场确认1047经1053刷新进入热缓存；元素1正伤害归零、另一元素保留，Godot同点免疫分支相同。完整因果与证据边界见[返工分析](../返工分析_20261022_三十一层.md)。
- 仅F31临时给修安排正式技能533，第二阶段由原有普通攻击结束，保存恢复排表／临时技能／observer；保留全部开场和原胜利断言，新增开场与免疫双阶段断言。没有停用敌人状态或改变游戏免疫规则；测试侧调整待总装／悟空交叉复核。
- 合主线hajimi时保留统一状态结算与battleRound回合上下文，随后组合dev.132～134。翻译边界7项、公式程序12项、内容覆盖基线检查通过；最终同步与22专项尚待结果，完成前本批不可合并。全量检查由总装统一执行。
- 2b～2d各期翻译范围、未支持边界与历史验收见随分支携带的各期变更记录草稿；本次组合验收不能用历史专项替代。全部待Claude交叉核查，不自销账或增加进度。

## 接口设计变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】状态效果第三／四期：永久加算与预约事件接口

- 设计原件在[框架维护约定](../../03_再刷重制_Godot/00_设计/框架维护约定.md)“状态效果第三／四期接口”；本批只交设计，没有新增第三／四期运行时或翻译完成度。
- 永久加算项归battler、actor只存原始数组、XState负责存取；旧Godot档缺省0、预览隔离、外层资源／结果槽、KRZ热缓存和178持剑差值均列入闭环。候选7状态、13块、31个真实addParam调用；1612移除读当前等级，1768条件仅目标HP<=0或isDead。完整mv_oracle矩阵尚未量测。
- 预约事件按覆盖单槽设计，解释器setup后清槽；1771是remove1770→2482→2479，实例临时槽不进普通档，不改FIFO或补OTB Action End。战斗与地图宿主时点先取最终链参照。
- 已静态核对冻结基础实现和7状态原文，不把候选数冒称最终活跃块。actor.gd／XState／resource_context.gd现已明确交接，但实现仍等本批合main；第四期宿主文件须另行交接。108奈叶归悟空，2e的TP测量WIP不在本批。

## 交接板与下一步（由总装并入）

- 本批验收完成后标可合并；总装合本分支即包含2b～2d与设计，工具会一并归并三个前期交付单。不要重复合旧分支；待Claude核查整批实现、F31测试夹具和伤害入口冲突处理。
- 本批未合main前不进入2e或第三期。合入后期二回state-effects-2b树续2e；第三期actor／XState／resource_context虽已明确交接，仍按brief先交2e后开新期。
- 需要用户决定：无。原版报错／无效块仍留js，OTB Action End不补，未支持边界不自动修成有效效果。
- 进度账：本批不自记完成度增量，留Claude交叉核查。

## 本分支关键检查点

- 2b ad7c867、2c 4760a54，2d与原设计已在本分支祖先中；本次整批重交不需切回旧分支。
- 47cec33完整原版开场证据；3953920收窄为仅安排533；98c7f92记录组合前560项通过。
- aaa45557合hajimi并保留统一伤害结算与battleRound；1604f0ee额度到线WIP停手；63e9db8恢复并核实首次正式同步；e37d5660合dev.132～134；4e7bb95登记最终验收。
- 上轮combined-acceptance.log的143是额度停手时主动终止等待组，未运行组合专项，不是测试失败或偶发。本轮用新日志final-validation.log，不覆盖旧记录。
