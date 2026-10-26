class_name XPowerBooks
extends RefCounted
## Native Honghuang power learning/forgetting and Economy CodexParamRate.
## Rules measured through real native hosts; UI is a separate XChoiceWindow flow.
const FORGET_ITEM := 3044
const STRONG_IDS := [1, 8, 9, 10, 11, 13, 17, 38, 45, 47, 50, 59, 70, 71, 82, 84, 85, 92, 93, 95, 99, 109, 110, 111, 112, 113, 114, 115, 117, 118, 119, 128, 129, 130, 131, 170]
static var _skills: Array = []
static var _rates := {}

static func skills() -> Array:
	if _skills.is_empty():
		var pattern := RegEx.create_from_string("<CodexPower:\\s*\\d+>")
		for item in XDB.table("Items"):
			if not item is Dictionary or pattern.search(str(item.get("note", ""))) == null:
				continue
			for e in item.get("effects", []):
				if int(e.code) == 43 and not _skills.has(int(e.dataId)):
					_skills.append(int(e.dataId))
	return _skills.duplicate()

## Scene_ItemBase.onActorOk recognizes tagged power books before target validity.
static func book_skill(item: Dictionary) -> int:
	if RegEx.create_from_string("<CodexPower:\\s*\\d+>").search(str(item.get("note",""))) == null:
		return 0
	for effect in item.get("effects",[]):
		if int(effect.code) == 43 and is_power(int(effect.dataId)):
			return int(effect.dataId)
	return 0

static func is_power(id: int) -> bool:
	return skills().has(id)

static func learned(a: XActor) -> Array:
	return skills().filter(func(id): return a.skill_ids.has(id)) if a != null else []

static func actor_class(a: XActor) -> String:
	if XItemMarks.SUPER_STRONG_IDS.has(a.actor_id):
		return "超强者"
	return "强者" if STRONG_IDS.has(a.actor_id) else "弱者"

static func limit(a: XActor) -> int:
	return {"超强者":3, "强者":4, "弱者":6}[actor_class(a)]

static func learn_reason(a: XActor, id: int) -> String:
	if a == null:
		return "请选择角色"
	var ids := learned(a)
	if ids.has(id):
		return "已经学会这项权能"
	if ids.size() >= limit(a):
		return actor_class(a) + "最多学习" + str(limit(a)) + "本权能书，请先遗忘已有权能"
	return ""

static func can_learn(a: XActor, id: int) -> bool:
	return is_power(id) and learn_reason(a, id).is_empty()

## Plain native forgetSkill protects only the canonical Game_Actors instance.
## A preview clone retains its own learned skills and can forget them locally.
static func protected_forget(a: XActor, id: int) -> bool:
	return is_power(id) and XState.current != null and XState.current.actors.get(a.actor_id) == a

## No persistent permit flag: the dedicated paid operation owns this one erasure.
static func forget_paid(s: XState, a: XActor, id: int) -> Dictionary:
	if a == null or not learned(a).has(id):
		return {"ok":false, "reason":"角色尚未学会这项权能"}
	if s.item_count(FORGET_ITEM) <= 0:
		return {"ok":false, "reason":"缺少权能遗忘符"}
	a.skill_ids.erase(id)
	s.gain_item(FORGET_ITEM, -1)
	a.refresh_passive()
	a.refresh_resources()
	return {"ok":true}

## Native Economy wraps paramRate, before the param's clamp and rounding.
## Only learned skills contribute, with all matching entries summed per param.
static func param_rate_bonus(a: XActor, param: int) -> float:
	var sum := 0.0
	for id in a.skill_ids:
		if not _rates.has(id):
			var values := {}
			var hit := RegEx.create_from_string("(?i)<CodexParamRate:\\s*([^>]+)>").search(str(XDB.rec("Skills", id).get("note", "")))
			if hit != null:
				for entry in hit.get_string(1).split(","):
					var pair := entry.split(":")
					if pair.size() < 2 or not pair[0].strip_edges().is_valid_float() or not pair[1].strip_edges().is_valid_float():
						continue
					var index := int(float(pair[0]))
					if index >= 0 and index < 8:
						values[index] = float(values.get(index, 0.0)) + float(pair[1])
			_rates[id] = values
		sum += float(_rates[id].get(param, 0.0))
	return sum
