extends Node
## 宝珠坊规则（XOrbs 鉴定／残片兑换／分解／暂存）与 mv_oracle orb_shop_probe.cjs 的正式读数（generated/oracle/orb_shop.json）
## 逐项比对：各随机流前 25 个值与 rollInt、4 个种子 × 5 种神秘珠 × 3 种数量的鉴定结果与随机流序号、鉴定失败提示、
## 可能产出与概率、9 档进度 × 4 种残片数的兑换、分解、暂存宝珠与神秘珠暂存箱的领取；另测存读档保留宝珠坊状态。

var results := []
const ORACLE := "res://modes/xiyou/generated/oracle/orb_shop.json"


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


## 数字一律当浮点比（JSON 读回都是浮点）
static func norm(v):
	if v is int or v is float:
		return snappedf(float(v), 0.0000000001)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


static func fresh(seed: int, v20 := -1) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.items = {}
	s.orb_seed = seed
	s.orb_state = {"n": {}, "returns": {}, "inbox": {}, "recent": []}
	if v20 >= 0:
		s.set_variable(20, v20)
	return s


static func bag(s: XState) -> Dictionary:
	var out := {}
	for k in s.items:
		if int(s.items[k]) > 0:
			out[str(k)] = float(s.items[k])
	return out


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("oracle_loaded", d is Dictionary and d.get("identify", []).size() >= 60, ORACLE):
		_rolls(d)
		_identify(d)
		_buy(d)
		_dismantle(d)
		_returns(d)
	_save_roundtrip()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _rolls(d: Dictionary) -> void:
	var bad := []
	var seed_state := {}
	for r in d.rolls:
		if not seed_state.has(r.seed):
			seed_state[r.seed] = fresh(int(r.seed))
		var s: XState = seed_state[r.seed]
		var got := []
		for i in range(r.values.size()):
			got.append(float(XOrbs.roll_int(s, str(r.stream), int(r.rollInt[0]), int(r.rollInt[1]))) if r.has("rollInt") else XOrbs.roll(s, str(r.stream)))
		if norm(got) != norm(r.values):
			bad.append([r.seed, r.stream, r.has("rollInt"), got.slice(0, 3), r.values.slice(0, 3)])
	check("roll_streams", bad.is_empty() and d.rolls.size() >= 20, bad)


func _identify(d: Dictionary) -> void:
	var bad := []
	for c in d.identify:
		var s := fresh(int(c.seed))
		s.gain_item(int(c.id), int(c.q) + 2)
		var mx := XOrbs.max_identify(s, int(c.id))
		var quote := XOrbs.quote_identify(s, int(c.id), int(c.q))
		var res := XOrbs.identify(s, int(c.id), int(c.q))
		if mx != int(c.max) or norm(quote) != norm(c.quote) or norm(res) != norm(c.result) or bag(s) != norm(c.bag) or norm(s.orb_state.n) != norm(c.rng.n) \
				or norm(s.orb_state.recent) != norm(c.recent):
			bad.append({"case": [c.seed, c.id, c.q], "got": [mx, res, s.orb_state.n], "want": [c.max, c.result, c.rng.n]})
	check("identify_outcomes", bad.is_empty(), bad.slice(0, 2))
	var f := {}
	for x in d.identifyFail:
		f[x.case] = x
	var s := fresh(1)
	s.gain_item(3027, 3)
	check("identify_fail_not_pearl", norm(XOrbs.quote_identify(s, 2947, 1)) == norm(f["not-pearl"].quote))
	check("identify_fail_zero", norm(XOrbs.quote_identify(s, 3027, 0)) == norm(f["zero"].quote))
	check("identify_fail_fraction", norm(XOrbs.quote_identify(s, 3027, 1.5)) == norm(f["fraction"].quote))
	check("identify_fail_short", norm(XOrbs.quote_identify(s, 3027, 4)) == norm(f["short"].quote))
	s.gain_item(int(f.full.full), 9998)
	check("identify_fail_full", XOrbs.max_identify(s, 3027) == int(f.full.max) and norm(XOrbs.quote_identify(s, 3027, 2)) == norm(f.full.quote) \
		and norm(XOrbs.quote_identify(s, 3027, 1)) == norm(f.full.one), [XOrbs.quote_identify(s, 3027, 2), f.full])
	var res := XOrbs.identify(s, 3027, 2)
	check("identify_full_keeps_bag", norm(res) == norm(f["identify-full"].result) and bag(s) == norm(f["identify-full"].bag) and s.orb_state.n.is_empty())
	bad = []
	for p in d.possible:
		var got := {"possible": XOrbs.possible(int(p.id)), "probabilities": XOrbs.probabilities(int(p.id)), "legacy": XOrbs.legacy_pool(XOrbs.seal(int(p.id)))}
		if norm(got) != norm({"possible": p.possible, "probabilities": p.probabilities, "legacy": p.legacy}):
			bad.append([p.id, got])
	check("identify_possible", bad.is_empty() and d.possible.size() == 5, bad)


func _buy(d: Dictionary) -> void:
	var bad := []
	for c in d.buy:
		if c.has("case"):
			var s := fresh(3, 10)
			s.gain_item(int(d.config.fragment), 50)
			s.gain_item(3028, 9999)
			check("buy_pearl_full", norm(XOrbs.quote_buy(s, 1)) == norm(c.quote), [XOrbs.quote_buy(s, 1), c.quote])
			continue
		var s := fresh(3, int(c.v20))
		if int(c.frag) > 0:
			s.gain_item(int(d.config.fragment), int(c.frag))
		var b := XOrbs.progress_band(s)
		var got := {"band": null if b.is_empty() else float(b.itemId), "price": float(XOrbs.pearl_price(b) if not b.is_empty() else 0),
			"quote1": XOrbs.quote_buy(s, 1), "quote5": XOrbs.quote_buy(s, 5)}
		got["buy"] = XOrbs.buy_pearl(s, 1)
		got["bag"] = bag(s)
		var want := {"band": c.band, "price": c.price, "quote1": c.quote1, "quote5": c.quote5, "buy": c.buy, "bag": c.bag}
		if norm(got) != norm(want):
			bad.append([c.v20, c.frag, got, want])
	check("buy_by_progress", bad.is_empty() and d.buy.size() >= 36, bad.slice(0, 2))


func _dismantle(d: Dictionary) -> void:
	var bad := []
	for c in d.dismantle:
		if c.has("case"):
			var s := fresh(5)
			s.gain_item(2951, 2)
			s.gain_item(int(d.config.fragment), 9999 - 40)
			check("dismantle_fragment_full", norm(XOrbs.quote_dismantle(s, 2951, 2)) == norm(c.quote) and norm(XOrbs.quote_dismantle(s, 2951, 1)) == norm(c.one))
			continue
		var s := fresh(5)
		s.gain_item(int(c.id), 4)
		var got := {"refund": float(XOrbs.refund(int(c.id))), "isOrb": XOrbs.is_orb_item(int(c.id)), "quote": XOrbs.quote_dismantle(s, int(c.id), 3),
			"zero": XOrbs.quote_dismantle(s, int(c.id), 0), "many": XOrbs.quote_dismantle(s, int(c.id), 5)}
		got["result"] = XOrbs.dismantle(s, int(c.id), 3)
		got["bag"] = bag(s)
		var want := {"refund": c.refund, "isOrb": c.isOrb, "quote": c.quote, "zero": c.zero, "many": c.many, "result": c.result, "bag": c.bag}
		if norm(got) != norm(want):
			bad.append([c.id, got, want])
	check("dismantle_cases", bad.is_empty() and d.dismantle.size() == 9, bad)


func _returns(d: Dictionary) -> void:
	var s := fresh(9)
	s.orb_state.returns = {"item 2947": 3, "item 56": 2, "item 99999": 1, "weapon 1": 1}
	s.gain_item(2947, 9998)
	var w: Array = d.returns
	check("returns_pending", XOrbs.pending_returns(s) == int(w[0].pending))
	var gained := XOrbs.claim_returns(s)
	# 正式版「weapon 1」领取时生成新装备却不扣暂存数（数据里不会出现）；Godot 不领，暂存同样保留
	check("returns_claim", gained == int(w[1].gained) and norm(s.orb_state.returns) == norm(w[1].box) and bag(s) == norm(w[1].bag), [gained, s.orb_state.returns, bag(s)])
	s.gain_item(2947, -5)
	gained = XOrbs.claim_returns(s)
	check("returns_claim_again", gained == int(w[2].gained) and norm(s.orb_state.returns) == norm(w[2].box) and bag(s) == norm(w[2].bag), [gained, s.orb_state.returns])
	s = fresh(9)
	s.orb_state.inbox = {"3027": 2, "3029": 1, "2947": 4}
	s.gain_item(3027, 9998)
	gained = XOrbs.claim_drops(s)
	check("inbox_claim", gained == int(d.inbox[0].gained) and norm(s.orb_state.inbox) == norm(d.inbox[0].box) and bag(s) == norm(d.inbox[0].bag), [gained, s.orb_state.inbox, bag(s)])


func _save_roundtrip() -> void:
	var s := fresh(77)
	s.gain_item(3028, 4)
	XOrbs.identify(s, 3028, 2)
	s.orb_state.returns = {"item 56": 1}
	s.orb_state.inbox = {"3030": 2}
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("rt_orb_state", norm(back.orb_state.n) == norm(s.orb_state.n) and norm(back.orb_state.returns) == norm(s.orb_state.returns) \
		and norm(back.orb_state.inbox) == norm(s.orb_state.inbox) and norm(back.orb_state.recent) == norm(s.orb_state.recent), back.orb_state)
	# 读档后接着鉴定，与不存读一路鉴定的结果相同（防 SL）
	s.gain_item(3028, 1)
	back.gain_item(3028, 1)
	check("rt_identify_continues", norm(XOrbs.identify(s, 3028, 1)) == norm(XOrbs.identify(back, 3028, 1)))
