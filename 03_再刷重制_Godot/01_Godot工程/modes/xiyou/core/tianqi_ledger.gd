class_name XTianqiLedger
extends RefCounted
## 【cc·天启篇·未经审查】伤害加成总账·期一「总账入口（不改数）」（设计仓《天启篇_伤害加成总账_v0.4》第八节期一细则）。只对天启篇存档生效，原版档不进这里。
## 表：modes/xiyou/tianqi_data/damage_ledger.json（只读）。每个「乘」一行，三种状态：
##   pooled 已归池（出现就失败）／exempt 豁免（写到期 expires，到期那一期起出现就失败）／allowed 永久允许（不判）。
## 守卫（GUARD）：天启篇里我方出手的每一下伤害，把落在单独相乘字段上的操作（钩子帧、技能专属被动起点、种族乘数、原版独立乘区）
##   按「来源」认一遍；来源没登记、字段不在这一行、已归池或豁免到期 → push_error（并行测试把 ERROR 行判失败）并记进 violations。
##   只记、不改数：伤害照算。来源由 XActorDamageHooks.capture 分段打标签（tags 跟 ops 一一对应），别的注册表模块按模块号认。
## 来源分桶（BUCKETS）：被动缓存（XActor._refresh_passive_now）并排多存一份 bySource，按秘籍格、符文之语、宝珠、原版装备、种族、成长装备、
##   天启篇、角色自带、状态分；原合计字段不动、西游档不建这份。
## 五池明细（DETAIL）：伤害详情（breakdown.row.pools）多一份五池和单独相乘残余，只加明细。
## 开关都默认开；全关＝回到 main（数值本来就不变）。

const PATH := "res://modes/xiyou/tianqi_data/damage_ledger.json"
## 单独相乘的口子（第三节第 1 条）：落在这些字段上的操作就算「乘」，不论 add／mul／set
const MUL_FIELDS := ["skillMultiplier", "elementMultiplier", "finalMultiplier", "settlementMultiplier",
	"physicalDamageMultiplier", "magicalDamageMultiplier", "growthMultiplier"]
## 注册表模块号 → 总账来源（actor-modules 按 tags 逐条认）
const MODULE_SOURCE := {"orb-sets": "orb_resonance", "race-blessings": "race", "cat-sword": "module.cat", "alienation": "alienation"}

static var GUARD := true
static var BUCKETS := true
static var DETAIL := true
## 测试用：不 push_error，只记（专项故意造违规时用）
static var QUIET := false

static var _data: Dictionary = {}
static var _rows: Dictionary = {}
static var _load_failed := false
static var violations: Array = []
static var _reported := {}


static func data() -> Dictionary:
	if _data.is_empty():
		if _load_failed or XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiLedger: 读不到或解析不了 " + PATH)
			return {}
		_data = parsed
		_rows = {}
		for r in _data.get("rows", []):
			_rows[str(r.id)] = r
	return _data


static func reload() -> void:
	_data = {}
	_rows = {}
	_load_failed = false


static func phase() -> int:
	return int(data().get("phase", 1))


static func row(source: String) -> Dictionary:
	data()
	var r = _rows.get(source)
	return r if r is Dictionary else {}


static func active() -> bool:
	return XTianqi.active(XState.current)


static func auditing(a = null) -> bool:
	return GUARD and (a == null or a is XActor) and active() and not data().is_empty()


static func bucketing() -> bool:
	return BUCKETS and active() and not data().is_empty()


static func detail_on() -> bool:
	return DETAIL and active()


## 一个操作是不是「乘」：落在单独相乘字段上、且不是恒等（mul/set 1、add 0）
static func is_mul(op: Dictionary) -> bool:
	var f := str(op.get("field", ""))
	if not MUL_FIELDS.has(f):
		return false
	var kind := str(op.get("op", ""))
	var v := float(op.get("value", 1.0 if kind != "add" else 0.0))
	return not (v == 0.0 if kind == "add" else v == 1.0)


## 来源 source 在字段 field 上乘一次合不合规：返回 "" 合规，否则是原因
static func check(source: String, field: String) -> String:
	var r := row(source)
	if r.is_empty():
		return "unregistered"
	if not (r.get("fields", []) as Array).has(field):
		return "field_not_registered"
	match str(r.get("status", "")):
		"allowed":
			return ""
		"exempt":
			return "" if phase() < int(r.get("expires", 0)) else "exempt_expired"
		"pooled":
			return "pooled"
	return "bad_status"


static func _flag(source: String, field: String, reason: String, ctx: Dictionary) -> void:
	var v := {"source": source, "field": field, "reason": reason}
	v.merge(ctx)
	violations.append(v)
	var key := source + "|" + field + "|" + reason
	if not QUIET and not _reported.has(key):
		_reported[key] = true
		push_error("伤害加成总账：天启篇出现没登记的乘区 %s.%s（%s，技能 %s）——登记进 tianqi_data/damage_ledger.json 或归池" % [source, field, reason, str(ctx.get("skill", ""))])


## 守卫本体：damage._calculate 在钩子之后调用。trace＝注册表 dispatch 的 trace；facts 里 actorModules.tags 跟 ops 一一对应。
## extras：{skill_pass, race, independent}（不走钩子的三处，值是这一下的倍率）
static func audit(item: Dictionary, a, trace: Array, facts: Dictionary, extras: Dictionary) -> Array:
	var found := []
	if not auditing(a):
		return found
	var ctx := {"skill": int(item.get("id", 0)), "actor": int(a.actor_id) if a is XActor else 0}
	for t in trace:
		var mod := str(t.get("module", ""))
		var ops: Array = t.get("ops", [])
		var tags: Array = facts.get("actorModules", {}).get("tags", []) if mod == "actor-modules" else []
		for i in ops.size():
			var op = ops[i]
			if not op is Dictionary or not is_mul(op):
				continue
			var source: String = str(tags[i]) if i < tags.size() else str(MODULE_SOURCE.get(mod, "module:" + mod))
			var why := check(source, str(op.field))
			found.append({"source": source, "field": str(op.field), "op": str(op.op), "value": float(op.get("value", 0.0)), "ok": why == ""})
			if why != "":
				_flag(source, str(op.field), why, ctx)
	for pair in [["skill_pass", "skillMultiplier"], ["race", "race"], ["independent", "independent"]]:
		var v := float(extras.get(pair[0], 1.0))
		if v == 1.0:
			continue
		var source: String = {"skill_pass": "skill_pass", "race": "enemy_race_bonus", "independent": "self_rate"}[pair[0]]
		var why := check(source, pair[1])
		found.append({"source": source, "field": pair[1], "op": "mul", "value": v, "ok": why == ""})
		if why != "":
			_flag(source, pair[1], why, ctx)
	return found


## 原版状态确认阶段乘：只认登记的那批状态号（state_confirm_ids）
static func state_confirm_registered(state_id: int) -> bool:
	return (data().get("state_confirm_ids", []) as Array).has(state_id) or (data().get("state_confirm_ids", []) as Array).has(float(state_id))


# ---- MODULE_CAP 白名单 ----
## 卡开着时模块的增伤默认拦；白名单 [{module, skill, field}] 才放（skill 0＝该模块全部技能）
static func whitelisted(module: String, skill: int, field: String) -> bool:
	for w in data().get("module_whitelist", []):
		if str(w.get("module", "")) == module and str(w.get("field", "")) == field and (int(w.get("skill", 0)) == 0 or int(w.get("skill", 0)) == skill):
			return true
	return false


# ---- 来源分桶（第五节第 4 条（3））----
const BUCKET_NAMES := {"secret": "秘籍格（功法、通用被动书）", "runeword": "符文之语", "orb": "宝珠", "equip": "原版装备", "race": "种族",
	"hubris": "成长装备", "tianqi": "天启篇自己的", "actor": "角色自带、技能", "state": "状态", "suit": "原版套装", "zhenqi": "真气"}


## 一个特性对象（装备实例、技能、状态）归哪个桶
static func bucket_of(o: Dictionary, a = null) -> String:
	if o.has("kind") and str(o.kind) in ["weapon", "armor"]:
		if o.has("qiyin") or o.has("tianqi_affixes") or o.has("tq_reward") or XTianqiAlienGear.is_tq(o):
			return "tianqi"
		if XHubris.is_gear(o):
			return "hubris"
		if not (o.get("runewords", []) as Array).is_empty() or str(o.get("runewordName", "")) != "":
			return "runeword"
		return "equip"
	if a is XBattler and a.states().has(o):
		return "state"
	if o.has("stypeId"):
		var id := int(o.get("id", 0))
		if XPowerBooks.is_power(id) or int(o.get("stypeId", 0)) == 5:
			return "secret"
		if not XRace.skill_info(id).is_empty():
			return "race"
		return "actor"
	return "actor"


static func _add(d: Dictionary, key, bucket: String, v: float) -> void:
	if v == 0.0:
		return
	var row: Dictionary = d.get(key, {})
	row[bucket] = float(row.get(bucket, 0.0)) + v
	d[key] = row


## 被动缓存的按来源分桶：和 _refresh_passive_now 同一批对象、同样的扫描，求和前按对象的桶分开记。
## 返回 {globalHarmRi: {桶: 值}, critHarmRi, skillTypeDvup: {类型: {桶: 值}}, SkETypeHarmRi, skillPass: {技能: {桶: rate}}, passiveELUP: {元素: {桶}}, elementAmplify: {元素: {桶}}}
static func passive_buckets(a, objs: Array) -> Dictionary:
	var out := {"globalHarmRi": {}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "passiveELUP": {}, "elementAmplify": {}}
	for o in objs:
		var bucket := bucket_of(o, a)
		var sc := XActor._note_scans(str(o.get("note", "")))
		var meta: Dictionary = o.get("meta", {})
		for m in sc[4]:
			_add(out, "globalHarmRi", bucket, float(m[0]) / 100.0)
		for m in sc[5]:
			_add(out, "critHarmRi", bucket, float(m[0]) / 100.0)
		for m in sc[2]:
			_add(out.skillTypeDvup, str(m[0]), bucket, XActor._num(m[1]) / 100.0)
		for m in sc[3]:
			_add(out.SkETypeHarmRi, int(m[0]), bucket, XActor._num(m[1]) / 100.0)
		for k in meta:
			var tag := str(k)
			if tag.begins_with("SkillPass") and str(meta[k]).contains("%"):
				_add(out.skillPass, int(tag.substr(9)), bucket, XActor._num(meta[k]) / 100.0)
			elif tag.begins_with("passiveELUP") and o.has("stypeId"):
				_add(out.passiveELUP, int(tag.substr(11)), bucket, XActor._num(meta[k]) / 100.0)
	# 元素增幅（damage.own_bonus 的 elementAmplify 来源：状态＋装备＋角色＋职业）；宝珠镶进装备的那份单列
	var amp_objs: Array = a.states() + (a.stat_equips() if a.has_method("stat_equips") else []) + ([a.data(), a.class_data()] if a is XActor else [])
	for o in amp_objs:
		var amp: Dictionary = o.get("yep", {}).get("elementAmplify", {})
		if amp.is_empty():
			continue
		var bucket := bucket_of(o, a) if not (o is Dictionary and (is_same(o, a.data()) or is_same(o, a.class_data()))) else "actor"
		var orb := orb_amplify(o)
		for e in amp:
			var own := float(amp[e]) - float(orb.get(str(e), 0.0))
			_add(out.elementAmplify, int(e), bucket, own)
			_add(out.elementAmplify, int(e), "orb", float(orb.get(str(e), 0.0)))
	return out


## 装备孔里宝珠加的元素增幅（XOrbs.effect 的 ELEMENT AMPLIFY 行，按孔的类型取镶嵌行）
static func orb_amplify(eq: Dictionary) -> Dictionary:
	var out := {}
	var held: Array = eq.get("augmentSlotItems", [])
	for i in held.size():
		var gem := XOrbs.gem_in_slot(eq, i)
		if gem.is_empty():
			continue
		var p := XOrbs.parse(gem)
		var lines: Array = p.attach.get(XOrbs.socket_type(eq).to_upper(), [])
		for line in lines:
			var m := RegEx.create_from_string("(?i)ELEMENT AMPLIFY[ ](\\d+):[ ]([\\+\\-]\\d+)[%％]").search(str(line))
			if m:
				out[m.get_string(1)] = float(out.get(m.get_string(1), 0.0)) + float(m.get_string(2)) / 100.0
	return out


## 合计（期三九线封顶接这里：caps {桶: 上限}，不给就是原合计）
static func bucket_total(buckets: Dictionary, caps := {}) -> float:
	var total := 0.0
	for b in buckets:
		var v := float(buckets[b])
		total += minf(v, float(caps[b])) if caps.has(b) else v
	return total


# ---- 五池明细（第四节第 1 条）----
## element_pool＝(1＋自身元素增幅＋elementAdd)（不含 elementMultiplier），其余照 damage._calculate 那一行的值
static func pools(frame: Dictionary, element: int, element_pool: float, normal: float, crit: float, tier: float, race: float, independent: float) -> Dictionary:
	return {"pools": {"skill": normal, "element": element_pool, "bonus": maxf(0.0, 1.0 + float(frame.finalAdd)), "crit": crit, "tier": tier},
		"residual": {"skillMultiplier": float(frame.skillMultiplier), "elementMultiplier": float(frame.elementMultiplier.get(str(element), 1.0)),
			"finalMultiplier": maxf(0.0, float(frame.finalMultiplier)), "race": race, "independent": independent,
			"physicalDamageMultiplier": float(frame.physicalDamageMultiplier), "magicalDamageMultiplier": float(frame.magicalDamageMultiplier)}}
