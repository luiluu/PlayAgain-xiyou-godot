class_name XRunewords
extends RefCounted
## 正式 v0.05 的结尾匹配规则：最长配方优先，每件装备只形成一条符文之语。
static func template_id(recipe: Dictionary, gear: Dictionary) -> int:
	if gear.kind=="weapon" and recipe.weaponTypes.map(func(v):return int(v)).has(int(gear.wtypeId)):return int(recipe.weapon)
	if gear.kind=="armor" and int(gear.atypeId)>0 and recipe.armorSlots.map(func(v):return int(v)).has(int(gear.etypeId)):return int(recipe.armor)
	return 0
static func check(gear: Dictionary) -> void:
	if not gear.get("runewords",[]).is_empty():return
	var materials: Array=gear.get("upgrades",[]).map(func(u):return int(u.item))
	var best := {}
	for recipe in XDB.table("Runewords"):
		if not recipe is Dictionary or template_id(recipe,gear)==0:continue
		var ids: Array=recipe.materials.map(func(v):return int(v))
		if ids.is_empty() or ids.size()>materials.size():continue
		if materials.slice(materials.size()-ids.size())!=ids:continue
		if best.is_empty() or ids.size()>best.materials.size():best=recipe
	if best.is_empty():return
	var tpl:=XDB.rec("Weapons" if gear.kind=="weapon" else "Armors",template_id(best,gear))
	if tpl.is_empty():return
	for i in range(8):gear.params[i]=float(gear.params[i])+float(tpl.params[i])
	gear.traits.append_array(tpl.traits.duplicate(true))
	var numeric:=RegEx.create_from_string("^\\s*(-?\\d+(?:\\.\\d+)?)\\s*(%?)\\s*$")
	for m in RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>").search_all(str(tpl.note)):
		var key:=m.get_string(1)
		if m.get_string(2)!=":":gear.meta[key]=true;continue
		var old:=numeric.search(str(gear.meta.get(key,"")));var extra:=numeric.search(m.get_string(3))
		gear.meta[key]=" "+str(float(old.get_string(1))+float(extra.get_string(1)))+(old.get_string(2) if old.get_string(2)!="" else extra.get_string(2)) if old and extra else m.get_string(3)
	gear.note=str(gear.note)+"\n"+str(tpl.note)
	XGear.merge_yep(gear,tpl)
	gear.runewordName=str(tpl.name)
	gear.runewords=[int(best.id)]

	gear.name=str(gear.runewordName)+str(gear.get("baseName",gear.name))+(" (+%d)"%int(gear.boostCount) if int(gear.boostCount)>0 else "")
