# 交付：codex/actor-bonus-states

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_64）
- 状态：进行中，尚不可合并
- 基线：actor-bonus 7ef7584a；同一 state-effects-2b 工作树续做，首批分支保留可合并。
- 范围：先取冻结原版1612 Apply／Remove／Leave和1768 Conclude的生命周期参照，再接完整签名的param_add；当前角色持久账本与预览隔离为本期验收重点。敌人无永久账本的边界单独说明，不扩未交接的formula_execution／mv_event_core、两个TP Apply宿主或完整预览空槽。
- 开工实查额度五小时89%、周29%，95%保存停；共用登记只读，不自销核。旧原版证据、.sandbox、generated及整树保留。

## 验证

参照已完成，游戏实现尚未开始。七组冻结原版最终取样errors空，另以断言核对逐次调用数量、永久账本与活跃状态存读。未改游戏代码／转换器，未重生成／导入，不重复首批已过19场或旧全量／同步。

## 可优化

独立定向参照与夹具，不注册全量同步；长批测使用python3 -u与XIYOU_TEST_HEARTBEAT=30。

## 原版参照检查点

- 七组定向参照errors空，保留来源身份与每次addParam后的HP／MP；初版探针误用Conclude方法名及recoverAll清状态，已纠正后重取，不算最终验证失败。
- 1612自然配置autoRemovalTiming=0，本来不会自然到期；forced_expire仅为明确改timing=2的测试宿主，验证Remove再Leave两组各减四次。通常驱散只Remove，重复附加只续期。移除按当时level，故3级加、5级撤会留下负余额，不擅自修正。
- 1768走原版offApplyStateEffects入口，分别测存活、仅HP0、仅死亡状态、两者及自目标；两次执行与JsonEx往返。

## 沙僧64参照收尾与续接位置

- 最新参照取代02f29249里的早期取样：1768必须在addState后refresh使KRZ类型缓存更新，实际入口是offApplyStateEffects；1612先加十万HP／MP作夹具底座，防止撤除后倒下使后续附加测不到。重新附加前clearResult，原版本次结果仍记removedStates会拒绝重加，不是永久脚本自身行为。
- 最终七组：1612.dispel／forced_expire、1768.alive／hp0／dead_state／both／self。两组1612的trace调用数均为0、4、0、0、4或8、0、4、0、4、0；存档时1612仍在，读后解除只扣一次Remove。1768存活不加，另外四组每次+HP10／MP30，两次后存读保留20／60。HP0自目标无死亡状态时addParam刷新资源的行为也保留在轨迹中。
- 参照夹具：`03_再刷重制_Godot/01_Godot工程/tests/fixtures/param_states_oracle.json`，SHA256 d0a0aa383c72ced5a8a6b859ea70bd53e8cc1d7995d334f1cc5347e10c29bfba。独立探针param_states_probe.cjs只写.sandbox，不注册同步；没有新临时输出目录，.sandbox和旧证据照留。
- 收尾验证：检查.sh原样文档／JSON／链接／编号检查exit0（dev.173），guard_check.cjs为16/16，git diff --check通过。只变参照／文档，不运行游戏专项或全量，不自核本人提交。
- 全库完整token签名扫描确认只命中1612的Apply／Remove／Leave及1768的Conclude四块。下一步仍是实现这四块，不把原版参照误算为已接线。
- 建议最小实现：四块完整签名→受控param_add，1612按当前level逐次加算并逐次刷新；1768条件严格为hp<=0 OR死亡状态，不能只用hp判断。角色复用XActor.add_param，必须核实user为XState.current.actors中的同一个真实实例；仅判断XActor类型不够，影子克隆仍有同actor_id，现有XParamPlus.add会按ID写真实账本。execute=false和带preview的资源域不得取得持久写能力。未移植敌人永久账本时诊断该宿主不可用，明确只交actor小期。
- 需要专项覆盖：真实add／重复add／remove／remove_state_auto及存读、HP／MP截回、Conclude各死亡分支与真实battle.apply未命中仍Conclude、execute=false＋预览资源域＋影子实例调用不得改真实账本／缓存／资源／RNG／诊断／观察者。不碰已留交接的formula_execution和mv_event_core。
- 转换后未翻译数预计441→437；既有xiyou_state_effects_tp.gd有441硬编码，届时同步更新名称与计数，保持两个TP Apply仍为JS。别为了这四块重跑旧19场；按新代码实际依赖选测。
- 当前同树分支codex/actor-bonus-states；actor-bonus 7ef7584a仍独立可合并。本小期尚不可合并，游戏代码和转换器完全未改。下一期完成后再passive-content→race-battle；自己的提交均待Claude。

## 2026-10-25 额度重置后续做

- 开工实查五小时0%、周30%，bd0e2306干净续接。四块最小受控翻译与真实角色账本能力检查草案已写，尚待转换、导入与专项。预览显式标记在类型列表、观察者和诊断之前处理；addParam逐次刷新绑定同一生命周期资源域，未碰外部宿主。

## 实现专项检查点

- 完整签名只接受1612三块与1768一块；结构化param_add仅允许真实当前角色账本，敌人宿主诊断param_add_actor_required，未移植敌人永久账本。XActor.add_param自身也拒绝影子与预览域。
- 原版扩为11组：增加真实Game_Action.apply未命中（正常存活与immortal的HP0目标）以及隐藏敌人的死亡状态／HP0。隐藏且仅死亡状态不加，隐藏HP0仍加；不复用Godot包含HP判定的is_dead作为原版isDead替身。
- 开发期差异均已定位：JSON数字类型比较、读后跟踪角色未setup、测试绑定资源域未释放引用环；早期直接HP0未标死亡的原版夹具与Godot目标可选判断不同，真实未命中用双方均支持的immortal HP0条件，直接Conclude的裸HP0仍严格保留。未因此改战斗目标判断。
- 当前新专项包括逐次addParam后HP／MP、普通与显式资源域生命周期、活跃状态存读、重复附加与解除、Remove后Leave双扣、Conclude各分支与未命中、四个phase的execute=false／preview标记／预览资源域／生命周期预览域／影子身份隔离；未修改外部宿主或完整预览空槽边界。
