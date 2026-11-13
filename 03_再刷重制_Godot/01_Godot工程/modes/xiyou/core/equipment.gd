class_name XEquipment
extends RefCounted
## 装备交换与预览共用规则；预览复制角色，绝不临时改动真实装备/生命/背包。

## 天启篇（XTianqiGear）：删除的栏位不能换；坐骑不受难度适应 1691 的封印
static func can_change(a: XActor, slot: int) -> bool:
	var slots := a.equip_slots()
	if slot < 0 or slot >= slots.size() or not XTianqiGear.open_type(int(slots[slot])):
		return false
	var t := int(slots[slot])
	return not a.traits_set(53).has(t) and not (a.traits_set(54).has(t) and not XTianqiGear.seal_ignored(t))

## Window_EquipItem.includes／bestEquipItem：装备类型等于该槽当前的槽位类型（双持时第 2 格是武器）且能装备
static func fits(a: XActor, slot: int, item: Dictionary) -> bool:
	var slots := a.equip_slots()
	return slot >= 0 and slot < slots.size() and not item.is_empty() and int(item.get("etypeId", 0)) == int(slots[slot]) and a.can_equip(item) \
		and (XState.current == null or XAlienation.can_wear(XState.current, a, item))  # 异化装备要就绪（installAlienationRuntime canEquip）

## installDualExclusiveRuntime（v0.62.10，Kyo 2026-11-01）：双持时专武只能装一把。专武＝带 <req_actors> 的武器（与出售保护的「专属」同一判定，
## 实例备注或解析出的角色需求）。另一个武器栏（槽位类型 1）已有专武时：change 不换、装备页变灰、最强装备跳过；
## 旧档已同时装着两把：release_unequippable 只留排在前面的一把，其余卸回背包。白晶晶（76，毒吻＋穿肠）例外。参照 dual_exclusive_probe。
const DUAL_EXCLUSIVE_EXEMPT := [76]
## O-235：原版 bestEquipItem 的跳过挂在 Game_BattlerBase.canEquip 上，被 Game_Actor 自己的 canEquip 盖过去没生效，
## 第二栏照样挑中专武，随后 changeEquip 被挡，第二栏空着。修好＝跳过专武、挑下一件最好的；false＝原版（第二栏留空）。
static var FIX_DUAL_EXCLUSIVE_BEST := true
static var _req_actors_re := RegEx.create_from_string("(?i)<req_actors\\s*:")

static func is_exclusive(item) -> bool:
	if not item is Dictionary or item.is_empty() or str(item.get("kind", "")) != "weapon":
		return false
	var eq = item.get("equipment")
	var req = eq.get("requirements", {}) if eq is Dictionary else {}
	var actors = req.get("actors", []) if req is Dictionary else []
	return (actors is Array and not actors.is_empty()) or _req_actors_re.search(str(item.get("note", ""))) != null

## 除 slot 这一栏外，别的武器栏里有没有专武
static func _other_has_exclusive(a: XActor, slot: int) -> bool:
	var slots := a.equip_slots()
	for i in range(mini(a.equips.size(), slots.size())):
		if i != slot and int(slots[i]) == 1 and is_exclusive(a.equips[i]):
			return true
	return false

## KyoDualExclusive.blocked：这一栏不能装这把专武
static func dual_blocked(a: XActor, slot: int, item) -> bool:
	if DUAL_EXCLUSIVE_EXEMPT.has(a.actor_id) or not is_exclusive(item):
		return false
	var slots := a.equip_slots()
	return slot >= 0 and slot < slots.size() and int(slots[slot]) == 1 and _other_has_exclusive(a, slot)

## releaseUnequippableItems 包装：武器栏里的专武只留排在前面的一把，其余卸下（不论 forcing 都退回背包，由调用处放回）
static func release_dual_exclusive(a: XActor) -> Array:
	var removed := []
	if DUAL_EXCLUSIVE_EXEMPT.has(a.actor_id):
		return removed
	var slots := a.equip_slots()
	var kept := false
	for i in range(mini(a.equips.size(), slots.size())):
		if int(slots[i]) != 1 or not is_exclusive(a.equips[i]):
			continue
		if not kept:
			kept = true
			continue
		removed.append(a.equips[i])
		a.equips[i] = null
	return removed

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
		XActor.read_touch()  # 换了装备：只读窗口里记的特性表、技能表作废（装备页在窗口里调预览，原来漏了，带全程比对跑 xiyou_panels 会报不一致）
		b.refresh_passive()
		b.release_unequippable()
		b.refresh_passive()
	return b

static func change(s: XState, a: XActor, slot: int, item) -> bool:
	if not can_change(a, slot) or not XAlienation.can_change(s, a, slot, item):  # 异化：待选、每人一件、就绪（changeEquip）
		return false
	if dual_blocked(a, slot, item):
		return false  # 双持专武：另一武器栏已有专武（installDualExclusiveRuntime changeEquip）
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
			if not fits(a, slot, e) or (FIX_DUAL_EXCLUSIVE_BEST and dual_blocked(a, slot, e)):  # 另一栏已挑了专武就跳过专武（O-235；原版挑中后被 change 挡下）
				continue
			var value := 0.0
			for p in e.params:
				value += float(p)
			if value > score:
				best = e
				score = value
		if best != null:
			change(s, a, slot, best)
