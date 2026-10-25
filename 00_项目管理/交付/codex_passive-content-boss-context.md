# 交付：codex/passive-content-boss-context

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_66）
- 状态：预设计进行中，尚不可合并；本小期未新增原版参照、未写运行时代码。
- 基线：ec75a3b1（Boss普通输出78组、六场8588项全过；可合并交付见codex_passive-content-boss-output.md）。同树新分支，无在途任务；所有boss66-*临时输出已清理，原版.sandbox、旧证据、generated及整树全部保留。
- 开工额度：五小时92%、周44%；上轮从66%接手，95%时以WIP保存并停，不因额度高而漏交已经验收的普通输出。

## 下一小期范围与先取参照

1. 先取action.apply／executeDamage／applyPostDamageEval上下文中HP与MP的负gain、set下降、正gain／set上升、自身代价、域外目标与无上下文对照，区分count0／3、霸体开关、死亡复活缺2651图标。
2. 参照要保留请求值、资源前后、伤害结果槽与护盾；before结果数组必须深复制，不能复用原版实时_result数组。先用正伤害＋死亡复活／自身吸取小样确认无界面宿主，再扩矩阵，避免整轮后才发现宿主缺项。
3. 本期不同时包行动序列与状态来源。它们逐入口另采参照：processActionSequence的_targets、actionHp／MpModify的makeActionTargets；battler customEffectEval的stateOrigin；action customEffectEval仅reactState且1341／2550的特殊来源与受害人。

## 预设计（待参照验证，不是已实现）

- 将来源与目标域显式绑定到行动所属XResourceContext，避免根据BattleManager残留subject推测。现有battle_logic.apply为每次行动新建resources并恢复上层资源对象；嵌套行动的上下文同样独立。
- eligible只在来源Boss输出倍率>1、目标不是来源，且处于当前单目标／targets域时成立；纯gain／set入口只对损失生效。普通executeHp／MpDamage的非自身正值无论倍率是否1都floor，保留已交原版边界。
- settled按目标＋资源种类保护普通伤害入口，direct保护gain→set嵌套链；缩放发生在已有减伤与护盾之前。HP结算不能遮住嵌套MP，域外目标不能借用父栈目标。
- 作用域栈须成对恢复。先确认GDScript当前宿主能保证的正常返回／诊断退出路径；禁止将未支持脚本当成功、不能把同一个Dictionary长期挂进全局。对预览／克隆的来源与域也须留隔离验证。
- 已有XResourceContext.gain执行护盾、写结果槽，再set与refresh；silent_gain无结果槽。当前没有专用set入口，直接属性赋值不自动触发原版set语义。不得仅对gain加倍率就宣称set下降已完成。
- formula_execution.gd目前把已翻译副作用转给resources.gain；本轮只读确认此入口，未获交接，不改该文件。若set能力需要扩此宿主，先给明确诊断／保留项，不能绕过边界。state_effects的资源能力已有同一resources接口，可在授权文件内接线。

## 依赖与未完成

- 普通输出数值实现00524617；最终验收ec75a3b1。普通输出每次已缩放值在后续gain／set不可再次放大。
- 上一期Boss属性／生命周期04e54453及更早全部已交范围不重做；前期权能五本、容量满返书＋预约1317、PREE-ASUP、WPNM／SkEType与race-battle等接口沿用旧单。未交接formula_execution／mv_event_core、两块TP Apply、敌人永久账本继续留空。
- 所有本车道提交待Claude核查，不销自己的核查、不自评完成度；共用交接板／变更记录／步骤清单／当前状态只读。

## 可优化

- 普通输出已独立交付后才进入复杂上下文；后续新增参照先跑宿主冒烟小样，再扩矩阵。保留每次失败的精简原因和原版原件，不把测试快照错误归为数值差异或偶发。

## 额度停手（2026-10-25）

- 最后实查五小时95%、周45%；按用户95%保存停手规则收尾，本次不是上下文接力，不创建后续会话或automation。预设计72d612bc已WIP保存，本节提交后以最新HEAD为准；工作区干净，无在途长任务／前台等待。
- 普通输出可合并分支仍为codex/passive-content-boss-output（ec75a3b1），完整78组参照、六场8588项验证与待Claude核查均已交，不因当前设计WIP而撤销已交范围。当前分支codex/passive-content-boss-context，唯一工作树仍state-effects-2b，保留全部.sandbox和generated。
- 恢复时先实查额度；按本单先补行动直接gain／set新参照，再推进。不要重做旧29组／8场、78组／六场或338组；此次未新增数值规则，未产生新的同步需求。
