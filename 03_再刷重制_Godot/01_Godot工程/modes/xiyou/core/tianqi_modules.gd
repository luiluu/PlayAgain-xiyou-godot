class_name XTianqiModules
extends RefCounted
## 天启篇技能重构第七期：专属模块角色（167～179）在天启篇的汇总入口。各模块的数值分支写在模块自己的文件里
## （都用 XTianqiSkills.cards_on() 判断，原版档不走）；这里只放要统一调一次的入口：
## - battle_start：XTianqiSkills.start_turns 开战时逐个角色调（渡鸦法宝开局残响、米拉黑日焚界准备回合……）。
## - damage_ops：XActorDamageHooks.capture 里接在 XTianqiSkills.module_ops（模块增伤乘区收口）之后，各模块按稿子给的
##   预算内加成（段数折算、扩散比例、条件增伤、受伤减免），所以不会被收口去掉。


static func battle_start(a, party: Array, foes: Array) -> void:
	if not (a is XActor) or not XTianqiSkills.cards_on():
		return
	match int(a.actor_id):
		167:
			XRaven.tq_battle_start(a)
		168:
			XMira.tq_battle_start(a)
		175:
			XGuyu.tq_battle_start(a)


static func damage_ops(item: Dictionary, a, b) -> Array:
	if not XTianqiSkills.cards_on() or XBattleLogic.is_item(item):
		return []
	return XMira.tq_ops(item, a, b) + XYomiJingliu.tq_ops(item, a, b) + XSukuna.tq_ops(item, a, b) + XGarou.tq_ops(item, a, b) + XYunshang.tq_ops(item, a, b) + XTusu.tq_ops(item, a, b) + XXuanBattle.tq_ops(item, a, b) + XCat.tq_ops(item, a, b) + XLiuying.tq_ops(item, a, b)
