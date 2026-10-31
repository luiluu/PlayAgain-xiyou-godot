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
	return true

static func limit_message(s: XState) -> String:
	return s.actor(s.item_target_actor_id).display_name() + " 能学习的抽奖被动技能已经达到" + MVScript.js_number(s.variable(9)) + "上限！"
