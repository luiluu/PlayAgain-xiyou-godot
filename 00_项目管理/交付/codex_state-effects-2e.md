# 交付：codex/state-effects-2e

- 车道／工作者：翻译／核查 · Codex（沙僧，接续沙僧_46）。
- 状态：进行中（设计与原版参照收尾；五块玩法尚未实施）。
- 位置：沿用`.claude/worktrees/state-effects-2b`，分支`codex/state-effects-2e`；未新开、重建工作树，未改main或其他车道。
- 本期交付类型：**资源上下文具体设计＋原版证据**。确认需要修改仍留给期三的`resource_context.gd`，按本期交代的停手条件收口；不交孤立TP数值、不进入永久加算／存档期三。五块仍JS，未翻译仍444，完成度不增加。
- 开工只读主库交接板、两树status／log，main为fd975959且b0cbf868为祖先；2e前置已合。续作开工额度五小时32%／周5%，最近44%／7%；按95%收尾线，无需因旧交付中的90%历史停手。

## 具体设计与停手原因

原件在[框架维护约定：状态效果2e生命周期资源上下文](../../03_再刷重制_Godot/00_设计/框架维护约定.md)目标节，尚未实现、待Claude核查：

- 保持`XActor.add_state(id, random)`虚方法签名，新增显式域包装入口；保存／恢复holder旧ctx，嵌套同域共享同一资源对象与随机流，跨holder显式传递，不用场景全局槽。
- 技能附加状态的Apply结果进入现有`_action_resources.result(target)`、同一日志与弹字出口；开战由logic单独持有资源槽和阶段结束快照，不能自动生成原版没有请求的弹字，也不把开战槽带入下一行动。
- `XResourceContext.refresh`必须区分类型外层工作、基础抵抗清除／截取、阵亡同步；不能统一“加状态时不刷新”。角色真实Apply允许TP暂超上限；敌人当场截取，但内部再次add阵亡仍受全局锁抑制。现资源层直接截TP／改状态数组，无法复现这一区别。
- 地图／菜单的直接add_state也需要所属state宿主持有根域及操作结果；只给battle_logic传ctx不足以把全库Apply块标为已支持。预览不得取真实默认域、资源、状态／参数与效果缓存、RNG、诊断或结果槽。
- Godot开战当前先Battle效果、后随机初始TP，启用607／857会被覆盖；新补充case单查真实Game_Unit.onBattleStart顺序，修正须与资源域一起交，不做孤立数值实现。
- 最少需把`resource_context.gd`作为**2e前置**明确交接；若角色刷新分层或地图／菜单根域必须改其他宿主，再先交接相应文件。交接板给沙僧期三的范围不能自动当成本期授权。本分支没有改actor、XState、resource_context、角色测试或任何Godot生产代码。

## 原版参照与原始证据

### 已保留的native22（不重复手动测量）

- 原`mv_oracle/.sandbox/state_effects.json`及native-v2.log保留。独立副本`04_验证/本地结果/state-effects-2e/native22-preserved.json`，SHA256 `24100228be3102a9dcca56fa0bb5ed9b08bbbd9b5819742308772c478876b0a0`。
- `tp.native_blocks`：140条直接执行边界（角色1／敌人、5块、初始TP -1/0/1/150/199/200/250、活／死），另4条真实连续addState两次。旧21例与2d最终参照相同，原22例errors=[]。
- 初值1的真实重加不会碰上限；140条直接调用不经过真实addState锁。不能用这些行声称自定义上限／刷新嵌套已经闭环。

### 新补充入口（可只跑本组，不跑native22）

`03_转换工具/mv_oracle/state_effects_tp_context_probe.cjs`独立执行只输出`.sandbox/state_effects_tp_context.json`；正式`state_effects_probe`复用同组case，追加在反击前。补充探针没有修改冻结源，所有原版写入受原有.sandbox守卫约束。

- `tp.guarded_apply`：8行，角色／敌人 ×1334／1336 ×正常HP／0HP未死。每行记录首次、重加、独立refresh。角色199→224／274，重加不再gain，独立refresh才回200；敌人首次即200。0HP未死两者都延后到独立refresh才加阵亡；两次重加共2次时长随机，若后续独立refresh加阵亡则合计3次。
- `tp.actor_custom_caps`：14行，合成技能经真实passiveEXTTP=-160／+100使角色上限40／300。5块直接执行与2块真实addState逐项记录，直接执行截上限，真实Apply可到64／114或324／374。不是替换maxTp函数，也不冒称覆盖全部上限机制。
- `tp.refresh_state_boundary`：4行，注入陈旧被抵抗状态后比较直接调用／真实addState。角色真实Apply保留该状态到独立refresh；敌人真实Apply当场清除。基础erase不写removedStates，也不新增Remove／Leave回调。
- 以上3例26行已在tp-context-native-v2.log退出0、errors=[]；原始副本`tp-context-native3-preserved.json` SHA256 `f705f6ab39b9ce057be49dd55e3cb6b725819bef3611d68f8fbf44c5a5985413`。
- `tp.battle_initialization`：新第四例，经真实Game_Unit.onBattleStart记录随机TP初始化与607／857的Custom Battle先后；在共享槽排队的tp-context-native-v4.log验证，结束后更新本单。

## 验证、失败与同步

- 新补充探针与主探针语法检查通过；现有状态整块翻译测试7/7通过。未改变转换器，五个TP块仍JS。
- tp-context-native.log失败根因：夹具把VM的_states替换为宿主Array，丢MV contains扩展；改为保留VM数组、清空并push内容。修后v2首次通过。失败原始输出保留，不算偶发，不改源算法。
- tp-context-native-v3.log在测量启动前失败：本地共享槽包装器上溯目录多一级，找不到并行测试模块；已修本地路径，v4重新排队。正式探针未改，不算原版测量或偶发。
- 按车道规则不跑全量检查。没有Godot生产改动，收尾只跑state_effects专项与严格原版增量校验；主库由唐僧合并后统一检查。
- 最终合main、正式同步`--accept-additions`、来源／工具／产物双指纹与专项结果均在本轮收尾后补入；只接受原21→26例新增，旧值变化即停，不写放宽接受单。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】2e生命周期资源上下文设计与真实Apply刷新边界参照（玩法未实施）

- 为607／609／857／1334／1336五个纯TP整块补齐具体资源域、嵌套恢复、结果槽与宿主消费设计；原版测量发现角色真实Apply可暂时超TP上限、敌人当场截取，不能直接复用现资源refresh而忽略全局锁与类型差异。
- 需要修改本期未获范围的resource_context刷新层，按停手条件只交设计与参照；五块仍JS、未翻译444、完成度不变。没有永久addParam／存档实现，不算进入期三。
- 验证与指纹：按本交付单最终收尾记录并入；主库统一全量检查由唐僧执行。全部提交待Claude交叉核查。

## 交接板草稿

- 下一步：先交接resource_context给2e作必要前置，按框架原件分层刷新与共享结果槽完成五块、Godot逐项对照后再交2e玩法；此前不启动永久加算期三。若地图／菜单宿主未交接，Apply完整块不能仅靠战斗入口宣称完成。
- 用户试玩说明：本批只补设计与参照，玩家行为未变。
- 需要用户决定：无新增玩法取舍；范围交接由唐僧登记，本轮不自行借用期三文件。
- 待交叉核查：本分支所有提交，执行者Codex（沙僧），核查待Claude；不能由沙僧自核。
- 进度账：不变，原版参照或接口设计不计已实现。
- 清理：本树有未入Git的native22、补充原始测量与失败日志；未归档核查前不要删目录。

## 本分支检查点

- 26fe46f：恢复期二、已合main并补齐环境；native22保留。
- 3faf0cd：补充探针测量前检查点。
- fb9f73d：修正VM数组夹具、保留首轮失败记录。
- 9d249fb：保存26行补充证据、接入正式探针与可独立入口。
