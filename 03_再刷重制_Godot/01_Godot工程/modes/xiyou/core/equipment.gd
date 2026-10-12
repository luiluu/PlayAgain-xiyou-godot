class_name XEquipment
extends RefCounted
## 装备交换与预览共用规则；预览复制角色，绝不临时改动真实装备/生命/背包。

static func can_change(a: XActor, slot: int) -> bool:
	var slots := a.equip_slots()
	return slot >= 0 and slot < slots.size() and not a.traits_set(53).has(int(slots[slot])) and not a.traits_set(54).has(int(slots[slot]))

static func clone(a: XActor) -> XActor:
	var b := XActor.new()
	b.actor_id = a.actor_id
	b.class_id = a.class_id
	b._lv = a.level
	b.exp_total = a.exp_total
	b.nickname = a.nickname
	b.skill_ids = a.skill_ids.duplicate()
	b.equips = a.equips.duplicate(true)
	b.state_ids = a.state_ids.duplicate()
	b.state_turns = a.state_turns.duplicate()
	b.buffs = a.buffs.duplicate()
	b.buff_turns = a.buff_turns.duplicate()
	b.hp = a.hp
	b.mp = a.mp
	b.tp = a.tp
	b.refresh_passive()
	return b

static func preview(a: XActor, slot: int, item) -> XActor:
	var b := clone(a)
	if can_change(b, slot):
		b.equips[slot] = item.duplicate(true) if item is Dictionary else null
		b.refresh_passive()
		b.release_unequippable()
		b.refresh_passive()
	return b

static func change(s: XState, a: XActor, slot: int, item) -> bool:
	if not can_change(a, slot):
		return false
	if item is Dictionary:
		if not s.gear.has(item) or int(item.etypeId) != int(a.equip_slots()[slot]) or not a.can_equip(item):
			return false
		# 同属性实例也逐件交换，不合并背包中的数量。
		s.gear.erase(item)
	var old = a.equips[slot]
	if old is Dictionary and not old.is_empty():
		s.gear.append(old)
	a.equips[slot] = item
	a.refresh_passive()
	for removed in a.release_unequippable():
		s.gear.append(removed)
	a.refresh_passive()
	a.hp = minf(a.hp, a.mhp)
	a.mp = minf(a.mp, a.mmp)
	return true

static func clear(s: XState, a: XActor) -> void:
	for slot in range(a.equips.size()):
		if a.equips[slot] is Dictionary:
			change(s, a, slot, null)

static func optimize(s: XState, a: XActor) -> void:
	var excluded := str(XDB.plugin("YEP_EquipCore").get("Non-Optimized Types", "5")).split(" ", false)
	for slot in range(a.equips.size()):
		if not can_change(a, slot) or excluded.has(str(a.equip_slots()[slot])):
			continue
		change(s, a, slot, null)
	for slot in range(a.equips.size()):
		if not can_change(a, slot) or excluded.has(str(a.equip_slots()[slot])):
			continue
		var best = null
		var score := -1.0
		for e in s.gear:
			if int(e.etypeId) != int(a.equip_slots()[slot]) or not a.can_equip(e):
				continue
			var value := 0.0
			for p in e.params:
				value += float(p)
			if value > score:
				best = e
				score = value
		if best != null:
			change(s, a, slot, best)
