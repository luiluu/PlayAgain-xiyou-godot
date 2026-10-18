# 交付：codex/formula-rng-design-20261018

- 车道／工作者：框架方案／沙僧（Codex；父会话统一登记名册）
- 工作树：`.claude/worktrees/formula-rng-design-20261018`
- 基准：main `07c2660`（dev.085）
- 独占文件：本交付单、`00_项目管理/协助预检_副作用公式与战斗随机数_20261018.md`、`00_项目管理/预检工具/公式与随机数预检_20261018.py`
- 状态：可合并（仅预检工具与设计文档；父会话统一全量检查后总装接收）

## 变更记录草稿

## 2026-10-18 【Codex·沙僧·未经Claude检验】协助计划12／14：副作用公式与独立战斗随机数框架方案

- 完整扫描冻结v0.28的10,453个技能／3,044个物品有效公式：31个自定义块、19份不同原文；其中3个资源副作用块、24个装备实例查询块、4个现已翻译只读块。另有5个普通护盾公式、1个type=0的潜在HP副作用语法；81个技能调用14种角色模块方法，未擅称纯函数。附所有块原文、明确使用者、楼层／可达性与44处随机语法命中。
- 方案由父会话并入框架维护约定「目标（待用户定案）」；本分支未实施游戏代码、未扩切片、未改参照探针、未更改开发编号与完成度。
- 验证：只读扫描可复跑、Python语法检查通过；完整 `检查.sh --oracle` 由父会话合并所有方案后统一运行。
- 未完成：用户仅同意出方案，实施需用户定案；后续完整行动结果／弹字／真实回合对照属于实施验收，现有48个净化之雷用例不冒充完成此项。

## 交接板

- 下一步：协助计划12、14的方案已交付，转「需要用户决定」；决定前不扩XCustomDamage特例，不把设计目标写成已实现。
- 用户试玩说明：本轮没有玩家可见行为变化。
- 需要用户决定：是否实施下面两项框架；默认建议按先12后14分批推进，每批保留旧路径与严格对照，未知语法继续显式待支持。净化之雷弹字首期按冻结MV结果槽兼容，不另加逐副作用弹字；更直观的净变化弹字另列优化。掉落抽定与规则流隔离不改变现掉落动画开时提前入包／逃跑留物行为。

## 供总装并入框架维护约定「目标（待用户定案）」的完整设计

以下是待定方案，合并后只在框架维护约定保留原件；本交付单按流程删除，预检报告只作为来源与审计证据。

### 12. 公式结构化程序与显式执行（待用户定案）

**边界与职责**：转换器负责受限JS语法识别与降低为结构化程序；`XFormulaProgram`负责局部值、只读上下文、短路控制流；`XBattleLogic`持有的执行上下文才允许资源写入。普通求值／AI／战力预览不拿真实battler引用或写入能力。停止新增按技能号／SHA分派的 `XCustomDamage`。SHA只用于来源漂移和程序缓存，程序支持由语法及能力白名单判断。

**转换产物 v1**：每个Skills／Items有效公式增加 `formulaProgram={version,source:{table,id,sha256,custom},status,capabilities,locals,steps,result}`。`status` 区分 `pure`、`effectful`、`unsupported`；`capabilities` 如 `read.battler`、`read.variables`、`read.equipment_instance_level`、`random.rule`、`write.hp/mp/tp`，不兼有隐式JS运行权限。`steps` 是**有序程序**，不是先把所有副作用排成表再算返回值；每条含op、源位置、表达式AST和接收者。支持的基本操作为局部声明／赋值、`value`赋值、受限if/else、只读表达式、`gain_resource(receiver,resource,amount)`。普通表达式的返回值和自定义块默认 `value=0` / 最终 `value` 规则分别保留；最终使用YEP的非负夹值与恢复类型sign规则。

**语法与拒绝**：首批词法／语法解析数值、布尔、null、a/b/user/target/subject别名（user/subject→a、target→b）、常量item.id、局部变量、已登记参数／只读方法、v/s只读下标、Math白名单、算术／比较／短路&&/||/!、三元与有限if/else。声明重复、var提升、声明先后要满足实际块语义，不能用正则把分号拆开后任意字符串替换。流程与操作设静态深度／节点上限，无循环、递归、原型、动态属性、任意函数、eval、网络、文件或任意全局。未知节点整体unsupported，给源位置＋原因；不把已执行一半的程序当supported。

装备等级24块不执行任意 `.filter`／箭头函数：解析其完整受限模式，规范化为白名单只读查询 `first_armor_instance_level(baseItemId, default=0)`，保持user.equips顺序、DataManager.isArmor、baseItemId、实例对象和level缺省语义，识别失败就unsupported。由 `XEquipmentView` 提供实例等级，适用于任意baseItemId和任意技能，不能写成1068专例。护盾5条先登记 `write.shield` 待能力模块接入，不因能读出末尾0便算已支持。81条Codex角色函数须注册独立、版本化只读/执行接口与上下文需求，未经模块参照不得默认准入通用程序。

**实战执行**：`logic.execute_formula(program, subject, target, action_context)`只在命中／闪避之后、冻结源求值位置执行。每次真实ACTION EFFECT／每个目标运行一次；源序列重复几次就运行几次，以命令ID／目标ID／作用序号保证日志重放不会再执行。局部表达式读取当前时点资源；遇gainHp/MP/TP立即调用统一资源mutator、按MV刷新夹值／阵亡／immortal／状态清除；随后语句读刷新后的值。这里首批只认已验证的无盾资源语义；冻结ShieldSystem.js的gainHp/setHp还会吸盾并对溢出扣量减伤，addShield含ShieldEffect加成。护盾能力接入时必须让同一mutator适配已安装的资源钩子链，避免公式绕开护盾或重复吸盾；未接入时不能宣称支持带盾资源写入。受限编译失败不开始运行；运行时异常按YEP返回0，已提交的前序资源写入保留并记诊断，不能悄悄回滚或继续后续语句。临时局部声明不写battler、不写全局。

**纯求值与预览**：`XDamage.eval_formula`恢复纯求值契约；只接 `FormulaReadContext`，effectful程序不能从该函数直接操作目标。实战执行返回 `FormulaOutcome{rawValue,sourceReads,randomTape,effectJournal,resultSlots,diagnostic}`，`XDamage.calculate`接已得到的rawValue，不能再隐式执行。AI/战力/帮助调用 `preview_formula`：对只读snapshot按同一引用图建影子资源状态（保留a==b、自目标与嵌套action共享引用，不能独立克隆a/b导致同一对象分裂）、使用固定期望random=.5或显式预览序列；可模拟程序步骤得出估计值，但不调用真实mutator、不发状态/弹字/事件、不改任何RNG游标、缓存或装备池。对未支持的副作用返回 `unavailable/reason`，不能冒充0伤害已支持。

`_mixed_weights`的有限差分也只能在独立影子态用同一randomTape重算，输入从同一个before snapshot开始，不能重复改真实目标。冻结源当前副作用3块均magical，无当前mixed副作用实例；未来遇 `effectful+mixed` 先unsupported并补oracle。若源真会重算副作用，是否保持该行为或修正须单独登记／用户决定，不能预先宣称影子重算对任意未来公式完全等价。

**行动结果与弹字**：资源mutator返回 `{receiver,resource,requestedDelta,actualDelta,before,after,addedStates,removedStates}`，按源语句顺序记入effectJournal；FormulaOutcome还保留MV ActionResult槽更新序列（hpAffected/hpDamage/mpDamage/tpDamage），不能把「净变化」与「MV最后写入结果槽」混为一项；槽值遵循gain调用的请求量与后写覆盖，不能擅自改成夹值后的actualDelta；护盾等钩子接入时，以传入底层MV gain的有效请求量为准，不以最外层尚未吸盾的原值冒充结果槽。XBattleLogic把最终普通伤害、公式资源副作用、状态、死亡一起合成ActionResult，并供画面按LGP_BetterDamagePopup对应规则排HP／MP／TP队列。首期兼容源的后写覆盖（例如普通伤害覆盖此前gainHp的hpDamage）；副作用journal仍保留真实增减量供记录与诊断。若希望每条额外扣血都弹字，作为独立可回退优化交用户决定。miss/evade时不运行公式，反射／反击按实际subject/target执行，不在画面回放时二次发放或刷新。

**报告口径**：转换器同时报告 `pureSupported`、`effectfulSupported`、`unsupportedActiveDamage`、`unsupportedNoDamage`，按Skills与Items分别统计；另列 `reachableSupported`／`reachablePending`／`reachabilityUnknown`。所有统计由实际产物的status与能力可用性算出。sourceManifest保留原文SHA、程序版本、能力需求和精确拒绝原因；净化之雷迁IR后不再算未翻译。保留旧formulaGd兼容列便于渐进迁移，不能用报告端扣去3个ID或SHA伪装转换成功。

**迁移顺序**：先加IR编译器与纯模式双算（不改游戏入口），对既有纯公式结果对照；再迁净化之雷3块，接资源mutator/ActionResult与完整action参照，通过后删除XCustomDamage分派及eval副作用；接1068所代表的装备等级查询，再迁其余23块；护盾／角色函数随对应系统，保留unsupported。一个技能一次只允许一个执行入口，旧formulaGd与新IR不能各执行一次。

**严格验收**：新 `formula_program_probe.cjs` 独立文件加入同步PROBES，读冻结v0.28真实YEP处理后的公式，保留现48例；补HP小于／等于／大于3000、MP/TP为0与上限、死亡与immortal、状态改变最大资源、miss/evade/反击/反射、多个目标与重复ACTION EFFECT、异常发生在写入前后。逐语句与完整apply都记录资源、最终value、死亡/状态、ActionResult槽与LGP弹字队列。护盾接入时追加无盾／部分吸收／刚好吸收／超额吸收、溢出减伤、setHp钩子和ShieldEffect倍率；装备等级含无装备／错类型／同base多实例首个／level0/高等级、熟练度与变量边界；纯预览前后比较所有角色资源/状态/装备/变量/RNG状态/池游标不变。三元／if未取分支不能执行副作用或随机。报告所有31块覆盖状态，不靠能parse就算语义通过。

### 14. 战斗规则独立随机数（待用户定案）

**所有权**：每个 `XBattleLogic` 实例拥有私有 `BattleRandomContext`，`setup`前显式传入；包含 `rule`（命中／暴击／浮动／选招／目标／OTB顺序／状态／逃跑）与独立 `reward`（掉落候选）的流。依赖通过构造／方法参数传给XEnemy初始化、XDamage浮动/公式、Battler加状态、战斗内事件变量、XZhenqi参考敌人setup；不设静态“当前battle RNG”、不按需临时seed全局。战斗外状态添加使用调用者的世界上下文，不能残留上场战斗RNG。画面只拿ActionLog，无权拿rule/reward对象。神话色相、呼吸、图标、音高抖动使用演出RNG；地图遇敌与随机移动归地图／世界流，闭关道法随机归养成流。

**API**：`BattleRandom.next_float(reason, event_key)`、`next_int_inclusive(lo,hi,reason,event_key)`、测试用 `ScriptedRandom`；需保留各分布与消费次序（浮动两次整数抽样、OTB首回合双排、概率0/1仍抽的现状、整数端点和原randi()%n的取模行为不得顺便改成无偏抽样）。randomTape记录逻辑原因/序号，校验流、范围和消费长度，溢出/耗尽应失败，不能测试序列循环后掩盖额外消费。公式随机不得落回全局randf。现有elite_roll、level_roll、XGear.roll_seq、XZhenqi.rand_seq逐项迁移或适配，不把force变量常开当实战覆盖。

**种子与重播**：建议首期使用Godot自有RandomNumberGenerator实例，固定环境登记4.7.2，schema记 `rngVersion` 与精确引擎版本；不要承诺默认算法跨引擎稳定。测试总传seed；实战从世界持久seed与单调battleSerial经固定编码／SHA-256派生master seed（不用语言hash或时间单独当seed）。rule/reward由带域名的同一派生函数各得seed，互不消费。首次添加世界seed只用独立随机对象，保存一次；旧Godot存档无字段时初始化并标版本，之后保存battleSerial；不迁MV存档。64位seed/state以十六进制字符串序列化，防JSON浮点丢精度。

每场debug replay包含源内容指纹、引擎/build/rngVersion、初始战斗snapshot、rule/reward seed与状态、命令与规则参数（包括提前掉落规则）、稳定战斗者ID（actor ID＋敌群成员索引＋生成序号），以及随机消费journal／每个规则事件摘要。重播恢复初态并执行同命令，比完整log与最终状态；版本不一致明确拒绝精确重播。存档若当前不支持战斗中保存，只在battle边界保存世界seed/serial，不为此新增战斗中保存。若以后要求跨引擎重播，另立稳定PRNG版本与固定向量，不在本轮默认引入。

**掉落与持久随机边界**：`drops_of`的不可变候选结果由规则事件抽定并按稳定敌人成员ID缓存，图标显隐不得决定是否抽样；同一敌人复活再倒下是否复用以当前_treasure/MV参照为准。提前入包规则仍保留：原设置开时倒下提前获得、逃跑保留，关时胜利才入包。画面只请求展示已抽定结果；实际入包通过一次性grant token，不能动画重播再发物品。

XGear的20数预掷池、持久游标、插槽现掷、orb_seed不强行改归battle流。装备构建通过明确RewardContext和原装备池所有者，只在原入包事件点消耗其持久流；若时序会影响后续战斗，要在不改变原语义的前提下预留不可变结果或建立独立装备流，实施时补存读／重复获取参照。此接口的兼容转换须单独小步核查，不能只把state.gain_gear内部全局random改成reward然后覆盖历史装备结果。建议独立持久 `equipmentRngVersion/seed/state`：首次由worldSeed以equipment域派生，保留旧存档已有rom.x/xn/xs/xsn；只有下一次原本需要refill或非池现掷时推进，模板预览不得初始化或推进。既有装备实例、已存预掷值与游标必须逐字不变，未来非池现掷序列无法承诺与旧全局seed逐点相同，需在实施登记该兼容边界；是否首期纳入这项装备流迁移由用户定案，未纳入时在适配器中明确保留旧装备路径并把‘战斗奖励全确定’标为待完成，不能靠只测物品掉落宣称装备也完成。

**预览**：AI候选打分、战力页、混合权重估算不拿rule/reward可变对象；使用独立固定预览上下文。比较预览前后rule/reward state与drawCount相同。实际敌人rating抽选、随机目标、追加行动和try_escape只在明确执行事件点推进。`commands.get(u, decide(u))`的默认参数有提前求值风险，迁移时改为显式存在性分支，保证手动命令不偷偷运行随机AI。

**确定性验收**：升级xiyou_determinism，保留真实技能的yepSeq、动画timings.se和敌人多技能候选，用 `start_turn→next_subject→decide→act→end_turn` 与真实场景两条路径跑至少3回合；包含智能AI、随机敌人AI、随机目标、多段、OTB追加行动／同速、附状态随机时长、神话判定、反击／魔反、真实HP与至少两次掉落机会。矩阵覆盖动画／镜头／掉落图标／声音独立开关、快速战斗、battle speed、time_scale、不同帧等待；在每次画面等待间有意调用全局randf/randi，验证规则流独立。音效开启必须真的请求并播出，不删timings.se假装覆盖；退出按规则停播放器并真实等0.5秒。

断言逐回合行动者/选招/目标/命中/暴击/伤害/状态及回合数、rule/reward journal、掉落候选、装备实例/池游标、奖励与最终状态；图标开关引起的**已定义提前入包／逃跑留物差异按MV单独断言**，不能要求所有逃跑场景奖励完全相等。逃跑额外覆盖失败→再成功、失败后escapeRatio+0.1、失败只消耗OTB当前角色本次行动、即使概率达到1仍保持现抽样。增加同seed同命令复跑、不同seed能出现分歧、两场并存上下文互不推进、setup前后演出随机扰动、预览零消费、重播内容版本不符拒绝、RNG状态序列化续跑。mv_oracle用固定随机序列对照每个规则调用的范围／分布与消费顺序，不要求Godot与MV原生seed生成相同数列。现有战斗／OTB／状态／掉落／装备／真气所有参照继续通过，偶发差异不能靠重跑。

**兼容与实施顺序**：先加注入适配器与审计失败保护，再迁setup/AI/顺序/状态/伤害，最后掉落候选与跨模块接口。移除生产战斗调用链全局rand*后加静态扫描守卫与一条新增调用检测；演出静态白名单必须注明域，不接受不断新增特例。新RNG序列会与旧Godot全局seed不同，保玩法分布／MV消费语义，不承诺旧测试seed打出逐点相同值；fixture改动必须有可审查原因。更换PRNG、拆更多流或改变提前奖励时序不在这项默认授权中。

## 进度账

- 仅框架预检／设计，完成度不变；不把待用户定案或未开放公式计为已实现。

## 本分支提交

- `7df29db` 完整预检与两项框架方案；后续补充提交写明ShieldSystem资源钩子边界。交叉核查仍待Claude，扫描自检不销账。
