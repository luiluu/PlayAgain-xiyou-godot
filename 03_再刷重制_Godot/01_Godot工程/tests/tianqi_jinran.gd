extends Node
## 法宝浸染规则核心专项（XTianqiJinran，T597 J1；设计稿 天启篇_法宝浸染_v0.5 第三、十、十四节）。
## 第十四节 J1 单测清单逐条一个块（块名前的数字＝派单验收号），另加洗痕、同一次提交、开关往返、西游档零改动、表与取整。

const J := preload("res://modes/xiyou/core/tianqi_jinran.gd")
var results: Array = []
var mat := 0


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state() -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


## 一件法宝（带 <Magic Weapon> 的防具）放进背包
func _fabao(s: XState) -> Dictionary:
	for r in XDB.table("Armors"):
		if r is Dictionary and str(r.get("name", "")) != "" and r.get("meta", {}).has("Magic Weapon"):
			var it := XGear.create("armor", int(r.id), s)
			s.register_gear(it)
			s.gear.append(it)
			return it
	return {}


## 当异源用的物品：拿得到、加减照实记的普通物品
func _find_material(s: XState) -> int:
	for r in XDB.table("Items"):
		if not r is Dictionary or str(r.get("name", "")) == "" or XState.item_max(int(r.id)) < 9999:
			continue
		var id := int(r.id)
		if XState.ECO_TO_SCORE.has(id) or XState.ECO_TO_ITEM.has(id) or s.item_count(id) != 0:
			continue
		s.gain_item(id, 50)
		var ok := s.item_count(id) == 50
		s.gain_item(id, -50)
		if ok and s.item_count(id) == 0:
			return id
	return 0


## 新档＋第一个人的本命已浸染（异痕）。返回 [s, 角色号]
func _fresh(material := 10000) -> Array:
	var s := _state()
	var aid := int(s.party[0])
	J.activate(s, aid, _fabao(s))
	if material > 0:
		s.gain_item(mat, material)
	return [s, aid]


func _j(s: XState, aid: int) -> Dictionary:
	var it = J.bound_item(s, aid)
	return it[J.FIELD] if it != null else {}


## 存档：当场过一遍 JSON 拍下来（to_dict 和内存里的装备共用字典，不拍下来之后的操作会改到「存档」）
func _save(s: XState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(s.to_dict()))


## 读档（和真存档一样过 JSON：数字变浮点、键变字符串）
func _reload(d: Dictionary) -> XState:
	var s := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	XState.current = s
	return s


## 直接把本命摆成异构、三格固定（测洗一条用）
func _set_top(s: XState, aid: int, keys: Array) -> Dictionary:
	var j := _j(s, aid)
	j.tier = 4
	j.slots = [{"key": keys[0], "tone": "dan"}, {"key": keys[1], "tone": "dan"}, {"key": keys[2], "tone": "dan"}]
	j.sleeping = null
	j.pending = null
	j.deck = {}
	return j


## 跨读档比较用：数字统一过一遍 JSON（读回来的整数是浮点）
func _js(x) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(x)))


func _keys(a: Array) -> Array:
	return a.map(func(e): return str(e.key))


func _run() -> void:
	XMessageBox.auto = true
	J.ENABLED = true
	var probe := _state()
	mat = _find_material(probe)
	J.material_override = mat
	_check("setup_material", mat > 0, mat)
	var f := _fresh()
	var s: XState = f[0]
	var aid: int = f[1]
	var j0 := _j(s, aid)
	_check("activate", int(j0.get("tier", 0)) == 1 and j0.slots[0] is Dictionary and j0.slots[1] == null and int(j0.n) == 1
		and J.base_pool(1).has(str(j0.slots[0].key)), j0)
	_check("activate_bound_once", J.activate(s, aid, _fabao(s)).has("error"))
	_check("lock", J.is_benming(s, J.bound_item(s, aid)) and not J.is_benming(s, s.gear[-1]))

	# 1 材料不足：不扣、不掷、不改
	s.gain_item(mat, -s.item_count(mat) + 5)
	var before := JSON.stringify(_j(s, aid))
	var r := J.advance(s, aid)
	_check("1_material_short", r.has("error") and s.item_count(mat) == 5 and JSON.stringify(_j(s, aid)) == before, r)
	J.material_override = 0
	var saved_item := int(J.data().get("material_item", 0))
	_check("1_no_material_item", saved_item > 0 or J.advance(s, aid).has("error"))  # 表里还没有异源物品号（J4 前）也只报不足
	J.material_override = mat
	s.gain_item(mat, 10000)

	# 2 退到底：异痕失败原地；蚀纹失败退异痕；异态失败退蚀纹；连败一路退到异痕为止
	J.ok_tape = [99]
	r = J.advance(s, aid)
	_check("2_fail_at_floor", not r.ok and int(_j(s, aid).tier) == 1 and int(_j(s, aid).res["2"]) == 1, r)
	J.ok_tape = [0, 0]
	J.advance(s, aid)
	J.advance(s, aid)
	_check("2_climb_to_3", int(_j(s, aid).tier) == 3)
	J.ok_tape = [99, 99, 99, 99]
	var tiers := []
	for i in 4:
		tiers.append(int(J.advance(s, aid).to))
	_check("2_slide_to_bottom", tiers == [2, 1, 1, 1], tiers)
	_check("2_sleep_on_drop", _j(s, aid).sleeping is Dictionary and _j(s, aid).slots[1] == null)

	# 3 三步残留交错：各步各记、只清本步、退阶不丢
	f = _fresh()
	s = f[0]
	aid = f[1]
	J.ok_tape = [0, 99, 99, 0]  # 冲蚀纹成；冲异态败（退异痕、残留3=1）；冲蚀纹败（残留2=1）；冲蚀纹成（残留2 清零）
	for i in 4:
		J.advance(s, aid)
	var j := _j(s, aid)
	_check("3_res_after_4", int(j.tier) == 2 and int(j.res["2"]) == 0 and int(j.res["3"]) == 1 and int(j.res["4"]) == 0, j.res)
	J.choose(s, aid, 1)
	var pv := J.preview(s, aid)
	_check("3_rate_shows_res", int(pv.rate) == 60 and int(pv.base) == 50 and int(pv.bonus) == 10 and int(pv.fail_to) == 1 and int(pv.sleeps) == 2, pv)
	J.ok_tape = [59, 99, 0]  # 60% 时掷 59 成（res3 清）；冲异构败（退蚀纹、res4=1）；再冲异态成
	for i in 3:
		J.advance(s, aid)
	j = _j(s, aid)
	_check("3_res_interleave", int(j.tier) == 3 and int(j.res["3"]) == 0 and int(j.res["4"]) == 1 and int(J.preview(s, aid).rate) == 40, [j.tier, j.res])
	# 必成：异构一步连败 13 次后 100%
	j.res["4"] = 13
	_check("3_cap_100", int(J.preview(s, aid).rate) == 100)
	j.res["4"] = 1

	# 4 连续读档同结果：同一份档读两次，各做同一个操作，结果和存档字段逐字相同
	J.ok_tape = []
	f = _fresh()
	s = f[0]
	aid = f[1]
	var d := _save(s)
	var outs := []
	for k in 2:
		var t := _reload(d)
		var rr := J.advance(t, aid)
		J.advance(t, aid)
		outs.append(_js([rr, _j(t, aid), t.item_count(mat)]))
	_check("4_reload_same", outs[0] == outs[1] and outs[0].find("error") < 0, outs)

	# 5 不存档重开掷出同结果：在内存里做了（没存档）→ 重开读的是操作前的档 → 再做一次，一样
	var mem := J.advance(s, aid)
	J.advance(s, aid)
	var first := _js([mem, _j(s, aid), s.item_count(mat)])
	var again := _reload(d)
	var rr2 := J.advance(again, aid)
	J.advance(again, aid)
	_check("5_no_save_same", first == _js([rr2, _j(again, aid), again.item_count(mat)]), [first])
	# 洗一条同样读档不变（候选、成色、洗牌堆）
	_set_top(s, aid, ["suiji", "dangzai", "juyi"])
	var d2 := _save(s)
	var w1 := _js(J.wash(s, aid, 2))
	var w2 := _js(J.wash(_reload(d2), aid, 2))
	_check("5_wash_same", w1 == w2 and w1.find("error") < 0, [w1, w2])

	# 6 有待选时禁操作；待选读档后原样恢复（不重掷）
	j = _j(s, aid)
	var m0 := s.item_count(mat)
	_check("6_pending_blocks", J.advance(s, aid).has("error") and J.wash(s, aid, 1).has("error") and s.item_count(mat) == m0, J.pending(s, aid))
	j.wash_marks = 6
	_check("6_pending_blocks_marks", J.spend_marks(s, aid, 1).has("error") and int(j.wash_marks) == 6)
	j.wash_marks = 1
	var keep := _js(J.pending(s, aid))
	var back := _reload(_save(s))
	_check("6_pending_restored", _js(J.pending(back, aid)) == keep and J.advance(back, aid).has("error"), keep)

	# 7 跳演出只扣一次：扣款在 advance 里一次做完；演出／跳过只读状态，不再动存档
	f = _fresh()
	s = f[0]
	aid = f[1]
	m0 = s.item_count(mat)
	J.ok_tape = [0]
	r = J.advance(s, aid)
	var snap := JSON.stringify(_j(s, aid))
	for k in 3:  # 演出播放、跳过、关窗口：界面只读 preview／pending
		J.preview(s, aid)
		J.pending(s, aid)
	_check("7_skip_once", r.ok and s.item_count(mat) == m0 - 10 and int(_j(s, aid).n) == 2 and JSON.stringify(_j(s, aid)) == snap, [m0, s.item_count(mat)])

	# 8 确认选项只结算一次
	_set_top(s, aid, ["suiji", "dangzai", "juyi"])
	J.wash(s, aid, 3)
	var p: Dictionary = J.pending(s, aid)
	var c1 = J.choose(s, aid, 1)
	var after1 := JSON.stringify(_j(s, aid).slots)
	var c2 = J.choose(s, aid, 2)
	_check("8_choose_once", c1.has("ok") and c2.has("error") and JSON.stringify(_j(s, aid).slots) == after1
		and str(_j(s, aid).slots[2].key) == str(p.cands[0].key), [c1, c2])
	J.wash(s, aid, 3)
	var old3 = _j(s, aid).slots[2]
	_check("8_keep_old", J.choose(s, aid, 0).has("ok") and JSON.stringify(_j(s, aid).slots[2]) == JSON.stringify(old3))

	# 9 再退到异痕时沉睡的是最终选中的第 2 格
	f = _fresh()
	s = f[0]
	aid = f[1]
	J.ok_tape = [0, 99]
	J.advance(s, aid)  # 蚀纹，第 2 格 A
	var a_entry = _j(s, aid).slots[1]
	J.advance(s, aid)  # 冲异态败 → 异痕，A 沉睡
	_check("9_first_sleep", JSON.stringify(_j(s, aid).sleeping) == JSON.stringify(a_entry))
	j = _j(s, aid)
	j.n = 77  # 换一个 n，让新掷的那条和 A 不同（同名也合法，这里只为分得清）
	var got_b := false
	for tries in 40:
		J.ok_tape = [0]
		J.advance(s, aid)
		var pp = J.pending(s, aid)
		if pp is Dictionary and str(pp.cands[0].key) != str(a_entry.key):
			got_b = true
			break
		J.choose(s, aid, 0)
		J.ok_tape = [99]
		J.advance(s, aid)
	_check("9_pick_offered", got_b and _j(s, aid).slots[1] == null and _j(s, aid).sleeping == null)
	var b_entry = J.pending(s, aid).cands[0]
	J.choose(s, aid, 1)  # 选新的 B
	J.ok_tape = [99]
	J.advance(s, aid)  # 冲异态败 → 再退到异痕
	_check("9_sleep_is_final", JSON.stringify(_j(s, aid).sleeping) == JSON.stringify(b_entry) and str(_j(s, aid).sleeping.key) != str(a_entry.key),
		[_j(s, aid).sleeping, a_entry])

	# 10 每轮（这一格连洗 3 次）每条合法词条至少出现一次：第 1 格（池 7）、第 2 格（池 8），各跑 40 轮
	J.ok_tape = []
	var miss := []
	for slot in [1, 2]:
		f = _fresh(100000)
		s = f[0]
		aid = f[1]
		j = _set_top(s, aid, ["suiji", "dangzai", "juyi"])
		var pool := J.legal_pool(j, slot)
		for rnd in 40:
			var seen := {}
			for k in 3:
				if rnd == 0:
					_check("10_left_%d_%d" % [slot, k], J.round_left(s, aid, slot) == 3 - k)
				var w := J.wash(s, aid, slot)
				var cs := _keys(w.ok.cands)
				if cs.size() != 3 or cs.size() != _uniq(cs).size():
					miss.append(["dup_or_short", slot, rnd, cs])
				for x in cs:
					seen[x] = true
				J.choose(s, aid, 0)  # 留旧的，池不变
			for x in pool:
				if not seen.has(x):
					miss.append([slot, rnd, x])
	_check("10_every_round_all", miss.is_empty(), miss.slice(0, 5))

	# 11 换格洗不推进别格的轮
	f = _fresh()
	s = f[0]
	aid = f[1]
	j = _set_top(s, aid, ["suiji", "dangzai", "juyi"])
	J.wash(s, aid, 2)
	J.choose(s, aid, 0)
	var deck2 := JSON.stringify(j.deck["2"])
	J.wash(s, aid, 3)
	J.choose(s, aid, 0)
	J.wash(s, aid, 1)
	J.choose(s, aid, 0)
	_check("11_other_slot_round", JSON.stringify(_j(s, aid).deck["2"]) == deck2 and J.round_left(s, aid, 2) == 2 and J.round_left(s, aid, 3) == 2,
		[deck2, _j(s, aid).deck])

	# 12 合法池中途变化：第 2 格一轮洗到一半，第 3 格从 聚异 换成 X → 第 2 格的叠删掉 X、聚异 新变合法插进剩下的叠，本轮剩下两次一定出
	var bad := []
	for trial in 20:
		f = _fresh()
		s = f[0]
		aid = f[1]
		j = _set_top(s, aid, ["suiji", "dangzai", "juyi"])
		j.n = 1000 + trial * 7
		var round_seen := {}
		var w := J.wash(s, aid, 2)
		for x in _keys(w.ok.cands):
			round_seen[x] = true
		J.choose(s, aid, 0)
		# 第 3 格洗到一个第 2 格这轮还没出过的名字（出过的话换个 n 再洗，最多 30 次）
		var x_key := ""
		for tries in 30:
			var w3 := J.wash(s, aid, 3)
			var pick := -1
			for i in w3.ok.cands.size():
				var k := str(w3.ok.cands[i].key)
				if k != "juyi" and J.legal_pool(j, 2).has(k):
					pick = i
					break
			if pick >= 0:
				J.choose(s, aid, pick + 1)
				x_key = str(_j(s, aid).slots[2].key)
				break
			J.choose(s, aid, 0)
		if x_key == "":
			bad.append(["no_x", trial])
			continue
		var pool2 := J.legal_pool(j, 2)
		var rest := {}
		for k in 2:
			var ww := J.wash(s, aid, 2)
			for x in _keys(ww.ok.cands):
				rest[x] = true
				round_seen[x] = true
			J.choose(s, aid, 0)
		if rest.has(x_key):
			bad.append(["illegal_drawn", trial, x_key])
		if not pool2.has("juyi") or not round_seen.has("juyi"):
			bad.append(["new_legal_missing", trial, pool2])
		# 整轮都合法的（第 2 格池去掉 X 和 聚异）每条都出过
		for x in pool2:
			if x != "juyi" and not round_seen.has(x):
				bad.append(["guarantee", trial, x])
	_check("12_pool_change", bad.is_empty(), bad.slice(0, 5))

	# 洗痕满 6 改浓、清零、同名不换
	f = _fresh()
	s = f[0]
	aid = f[1]
	j = _set_top(s, aid, ["suiji", "dangzai", "juyi"])
	for k in 5:
		J.wash(s, aid, 1)
		J.choose(s, aid, 0)
	_check("marks_need_6", int(j.wash_marks) == 5 and J.spend_marks(s, aid, 1).has("error"))
	J.wash(s, aid, 1)
	J.choose(s, aid, 0)
	var key1 := str(j.slots[0].key)
	j.slots[0].tone = "dan"
	var sm := J.spend_marks(s, aid, 1)
	_check("marks_to_nong", sm.has("ok") and str(j.slots[0].tone) == "nong" and str(j.slots[0].key) == key1 and int(j.wash_marks) == 0, sm)

	# n／扣款／待选／洗痕同一次提交
	var m1 := s.item_count(mat)
	var n1 := int(j.n)
	J.wash(s, aid, 2)
	_check("one_commit", s.item_count(mat) == m1 - 40 and int(j.n) == n1 + 1 and j.pending is Dictionary and int(j.wash_marks) == 1)
	J.choose(s, aid, 0)

	# 开关往返：关时不能操作、本命锁解除、字段留着；开回来照旧
	var keep_j := _js(j)
	var item = J.bound_item(s, aid)
	J.ENABLED = false
	_check("off", J.advance(s, aid).has("error") and J.wash(s, aid, 1).has("error") and not J.is_benming(s, item) and J.preview(s, aid).is_empty()
		and _js(item[J.FIELD]) == keep_j)
	var off_back := _reload(_save(s))
	J.ENABLED = true
	_check("on_again", J.is_benming(off_back, J.bound_item(off_back, aid)) and _js(_j(off_back, aid)) == keep_j, [_js(_j(off_back, aid)), keep_j])

	# 西游档零改动：不浸染、不写 flags、不锁
	var plain := XState.new_game(3, 1, [8, 9, 10])
	var pit := _fabao(plain)
	var flags0 := JSON.stringify(plain.flags)
	_check("xiyou_off", not J.on(plain) and J.activate(plain, 8, pit).has("error") and not pit.has(J.FIELD)
		and JSON.stringify(plain.flags) == flags0 and not J.is_benming(plain, pit) and J.bound_item(plain, 8) == null)

	# 复制装备不带本命（GEAR_KEYS copy=false）、强化换件整份搬
	var cp: Dictionary = item.duplicate(true)
	XTianqiSave.strip_on_copy(cp)
	_check("copy_strips", not cp.has(J.FIELD))
	var nw := _fabao(s)
	var mv := J.move_to(s, aid, nw)
	_check("move_to", mv.has("ok") and not item.has(J.FIELD) and is_same(J.bound_item(s, aid), nw) and _js(nw[J.FIELD]) == keep_j)

	# 表与取整：C 案系数（4.1 表）、浓 ×125% 向下取整（9.2 例：随击蚀纹浓 56）、残光不在第 1 格外的词条
	var coef := [J.coef_pct(120, 2), J.coef_pct(150, 2), J.coef_pct(180, 3), J.coef_pct(200, 4)]
	_check("coef_table", coef == [138, 172, 234, 300], coef)
	_check("amp_nong", J.amp({"key": "suiji", "tone": "nong"}, 2) == 56 and J.amp({"key": "suiji", "tone": "dan"}, 4) == 80)
	_check("slot1_pool", J.base_pool(1).size() == 8 and not J.base_pool(1).has("manying") and not J.base_pool(1).has("juyi") and J.base_pool(2).size() == 10)

	J.ENABLED = false
	J.material_override = 0
	J.ok_tape = []
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _uniq(a: Array) -> Array:
	var out := []
	for x in a:
		if not out.has(x):
			out.append(x)
	return out
