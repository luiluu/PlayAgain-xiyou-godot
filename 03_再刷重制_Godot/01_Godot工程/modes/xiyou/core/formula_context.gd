class_name XFormulaContext
extends RefCounted
## Trusted adapter: expressions only see detached dictionaries, never battler methods.
const PROPERTIES := "hp mp tp mhp mmp atk def mat mdf agi luk level hit eva cri cev mev mrf cnt hrg mrg trg tgr grd rec pha mcr tcr pdr mdr fdr exr"

static func row(b: XBattler, skill_id := 0) -> Dictionary:
	var p := {}
	for name in PROPERTIES.split(" "):
		p[name] = b.get(name)
	var elements := {}
	for i in range(XDB.system().get("elements", []).size()):
		elements[str(i)] = b.element_rate(i)
	var gear := []
	if b is XActor:
		for item in b.equip_list():
			gear.append({"kind": str(item.get("kind", "")), "baseItemId": int(item.get("base", item.get("id", 0))),
				"level": float(item.get("level", item.get("boostCount", 0)))})
	return {"properties": p, "elements": elements, "mastery": {str(skill_id): b.skillMasteryLevel(skill_id)},
		"stateIds": b.state_ids.duplicate(), "states": b.states().map(func(s): return s.id), "equipment": gear,
		"maxTp": b.max_tp(), "actorId": b.actor_id if b is XActor else null,
		"param": range(8).map(func(i): return b.param(i)), "xparam": range(10).map(func(i): return b.xparam(i)),
		"sparam": range(10).map(func(i): return b.sparam(i))}

static func capture(a: XBattler, b: XBattler, variables, switches := {}, skill_id := 0) -> Dictionary:
	var first := row(a, skill_id)
	return {"a": first, "b": first if a == b else row(b, skill_id), "v": variables, "s": switches}

static func clone_battler(b: XBattler) -> XBattler:
	# GDScript variables have SCRIPT_VARIABLE but no STORAGE bit. Derived parameter
	# getters share that flag, so exclude the read-only parameter facade explicitly.
	var out: XBattler = b.get_script().new()
	for property in b.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and (not str(property.name) in PROPERTIES.split(" ") or str(property.name) in ["hp", "mp", "tp"]):
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
