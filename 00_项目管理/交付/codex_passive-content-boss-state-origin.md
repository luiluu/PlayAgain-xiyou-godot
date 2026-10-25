# 交付：codex/passive-content-boss-state-origin

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_70）
- 状态：进行中
- 基线：f8046576；同树接续69已独立交付两期，不重跑旧验收。五小时78%、周57%（开工实查）。

## 本小期范围

- Battler customEffectEval 按状态来源→持有者推入独立Boss域；低倍率与空来源必须遮蔽外层域。普通Action阶段沿用外层来源。1341／2550反应来源下一独立小期。
- 先原版宿主冒烟，再矩阵，再运行时接线与专项。冻结源只读，脚本夹具只替换内存状态数据，不替换结算／来源域方法。
- 共用交接板／变更记录／步骤清单／当前状态只读；不自销核、不自评完成度。依赖链见前期[交付单](codex_passive-content-boss-sequence.md)。

## 验证

- 运行时改动后新增专项与state_effects、TP、Boss输出／域／序列、生命周期直接依赖；不改切片／界面，无新增三级必跑项。确定性early_inventory_rule旧8败不重跑、不夹带修复。

## 可优化

- 已做：状态来源与特殊react拆期，独立原版探针和文件名，不覆盖旧证据；只验本期与直接依赖。

- 冒烟初次失败：夹具引用未存在的2998原状态来取phase键，尚未进入原版宿主；改为从被克隆状态2取键，原失败日志与JSON保留。

- 原版冒烟第二次3／3、errors空（任务6900e426b10a43ea938a3039c3767c4c）；包括Boss来源、低倍率来源遮蔽、死亡与恢复，宿主无需补丁。开始完整矩阵。

- 接线草稿：run_one执行Battler阶段且有resources时，origin→holder成对推入／退出；execute=false不借实时域，Action阶段不改。新增专项以真实gain_resource验单条持有者gain，其余set／跨目标／嵌套脚本通过run_one观察者回放域语义，未声称通用JS宿主已移植。五小时83%、周58%。

- 原版完整121／121、唯一ID、errors空（任务9f6e96297146456d9431d8a4eb2d97f3），复制独立fixture与原件字节一致。导入06f68fa307544d2c918eecc511f88b68 exit0、无Script／Parse／Compile错误；只收新专项UID，非车道附带UID移存.sandbox/boss70_unrelated_import_uid.txt。下一步Godot新增与直接依赖验收。

- Godot首批7df73c0ad8cd445c8459ebfa8c2e3bbf：新专项80行old从Dictionary动态值推断类型失败，导致场景未启动；单独check-only已复现，未将exit0当通过。已认证自身包装器后停止本批，保留日志；修为显式Dictionary类型，重新check-only后重验。不将首批其他场景算已通过。

- 第二批d6c7b29a5e8a41e9912ef5ca5afc4c6b：七直接依赖单次通过，新专项15723项表面全对但Action对照夹具漏传item，触发_active读取Nil的Script错误，严格判失败；自动复跑同错误，非偶发。补齐Action宿主item输入；运行时未变，七依赖结果保留，只重验新专项。单独check-only的无GameApp错误来自脚本模式缺Autoload，未当实际场景编译结论。
