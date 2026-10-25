# 交付：codex/passive-content-boss-output

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_66）
- 状态：进行中；从已验04e54453在同树新分支接手，工作区干净，无在途长任务。
- 开工：2026-10-25；实查五小时66%、周40%。只改本车道交付单，共用登记只读。
- 本期先补冻结原版参照，交普通executeHpDamage／executeMpDamage输出倍率；直接gain／set、行动序列和状态来源上下文另分可验小期，不宣称已完成。
- 依赖／已交：Boss属性与生命周期04e54453、普通静态eb6fff3f及其前置顺序照各自交付单；不重做旧29组或8场。

## 可优化

- 按原版入口分期：本期普通结算先独立交付，复杂上下文逐入口采样，避免难尾巴延迟可交部分。

## 变更记录草稿

## 2026-10-25 【Codex·沙僧·未经Claude检验】Boss普通HPMP输出倍率（dev.待定）

- 敌人新增boss_output_rate，只看Boss身份与霸体布尔，等于已验属性倍率；不查2651图标。死亡复活后标志仍真、图标暂缺时同样放大。
- execute_hp_damage／execute_mp_damage最外层对非自身正伤害取floor(value×rate)，随后才走现有导入平衡、真气、护盾与吸取上限；倍率为1也照原版取整。治疗、0值、自身代价原样进入原链。
- 冻结原版78组：0／1／3／5名超强者、霸体开关、HP／MP正负零与小数、吸取／自身吸取、普通／名单／备注Boss、角色来源、角色／敌人护盾、死亡复活缺图标。MP伤害类型冻结库缺失，使用普通技能数据副本仅指定damage.type=2，所有结算方法均为原版；HP与两类吸取用真实技能1／865／500。
- 只交普通结算入口；直接gain／set与action.apply／executeDamage／applyPostDamageEval上下文、行动序列、状态来源与1341／2550特殊反应仍未接，不自评完成度、不自销核。

## 验证（收尾填写）

- 78组原版errors空；最终修正before结果数组深复制及结算后图标比较，重新采样中。
- Godot导入无SCRIPT ERROR／ERROR。首次专项测试有误写的XDB.load_db入口，已主动终止自己的任务并修正；初次短跑3823项中3817项通过，六项失败均为快照／图标时点，未改数值实现来绕过。
- 原版早期宿主失败与浅快照原件全部留在mv_oracle/.sandbox；不当作有效参照／不称偶发。未改切片／转换器，不重同步或跑旧8场；本期只新增专项和直接依赖。

## 后续与边界

- 下一小期从本期最终已验HEAD同树开codex/passive-content-boss-context，先采普通行动上下文内的负gain与set下降参照，再设计明确来源／单目标或targets域与settled／direct的作用域栈；嵌套与异常需恢复，不读残留BattleManager subject。
- 普通入口缩放落在battle_logic.gd的_boss_output_value，后期settled栈必须避免这次已缩放值在gain／set再次被放大。当前resource_context.gd、damage.gd、state_effects.gd均未动；formula_execution／mv_event_core和两块TP Apply宿主仍未交接，不碰。
- 后续分别取BattleManager.processActionSequence、actionHp／MpModify目标域、Game_Battler.customEffectEval的stateOrigin、Game_Action.customEffectEval仅reactState的1341／2550来源参照。未接宿主明确留诊断，不为尾巴拖住已交小期。
- 前期权能五本／容量满返书与预约1317／PREE-ASUP／穿武器动态链、race-battle接口等沿用旧单，不重复旧338组。50%审查二期仍另合，依赖顺序保持。
