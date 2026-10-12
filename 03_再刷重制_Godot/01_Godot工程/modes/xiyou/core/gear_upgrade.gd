class_name XGearUpgrade
extends RefCounted
## YEP 升级插槽：先完整检查条件与效果再扣物品/槽位；支持数值、元素、命中暴击与打孔。
## <Upgrade Effect> 在正式插件没有被识别（仅 Weapon/Armor Effect 生效），保持不可操作并报告转换问题。
static func rule(item: Dictionary) -> Dictionary:
	return item.get("upgrade",{})

static func reason(gear: Dictionary, item: Dictionary, count: int) -> String:
	var data := rule(item)
	if data.is_empty() or not data.get("issues",[]).is_empty():return "这件材料没有可用的强化效果"
	var kind := str(gear.get("kind",""))
	if not kind in ["weapon","armor"] or data.get(kind,[]).is_empty():return "不能用于这类装备"
	var types: Array = data.get(kind+"Types",[]).map(func(v):return int(v))
	var type := int(gear.get("wtypeId" if kind == "weapon" else "atypeId",0))
	if not types.has(0) and not types.has(type):return "装备类型不符"
	if count <= 0:return "没有这件材料"
	if int(gear.get("upgradeSlots",6)) < int(data.get("cost",1)):return "强化插槽不足"
	for effect in data[kind]:
		if effect.op == "slots":
			var cap := int(XDB.plugin("YEP_X_ItemUpgradeSlots").get("MAX Slots",12))
			if int(gear.get("originalUpgradeSlots",6)) >= cap and int(effect.value) > 0:return "已达到插槽上限"
			if int(gear.get("originalUpgradeSlots",6)) <= 0 and int(effect.value) < 0:return "没有可移除的插槽"
	return ""

static func preview(gear: Dictionary, item: Dictionary) -> Dictionary:
	var copy := gear.duplicate(true)
	if reason(copy,item,1) == "":apply_effects(copy,item,false)
	return copy

static func apply(s: XState, gear: Dictionary, item_id: int) -> bool:
	var item := XDB.rec("Items",item_id)
	if not s.owns_gear(gear) or reason(gear,item,s.item_count(item_id)) != "":return false
	# 在副本完成全部计算，随后一次性替换实例内容；引用该实例的角色会看到同一结果。
	var copy := gear.duplicate(true)
	apply_effects(copy,item,true)
	s.gain_item(item_id,-1)
	gear.clear();gear.merge(copy,true)
	for a in s.members():
		a.refresh_passive()
		a.hp = minf(a.hp,a.mhp);a.mp = minf(a.mp,a.mmp)
	return true

static func apply_effects(gear: Dictionary, item: Dictionary, randomize := true) -> void:
	var data := rule(item)
	gear.upgradeSlots = int(gear.get("upgradeSlots",6)) - int(data.cost)
	gear.originalUpgradeSlots = int(gear.get("originalUpgradeSlots",6))
	gear.boostCount = int(gear.get("boostCount",0)) + int(data.boost)
	var history: Array = gear.get("upgrades",[])
	history.append({"item":int(item.id),"name":str(item.name),"cost":int(data.cost)})
	gear.upgrades = history
	for effect in data[str(gear.kind)]:
		match str(effect.op):
			"param":
				var ids: Array = range(8) if effect.param is String else [int(effect.param)]
				for i in ids:
					if effect.param is String and effect.param == "current" and float(gear.params[i]) == 0:continue
					var n := float(effect.value)
					if bool(effect.get("random",false)):
						n = (floorf(XGear.roll() * ((n+1)*2)-n) if not bool(effect.get("signed",false)) else (floorf(XGear.roll() * (n+signf(n))))) if randomize else 0.0
					if bool(effect.get("percent",false)):
						var base := XDB.rec("Weapons" if gear.kind == "weapon" else "Armors",int(gear.base))
						n *= float(base.params[i]) / 100
					gear.params[i] = float(gear.params[i]) + n
			"element":
				var yep: Dictionary = gear.get("yep",{})
				var pool: Dictionary = yep.get("elementAmplify",{})
				var key := str(int(effect.element))
				pool[key] = float(pool.get(key,0)) + float(effect.value)
				yep.elementAmplify = pool;gear.yep = yep
			"xparam":
				var found := false
				for t in gear.traits:
					if int(t.code) == 22 and int(t.dataId) == int(effect.param):
						t.value = float(t.value) + float(effect.value); found = true; break
				if not found:gear.traits.append({"code":22.0,"dataId":float(effect.param),"value":float(effect.value)})
			"slots":
				gear.upgradeSlots += int(effect.value)
				gear.originalUpgradeSlots += int(effect.value)
				gear.boostCount -= 1;gear.upgrades.pop_back()
	XRunewords.check(gear)
	var name := str(gear.get("runewordName",""))+str(gear.get("baseName",gear.name))
	gear.name = name + (" (+%d)" % int(gear.boostCount) if int(gear.boostCount) > 0 else "")
