class_name XTianqiAlienAffix
extends RefCounted
## 【cc·天启篇·未经审查】天启篇四条本线新异化词条的战斗效果（四线异化与异化装备重构 v0.8 第 4.2 节）。
## 数在 tianqi_data/alien_gear.json 的 effects（测试参数）。四级分档（cc/tianqi-alien-tiers）：收益那一项按装备的级（侵染／蚀骨／化形／终焉）取数组，
## 代价各级一样；设计稿的数在化形。临终攻击 +20／30／50／80%，再动每 5／3／3／2 回合，节俭省 20／25／33／50%，带毒附毒 50／70／100／100%。
## 认人：XAlienation.for_actor（战斗里是开战时冻结的那件，和原版异化一样一人只认一件），装备带天启篇异化标记（XTianqiAlienGear.tq）。
## - 临终（死亡）：受到致命伤害时这一下留 1 点生命（每场 per_battle 次），本回合攻击、魔攻 +atk_rate%；本回合结束时必死。
## - 再动（战争）：每 every 回合（第 3、6、9…回合）多行动一次；受到的伤害 +taken%。
## - 节俭（饥荒）：技能消耗 −cost%；受到的回复 −heal%。
## - 带毒（瘟疫）：攻击打中敌人时附加「中毒」（chance%，敌人抵抗就不上）；自己开战和每回合结束时都挂上「中毒」。
## 接法：XTianqiAffixBattle 的 start／finish／param_rate／damage_ops／cost／action_plus_set／after_apply／end_turn 各调一处，
## BattleLogic.execute_hp_damage 一行（临终）。只认天启篇存档（XTianqiAffixBattle.on），原版档、原版异化装备一概不动。
##
## 开关（O-337）：false＝四条新词条在战斗里没有效果（装备照样能掉、能刻，详情写「未生效」）
static var ENABLED := true

const META := "xalien_affix"
const POISON := 4   # 原版状态「中毒」（每回合生命 −10%，战斗结束解除）
const DEATH := 1


static func on(s = null) -> bool:
	return ENABLED and XTianqiAffixBattle.on(s)


static func params(key: String) -> Dictionary:
	return XTianqiAlienGear.data().get("effects", {}).get(key, {})


## 某项的数：表里是数组就按级取（侵染 0…终焉 3），单个数各级一样（四级分档，cc/tianqi-alien-tiers）
static func value(key: String, field: String, level_idx: int, fallback := 0.0) -> float:
	var v = params(key).get(field, fallback)
	if v is Array:
		return float(v[clampi(level_idx, 0, (v as Array).size() - 1)]) if not (v as Array).is_empty() else fallback
	return float(v)


## 这个人身上那件天启篇异化装备的级（0 起；没有为 -1）
static func level_of(a) -> int:
	if not (a is XActor):
		return -1
	var item = XAlienation.for_actor(a).get("item", null)
	return XTianqiAlienGear.level_index(str(XTianqiAlienGear.tq(item).get("level", ""))) if item is Dictionary else -1


## 这个人身上生效的天启篇新词条键（没有为空）
static func key_of(a) -> String:
	if not (a is XActor):
		return ""
	var f := XAlienation.for_actor(a)
	var item = f.get("item", null)
	if not (item is Dictionary) or not XTianqiAlienGear.is_tq(item):
		return ""
	var k := str(f.get("affix", ""))
	return k if XTianqiAlienGear.is_new_affix(k) else ""


static func _store(logic) -> Dictionary:
	if logic == null or not logic.has_meta(META):
		return {}
	return logic.get_meta(META)


static func _logic():
	return XAlienBattle.active_logic()


static func _unit(st: Dictionary, a) -> Dictionary:
	if not st.units.has(a):
		st.units[a] = {"dying_used": 0, "dying_turn": -1}
	return st.units[a]


# ---- 开战、收尾 ----

static func start(logic) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	if not on(logic.state):
		return
	logic.set_meta(META, {"units": {}, "logs": []})
	for a in logic.actors:
		if key_of(a) == "venom" and a.is_alive():
			logic._state_add(a, POISON)


static func finish(logic) -> void:
	if logic != null and logic.has_meta(META):
		for a in _store(logic).units:
			if is_instance_valid(a):
				a.param_mark_dirty()
		logic.remove_meta(META)


## 本回合在临终里（留了一口气、回合结束时要死）
static func dying_now(a) -> bool:
	var logic = _logic()
	var st := _store(logic)
	if st.is_empty() or not st.units.has(a):
		return false
	return int(st.units[a].dying_turn) == int(logic.turn) and a.hp > 0.0


# ---- 面板、伤害、消耗、行动次数 ----

## 临终：攻击、魔攻
static func param_rate(a, i: int) -> float:
	if not ENABLED or not (i == 2 or i == 4) or not dying_now(a):
		return 1.0
	return 1.0 + value("dying", "atk_rate", level_of(a)) / 100.0


static func damage_ops(item: Dictionary, a, b) -> Array:
	var st := _store(_logic())
	if st.is_empty() or not (b is XActor):
		return []
	var k := key_of(b)
	var type := int(item.get("damage", {}).get("type", 0))
	if k == "thrift" and type == 3:
		return [{"op": "mul", "field": "healingMultiplier", "value": maxf(0.0, 1.0 - value("thrift", "heal", level_of(b)) / 100.0)}]
	if k == "again" and type in [1, 5] and a != b:
		return [{"op": "mul", "field": "incomingMultiplier", "value": 1.0 + value("again", "taken", level_of(b)) / 100.0}]
	return []


## 节俭：在别的减耗之后再乘
static func cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:
	if not on() or key_of(a) != "thrift" or skill == null or skill.is_empty():
		return c
	var m := maxf(0.0, 1.0 - value("thrift", "cost", level_of(a)) / 100.0)
	return {"mp": maxi(0, floori(float(c.mp) * m)), "tp": maxi(0, floori(float(c.tp) * m))}


## 再动：第 every、2×every…回合多行动一次（必定）
static func action_plus_set(a, rates: Array) -> void:
	var logic = _logic()
	if _store(logic).is_empty() or key_of(a) != "again":
		return
	var every := maxi(1, int(value("again", "every", level_of(a), 3.0)))
	if int(logic.turn) > 0 and int(logic.turn) % every == 0:
		rates.append(1.0)


# ---- 临终：致命一击留一口气（BattleLogic.execute_hp_damage） ----

static func hp_damage(logic, _u, t, value: float) -> float:
	var st := _store(logic)
	if st.is_empty() or value <= 0.0 or not (t is XActor) or not t.is_alive() or key_of(t) != "dying":
		return value
	if value < t.hp + t.shield:
		return value
	var un := _unit(st, t)
	if int(un.dying_turn) == int(logic.turn):
		return maxf(0.0, t.hp + t.shield - 1.0)  # 本回合已在临终：这回合都不死
	if int(un.dying_used) >= int(value("dying", "per_battle", level_of(t), 1.0)):
		return value
	un.dying_used = int(un.dying_used) + 1
	un.dying_turn = int(logic.turn)
	t.param_mark_dirty()
	st.logs.append({"type": "battle_text", "text": "%s 临终：这回合不会倒下，回合结束时必死。" % t.display_name()})
	return maxf(0.0, t.hp + t.shield - 1.0)


# ---- 带毒：打中附毒 ----

static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	var st := _store(logic)
	if st.is_empty() or key_of(u) != "venom" or t == null or t is XActor or not t.is_alive():
		return
	if not (skill is Dictionary) or not int(skill.get("damage", {}).get("type", 0)) in [1, 5]:
		return
	if bool(r.get("missed", false)) or bool(r.get("evaded", false)) or float(r.get("hp", 0.0)) <= 0.0:
		return
	if t.traits_set(XBattler.TRAIT_STATE_RESIST).has(POISON):
		return
	if logic._float("tianqi_alien_venom") * 100.0 < value("venom", "chance", level_of(u), 100.0):
		logic._state_add(t, POISON)


# ---- 回合结束：临终必死、带毒自己续毒 ----

static func end_turn(logic) -> void:
	var st := _store(logic)
	if st.is_empty():
		return
	for a in logic.actors:
		if not (a is XActor):
			continue
		var un: Dictionary = st.units.get(a, {})
		if not un.is_empty() and int(un.dying_turn) == int(logic.turn):
			un.dying_turn = -1
			a.param_mark_dirty()
			if a.is_alive():
				a.hp = 0.0
				logic._state_add(a, DEATH)
				st.logs.append({"type": "battle_text", "text": "%s 临终的时刻到了。" % a.display_name()})
		if key_of(a) == "venom" and a.is_alive() and not a.state_ids.has(POISON):
			logic._state_add(a, POISON)


## 本场的提示（战斗日志用）
static func take_logs(logic) -> Array:
	var st := _store(logic)
	if st.is_empty() or (st.logs as Array).is_empty():
		return []
	var out: Array = st.logs.duplicate()
	st.logs.clear()
	return out
