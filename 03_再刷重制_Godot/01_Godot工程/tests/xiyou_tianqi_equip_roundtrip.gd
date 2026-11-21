extends Node
## 天启篇穿脱来回测（T333）：每件装备穿上再脱下，派生属性须逐项回到原值。
## 覆盖：数据库全部武器／防具模板、天启篇词条装（XGear.create 掷词条）、七印装备（套装／毕业武器／神器）、异化装备（四线各级）。
## 只测不改游戏逻辑；回不去的写进 KNOWN_FAIL（「装备键|项」），已知失败不让测试红，新出现的失败才红；KNOWN_FAIL 里的项修好后会提示「可以删了」。
## 「烙印」是角色身上的境界（XTianqiBrand），不是装备，不在穿脱范围；七印装备（XTianqiQiyinEquip）是烙印相关的装备，这里算进去。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
## 已知回不去的清单：键写「<装备键>|<项>」，装备键如 db|w2，见交付单
const KNOWN_FAIL: Array = []

var results: Array = []
var _fails: Array = []   # [装备键, 项, 前, 后]
var _skipped := {}       # 来源 -> 不能穿而跳过的件数
var _tested := {}        # 来源 -> 测过的件数


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 属性指纹：基础八项、附加／特殊能力值、技能表、状态、被动表键
func _print(a: XActor) -> Dictionary:
	var d := {}
	for i in range(8):
		d["param%d" % i] = a.param(i)
	for i in range(10):
		d["xparam%d" % i] = a.xparam(i)
		d["sparam%d" % i] = a.sparam(i)
	var ids := a.skills().map(func(k): return int(k.id))
	ids.sort()
	d["skills"] = JSON.stringify(ids)
	var st := a.state_ids.duplicate()
	st.sort()
	d["states"] = JSON.stringify(st)
	var keys: Array = a.passive_cache().skillPass.keys()
	keys.sort()
	d["skillPass"] = JSON.stringify(keys)
	return d


func _run() -> void:
	XMessageBox.auto = true
	var s := Kit.new_game("jianxian")
	var pool: Array = []
	for m in s.battle_members():
		m.change_level(99)
		XEquipment.clear(s, m)   # 先脱光：基线是空身，开局自带装备不干扰
		m.refresh_passive()
		pool.append(m)
	var a: XActor = pool[0]
	_check("tianqi_state", XTianqiGear.on(s))
	var items: Array = []   # [来源, 键, 装备]
	_collect_db(items)
	_collect_affix(s, items)
	_collect_qiyin(items)
	_collect_alien(s, items)
	var base_gear := s.gear.size()
	for e in items:
		_roundtrip(s, pool, str(e[0]), str(e[1]), e[2])
	_check("gear_bag_untouched", s.gear.size() == base_gear, [base_gear, s.gear.size()])
	for src in _tested:
		_check("tested_" + src, int(_tested[src]) > 0, [_tested[src], _skipped.get(src, 0)])
	var fresh := []
	var known_seen := []
	for f in _fails:
		var key := "%s|%s" % [f[1], f[2]]
		if KNOWN_FAIL.has(key):
			known_seen.append(key)
		else:
			fresh.append(f)
	for k in KNOWN_FAIL:
		if not known_seen.has(k):
			print("NOTE KNOWN_FAIL 已不再失败，可以删了: ", k)
	_check("roundtrip_no_new_fail", fresh.is_empty(), fresh.slice(0, 20))
	print("SUMMARY tested=", JSON.stringify(_tested), " skipped=", JSON.stringify(_skipped), " fails=", _fails.size(), " known=", known_seen.size())
	for f in _fails:
		print("DIFF ", f[0], " ", f[1], " ", f[2], " -> ", f[3])
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _collect_db(items: Array) -> void:
	for kind in ["weapon", "armor"]:
		var table := "Weapons" if kind == "weapon" else "Armors"
		for rec in XDB.table(table):
			if not rec is Dictionary or rec.is_empty() or str(rec.get("name", "")) == "":
				continue
			var it := XGear.template(kind, int(rec.id))
			if not it.is_empty():
				items.append(["db", "db|%s%d" % [kind[0], int(rec.id)], it])


## 天启篇词条装：每个部位挑几件，XGear.create 在天启篇存档里掷天启篇词条
func _collect_affix(s: XState, items: Array) -> void:
	var seen := {}
	for kind in ["weapon", "armor"]:
		var table := "Weapons" if kind == "weapon" else "Armors"
		for rec in XDB.table(table):
			if not rec is Dictionary or rec.is_empty() or str(rec.get("name", "")) == "":
				continue
			var key := "%s%d" % [kind, int(rec.get("etypeId", rec.get("wtypeId", 0)))]
			seen[key] = int(seen.get(key, 0)) + 1
			if int(seen[key]) > 6:
				continue
			var it := XGear.create(kind, int(rec.id), s)
			if not it.is_empty() and it.has("tianqi_affixes"):
				items.append(["affix", "affix|%s%d" % [kind[0], int(rec.id)], it])


func _collect_qiyin(items: Array) -> void:
	var rng := XRandomStream.create("5a5a5a5a5a5a5a5a", "roundtrip")
	for seal in XTianqiQiyinDrop.seals():
		for pc in XTianqiQiyinGear.parts():
			for ts in [false, true]:
				var it := XTianqiQiyinEquip.make({"kind": "set", "seal": seal, "part": str(pc.key), "true_seal": ts, "grades": ["putong", "shangpin", "ji"]}, "jianxian", rng)
				if not it.is_empty():
					items.append(["qiyin", "qiyin|set|%s|%s|%s" % [seal, pc.key, ts], it])
		for wt in XTianqiQiyinDrop.weapon_classes(seal):
			var w := XTianqiQiyinEquip.make({"kind": "weapon", "seal": seal, "wtype": wt, "true_seal": true, "grades": ["ji", "ji", "ji"]}, "jianxian", rng)
			if not w.is_empty():
				items.append(["qiyin", "qiyin|weapon|%s|%s" % [seal, wt], w])
	for art in XTianqiQiyinGear.artifacts():
		var it := XTianqiQiyinEquip.make_artifact(str(art.get("key", "")))
		if not it.is_empty():
			items.append(["qiyin", "qiyin|artifact|%s" % art.get("key", ""), it])


## 异化装备：四线 × 各级 × 本线每条词条，挂在一件武器／一件防具上
func _collect_alien(s: XState, items: Array) -> void:
	var levels: Array = XTianqiAlienGear.data().get("levels", {}).keys()
	for m in XTianqiAlienGear.MODULES:
		var line := str(m[1])
		for lv in levels:
			for affix in XTianqiAlienGear.line_keys(line):
				for base in [["weapon", 1], ["armor", 7900 + 0]]:
					var it := XTianqiAlienGear.create(s, str(base[0]), int(base[1]), line, str(lv), str(affix))
					if it.has("ok"):
						items.append(["alien", "alien|%s|%s|%s|%s%d" % [line, lv, affix, str(base[0])[0], int(base[1])], it.ok])
					elif it.has("name") and it.has("alien"):
						items.append(["alien", "alien|%s|%s|%s|%s%d" % [line, lv, affix, str(base[0])[0], int(base[1])], it])


func _slot_for(a: XActor, item: Dictionary) -> int:
	var slots := a.equip_slots()
	for i in range(slots.size()):
		if XEquipment.fits(a, i, item) and XEquipment.can_change(a, i):
			return i
	return -1


func _roundtrip(s: XState, pool: Array, src: String, key: String, item: Dictionary) -> void:
	var a: XActor = null
	var slot := -1
	for m in pool:   # 挑第一个穿得上的队员（职业、等级、栏位各不相同）
		slot = _slot_for(m, item)
		if slot >= 0:
			a = m
			break
	if a == null:
		_skipped[src] = int(_skipped.get(src, 0)) + 1
		return
	var before_equips := a.equips.duplicate(true)
	var before := _print(a)
	var item_before := JSON.stringify(item)
	s.gear.append(item)
	if not XEquipment.change(s, a, slot, item):
		s.gear.erase(item)
		_skipped[src] = int(_skipped.get(src, 0)) + 1
		return
	_tested[src] = int(_tested.get(src, 0)) + 1
	var worn := _print(a)
	XEquipment.change(s, a, slot, null)
	var after := _print(a)
	for k in before:
		if before[k] != after[k]:
			_fails.append([src, key, k, "%s -> %s (穿着时 %s)" % [before[k], after[k], worn[k]]])
	if JSON.stringify(item) != item_before:
		_fails.append([src, key, "item_mutated", "装备本身被改写"])
	var back := s.gear.find_custom(func(e): return is_same(e, item))
	if back < 0:
		_fails.append([src, key, "not_back_in_bag", "脱下后不在背包"])
	else:
		s.gear.remove_at(back)
	if JSON.stringify(a.equips) != JSON.stringify(before_equips):
		_fails.append([src, key, "equips_changed", "脱下后装备栏与穿前不同"])
