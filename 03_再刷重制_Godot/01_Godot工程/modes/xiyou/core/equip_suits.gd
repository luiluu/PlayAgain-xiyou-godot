class_name XEquipSuits
extends RefCounted
## GT_EquipSuitCore 的累计件数门槛：满足的每个档位都同时生效，不把套装状态写进存档。
static func counts(a: XActor) -> Dictionary:
	var out := {}
	for e in a.equip_list():
		for id in e.get("equipment",{}).get("suits",[]):out[int(id)] = int(out.get(int(id),0)) + 1
	return out

static func active(a: XActor) -> Array:
	var out := []
	var defs: Array = XDB.table("EquipSuits")
	var pieces := counts(a)
	for id in pieces:
		if id <= 0 or id >= defs.size() or defs[id] == null:continue
		for b in defs[id].bonuses:
			if int(pieces[id]) >= int(b.requirePieces):out.append(b)
	return out

static func value(a: XActor, group: String, id: int, rate: bool) -> float:
	var result := 1.0 if rate else 0.0
	for b in active(a):
		var n := float(b[group + ("Rate" if rate else "Plus")][id])
		result = result * n if rate else result + n
	return result

static func ids(a: XActor, key: String) -> Array:
	var out := []
	for b in active(a):
		for id in b.get(key,[]):
			if not out.has(int(id)):out.append(int(id))
	return out

static func reward(members: Array, base: float, id: int) -> float:
	var plus := 0.0
	var rate := 1.0
	for a in members:
		plus += value(a,"bResult",id,false) / 100
		rate *= value(a,"bResult",id,true)
	var result := base * (1+plus) * rate
	return result if id == 2 else floorf(result)
