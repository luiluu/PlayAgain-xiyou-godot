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


func _r2_baselines() -> void:
	# R2（第 2、3、5、7 类旧写法收进门面）：用改动前实测序列写死当基线，验证老档同种子序列一字不变
	# 1. 第 2 类（drop_hash / XTianqiDrop.roll_signature）
	Kit.new_game("jianxian", "war", ORB_SEED)
	kit.save()
	kit.legacy(["drop"])
	var s_drop := kit.reload()
	_check("r2_drop_legacy_absent", s_drop != null and not s_drop.flags.tianqi.has("drop"))
	var d_store := XTianqiDrop.store(s_drop)
	_check("r2_drop_seed", int(d_store.seed) == 1189011166, d_store.seed)
	var drop_seq1 := range(20).map(func(_i): return XTianqiDrop.roll_signature(s_drop, "9:2:9", 0.1))
	var drop_seq2 := range(15).map(func(_i): return XTianqiDrop.roll_signature(s_drop, "7:3:7", 0.25))
	_check("r2_drop_seq_9_2_9", drop_seq1 == [false,false,false,false,false,false,true,false,false,false,false,false,true,false,false,false,false,false,false,false], drop_seq1)
	_check("r2_drop_seq_7_3_7", drop_seq2 == [false,false,false,false,false,false,true,false,false,false,true,false,false,true,false], drop_seq2)
	_check("r2_drop_hash_direct", is_equal_approx(XTianqiRandom.drop_hash(1189011166, "9:2:9", 0), float(("1189011166|9:2:9|0").sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0))
	Kit.new_game("jianxian", "war", ORB_SEED)
	_check("r2_drop_reload_same", kit.reload_same(func(st): return range(15).map(func(_i): return XTianqiDrop.roll_signature(st, "9:2:9", 0.1))))

	# 2. 第 3 类（qiyin_seed / XTianqiQiyin.next_seed / save_rng）
	Kit.new_game("jianxian", "war", ORB_SEED)
	kit.save()
	kit.legacy(["qiyin"])
	var s_qy := kit.reload()
	_check("r2_qiyin_legacy_absent", s_qy != null and not s_qy.flags.tianqi.has("qiyin"))
	var qp := XTianqiQiyin.progress(s_qy)
	_check("r2_qiyin_seed", str(qp.seed) == "1f8a6c43ed44da1a", qp.seed)
	var qy_seeds := ["qiyin", "qiyin", "qiyin_dragon", "qiyin_recruit", "qiyin"].map(func(dom): return XTianqiQiyin.next_seed(s_qy, dom))
	_check("r2_qiyin_next_seeds", qy_seeds == ["e98b358314c4a976","6e8a7b8d078ae4b7","9c866e837e00acf3","cb7d7c84a9b31d25","fb029a661e8d0e85"], qy_seeds)
	_check("r2_qiyin_rng_n", int(qp.rng_n) == 5, qp.rng_n)
	var qy_st := XTianqiQiyin.save_rng(s_qy, "qiyin")
	var qy_floats := _floats(func(): return qy_st.next_float("probe"), 6)
	_check("r2_qiyin_floats", _norm(qy_floats) == _norm([0.041818859056,0.345350468298,0.313256254885,0.337641534628,0.858056242345,0.278290233109]), qy_floats)
	_check("r2_qiyin_reload_same", kit.reload_same(func(st):
		var rng := XTianqiQiyin.save_rng(st, "qiyin")
		return _floats(func(): return rng.next_float("probe"), 4)))
	XTianqiQiyin.SEED_FROM_SAVE = false
	var n_before := int(XTianqiQiyin.progress(s_qy).rng_n)
	var off_seed := XTianqiQiyin.next_seed(s_qy, "qiyin")
	var n_after := int(XTianqiQiyin.progress(s_qy).rng_n)
	XTianqiQiyin.SEED_FROM_SAVE = true
	_check("r2_qiyin_switch_off", off_seed != "" and n_before == n_after, [off_seed, n_before, n_after])

	# 3. 第 5 类（merchant_roll / XTianqiMerchant.draw）
	var mr_seq := range(3).map(func(u): return _floats(XTianqiRandom.merchant_roll(12345, u), 5))
	_check("r2_merchant_raw_floats", _norm(mr_seq) == _norm([
		[0.020402685739,0.016547848238,0.543155794498,0.634904056089,0.910029513761],
		[0.608380826423,0.331169624813,0.355809666915,0.321889439132,0.254739272641],
		[0.196358967107,0.645791401388,0.168463539332,0.008874822175,0.599449031521],
	]), mr_seq)
	var s_m := Kit.new_game("jianxian", "war", ORB_SEED)
	s_m.map_id = 141
	s_m.flags[XAbyssMerchant.RUN_FLAG] = {"sequence": 1, "claimed": true, "appeared": true, "used": 0, "seed": 12345,
		"identity": {"key": "abyss:141", "kind": "深渊商人"}}
	XAbyssMerchant.ledger(s_m).balances["abyss:141"] = 500
	var s_m_rt := kit.roundtrip()
	var m_items := []
	for spec in [["treasure", ""], ["collection", "first_strike"], ["treasure", ""]]:
		var got = XTianqiMerchant.draw(s_m_rt, spec[0], "武器", spec[1])
		m_items.append({"id": int(got.id), "kind": str(got.kind), "name": str(got.name),
			"tq_seed_id": str(got.get("tq_seed_id", "")), "affixes": got.get("tianqi_affixes", [])})
	var exp_m := [
		{"affixes":[{"extra":{},"grade":"normal","key":"mmp","tier":3},{"extra":{},"grade":"normal","key":"atk","tier":3},{"extra":{},"grade":"fine","key":"skill_cost","tier":3}],"id":1431,"kind":"weapon","name":"旧神的契约书","tq_seed_id":"eb9d7179d0ea7fac"},
		{"affixes":[{"extra":{},"grade":"fine","key":"hit","tier":3},{"extra":{},"grade":"normal","key":"mat","tier":3},{"extra":{},"grade":"fine","key":"first_strike","tier":3}],"id":1579,"kind":"weapon","name":"劈~！","tq_seed_id":"4fb6c9d95f40fa61"},
		{"affixes":[{"extra":{},"grade":"fine","key":"atk","tier":3},{"extra":{},"grade":"normal","key":"mat","tier":3},{"extra":{},"grade":"normal","key":"skill_cost","tier":3}],"id":1432,"kind":"weapon","name":"圣甲虫巨弩","tq_seed_id":"448f521e98956631"},
	]
	_check("r2_merchant_items", _norm(m_items) == _norm(exp_m), m_items)
	Kit.new_game("jianxian", "war", ORB_SEED)
	XState.current.map_id = 141
	XState.current.flags[XAbyssMerchant.RUN_FLAG] = {"sequence": 1, "claimed": true, "appeared": true, "used": 0, "seed": 12345,
		"identity": {"key": "abyss:141", "kind": "深渊商人"}}
	XAbyssMerchant.ledger(XState.current).balances["abyss:141"] = 500
	_check("r2_merchant_reload_same", kit.reload_same(func(st):
		var g = XTianqiMerchant.draw(st, "treasure", "武器")
		return [int(g.id), str(g.get("tq_seed_id", "")), g.get("tianqi_affixes", [])]))

	# 4. 第 7 类（elements_seed / elements_rng / XTianqiElements）
	Kit.new_game("jianxian", "war", ORB_SEED)
	kit.save()
	kit.legacy(["elements"])
	var s_el := kit.reload()
	_check("r2_elements_legacy_absent", s_el != null and not s_el.flags.tianqi.has("elements"))
	_check("r2_elements_derived_seed_jx", XTianqiElements.derived_seed(s_el) == 1276351530, XTianqiElements.derived_seed(s_el))
	_check("r2_elements_derived_seed_ly", XTianqiElements.derived_seed(Kit.new_game("lianyu", "war", ORB_SEED)) == 349736755)
	var floors := XTianqiElements.ensure_deck(s_el)
	_check("r2_elements_floors_hash", JSON.stringify(floors).sha256_text() == "04a0099be700dfd793e7b31da89769f268d9e06ad03d41fb3cfa157e633b69b3", JSON.stringify(floors).sha256_text())
	_check("r2_elements_floors_1_17_33", _norm([floors["1"], floors["17"], floors["33"]]) == _norm([
		{"immune":[],"resist":[4,7],"weak":[5,6]},
		{"immune":[15],"resist":[7,2],"weak":[6,14]},
		{"immune":[],"resist":[7],"weak":[15]},
	]))
	_check("r2_elements_fixed_hongjun", _norm(XTianqiElements.fixed_deal(s_el, "hongjun")) == _norm({"immune":[3],"resist":[7,8],"weak":[15,4]}))
	_check("r2_elements_fixed_yingzi", _norm(XTianqiElements.fixed_deal(s_el, "yingzi")) == _norm({"immune":[7],"resist":[2,6],"weak":[9,8]}))
	_check("r2_elements_fixed_db", _norm(XTianqiElements.fixed_deal(s_el, "dungeon_boss:1")) == _norm({"immune":[3],"resist":[7,2],"weak":[8,9]}))
	_check("r2_elements_fixed_knight", _norm([
		XTianqiElements.fixed_deal(s_el, "knight", 1),
		XTianqiElements.fixed_deal(s_el, "knight", 2),
		XTianqiElements.fixed_deal(s_el, "knight", 3),
	]) == _norm([
		{"immune":[14],"resist":[6,5],"weak":[4,15]},
		{"immune":[2],"resist":[15,4],"weak":[9,7]},
		{"immune":[8],"resist":[9,14],"weak":[6,2]},
	]))
	XState.current = s_el
	var s_el_rt := kit.roundtrip()
	_check("r2_elements_roundtrip", s_el_rt != null
		and JSON.stringify(XTianqiElements.ensure_deck(s_el_rt)).sha256_text() == "04a0099be700dfd793e7b31da89769f268d9e06ad03d41fb3cfa157e633b69b3"
		and _norm(XTianqiElements.fixed_deal(s_el_rt, "knight", 2)) == _norm({"immune":[2],"resist":[15,4],"weak":[9,7]}))


func _run() -> void:
	seed(20261114)
	kit = Kit.new("xiyou_tianqi_random")
	if OS.get_environment("XIYOU_TQ_RANDOM_WRITE") == "1":
		_write_fixture()
	else:
		_premove()
		_reload_same()
		_switches()
		_r2_baselines()
	XTianqiSave.ENABLED = true
	XTianqi.SEED_FROM_SAVE = true
	kit.teardown()
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
