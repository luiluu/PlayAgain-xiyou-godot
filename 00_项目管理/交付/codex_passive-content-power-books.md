# 交付：codex/passive-content-power-books

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_71）
- 状态：进行中（核心草稿与专项已提交，尚未验收）
- 基线：1132e919；前期stateOrigin最终b91b1a14、特殊react最终1132e919均独立可合并待Claude，不重跑旧验收。

## 本小期范围

- 权能五本1654／1656／1674／1683／1718：学习上限、普通遗忘保护、专用付费遗忘入口、静态效果。先原版宿主冒烟与矩阵，不能只读代码改规则。
- 已定位冻结源installNativeHonghuangRuntime.js 80～123：CodexHonghuang.powerClass优先CodexZones，超强3／强4／弱6；Game_Actor.learnSkill、forgetSkill与Game_Action.testItemEffect／itemEffectLearnSkill共同守卫。专用forgetLearnedPower消费3044遗忘符，不返书。新局free迁移名单为空；不移植MV旧档整理。
- 普通被动248效果与90科技静态链已交，不重做。旧首轮343参照因权能无法普通遗忘而污染，本期每例newGame，独立文件不覆盖旧证据。
- 已设计并接核心actor.gd草稿，尚未接道具页拒收提示与3044遗忘UI。容量满变量9返书／预约1317、PREE／ASUP、WPNM／SkEType、race-battle仍按后续顺序。
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

- 修正后native2已done exit0（230ad4b5e5b342ef86d4f70a7b6f3157），8唯一ID、errors空；真实class／limit为106超强3、1强4、2弱6，各次书籍是否可学逐项吻合。已独立保存power_books_corrected8.json并复制fixture，旧重复原件保留。接着跑45例边界与六例菜单流程，仍未宣称Godot已验。

- 新增xiyou_power_books八例专项，按原版每步比较类／上限／技能表／注册表、能力值、附加与特殊参数、元素、TP、追加行动、遗忘符和各接口原因。使用真实battle.apply效果43、actor.learn／forget与独立付费接口，未用观测器代替规则执行。开始导入后先跑本专项，未通过前不加UI范围。

## 沙僧70→71（同树上下文接力，本轮继续）

- 用户已说“继续”，额度已恢复：本轮开工五小时39%、周6%，非额度停手。按既定同工作树自动上下文接力创建71后70停止，71唯一后续执行者。先实查额度，五小时95%才WIP保存并停、周98%收尾；设计／疑难high，有真实接口才称机械步骤切medium。
- 所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用此树，当前分支codex/passive-content-power-books，HEAD以本节提交为准；不在main写、不创建／清理worktree、不reset／cherry-pick、不建automation、不向唐僧或其他已有会话发消息；共用登记只读，只写自己交付单。保留全部.sandbox、失败／不完整采样、generated与整树。
- 本轮已做：b69077e4恢复；fd7a24db设计与45例边界probe；ed8000d7六例菜单probe与CodexParamRate位置；1cb3dfd3核心草稿；9bd227a9有效修正8例fixture；afd8ed85八例Godot专项。全部待Claude，不自销核、不自评进度。前期stateOrigin／react与69两期均独立可合并，不重做；旧确定性8个early_inventory_rule继承失败仍保留不夹带修复。
- 原版修正后8例task230ad4b5e5b342ef86d4f70a7b6f3157已done exit0；唯一ID／errors空／实际类与上限逐项已核：106超强3、1强4、2弱6。原件.sandbox/power_books_corrected8.json与tests/fixtures/power_books_oracle.json字节相等。原始重复8例另存power_books_initial_duplicate.json及源码，不复用为完整参照。共享源generated五本道具和3044均已存在，无切片变化。
- **在途三任务勿重复启动**（交接写入时等共用四槽）：boss70-power-boundary.log（45例独立probe）、boss70-power-menu.log（6例原版openPowerForget菜单回调流）、boss70-power-import.log（Godot导入）。日志／status都在03_再刷重制_Godot/04_验证/本地结果/，用等待任务.sh --timeout45逐个看终态；期间不绕槽、不加上限、不杀别人。native2成功临时日志尚未清，证据已固化后可清自己的成功临时输出；所有失败与.sandbox不删。
- 核心文件modes/xiyou/core/power_books.gd新增XPowerBooks，actor.gd只改learn_skill／forget_skill／param_rate三个挂点。普通forget只保护XState.current.actors里的正式实例，clone仍能遗忘；付费forget_paid(s,a,id)直接擦该技能并扣3044、刷新，不用全局permit；没有旧MV迁移。CodexParamRate按已学技能标签求和，乘进param_rate；原版位置installNativeEconomyRuntime.js 55～70，别改成最终param再乘。**尚未导入或验收，不称实现完成**。
- tests/xiyou_power_books.gd／tscn是八例专项，使用真实battle.apply、actor.learn／forget、付费接口，逐步比较静态属性和原因；导入若exit0仍查Script／Parse／Compile错误。先跑八例再扩45例与菜单。导入会生自己的core与专项UID，只收本车道UID；若又生xiyou_battle_common_events.gd.uid移存.sandbox独立名，勿夹带。
- 45例probe：三角色×三个学习宿主apply／直接learn／直接itemEffect×五本循环顺序，普通forget保护与clone例外、缺符、付费与重复付费、腾位再学。clone用JsonEx.makeDeepCopy，若宿主失败按报错定位，不随意stub结算。6例menu probe观察CodexYunshang.choose数据边界，执行真实H.openPowerForget回调与paid规则，覆盖两种确认取消、成功、符被移走、无权能；不声称它等于截图。
- UI设计尚未落代码：新增独立XChoiceWindow子页（不改共用choice_window），按角色→技能→确认→结果，原item_scene暂停输入，关闭回列表；3044本身scope0/occasion2/consumablefalse，拦截_use_direct入口；原版itemUse入口installNativeHonghuangRuntime.js 138～148。权能使用前_effective与_use统一调用learn_reason，避免拒收仍扣书，并显示原版理由。先读menu原件真实行文，再接UI；改界面必跑event_compare且取原版／Godot成对截图及运行时读数。复用XChoiceWindow、XOrbShop.wrap_info，几何与原版同源；新截图脚本可复用ui_reference既有只读服务与原版截图流程，不动工具车道文件。
- 收尾跑新专项、普通被动338例、Actor/导入/技能/属性／Boss等直接依赖；无切片则不强加难度1必跑，但总装合并影响面选测仍由总装做。原检查.sh文档／JSON／链接／编号块、node --check、MV守卫16／16、git diff --check；精简证据入Git后清自己成功临时输出。当前只是WIP，未跑本轮验收，别将前期全绿套到新核心。
- 后续顺序不变：权能五本完整交付→容量满变量9返书／预约1317→PREE／ASUP→WPNM／SkEType与race-battle等八戒接口→都完且额度足才核他人；formula_execution／mv_event_core不在交接改动范围，set仍unsupported。更早限制与依赖链见本单前节及69→70全文。

## 沙僧71接手（2026-10-26）

- 同树上下文接力；HEAD 5a895af1、工作区干净。实查五小时52%、周8%，继续当前权能小期。三项原任务仍在运行，边界已推进到弱者组；不重复启动、不绕共用槽。共用登记只读，提交全部待Claude。
