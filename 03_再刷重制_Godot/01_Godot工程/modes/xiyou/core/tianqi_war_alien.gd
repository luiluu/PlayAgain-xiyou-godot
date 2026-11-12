class_name XTianqiWarAlien
extends RefCounted
## 【cc·天启篇·未经审查】战争线异化怪的战斗规则（四线异化 v0.8 第 2.2、3.2 节；四线剧情与关卡设计稿 v0.4 第 4.2、5.1 节）。
## 只给战争线自己的几场战斗用：开场第 1 节「异兆」、第 2 节「蔓延」，10／20／30 层的使徒守层者（XTianqiWarLine 开战前 prepare）。
## 1～30 层「按段异化」（第 3.3 节，四线共用的异化判定）在 XTianqiSegAlien：它抽好哪只、什么级、什么种类后调这里的 apply。
##
## 怎么开一场：XTianqiWarAlien.prepare("omen") 之后照常开战（敌群是原版的），setup 时按预设把指定的敌人变成异化怪：
## - 级（侵染／蚀骨／化形／终焉）：生命 ×1.25／×1.5／×2／×3，名字前加「级·」。
## - 种类：战狂（八项属性 ×1.5／×2／×3／×5；化形起每次受伤攻击 +5%）、战意（每被攻击一次叠 1 层，满 6／5／3／2 层立刻再动，
##   层数照设计稿附录避开 4）、号令官（存活时同场所有怪属性 +10／20／30／50%、每回合再动 0／1／1／2 次；化形起被打倒时其他怪各立刻行动一次）、
##   烟火师（每次行动火花额外 +1；化形起火花满触发再动时自己多动一次；随机雷电段数没做）。
## - 火花（本线核心计量）：异化怪每行动 +1，满 10（终焉在场时 6）全体异化怪立刻再动一次，火花归零。
## - 交锋（线规则）：场上有异化怪时，从第 3 回合起双方伤害每回合 +10%（上限 +100%）。
## 计量和层数现在只在战斗日志里报（battle_text），没有专门的计量条（画面归 B 界面车道）。
##
## 开关：XTianqiWarLine.ENABLED（战争线整条）；只认天启篇存档、发行构建里还要 XTianqi.RELEASE_OPEN。没 prepare 的战斗一概不动。

const META := "xwar_alien"

static var _pending := ""


static func data() -> Dictionary:
	return XTianqiWarLine.data().get("alien", {})


static func preset(key: String) -> Dictionary:
	var p = XTianqiWarLine.data().get("presets", {}).get(key)
	return p if p is Dictionary else {}


## 下一场战斗按这个预设异化（omen／spread／apostle10／apostle20／apostle30）。不收时返回 false。
static func prepare(key: String, s: XState = null) -> bool:
	if preset(key).is_empty() or not XTianqiWarLine.allowed(s):
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


static func tier_info(tier: String) -> Dictionary:
	var t = data().get("tiers", {}).get(tier)
	return t if t is Dictionary else {}


static func kind_info(kind: String) -> Dictionary:
	var k = data().get("kinds", {}).get(kind)
	return k if k is Dictionary else {}


## 某只敌人的异化记录 {tier, kind, idx, fervor, rage}；不是异化怪为空
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
	if key == "" or not XTianqiWarLine.allowed(s):
		return
	var p := preset(key)
	var picks := _pick_units(logic.enemies, p.get("units", "all"))
	apply(logic, s, key, picks.map(func(e): return {"enemy": e, "tier": str(p.tier), "kind": str(p.kind)}))


## 本线异化种类里已经做好战斗规则的（按段异化 XTianqiSegAlien 只从这里面抽；连击兵还没做）
static func kinds() -> Array:
	return data().get("kinds", {}).keys()


## 把指定的敌人变成异化怪（预设和按段异化共用）：list 每项 {enemy, tier, kind}；返回 true＝这场有异化
static func apply(logic, s: XState, key: String, list: Array) -> bool:
	if logic.has_meta(META):
		logic.remove_meta(META)
	if list.is_empty() or not XTianqiWarLine.allowed(s):
		return false
	var f := {"preset": key, "units": {}, "sparks": 0, "queue": [], "hit": {}, "cmd_buff": {}, "cmd_down": {}}
	for row in list:
		var e = row.enemy
		var tier := str(row.tier)
		var kind := str(row.kind)
		var ti := tier_info(tier)
		var ki := kind_info(kind)
		if ti.is_empty() or ki.is_empty():
			continue
		var idx := int(ti.get("idx", 0))
		f.units[e] = {"tier": tier, "kind": kind, "idx": idx, "fervor": 0, "rage": 0.0}
		if kind == "berserk":
			var m := float(ki.mult[idx])
			for i in range(8):
				e.add_param(i, e.param_base_unscaled(i) * (m - 1.0))
		e.add_param(0, e.param_base_unscaled(0) * (float(ti.hp) - 1.0) * (float(ki.mult[idx]) if kind == "berserk" else 1.0))
		e.hp = e.mhp
		e.mp = e.mmp
		e.set_meta("tianqi_prefix", str(ti.name) + "·")
	if f.units.is_empty():
		return false
	logic.set_meta(META, f)
	_apply_commander(logic, f)
	var names := PackedStringArray()
	for e in f.units:
		names.append("%s（%s·%s）" % [e.original_name(), str(tier_info(str(f.units[e].tier)).name), str(kind_info(str(f.units[e].kind)).name)])
	_say(f, "战场上燃起了火花：%s。异化怪每行动一次攒一点火花，满 %d 点全体再动。" % ["、".join(names), spark_full(logic)])
	for e in f.units:
		if str(f.units[e].kind) == "fervor":
			_say(f, "战意：每被攻击一次叠一层，满 %d 层立刻再动。" % int(kind_info("fervor").full[int(f.units[e].idx)]))
			break
	return true


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


## 火花满几点触发：终焉级在场时少一些
static func spark_full(logic) -> int:
	var sp: Dictionary = data().get("sparks", {})
	for e in fight(logic).get("units", {}):
		if e.is_alive() and str(fight(logic).units[e].tier) == "zhongyan":
			return int(sp.full_zhongyan)
	return int(sp.full)


## 号令官存活：同场其他怪（含小怪）属性提高；号令官倒下就收回
static func _apply_commander(logic, f: Dictionary) -> void:
	var cmd = _commander(logic, f)
	var rate := 0.0
	if cmd != null:
		rate = float(kind_info("commander").buff[int(f.units[cmd].idx)])
	for e in logic.enemies:
		var want := rate if e.is_alive() else 0.0
		var have := float(f.cmd_buff.get(e, 0.0))
		if is_equal_approx(want, have):
			continue
		for i in range(2, 8):
			e.add_param(i, e.param_base_unscaled(i) * (want - have))
		f.cmd_buff[e] = want


static func _commander(logic, f: Dictionary):
	for e in f.units:
		if e.is_alive() and str(f.units[e].kind) == "commander":
			return e
	return null


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


## BattleLogic.make_action_times：号令官在场时同场所有怪每回合多动几次
static func extra_actions(logic, b) -> int:
	if not active(logic) or not b is XEnemy:
		return 0
	var f := fight(logic)
	var cmd = _commander(logic, f)
	return int(kind_info("commander").extra[int(f.units[cmd].idx)]) if cmd != null else 0


## BattleLogic.act 末尾：火花、战意、号令官倒下
static func after_action(logic, u) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var again := []
	if is_alien(logic, u):
		var n := int(data().sparks.per_action) + (int(kind_info("pyro").spark_extra) if str(f.units[u].kind) == "pyro" else 0)
		f.sparks = int(f.sparks) + XTianqiRewards.spark_gain(logic, n)  # 天启篇奖励：净印·止戈几率不加
		var full := spark_full(logic)
		if int(f.sparks) >= full:
			f.sparks = 0
			for e in f.units:
				if e.is_alive():
					again.append(e)
					if str(f.units[e].kind) == "pyro" and int(f.units[e].idx) >= 2:
						again.append(e)  # 烟火师化形：自己再多动一次
			_say(f, "火花满了（%d 点）：异化怪全体再动！" % full)
		else:
			_say(f, "火花 %d／%d。" % [int(f.sparks), full])
	# 战意：这一次行动里被我方打到的战意怪各叠一层
	for e in f.hit.keys():
		var r: Dictionary = f.units.get(e, {})
		if r.is_empty() or not e.is_alive():
			continue
		r.fervor = int(r.fervor) + 1
		var need := int(kind_info("fervor").full[int(r.idx)])
		if int(r.fervor) >= need:
			r.fervor = 0
			again.append(e)
			_say(f, "%s战意满了：立刻再动！" % e.display_name())
		else:
			_say(f, "%s战意 %d／%d。" % [e.display_name(), int(r.fervor), need])
	f.hit = {}
	# 号令官倒下：收回加成；化形起其他怪各立刻行动一次
	for e in f.units:
		if str(f.units[e].kind) == "commander" and e.is_dead() and not f.cmd_down.has(e):
			f.cmd_down[e] = true
			_say(f, "号令官倒下了。")
			if int(f.units[e].idx) >= 2:
				for o in logic.alive(logic.enemies):
					again.append(o)
	_apply_commander(logic, f)
	for i in range(again.size() - 1, -1, -1):
		logic.current_order.push_front(again[i])
	return take_logs(logic)


## 交锋：场上有异化怪时，从第 3 回合起每回合伤害 +10%，上限 +100%
static func clash_mult(logic) -> float:
	if not active(logic):
		return 1.0
	var f := fight(logic)
	if not f.units.keys().any(func(e): return e.is_alive()):
		return 1.0
	var c: Dictionary = data().clash
	var n := int(logic.turn) - int(c.from_turn) + 1
	return 1.0 + minf(float(c.cap), float(c.per_turn) * maxf(0.0, float(n)))


## BattleLogic.execute_hp_damage：交锋加伤；战意记被打；战狂化形受伤加攻
static func hp_damage(logic, u, t, value: float) -> float:
	if not active(logic) or value <= 0.0:
		return value
	var f := fight(logic)
	value *= clash_mult(logic)
	var r: Dictionary = f.units.get(t, {})
	if not r.is_empty() and u is XActor:
		if str(r.kind) == "fervor":
			f.hit[t] = true
		elif str(r.kind) == "berserk" and int(r.idx) >= 2:
			t.add_param(2, t.param_base_unscaled(2) * float(kind_info("berserk").rage_per_hit))
	return value


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		var f := fight(logic)
		for e in f.get("units", {}):
			if e.has_meta("tianqi_prefix"):
				e.remove_meta("tianqi_prefix")
		logic.remove_meta(META)
		f.clear()
