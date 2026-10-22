# 交付：codex/module-hooks

- 车道／工作者：框架 · Codex（沙僧）。
- 状态：可合并
- 工作树：`.claude/worktrees/module-hooks`；基线main 925dcce。
- 执行者：Codex；全部待Claude交叉核查。车道未跑全量检查，由总装合并后统一 `检查.sh --oracle`、登记开发编号与推送。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】架构13：模块挂接点表与伤害数值入口（dev.待定）

- 按用户插队顺序，先交模块挂接点表的伤害数值首期，再回状态效果第三期往后。2b／2c／2d仍按原交付分别可合并；2e的TP原版测量WIP原样保留，没有冒充玩法完成。
- 新增XModuleRegistry只读编译表，条目带id／version／capabilities／contexts／hooks；校验未知或pending挂点、重复id、能力冲突、上下文及嵌套读路径、依赖环和源次序冲突、处理器签名、写字段及有限数值。固定order＋稳定id；无运行时增删入口。
- XDamage.calculate在恢复分流／公式求值前新增damage.before入口；处理器只接递归冻结的值快照，返回有类型的set／add／mul操作，每个处理器整组原子接受。原orb-sets仅走注册表，移除旧内联叠乘；既有Confirm→固定减伤→React、护盾、导入平衡边界保持。
- 数值帧支持技能／普通／元素／最终／暴击、物魔防御率和伤害率、穿透／承伤、成长／结算倍率、无属性、种类最大值及临时固定减伤覆盖。显式preview=true时禁止浮动抽样，即使调用方误带实战随机流。返回moduleTrace记录模块／版本／挂点／order／operationId、输入帧、操作及诊断；失败告警并返回unavailable，不伪装成零伤害。
- 冻结引擎实际装载23项，逐项enter→build，cleanup逆序；cat-sword索引9（order18／19），orb-sets索引19（order39）。以真实原版cat-sword函数验证持剑、剑心、进阶、echo、速度保护、巨龙减伤、吸收／免疫／治疗等；Godot临时减伤只写本次flatMitigationAdd，不改真实passiveCache。
- 已读悟空claude/wukong-hajimi交付提案（含4ea173d）。落实其装备视图漏点：XDamage._yep_objects优先读actor.stat_equips；旧actor尚无该方法时读equip_list，因此元素增幅／放大／固定增幅和共用该入口的暴击倍率均能消费统计视图，无178伤害核心特判。截取其cat_probe的stats.sword671冻结参照（6个等级、物理加成0.36），附探针SHA、案例ID及runtimeInputs，验证读取与不改装备实例。
- 新module_hooks_probe含27例，加入同步PROBES与只增稳定键；新xiyou_module_hooks逐项对照原版，并验证注册拒收、嵌套派发、重复计算、预览、随机消费和显式tape重播。设计原件已更新到[框架维护约定](../../03_再刷重制_Godot/00_设计/框架维护约定.md)第13项。

## 验证

- 相关专项13/13全过，无偶发。首批48126项；悟空提案落盘后再验其直接影响的module_hooks／orbs／attack_element：1166／63／66项。按最新结果替换旧3项，不重复计数为 **48187/48187**。
- 覆盖：模块挂点、攻击属性、战斗、掉落、公式程序与副作用／余项、导入平衡、宝珠、琦玉、结算、护盾、状态阶段。日志：`04_验证/本地结果/module-hooks/related.log`、`related-final.log`；最后3项原始日志在`final-scenes/`，去重汇总在`verification-summary.json`。
- 原版新探针27例errors=[]。只增接收4/4通过：新案例ID接受，既有值改变／案例删除拒绝，主工作区首次接收整份27例参照接受；证据`addition-keys.json`。
- 正式同步`sync-carried-env.log`退出0：34组复用、10组重测（含6难度切片，共15条原版命令），全部通过；测量不变，changedInputs／changedMaps为空，measurementChanges={}，来源issues=[]。
- 最终登记指纹验收`sync-fair-stamp.log`退出0（14:38，Europe/Paris）：42组复用，只补测manifest摘要变化要求重测的formula_program／formula_equipment两组，均通过；测量不变、来源0问题，已生成sync_stamp.json。
- 与state-effects-2d（b34efa5）、claude/wukong-hajimi的merge-tree预演均无冲突；探针表／只增表新增位置已错开。此为文本兼容预演，组合运行验收仍由总装统一完成。

## 给悟空的接入契约

- 详细接口以框架维护约定第13项为原件。compile([orb_descriptor(), 角色描述条目])构造表；角色Callable可放cat.gd，enter／build分别用damage.before的order18／19。
- 建议的damage_frame(item,a,b,frame)须改为damage_enter(context,frame)／damage_build(context,frame)返回ops；不向数值处理器传真实a／b或可写frame。宿主捕获持剑、技能、进阶、速度、回合、本段连携等facts，经calculate的moduleFacts／operationId显式传入，正式启用前消费available=false。
- build对应normalAdd／elementAdd／finalAdd／criticalAdd／settlementMultiplier；enter对应flatMitigationAdd。每个伤害段独立派发，连携步骤、命中／暴击、标记消费、剑心层数、临时公式上下文及行动结束由CAT BEGIN／STRIKE宿主负责。
- 本期Cat是测试适配器；standard当前只登记已有效的orb-sets，不抢悟空cat.gd实现，不提前开放178或新增角色机制。

## 边界／已知未完成

- damage.after、split及其他宿主挂点仍pending；注册表不会因存在名字便让未实现点生效。原版f.after位于Confirm后／React前，不能冒充扣血后挂点；资源journal仍归原XResourceContext宿主应用。
- moduleTrace随calculate返回，既有battle_logic的float接口尚未写入战斗日志／replay；不宣称完整模块重播已完成。第11转换规格／第12会话启用仍未实施，本期显式table／facts为过渡接口。
- 回退用本批Git逆补丁恢复原orb内联入口；空表会停用宝珠，不能当兼容回退。原版FS守卫未改，不读写玩家存档。

## 同步调度记录

- sync.log：LANG／LC_ALL与携带缓存不同，误触发44组全重跑；核实自己的childIdentity后主动停止，退出143，非偶发失败。恢复携带缓存的原语言环境后，sync-carried-env.log正常完成。
- sync-stamp.log：最后两组长期轮询抢不到共享槽，核实自己的childIdentity后主动停止，退出143。最终用本地证据目录fair_sync.py调用原同步器，仅把本轮调度改为单并发，使用原并行测试模块已有file_lock在同一个slots/0.lock上阻塞等待；不增全局并发、不改探针／比较／缓存／守卫，不停止其他车道任务。临时适配器不入Git，成功结果以sync-fair-stamp.log为准。
- 大型证据均在本工作树`03_再刷重制_Godot/04_验证/本地结果/module-hooks/`，不入Git。所有本车道长任务均已结束。

## 交接板／进度账

- 架构13数值首期可合并；建议先按序合2b→2c→2d，再本分支，一批统一 --oracle。保留2d的finish／apply_state_effects显式ctx接口；不需再次合main排整轮验收。
- 下一步回状态效果第三期往后。若actor.gd／XState仍在禁止范围，先按2d交付约定交永久addParam存档／刷新完整接口提案，再处理第四／第五期；不以孤立字段冒充完成。2e测量检查点保留。
- 玩家方向：既有宝珠与伤害结果保持，本批为后续167～178提供挂点；角色开放与连携交角色车道。无需用户决定；不重算进度，全部待Claude交叉核查。

## 主要提交

- 02dfa9e 注册表与伤害数值覆盖；eb2ddd6／5166778 原版字段组合与同步接入。
- 9e0be07 显式预览随机保护；f6b7015 哈基米统计视图与671剑参照。
- bd7620c／af911b1 只增稳定键及共用登记位置；其余检查点见本分支历史。
