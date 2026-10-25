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
