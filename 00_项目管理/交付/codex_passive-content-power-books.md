# 交付：codex/passive-content-power-books

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_70）
- 状态：进行中（已恢复；参照阶段，尚未修改Godot运行时）
- 基线：1132e919；前期stateOrigin最终b91b1a14、特殊react最终1132e919均独立可合并待Claude，不重跑旧验收。

## 本小期范围

- 权能五本1654／1656／1674／1683／1718：学习上限、普通遗忘保护、专用付费遗忘入口、静态效果。先原版宿主冒烟与矩阵，不能只读代码改规则。
- 已定位冻结源installNativeHonghuangRuntime.js 80～123：CodexHonghuang.powerClass优先CodexZones，超强3／强4／弱6；Game_Actor.learnSkill、forgetSkill与Game_Action.testItemEffect／itemEffectLearnSkill共同守卫。专用forgetLearnedPower消费3044遗忘符，不返书。新局free迁移名单为空；不移植MV旧档整理。
- 普通被动248效果与90科技静态链已交，不重做。旧首轮343参照因权能无法普通遗忘而污染，本期每例newGame，独立文件不覆盖旧证据。
- 尚未设计／修改actor.gd、道具使用或UI入口。容量满变量9返书／预约1317、PREE／ASUP、WPNM／SkEType、race-battle仍按后续顺序。
- 共享登记只读，保留所有.sandbox／generated和工作树；全部提交待Claude，不自销核、不自评完成度。

## 可优化

- 已做：每例新局隔离权能污染；先验证学会→普通遗忘被拒→缺符失败→付费遗忘的真实宿主链，再扩容量矩阵，避免重复大采样。

- 原版冒烟五本5／5 errors空（2b43a6bb9e78467889c6959d43f8861c）。已逐项核对学会、重复不可用、普通遗忘被拒、缺3044失败、付费遗忘成功且消费1枚；每例fresh newGame，无前期污染。下一步扩真实类别学习上限三组，不添加合成第六本来伪称弱者容量触顶已验。

## 沙僧70收尾／下次续接（2026-10-26）

- 实查五小时95%、周60%，按用户规则WIP保存并停，不自动建新会话继续消耗。当前分支codex/passive-content-power-books；同一worktree仅此执行者，所有在途长任务均已done。所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b；不在main写、不创建／清理worktree、不reset／cherry-pick、不建automation、不向其他已有会话发消息。共用四槽，不绕槽、不动工具车道文件。
- 本轮新增两期均已独立可合并：stateOrigin最终b91b1a14（运行时d3fee911、121原版、70956／70956）；特殊react最终1132e919（运行时86f3c8f1、72原版、80303／80303、十场单次无Script错误／无偶发）。两份交付单／精简证据在，全部待Claude交叉核查；不重采旧参照、不重跑旧验收。前期69交付两期和确定性8项early_inventory_rule继承失败见[序列交付单](codex_passive-content-boss-sequence.md)，不夹带无关修复。
- 当前权能五本冒烟5例有效，真实learn／repeat／ordinary-forget／missing-token／paid-forget链已核，原件power_books_smoke.json。首个完整采样47176071312442e5853e16624530bd84虽exit0、8例errors空，但名单误写[106,1,1]，只有7唯一ID、两组强者且漏弱者，**不称完整矩阵通过**。已另存.sandbox/power_books_initial_duplicate.json和原始probe源码，初次完整日志保留。
- 冻结CodexZones.classOf实际优先Boss列表，角色1为强者；actor2不在超强／强列表中，应为弱者。已把probe后续名单改成[106,1,2]，**修正后尚未运行**，下次先跑它并确认唯一ID／实际class／limit，不能把旧8例复制成完整fixture。参照进展见[权能书参照进展](../核查范围/权能书参照进展_20261026.json)。目前没有权能Godot夹具／专项／实现，不称可合并。
- 后续容量覆盖还要扩：重复学会、满容量拒收、专用遗忘后再学／反复取消或缺符等；现有真实权能仅五本，弱者上限6不能靠合成第六本道具冒称真实触顶已验。每例newGame防普通forget保护导致污染。3044付费入口会影响UI，先设计再接，改UI须三级必跑event_compare；改切片则必跑规则难度1四段。旧MV迁移整理不移植。
- 长期顺序仍为：完成权能五本→容量满变量9返书／预约1317→PREE／ASUP→WPNM／SkEType与race-battle等八戒接口→全部完成且额度足才核他人。两块TP Apply／完整预览空槽、敌人永久账本仍未做；formula_execution.gd／mv_event_core不在本期范围，set公式仍unsupported。
- 下次先实查额度，95%仍不继续；设计／疑难用high，有真实接口才称机械收尾切medium。长批python3 -u、XIYOU_TEST_HEARTBEAT=30、长任务.py start＋等待任务.sh --timeout45。保留全部.sandbox、失败／不完整采样、generated与整树；仅精简证据入Git后清自己成功临时输出。

- 清理：有效冒烟的精简进展与原件已固化，本车道成功冒烟临时输出5路径已清；不完整全采样日志与全部.sandbox／此前失败记录／generated保留。

## 本轮恢复（2026-10-26）

- 用户要求继续；实查五小时39%、周6%，工作区干净，HEAD c66e12eb。续做修正后的[106,1,2]原版矩阵，旧重复名单原件保留，不重跑已交两期。

### 接线设计草稿（本轮，尚未改运行时）

- 新核心XPowerBooks（独立文件）从物品CodexPower标签＋效果43建立稳定技能表，按冻结角色ID分档，提供learn_reason／can_learn／learned／forget_paid；actor.learn_skill负责所有学习入口的上限，actor.forget_skill只保护XState.current里的正式角色实例，克隆仍可普通遗忘（与原版canonical identity判定一致）。专用付费接口原子地删技能、扣3044、刷新被动与资源，不留跨调用permit旗标。
- 物品效果43复用actor.learn_skill守卫；物品页_effective及_use前的权能原因提示复用同一核心，防被拒后仍消耗本道具。3044在物品页使用入口打开独立XChoiceWindow子页，复用已移植的CodexYunshang.choose布局；原页暂停输入，结束后回物品列表。按原版走角色→技能→确认→结果，取消不扣符，不返权能书。先取原版各页实际行文与流程参照再接UI；不改共用choice_window。
- 追加独立power_books_boundary_probe.cjs入口（尚未运行），45例＝三个角色类别×三个学习宿主（apply／直接learn／直接itemEffect）×五本循环顺序；覆盖不同书在容量边界被拒、普通遗忘保护与克隆例外、缺符、成功／重复付费遗忘、腾位后学习。不覆盖MV旧存档整理，不合成第六本权能。
- 当前共用槽满，修正后的8例native2仍在排队，未绕槽或启动第二个重任务；先保存设计与后续探针。

- 又发现静态效果尚缺一条通用接线：原版installNativeEconomyRuntime.js 55～69把已学技能的CodexParamRate按参数求和，再乘进Game_Actor.paramRate（不是最终param之后再乘）。五本中7245／7246／7247分别加魔攻魔防／物攻物防／敏捷幸运50%。现有Godot actor.param_rate只乘装备套装，无该标签。应在param_rate按原顺序复用新核心的已学技能百分比解析，实际对照后再改；不去改XCat最终param包装顺序。
- 追加power_books_menu_probe.cjs独立菜单流程入口（尚未运行）：按原版openPowerForget捕获行文与回调，六例含角色页取消、两种确认取消、成功、确认前符被移走与全员无权能；不替换真实学习／遗忘规则，choice只在数据边界观察，不能冒充成对截图。

- 核心草稿已落盘：XPowerBooks新增注册表／类别限制／普通遗忘canonical保护／原子付费遗忘／CodexParamRate；actor.gd只加三个挂点（learn、forget、param_rate）。依据为五本有效冒烟与首轮有效的超强3／强4子样本及冻结原宿主；修正后三类完整参照仍等槽。尚未Godot导入／验收，不报可合并。尚未修改物品页，UI与效果入口的拒收提示待后续接线。
