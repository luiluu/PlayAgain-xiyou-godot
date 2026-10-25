# 交付：codex/passive-content-boss-sequence

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_69）
- 状态：可合并（专项已验，待Claude交叉核查；继承确定性失败见下）
- 基线：e1925bea（Boss行动资源域129例＋五场41838项已独立交付待Claude）。同树续接，不在main写，不重采前期原版，不丢.sandbox／generated，不清工作树。


## 最终交付（2026-10-26）

- 行为：Boss数值HP／MP行动序列按每条命令实际make_targets列表放大非自身损失一次；复用资源gain的护盾、setter、刷新与结果槽语义。独立资源槽、嵌套共享本战斗Boss域，命令退出恢复；空列表遮蔽外层来源域；无来源敌群事件与TP沿原路径。
- 补齐有原版参照的ENEMY／ACTOR索引与FIRST规则选择器；不一次扩所有未采的选择器。每次资源操作清理旧slots，避免跨数值命令发布过时结果，交错原版确认MP伤害8保留为8。
- 原版：87例完整＋交错1例＝88唯一ID，errors空、来源一致；保留两原件及combined88，夹具逐对象等于原件并集。精简证据见[Boss数值行动序列专项](../核查范围/Boss数值行动序列专项_20261026.json)。独立探针未加入同步PROBES，不覆盖既有原件或重采旧78／129组。
- 最终验证：boss69-sequence-final3（5db85d0042fe4933a9deb3fb156df054）exit0，10场50671／50671（新增8315、action_sequence115、Boss普通3823／域16621、formula908、状态19949／TP537、导入273、敌群108、公共事件22），均单次通过、无偶发、无SCRIPT ERROR／ERROR。运行时最终83fc68f4，UID72b69b64后未改运行时代码。导入exit0、仅收本专项UID。
- **继承失败**：此前本期11场批次的xiyou_determinism为374／382，8个early_inventory_rule稳定失败；隔离e1925bea基线同374／382且失败行逐条相等，无Script错误。快照929个基线已跟踪文件逐字节等于e1925bea后固化为副本，generated仅共享且记录manifest SHA。不是偶发，不将11场写成全过，不夹带无关掉落／测试修复。最后slots小修后验证10场；不声称最终版本的确定性场景已通过。
- 限制：通用EVAL宿主未移植，空targets的FIRST原版异常行为未声明对齐；其他选择器暂为空表，不扩已采范围。stateOrigin、1341／2550反应来源下一期另取参照，尚未开始。本期没有完整战斗预览／两块TP Apply或敌人永久账本的新结论。
- 合并：依赖e1925bea（上一独立交付）；同树分支codex/passive-content-boss-sequence。共用交接板／变更记录／步骤清单／当前状态未改。全部本车道提交待Claude核查，不自销核、不自评进度。总装按战斗规则影响面选测；基线确定性遗留请登记并派测试／掉落车道归因，精简证据与失败原件均在。
- 清理：精简证据入Git后只清本车道成功临时输出；所有失败日志、所有.sandbox、generated与整树保留。文档／JSON／链接／编号、node语法、MV守卫16项与差异格式在最后编辑后复跑。

## 本小期范围

- 先做行动序列HP／MP数值修改：processActionSequence正常分派与actionHpModify／actionMpModify直接入口，覆盖目标列表覆盖、重复目标、自身代价、无目标、非Boss／无霸体与护盾。
- 先用新增原版探针冒烟，再扩矩阵；不修改冻结源或替换原版数值／上下文方法。状态来源、1341／2550另采，不混本小期；序列通用EVAL脚本宿主仍未移植，不能以域回放冒充宿主可用。
- 预设计：XBossOutputContext帧增加显式targets列表；数值命令按make_targets得到的实际列表推域，不能复用序列原_targets或BattleManager残留_subject猜来源。normal／诊断返回成对恢复。
- 资源接口设计待原版参照：优先复用已有XResourceContext.gain与刷新／结果槽语义，保留sequence_gain无显式来源的调用边界，避免把敌群事件资源变动误算成Boss输出。先核对导入平衡与Boss的包装先后，再接线。

## 验证与待核查

- 先采冒烟原版，再扩矩阵；运行时有改动后跑新增专项、xiyou_action_sequence及Boss资源域／普通输出／公式／状态效果等直接依赖。无切片／界面变更，不新增三级必跑项，不跑旧全量。
- 全部本车道提交执行者Codex（沙僧），待Claude交叉核查；不自销核、不自评完成度。共用交接板／变更记录／步骤清单／当前状态只读。
- 五小时额度58%、周54%，按95%停手和上下文40%同树接力。

## 可优化

- 已做：分入口拆小期，先交已验的129例资源域，再接序列数值入口；先冒烟验证宿主，完整参照一次采齐。新增参照用独立文件名，避免覆盖已交原件。

- 原版冒烟boss69-sequence-smoke（f9621a9f588743648e2286b77c0ae3d1）3／3 errors空，覆盖direct HP、process MP和致死链；宿主无需额外修补。扩矩阵前把实际出战角色也纳入快照与初始化，确保ACTORS／ACTOR 0选择器命中的对象有数值对照。

- 69运行时接线草稿：Boss域新增targets列表帧；XActionSequence持有独立resources，每条_modify按解析后的列表推域／退出，sequence_gain有resources时clearResult→复用gain→publish，返回结果槽的显示值。原无resources调用路径保留，敌群事件不借来源。Boss>1只来自敌人、导入倍率<1只来自角色，两者不同时生效；现有导入减伤顺序保留。尚待完整原版与Godot验收，不报可合并。

- 原版完整boss69-sequence-full（2a09c4d4c2054d06bcc97a25e1c341f4）87／87 errors空，含实际三位出战对象；独立原件.sandbox/boss_sequence.json已复制为fixture且逐对象一致。新增专项比较解析目标、所有已观察单位的前后资源／护盾／dirty／结果槽、退出后的域外gain，并检查列表域嵌套／空域遮蔽与敌群事件无来源；Godot验收待跑。

- 首轮Godot boss69-sequence-godot exit1，8213项中42项失败，全部定位到原规则make_targets缺ENEMY 1／ACTOR 0／FIRST（对应三组HP／MP）；非倍率或护盾差异，未归偶发、未盲重跑。按新增87例原版补这三种已采选择器，保留首败日志，不把画面选择器全部扩到规则侧。

- 第二轮boss69-sequence-final exit1：9场通过；序列仍8项失败，确认为新增索引选择器错误读取XActor不存在的hidden，已改仅敌人检查hidden；日志含SCRIPT ERROR已判失败。另xiyou_determinism稳定8个early_inventory_rule失败（首跑／自动重跑同样），尚未归因；不称偶发。下一步用本树.sandbox内只读链接快照、仅三文件取e1925bea原版本跑相同场景，区分本期回归与继承失败；不reset／改当前运行时／建新worktree。

- boss69-sequence-final2终态exit0，10场50569／50569（新增8213、action_sequence115、事件108／22、导入273、既有Boss／公式／状态链），均单次且无SCRIPT ERROR；确定性隔离基线boss69-determinism-baseline同为374／382，8个early_inventory_rule与本期一致，证明继承失败，保留原件与快照不夹带无关修复。另发现同一序列resources跨命令保留slots可能在数值→普通MP伤害→另一目标数值时publish旧目标槽，追加单个interleaved原版样本，不重采87例。

- 追加interleaved原版1例通过（4f6e98727f6e49ceb0b9a02fb1f54dcb），与87原件来源一致、合成88唯一ID并保留两原件。Godot旧实现实测8312／8315，三处结果槽确实把普通MP伤害8回写成0；已在每次数值gain开始清理该序列resources的旧slots后seed目标，publish仅本次操作所触及对象。TP继续原路径，不扩本期未采的TP资源语义。相关10场需按最终版本再跑。

- boss69-sequence-import exit0且无SCRIPT ERROR／ERROR／Parse／Compile Error；新增xiyou_boss_sequence UID已生成，顺带非车道xiyou_battle_common_events.gd.uid移存.sandbox/boss69_unrelated_import_uid.txt，未夹带。下一步最终88例＋九依赖，不重复已确认的确定性基线失败。
