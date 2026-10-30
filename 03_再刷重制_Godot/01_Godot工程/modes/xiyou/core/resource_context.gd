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
## Frozen YEP Core uses its saved base refresh for map/menu TP setters.
var in_battle := true
var boss_output := XBossOutputContext.new()
## Host inputs without this context itself (avoid a reference cycle).
var lifecycle_inputs := {}

func state_context(b: XBattler) -> Dictionary:
	var ctx := lifecycle_inputs.duplicate()
	if b.lifecycle_context.get("resources") == self:
		ctx.merge(b.lifecycle_context, true)
	ctx.resources = self
	ctx.random = random
	ctx.execute = not preview
	ctx.preview = preview
	return ctx

## One explicit operation domain for state changes, including nested Apply/Remove effects.
func add_state(b: XBattler, id: int, inputs := {}) -> void:
	if preview or bool(inputs.get("preview", false)) or b == null:
		return
	# Native isStateAddable checks appearance and the death state. Raw HP may
	# already be zero while refresh/_die still needs to attach state 1.
	var forced := XAlienBattle.forced_state(b, id)  # 异化疫囊、囚厄：不可抵抗、本次移除过也照加
	if b.state_ids.has(1) or (b is XEnemy and b.hidden) or (b.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) and not forced):
		return
	if result(b).removedStates.has(id) and not forced:
		return
	var context := state_context(b)
	context.merge(inputs, true)
	context.resources = self
	b.add_state_with_context(id, context.get("random"), context)

func remove_state(b: XBattler, id: int) -> void:
	if not preview and b != null:
		b.remove_state_with_context(id, state_context(b))


func publish() -> void:
	for b in slots:
		b.runtime_result = result(b).duplicate(true)

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
	if XAlienBattle.route_gain(self, b, resource, amount):
		return {}  # 异化绝缘拒收外来恢复、舍身的生命恢复转给队友（gainHp／gainMp 包装）
	if resource == "hp" and XAlienBattle.route_life_gain(self, b, amount):
		return {}  # 异化空壳、嫁祸不吃治疗，嫁祸扣血由保护者付，连命结算到池（hpChange）
	if resource == "mp" and XAlienBattle.route_hollow_mp(b, amount):
		return {}  # 异化空壳回蓝变护盾（gainMp 包装）
	if resource == "hp" and amount < 0.0 and XAlienBattle.frame_blocks_hp(b):
		amount = 0.0  # 异化 gainHp 包装（Runtime wrapHp）：逆祷者的帧里对敌人扣血归零
	var before := snapshot(b)
	var requested := amount
	if amount < 0.0:
		amount = -boss_output.loss_value(b, resource, -amount)
	boss_output.enter_direct(b, resource)
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
	_set_resource(b, resource, old + amount)
	boss_output.leave_direct()
	# KRZ 收到 Boss 缩放后的值；敌人 gainHp 另在 ShieldSystem 吸收之后才进入 KRZ。
	# 角色 gainHp 自有包装收到护盾前值。取整／敌人护盾归零均不额外置 dirty。
	if shown != 0.0:
		b.param_mark_dirty()
	var after := snapshot(b)
	var entry := {"receiver": labels.get(b, "b"), "resource": resource, "requestedDelta": requested,
		"actualDelta": float(b.get(resource)) - old, "before": before, "after": after}
	journal.append(entry)
	XAlienBattle.after_gain(b, resource)  # 异化 hpChange 末尾：同步生命池与嫁祸者
	return entry

## 原版 setHp／setMp：护盾在 setter 内处理；不写伤害槽、不做 gain 末尾 dirty。
func set_resource(b: XBattler, resource: String, value: float) -> Dictionary:
	if not error.is_empty():
		return {}
	if not resource in ["hp", "mp", "tp"] or is_nan(value) or is_inf(value):
		error = "invalid_resource_request"
		return {}
	var unsupported := supported(b)
	if not unsupported.is_empty():
		error = unsupported
		return {}
	if resource == "hp" and XAlienBattle.routes_set_hp(b):
		return gain(b, "hp", value - b.hp)  # 异化 setHp 包装：生命池、嫁祸、空壳、舍身、绝缘按 gainHp(差值) 走
	if resource == "hp" and value < b.hp and XAlienBattle.frame_blocks_hp(b):
		value = b.hp  # 异化 setHp 包装（Runtime）：逆祷者的帧里对敌人压低生命无效
	var before := snapshot(b)
	var old: float = b.get(resource)
	_set_resource(b, resource, value)
	var entry := {"receiver": labels.get(b, "b"), "resource": resource, "requestedValue": value,
		"actualDelta": float(b.get(resource)) - old, "before": before, "after": snapshot(b)}
	journal.append(entry)
	return entry

func _set_resource(b: XBattler, resource: String, value: float) -> void:
	var old: float = b.get(resource)
	if value < old:
		value = old - boss_output.loss_value(b, resource, old - value)
	boss_output.enter_direct(b, resource)
	if resource == "hp" and value < old:
		value = old - b.absorb_shield(old - value)
	# YEP compares the requested input before refresh/clamp; an equal input does no refresh.
	if value != old:
		b.set(resource, value)
		if resource == "tp" and not in_battle:
			_refresh_base(b)
		else:
			refresh(b)
	boss_output.leave_direct()

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
	var previous := b.lifecycle_context
	b.lifecycle_context = state_context(b)
	_refresh_type_before(b)
	# The base/actor refresh reaches the global add lock; enemy's saved alias
	# still reaches the base clamp. Both retain their outer KRZ refresh work.
	if not (not b is XEnemy and XBattler._adding_state):
		_refresh_base(b)
		_refresh_death(b)
	_refresh_type_after(b)
	b.lifecycle_context = previous

func _refresh_type_before(b: XBattler) -> void:
	b.param_refresh()
	if b is XActor:
		b.release_to_party()

func _refresh_base(b: XBattler) -> void:
	var resisted := b.traits_set(XBattler.TRAIT_STATE_RESIST)
	for id in b.state_ids.duplicate():
		if resisted.has(id):
			b.state_ids.erase(id)
			b.state_turns.erase(id)
	b.hp = clampf(b.hp, 0.0, b.mhp)
	b.mp = clampf(b.mp, 0.0, b.mmp)
	b.tp = clampf(b.tp, 0.0, b.max_tp())

func _refresh_death(b: XBattler) -> void:
	var r := result(b)
	if b.hp == 0.0 and not b.state_ids.has(1) and not b.immortal and not b.traits_set(XBattler.TRAIT_STATE_RESIST).has(1) and not r.removedStates.has(1):
		var ctx := state_context(b)
		ctx.duration_key = str(labels.get(b, "b")) + ":1"
		b.add_state_with_context(1, random, ctx)
	elif b.hp > 0.0 and b.state_ids.has(1):
		b.remove_state_with_context(1, state_context(b))
	b.resource_death_blocked = b.hp == 0.0 and not b.state_ids.has(1)

func _refresh_type_after(b: XBattler) -> void:
	if b is XActor or b is XEnemy:
		b.refresh_passive()
	# KRZ's outer type refresh clears need_refresh even when death's nested
	# addState marked it again. gain() marks dirty only after this returns.
	b.effect_dirty = false
	b.param_dirty = false
