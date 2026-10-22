# 交付：codex/state-effects-2b

- 车道／工作者：翻译／核查 · Codex（沙僧）
- 状态：进行中（专项全过，最终同步正在运行）
- 基点：main 09ebfb0（合并 codex/state-effects-2）。交付前 `git merge main` 已确认无新提交；唐僧主工作区的未提交收尾只读，未改共用文件。
- 范围：第二期第二小期：四种整块常量加成、默认伤害链上下文、原有终值扩展兼容。旧终值覆写的全面迁移另有具体提案，不能宣称完成。
- 独占：battler.gd、damage.gd、core/state_effects.gd、state_effects_probe.cjs、xiyou_state_effects测试、转换器状态效果翻译部分。battle_logic.gd只改状态挂点，未动certain_hit()。
- 未碰 actor.gd、xiyou_slice.json、角色／界面／工具既有脚本；新增的测试状态效果翻译.py只用于本车道翻译边界验收。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】状态效果第二期第二小期（dev.待定）

- 四类已取原版参照的常量加成翻译成 `value_steps`：local bonus、finalRate、finalRate＋critical bonusRate、前者后接独立 floor。28个真实状态confirm块；按更新后的value逐步加法与取整，尾部独立条件重新检查，保留负系数与负结果，不合并总倍率。
- 全块／词法边界匹配；带未知副作用、半块、破坏标识符、额外语句的全部保留js。旧125个mul＋2个user_param_damage逐源块输出不变；js由511降至483（仍有483未翻译，不代表所有声明式形状已完成）。
- 默认伤害路径统一经XStateEffects，Confirm／React得到资源／结果槽、record、vars／switches、规则RNG、critical；respond返回的value传给establish。新增基础分解挂点 `_calculate_damage`，可固定基础数值并保留四段效果；保留旧 `_damage_value`「已结算终值」覆写契约，相关限制见下。
- 原版：state_effects_probe共19例退出0、无errors；旧17例与既有generated参照逐项不变。新增28状态×7value×4伤害类型×2暴击=1568行全对；固定基础7的真实四段输入为7→14→7→21，扣血7。输出 `.sandbox/state_effects.json`。
- Godot：最终相关13场景共4546项断言通过：state_effects1640、battle8、battle_events108、battle_options92、battle_ui43、battleback_save5、drop_record26、formula_effects908、imported_balance273、shield565、custom_damage145、random_streams484、transform_params249。额外翻译边界4项、既有公式编译12项通过；预览未写真实资源、状态缓存、RNG、诊断或资源槽。
- 日志：`03_再刷重制_Godot/04_验证/本地结果/state-effects-2b/`；最终测试分别在dependencies（首轮通过的8个旧依赖）和final-dependencies（state_effects／drop_record／custom_damage／random_streams／transform_params最终结果）。首次测试确定性失败及修复见下，未靠偶发重跑销账。
- 车道只跑专项；全量检查留给总装合main统一一轮，全部提交待Claude交叉核查，不自核。

## 完整迁移旧终值夹具的具体提案（本期未做）

- `_damage_value(u, skill, t, critical)`原来返回已完成Confirm／React的终值；旧drop_record测试子类覆写它返回100。尝试把所有覆写返回值当基础数再统一过状态时，两条精确记录由100／167变成600／667。其余首轮直接依赖均通过。
- 原因是夹具初始条件不同：原版drop_record_probe直接调用BattleManager.startBattle，状态表[]／[1460]；Godot setup还跑dsPassiveSkill开战标签，多带状态995。旧终值覆写跳过Confirm，隐藏了这个差异。不能把这个角色测试的失败当作纯倍率错误，也不能为了它跳过生产路径的状态效果。
- 后续有掉落／角色测试权限的车道：将Godot该夹具的初始状态与原版row.states对齐并刷新热缓存；把FixedDamageLogic改覆写本期新增`_calculate_damage`返回`{value: row.baseDamage, critical: ...}`，参照不改；两条记录仍应100／167。再迁移／移除旧终值入口，才能宣称全部覆写也经过Confirm／React。沙僧本期未改该测试及其探针。
- 本期默认路径与新的基础挂点已验证四段链；**旧 `_damage_value` 终值覆写依旧跳过Confirm／React，是保留的兼容边界，非已修完**。

## 验证中的确定性失败记录

- 首次状态效果专项1639/1640：JSON浮点314与本地整数314的嵌套数组严格比较失败，数值一致；已统一测试类型，最终1640/1640。
- 首轮依赖drop_record24/26：上述终值接口变化造成，恢复兼容契约并新增基础挂点后26/26。未改角色测试、未改参照、未标偶发。

## 交接板／进度账草稿

- 本期不调整进度账；待Claude核查本分支和main内此前的沙僧实现。
- 核查分支`codex/review-dev122-123`（同级工作树review-dev122-123，最新56e57fc）已可合并，原dev.122／dev.123及5c1bf82无需重复核。P2 sips转PNG时ICC带当前时间，源不变输出SHA仍变，留工具车道修；89811f2已修8个假图片夹具，以接续报告为准。
- 下一步直接接第二期其余声明式形状：每种先mv_oracle，只接整块。原版报错／不触发不自动修成有效。难尾写明未支持，不冒称完成。
- 第三期状态私有数据、param_add和兼容Godot旧档的保存字段；若必须改actor.gd的param_plus／存取，按用户边界写具体提案再跳第四期，不能只加字段漏执行和存档。
- 第四期公共事件预约与消费：原版覆盖单槽（1771两次最终2479），不能暗改FIFO；若必须改battle_event_runner／XState等范围外核心，写具体提案。连续两期无可交付成果即停手回报，不强行做到第五期。
- 第五期只1741～1749：1741／1742的this.user、1743畸形标签、1747语法错、1748 attackCount、1749 criticalRate先量真实无效／报错；1744～1746无Custom块。108奈叶归悟空。

## 长任务与接力状态

- 最终同步用长任务.py包装运行`同步正式西游.py --accept-additions`，日志`03_再刷重制_Godot/04_验证/本地结果/state-effects-2b/sync.log`。不能重复启动；用等待任务.sh等现有任务。
- 同步计划执行42个探针（转换器源变更导致缓存失效）；结束后核对退出码、同步报告和sync_stamp.json，再改状态为可合并并提交。
- main当前仍在09ebfb0，本轮未出现新的Claude提交；若后续出现先核查，不自销Codex提交。
- 本期此前WIP均已提交。没有活动heartbeat；旧临时监视已删除，不重建。

- 自动同树接力点：下一会话`重制_沙僧_41`从本工作树继续，先等现有sync.log任务（包装PID64254，子组64255；不要据PID盲目终止），核对同步报告再标可合并；随后第二期其余形状。未提交改动应为无。不能把本期已记录的旧终值接口兼容边界重新改成失败的基础值语义。
