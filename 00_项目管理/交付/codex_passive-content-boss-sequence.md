# 交付：codex/passive-content-boss-sequence

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_69）
- 状态：进行中
- 基线：e1925bea（Boss行动资源域129例＋五场41838项已独立交付待Claude）。同树续接，不在main写，不重采前期原版，不丢.sandbox／generated，不清工作树。

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
