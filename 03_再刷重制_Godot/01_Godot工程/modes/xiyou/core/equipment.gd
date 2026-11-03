class_name XEquipment
extends RefCounted
## 装备交换与预览共用规则；预览复制角色，绝不临时改动真实装备/生命/背包。

static func can_change(a: XActor, slot: int) -> bool:
	var slots := a.equip_slots()
	return slot >= 0 and slot < slots.size() and not a.traits_set(53).has(int(slots[slot])) and not a.traits_set(54).has(int(slots[slot]))

## Window_EquipItem.includes／bestEquipItem：装备类型等于该槽当前的槽位类型（双持时第 2 格是武器）且能装备
static func fits(a: XActor, slot: int, item: Dictionary) -> bool:
	var slots := a.equip_slots()
	return slot >= 0 and slot < slots.size() and not item.is_empty() and int(item.get("etypeId", 0)) == int(slots[slot]) and a.can_equip(item) \
		and (XState.current == null or XAlienation.can_wear(XState.current, a, item))  # 异化装备要就绪（installAlienationRuntime canEquip）

static func clone(a: XActor) -> XActor:
	var b := XActor.new()
	b.actor_id = a.actor_id
	b.class_id = a.class_id
	b._lv = a.level
	b.exp_total = a.exp_total
	b.nickname = a.nickname
	b.class_exp = a.class_exp.duplicate()
	b.set_looks(a.looks)
	b.skill_ids = a.skill_ids.duplicate()
	b.equips = a.equips.duplicate(true)
	b.state_ids = a.state_ids.duplicate()
	b.state_turns = a.state_turns.duplicate()
	b.buffs = a.buffs.duplicate()
	b.buff_turns = a.buff_turns.duplicate()
	b.hp = a.hp
	b.mp = a.mp
	b.tp = a.tp
	b.zhenqi = a.zhenqi.duplicate(true)   # 道法技能按境界缩放（XZhenqi.daofa_scale），漏了预览与战力都按 1/4 算
	b.state_data = a.state_data.duplicate(true)  # _stateCounter 等状态私有字段（原版 JsonEx 深拷贝整个对象）；漏了 1775 层数归 1
	b.mastery_levels = a.mastery_levels.duplicate()  # _skillMasteryLevels／_skillMasteryUses（同上，深拷贝带着）：战力与预览的伤害预演读熟练度
	b.mastery_uses = a.mastery_uses.duplicate()
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
	if not can_change(a, slot) or not XAlienation.can_change(s, a, slot, item):  # 异化：待选、每人一件、就绪（changeEquip）
		return false
	if item is Dictionary:
		var index := s.gear.find_custom(func(e):return is_same(e,item))
		if index < 0 or not fits(a, slot, item):
			return false
		# 同属性实例也逐件交换，不合并背包中的数量。
		s.gear.remove_at(index)
	var old = a.equips[slot]
	if old is Dictionary and not old.is_empty():
		s.gear.append(old)
	a.equips[slot] = item
	a.refresh_passive()
	for removed in a.release_unequippable():
		s.gear.append(removed)
	a.refresh_passive()
	XActorModules.equip_changed(a)  # 专属角色模块的 changeEquip 包装（饿狼同步、法宝进化）
	XDemonCrown.equip_changed(a)  # 魔冠 changeEquip 包装：战斗中换掉开战穿的那件，这一场不算成长
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
		var score := -1000.0   # MV bestEquipItem 的起点，能力值和为负的也能选上
		for e in s.gear:
			if not fits(a, slot, e):
				continue
			var value := 0.0
			for p in e.params:
				value += float(p)
			if value > score:
				best = e
				score = value
		if best != null:
			change(s, a, slot, best)
