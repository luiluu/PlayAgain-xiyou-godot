class_name XRunewords
extends RefCounted
## 正式 v0.05 的结尾匹配规则：最长配方优先，每件装备只形成一条符文之语；v0.62.12 起是更长配方开头时先挂起（decide）。
static func template_id(recipe: Dictionary, gear: Dictionary) -> int:
	if gear.kind=="weapon" and recipe.weaponTypes.map(func(v):return int(v)).has(int(gear.wtypeId)):return int(recipe.weapon)
	if gear.kind=="armor" and int(gear.atypeId)>0 and recipe.armorSlots.map(func(v):return int(v)).has(int(gear.etypeId)):return int(recipe.armor)
	return 0
## 有效配方（有材料、对这件装备有模板）
static func _recipes(gear: Dictionary) -> Array:
	return XDB.table("Runewords").filter(func(r): return r is Dictionary and not r.get("materials", []).is_empty() and template_id(r, gear) != 0)

static func _mats(r: Dictionary) -> Array:
	return r.materials.map(func(v): return int(v))

## RW.match：结尾匹配，取最长的配方
static func match_recipe(gear: Dictionary, materials: Array) -> Dictionary:
	var best := {}
	for recipe in _recipes(gear):
		var ids := _mats(recipe)
		if ids.size()>materials.size():continue
		if materials.slice(materials.size()-ids.size())!=ids:continue
		if best.is_empty() or ids.size()>best.materials.size():best=recipe
	return best

## RW.canGrow（v0.62.12，用户 2026-10-27 原版改动）：从第 start 颗起已镶的这段，是否还能沿某个更长的配方在剩余孔位里镶完
static func can_grow(gear: Dictionary, materials: Array, start: int, length: int) -> bool:
	var left := maxi(0, int(gear.get("upgradeSlots", 0)))
	if left == 0:
		return false
	var k := materials.size() - start
	var head := materials.slice(start)
	return _recipes(gear).any(func(r):
		var z := _mats(r)
		return z.size() > maxi(k, length) and z.size() - k <= left and z.slice(0, k) == head)

## RW.decide：刚做成的配方若是更长配方的开头、剩余孔位还够，先挂起（runewordPending 随装备存档）；
## 下一颗没接上更长配方、或孔用完时，结算挂起的那条
## O-308·符文之语挂起（跟到 v0.62.12）：false＝回到 v0.28，做成就结算（RW.match）
static var PENDING_V062 := true
static func decide(gear: Dictionary, materials: Array) -> Dictionary:
	var best := match_recipe(gear, materials)
	if not PENDING_V062:
		return best
	var c := {} if best.is_empty() else {"r": best, "start": materials.size() - best.materials.size()}
	var p = gear.get("runewordPending")
	if p is Dictionary:
		for r in XDB.table("Runewords"):
			if r is Dictionary and int(r.get("id", -1)) == int(p.get("id", -1)):
				var z := _mats(r)
				var st := int(p.get("start", 0))
				if not z.is_empty() and materials.slice(st, st + z.size()) == z and (c.is_empty() or z.size() >= c.r.materials.size()):
					c = {"r": r, "start": st}
				break
	if c.is_empty():
		gear.erase("runewordPending")
		return {}
	if can_grow(gear, materials, int(c.start), c.r.materials.size()):
		gear.runewordPending = {"id": int(c.r.id), "start": int(c.start)}
		return {}
	gear.erase("runewordPending")
	return c.r

static func check(gear: Dictionary) -> void:
	if not gear.get("runewords",[]).is_empty():return
	var materials: Array=gear.get("upgrades",[]).map(func(u):return int(u.item))
	var best := decide(gear, materials)
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
