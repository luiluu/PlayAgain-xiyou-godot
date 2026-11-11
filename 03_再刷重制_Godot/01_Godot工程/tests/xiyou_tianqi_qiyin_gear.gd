extends Node
## 天启篇七印祭坛装备表（XTianqiQiyinGear，tianqi_data/qiyin_gear.json）的自检：
## 一、七印齐、顺序就是揭开顺序（白红黑灰殉震默）。
## 二、每套恰好 6 件、6 个部位不重不漏、装备类型号与 XTianqiGear.ORDER 对上（头 3、甲 4、手 6、腰 8、裤 5、鞋 7）；2／3／5 三档都有。
## 三、13 把毕业武器、名字不重；前六印各两类、12 类不重不漏；默印一把、随机类。
## 四、5 件神器，神器栏类型 17。
## 五、表里用到的效果码都在 _note.effect_codes 列过，每条效果都有 text。
## 六、数值好看：设计数值不含 4（豁免键写在表头）。
## 不用转换产物，不建存档。

const SEALS := ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"]
const PARTS := {"head": 3, "body": 4, "hands": 6, "waist": 8, "legs": 5, "feet": 7}

var results: Array = []


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


func _run() -> void:
	XTianqiQiyinGear.reload()
	_header()
	_seals()
	_sets()
	_weapons()
	_artifacts()
	_codes()
	_nice()
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _header() -> void:
	var d := XTianqiQiyinGear.data()
	_check("表能读", not d.is_empty())
	_check("表头 version／draft／source", d.has("version") and d.get("draft") == true and str(d.get("source", "")) != "", [d.get("version"), d.get("draft")])
	var gw := XTianqiQiyinGear.grade_weights()
	_check("成色权重 普通 50、上品 30、极 20", int(gw.get("normal", 0)) == 50 and int(gw.get("fine", 0)) == 30 and int(gw.get("perfect", 0)) == 20, gw)


func _seals() -> void:
	_check("七印齐、顺序对", XTianqiQiyinGear.seal_keys() == SEALS, XTianqiQiyinGear.seal_keys())
	for i in SEALS.size():
		_check("印的 order：" + SEALS[i], int(XTianqiQiyinGear.seal(SEALS[i]).get("order", 0)) == i + 1)
	_check("没有的印返回空", XTianqiQiyinGear.seal("nope").is_empty() and XTianqiQiyinGear.set_of("nope").is_empty() and XTianqiQiyinGear.school("nope").is_empty())


func _sets() -> void:
	# 部位表本身与 XTianqiGear.ORDER 对上
	var parts := XTianqiQiyinGear.parts()
	_check("部位六个", parts.size() == 6, parts.size())
	for p in parts:
		var want: int = PARTS.get(str(p.key), -1)
		_check("部位类型号：" + str(p.key), int(p.etype) == want and XTianqiGear.ORDER.has(int(p.etype)), [p.etype, want])
	var rule := XTianqiQiyinGear.set_rule()
	_check("套装神话 80 级、首杀 75 级", rule.get("quality") == "shenhua" and int(rule.get("level", 0)) == 80 and int(rule.get("first_kill_level", 0)) == 75, rule)
	_check("套装词条：防具组、四阶、三槽", rule.get("affixes", {}).get("group") == "fangju" and int(rule.get("affixes", {}).get("affix_tier", 0)) == 4 and int(rule.get("affixes", {}).get("slots", 0)) == 3)
	_check("套装真印：全极、底子 +10%", rule.get("true_seal", {}).get("grade") == "perfect" and is_equal_approx(float(rule.get("true_seal", {}).get("base_mult", 0)), 1.1))
	var piece_names := {}
	for s in SEALS:
		var st := XTianqiQiyinGear.set_of(s)
		var pieces: Array = st.get("pieces", [])
		_check("套装有名字：" + s, str(st.get("name", "")) != "")
		_check("每套恰好 6 件：" + s, pieces.size() == 6, pieces.size())
		var seen := {}
		for pc in pieces:
			seen[str(pc.part)] = true
			piece_names[str(pc.name)] = true
			_check("件的类型号对上 ORDER：%s.%s" % [s, pc.part], int(pc.etype) == int(PARTS.get(str(pc.part), -1)) and XTianqiGear.ORDER.has(int(pc.etype)), pc)
			_check("件名「套装名·部位」：%s.%s" % [s, pc.part], str(pc.name).begins_with(str(st.name) + "·"), pc.name)
		_check("6 个部位不重不漏：" + s, seen.size() == 6 and PARTS.keys().all(func(k): return seen.has(k)), seen.keys())
		var counts: Array = st.get("bonuses", []).map(func(b): return int(b.count))
		_check("2／3／5 三档都有：" + s, counts == [2, 3, 5], counts)
		for c in [2, 3, 5]:
			_check("%s 件档有效果：%s" % [c, s], not XTianqiQiyinGear.set_bonus(s, c).is_empty())
		_check("没有的件数档为空：" + s, XTianqiQiyinGear.set_bonus(s, 6).is_empty())
	_check("42 件名字不重", piece_names.size() == 42, piece_names.size())


func _weapons() -> void:
	var ws := XTianqiQiyinGear.weapons()
	_check("13 把毕业武器", ws.size() == 13, ws.size())
	var names := {}
	var keys := {}
	for w in ws:
		names[str(w.name)] = true
		keys[str(w.key)] = true
		_check("武器有独有效果：" + str(w.name), not w.get("effects", []).is_empty())
	_check("武器名字不重", names.size() == 13, names.size())
	_check("武器键不重", keys.size() == 13, keys.size())
	var types := XTianqiQiyinGear.weapon_types()
	var type_keys: Array = types.map(func(t): return str(t.key))
	_check("12 个武器类", types.size() == 12, types.size())
	_check("wtype_id 先留 null", types.all(func(t): return t.get("wtype_id") == null))
	var covered := {}
	for s in SEALS:
		var mine := XTianqiQiyinGear.weapons_of_seal(s)
		var sc := XTianqiQiyinGear.school(s)
		_check("有流派印记与真印追加：" + s, not sc.get("mark", []).is_empty() and not sc.get("true_extra", []).is_empty(), sc)
		if s == "mo":
			_check("默印一把、随机类", mine.size() == 1 and mine[0].get("type") == null and mine[0].get("type_random") == true, mine)
			continue
		var tset: Array = mine.map(func(w): return str(w.type))
		_check("前六印各两类：" + s, mine.size() == 2 and tset[0] != tset[1], tset)
		_check("流派两类同武器：" + s, sc.get("types", []) == tset, [sc.get("types"), tset])
		for t in tset:
			_check("武器类认得：" + t, type_keys.has(t))
			covered[t] = covered.get(t, 0) + 1
	_check("12 类不重不漏", covered.size() == 12 and covered.values().all(func(n): return n == 1), covered)
	var rule := XTianqiQiyinGear.weapon_rule()
	_check("武器神话 80 级、底子 ×1.1", rule.get("quality") == "shenhua" and int(rule.get("level", 0)) == 80 and is_equal_approx(float(rule.get("base_mult", 0)), 1.1), rule)
	_check("武器词条：兵器组、四阶、三槽", rule.get("affixes", {}).get("group") == "bingqi" and int(rule.get("affixes", {}).get("affix_tier", 0)) == 4 and int(rule.get("affixes", {}).get("slots", 0)) == 3)
	_check("按中文类名查", XTianqiQiyinGear.weapon_of_type("弓弩").get("name") == "白虹贯日")
	_check("按类键查", XTianqiQiyinGear.weapon_of_type("book").get("name") == "天书")
	_check("按键查", XTianqiQiyinGear.weapon("buliwenzi").get("seal") == "mo")
	_check("没有的类为空", XTianqiQiyinGear.weapon_of_type("nope").is_empty())


func _artifacts() -> void:
	var arts := XTianqiQiyinGear.artifacts()
	_check("5 件神器", arts.size() == 5, arts.size())
	var keys: Array = arts.map(func(a): return str(a.key))
	_check("神器键", keys == ["bow_crown", "great_sword", "scales", "grey_scythe", "seven_seal_scroll"], keys)
	for a in arts:
		_check("神器有效果和代价：" + str(a.key), not a.get("effects", []).is_empty() and not a.get("costs", []).is_empty())
	var rule := XTianqiQiyinGear.artifact_rule()
	_check("神器栏类型 17、全队一件", int(rule.get("etype", 0)) == XTianqiGear.ARTIFACT and int(rule.get("team_active_max", 0)) == 1, rule)


func _codes() -> void:
	var listed := XTianqiQiyinGear.effect_codes()
	var used := XTianqiQiyinGear.used_effect_codes()
	_check("效果码登记表非空", not listed.is_empty())
	var missing := used.filter(func(c): return not listed.has(c))
	_check("用到的效果码都在 _note 里列过", missing.is_empty(), missing)
	var unused := listed.keys().filter(func(c): return not used.has(c))
	_check("_note 里没有用不到的效果码", unused.is_empty(), unused)
	var no_text := []
	_effects_without_text(XTianqiQiyinGear.data(), no_text)
	_check("每条效果都有 text", no_text.is_empty(), no_text)


func _effects_without_text(v, out: Array) -> void:
	if v is Dictionary:
		if v.has("code") and str(v.get("text", "")) == "":
			out.append(v.code)
		for k in v:
			if k != "_note":
				_effects_without_text(v[k], out)
	elif v is Array:
		for x in v:
			_effects_without_text(x, out)


func _nice() -> void:
	var bad := XTianqiQiyinGear.nice_number_violations()
	_check("设计数值不含 4", bad.is_empty(), bad)
	_check("豁免键只放编号、类型号、层数、件数", XTianqiQiyinGear.data().get("nice_number_exempt", []).all(
		func(k): return k in ["version", "order", "etype", "affix_tier", "count", "first_kill_floors"]))
