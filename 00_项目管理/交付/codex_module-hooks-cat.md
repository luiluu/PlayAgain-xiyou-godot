# 交付：codex/module-hooks-cat

- 车道／工作者：伤害模块·Codex（沙僧）
- 状态：可合并
- 工作树：`.claude/worktrees/module-hooks-cat`；全部待Claude交叉核查。
- 前置：codex/module-hooks（a8fcb0d）先合，再合本补丁。该已交付分支不追加提交。本补丁已合main的5d6c7b8以保留review_fix新增6例；这些main变更不是本车道新实现。
- 总装合并后统一`检查.sh --oracle`、登记开发编号与推送；车道只跑相关专项。没有写共用交接板／变更记录／版本／进度账。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】架构13首个生产用例：哈基米伤害模块（dev.待定）

- 新增`core/cat_damage_hooks.gd`，实现冻结CodexCat 1.0.1的cat-sword enter／build；standard固定登记cat-sword与orb-sets，源次序18／19／39。直接消费首期数值帧，无第二套持剑算术、无临时改写真实passiveCache。
- 实装持剑技10437～10440／10445的普通与物理／神圣加成、剑心最终／暴击加成、进阶结算倍率，以及抱剑护身三重上界、巨龙1999自然回合护甲窗口。进阶判定读取角色基础已有XCat.advanced；悟空首期该getter恒false，本补丁没有擅自开启进阶。
- 注册表在伤害宿主构造Cat值快照：原始已学技能、主武器类型、目标速度和显式battleRound。只有基础cat.gd及actor.stat_equips同时存在才启用；未合角色基础时明确禁用。handler只收到递归冻结值，不持有battler／角色模块／随机流。显式moduleFacts.cat供影子快照和重播调用；宝珠事实仍归原边界。
- 已按悟空提案交付真实生产处理器，不再将数值实现留给角色车道。此条取代上一交付单“Cat只为测试适配器／请悟空实现handler”的临时接入说明；不修改悟空cat.gd／actor.gd。
- 原版探针从27增至30例，补目标速度6000的第三上界和巨龙4／9回合；保留原27例逐条完全相等。模块测试改为调用生产descriptor，补默认XDamage入口自动抓取真实基础getter、显式快照一致、重复计算与资源／装备不变。
- 设计原件继续维护[框架维护约定](../../03_再刷重制_Godot/00_设计/框架维护约定.md)第13项，不另存相同设计。

## 验证

- 正式同步`sync.log`退出0：44组中复用40、重测4组（module_hooks、formula_program、formula_equipment、review_fix）；来源issues=[]，changedInputs／changedMaps为空，除新增module_hooks参照外既有测量无变化，review_fix现有38例保留。30例原版errors=[]。
- `stamp-and-additions.json`核实：旧27例完全不变，新3例只增；toolsDigest与全部generated输出摘要都等于sync_stamp.json。合并后转换工具若同时纳入哈基米公式等其他改动，摘要自然不同，须按总装正常同步，不能强行借本车道指纹。
- 本分支6个相关专项全部通过，无偶发：module_hooks 1304、orbs 63、attack_element 66、shield 565、state_effects 60、imported_balance 273，合计2331/2331；原始日志`scenes.log`及`scenes/`。首期框架的13场景48187项证据仍见上一交付，不重复计数。
- 与claude/wukong-hajimi **23d47144e4e8b3b43502f8180b5fd6fc294d52ef**做独立合并态运行；组合树906ce52，加默认入口测试后52ba1fe。4场景全部通过，无偶发：module_hooks **1310**、cat **622**、orbs **63**、attack_element **66**，合计2061/2061。默认入口已验证基础模块存在时自动派发生产Cat钩子。证据`integration-identity.txt`、`integration.log`及`integration-scenes/`；未向悟空工作树写入、未将其角色实现合入本交付分支。
- 与状态第三／四期设计分支的merge-tree预演无冲突。组合运行验证不代替Claude交叉核查或总装整轮检查。

## 后续接入／边界

- 普通剑技不需回合参数；巨龙1999必须由试炼／战斗宿主显式给`options.battleRound`自然回合（0按源视为1），4／9回合开放，其余保护。缺失时返回unavailable＋`cat_dragon_round_missing`，不能用猜测回合长期套减伤。试炼尚未开放，角色车道接宿主时一并传入。
- CAT BEGIN／CAT STRIKE的剑技连携、段数／标记／剑心层数消费、费用／命中／反射时点和试炼开放仍归角色车道。本批只完成伤害数值钩子，不能据此宣称剑技已有伤害段或178整体完成。
- damage.after／split／其他宿主挂点和战斗日志／完整replay接线仍按首期明确pending。资源操作继续归XResourceContext，未新增扣资源或抽随机能力。
- 回退本补丁后恢复首期“宝珠生产表＋Cat测试适配器”的状态；首期本身回退按其交付单恢复旧宝珠入口。没有读写真实玩家存档，mv_oracle文件系统守卫未改。
- 插队完成后已返回状态效果：`codex/state-effects-3-design`（1ff5c0c）另交第三／四期接口，可合并但不含运行时支持。第三期需要actor／XState／resource_context完整交接；按2d约定不越界、不用孤立字段记完成、不强推第五期。原2e TP测量WIP与原工作树保留。
- 无需用户决定。生产数值钩子已可合并，进度仍由总装按核查结果登记。

## 同步与临时集成记录

- `parent-reference.log`借首期产物时曾退出2：首期review_fix只有32例，本分支已有38例；原只增检查正确拒绝删除6例。随后合最新main并刷新参照，以正常同步通过，未放松比较或改旧参照。
- `fair_sync.py`／`fair_tests.py`只在本地证据目录调用原同步器／原测试器，使用原file_lock阻塞等同一个slots/0.lock，本车道并发1、共用上限仍4；不改探针／比较／缓存校验／临时HOME隔离／文件守卫，不停其他车道进程。全部正式任务正常结束。
- 大型证据保存在本工作树`03_再刷重制_Godot/04_验证/本地结果/module-hooks-cat/`，不入Git；临时合并态worktree验证后移除，身份与日志保留。
