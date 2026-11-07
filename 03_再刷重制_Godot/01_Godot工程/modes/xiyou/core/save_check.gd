class_name XSaveCheck
## 读档前的深层类型检查（审计第 10 项）：按 XState.from_dict 及其调用的各 from_save、读完马上跑的包装
## （XPets.loaded 等）实际读取的方式逐字段查。GDScript 没有异常，坏字段在 from_dict 半途报脚本错时，
## 全局账本已经清掉、新状态只建了一半；所以凡是会让 int()／float()／bool()／Array()、字典下标或
## 有类型成员赋值出错的形状都在这里先拒掉，XSave.valid_data 不过就不进 from_dict。
## 只拒「会出错」的形状，不收紧本来能读的旧档（缺省的可选字段、字符串数字照旧放行）。
## 改 from_dict 或各 from_save 的读法时，同步改这里；tests/xiyou_save_corrupt 每类各有样例。


## int()／float() 能接受的标量（JSON 数字都是 float；字符串、布尔转换也不报错）
static func scalar(v) -> bool:
	return v is int or v is float or v is String or v is bool


## bool() 能接受的：布尔或数字
static func boolish(v) -> bool:
	return v is bool or v is int or v is float


static func scalars(v) -> bool:
	return v is Array and v.all(scalar)


static func scalar_values(v) -> bool:
	return v is Dictionary and v.values().all(scalar)


## 可选字段：没有、或值通过 f
static func opt(d: Dictionary, key: String, f: Callable) -> bool:
	return not d.has(key) or f.call(d[key])


## for k in x 能迭代、又不会在 x[k] 上出错的：只收字典
static func dict_or_absent(d: Dictionary, key: String) -> bool:
	return opt(d, key, func(v): return v is Dictionary)


static func actor_row(row: Dictionary) -> bool:
	for f in ["skills", "states"]:
		if not scalars(row.get(f)):
			return false
	for f in ["stateTurns", "cooldowns", "classExp", "masteryLevels", "masteryUses"]:
		# masteryLevels／Uses 不是字典时 from_save 跳过；是字典就逐值转数字
		if row.has(f) and row[f] is Dictionary and not scalar_values(row[f]):
			return false
	for f in ["stateTurns", "cooldowns", "classExp"]:
		if not dict_or_absent(row, f):
			return false
	for f in ["buffs", "buffTurns"]:
		if not opt(row, f, scalars):
			return false
	for f in ["level", "exp", "hp", "mp", "tp", "lastBattleSkill"]:
		if not opt(row, f, scalar):
			return false
	var z = row.get("zhenqi")
	if z is Dictionary:
		if not (opt(z, "qi", scalar) and opt(z, "realm", scalar) and opt(z, "pending", scalars)):
			return false
		if z.has("firsts") and not (z.firsts is Dictionary or z.firsts is Array):
			return false
		if not opt(z, "daofa", scalar_values):
			return false
		if z.get("daofaStages") is Dictionary and not scalar_values(z.daofaStages):
			return false
	return true


static func top(d: Dictionary) -> bool:
	if not scalar_values(d.get("items")):
		return false
	if not d.switches.values().all(boolish):
		return false
	for k in ["lastItem", "nextGearId", "saveCount", "orbSeed", "hangUpTotal", "playerMoveSpeed", "actorMaxLevel"]:
		if not opt(d, k, scalar):
			return false
	if d.get("unknownOrigin") != null and not scalar(d.unknownOrigin):
		return false
	for k in ["followersVisible", "encounterEnabled", "allowAutosave"]:
		if not opt(d, k, boolish):
			return false
	# 有类型的字典成员直接赋值：换成别的类型就报错
	for k in ["dungeon", "bossMastery", "raceSupply", "ecoFrac", "hangUp", "flags"]:
		if not dict_or_absent(d, k):
			return false
	if d.has("orbState"):
		var os = d.orbState
		if not os is Dictionary or not opt(os, "recent", func(v): return v is Array):
			return false
		for k in ["n", "returns", "inbox"]:
			if not opt(os, k, scalar_values):
				return false
	if d.has("rom"):
		for k in ["x", "xs", "g", "m"]:
			if not opt(d.rom, k, scalars):
				return false
		for k in ["xn", "xsn", "gn"]:
			if not opt(d.rom, k, scalar):
				return false
	var dg = d.get("designation")
	if dg is Dictionary and dg.has("name") and not (dg.has("color") and scalar(dg.get("icon"))):
		return false
	for op in d.get("actorOps", []):
		if not op is Dictionary or not op.has("op") or not scalar(op.get("skill")):
			return false
		if not (opt(op, "ids", scalars) and opt(op, "exclude", scalars) and opt(op, "from", scalar) and opt(op, "named", boolish)):
			return false
	for k in ["unlockedMaps", "erasedEvents", "costumeOff"]:
		if not opt(d, k, scalars):
			return false
	if not opt(d, "pingbiQuality", func(v): return v is Array and v.all(boolish)):
		return false
	if d.get("vehicles") is Array:
		for v in d.vehicles:
			if v is Dictionary:
				for k in ["mapId", "x", "y", "direction", "characterIndex", "altitude"]:
					if not opt(v, k, scalar):
						return false
				if not opt(v, "driving", boolish):
					return false
	if d.get("screen") is Dictionary:
		var sc: Dictionary = d.screen
		for k in ["tone", "toneTarget"]:
			if sc.get(k) is Array and sc[k].size() == 4 and not scalars(sc[k]):
				return false
		for k in ["toneDuration", "weatherPower", "weatherPowerTarget", "weatherDuration"]:
			if not opt(sc, k, scalar):
				return false
	return warehouse(d.get("phwarehouse")) and subsystems(d)


## XWarehouse.from_save：仓库项要么是装备（登记时读 kind／base），要么是数字
static func warehouse(raw) -> bool:
	if not raw is Dictionary:
		return true
	for title in raw:
		var w = raw[title]
		if not w is Dictionary:
			continue
		if not dict_or_absent(w, "items") or not dict_or_absent(w, "qtty"):
			return false
		for k in ["maxCapacity", "currentCapacity"]:
			if not opt(w, k, scalar):
				return false
		if not opt(w, "lootBonus", boolish):
			return false
		for cat in XWarehouse.CATEGORIES:
			var list = w.get("items", {}).get(cat, [])
			if not list is Array or not list.all(func(v): return XSave._valid_gear(v) or scalar(v)):
				return false
			var q = w.get("qtty", {}).get(cat, {})
			if q is Dictionary and not scalar_values(q):
				return false
	return true


static func subsystems(d: Dictionary) -> bool:
	if d.get("saveactors") is Array and not d.saveactors.all(func(v): return v == null or scalar(v)):
		return false
	var pc = d.get("playerCostume")
	if pc is Dictionary and pc.has("characterName") and not opt(pc, "characterIndex", scalar):
		return false
	var rv = d.get("codexRaven")
	if rv is Dictionary and not (opt(rv, "soul", scalar) and opt(rv, "forged", scalar) and opt(rv, "residue", scalar) and opt(rv, "hunter", boolish)):
		return false
	var gr = d.get("codexGarou")
	if gr is Dictionary and not (opt(gr, "breakthroughs", scalar) and opt(gr, "catalyst", boolish)):
		return false
	var ss = d.get("shopStock")
	if ss is Dictionary:
		var inv = ss.get("inv", {})
		if inv is Dictionary:
			for g in inv:
				var row = inv[g]
				if not row is Dictionary:
					continue
				if not dict_or_absent(row, "stock") or not row.get("stock", {}).values().all(scalar_values):
					return false
				if row.get("speed") != null and not scalar(row.speed):
					return false
		if not opt(ss, "schedules", func(v): return v is Array):
			return false
		for sc in ss.get("schedules", []):
			if sc is Dictionary and not (opt(sc, "kind", scalar) and opt(sc, "id", scalar) and opt(sc, "start", scalar)):
				return false
	# XPets：读完马上 war_pet／team_a_actor／loaded（推力逐项转数字、技能逐个读）
	var pt = d.get("pets")
	if pt is Dictionary:
		if not (opt(pt, "war", scalar) and opt(pt, "team_a", scalar)):
			return false
		var list = pt.get("list", [])
		if list is Array:
			if not list.all(func(p): return p is Dictionary):
				return false
			var i := int(pt.get("war", -1))
			if i >= 0 and i < list.size():
				var pet: Dictionary = list[i]
				if not (scalars(pet.get("push")) and pet.get("skills") is Array):
					return false
	return true
