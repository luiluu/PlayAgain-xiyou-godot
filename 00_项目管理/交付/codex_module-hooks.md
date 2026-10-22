# 交付：codex/module-hooks

- 车道／工作者：框架 · Codex（沙僧）。
- 状态：进行中
- 用户 2026-10-22 插队：第二期2b～2d已经可合并，2e仅原版TP测量WIP保留，先做架构审查13「模块挂接点表」，之后回状态效果第三期往后。
- 基于 main e5e283b；不改主工作区共用登记。独占 damage.gd、新 module_registry.gd、自己的探针／专项、框架约定本节；不改 battle_logic.gd／actor.gd／battler.gd、切片或角色实现。
- 本期：登记表校验、稳定次序、只读上下文、有类型的数值变换与逐次trace；先迁既有orb-sets。以冻结cat-sword原版数值与临时减伤为首个扩展用例，不提前开放178。资源提交与其他宿主挂点保持pending，不能冒充已挂接。
- 哈基米提案在 claude/wukong-hajimi 尚未落盘；交付前读取。原版先测后实现。长任务脱离会话运行；车道只跑相关专项，合并后由唐僧统一全量 --oracle。全部提交待Claude交叉核查。

## 检查点

- 冻结引擎注册表23项，cat-sword索引9、orb-sets索引19；每项enter→build，cleanup逆序。native-v2原版15例errors=[]，保留首轮探针夹具错误日志（Node数组缺MV contains，已改MV数组），没有改原版守卫／生产。
- 注册表与伤害数值入口首版专项605/605通过（test-v3.log）；持剑／剑心／进阶／echo／其他技能／吸收／免疫／速度减伤／巨龙减伤／治疗／live浮动逐例对照；原版资源与缓存均无残留。
- 接下来补全数值字段组合参照、真实行动入口回归、框架文档与最终同步；尚不可合并。初次专项两处测试API拼写与StringName值复制已修，保留失败日志，不算偶发重跑。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】架构13：模块挂接点表与伤害数值入口（dev.待定）

- 用户插队顺序：第二期2b／2c／2d已分别交可合并；2e仅保留原版TP测量WIP，不把它冒充玩法完成。本批先做模块挂接点表，之后回状态效果第三期往后。
- 新增XModuleRegistry只读编译表，条目带id／version／capabilities／contexts／hooks；校验未知／pending挂点、重复id、能力冲突、上下文及嵌套读路径、依赖环与源次序冲突、处理器签名、写字段及有限数值。固定order＋稳定id；表没有运行时增删。处理器只接深拷贝且递归冻结的值上下文，返回set／add／mul操作；每个处理器的整组变换原子接受。
- XDamage.calculate新增damage.before入口与moduleTrace；原orb-sets只走表一次，既有公式、Confirm→固定减伤→React与护盾／导入平衡边界保留。数值帧补齐技能／普通／元素／最终／暴击、物魔防御率／伤害率／穿透、承伤、成长／结算倍率、无属性／种类最大值与临时固定减伤覆盖。
- 冻结原版CodexDamageHooks有23项，依次enter→build，cleanup逆序。哈基米cat-sword索引9（order18／19）、orb-sets索引19（order39）。以测试适配器对照哈基米持剑、剑心、进阶、echo、速度保护、巨龙减伤、吸收／免疫／治疗和live随机；不把178测试夹具注册到游戏默认表，不提前开放角色。持剑把真实缓存临时改写的做法在Godot中转为本次flatMitigationAdd覆盖。
- 边界：damage.after及其他宿主挂点明确pending，注册会拒收；原版f.after在Confirm后／React前，不能冒充扣血后挂点。moduleTrace由calculate返回，既有battle_logic的float接口尚未消费到战斗日志／replay，待占该宿主的车道接线；不声称完整角色模块、来源护盾账本或完整模块重播已实现。11转换规格／12会话启用仍待实施，本期用显式table／facts参数过渡。
- 新module_hooks_probe：27例、errors=[]，实际原引擎handler与计算器参照；含额外frame-probe操作组验证所有本期数值字段组合（与原生cat用例分别标识）。新xiyou_module_hooks检验逐例伤害／倍率／减伤、源序、重播、只读、注册拒收与嵌套派发。探针加入同步PROBES，专项校验runtimeInputs。
- 合并基线：已合main 925dcce（不重复合main、不重复全量验收）；与state-effects-2d的merge-tree预演无冲突，保留其finish/apply_state_effects显式ctx接口。建议先按顺序合2b→2c→2d，再本分支，一批统一 --oracle。
- 原版守卫未改；不读写玩家存档。车道不跑全量检查，由总装统一检查与推送；回退用本批Git逆补丁恢复原orb内联入口，不同时启用两条路径。

## 给悟空的挂接契约

- 接入点：`XModuleRegistry.compile([XModuleRegistry.orb_descriptor(), <角色描述条目>])`；描述条目可来自新的角色脚本，enter／build分别挂damage.before的order18／19。默认standard当前只有orb-sets；正式启用178时才在工厂加角色条目。
- `XDamage.calculate(..., {moduleRegistry: table, moduleFacts: <角色只读快照>, operationId: <本次行动/伤害段ID>, ...})`。现有damage.calculate仍兼容原options；宿主先捕获持剑、已学技能、进阶、目标速度、回合和本段连携数据，再以facts传入。处理器不接battler或随机流，也不自己消费标记／剑心／资源。
- build写normalAdd／elementAdd／finalAdd／criticalAdd／settlementMultiplier；enter写flatMitigationAdd。elementAdd／elementMultiplier／flatMitigationAdd操作必须给0～15的整数element。字段名按原版frame命名。writes逐项列准确字段，contexts／reads列所需facts，缺值会返回unavailable。
- 每段calculate独立派发；连携步骤／目标／命中／标记消费、临时公式上下文、行动结束和剑心层数由角色宿主负责。未命中不应调用伤害计算；反击／反射用实际使用者和目标；预览使用影子facts，不能把真实资源写接口塞进值快照。正式接入前必须处理available=false，不能按0伤害继续。
- 本期已按冻结Cat v1.0.1做首用例；截至本检查点，claude/wukong-hajimi交付目录还只有上批wukong-next单，未见新钩子提案。最终交付前再读一次；不将尚未写出的提案冒称已审。

## 交接板草稿

- 架构13：数值注册表与damage.before已交；damage.after、split及其他宿主点、日志/replay接线仍pending。哈基米下一期可依本接口接角色模块，不再新增伤害核心特判。
- 沙僧下一步：用户要求回状态效果第三期往后；2e的TP整块前置保留，不抢在插队任务之前扩做。第三期若仍禁actor.gd／XState，则先按2d交付约定写addParam存档／刷新完整接口提案，再处理第四／第五期，不靠孤立字段冒充完成。
- 用户试玩说明：已有宝珠套装与伤害结果保持；本期为后续167～178模块接入提供挂点，不宣称新角色已开放。
- 需要用户决定：无。

## 进度账

- 不重算完成度；本批是框架入口，全部待Claude交叉核查。

## 同步环境修正

- 首轮sync.log因Codex继承了LANG／LC_ALL，而携带缓存里二者均为未设置，规划44探针全失效；首份slice_d1已通过（含排槽488.743秒），其余与专项都长时间排共享槽。核实本车道childIdentity后主动终止本轮自己的同步进程组，退出143；保留日志，不作偶发失败、不声称该轮通过，未动其他车道进程。
- 按携带缓存的实际环境恢复：从main重新复制42条缓存，第二次同步显式移除LANG／LC_ALL；缓存仍逐项验证输入及输出SHA。新的module_hooks和未缓存／实质变化的用例正常重跑，不放宽比对／守卫／并发。这样避免仅因会话工具环境不同重复全量探针。
