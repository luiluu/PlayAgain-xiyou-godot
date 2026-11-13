class_name XTianqiQiyinDrop
extends RefCounted
## 天启篇「七印祭坛」里副本的掉落逻辑（纯函数）：数据表 modes/xiyou/tianqi_data/qiyin_drop.json（七印祭坛方案 v0.4，Kyo 11-12 定稿）。
##
## 只算「掉什么、掉几件、印屑多少」，不碰背包、存档、战斗结算、界面；还没接进流程。
## 状态是一个 Dictionary（字段见 new_state()），每个函数拿旧状态、在返回值的 state 里给新状态，不改传进来的那份。
## 随机数一律用注入的 XRandomStream（测试可固定种子或喂脚本磁带）；每个函数的抽取顺序写在函数注释里，接进存档回放时照这个顺序。
##
## 物品：
##   套装件 {"kind": "set", "seal", "part", "true_seal": bool, "grades": [成色×3]}
##   毕业武器 {"kind": "weapon", "seal", "wtype"（表里 weapon_classes 的名字）, "true_seal", "grades"}
##   成色键：putong 普通、shangpin 上品、ji 极。
## 印键：bai hong hei hui xun zhen mo；部位键：head body hands waist legs feet；难度键同 XTianqi.DIFFICULTIES。

const PATH := "res://modes/xiyou/tianqi_data/qiyin_drop.json"
const KIND_SET := "set"
const KIND_WEAPON := "weapon"
const OFFER_SHARDS := "shards"
const OFFER_WEAPON := "weapon"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyinDrop: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyinDrop: JSON 解析失败 " + PATH)
	return _data


## 测试用：清掉缓存，下次重新读文件
static func reload() -> void:
	_data = {}


static func _sec(name: String) -> Dictionary:
	var v = data().get(name, {})
	return v if v is Dictionary else {}


static func _f(sec: String, key: String) -> float:
	return float(_sec(sec).get(key, 0.0))


static func _i(sec: String, key: String) -> int:
	return int(_sec(sec).get(key, 0))


static func seals() -> Array:
	return data().get("seals", []).duplicate()


static func parts() -> Array:
	return data().get("parts", []).duplicate()


## 某印的毕业武器类型名单（默印 12 类）
static func weapon_classes(seal: String) -> Array:
	var v = _sec("weapon_classes").get(seal, [])
	return v.duplicate() if v is Array else []


static func artifact_keys() -> Array:
	return _sec("artifact").get("keys", []).duplicate()


## 守层者首杀揭开哪几印；不是 31～35 层为空
static func floor_seals(floor_no: int) -> Array:
	var v = _sec("floor_first_kill").get(str(floor_no), [])
	return v.duplicate() if v is Array else []


static func is_difficulty(key: String) -> bool:
	return _sec("true_seal").get("chance", {}).has(key)


# ---- 状态 ----

## 新存档的掉落状态：
##   set_miss {印: 连空次数}（Boss 没掉套装件的次数，掉了归零）
##   weapon_miss {印: 连空次数}（Boss 没掉毕业武器的次数）
##   true_miss 全局连续没出真印的件数
##   enter_count 进里副本总次数（任何印）
##   restless 当前躁动的印（"" 是没有或已平息）；restless_last 上一次抽中的印（不连抽用，平息后也留着）
##   first_clear {印: true}；floor_kill {"31": true}
static func new_state() -> Dictionary:
	return {"set_miss": {}, "weapon_miss": {}, "true_miss": 0, "enter_count": 0,
		"restless": "", "restless_last": "", "first_clear": {}, "floor_kill": {}}


static func _copy(state: Dictionary) -> Dictionary:
	var s := new_state()
	for k in state:
		var v = state[k]
		s[k] = v.duplicate(true) if v is Dictionary or v is Array else v
	return s


# ---- 小工具 ----

## owned 可以是部位数组（就是这一印的），也可以是 {印: 部位数组}
static func _owned_for(owned, seal: String) -> Array:
	if owned is Dictionary:
		var v = owned.get(seal, [])
		return v.duplicate() if v is Array else []
	if owned is Array:
		return owned.duplicate()
	return []


## 部位随机：已有部位权重乘 owned_part_weight。抽 1 个浮点数。
static func _pick_part(owned: Array, rng: XRandomStream, reason: String) -> String:
	var ps := parts()
	var w_owned := _f("boss_set", "owned_part_weight")
	var weights: Array = []
	var total := 0.0
	for p in ps:
		var w: float = w_owned if owned.has(p) else 1.0
		weights.append(w)
		total += w
	var r := rng.next_float(reason) * total
	for i in ps.size():
		r -= float(weights[i])
		if r < 0.0:
			return str(ps[i])
	return str(ps[ps.size() - 1])


## 成色：每条词条按权重掷；真印全是 true_grade、不抽随机数
static func _roll_grades(true_seal: bool, rng: XRandomStream) -> Array:
	var g := _sec("grades")
	var n := int(g.get("slots", 0))
	var out: Array = []
	if true_seal:
		for i in n:
			out.append(str(g.get("true_grade", "ji")))
		return out
	var weights: Dictionary = g.get("weights", {})
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	for i in n:
		var r := rng.next_float("qiyin_grade") * total
		var pick := ""
		for k in weights:
			pick = str(k)
			r -= float(weights[k])
			if r < 0.0:
				break
		out.append(pick)
	return out


## 真印：暗保底到了不抽随机数直接出；否则按难度几率（乘 mult）掷。改 s.true_miss。
static func _roll_true(s: Dictionary, difficulty: String, mult: float, rng: XRandomStream) -> bool:
	var t := _sec("true_seal")
	var hit := false
	if int(s.true_miss) >= int(t.get("pity_misses", 0)):
		hit = true
	else:
		var p := minf(1.0, float(t.get("chance", {}).get(difficulty, 0.0)) * mult)
		hit = rng.next_float("qiyin_true_seal") < p
	s.true_miss = 0 if hit else int(s.true_miss) + 1
	return hit


## 一件套装件：部位（forced 非空就不抽）→ 真印 → 成色
static func _make_set(s: Dictionary, seal: String, owned: Array, forced_part: String, difficulty: String,
		true_mult: float, rng: XRandomStream) -> Dictionary:
	var part := forced_part if not forced_part.is_empty() else _pick_part(owned, rng, "qiyin_part")
	var ts := _roll_true(s, difficulty, true_mult, rng)
	return {"kind": KIND_SET, "seal": seal, "part": part, "true_seal": ts, "grades": _roll_grades(ts, rng)}


## 一把毕业武器：类型（forced 非空就不抽）→ 真印 → 成色
static func _make_weapon(s: Dictionary, seal: String, forced_wtype: String, difficulty: String,
		true_mult: float, rng: XRandomStream) -> Dictionary:
	var wtype := forced_wtype
	if wtype.is_empty():
		var cls := weapon_classes(seal)
		wtype = str(cls[rng.next_index_mod(cls.size(), "qiyin_wtype")])
	var ts := _roll_true(s, difficulty, true_mult, rng)
	return {"kind": KIND_WEAPON, "seal": seal, "wtype": wtype, "true_seal": ts, "grades": _roll_grades(ts, rng)}


# ---- 进副本、躁动、直取 ----

## 进一次里副本（任何印都算）：进副本计数 +1；每满 every_enters 次，在 revealed（已揭开的印）里随机抽一印躁动，
## 不连抽上一次抽中的印（只揭开一印时就是它）。返回 {"state", "restless": 这次新抽的印或 ""}。
## 抽取：到点且可选的印有两个以上时 next_index_mod 一次。
static func on_enter(state: Dictionary, revealed: Array, rng: XRandomStream) -> Dictionary:
	var s := _copy(state)
	s.enter_count = int(s.enter_count) + 1
	var picked := ""
	var every := _i("restless", "every_enters")
	if every > 0 and int(s.enter_count) % every == 0 and not revealed.is_empty():
		var pool: Array = revealed.filter(func(x): return str(x) != str(s.restless_last))
		if pool.is_empty():
			pool = revealed.duplicate()
		picked = str(pool[0]) if pool.size() == 1 else str(pool[rng.next_index_mod(pool.size(), "qiyin_restless")])
		s.restless = picked
		s.restless_last = picked
	return {"state": s, "restless": picked}


## 直取：首通过的里副本可以跳过前两场只打 Boss（放弃前两场的印屑）
static func direct_allowed(state: Dictionary, seal: String) -> bool:
	return bool(state.get("first_clear", {}).get(seal, false))


# ---- 里副本 ----

## 前两场精英各打一次调一次：shard_chance 给 1 个印屑。抽 1 个浮点数。返回 {"state", "shards"}。
static func roll_elite(state: Dictionary, rng: XRandomStream) -> Dictionary:
	var hit := rng.next_float("qiyin_elite_shard") < _f("elite", "shard_chance")
	return {"state": _copy(state), "shards": _i("elite", "shards") if hit else 0}


## 献的合法性：offering 为 {} 不献；{"kind": "shards", "part": 部位}；{"kind": "weapon", "wtype": 本印的武器类型}。
## 返回 {"ok", "reason", "shards": 要花的印屑, "weapons": 要消耗的武器把数}。背包够不够由调用方查。
static func offering_check(seal: String, offering: Dictionary) -> Dictionary:
	var out := {"ok": true, "reason": "", "shards": 0, "weapons": 0}
	if offering.is_empty():
		return out
	var o := _sec("offering")
	match str(offering.get("kind", "")):
		OFFER_SHARDS:
			if not parts().has(str(offering.get("part", ""))):
				return {"ok": false, "reason": "bad_part", "shards": 0, "weapons": 0}
			out.shards = int(o.get("shards", {}).get("cost", 0))
		OFFER_WEAPON:
			if not weapon_classes(seal).has(str(offering.get("wtype", ""))):
				return {"ok": false, "reason": "bad_wtype", "shards": 0, "weapons": 0}
			out.weapons = int(o.get("weapon", {}).get("count", 1))
		_:
			return {"ok": false, "reason": "bad_kind", "shards": 0, "weapons": 0}
	return out


## Boss 打赢时的套装件当次几率（含物品掉落加成、躁动），不含暗保底。测试和界面提示用。
static func boss_set_chance(state: Dictionary, seal: String, drop_mult := 1.0) -> float:
	var b := _sec("boss_set")
	var miss := int(state.get("set_miss", {}).get(seal, 0))
	var p := (float(b.get("base", 0.0)) + float(b.get("step", 0.0)) * miss) * drop_mult
	if str(state.get("restless", "")) == seal:
		p *= _f("restless", "set_mult")
	return minf(1.0, p)


## 里副本 Boss 打赢一次。
## owned_parts：这一印背包和身上已有的部位（数组，或 {印: 数组}）；offering 见 offering_check（花费由调用方先扣）；
## drop_mult：物品掉落加成倍率（1.0＝没有），只乘套装件、毕业武器几率。
## 返回 {"state", "set_pieces": [套装件…], "weapon": 武器或 {}, "artifact": 神器键或 "", "shards": 没掉套装件给的印屑,
##   "refund": 献印屑没掉退的印屑, "restless": 这一场是不是躁动印（打完已平息）, "error": ""}。
## 抽取顺序：
##   1 套装件：没到暗保底抽 1 个浮点数定掉不掉；掉了再逐件抽连掉（最多到 max_pieces）；然后逐件：部位（献印屑的第一件不抽）→ 真印（暗保底不抽）→ 成色（真印不抽）
##   2 毕业武器：没到暗保底抽 1 个浮点数；掉了：类型（献武器的不抽）→ 真印 → 成色
##   3 神器：抽 1 个浮点数；中了再 next_index_mod 一次
static func roll_boss(state: Dictionary, seal: String, difficulty: String, owned_parts, offering: Dictionary,
		drop_mult: float, rng: XRandomStream) -> Dictionary:
	var out := {"state": _copy(state), "set_pieces": [], "weapon": {}, "artifact": "", "shards": 0, "refund": 0,
		"restless": false, "error": ""}
	if not seals().has(seal):
		out.error = "bad_seal"
		return out
	if not is_difficulty(difficulty):
		out.error = "bad_difficulty"
		return out
	var chk := offering_check(seal, offering)
	if not chk.ok:
		out.error = "bad_offering:" + str(chk.reason)
		return out
	var s: Dictionary = out.state
	var restless := str(s.restless) == seal
	var true_mult := _f("restless", "true_mult") if restless else 1.0
	var offer_kind := str(offering.get("kind", ""))
	# 1 套装件
	var b := _sec("boss_set")
	var miss := int(s.set_miss.get(seal, 0))
	var dropped := miss >= int(b.get("pity_misses", 0))
	if not dropped:
		dropped = rng.next_float("qiyin_boss_set") < boss_set_chance(s, seal, drop_mult)
	if dropped:
		s.set_miss[seal] = 0
		var count := 1
		while count < int(b.get("max_pieces", 1)) and rng.next_float("qiyin_boss_chain") < float(b.get("chain", 0.0)):
			count += 1
		var owned := _owned_for(owned_parts, seal)
		for i in count:
			var forced := str(offering.get("part", "")) if i == 0 and offer_kind == OFFER_SHARDS else ""
			var piece := _make_set(s, seal, owned, forced, difficulty, true_mult, rng)
			owned.append(piece.part)
			out.set_pieces.append(piece)
	else:
		s.set_miss[seal] = miss + 1
		out.shards = int(b.get("miss_shards", 0))
		if offer_kind == OFFER_SHARDS:
			out.refund = int(_sec("offering").get("shards", {}).get("refund", 0))
	# 2 毕业武器
	var w := _sec("boss_weapon")
	var wmiss := int(s.weapon_miss.get(seal, 0))
	var wdrop := wmiss >= int(w.get("pity_misses", 0))
	if not wdrop:
		var wp := float(w.get("chance", {}).get(difficulty, 0.0)) * drop_mult
		if offer_kind == OFFER_WEAPON:
			wp *= float(_sec("offering").get("weapon", {}).get("chance_mult", 1.0))
		wdrop = rng.next_float("qiyin_boss_weapon") < minf(1.0, wp)
	if wdrop:
		s.weapon_miss[seal] = 0
		var forced_w := str(offering.get("wtype", "")) if offer_kind == OFFER_WEAPON else ""
		out.weapon = _make_weapon(s, seal, forced_w, difficulty, true_mult, rng)
	else:
		s.weapon_miss[seal] = wmiss + 1
	# 3 神器
	var a := _sec("artifact")
	if rng.next_float("qiyin_artifact") < float(a.get("chance", 0.0)):
		var keys: Array = a.get("keys", [])
		out.artifact = str(keys[rng.next_index_mod(keys.size(), "qiyin_artifact_pick")])
	# 躁动打赢一次就平息
	if restless:
		s.restless = ""
		out.restless = true
	return out


## 首通：某印 Boss 第一次打赢，再给 first_clear.set_pieces 件本印套装件（部位随机、已有部位减半、单独掷真印；不吃躁动）。
## 已首通过的返回空。调用方在 roll_boss 之后调（owned 记得算上 roll_boss 刚掉的）。返回 {"state", "set_pieces"}。
static func first_clear(state: Dictionary, seal: String, difficulty: String, owned_parts, rng: XRandomStream) -> Dictionary:
	var s := _copy(state)
	var out := {"state": s, "set_pieces": []}
	if not seals().has(seal) or bool(s.first_clear.get(seal, false)):
		return out
	s.first_clear[seal] = true
	var owned := _owned_for(owned_parts, seal)
	for i in _i("first_clear", "set_pieces"):
		var piece := _make_set(s, seal, owned, "", difficulty, 1.0, rng)
		owned.append(piece.part)
		out.set_pieces.append(piece)
	return out


## 31～35 层守层者首杀：它揭开的每一印各必掉 1 件套装件（31 层白、红各 1 件）。已杀过或不是这几层返回空。
## owned_parts 用 {印: 部位数组}（31 层两印各算各的）。返回 {"state", "set_pieces", "revealed": 这一层揭开的印}。
static func floor_first_kill(state: Dictionary, floor_no: int, difficulty: String, owned_parts, rng: XRandomStream) -> Dictionary:
	var s := _copy(state)
	var revealed := floor_seals(floor_no)
	var out := {"state": s, "set_pieces": [], "revealed": revealed}
	if revealed.is_empty() or bool(s.floor_kill.get(str(floor_no), false)):
		return out
	s.floor_kill[str(floor_no)] = true
	for seal in revealed:
		var piece := _make_set(s, str(seal), _owned_for(owned_parts, str(seal)), "", difficulty, 1.0, rng)
		out.set_pieces.append(piece)
	return out


## 31～35 层野外：kind 是 "elite" 或 "guardian"。按几率（乘物品掉落加成）掉 1 件随机印（revealed 里均匀抽）的套装件。
## 抽取：不是这几层、没揭开的印或 kind 不对就不抽；否则 1 个浮点数，中了再：印 next_index_mod → 部位 → 真印 → 成色。
## 返回 {"state", "set_pieces"}。
static func roll_field(state: Dictionary, floor_no: int, kind: String, revealed: Array, owned_parts, difficulty: String,
		drop_mult: float, rng: XRandomStream) -> Dictionary:
	var s := _copy(state)
	var out := {"state": s, "set_pieces": []}
	var p := float(_sec("field").get(kind, 0.0)) * drop_mult
	if floor_seals(floor_no).is_empty() or revealed.is_empty() or p <= 0.0:
		return out
	if rng.next_float("qiyin_field") < minf(1.0, p):
		var seal := str(revealed[rng.next_index_mod(revealed.size(), "qiyin_field_seal")])
		out.set_pieces.append(_make_set(s, seal, _owned_for(owned_parts, seal), "", difficulty, 1.0, rng))
	return out


# ---- 熔、分解、兑换（只判定和算数，不动背包）----

## 熔：main 主件、sub 副件（物品字典），shards 现有印屑。同印同部位（武器同类）、真印只能和真印熔、印屑够 cost。
## 返回 {"ok", "reason", "cost"}。reason：kind_mismatch、seal_mismatch、part_mismatch、wtype_mismatch、true_mismatch、same_item、no_shards。
static func melt_check(main: Dictionary, sub: Dictionary, shards: int) -> Dictionary:
	var cost := _i("melt", "cost")
	var fail := func(r: String) -> Dictionary: return {"ok": false, "reason": r, "cost": cost}
	if main.has("id") and sub.has("id") and main.id == sub.id:
		return fail.call("same_item")
	var kind := str(main.get("kind", ""))
	if kind != str(sub.get("kind", "")) or not (kind in [KIND_SET, KIND_WEAPON]):
		return fail.call("kind_mismatch")
	if str(main.get("seal", "")) != str(sub.get("seal", "")):
		return fail.call("seal_mismatch")
	if kind == KIND_SET and str(main.get("part", "")) != str(sub.get("part", "")):
		return fail.call("part_mismatch")
	if kind == KIND_WEAPON and str(main.get("wtype", "")) != str(sub.get("wtype", "")):
		return fail.call("wtype_mismatch")
	if bool(main.get("true_seal", false)) != bool(sub.get("true_seal", false)):
		return fail.call("true_mismatch")
	if shards < cost:
		return fail.call("no_shards")
	return {"ok": true, "reason": "", "cost": cost}


## 分解给几个印屑：套装件 2、毕业武器 10，真印乘 true_mult。不认识的物品 0。
static func dismantle_value(item: Dictionary) -> int:
	var d := _sec("dismantle")
	var kind := str(item.get("kind", ""))
	if not (kind in [KIND_SET, KIND_WEAPON]):
		return 0
	var v := int(d.get(kind, 0))
	if bool(item.get("true_seal", false)):
		v *= int(d.get("true_mult", 1))
	return v


## 印屑兑换。kind "set"：花 exchange.set 个，换一件随机部位的本印套装件（部位照掉落规则，已有部位减半）；
## kind "weapon"：花 exchange.weapon 个，换一把自选印（流派）的毕业武器，类型在该印里随机。
## 兑换的不是掉落：不掷真印、不动真印暗保底，成色照常掷。返回 {"ok", "reason", "cost", "item"}。
## 抽取：套装件 部位 → 成色；武器 类型 → 成色。
static func exchange(kind: String, seal: String, shards: int, owned_parts, rng: XRandomStream) -> Dictionary:
	var cost := _i("exchange", kind)
	if not (kind in [KIND_SET, KIND_WEAPON]) or cost <= 0:
		return {"ok": false, "reason": "bad_kind", "cost": 0, "item": {}}
	if not seals().has(seal):
		return {"ok": false, "reason": "bad_seal", "cost": cost, "item": {}}
	if shards < cost:
		return {"ok": false, "reason": "no_shards", "cost": cost, "item": {}}
	var item := {}
	if kind == KIND_SET:
		item = {"kind": KIND_SET, "seal": seal, "part": _pick_part(_owned_for(owned_parts, seal), rng, "qiyin_exchange_part"),
			"true_seal": false, "grades": _roll_grades(false, rng)}
	else:
		var cls := weapon_classes(seal)
		item = {"kind": KIND_WEAPON, "seal": seal, "wtype": str(cls[rng.next_index_mod(cls.size(), "qiyin_exchange_wtype")]),
			"true_seal": false, "grades": _roll_grades(false, rng)}
	return {"ok": true, "reason": "", "cost": cost, "item": item}


# ---- 数值要好看（Kyo 11-10）：表里设计数值不含 4，豁免键写在表头 nice_number_exempt ----

static func nice_number_violations() -> Array:
	var exempt: Array = data().get("nice_number_exempt", [])
	var out := []
	_scan_nice(data(), "", exempt, out)
	return out


static func _scan_nice(v, path: String, exempt: Array, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not exempt.has(k):
				_scan_nice(v[k], path + "/" + str(k), exempt, out)
	elif v is Array:
		for i in v.size():
			_scan_nice(v[i], path + "/" + str(i), exempt, out)
	elif v is float or v is int:
		var t := XTianqiBalance._num_text(float(v))
		if t.contains("4"):
			out.append(path + "=" + t)
