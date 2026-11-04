class_name XLifeSteal
## 【cc·哪吒·未经审查】YEP_LifeSteal 技能吸血（O-待定）。参照 mv_oracle/life_steal_probe.cjs（tests/fixtures/life_steal_oracle.json，正式引擎）。
##
## 原版：Game_Action.executeHpDamage 包装（装在 YEP_DamageCore 之外、AbsorptionBarrier／ShieldSystem／各 codex 运行时之内），内层扣完血后读
## target._result.hpDamage（＝护盾、真气等外层先减过的实际伤害，不被目标剩余生命夹住；内层没写结果就是 0），>0 时行动者 lifeSteal：
##   rate = 1-(1-(1-(1-N×0.01)))，吸血量 = max(0, floor(伤害×(1-rate)+flat))；≤0 就什么也不做；
##   再依次乘行动者每个状态备注 <DBHPLSteal: N%>（必须带 %，不带的被插件忽略）的 N/100（浮点，最后才取整）；
##   角色（不是敌人）再按 状态→装备→技能 的顺序，对每件物品备注里第一条 <RecPushStateX: P%> 掷一次（Math.random()×100<P）挂状态给自己（已有也再挂一次）；
##   最后 gainHp(floor(吸血量))。吸血回的血不封顶（超出 mhp 的部分被夹掉），敌人行动者也吸，反射／反击／掩护里谁是行动者谁吸，多段命中每段各吸一次。
## 只实现冻结数据里真有的：技能 <HP Life Steal: N%>（转换器 parse_life_steal 写进 lifeSteal.hpRate，另转 hpFlat／allNull／hpNull）。
## 角色／职业／装备／状态层的 LIFE STEAL Rate／Flat／CUSTOM／GUARD／CANCEL、MP 吸血、Negative／Overheal 参数（都是 false）在数据里一条都没用，不实现。


## 吸血量（未取整、已乘 DBHPLSteal）。没有吸血标签、被 CANCEL、伤害 ≤0、命中类型不明、吸到 ≤0：返回 0。
static func amount(u: XBattler, item: Dictionary, damage: float) -> float:
	var ls: Dictionary = item.get("lifeSteal", {})
	if ls.is_empty() or bool(ls.get("allNull", false)) or bool(ls.get("hpNull", false)) or damage <= 0.0:
		return 0.0
	if not int(item.get("hitType", 0)) in [0, 1, 2]:
		return 0.0
	# Game_Action.getLifeStealRate／getLifeStealFlat → Game_Battler.lifeSteal，浮点运算次序照原样（1-(1-x) 不等于 x）
	var rate_item := 1.0 - (1.0 - float(ls.get("hpRate", 0.0)))
	var rate := 1.0 - rate_item
	var steal := maxf(0.0, floorf(damage * (1.0 - rate) + float(ls.get("hpFlat", 0))))
	if steal <= 0.0:
		return 0.0
	var re := RegEx.create_from_string("(-?\\d+)(%?)")
	for st in u.states():
		var m := re.search(str(st.get("meta", {}).get("DBHPLSteal", "")))
		if m != null and m.get_string(2) == "%":
			steal *= float(m.get_string(1)) / 100.0
	return steal


## 吸血时角色自己掷的 RecPushState：状态→装备→技能，每件物品备注里第一条。敌人没有。
static func push_rows(u: XBattler) -> Array:
	var out := []
	if not (u is XActor):
		return out
	var re := RegEx.create_from_string("<RecPushState(\\d+): ([-]?\\d+)%>")
	var objects := []
	objects.append_array(u.states())
	objects.append_array((u as XActor).equip_list())
	objects.append_array(u.skills())
	for obj in objects:
		var m := re.search(str(obj.get("note", "")))
		if m != null:
			out.append({"stateId": int(m.get_string(1)), "probability": float(m.get_string(2))})
	return out
