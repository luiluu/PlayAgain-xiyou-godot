class_name XTianqiFamineAlien
extends RefCounted
## 【cc·天启篇·未经审查】饥荒线异化怪的战斗规则（四线异化 v0.8 第 2.2、3.3 节；四线剧情与关卡设计稿 v0.4 第 4.3、5.1 节）。
## 只给饥荒线自己的几场战斗用：开场第 1 节「异兆」、第 2 节「蔓延」，10／20／30 层的使徒守层者（XTianqiLine 开战前 prepare）。
## 1～30 层「按段异化」（第 3.3 节，四线共用）不在这里，由按段异化车道调 prepare_units。
##
## 怎么开一场：XTianqiFamineAlien.prepare("omen") 之后照常开战（敌群是原版的），setup 时按预设把指定的敌人变成异化怪：
## - 级（侵染／蚀骨／化形／终焉）：生命 ×1.25／×1.5／×2／×3，名字前加「级·」。
## - 种类（数值是第 1～4 档；化形效果从化形起；终焉效果没做，终焉只给骑士和 31～36 层 Boss）：
##   枯竭者：我方技能 MP／TP 消耗 +30／50／80／120%；化形起生命消耗的技能也提高。
##   荒年者：我方受到的回复（生命、MP）−20／30／50／70%；化形起我方再生（每回合回血、回蓝）失效。
##   掠夺者：命中我方时夺走目标 5／10／15／25% 的当前 MP 和 TP；化形起夺到的转成自己的护盾（MP＋TP 之和）。
##   熬夜者：我方 TP 获得 −30／50／70／100%；化形起每回合结束我方 TP −10。
##   透支者：我方每放一次技能，另扣 2／3／6／10% 当前生命（第 2 档照「避开 4」从 4% 改 3%）；化形起改按最大生命。
## - 饥饿（本线核心计量）：消耗倍率＝1＋场上枯竭者的提高相加；回复倍率＝1－场上荒年者的降低相加（最低 0.1）。开战时和每回合开始在战斗日志里报。
## - 口粮（线规则，Kyo 11-08 已确认）：饥荒异化在场时，原本 MP、TP、生命消耗都是 0 的技能（原生攻击 1、防御 2 除外）
##   每次扣最大 MP 的 3／5／8／12%（按场上最高级），MP 不够改扣同样比例的当前生命（不会扣到 0）。
## 没做（交付单「未做」）：减耗、免耗效果打折；自带资源角色的获得量降低（要逐个角色模块接）；荒年的掉落减少与余粮；终焉效果。
##
## 开关：XTianqiFamineLine.ENABLED（饥荒线整条）；只认天启篇存档、发行构建里还要 XTianqi.RELEASE_OPEN。没 prepare 的战斗一概不动。

const META := "xfamine_alien"

static var _pending := ""
## 正在打的饥荒异化战（资源挂钩不带 logic，从这里取）
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	return XTianqiLine.data(XTianqiFamineLine.KEY).get("alien", {})


static func preset(key: String) -> Dictionary:
	return XTianqiLine.alien_preset(XTianqiFamineLine.KEY, key)


## 下一场战斗按这个预设异化（omen／spread／apostle10／apostle20／apostle30）。不收时返回 false。
static func prepare(key: String, s: XState = null) -> bool:
	if preset(key).is_empty() or not XTianqiFamineLine.allowed(s):
		_pending = ""
		return false
	_pending = key
	return true


static func pending() -> String:
	return _pending


static func active(logic) -> bool:
	return logic != null and logic.has_meta(META)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if active(logic) else {}


static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if active(l) else null


static func tier_info(tier: String) -> Dictionary:
	var t = data().get("tiers", {}).get(tier)
	return t if t is Dictionary else {}


static func kind_info(kind: String) -> Dictionary:
	var k = data().get("kinds", {}).get(kind)
	return k if k is Dictionary else {}


## 某只敌人的异化记录 {tier, kind, idx}；不是异化怪为空
static func unit(logic, e) -> Dictionary:
	return fight(logic).get("units", {}).get(e, {}) if active(logic) else {}


static func is_alien(logic, e) -> bool:
	return not unit(logic, e).is_empty()


## BattleLogic.setup：敌群建完后调（四骑士 setup 之后）
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var key := _pending
	_pending = ""
	if key == "" or not XTianqiFamineLine.allowed(s):
		return
	var p := preset(key)
	var picks := _pick_units(logic.enemies, p.get("units", "all"))
	if picks.is_empty():
		return
	var f := {"preset": key, "units": {}, "queue": []}
	var ti := tier_info(str(p.tier))
	for e in picks:
		f.units[e] = {"tier": str(p.tier), "kind": str(p.kind), "idx": int(ti.get("idx", 0))}
		e.add_param(0, e.param_base_unscaled(0) * (float(ti.hp) - 1.0))
		e.hp = e.mhp
		e.mp = e.mmp
		e.set_meta("tianqi_prefix", str(ti.name) + "·")
	logic.set_meta(META, f)
	_logic_ref = weakref(logic)
	_say(f, "饥荒的异化：%s（%s·%s）。" % ["、".join(PackedStringArray(picks.map(func(e): return e.original_name()))),
		str(ti.name), str(kind_info(str(p.kind)).name)])
	_say(f, hunger_text(logic))


static func _pick_units(enemies: Array, spec) -> Array:
	var list := enemies.filter(func(e): return not e.hidden)
	if spec is Array:
		var out := []
		for i in spec:
			if int(i) >= 0 and int(i) < list.size():
				out.append(list[int(i)])
		return out
	if str(spec) == "guardian":
		var g := list.filter(func(e): return str(e.original_name()).contains("守层者"))
		return g if not g.is_empty() else list.slice(0, 1)
	return list


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


# ---- 饥饿 ----

## 场上活着的某种异化的档位（0 起）列表
static func _idx_of(logic, kind: String) -> Array:
	var f := fight(logic)
	var out := []
	for e in f.get("units", {}):
		if e.is_alive() and str(f.units[e].kind) == kind:
			out.append(int(f.units[e].idx))
	return out


static func _sum(logic, kind: String, field: String) -> float:
	var v := 0.0
	var arr: Array = kind_info(kind).get(field, [])
	for i in _idx_of(logic, kind):
		v += float(arr[i])
	return v


static func _max_idx(logic, kind: String) -> int:
	var l := _idx_of(logic, kind)
	return -1 if l.is_empty() else int(l.max())


## 场上有活着的饥荒异化怪
static func hungry(logic) -> bool:
	return active(logic) and fight(logic).units.keys().any(func(e): return e.is_alive())


static func cost_mult(logic) -> float:
	return 1.0 + _sum(logic, "exhaust", "cost_up") if active(logic) else 1.0


static func heal_mult(logic) -> float:
	if not active(logic):
		return 1.0
	return maxf(float(data().hunger.heal_floor), 1.0 - _sum(logic, "lean", "heal_down"))


static func tp_mult(logic) -> float:
	return maxf(0.0, 1.0 - _sum(logic, "night", "tp_down")) if active(logic) else 1.0


## 口粮比例：按场上最高级的饥荒异化；没有为 0
static func ration_rate(logic) -> float:
	if not hungry(logic):
		return 0.0
	var top := -1
	var f := fight(logic)
	for e in f.units:
		if e.is_alive():
			top = maxi(top, int(f.units[e].idx))
	return float(data().ration.rate[top]) if top >= 0 else 0.0


static func hunger_text(logic) -> String:
	if not hungry(logic):
		return "饥饿散去了。"
	return "饥饿：技能消耗 ×%s，受到的回复 ×%s；不花资源的技能每次交口粮（最大 MP 的 %d%%）。" % [
		_num(cost_mult(logic)), _num(heal_mult(logic)), roundi(ration_rate(logic) * 100.0)]


static func _num(v: float) -> String:
	return str(snappedf(v, 0.01))


# ---- 挂钩 ----

## BattleLogic.start_turn：每回合报一次饥饿
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	_say(fight(logic), hunger_text(logic))
	return take_logs(logic)


## BattleLogic.skill_cost：我方技能的 MP／TP 消耗 × 饥饿（枯竭者）；面板（战斗外）不动
static func cost(logic, a, skill: Dictionary, c: Dictionary, panel: bool) -> Dictionary:
	if panel or not active(logic) or not a is XActor or not logic.actors.has(a):
		return c
	var m := cost_mult(logic)
	if m == 1.0:
		return c
	return {"mp": floori(int(c.mp) * m), "tp": floori(int(c.tp) * m)}


## BattleLogic.skill_hp_cost 的包装：化形枯竭者在场时生命消耗也提高（logic 从 active_logic 取）
static func hp_cost(a, value: int) -> int:
	var logic = active_logic()
	if logic == null or value <= 0 or not a is XActor or not logic.actors.has(a) or _max_idx(logic, "exhaust") < 2:
		return value
	return floori(value * cost_mult(logic))


## BattleLogic.pay_skill_cost 之后：零消耗技能交口粮；透支者另扣生命
static func after_pay(logic, u, skill: Dictionary, c: Dictionary) -> void:
	if not hungry(logic) or not u is XActor or not logic.actors.has(u) or logic.is_item(skill):
		return
	var f := fight(logic)
	var id := int(skill.get("id", 0))
	if data().ration.exempt_skills.has(id):
		return
	if int(c.get("mp", 0)) <= 0 and int(c.get("tp", 0)) <= 0 and logic.skill_hp_cost(u, skill) <= 0:
		var r := ration_rate(logic)
		var need := floorf(float(u.mmp) * r)
		if need > 0.0 and u.mp >= need:
			u.mp -= need
			_say(f, "%s交了口粮：MP −%d。" % [u.display_name(), int(need)])
		else:
			var lose := minf(floorf(float(u.hp) * r), maxf(0.0, u.hp - 1.0))
			if lose > 0.0:
				u.hp -= lose
				_say(f, "%s交不出口粮，饿得生命 −%d。" % [u.display_name(), int(lose)])
	var od := _max_idx(logic, "overdraw")
	if od >= 0:
		var rate := _sum(logic, "overdraw", "hp_cost")
		var base: float = float(u.mhp) if od >= 2 else float(u.hp)
		var lose := minf(floorf(base * rate), maxf(0.0, u.hp - 1.0))
		if lose > 0.0:
			u.hp -= lose
			_say(f, "透支：%s生命 −%d。" % [u.display_name(), int(lose)])
	u.refresh_resources()


## XResourceContext._gain：我方受到的回复（生命、MP）× 回复倍率（荒年者），TP 获得 × 熬夜者
static func gain(b, resource: String, amount: float) -> float:
	if amount <= 0.0 or not b is XActor:
		return amount
	var logic = active_logic()
	if logic == null or not logic.actors.has(b):
		return amount
	match resource:
		"hp", "mp":
			return floorf(amount * heal_mult(logic))
		"tp":
			return floorf(amount * tp_mult(logic))
	return amount


## BattleLogic 里的静默 TP 获得（技能 tpGain、受伤充 TP）：× 熬夜者
static func tp_gain(logic, b, amount: float) -> float:
	if amount <= 0.0 or not active(logic) or not b is XActor or not logic.actors.has(b):
		return amount
	return floorf(amount * tp_mult(logic))


## BattleLogic._regenerate：再生回血、回蓝 × 回复倍率（化形荒年者在场时失效），回 TP × 熬夜者。返回 [dh, dm, dt]
static func regen(logic, b, dh: float, dm: float, dt: float) -> Array:
	if not active(logic) or not b is XActor or not logic.actors.has(b):
		return [dh, dm, dt]
	var off := _max_idx(logic, "lean") >= 2
	var h := heal_mult(logic)
	if dh > 0.0:
		dh = 0.0 if off else floorf(dh * h)
	if dm > 0.0:
		dm = 0.0 if off else floorf(dm * h)
	if dt > 0.0:
		dt = dt * tp_mult(logic)
	return [dh, dm, dt]


## BattleLogic.execute_hp_damage：掠夺者命中我方时夺 MP、TP（化形起转成自己的护盾）
static func hp_damage(logic, u, t, value: float) -> float:
	if value <= 0.0 or not active(logic) or not t is XActor:
		return value
	var r := unit(logic, u)
	if r.is_empty() or str(r.kind) != "plunder" or not u.is_alive():
		return value
	var rate := float(kind_info("plunder").steal[int(r.idx)])
	var mp := floorf(float(t.mp) * rate)
	var tp := floorf(float(t.tp) * rate)
	if mp <= 0.0 and tp <= 0.0:
		return value
	t.mp -= mp
	t.tp -= tp
	t.refresh_resources()
	var f := fight(logic)
	if int(r.idx) >= 2:
		u.shield = float(u.shield) + mp + tp
		_say(f, "%s夺走了%s的 MP %d、TP %d，变成了自己的护盾。" % [u.display_name(), t.display_name(), int(mp), int(tp)])
	else:
		_say(f, "%s夺走了%s的 MP %d、TP %d。" % [u.display_name(), t.display_name(), int(mp), int(tp)])
	return value


## BattleLogic.end_turn：化形熬夜者在场时我方 TP −10
static func end_turn(logic) -> Array:
	if not active(logic):
		return []
	if _max_idx(logic, "night") >= 2:
		var n := float(kind_info("night").tp_drain)
		for a in logic.alive(logic.actors):
			a.tp = maxf(0.0, float(a.tp) - n)
		_say(fight(logic), "熬夜：我方 TP 各 −%d。" % int(n))
	return take_logs(logic)


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		var f := fight(logic)
		for e in f.get("units", {}):
			if e.has_meta("tianqi_prefix"):
				e.remove_meta("tianqi_prefix")
		logic.remove_meta(META)
		f.clear()
	_logic_ref = null
