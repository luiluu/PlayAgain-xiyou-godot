class_name XTianqiDeathAlien
extends RefCounted
## 【cc·天启篇·未经审查】死亡线异化怪的战斗规则（四线异化 v0.8 第 2.2、3.1 节；四线剧情与关卡设计稿 v0.4 第 4.1、5.1 节；
## 带 4 的测试参数按 v0.4 附录换）。给死亡线自己的几场战斗用：开场第 1 节「异兆」、第 2 节「蔓延」，10／20／30 层的使徒守层者
## （XTianqiLine 开战前 prepare）；1～30 层「按段异化」由 XTianqiSegAlien 抽好后经 XTianqiLine.alien_apply 调这里的 apply。
##
## 怎么开一场：XTianqiDeathAlien.prepare("omen") 之后照常开战（敌群是原版的），setup 时按预设把指定的敌人变成异化怪：
## - 级（侵染／蚀骨／化形／终焉）：生命 ×1.25／×1.5／×2／×3，名字前加「级·」。预设可带 stats_from（敌人号）：先把能力值换成那只敌人的原数值
##  （勇者之塔是高等级副本，开场在 5 层左右打，借塔里的外观、用六层的数值）。
## - 种类（数值是第 1～4 档；化形效果从化形起；终焉只给骑士和 31～36 层 Boss）：
##   宣判者 verdict：每 5／3／2／1 回合在回合开始给一名我方挂「死期」（终焉一次两人）；侵染、蚀骨时打倒它死期就解开，免即死挡得住；化形起挡不住。
##   收尸人 reaper：每有一名我方倒下，自身攻防魔攻魔防 +10／15／25／50%（按基础值），回复 10／15／20／30% 最大生命；化形起倒下的人 2 回合内不能复活。
##   丧钟 knell：开场倒数 6／5／3／2 回合，归零时生命比例最低的我方倒下、重新倒数；化形起归零时全体另损失 20% 生命；终焉归零那回合我方不能复活。
##   替身 double：被打倒时改由一名生命比例低于 30／50／100／100% 的我方代它倒下，本体回到 20／30／50／60% 生命；化形起能替两次；终焉被换下的人本场不能复活。
##   骑士队长 captain：在场时逃跑必定失败；我方的「免即死」挡死期、丧钟的几率失效 50／75／100／100%；化形起死期改在被挂的人行动之后立刻结算；
##   终焉同场其他死亡异化的间隔（宣判者）−1 回合。
## - 死期（本线核心计量）：开战、每回合开始在战斗日志里报谁被挂了、丧钟还剩几回合；回合结束时带走被挂的人。终焉级在场时死者本场不能复活。
## 「致命伤害保命」失效：免即死（抵抗阵亡状态）、七印灰印免死（XTianqiQiyinEffects，breaks_saves）已接（cc/tianqi-alien-finale）。
## 没做（交付单「未做」）：各角色模块自带的「不屈」类效果（要逐个角色模块接）；收尸人终焉的吸收技能；
## 画面上的死期钟和倒数（现在只在战斗日志里报）。
##
## 开关：XTianqiDeathLine.ENABLED（死亡线整条）；只认天启篇存档且选了死亡线，发行构建里还要 XTianqi.RELEASE_OPEN。没 prepare 的战斗一概不动。

const META := "xdeath_alien"

static var _pending := ""
## 正在打的死亡异化战（复活挂钩不带 logic，从这里取）
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	return XTianqiLine.data(XTianqiDeathLine.KEY).get("alien", {})


static func preset(key: String) -> Dictionary:
	return XTianqiLine.alien_preset(XTianqiDeathLine.KEY, key)


## 下一场战斗按这个预设异化（omen／spread／apostle10／apostle20／apostle30）。不收时返回 false。
static func prepare(key: String, s: XState = null) -> bool:
	if preset(key).is_empty() or not XTianqiDeathLine.allowed(s):
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


## 本线做好了战斗规则的种类（按段异化 XTianqiSegAlien 只从这里面抽）
static func kinds() -> Array:
	return data().get("kinds", {}).keys()


## 某只敌人的异化记录 {tier, kind, idx, ...}；不是异化怪为空
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
	if key == "" or not XTianqiDeathLine.allowed(s):
		return
	var p := preset(key)
	var picks := _pick_units(logic.enemies, p.get("units", "all"))
	var from := int(p.get("stats_from", 0))
	if from > 0:  # 同场没被选中的敌人也换数值（开场在 5 层左右打，原数值太高）
		for e in logic.enemies.filter(func(x): return not x.hidden and not picks.has(x)):
			_borrow_stats(e, from)
	apply(logic, s, key, picks.map(func(e): return {"enemy": e, "tier": str(p.tier), "kind": str(p.kind), "stats_from": int(p.get("stats_from", 0))}))


## 把指定的敌人变成异化怪（预设和按段异化共用）：list 每项 {enemy, tier, kind[, stats_from]}；返回 true＝这场有异化
static func apply(logic, s: XState, key: String, list: Array) -> bool:
	if logic.has_meta(META):
		logic.remove_meta(META)
	if list.is_empty() or not XTianqiDeathLine.allowed(s):
		return false
	var f := {"preset": key, "units": {}, "queue": [], "doom": {}, "dead": {}, "lock": {}, "no_revive": {}, "knell_lock": -1}
	var names := PackedStringArray()
	for row in list:
		var e = row.enemy
		var ti := tier_info(str(row.tier))
		if ti.is_empty() or kind_info(str(row.kind)).is_empty():
			continue
		var base := []
		for i in range(8):
			base.append(e.param_base_unscaled(i))
		var from := int(row.get("stats_from", 0))
		if _borrow_stats(e, from):
			base = XDB.rec("Enemies", from).params.map(func(v): return float(v))
		var idx := int(ti.get("idx", 0))
		## base：异化前的基础能力值（换过数值的按换后的），级的生命倍率和收尸人的加值都按它
		var u := {"tier": str(row.tier), "kind": str(row.kind), "idx": idx, "base": base}
		match str(row.kind):
			"verdict":
				u["last"] = 0
			"knell":
				u["count"] = int(kind_info("knell").count[idx])
			"double":
				u["used"] = 0
		f.units[e] = u
		e.add_param(0, float(base[0]) * (float(ti.hp) - 1.0))
		e.hp = e.mhp
		e.mp = e.mmp
		e.set_meta("tianqi_prefix", str(ti.name) + "·")
		names.append("%s（%s·%s）" % [e.original_name(), str(ti.name), str(kind_info(str(row.kind)).name)])
	if f.units.is_empty():
		return false
	logic.set_meta(META, f)
	_logic_ref = weakref(logic)
	if _captain_idx(logic) >= 0:
		logic.can_escape = false
	_say(f, "死亡的异化：%s。" % "、".join(names))
	_say(f, doom_text(logic))
	return true


## 能力值换成另一只敌人的原数值（借外观、用它的数值；神话倍率也去掉）。没换返回 false
static func _borrow_stats(e, from: int) -> bool:
	if from <= 0 or XDB.rec("Enemies", from).is_empty():
		return false
	var ref: Array = XDB.rec("Enemies", from).params
	for i in range(8):
		e.add_param(i, float(ref[i]) - e.param_base_unscaled(i))
	e.hp = e.mhp
	e.mp = e.mmp
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


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


# ---- 查询 ----

## 场上活着的某种异化 [[敌人, 记录], ...]
static func _alive_of(logic, kind: String) -> Array:
	var f := fight(logic)
	var out := []
	for e in f.get("units", {}):
		if e.is_alive() and str(f.units[e].kind) == kind:
			out.append([e, f.units[e]])
	return out


static func _max_idx(logic, kind: String) -> int:
	var top := -1
	for pair in _alive_of(logic, kind):
		top = maxi(top, int(pair[1].idx))
	return top


static func _captain_idx(logic) -> int:
	return _max_idx(logic, "captain")


## 场上有活着的终焉级死亡异化（死者本场不能复活）
static func _zhongyan(logic) -> bool:
	var f := fight(logic)
	for e in f.get("units", {}):
		if e.is_alive() and int(f.units[e].idx) >= 3:
			return true
	return false


static func doomed(logic, a) -> bool:
	return active(logic) and fight(logic).doom.has(a)


## 这一招挂死期的宣判者间隔（骑士队长终焉在场 −1，最少 1）
static func verdict_interval(logic, idx: int) -> int:
	var n := int(kind_info("verdict").interval[idx])
	if _captain_idx(logic) >= 3:
		n -= 1
	return maxi(1, n)


static func doom_text(logic) -> String:
	if not active(logic):
		return ""
	var f := fight(logic)
	var parts := PackedStringArray()
	var marked := PackedStringArray()
	for a in f.doom:
		if a.is_alive():
			marked.append(a.display_name())
	if not marked.is_empty():
		parts.append("死期：%s会在本回合结束时死去" % "、".join(marked))
	for pair in _alive_of(logic, "knell"):
		parts.append("丧钟还剩 %d 回合" % int(pair[1].count))
	if _captain_idx(logic) >= 0:
		parts.append("骑士队长在场：逃跑必定失败")
	return "；".join(parts) + "。" if not parts.is_empty() else ""


static func _report(logic) -> void:
	var t := doom_text(logic)
	if t != "":
		_say(fight(logic), t)


# ---- 死亡的结算 ----

## 骑士队长让「免即死」失效（按场上最高级的几率掷一次）
## 骑士队长在场：别的模块的「致命伤害保命」（七印灰印免死等）按队长的失效几率失效
static func breaks_saves(logic) -> bool:
	return active(logic) and _captain_breaks(logic)


static func _captain_breaks(logic) -> bool:
	var c := _captain_idx(logic)
	if c < 0:
		return false
	var rate := float(kind_info("captain").fail[c])
	return rate >= 1.0 or logic._int(0, 99, "tianqi_death_captain") < roundi(rate * 100.0)


## 让我方一人倒下：resistible＝免即死（抵抗阵亡状态）挡得住（骑士队长可能让它失效）。返回是不是真倒下了
static func _kill(logic, a, resistible: bool, why: String) -> bool:
	if not a.is_alive():
		return false
	var f := fight(logic)
	if resistible and a.traits_set(XBattler.TRAIT_STATE_RESIST).has(1) and not _captain_breaks(logic):
		_say(f, "%s挡住了%s。" % [a.display_name(), why])
		return false
	_say(f, "%s：%s倒下了。" % [why, a.display_name()])
	a.immortal = false
	a.shield = 0.0
	a.hp = 0.0
	if not a.state_ids.has(1):
		a.add_new_state(1)
	a.refresh_resources()
	f.queue.append({"type": "collapse", "target": a, "views": logic.views([a])})
	if _zhongyan(logic):
		f.no_revive[a] = true
	return true


## 打倒了挂标记的宣判者（侵染、蚀骨）：它挂的死期解开
static func _lift_dooms(logic) -> void:
	var f := fight(logic)
	for a in f.doom.keys():
		var judge = f.doom[a]
		var r: Dictionary = f.units.get(judge, {})
		if judge.is_dead() and int(r.get("idx", 0)) < 2:
			f.doom.erase(a)
			if a.is_alive():
				_say(f, "宣判者倒下了，%s的死期解开了。" % a.display_name())


## 带走一人的死期
static func _resolve_doom(logic, a) -> void:
	var f := fight(logic)
	var judge = f.doom.get(a)
	f.doom.erase(a)
	var idx := int(f.units.get(judge, {}).get("idx", 0))
	_kill(logic, a, idx < 2, "死期")


## 新倒下的我方：收尸人变强、回血；化形起锁 2 回合不能复活
static func _scan_deaths(logic) -> void:
	var f := fight(logic)
	var fresh := []
	for a in logic.actors:
		if a.is_dead():
			if not f.dead.has(a):
				f.dead[a] = true
				fresh.append(a)
		else:
			f.dead.erase(a)
	if fresh.is_empty():
		return
	var info := kind_info("reaper")
	for pair in _alive_of(logic, "reaper"):
		var e = pair[0]
		var idx := int(pair[1].idx)
		var base: Array = pair[1].base
		for a in fresh:
			var up := float(info.up[idx])
			for i in [2, 3, 4, 5]:
				e.add_param(i, float(base[i]) * up)
			e.hp = minf(float(e.mhp), float(e.hp) + floorf(float(e.mhp) * float(info.heal[idx])))
			e.refresh_resources()
			_say(f, "%s收走了%s：属性 +%d%%，生命回复了。" % [e.display_name(), a.display_name(), roundi(up * 100.0)])
			if idx >= 2:
				f.lock[a] = int(logic.turn) + int(info.lock_turns)


# ---- 挂钩 ----

## BattleLogic.start_turn：宣判者挂死期，报死期和丧钟
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var turn := int(logic.turn)
	for pair in _alive_of(logic, "verdict"):
		var e = pair[0]
		var r: Dictionary = pair[1]
		var idx := int(r.idx)
		if turn - int(r.last) < verdict_interval(logic, idx):
			continue
		r.last = turn
		for _n in range(int(kind_info("verdict").targets[idx])):
			var live: Array = logic.actors.filter(func(a): return a.is_alive() and not f.doom.has(a))
			if live.is_empty():
				break
			var t = live[logic._int(0, live.size() - 1, "tianqi_death_verdict")]
			if XTianqiRewards.doom_spared(logic, t, false):  # 天启篇奖励：净印·长明（异化怪不算终焉）
				_say(f, "%s：「现在一切结束了。」死期落在%s身上，被净印挡下，只损失了一半生命。" % [e.display_name(), t.display_name()])
				continue
			f.doom[t] = e
			_say(f, "%s：「现在一切结束了。」%s被挂上了死期。" % [e.display_name(), t.display_name()])
	_report(logic)
	return take_logs(logic)


## BattleLogic.act 末尾：收尸人、宣判者倒下解开死期；化形骑士队长在场时被挂的人行动完立刻结算
static func after_action(logic, u) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	_lift_dooms(logic)
	if u is XActor and f.doom.has(u) and _captain_idx(logic) >= 2:
		_resolve_doom(logic, u)
	_scan_deaths(logic)
	return take_logs(logic)


## BattleLogic.end_turn：死期带走、丧钟倒数
static func end_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	_lift_dooms(logic)
	for a in f.doom.keys():
		_resolve_doom(logic, a)
	_scan_deaths(logic)
	var info := kind_info("knell")
	for pair in _alive_of(logic, "knell"):
		var r: Dictionary = pair[1]
		var idx := int(r.idx)
		r.count = int(r.count) - 1
		if int(r.count) > 0:
			continue
		r.count = int(info.count[idx])
		_say(f, "%s的钟声敲响了。" % pair[0].display_name())
		if idx >= 3:
			f.knell_lock = int(logic.turn)
		var live: Array = logic.actors.filter(func(a): return a.is_alive())
		if live.is_empty():
			break
		live.sort_custom(func(a, b): return a.hp_rate() < b.hp_rate())
		_kill(logic, live[0], idx < 2, "丧钟")
		if idx >= 2:
			for a in logic.actors:
				if a.is_alive():
					a.hp = maxf(1.0, float(a.hp) - floorf(float(a.mhp) * float(info.toll_loss)))
					a.refresh_resources()
			_say(f, "钟声震得我方全体损失了 %d%% 生命。" % roundi(float(info.toll_loss) * 100.0))
	_scan_deaths(logic)
	return take_logs(logic)


## BattleLogic.execute_hp_damage：替身被打倒时改由一名我方代它倒下，本体以部分生命继续
static func hp_damage(logic, u, t, value: float) -> float:
	if value <= 0.0 or not active(logic) or not t is XEnemy:
		return value
	var r := unit(logic, t)
	if r.is_empty() or str(r.kind) != "double" or not t.is_alive() or value < float(t.hp):
		return value
	var info := kind_info("double")
	var idx := int(r.idx)
	if int(r.used) >= int(info.times[idx]):
		return value
	var below := float(info.below[idx])
	var cands: Array = logic.actors.filter(func(a): return a.is_alive() and a.hp_rate() <= below)
	if cands.is_empty():
		return value
	cands.sort_custom(func(a, b): return a.hp_rate() < b.hp_rate())
	var f := fight(logic)
	r.used = int(r.used) + 1
	var victim = cands[0]
	_say(f, "%s的替身：%s代它倒下了。" % [t.display_name(), victim.display_name()])
	_kill(logic, victim, false, "替身")
	if idx >= 3:
		f.no_revive[victim] = true
	t.hp = maxf(1.0, floorf(float(t.mhp) * float(info.heal[idx])))
	t.refresh_resources()
	return 0.0


## BattleLogic.try_escape：骑士队长在场时逃跑必定失败
static func blocks_escape(logic) -> bool:
	return active(logic) and _captain_idx(logic) >= 0


## XBattler.remove_state(1)：终焉在场时的死者、替身终焉换下的人、收尸人化形锁住的、丧钟终焉归零那回合，不能复活
static func blocks_revive(b) -> bool:
	var logic = active_logic()
	if logic == null or not b is XActor or not logic.actors.has(b):
		return false
	var f := fight(logic)
	if f.no_revive.has(b) or int(f.knell_lock) == int(logic.turn):
		return true
	return f.lock.has(b) and int(logic.turn) < int(f.lock[b])


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		var f := fight(logic)
		for e in f.get("units", {}):
			if e.has_meta("tianqi_prefix"):
				e.remove_meta("tianqi_prefix")
		logic.remove_meta(META)
		f.clear()
	_logic_ref = null
