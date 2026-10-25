# 交付：codex/state-effects-2g

- 车道／工作者：框架／沙僧（Codex）
- 状态：进行中（WIP；用户2026-10-24改为先做50%阶段审查，2g往后排）
- 本次保留的WIP范围：资源刷新前置、预览克隆剥离生命周期域、607／609／857 三个 Battle TP 整块；**不是五块 TP 整期完成**。
- 工作树：沿用 `.claude/worktrees/state-effects-2b`，旧未入 Git 原版证据必须保留，合并后不要清理整个工作树。
- 起点：先 fetch，从 main `2fba4b52`（dev.164）新建；交付前已合 main `7fc0c310`（dev.165），无冲突并重新导入。

## 变更记录草稿

## 2026-10-24 【Codex·沙僧·未经Claude检验】2g首批：三个开战TP块及生命周期资源前置（dev.待定）

- 开战 TP 先完成初始随机值，再分发 Battle 状态效果；607／609 请求 +200、857 请求 +50，经统一资源刷新与结果槽，开战槽与 journal 留在 battle_start_effects，下一行动使用新槽。
- 明确资源域的状态附加／解除／自然到期／刷新包装，嵌套恢复 holder 的旧域；角色 add 锁内保留类型层刷新，跳过基础夹值；敌人仍夹值但嵌套阵亡受同一全局锁拦截。刷新尾部按 KRZ 清 dirty，gain 返回时再标 dirty；TP 槽保留请求量与旧 HP／MP／success，journal 记录实际增量。
- formula_context 的影子克隆明确跳过 lifecycle_context 与状态来源，保留其他对象值的拒绝守卫；已有结果槽的生命周期预览可执行且不写真实资源、状态、缓存、随机流、诊断、结果槽或观察者。actor.gd 只改 add_state／资源刷新；XTraining.param_bonus 原样保留。
- 转换器仅接受完整 Battle `user.gainTp(200);`／`user.gainTp(50);` 的 token 签名；未翻译 **444→441**。1334／1336 Apply 仍为 JS（见停手边界）。
- 新专项逐项比较原版 TP 边界：140 条直接执行、4 条重加、8 条真实 Apply guard、14 条被动上限与4条抵抗状态边界，再比开战顺序与作用域隔离，共537项。Apply 的未来 op 仅在测试中临时替换后还原，不当作生产翻译完成。
- 验证：最终13场中12场通过，公式资源专项906/908，2项失败，**不可合并**；不运行全量检查，不复核本人的完成度。
- 未完成：五块中的两个 Apply、完整预览的空结果槽边界、期二两处接线及期三；未动 P2-1 异化 ready。

## 验证

- 原版 `generated/oracle/state_effects.json` 为既有26例，SHA256 `7eff2c8a0c7632f25f9b419cfe5e2edb6e363094ee5f0ee6af57f2293a2160ad`；未重跑native22、未改探针或参照值。
- 翻译边界 Python 8/8；新增 TP 专项初测537/537。第一次测试类型声明错误已修，不计通过；实际对照发现的刷新尾部dirty差异已修，最终矩阵无差异。
- 交付前已合 main dev.165 并重导入。合并未涉及切片、转换器或探针；本批只改状态块转换分支并重生成，未扩切片、未改探针，不跑正式全量同步；总装合并时按工具规则同步即可。
- 最终长任务（固定游戏／测试代码 `e6002317`＋main dev.165）：13场，state_effects两场、formula五场、troop_events两场、settlement、review135、enemy_book、floor_run_c。日志 `03_再刷重制_Godot/04_验证/本地结果/state-effects-2g/final-related.log`，start脱离会话启动，前台等待脚本 `--timeout 540` 等待，结束后抄录结果并删除本车道输出。
- 首次37场预选批在排槽期间未启动任何场景，主动终止（exit143），不计通过；静态属性rules24段不受本次入口／资源层改动影响，最终只验13场直接相关专项。
- 完整预览空槽边界已在合main且重导入后独立干净复现：available=true、journal=0、slots_before=0、slots_after=2，exit0，无脚本错误；临时场景与临时HOME已删除。它是待交接依赖证据，不是完整预览隔离通过。

## 按用户停手条件留下的接口

1. **`core/formula_execution.gd:48～50`**：预览复制旧结果时调用 `resource_context.result(a/b)`，该读法会在真实域注册空槽。需要改为只读读取 slots，缺槽用 `XResourceContext.empty_result()`，或在资源层提供 peek_result 后调用；不能放宽影子克隆的detached守卫。复现入口：空 `resources`、a/b绑定生命周期域后，调用 `XFormulaExecution.run_item(XDB.rec("Skills", 857), a, b, [], {}, false, null, resources)`，真实slots从0变2。此文件未交接，本批未改，因此不声称所有预览入口隔离完成。
2. **地图／菜单状态宿主**：`core/mv_event_core.gd` 的313仍直调 add_state／remove_state。需要宿主拥有一次显式XResourceContext，以旧runtime_result种槽，经 add_state_with_context／remove_state_with_context 调用，结束publish并把journal／结束快照保存到操作结果；嵌套复用同域、不能无故clearResult。菜单道具等入口使用战斗结算时沿用行动域；直接附加的入口也须交接相同接口。不能只接战斗就把1334／1336全局标为已支持。
3. 未来应一并盘点 `battle/action_sequence.gd` 的直接 remove_state、`core/cat.gd` 直接增删、`core/power.gd` 的开战状态预演；这些不在本批独占。本批只交Battle三个完整块，不自行扩到上述文件。

接口交接前按用户“先交已完成部分”停手，不开期二，不借机改别人的独占文件。

## 交接板／进度账

- 下一步：合并本独立首批并交Claude核查；续接五块余下两块前先补交上述宿主与空槽只读接口。三块已使未翻译444→441，剩余两个Apply仍待完成。
- 期二 XEnemyBook.on_enemy_death 与 ConsumeReduceAll|Zj|Mf|N 未开，cat_probe atkk1817 的tpGap及xiyou_cat跳过均原样保留；期三可砍的历史两项未开。
- 阶段审查50%／75%／95%职责已接收；未收到“阶段审查 N%”不启动，本轮不复核自己的完成度，不增加进度账。
- 用户试玩说明：三类开战回TP状态按原版生效；两类附加状态回TP尚未接入。
- 不需要用户新拍板；所需文件接口由总装安排独占交接。

## 本分支提交

- `dc65ca43` 开工范围；`aeb46e8a` 资源域与三块Battle草案；`e6002317` 原版刷新尾部与夹具修正；`593a4da` 合main dev.165。
- 文档检查点 `a2fb0e1a`／`fd36e95f`；最终交付另见HEAD。

## 2026-10-24 接到阶段审查后的保存现场

- 最终长任务已结束：runId `26af575857bb41d28809e002ab3b4a1d`，2026-10-24 15:46:22～16:12:19 Europe/Paris，exit1，含排槽1556秒。12/13场通过；formula_effects为906/908，失败 `boundary.capState_buffs.after` 和 `.journal`，首次与单跑重跑均失败，不是偶发，未放宽参照。
- 差异：阵亡清掉增加MP上限的状态后，Godot在嵌套refresh中先把MP1500夹到1000，再扣51得949；原版第一次保持1500，下一setter才夹到1000。已定位当前 `_adding_state` 基础夹值guard只排除XActor，通用XBattler仍进入基础夹值；续接时按原版最终别名链修正“除XEnemy外的基类add锁分支”，重跑formula_effects与TP矩阵后再判断能否交付。当前**没有**先改成未经专项确认的修复。
- 其余12场：enemy_book52、floor_run_c560、formula_equipment1804、formula_program43458、formula_rest1352、formulas7、review13584、settlement11、state_effects19949、state_effects_tp537、troop_events6574、troop_events_b6450，均全过。Python翻译边界8/8。
- 用户新指令：先做 `codex/stage-review-50`，固定审查d287ea37之后至7fc0c310；审查交付后再接本分支。故本分支保持WIP、不可合并，不推进期二／期三。未翻译441只表示当前WIP产物，不入main完成度。
- 本轮新增的临时输出目录state-effects-2g、临时场景与临时HOME已清理；旧state-effects-2e／2f及其他未入Git原版证据完全保留。合并／复用时不要删除工作树。

## 沙僧62续接（2026-10-25）

- 已完成四零散b135ee33并独立交付，继续本期bf585fdc旧现场；额度五小时52%、周23%。本树无未提交改动。先并入已验证四零散分支作为依赖基线（含此前已合main545ebd37），不再追无关main，不重复阶段审查或全量同步。总装按四零散→2g顺序合并；四零散仍待Claude核查。
- 仅修已定位的add锁基类夹值边界，先验formula_effects与state_effects_tp；完整预览空槽及Apply宿主接口仍留原停手范围。原版证据／.sandbox／generated与整树保留，共用登记只读。

- 依赖合并仅resource_context死亡分发一处冲突：保留2g add_state_with_context生命周期入口；四零散的note_death在battler._add_state真实死亡处已自动合入，避免在资源层重复计数。后续专项同时覆盖四零散死亡回归。

- add锁guard已改为非XEnemy的基类／角色分支，敌人仍经原夹值链；只改这一处行为，不改原版参照。Python翻译边界8/8。下一步本地重生成＋占槽导入，先跑formula_effects/state_effects_tp，没通过前不交付。

- 本地重生成与Godot导入exit0；焦点两场首次通过：formula_effects908/908（两处capState_buffs失败关闭）、state_effects_tp537/537。接着只补本期原13场其余11场＋四零散loose_fixes死亡回归，前两场不重复。
