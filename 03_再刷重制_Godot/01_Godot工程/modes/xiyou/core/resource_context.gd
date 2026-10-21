class_name XResourceContext
extends RefCounted
## Explicit action-owned gain/set/refresh chain for the currently ported capabilities (ShieldSystem included).
## Result slots store requested deltas; journal stores actual changes separately.
var random: XRandomStream
var journal: Array = []
var slots := {}
var labels := {}
var error := ""
var preview := false

static func empty_result() -> Dictionary:
	return {"hpAffected": false, "hpDamage": 0.0, "mpDamage": 0.0, "tpDamage": 0.0,
		"success": false, "missed": false, "evaded": false, "critical": false, "addedStates": [], "removedStates": []}

static func popup_queue(r: Dictionary) -> Array:
	var out := []
	var base := {"hpAffected": r.hpAffected, "hpDamage": r.hpDamage, "mpDamage": r.mpDamage, "tpDamage": r.tpDamage,
		"missed": r.missed, "evaded": r.evaded, "addedStates": r.addedStates.duplicate(), "removedStates": r.removedStates.duplicate()}
	for kind in ["miss", "hp", "mp", "tp", "status"]:
		var active: bool = (r.missed or r.evaded) if kind == "miss" else r.hpAffected if kind == "hp" else r.mpDamage != 0 if kind == "mp" else r.tpDamage != 0 if kind == "tp" else not r.addedStates.is_empty() or not r.removedStates.is_empty()
		if not active:
			continue
		var row := base.duplicate(true)
		if kind != "hp": row.hpAffected = false
		if kind != "mp": row.mpDamage = 0.0
		if kind != "tp": row.tpDamage = 0.0
		if kind != "miss":
			row.missed = false
			row.evaded = false
		if kind != "status":
			row.addedStates = []
			row.removedStates = []
		else:
			row.hpDamage = 0.0
		out.append(row)
	return out

func result(b: XBattler) -> Dictionary:
	if not slots.has(b):
		slots[b] = empty_result()
	return slots[b]

func seed_result(b: XBattler, data: Dictionary) -> void:
	slots[b] = data.duplicate(true)
	for key in ["addedStates", "removedStates"]:
		slots[b][key] = slots[b][key].map(func(id): return int(id))

static func permanent(id: int) -> bool:
	var data := XDB.rec("States", id)
	var meta: Dictionary = data.get("meta", {})
	return meta.has("Permanent") or meta.has("永続ステート")

static func supported(b: XBattler) -> String:
	if b.has_meta("resource_hooks") and not b.get_meta("resource_hooks").is_empty():
		return "unregistered_resource_hooks"
	for state in b.states():
		if state.get("meta", {}).has("SC触发开关解除"):
			return "state_remove_switch_pending"
	return ""

func snapshot(b: XBattler) -> Dictionary:
	return {"resources": [b.hp, b.mp, b.tp], "caps": [b.mhp, b.mmp, b.max_tp()], "states": b.state_ids.duplicate(),
		"stateTurns": b.state_turns.duplicate(true), "buffs": b.buffs.duplicate(), "buffTurns": b.buff_turns.duplicate(),
		"alive": not b.state_ids.has(1), "dead": b.state_ids.has(1), "immortal": b.immortal,
		"result": result(b).duplicate(true)}

func gain(b: XBattler, resource: String, amount: float) -> Dictionary:
	if not error.is_empty():
		return {}
	if not resource in ["hp", "mp", "tp"] or is_nan(amount) or is_inf(amount):
		error = "invalid_resource_request"
		return {}
	var unsupported := supported(b)
	if not unsupported.is_empty():
		error = unsupported
		return {}
	var before := snapshot(b)
	var requested := amount
	var shown := amount
	# 扣血先吸收护盾，击穿后剩余减半。敌人走 ShieldSystem 的 gainHp 钩子，结果槽记减免后；角色的 gainHp 是
	# krz_state_re 在 Game_Actor 上的自有方法（盖过后装的 gainHp 钩子），结果槽记原值，由 setHp 钩子减免实际扣量。
	if resource == "hp" and amount < 0.0:
		amount = -b.absorb_shield(-amount)
		if not b is XActor:
			shown = amount
	var r := result(b)
	r[resource + "Damage"] = -shown
	if resource == "hp":
		r.hpAffected = true
	var old: float = b.get(resource)
	# YEP Core setters skip refresh for an exactly unchanged input, after gain writes slots.
	if old + amount != old:
		b.set(resource, old + amount)
		refresh(b)
	var after := snapshot(b)
	var entry := {"receiver": labels.get(b, "b"), "resource": resource, "requestedDelta": requested,
		"actualDelta": float(b.get(resource)) - old, "before": before, "after": after}
	journal.append(entry)
	return entry

## 公式 a.addShield(x)／b.addShield(x)：不写结果槽；逐句记录里 resource 记 shield，前后快照照常（快照不含护盾，另记 shieldBefore／shieldAfter）。
func add_shield(b: XBattler, amount: float) -> Dictionary:
	if not error.is_empty():
		return {}
	var before := snapshot(b)
	var old := b.shield
	b.add_shield(amount)
	var entry := {"receiver": labels.get(b, "b"), "resource": "shield", "requestedDelta": amount,
		"actualDelta": b.shield - old, "shieldBefore": old, "shieldAfter": b.shield, "before": before, "after": snapshot(b)}
	journal.append(entry)
	return entry

func silent_gain(b: XBattler, resource: String, amount: float) -> void:
	# MV gainSilentTp calls setTp/refresh without overwriting the formula's TP slot.
	var old: float = b.get(resource)
	if old + amount != old:
		b.set(resource, old + amount)
		refresh(b)

func refresh(b: XBattler) -> void:
	var resisted := b.traits_set(XBattler.TRAIT_STATE_RESIST)
	for id in b.state_ids.duplicate():
		if resisted.has(id):
			b.state_ids.erase(id)
			b.state_turns.erase(id)
	b.hp = clampf(b.hp, 0.0, b.mhp)
	b.mp = clampf(b.mp, 0.0, b.mmp)
	b.tp = clampf(b.tp, 0.0, b.max_tp())
	var r := result(b)
	if b.hp == 0.0 and not b.state_ids.has(1) and not b.immortal and not resisted.has(1) and not r.removedStates.has(1):
		b.hp = 0.0
		for id in b.state_ids.duplicate():
			if not permanent(id):
				b.state_ids.erase(id)
				b.state_turns.erase(id)
		b.buffs.fill(0)
		b.buff_turns.fill(0)
		b.zq_pojia_rate = 0.5
		b.state_ids.append(1)
		b._sort_states()
		var state := XDB.rec("States", 1)
		var lo := int(state.get("minTurns", 1))
		var hi := int(state.get("maxTurns", lo))
		var duration := floori(0.5 * (hi - lo + 1)) + lo if preview else b.roll_state_duration(lo, hi, random, str(labels.get(b, "b")) + ":1")
		b.state_turns[1] = duration
		if not r.addedStates.has(1):
			r.addedStates.append(1)
	elif b.hp > 0.0 and b.state_ids.has(1):
		b.state_ids.erase(1)
		b.state_turns.erase(1)
		if not r.removedStates.has(1):
			r.removedStates.append(1)
	b.resource_death_blocked = b.hp == 0.0 and not b.state_ids.has(1)
	# The add-state recursion guard suppresses another resource clamp inside death.
	# Recompute portable passive data, but leave the newly changed resource caps for
	# the next setter, matching the measured state-dependent-cap sequence.
	if b is XActor or b is XEnemy:
		b.refresh_passive()
