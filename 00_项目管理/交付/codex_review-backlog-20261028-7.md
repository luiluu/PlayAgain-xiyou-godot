# 交付：codex/review-backlog-20261028-7

- 车道／工作者：核查／重制_沙僧_86（Codex）
- 状态：WIP，用户要求停工等待额度reset；第七期未最终交付，勿整条合并
- 正在做什么：审Claude武器解放、工具补漏及剩余文档登记；第六期已提交推送，四批待总装登记，不重核。
- 基准：dc8057c186702569d93f0213d702dd52e4442b71；固定基准，不追新合并。
- 范围：武器解放28a6c7ab／16f67bd6、工具补漏dc8057c1；文档登记以pending-start.json逐批排除Codex提交后限定。
- 只审不修；问题只记交总装派Claude修，不自核。沿用原工作树，旧62份证据及所有本地结果保留；不改共用交接板、编号、记录。
- 额度／接力：五小时95%、周90%收尾停手；上下文40%保存并接续。本次开工五小时0%、周10%。

## 需要总装决定

- 详见[第七期检查点报告](../核查报告_20261028_清积压第七期.md)：工具两项P2已隔离复现；仓库提案与地图盘点保留，武器强制行动待运行对照。

## 验证

- 工具组合套件168/168；导入与原版重采正在共用队列等资源；11批文档／Claude登记操作限定结论已保存，尚非最终交付。

## 沙僧85→86接续（2026-10-28）

- 触发：实际会话输入194384／窗口475000＝40.9%，达到40%同工作树接续线。末查五小时59%、周19%，未到95%／90%停手线；没有使用额度重置。新会话重制_沙僧_86，实际文件命令必须显式workdir为原state-effects-2b，UI关联项目根目录不代表文件工作区。
- 当前分支codex/review-backlog-20261028-7，固定代码基准dc8057c186702569d93f0213d702dd52e4442b71；不切新树、不reset/cherry-pick、不接管main、不改共用文件、不建PR。第六期f17c2bba已补推且远端一致，四批尚待总装登记；第五期六批已实际登记。
- 第七期已保存WIP报告：工具168/168、rc0（含增量，勿重复全套）；T1/T2两个P2隔离真复现，T3两条P3边界。仓库提案Q1/Q2 P2与Q3 P3、盘点D1 P2及周额度文档D2 P3已记录。武器W1源码链已确认，真实强制行动对照尚未运行，不能写实测通过。
- 11批文档／Claude登记操作限定结论已整理，覆盖13个Claude提交：ce61e84、4c385c3、7881bd3、464bd21、e73a4d5、552059c、5a343fb、9182dcb、9b18739、a5ae028、8021263、e615419、90f7c87。两个Claude复核Codex产品的原报告不在本期覆盖；仓库提案、错误地图盘点和两个代码问题批保留。尚未做最终限定销账模拟，不称已登记。
- 在途任务（长任务包装器已脱离会话，不杀不重启）：review-backlog-20261028-7/prepare.log（补齐，转换完成，Godot导入在共用槽排队）；native-weapon.log（正式weapon_unleash_probe参照重采，在共用槽排队）。读.status.json和tail即可；不是卡死，不动其他车道进程。原转换前后9项issues逐项相同，不能写空。generated-before7保留原整份生成数据，旧62文件原件仍在。
- 接下来：等prepare退出0后按影响面一次跑weapon_unleash、attack_query、action_sequence、item_use、determinism、random_streams、troop_events、battle_events、combat等相关专项（不跑全量）；等native-weapon结束后保存.sandbox/weapon_unleash.json到本期证据，与generated/oracle/weapon_unleash.json逐字比sourceIdentity和cases。
- W1诊断现成：mv_oracle/.sandbox/review7_weapon_forced.cjs（通过真实forceAction/processForcedAction/startAction，只写自己的.sandbox/review7_weapon_forced.json）；Godot .godot/review7_weapon_forced.tscn正常场景启动，结果写.godot/review7_weapon_forced.json。只运行ignored诊断，别改实现/正式测试。都用占槽.py和长任务.py；预期无状态两端技能127／1次，眩晕29原版技能1／0次、Godot可能127／1次，以实测为准。
- 收口第七期：把运行结果补报告，正式生产解析拟登记条目、模拟只销上述Claude13提交并查unsafeRemoved；跑本分支文档选测--affected dc8057c1 --oracle，保留全部失败，再提交推送核远端SHA。第七期没有最终交付前勿合。
- 已并行准备第八期源码（全部只读，不切分支）：content-agent三批reach106／115／109；ce-agent审ce-fix2和G1；tools-agent审nezha-merge-speed／slice-affected／floor-narrow。其检查点位于review-backlog-20261028-8/{content-agent,ce-agent,tools-agent}/checkpoint.md。先读检查点提纲继续未完验证，不重读已审大差异或重复168工具套件。子代理已通知收尾保存，不再派新活；新会话读文件即可，不依赖旧代理上下文。
- 原授权继续清积压，不要每期结束停下来等Kyo再说继续；遇问题只记交Claude，总装登记后再核修复。到40%自动接下个序号，同树保存证据；到额度线真实收尾停手。

## 沙僧86进行中

- 已同树接手；tracked开工干净，旧证据全部保留。开工额度五小时68%、周21%，未使用重置。
- prepare已done/0；正式原版武器重采86例，stdout errors=[]；重采sourceIdentity与cases分别完全等于当前generated，保存native-weapon-unleash.json与native-weapon-comparison.json。
- 相关11场专项和两个独立强制行动诊断在运行／共用槽排队。Godot诊断首次排队时为补隔离HOME主动停止，仅重启自己的诊断到forced-godot-isolated.log；保留原日志与终态。
- 生产待核查解析器的内存限定登记模拟已结束：只移除预定13个Claude提交，unsafeRemoved=[]、notRemoved=[]；全部角色待审批63→54，混合批的Codex提交仍保留。尚未实际登记。
- 第八期floor-narrow候选已用生产select与未改动的两份真实测试完整隔离复现：只改keepEvents图32／4时，分别漏选unknown160／floor30_seeker；full=false。证据在第八期tools-agent/floor-selection-counterexample.json；本车道只记不修。

## 沙僧86停工现场（用户2026-10-28明确要求等待额度reset）

- 已停止新核查；没有使用额度重置。最后额度实查五小时89%、周24%；本次按用户要求提前停工，不等95%线。
- 第七期正式专项已done/0：11场18428/18428，完整逐场TEST_RESULT及无SCRIPT ERROR／ERROR／FAIL验证已保存specialty-summary.json。正式原版武器86例重采与generated的sourceIdentity／cases完全相同。
- W1仍未完整取证，不按确证批准或销账：原版首轮夹具因延迟状态缓存失败，第二版补真实refresh；Godot首轮随机磁带类型不匹配失败，第二版混合缩进解析失败，第三版统一空格准备好。各版原件和失败日志均在本期diagnostic-sources及对应日志；没有改实现或正式tests。
- 用户停工时，仅向自己的forced-native-v2、forced-godot-v3、以及第八期autosave-disk三个仍在排队的长任务包装器发停止信号；没有动其他车道进程。终态与stopRequested记录保留在user-stop-20261028.json及各.status.json。恢复时先读终态，确认旧进程已退出，再用新日志名接续，不能覆盖首轮。
- 第七期文档13提交的生产限定销账模拟通过，unsafeRemoved=[]、notRemoved=[]；尚未实际登记。13c34861检查点已推github并核远端同SHA。本次停工提交继续保留WIP，勿把整条当最终可合并。
- 第八期：15场专项1434/1434、done/0，specialty-summary.json逐场汇总；七图剔转换meta后逐项等于冻结源，content-agent/map-identity-review86.json。F1／P2已用完整198图固定切片及两份未改真实专项复现，见tools-agent/floor-selection-real-slice-counterexample.json；只改图32或4的keepEvents会分别漏unknown160／floor30_seeker，full=false。
- 第八期六批／45个Claude提交的候选限定登记生产模拟通过，unsafeRemoved=[]、notRemoved=[]，floorNarrowRetained=true；这是草案，自动存档落盘诊断尚未跑完，不当最终交付。draft-report.md、proposed-registration.md、registration-simulation.json及三个代理checkpoint.md均在第八期证据根。
- 恢复顺序：先核三个被停任务终态；用新日志运行第七期native v2与Godot v3独立强制行动对照，及第八期review8_autosave_disk正常场景（隔离HOME、占槽、长任务）；不重复已通过11／15场与168／45／10工具套件。补报告、最终文档选测、限定生产销账模拟与交付单解析，提交推送核远端，再继续后续可核积压。
