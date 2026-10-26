class_name XPassiveBooks
extends RefCounted
## Frozen Game_Action.itemEffectLearnSkill: type5 uses selected actor.skills(), not actor.learnSkill.
const LIMIT_EVENT := 1317

static func learned(a: XActor) -> Array:
	return a.skills().filter(func(k): return int(k.get("stypeId",0)) == 5).map(func(k): return int(k.id))

static func refund_if_full(s: XState, skill_id: int, item: Dictionary) -> bool:
	if s == null or int(XDB.rec("Skills",skill_id).get("stypeId",0)) != 5:
		return false
	# The native menu sets this before applying the effect. Direct actor learning never comes here.
	if s.item_target_actor_id <= 0 or XDB.rec("Actors",s.item_target_actor_id).is_empty():
		return false
	if learned(s.actor(s.item_target_actor_id)).size() < float(s.variable(9)):
		return false
	s.gain_item(int(item.get("id",0)),1)
	s.reserve_common_event(LIMIT_EVENT)
	s.set_meta("capacity_refund",int(item.get("id",0)))
	return true

static func limit_message(s: XState) -> String:
	return s.actor(s.item_target_actor_id).display_name() + " 能学习的抽奖被动技能已经达到" + MVScript.js_number(s.variable(9)) + "上限！"


## Scope: only a type5 book rejected by this effect. Other event items keep their existing route.
static func begin_item(s: XState) -> void:
	if s.has_meta("capacity_refund"):
		s.remove_meta("capacity_refund")

static func remember_return(s: XState, item: Dictionary, category: int, index: int) -> void:
	var rejected := int(s.get_meta("capacity_refund",0))
	begin_item(s)
	if rejected <= 0 or rejected != int(item.get("id",0)) or s.peek_common_event() != LIMIT_EVENT:
		return
	s.set_meta("capacity_bag_return",{"map":s.map_id,"item":rejected,"category":category,"index":index,
		"message":"事件已执行："+str(item.get("name",""))+"（未检测到可确认的变化）"})

static func take_return(s: XState) -> Dictionary:
	var saved: Dictionary = s.get_meta("capacity_bag_return",{})
	if s.has_meta("capacity_bag_return"):
		s.remove_meta("capacity_bag_return")
	if s != XState.current or saved.is_empty() or int(saved.map) != s.map_id or s.peek_common_event() > 0:
		return {}
	return saved
