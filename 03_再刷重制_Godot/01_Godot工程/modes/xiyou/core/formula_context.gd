class_name XFormulaContext
extends RefCounted
## Trusted adapter: expressions only see detached dictionaries, never battler methods.
const PROPERTIES := "hp mp tp mhp mmp atk def mat mdf agi luk level hit eva cri cev mev mrf cnt hrg mrg trg tgr grd rec pha mcr tcr pdr mdr fdr exr shield"

static var _plans := {}

static func row(b: XBattler, skill_id := 0, requirements := {}) -> Dictionary:
	var p := {}
	var names: Array = requirements.get("properties", {}).keys() if requirements.has("bounded") else Array(PROPERTIES.split(" "))
	var methods: Dictionary = requirements.get("methods", {})
	for name in names:
		p[name] = b.get(name)
	var elements := {}
	for i in (range(XDB.system().get("elements", []).size()) if not requirements.has("bounded") or methods.has("element") else []):
		elements[str(i)] = b.element_rate(i)
	var gear := []
	if b is XActor and (not requirements.has("bounded") or methods.has("equipment_level")):
		for item in b.equip_list():
			gear.append({"kind": str(item.get("kind", "")), "baseItemId": int(item.get("base", item.get("id", 0))),
				"instanceLevel": XEquipmentView.level(item)})
	return {"properties": p, "elements": elements, "mastery": {str(skill_id): b.skillMasteryLevel(skill_id)} if not requirements.has("bounded") or methods.has("mastery") else {},
		"stateIds": b.state_ids.duplicate() if not requirements.has("bounded") or methods.has("has_state") else [], "states": b.states().map(func(s): return s.id) if not requirements.has("bounded") or methods.has("states_count") else [], "equipment": gear,
		"maxTp": b.max_tp() if not requirements.has("bounded") or methods.has("max_tp") else 200.0, "actorId": b.actor_id if b is XActor else null,
		"param": range(8).map(func(i): return b.param(i)) if not requirements.has("bounded") or methods.has("param") else [], "xparam": range(10).map(func(i): return b.xparam(i)) if not requirements.has("bounded") or methods.has("xparam") else [],
		"sparam": range(10).map(func(i): return b.sparam(i)) if not requirements.has("bounded") or methods.has("sparam") else []}

static func _collect(node, plan: Dictionary) -> void:
	if node is Dictionary:
		var op := str(node.get("op", ""))
		if op in ["property", "read"]:
			var req: Dictionary = plan[str(node.receiver)]
			if op == "property":
				req.properties[str(node.name)] = true
			else:
				req.methods[str(node.name)] = true
				if node.name in ["hp_rate", "mp_rate"]:
					for field in (["hp", "mhp"] if node.name == "hp_rate" else ["mp", "mmp"]):
						req.properties[field] = true
		for key in node:
			_collect(node[key], plan)
	elif node is Array:
		for child in node:
			_collect(child, plan)

static func capture(a: XBattler, b: XBattler, variables, switches := {}, skill_id := 0, program := {}) -> Dictionary:
	var req := {}
	if not program.is_empty():
		var key: String = program.source.sha256
		if not _plans.has(key):
			var plan := {"a": {"bounded": true, "properties": {}, "methods": {}}, "b": {"bounded": true, "properties": {}, "methods": {}}}
			_collect(program.steps, plan)
			_plans[key] = plan
		req = _plans[key]
	var first := row(a, skill_id, req.get("a", {}))
	var second := row(b, skill_id, req.get("b", {}))
	if a == b:
		first.properties.merge(second.properties)
		first.elements.merge(second.elements)
		for field in ["param", "xparam", "sparam"]:
			if first[field].is_empty():
				first[field] = second[field]
		second = first
	return {"a": first, "b": second, "v": variables, "s": switches}

static func clone_battler(b: XBattler) -> XBattler:
	# GDScript variables have SCRIPT_VARIABLE but no STORAGE bit. Derived parameter
	# getters share that flag, so exclude the read-only parameter facade explicitly.
	var out: XBattler = b.get_script().new()
	for property in b.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and (not str(property.name) in PROPERTIES.split(" ") or str(property.name) in ["hp", "mp", "tp", "shield"]):
			if str(property.name) == "state_origins":
				continue  # 指向其他战斗者的状态来源（导入角色平衡的持续伤害用），预览克隆不需要
			var value = b.get(property.name)
			if not XFormulaProgram._detached(value):
				return null
			out.set(property.name, value.duplicate(true) if value is Array or value is Dictionary else value)
	for key in b.get_meta_list():
		var value = b.get_meta(key)
		if not XFormulaProgram._detached(value):
			return null
		out.set_meta(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	return out
