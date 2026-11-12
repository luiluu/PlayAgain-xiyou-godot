class_name XRiftAlien
extends RefCounted
## 【cc·天启篇相关·未经审查】漩涡五阶段「怪物逐渐异化」（设计稿 方案/重制版_漩涡五阶段怪物异化设计稿_v0.1.md，Kyo 11-12 六项全按默认）。
## 数据 res://modes/xiyou/rift_alien.json（测试参数，数字避开 4）。只管西游（玩家手里的重制版）；天启篇存档一概不动（天启篇走 XTianqiSegAlien）。
##
## 阶段读 stage()：XRift.stage()（现在 1 或 2），测试和以后的阶段三～五用 STAGE_OVERRIDE。每升一阶，上一阶的东西保留再往上叠。
## - 一阶、开关关：什么都不建，战斗与原版逐值相同。
## - 二阶「侵染」：只有画面。守层者身上幽紫一明一暗（6 秒）；稀有、精英、首领、非常稀有进场 11% 闪一下（1 秒褪掉）。
##   不进存档、不改数值、不改名字；闪不闪用本模块自己的随机流（由本场种子派生），战斗规则随机流一个数都不取。
## - 三阶起：按阶段表给敌群定一只异化怪（守层者＞深渊＞首领＞稀有，一场最多一只；小怪不异化）。
##   级：侵染／蚀骨／化形（西游不出终焉），生命 ×1.25／×1.5／×2，名字前加「级·」。被选中的那只不判神话（照样掷过，随机流不变，掷中了也去掉）。
##   种类从无主池（四线各借一种）随机：战狂（八项 ×1.5／×2／×3；化形每次受伤攻击 +5%）、荒年者（我方受到的回复 −20／−30／−50%；化形我方再生失效）、
##   毒腺（命中我方附加中毒，每回合扣最大生命 3／5／8%，3 回合；化形可叠 3 层）、
##   丧钟（开场倒数 5／3／2 回合，归零时生命比例最低的我方倒下、重新倒数；侵染蚀骨可被即死免疫挡；化形归零时全体再损失 20% 生命）。
##   不带四线的核心计量、线规则和终焉效果。判定、种类、掉落都用本模块自己的随机流；没选中异化的战斗与一阶逐值相同。
## - 掉落：赢了且异化怪倒下，按级掷（3／8／20%）一件西游原版异化装备（22 件本体等权，XAlienation.create；首领以上来源算 boss），
##   名字「级·词条·原名」，分解按级给能量 1／2／3。原版异化整套隐藏时（XAlienBattle.hidden，含发行隐藏）不掉。原版 1% 异化遭遇照旧各算各的。
## - 异化图鉴：赢了倒下的异化怪按「借自的线:种类:级」点亮天启篇异化图鉴（XConfig.tianqi_alien_mark，跨存档，不给数值和物品）。
## 外观的纹路贴图、附加件、化形替换件和变形演出还没有美术，先用 tint() 给 XBattlerSprite 的幽紫偏色顶着。
##
## 开关（O-356）：ENABLED＝false 时一概不建（画面、异化、掉落、图鉴都没有）；发行构建里另要 RELEASE_OPEN（默认关，不推给玩家）。

const PATH := "res://modes/xiyou/rift_alien.json"
const META := "xrift_alien"
const LOOK := "xrift_look"

## 开关：false＝漩涡阶段不影响怪物
static var ENABLED := true
## 测试用／以后扩阶段：>0 时当作这一阶（1～5），0＝读 XRift.stage()
static var STAGE_OVERRIDE := 0
## 发行开关：false＝发行构建（ReleaseEntry.is_release）里一概不建（天启篇相关，Kyo 11-12 只进本地 main、不推给玩家）；以后对玩家开放改成 true
static var RELEASE_OPEN := false
## 测试用：≥0 时掉落的「掷中没有」和「选哪件本体」都取它
static var force_drop := -1.0

static var _data: Dictionary = {}
static var _tag := RegEx.create_from_string("^【([^】]+)】")
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XRiftAlien: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XRiftAlien: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


# ---- 开关、阶段 ----

static func stage() -> int:
	return clampi(STAGE_OVERRIDE, 1, 5) if STAGE_OVERRIDE > 0 else XRift.stage()


## 这一档受漩涡阶段影响：开关开着、不是天启篇存档、阶段二起
static func on(s: XState) -> bool:
	return ENABLED and s != null and not XTianqi.active(s) and stage() >= 2 and (RELEASE_OPEN or not ReleaseEntry.is_release())


static func tier_info(tier: String) -> Dictionary:
	var t = data().get("tiers", {}).get(tier)
	return t if t is Dictionary else {}


static func kind_info(kind: String) -> Dictionary:
	var k = data().get("kinds", {}).get(kind)
	return k if k is Dictionary else {}


static func kinds() -> Array:
	return data().get("kinds", {}).keys()


static func class_of(e) -> String:
	var name := str(e.data().get("name", "")) if e is XEnemy else str(e)
	var m := _tag.search(name)
	if m == null:
		return ""
	return str(data().get("classes", {}).get(m.get_string(1), ""))


static func floor_of(s: XState) -> int:
	var f := XDungeon.map_floor(int(s.map_id))
	if f <= 0:
		f = XTianqi.cleared_floors(s)
	return clampi(f, 1, int(data().get("floor_max", 30)))


static func diff_key(difficulty: int) -> String:
	var d: Dictionary = data().get("difficulty", {})
	return str(d.get("map", {}).get(str(difficulty), d.get("map_default", "mid")))


static func _order() -> Array:
	return data().get("tier_order", [])


static func _tier_at(i: int) -> String:
	var t := _order()
	return str(t[clampi(i, 0, t.size() - 1)])


## 某类怪在这一阶、这一层、这一档难度下的规则 {rate 百分数, tier, up, up_rate}；不异化为空
static func rule(cls: String, st: int, floor_no: int, difficulty: int) -> Dictionary:
	var row = data().get("stages", {}).get(str(st), {}).get(cls)
	if not row is Dictionary:
		return {}
	var r: Dictionary = row.duplicate(true)
	if r.has("bands"):
		var tier := ""
		for b in r.bands:
			if floor_no >= int(b.from) and floor_no <= int(b.to):
				tier = str(b.tier)
		if tier == "":
			tier = str((r.bands as Array).back().tier)
		r.erase("bands")
		r["tier"] = tier
	r["up"] = str(r.get("up", ""))
	r["up_rate"] = float(r.get("up_rate", 0))
	var d: Dictionary = data().get("difficulty", {}).get(diff_key(difficulty), {})
	var rate := float(r.rate)
	if cls == "rare" or cls == "very_rare":
		rate = rate * float(d.get("rate_mult", 1)) + float(d.get("rate_add", 0))
	r["rate"] = clampf(rate, 0.0, 100.0)
	var order := _order()
	if cls == "rare":
		var shift := int(d.get("rare_up_shift", 0))
		if shift > 0:
			if str(r.up) == "":
				r.up = _tier_at(order.find(str(r.tier)) + shift)
				r.up_rate = float(d.get("rare_up_rate", 0))
			else:
				r.up = _tier_at(order.find(str(r.up)) + shift)
		if d.has("rare_max"):
			var cap := order.find(str(d.rare_max))
			if order.find(str(r.tier)) > cap:
				r.tier = _tier_at(cap)
			if str(r.up) != "" and order.find(str(r.up)) > cap:
				r.up = _tier_at(cap)
		if str(r.up) == str(r.tier):
			r.up = ""
			r.up_rate = 0.0
	elif cls == "guardian":
		var g := int(d.get("guardian_shift", 0))
		if g != 0:
			r.tier = _tier_at(order.find(str(r.tier)) + g)
	return r


## 给一场敌群定异化：[{enemy, tier, kind, class}]。roll(理由, 键) 返回 [0,1)（战斗里是本模块自己的随机流，测试可换）
static func plan(s: XState, enemies: Array, roll: Callable) -> Array:
	var st := stage()
	if not on(s) or st < 3:
		return []
	var floor_no := floor_of(s)
	var order: Array = data().get("priority", [])
	var cands := []
	for i in enemies.size():
		var e = enemies[i]
		if e.hidden:
			continue
		var cls := class_of(e)
		if cls != "":
			cands.append([order.find(cls), i, e, cls])
	cands.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var ks := kinds()
	var out := []
	for c in cands:
		if out.size() >= int(data().get("max_units", 1)):
			break
		var e = c[2]
		var cls: String = c[3]
		var r := rule(cls, st, floor_no, int(s.difficulty))
		if r.is_empty():
			continue
		var key := "%d:%d" % [int(c[1]), int(e.enemy_id)]
		if float(r.rate) < 100.0 and float(roll.call("rift_alien.rate", key)) * 100.0 >= float(r.rate):
			continue
		var tier := str(r.tier)
		if str(r.up) != "" and float(roll.call("rift_alien.up", key)) * 100.0 < float(r.up_rate):
			tier = str(r.up)
		var kind = ks[mini(floori(float(roll.call("rift_alien.kind", key)) * ks.size()), ks.size() - 1)]
		out.append({"enemy": e, "tier": tier, "kind": str(kind), "class": cls})
	return out


# ---- 本场 ----

static func active(logic) -> bool:
	return logic != null and logic.has_meta(META)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if active(logic) else {}


static func active_logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


static func unit(logic, e) -> Dictionary:
	return fight(logic).get("units", {}).get(e, {}) if active(logic) else {}


static func is_alien(logic, e) -> bool:
	return not unit(logic, e).is_empty()


## 本模块的随机流：由本场规则流的种子和敌群号派生，不从规则流取数
static func stream(logic) -> XRandomStream:
	var seed := str(logic._rule().snapshot().get("seed", "0000000000000000"))
	return XRandomStream.create(XRandomStream.derive(seed, "rift_alien|%d" % int(logic.troop_id)), "rift_alien")


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


## BattleLogic.setup：敌群建完、天启篇各异化之后调
static func setup(logic, s: XState) -> void:
	end(logic)
	if not on(s):
		return
	var rng := stream(logic)
	var f := {"units": {}, "queue": [], "poison": {}, "rng": rng}
	logic.set_meta(META, f)
	_logic_ref = weakref(logic)
	_mark_looks(logic, rng)
	var list := plan(s, logic.enemies, func(reason: String, key: String) -> float: return rng.next_float(reason, key))
	apply(logic, list)


## 二阶画面：守层者常驻一明一暗，稀有以上 11% 进场闪一下
static func _mark_looks(logic, rng: XRandomStream) -> void:
	var lk: Dictionary = data().get("look", {})
	for i in logic.enemies.size():
		var e = logic.enemies[i]
		var cls := class_of(e)
		if cls == "":
			continue
		var look := {"pulse": cls == "guardian", "flash": false, "tier": ""}
		if cls == "rare" or cls == "very_rare":
			look.flash = rng.next_float("rift_alien.flash", "%d:%d" % [i, int(e.enemy_id)]) * 100.0 < float(lk.get("flash_rate", 0))
		e.set_meta(LOOK, look)


## 把指定敌人变成异化怪：list 每项 {enemy, tier, kind}
static func apply(logic, list: Array) -> bool:
	var f := fight(logic)
	if f.is_empty():
		return false
	for row in list:
		var e = row.enemy
		var tier := str(row.tier)
		var kind := str(row.kind)
		var ti := tier_info(tier)
		var ki := kind_info(kind)
		if ti.is_empty() or ki.is_empty():
			continue
		var idx := int(ti.idx)
		if e.elite:  # 和神话互斥：掷过的神话去掉
			e.elite = false
			e.elite_hue = 0.0
			e.refresh_passive()
		var u := {"tier": tier, "kind": kind, "idx": idx, "class": str(row.get("class", ""))}
		var m := float(ki.mult[idx]) if kind == "berserk" else 1.0
		if kind == "berserk":
			for i in range(8):
				e.add_param(i, e.param_base_unscaled(i) * (m - 1.0))
		e.add_param(0, e.param_base_unscaled(0) * (float(ti.hp) - 1.0) * m)
		if kind == "knell":
			u["count"] = int(ki.count[idx])
		e.recover_all()
		e.set_meta("tianqi_prefix", str(ti.name) + "·")
		var look: Dictionary = e.get_meta(LOOK, {"pulse": false, "flash": false})
		look["tier"] = tier
		e.set_meta(LOOK, look)
		f.units[e] = u
	if f.units.is_empty():
		return false
	for e in f.units:
		var u: Dictionary = f.units[e]
		_say(f, "漩涡的颜色渗进了%s：%s·%s。" % [e.original_name(), str(tier_info(str(u.tier)).name), str(kind_info(str(u.kind)).name)])
		if str(u.kind) == "knell":
			_say(f, "丧钟开始倒数：还剩 %d 回合。" % int(u.count))
	return true


static func _alive_of(logic, kind: String) -> Array:
	var out := []
	var f := fight(logic)
	for e in f.get("units", {}):
		if str(f.units[e].kind) == kind and e.is_alive():
			out.append([e, f.units[e]])
	return out


static func _max_idx(logic, kind: String) -> int:
	var n := -1
	for pair in _alive_of(logic, kind):
		n = maxi(n, int(pair[1].idx))
	return n


# ---- 挂钩 ----

## BattleLogic.start_turn：报丧钟
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	for pair in _alive_of(logic, "knell"):
		_say(f, "丧钟还剩 %d 回合。" % int(pair[1].count))
	return take_logs(logic)


## BattleLogic.execute_hp_damage：化形战狂受伤叠攻；毒腺命中我方附加中毒
static func hp_damage(logic, u, t, value: float) -> float:
	if value <= 0.0 or not active(logic):
		return value
	var f := fight(logic)
	var tr: Dictionary = f.units.get(t, {})
	if not tr.is_empty() and str(tr.kind) == "berserk" and int(tr.idx) >= 2 and t.is_alive():
		t.add_param(2, t.param_base_unscaled(2) * float(kind_info("berserk").rage_per_hit))
	var ur: Dictionary = f.units.get(u, {})
	if not ur.is_empty() and str(ur.kind) == "gland" and t is XActor and logic.actors.has(t) and u.is_alive():
		_add_poison(f, t, int(ur.idx))
	return value


static func _add_poison(f: Dictionary, a, idx: int) -> void:
	var k := kind_info("gland")
	var list: Array = f.poison.get(a, [])
	var cap := int(k.stack_max) if idx >= 2 else 1
	if list.size() < cap:
		list.append(int(k.turns))
	else:
		list.sort()
		list[0] = int(k.turns)  # 叠满了刷新最快到期的那层
	f.poison[a] = list
	_say(f, "%s中毒了（%d 层）。" % [a.display_name(), list.size()])


## 本场毒腺中毒的层数（测试、画面用）
static func poison_of(logic, a) -> Array:
	return fight(logic).get("poison", {}).get(a, []) if active(logic) else []


## BattleLogic.end_turn：中毒扣血、丧钟倒数
static func end_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var rate := float(kind_info("gland").poison[maxi(0, _max_idx(logic, "gland"))])  # 毒腺倒下后已挂的中毒照侵染档走完
	for a in f.poison.keys():
		var list: Array = f.poison[a]
		if a.is_alive():
			var lose := floorf(float(a.mhp) * rate * list.size())
			if lose > 0.0:
				var before: float = a.hp
				a.hp = maxf(0.0, a.hp - lose)
				a.refresh_resources()
				f.queue.append({"type": "regen", "target": a, "hp": before - a.hp, "views": logic.views([a])})
				if a.is_dead():
					logic._die(a)
					f.queue.append({"type": "collapse", "target": a, "views": logic.views([a])})
		var left := []
		for n in list:
			if int(n) > 1:
				left.append(int(n) - 1)
		if left.is_empty():
			f.poison.erase(a)
		else:
			f.poison[a] = left
	var info := kind_info("knell")
	for pair in _alive_of(logic, "knell"):
		var r: Dictionary = pair[1]
		var idx := int(r.idx)
		r.count = int(r.count) - 1
		if int(r.count) > 0:
			continue
		r.count = int(info.count[idx])
		_say(f, "%s的钟声敲响了。" % pair[0].display_name())
		var live: Array = logic.actors.filter(func(a): return a.is_alive())
		if live.is_empty():
			break
		live.sort_custom(func(a, b): return a.hp_rate() < b.hp_rate())
		_kill(logic, f, live[0], idx < 2)
		if idx >= 2:
			for a in logic.actors:
				if a.is_alive():
					a.hp = maxf(1.0, float(a.hp) - floorf(float(a.mhp) * float(info.toll_loss)))
					a.refresh_resources()
			_say(f, "钟声震得我方全体损失了 %d%% 生命。" % roundi(float(info.toll_loss) * 100.0))
	return take_logs(logic)


static func _kill(logic, f: Dictionary, a, resistible: bool) -> void:
	if resistible and a.traits_set(XBattler.TRAIT_STATE_RESIST).has(1):
		_say(f, "%s挡住了丧钟。" % a.display_name())
		return
	_say(f, "丧钟：%s倒下了。" % a.display_name())
	a.immortal = false
	a.shield = 0.0
	a.hp = 0.0
	if not a.state_ids.has(1):
		a.add_new_state(1)
	a.refresh_resources()
	f.queue.append({"type": "collapse", "target": a, "views": logic.views([a])})


## 荒年者在场时我方受到的回复倍率（1＝不变）
static func heal_mult(logic) -> float:
	var i := _max_idx(logic, "lean")
	return 1.0 - float(kind_info("lean").heal_down[i]) if i >= 0 else 1.0


## XResourceContext._gain：荒年者在场时我方回复生命、法力打折
static func gain(b, resource: String, amount: float) -> float:
	if amount <= 0.0 or not b is XActor or not (resource == "hp" or resource == "mp"):
		return amount
	var logic = active_logic()
	if logic == null or not active(logic) or not logic.actors.has(b):
		return amount
	var h := heal_mult(logic)
	return amount if h >= 1.0 else floorf(amount * h)


## BattleLogic 回合末再生：荒年者打折，化形荒年者在场时我方再生失效
static func regen(logic, b, dh: float, dm: float) -> Array:
	if not active(logic) or not b is XActor or not logic.actors.has(b) or _max_idx(logic, "lean") < 0:
		return [dh, dm]
	var off := _max_idx(logic, "lean") >= 2
	var h := heal_mult(logic)
	if dh > 0.0:
		dh = 0.0 if off else floorf(dh * h)
	if dm > 0.0:
		dm = 0.0 if off else floorf(dm * h)
	return [dh, dm]


# ---- 掉落、图鉴 ----

## 西游原版异化装备的 22 件本体（alienation.json pools 的键 "w:1042"）
static func bodies() -> Array:
	return XAlienation.config().get("pools", {}).keys()


## BattleLogic.grant：赢了，倒下的异化怪按级掷一件原版异化装备；先点亮图鉴
static func grant(logic) -> Array:
	var got := []
	if not active(logic) or not on(logic.state):
		return got
	var s: XState = logic.state
	var f := fight(logic)
	var rng: XRandomStream = f.rng
	for e in f.units:
		var u: Dictionary = f.units[e]
		if not e.is_dead():
			continue
		XConfig.tianqi_alien_mark(XTianqiAlienCodex.key(str(kind_info(str(u.kind)).from), str(u.kind), str(u.tier)))
		if XAlienBattle.hidden():
			continue
		var id: String = logic.stable_id(e)
		if (force_drop if force_drop >= 0.0 else rng.next_float("rift_alien.drop", id)) * 100.0 >= float(tier_info(str(u.tier)).drop):
			continue
		var list := bodies()
		if list.is_empty():
			continue
		var body := str(list[mini(floori((force_drop if force_drop >= 0.0 else rng.next_float("rift_alien.body", id)) * list.size()), list.size() - 1)])
		var parts := body.split(":")
		var origin := "mob" if str(u.get("class", "")) == "rare" else "boss"
		var made := XAlienation.create(s, parts[0], int(parts[1]), origin)
		if made.has("error"):
			push_warning("漩涡异化掉落创建失败：" + str(made.error))
			continue
		var i: Dictionary = made.ok
		i.alien["rift"] = str(u.tier)
		XAlienation.relabel(i)
		s.gear.append(i)
		var l := XAlienation.ledger(s)
		(l.recent as Array).push_front({"name": str(i.name), "origin": origin, "uid": str(i.alien.uid), "kind": XAlienation.kind(i), "id": str(i.get("instanceId", ""))})
		l.recent = (l.recent as Array).slice(0, 30)
		got.append(str(i.name))
	for n in got:
		logic.victory_texts.append("获得 " + n)
	return got


## 漩涡异化装备的级（侵染等的键）；不是为空
static func gear_tier(i) -> String:
	return str(XAlienation.mark(i).get("rift", ""))


## 分解给的能量（按级 1／2／3）；不是漩涡异化装备返回 -1
static func gear_energy(i) -> int:
	var t := gear_tier(i)
	return int(tier_info(t).get("energy", -1)) if t != "" else -1


## 名字前缀「级·」；不是漩涡异化装备为空
static func gear_prefix(i) -> String:
	var t := gear_tier(i)
	return str(tier_info(t).name) + "·" if t != "" and not tier_info(t).is_empty() else ""


# ---- 画面 ----

## XBattlerSprite 每帧问：幽紫偏色（a＝强度）；t 秒＝这只出场后过了多久
static func tint(e, t: float) -> Color:
	if not ENABLED or not e is XEnemy or not e.has_meta(LOOK):
		return Color(0, 0, 0, 0)
	var lk: Dictionary = data().get("look", {})
	var look: Dictionary = e.get_meta(LOOK)
	var a := 0.0
	var tier := str(look.get("tier", ""))
	if tier != "":
		a = float(lk.get("tier_glow", {}).get(tier, 0.0))
	var fx := XConfig.flag("codexScreenFx")  # 二阶的预兆跟大厅「画面特效」设置一起，可关；异化怪的常亮不关
	if fx and bool(look.get("pulse", false)):
		a = maxf(a, float(lk.get("guardian_pulse", 0.0)) * (0.5 - 0.5 * cos(TAU * t / maxf(float(lk.get("period", 6)), 0.01))))
	if fx and bool(look.get("flash", false)) and t < float(lk.get("fade", 1)):
		a = maxf(a, float(lk.get("flash", 0.0)) * (1.0 - t / maxf(float(lk.get("fade", 1)), 0.01)))
	var c: Array = lk.get("color", [0.62, 0.35, 0.95])
	return Color(float(c[0]), float(c[1]), float(c[2]), a)


## BattleLogic.end_battle：清本场
static func end(logic) -> void:
	if logic == null:
		return
	if logic.has_meta(META):
		var f := fight(logic)
		for e in f.get("units", {}):
			if e.has_meta("tianqi_prefix"):
				e.remove_meta("tianqi_prefix")
		logic.remove_meta(META)
	for e in logic.enemies:
		if e is XEnemy and e.has_meta(LOOK):
			e.remove_meta(LOOK)
	_logic_ref = null
