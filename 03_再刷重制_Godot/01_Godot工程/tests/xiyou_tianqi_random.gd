extends Node
## 天启篇随机门面专项（XTianqiRandom，cc/save-rng-facade R1）：seed-fix 的存档派生入口原样搬进门面后，老档的结果序列一个都不变。
## 夹具 tests/fixtures/tianqi_random_premove.json 是**搬家前**（main 61b2786ca 的 XTianqi.*）生成的：一份去掉了随机身份的天启篇
## 老档原文（背包、身上、仓库都有装备；一件带旧号、一对同 instanceId 的复制品），以及当时读档补出来的号和各入口掷出的序列。
## 本专项把那份存档原文写进存档位、真读档（XSave.load_slot），逐件比补出来的号、逐个比各入口的结果；门面和 XTianqi 的同名转发各跑一遍。
## 另：reload_same（存→读→再取相同）、开关关时回到全局随机、读档补号改由 XTianqiSave.after_load 调（关存档门面开关也照补）。
## 重生成夹具（只在搬家前的代码上做过一次，以后不要重生成，否则断言失去意义）：XIYOU_TQ_RANDOM_WRITE=1 跑本场景。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const FIXTURE := "res://tests/fixtures/tianqi_random_premove.json"
const ORB_SEED := 20261114
const WH := "随机门面测试仓库"
var results: Array = []
var kit: Kit


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _weapons(n: int) -> Array:
	var out := []
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) >= 5 and not XEquipment.is_exclusive(tpl):
				out.append(int(r.id))
				if out.size() >= n:
					break
	return out


## 造老档：背包 4 件（两件来源键同一家店）、身上 1 件、仓库 2 件；存盘后去掉所有号（只留背包第 2 件的旧号），再加一件同 instanceId 的复制品
func _build_legacy_raw() -> Dictionary:
	var s := Kit.new_game("jianxian", "war", ORB_SEED)
	var wids := _weapons(4)
	s.gain_gear("weapon", wids[0], 1)
	s.gain_gear("weapon", wids[1], 1, "shop|4|g1:1")
	s.gain_gear("weapon", wids[1], 1, "shop|4|g1:1")
	s.gain_gear("weapon", wids[2], 1, "event|4|7|0|weapon:%d" % wids[2])
	s.gain_gear("weapon", wids[3], 1)
	var worn: Dictionary = s.gear.pop_back()
	var ids := s.actors.keys()
	ids.sort()
	var a = s.actors[ids[0]]
	a.equips[1] = worn
	XWarehouse.create(s, "<%s>" % WH)
	s.gain_gear("weapon", wids[0], 2)
	s.warehouses[WH].items.weapon.append(s.gear.pop_back())
	s.warehouses[WH].items.weapon.append(s.gear.pop_back())
	if not kit.save():
		return {}
	var d := kit.raw()
	var keep := ""
	for i in d.gear.size():
		var g = d.gear[i]
		if g is Dictionary:
			if i == 1:
				keep = str(g.get("tq_seed_id", ""))
			else:
				g.erase("tq_seed_id")
			g.erase("tq_rng_n")
	for ad in d.get("actors", {}).values() if d.get("actors") is Dictionary else d.get("actors", []):
		if ad is Dictionary:
			for e in ad.get("equips", []):
				if e is Dictionary:
					e.erase("tq_seed_id")
	for w in d.get("phwarehouse", {}).values():  # 存档里仓库键名照原版 phwarehouse
		for e in w.get("items", {}).get("weapon", []):
			if e is Dictionary:
				e.erase("tq_seed_id")
	var twin: Dictionary = (d.gear[0] as Dictionary).duplicate(true)
	d.gear.append(twin)
	d["_fixture_kept_id"] = keep
	d["_fixture_had_ids"] = JSON.stringify(d).count("\"tq_seed_id\"")
	return d


func _floats(f: Callable, n: int) -> Array:
	var out := []
	for i in n:
		out.append(snappedf(float(f.call()), 0.000000000001))
	return out


## 在读回来的老档上把搬过去的各入口跑一遍；api＝XTianqiRandom 或 XTianqi（转发）
func _probe(s: XState, api) -> Dictionary:
	var out := {}
	var gear: Array = api.all_gear(s)
	out["order"] = gear.map(func(g): return str(g.get("instanceId", "")))
	out["ids"] = gear.map(func(g): return str(g.get("tq_seed_id", "")))
	out["seeds_on"] = api.seeds_on(s)
	out["save_stream"] = _floats(func(): return api.save_stream(s, "probe|0").next_float("p"), 1)
	var st: XRandomStream = api.save_stream(s, "probe|1")
	out["save_stream_seq"] = _floats(func(): return st.next_float("p"), 4)
	out["save_roll"] = _floats(api.save_roll(s, "alien_attach|3"), 4)
	var g0: Dictionary = s.gear[0]
	out["item_roll_1"] = _floats(api.item_roll(s, g0, "reforge"), 3)
	out["item_roll_2"] = _floats(api.item_roll(s, g0, "reforge"), 3)
	out["item_roll_lock"] = _floats(api.item_roll(s, g0, "reforge_lock"), 2)
	out["rng_n"] = int(g0.get("tq_rng_n", -1))
	var fresh := {"instanceId": "probe-iid-1", "name": "x"}
	api.on_register(s, fresh)
	out["reg_plain"] = str(fresh.get("tq_seed_id", ""))
	var src := []
	for i in 3:
		var it := {"instanceId": "probe-src-%d" % i}
		api.on_register(s, it, "shop|9|probe" if i != 1 else "event|9|probe")
		src.append(str(it.get("tq_seed_id", "")))
	out["reg_src"] = src
	out["src_n"] = s.flags.tianqi.get("src_n", {}).duplicate(true)
	var star := {"instanceId": "star-old-7", "name": "y", "atk": 3}
	api.before_renumber(s, star)
	out["star"] = str(star.get("tq_seed_id", ""))
	var lazy := {"instanceId": "lazy-1"}
	out["seed_id_lazy"] = api.seed_id(s, lazy)
	out["has_seed_id"] = [api.has_seed_id(lazy), api.has_seed_id({}), api.has_seed_id({"tq_seed_id": "zz"})]
	return out


## 夹具经过 JSON（整数读成浮点）：两边都过一遍 JSON 再比
func _norm(v) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func _load_fixture_raw(raw: Dictionary) -> XState:
	XSave._write(XSave.path(Kit.SLOT), raw)
	return kit.reload()


func _write_fixture() -> void:
	var raw := _build_legacy_raw()
	var s := _load_fixture_raw(raw)
	var expected := _probe(s, XTianqi)
	var f := FileAccess.open(ProjectSettings.globalize_path(FIXTURE), FileAccess.WRITE)
	f.store_string(JSON.stringify({"note": "搬家前（main 61b2786ca，XTianqi.*）生成；不要重生成", "save": raw, "expected": expected}, "\t", true))
	f.close()
	_check("fixture_written", s != null and expected.ids.size() >= 7, expected)


func _premove() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check("fixture_present", fx is Dictionary and fx.get("save") is Dictionary)
	if not fx is Dictionary:
		return
	var exp: Dictionary = fx.expected
	for api_name in ["XTianqiRandom", "XTianqi"]:
		var s := _load_fixture_raw(fx.save)
		_check(api_name + "_loaded", s != null)
		if s == null:
			continue
		var got := _probe(s, XTianqiRandom if api_name == "XTianqiRandom" else XTianqi)
		for k in exp:
			_check("%s_same_%s" % [api_name, k], _norm(got.get(k)) == _norm(exp[k]), [got.get(k), exp[k]])
	# 夹具本身有意义：7 件以上、全补上号、旧号原样保留、复制品撞号加后缀与原件不同
	var ids: Array = exp.ids
	_check("fx_all_assigned", ids.size() >= 7 and ids.all(func(x): return XRandomStream.valid_hex(str(x))), ids)
	_check("fx_kept_old_id", str(fx.save.get("_fixture_kept_id", "")) != "" and ids.has(str(fx.save._fixture_kept_id)))
	_check("fx_legacy_only_one_id", int(fx.save.get("_fixture_had_ids", -1)) == 1, fx.save.get("_fixture_had_ids"))
	_check("fx_has_worn_and_wh", int(exp.order.size()) >= 8, exp.order)
	var order: Array = exp.order
	_check("fx_twin_distinct", order.count(order[0]) == 2 and ids[0] != ids[order.rfind(order[0])], [order, ids])


## 存→读→再取，结果相同（kit.reload_same）
func _reload_same() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fx is Dictionary:
		return
	var s := _load_fixture_raw(fx.save)
	_check("rs_loaded", s != null)
	var iid := str(s.gear[0].instanceId) if s != null else ""
	var roll := func(st: XState):
		if st == null:
			return null
		var g: Dictionary = st.gear.filter(func(x): return str(x.get("instanceId", "")) == iid)[0]
		return [_floats(XTianqiRandom.item_roll(st, g, "reforge"), 3), _floats(XTianqiRandom.save_roll(st, "rs|%d" % int(st.flags.tianqi.get("affix_roll_n", 0))), 2),
			XTianqiRandom.all_gear(st).map(func(x): return str(x.get("tq_seed_id", "")))]
	_check("reload_same", kit.reload_same(roll))
	var seqs: Array = kit.each_seed(func(sd):
		var ns := Kit.new_game("jianxian", "war", sd)
		ns.gain_gear("weapon", _weapons(1)[0], 1)
		return kit.reload_same(roll) and kit.reload() != null)
	_check("reload_same_each_seed", seqs.all(func(v): return v), seqs)


## 读档补号由 XTianqiSave.after_load 调；存档门面开关关了也照补（补号只看 SEED_FROM_SAVE）；随机开关关了不补、回到全局随机
func _switches() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fx is Dictionary:
		return
	var exp_ids: Array = fx.expected.ids
	XTianqiSave.ENABLED = false
	var s := _load_fixture_raw(fx.save)
	XTianqiSave.ENABLED = true
	_check("save_off_still_assigns", s != null and XTianqiRandom.all_gear(s).map(func(g): return str(g.get("tq_seed_id", ""))) == exp_ids)
	# from_dict 也走得到（不经存盘）
	var fd := XState.from_dict(JSON.parse_string(JSON.stringify(fx.save)))
	_check("from_dict_assigns", XTianqiRandom.all_gear(fd).map(func(g): return str(g.get("tq_seed_id", ""))) == exp_ids)
	XTianqi.SEED_FROM_SAVE = false
	var off := _load_fixture_raw(fx.save)
	var unassigned: Array = XTianqiRandom.all_gear(off).filter(func(g): return not XTianqiRandom.has_seed_id(g)) if off != null else []
	var r1 := _floats(XTianqiRandom.save_roll(off, "x|0"), 3)
	var r2 := _floats(XTianqiRandom.save_roll(off, "x|0"), 3)
	XTianqi.SEED_FROM_SAVE = true
	_check("off_no_assign", unassigned.size() == exp_ids.size() - int(fx.save._fixture_had_ids), [unassigned.size(), fx.save._fixture_had_ids])
	_check("off_global_random", r1 != r2, [r1, r2])
	# 西游档：不补号
	var plain := XState.new()
	plain.gear.append({"instanceId": "p1"})
	XTianqiRandom.assign_all(plain)
	_check("plain_no_assign", not XTianqiRandom.has_seed_id(plain.gear[0]))


func _run() -> void:
	seed(20261114)
	kit = Kit.new("xiyou_tianqi_random")
	if OS.get_environment("XIYOU_TQ_RANDOM_WRITE") == "1":
		_write_fixture()
	else:
		_premove()
		_reload_same()
		_switches()
	XTianqiSave.ENABLED = true
	XTianqi.SEED_FROM_SAVE = true
	kit.teardown()
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
