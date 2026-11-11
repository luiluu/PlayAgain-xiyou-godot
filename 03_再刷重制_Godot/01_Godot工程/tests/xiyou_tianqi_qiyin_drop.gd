extends Node
## 七印祭坛里副本掉落（XTianqiQiyinDrop，tianqi_data/qiyin_drop.json）的自检：
## 一、表：七印、六部位、武器类型、五难度键同 XTianqi.DIFFICULTIES、神器五件、设计数值不含 4。
## 二、规则单测（脚本随机流，按抽取原因喂值）：空次数递增与归零、连空 20 次必掉、两连三连最多 3 件、没掉给印屑；
##    武器暗保底 20、真印暗保底 30、成色；躁动不连抽与打赢平息；献印屑第一件部位、没掉退 3 个；献武器翻倍且同类；
##    物品掉落加成不碰真印和神器；首通、守层者首杀、野外、精英印屑、直取；熔、分解、兑换的数；状态传进不被改。
## 三、统计（固定种子）：艰险刷一印凑齐 5 件不同部位要打几次 Boss（起手已有守层者首杀和首通各 1 件），
##    平均 30～36、中位 27～33（设计测算 套装凑齐.py：平均约 33、中位 30、十分位约 16、九十分位约 52）；两连约 10%、三连约 1%。
## 不用转换产物，不建存档。人数可用 -- --people=N 改（默认 20000）。

const D := preload("res://modes/xiyou/core/tianqi_qiyin_drop.gd")
const PEOPLE := 20000

var results: Array = []


## 按抽取原因喂值的随机流：queues {原因: [值…]}，用完或没写的原因给 fallback（浮点）／0（下标）。
## seen 记每次抽取的原因，断言「抽没抽」用。
class Tape extends XRandomStream:
	var queues: Dictionary = {}
	var fallback := 0.999
	var seen: Array = []

	func _init(q := {}, fb := 0.999) -> void:
		queues = q.duplicate(true)
		fallback = fb

	func _pop(reason: String):
		seen.append(reason)
		draws += 1
		var q = queues.get(reason, [])
		if q is Array and not q.is_empty():
			return q.pop_front()
		return null

	func next_float(reason: String, _event_key := "") -> float:
		var v = _pop(reason)
		return fallback if v == null else float(v)

	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		var v = _pop(reason)
		return 0 if v == null else int(v) % n

	func count(reason: String) -> int:
		return seen.count(reason)


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


func _people() -> int:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--people="):
			return int(str(a).substr(9))
	return PEOPLE


func _run() -> void:
	D.reload()
	_table()
	_boss_set()
	_chain()
	_weapon()
	_true_seal()
	_grades_parts()
	_drop_mult_artifact()
	_restless()
	_offering()
	_first_and_field()
	_melt_dismantle_exchange()
	_pure()
	_stats()
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _st(over := {}) -> Dictionary:
	var s := D.new_state()
	for k in over:
		s[k] = over[k]
	return s


func _boss(state: Dictionary, q := {}, seal := "bai", diff := "jianxian", owned = [], offering := {}, mult := 1.0) -> Dictionary:
	var rng := Tape.new(q)
	var r := D.roll_boss(state, seal, diff, owned, offering, mult, rng)
	r["_rng"] = rng
	return r


# ---- 一、表 ----

func _table() -> void:
	var d := D.data()
	_check("表能读", not d.is_empty())
	_check("表头 draft／来源", d.get("draft") == true and str(d.get("source", "")).contains("七印祭坛方案 v0.4") \
		and str(d.get("_note", "")).contains("Kyo 11-12 定稿"), [d.get("draft"), d.get("source")])
	_check("七印", D.seals() == ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"], D.seals())
	_check("六部位", D.parts() == ["head", "body", "hands", "waist", "legs", "feet"], D.parts())
	for s in D.seals():
		var n := D.weapon_classes(s).size()
		_check("武器类型数：" + s, n == (12 if s == "mo" else 2), n)
	var all12 := {}
	for s in D.seals():
		if s != "mo":
			for w in D.weapon_classes(s):
				all12[w] = true
	_check("前六印的 12 类正好是默印的 12 类", all12.keys().size() == 12 and D.weapon_classes("mo").all(func(w): return all12.has(w)))
	var want: Array = XTianqi.DIFFICULTIES.map(func(x): return x.key)
	_check("武器几率难度键同 XTianqi.DIFFICULTIES", d.boss_weapon.chance.keys() == want, d.boss_weapon.chance.keys())
	_check("真印几率难度键同 XTianqi.DIFFICULTIES", d.true_seal.chance.keys() == want, d.true_seal.chance.keys())
	_check("神器五件", D.artifact_keys() == ["bow_crown", "great_sword", "scales", "grey_scythe", "seven_seal_scroll"], D.artifact_keys())
	_check("31 层揭白红", D.floor_seals(31) == ["bai", "hong"] and D.floor_seals(35) == ["zhen"] and D.floor_seals(36).is_empty())
	var bad := D.nice_number_violations()
	_check("设计数值不含 4", bad.is_empty(), bad)
	_check("成色权重合计 1", is_equal_approx(d.grades.weights.values().reduce(func(a, b): return a + b, 0.0), 1.0))


# ---- 二、规则单测 ----

func _boss_set() -> void:
	# 没掉：空次数 +1、给 1 个印屑、不掉件
	var r := _boss(_st())
	_check("没掉：空次数 1", r.state.set_miss.get("bai") == 1, r.state.set_miss)
	_check("没掉：给 1 个印屑", r.shards == 1 and r.set_pieces.is_empty(), r.shards)
	_check("几率 5% 起每空 +2%", is_equal_approx(D.boss_set_chance(_st(), "bai"), 0.05) \
		and is_equal_approx(D.boss_set_chance(r.state, "bai"), 0.07) \
		and is_equal_approx(D.boss_set_chance(_st({"set_miss": {"bai": 10}}), "bai"), 0.25))
	var r2 := _boss(r.state)
	_check("再空：空次数 2", r2.state.set_miss.get("bai") == 2)
	# 掉落边界：空 5 次时几率 15%
	var s5 := _st({"set_miss": {"bai": 5}})
	_check("几率边界：0.149 掉", _boss(s5, {"qiyin_boss_set": [0.149]}).set_pieces.size() == 1)
	_check("几率边界：0.151 不掉", _boss(s5, {"qiyin_boss_set": [0.151]}).set_pieces.is_empty())
	var hit := _boss(s5, {"qiyin_boss_set": [0.0]})
	_check("掉了归零", hit.state.set_miss.get("bai") == 0 and hit.shards == 0, hit.state.set_miss)
	_check("掉的是本印套装件", hit.set_pieces[0].kind == "set" and hit.set_pieces[0].seal == "bai")
	# 各印各记
	var rb := _boss(_st({"set_miss": {"hong": 7}}))
	_check("各印各记空次数", rb.state.set_miss.get("bai") == 1 and rb.state.set_miss.get("hong") == 7, rb.state.set_miss)
	# 暗保底：连空 20 次后下一次必掉，且不抽掉不掉
	var s19 := _st({"set_miss": {"bai": 19}})
	var m19 := _boss(s19)
	_check("连空 19 次时几率 43%，还可能空", m19.set_pieces.is_empty() and m19.state.set_miss.bai == 20 \
		and is_equal_approx(D.boss_set_chance(s19, "bai"), 0.43))
	var p20 := _boss(m19.state)
	_check("连空 20 次后必掉", p20.set_pieces.size() == 1 and p20.state.set_miss.bai == 0, p20.set_pieces)
	_check("暗保底不抽掉落数", p20._rng.count("qiyin_boss_set") == 0)
	# 连续空 20 次（全 0.999）后第 21 次必掉
	var s := _st()
	var n := 0
	while n < 30:
		n += 1
		var x := _boss(s)
		s = x.state
		if not x.set_pieces.is_empty():
			break
	_check("全空的运气下第 21 次掉", n == 21, n)


func _chain() -> void:
	var s := _st({"set_miss": {"bai": 20}})
	_check("掉了默认 1 件", _boss(s).set_pieces.size() == 1)
	var two := _boss(s, {"qiyin_boss_chain": [0.099, 0.5]})
	_check("两连：0.099 再掉 1 件", two.set_pieces.size() == 2, two.set_pieces.size())
	_check("两连边界：0.101 不连", _boss(s, {"qiyin_boss_chain": [0.101]}).set_pieces.size() == 1)
	var three := _boss(s, {"qiyin_boss_chain": [0.0, 0.0, 0.0, 0.0]})
	_check("三连上限 3 件", three.set_pieces.size() == 3, three.set_pieces.size())
	_check("三连后不再抽连掉", three._rng.count("qiyin_boss_chain") == 2, three._rng.count("qiyin_boss_chain"))
	var pp := _boss(s, {"qiyin_boss_chain": [0.0, 0.0], "qiyin_part": [0.1, 0.1, 0.1]})
	var parts: Array = pp.set_pieces.map(func(p): return p.part)
	_check("连掉的部位按刚掉的减半（同一次里也算已有）", parts == ["head", "body", "body"], parts)


func _weapon() -> void:
	var r := _boss(_st())
	_check("武器没掉：空次数 1", r.state.weapon_miss.get("bai") == 1 and r.weapon.is_empty())
	var want := {"xunchang": 0.03, "jianxian": 0.05, "jiusi": 0.06, "lianyu": 0.08, "zhengdao": 0.1}
	for k in want:
		var p: float = want[k]
		_check("武器几率 %s 边界内掉" % k, not _boss(_st(), {"qiyin_boss_weapon": [p - 0.001]}, "bai", k).weapon.is_empty())
		_check("武器几率 %s 边界外不掉" % k, _boss(_st(), {"qiyin_boss_weapon": [p + 0.001]}, "bai", k).weapon.is_empty())
	var w := _boss(_st({"weapon_miss": {"bai": 3}}), {"qiyin_boss_weapon": [0.0], "qiyin_wtype": [1]})
	_check("武器掉了归零、类型随机在本印里", w.state.weapon_miss.bai == 0 and w.weapon.kind == "weapon" and w.weapon.wtype == "暗器", w.weapon)
	var m := _boss(_st({"weapon_miss": {"mo": 0}}), {"qiyin_boss_weapon": [0.0], "qiyin_wtype": [11]}, "mo")
	_check("默印 12 类随机", m.weapon.wtype == "书", m.weapon)
	var s19 := _st({"weapon_miss": {"bai": 19}})
	var m19 := _boss(s19)
	_check("武器连空 19 次还会空", m19.weapon.is_empty() and m19.state.weapon_miss.bai == 20)
	var p20 := _boss(m19.state)
	_check("武器连空 20 次后必掉", not p20.weapon.is_empty() and p20.state.weapon_miss.bai == 0)
	_check("武器暗保底不抽掉落数", p20._rng.count("qiyin_boss_weapon") == 0)
	_check("武器各印各记", _boss(_st({"weapon_miss": {"hong": 20}})).weapon.is_empty())


func _true_seal() -> void:
	var s := _st({"set_miss": {"bai": 20}})
	var t := _boss(s, {"qiyin_true_seal": [0.099]})
	_check("真印几率（艰险 10%）边界内", t.set_pieces[0].true_seal and t.state.true_miss == 0)
	var f := _boss(_st({"set_miss": {"bai": 20}, "true_miss": 7}), {"qiyin_true_seal": [0.101]})
	_check("真印边界外：空件数 +1", not f.set_pieces[0].true_seal and f.state.true_miss == 8, f.state.true_miss)
	var z := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_true_seal": [0.299]}, "bai", "zhengdao")
	_check("证道真印 30%", z.set_pieces[0].true_seal)
	var x := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_true_seal": [0.051]}, "bai", "xunchang")
	_check("寻常真印 5%", not x.set_pieces[0].true_seal)
	var p := _boss(_st({"set_miss": {"bai": 20}, "true_miss": 30}))
	_check("全局连续 30 件没出，下一件必是真印", p.set_pieces[0].true_seal and p.state.true_miss == 0 and p._rng.count("qiyin_true_seal") == 0)
	_check("真印三条全极、不抽成色", p.set_pieces[0].grades == ["ji", "ji", "ji"] and p._rng.count("qiyin_grade") == 0)
	var q := _boss(_st({"set_miss": {"bai": 20}, "true_miss": 29}))
	_check("29 件时还会空", not q.set_pieces[0].true_seal and q.state.true_miss == 30)
	# 武器和套装件共用一个计数，按掉落顺序
	var both := _boss(_st({"set_miss": {"bai": 20}, "weapon_miss": {"bai": 20}, "true_miss": 29}))
	_check("套装件、武器共用真印计数", not both.set_pieces[0].true_seal and both.weapon.true_seal and both.state.true_miss == 0)
	# 三连每件单独掷
	var each := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_boss_chain": [0.0, 0.0], "qiyin_true_seal": [0.5, 0.0, 0.5]})
	_check("每件单独掷真印", each.set_pieces.map(func(i): return i.true_seal) == [false, true, false] and each.state.true_miss == 1)


func _grades_parts() -> void:
	var g := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_grade": [0.0, 0.6, 0.85]})
	_check("成色：普通 50% 上品 30% 极 20%", g.set_pieces[0].grades == ["putong", "shangpin", "ji"], g.set_pieces[0].grades)
	_check("非真印抽 3 次成色", g._rng.count("qiyin_grade") == 3)
	# 部位权重：已有减半
	var a := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_part": [0.1]}, "bai", "jianxian", ["head"])
	var b := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_part": [0.1]}, "bai", "jianxian", [])
	_check("已有部位权重减半", a.set_pieces[0].part == "body" and b.set_pieces[0].part == "head", [a.set_pieces[0].part, b.set_pieces[0].part])
	_check("owned 也可以是 {印: 部位}", _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_part": [0.1]}, "bai", "jianxian",
		{"bai": ["head"], "hong": []}).set_pieces[0].part == "body")
	var rng := XRandomStream.create(XRandomStream.derive("0123456789abcdef", "qiyin-part"), "qiyin")
	var cnt := {}
	var n := 30000
	for i in n:
		var p := D._pick_part(["head", "body"], rng, "qiyin_part")
		cnt[p] = int(cnt.get(p, 0)) + 1
	var fh := float(cnt.get("head", 0)) / n
	var ff := float(cnt.get("feet", 0)) / n
	_check("部位统计：已有 1/10、没有 1/5", absf(fh - 0.1) < 0.01 and absf(ff - 0.2) < 0.015, [fh, ff])


func _drop_mult_artifact() -> void:
	# 加成 ×2：套装件 5%→10%，武器 5%→10%；真印、神器不变
	var r := _boss(_st(), {"qiyin_boss_set": [0.099], "qiyin_boss_weapon": [0.099], "qiyin_true_seal": [0.15, 0.15],
		"qiyin_artifact": [0.0015]}, "bai", "jianxian", [], {}, 2.0)
	_check("加成对套装件生效", r.set_pieces.size() == 1)
	_check("加成对武器生效", not r.weapon.is_empty())
	_check("加成不碰真印", not r.set_pieces[0].true_seal and not r.weapon.true_seal)
	_check("加成不碰神器", r.artifact == "")
	_check("加成 ×1 时 0.099 不掉", _boss(_st(), {"qiyin_boss_set": [0.099]}).set_pieces.is_empty())
	var a := _boss(_st(), {"qiyin_artifact": [0.0009], "qiyin_artifact_pick": [3]})
	_check("神器 0.1%，五件里随机一件", a.artifact == "grey_scythe", a.artifact)
	_check("神器边界外", _boss(_st(), {"qiyin_artifact": [0.0011]}).artifact == "")
	_check("神器不随难度变", _boss(_st(), {"qiyin_artifact": [0.0009]}, "bai", "xunchang").artifact != "" \
		and _boss(_st(), {"qiyin_artifact": [0.0011]}, "bai", "zhengdao").artifact == "")


func _restless() -> void:
	var s := D.new_state()
	var rv := ["bai", "hong", "hei"]
	var e1 := D.on_enter(s, rv, Tape.new())
	var e2 := D.on_enter(e1.state, rv, Tape.new())
	_check("前两次不躁动", e1.restless == "" and e2.restless == "" and e2.state.enter_count == 2)
	var e3 := D.on_enter(e2.state, rv, Tape.new({"qiyin_restless": [1]}))
	_check("第 3 次抽一印躁动", e3.restless == "hong" and e3.state.restless == "hong", e3.restless)
	var e6 := D.on_enter(_st({"enter_count": 5, "restless": "hong", "restless_last": "hong"}), rv, Tape.new({"qiyin_restless": [1]}))
	_check("不连抽同一印（去掉上一印再抽）", e6.restless == "hei", e6.restless)
	var one := D.on_enter(_st({"enter_count": 2, "restless_last": "bai"}), ["bai"], Tape.new())
	_check("只揭开一印就是它", one.restless == "bai")
	var two := D.on_enter(_st({"enter_count": 2, "restless_last": "bai"}), ["bai", "hong"], Tape.new())
	_check("两印时必换另一印、不抽随机数", two.restless == "hong" and two.state.restless == "hong")
	var none := D.on_enter(_st({"enter_count": 2}), [], Tape.new())
	_check("没揭开的印不躁动", none.restless == "" and none.state.enter_count == 3)
	# 固定种子连进 300 次，相邻两次躁动不同印
	var rng := XRandomStream.create(XRandomStream.derive("0123456789abcdef", "qiyin-restless"), "qiyin")
	var st := D.new_state()
	var picks: Array = []
	for i in 300:
		var e := D.on_enter(st, rv, rng)
		st = e.state
		if e.restless != "":
			picks.append(e.restless)
	var repeat := false
	for i in range(1, picks.size()):
		repeat = repeat or picks[i] == picks[i - 1]
	_check("连进 300 次：100 次躁动、不连抽", picks.size() == 100 and not repeat, picks.size())
	# 打赢躁动的那一印
	var rs := _st({"restless": "bai", "restless_last": "bai", "set_miss": {"bai": 0}})
	_check("躁动：套装件几率翻倍", is_equal_approx(D.boss_set_chance(rs, "bai"), 0.1) and is_equal_approx(D.boss_set_chance(rs, "hong"), 0.05))
	var w := _boss(rs, {"qiyin_boss_set": [0.099], "qiyin_true_seal": [0.199]})
	_check("躁动：0.099 掉套装件", w.set_pieces.size() == 1)
	_check("躁动：真印按本档翻倍（艰险 20%）", w.set_pieces[0].true_seal)
	_check("躁动：打赢一次就平息", w.state.restless == "" and w.restless and w.state.restless_last == "bai")
	var o := _boss(rs, {"qiyin_boss_set": [0.099]}, "hong")
	_check("打别的印不平息、不翻倍", o.state.restless == "bai" and not o.restless and o.set_pieces.is_empty())
	var z := _boss(_st({"restless": "bai", "set_miss": {"bai": 20}}), {"qiyin_true_seal": [0.599]}, "bai", "zhengdao")
	_check("躁动：证道真印 30%→60%", z.set_pieces[0].true_seal)
	var lost := _boss(rs)
	_check("躁动印没掉也平息（打赢就算）", lost.state.restless == "")


func _offering() -> void:
	var off := {"kind": "shards", "part": "head"}
	_check("献印屑花 5 个", D.offering_check("bai", off) == {"ok": true, "reason": "", "shards": 5, "weapons": 0})
	_check("献印屑部位不对", not D.offering_check("bai", {"kind": "shards", "part": "ring"}).ok)
	_check("不献", D.offering_check("bai", {}).ok)
	var r := _boss(_st({"set_miss": {"bai": 20}}), {"qiyin_boss_chain": [0.0, 0.0], "qiyin_part": [0.5, 0.5]}, "bai", "jianxian",
		["head", "body"], off)
	_check("献印屑：第一件必是指定部位（已有的也能指）", r.set_pieces[0].part == "head", r.set_pieces.map(func(i): return i.part))
	_check("献印屑：只定第一件，后面照常抽", r._rng.count("qiyin_part") == 2 and r.set_pieces[1].part != "head")
	var m := _boss(_st(), {}, "bai", "jianxian", [], off)
	_check("献印屑：没掉退 3 个，另给 1 个", m.refund == 3 and m.shards == 1)
	var m2 := _boss(_st(), {}, "bai", "jianxian", [], {})
	_check("不献没掉不退", m2.refund == 0)
	var woff := {"kind": "weapon", "wtype": "暗器"}
	_check("献武器消耗 1 把", D.offering_check("bai", woff) == {"ok": true, "reason": "", "shards": 0, "weapons": 1})
	_check("献武器类型要是本印的", not D.offering_check("bai", {"kind": "weapon", "wtype": "剑"}).ok \
		and D.offering_check("mo", {"kind": "weapon", "wtype": "剑"}).ok)
	var w := _boss(_st(), {"qiyin_boss_weapon": [0.099]}, "bai", "jianxian", [], woff)
	_check("献武器：几率翻倍（艰险 10%）", not w.weapon.is_empty())
	_check("献武器：必是同类、不抽类型", w.weapon.get("wtype") == "暗器" and w._rng.count("qiyin_wtype") == 0)
	_check("献武器：边界外不掉", _boss(_st(), {"qiyin_boss_weapon": [0.101]}, "bai", "jianxian", [], woff).weapon.is_empty())
	var pw := _boss(_st({"weapon_miss": {"bai": 20}}), {}, "bai", "jianxian", [], woff)
	_check("献武器：暗保底掉的也是同类", pw.weapon.get("wtype") == "暗器")
	_check("献武器不碰套装件几率", _boss(_st(), {"qiyin_boss_set": [0.06]}, "bai", "jianxian", [], woff).set_pieces.is_empty())
	var bad := _boss(_st(), {}, "bai", "jianxian", [], {"kind": "weapon", "wtype": "剑"})
	_check("献错：报错、不抽、不改状态", bad.error.begins_with("bad_offering") and bad._rng.draws == 0 and bad.state == _st())
	_check("难度键不对报错", _boss(_st(), {}, "bai", "putong").error == "bad_difficulty")
	_check("印键不对报错", _boss(_st(), {}, "jin").error == "bad_seal")


func _first_and_field() -> void:
	var s := D.new_state()
	_check("没首通不能直取", not D.direct_allowed(s, "bai"))
	var f := D.first_clear(s, "bai", "jianxian", [], Tape.new())
	_check("首通给 1 件本印套装件", f.set_pieces.size() == 1 and f.set_pieces[0].seal == "bai" and f.state.first_clear.get("bai") == true)
	_check("首通后能直取", D.direct_allowed(f.state, "bai") and not D.direct_allowed(f.state, "hong"))
	_check("首通只给一次", D.first_clear(f.state, "bai", "jianxian", [], Tape.new()).set_pieces.is_empty())
	_check("首通也掷真印", D.first_clear(_st({"true_miss": 30}), "bai", "jianxian", [], Tape.new()).set_pieces[0].true_seal)
	var k := D.floor_first_kill(s, 31, "jianxian", {}, Tape.new())
	_check("31 层守层者首杀：白、红各 1 件", k.set_pieces.map(func(i): return i.seal) == ["bai", "hong"] and k.revealed == ["bai", "hong"])
	_check("守层者首杀只给一次", D.floor_first_kill(k.state, 31, "jianxian", {}, Tape.new()).set_pieces.is_empty())
	_check("35 层给震印", D.floor_first_kill(k.state, 35, "jianxian", {}, Tape.new()).set_pieces.map(func(i): return i.seal) == ["zhen"])
	_check("30、36 层不给", D.floor_first_kill(s, 30, "jianxian", {}, Tape.new()).set_pieces.is_empty()
		and D.floor_first_kill(s, 36, "jianxian", {}, Tape.new()).set_pieces.is_empty())
	var rv := ["bai", "hong", "hei"]
	var e := D.roll_field(s, 32, "elite", rv, {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0049], "qiyin_field_seal": [2]}))
	_check("野外精英 0.5%：掉已揭开印里随机一印", e.set_pieces.size() == 1 and e.set_pieces[0].seal == "hei")
	_check("野外精英边界外", D.roll_field(s, 32, "elite", rv, {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0051]})).set_pieces.is_empty())
	_check("野外守护者 3%", D.roll_field(s, 33, "guardian", rv, {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0299]})).set_pieces.size() == 1
		and D.roll_field(s, 33, "guardian", rv, {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0301]})).set_pieces.is_empty())
	_check("野外吃物品掉落加成", D.roll_field(s, 33, "guardian", rv, {}, "jianxian", 2.0, Tape.new({"qiyin_field": [0.059]})).set_pieces.size() == 1)
	_check("31～35 层以外野外不掉", D.roll_field(s, 30, "guardian", rv, {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0]})).set_pieces.is_empty())
	_check("没揭开的印野外不掉", D.roll_field(s, 31, "guardian", [], {}, "jianxian", 1.0, Tape.new({"qiyin_field": [0.0]})).set_pieces.is_empty())
	_check("精英印屑 33%", D.roll_elite(s, Tape.new({"qiyin_elite_shard": [0.329]})).shards == 1
		and D.roll_elite(s, Tape.new({"qiyin_elite_shard": [0.331]})).shards == 0)


func _melt_dismantle_exchange() -> void:
	var a := {"kind": "set", "seal": "bai", "part": "head", "true_seal": false}
	var b := {"kind": "set", "seal": "bai", "part": "head", "true_seal": false}
	_check("熔：同印同部位、花 3 个", D.melt_check(a, b, 3) == {"ok": true, "reason": "", "cost": 3})
	_check("熔：印屑不够", D.melt_check(a, b, 2).reason == "no_shards")
	_check("熔：部位不同", D.melt_check(a, {"kind": "set", "seal": "bai", "part": "feet", "true_seal": false}, 9).reason == "part_mismatch")
	_check("熔：印不同", D.melt_check(a, {"kind": "set", "seal": "hong", "part": "head", "true_seal": false}, 9).reason == "seal_mismatch")
	_check("熔：真印只能和真印", D.melt_check(a, {"kind": "set", "seal": "bai", "part": "head", "true_seal": true}, 9).reason == "true_mismatch"
		and D.melt_check({"kind": "set", "seal": "bai", "part": "head", "true_seal": true}, a, 9).reason == "true_mismatch")
	_check("熔：真印和真印可以", D.melt_check({"kind": "set", "seal": "bai", "part": "head", "true_seal": true},
		{"kind": "set", "seal": "bai", "part": "head", "true_seal": true}, 3).ok)
	var wa := {"kind": "weapon", "seal": "bai", "wtype": "弓弩", "true_seal": false}
	_check("熔：武器同类可以", D.melt_check(wa, wa.duplicate(), 3).ok)
	_check("熔：武器类不同", D.melt_check(wa, {"kind": "weapon", "seal": "bai", "wtype": "暗器", "true_seal": false}, 3).reason == "wtype_mismatch")
	_check("熔：套装件不能和武器", D.melt_check(a, wa, 3).reason == "kind_mismatch")
	_check("熔：不能自己熔自己", D.melt_check({"id": 7, "kind": "set", "seal": "bai", "part": "head"}, {"id": 7, "kind": "set", "seal": "bai", "part": "head"}, 3).reason == "same_item")
	_check("分解：套装件 2、武器 10", D.dismantle_value(a) == 2 and D.dismantle_value(wa) == 10)
	_check("分解：真印翻五倍", D.dismantle_value({"kind": "set", "true_seal": true}) == 10 and D.dismantle_value({"kind": "weapon", "true_seal": true}) == 50)
	_check("分解：不认识的 0", D.dismantle_value({"kind": "ring"}) == 0)
	var ex := D.exchange("set", "hong", 20, ["head"], Tape.new({"qiyin_exchange_part": [0.1]}))
	_check("兑换套装件 20 个：本印、部位照减半、不是真印", ex.ok and ex.cost == 20 and ex.item.seal == "hong" and ex.item.part == "body"
		and not ex.item.true_seal and ex.item.grades.size() == 3, ex)
	_check("兑换套装件印屑不够", D.exchange("set", "hong", 19, [], Tape.new()).reason == "no_shards")
	var ew := D.exchange("weapon", "zhen", 100, [], Tape.new({"qiyin_exchange_wtype": [1]}))
	_check("兑换武器 100 个：自选印、类型在该印里随机", ew.ok and ew.cost == 100 and ew.item.wtype == "书" and not ew.item.true_seal, ew)
	_check("兑换武器印屑不够", D.exchange("weapon", "zhen", 99, [], Tape.new()).reason == "no_shards")
	_check("兑换类型不对", not D.exchange("ring", "zhen", 999, [], Tape.new()).ok)


func _pure() -> void:
	var s := _st({"set_miss": {"bai": 20}, "weapon_miss": {"bai": 20}, "restless": "bai", "true_miss": 30})
	var before := s.duplicate(true)
	var r := _boss(s)
	D.on_enter(s, ["bai", "hong"], Tape.new())
	D.first_clear(s, "bai", "jianxian", [], Tape.new())
	D.floor_first_kill(s, 31, "jianxian", {}, Tape.new())
	_check("传进去的状态不被改", s == before and r.state != before)
	var owned := ["head"]
	_boss(_st({"set_miss": {"bai": 20}}), {"qiyin_boss_chain": [0.0]}, "bai", "jianxian", owned)
	_check("传进去的已有部位不被改", owned == ["head"])


# ---- 三、统计 ----

func _pct(sorted: Array, num: int, den: int) -> int:
	return int(sorted[floori(float(sorted.size()) * num / den)])


func _stats() -> void:
	var n := _people()
	var t0 := Time.get_ticks_msec()
	var runs_all: Array = []
	var drops := 0
	var doubles := 0
	var triples := 0
	var max_set_gap := 0
	var max_weapon_gap := 0
	var max_true_gap := 0
	var weapons := 0
	var boss_total := 0
	var items_total := 0
	var trues_total := 0
	for i in n:
		var rng := XRandomStream.create(XRandomStream.derive("7a1e2b3c5d6f7081", "person-%d" % i), "qiyin")
		var s := D.new_state()
		var owned: Array = []
		var k := D.floor_first_kill(s, 31, "jianxian", {"bai": owned}, rng)
		s = k.state
		for p in k.set_pieces:
			if p.seal == "bai":
				owned.append(p.part)
		var f := D.first_clear(s, "bai", "jianxian", owned, rng)
		s = f.state
		for p in f.set_pieces:
			owned.append(p.part)
		var runs := 0
		var set_gap := 0
		var weapon_gap := 0
		var true_gap := 0
		while _distinct(owned) < 5:
			runs += 1
			var r := D.roll_boss(s, "bai", "jianxian", owned, {}, 1.0, rng)
			s = r.state
			boss_total += 1
			var got: Array = r.set_pieces
			if got.is_empty():
				set_gap += 1
			else:
				max_set_gap = maxi(max_set_gap, set_gap)
				set_gap = 0
				drops += 1
				if got.size() >= 2:
					doubles += 1
				if got.size() >= 3:
					triples += 1
			for p in got:
				owned.append(p.part)
			var items: Array = got.duplicate()
			if r.weapon.is_empty():
				weapon_gap += 1
			else:
				max_weapon_gap = maxi(max_weapon_gap, weapon_gap)
				weapon_gap = 0
				weapons += 1
				items.append(r.weapon)
			for it in items:
				items_total += 1
				if it.true_seal:
					trues_total += 1
					max_true_gap = maxi(max_true_gap, true_gap)
					true_gap = 0
				else:
					true_gap += 1
			if runs > 500:
				break
		runs_all.append(runs)
	runs_all.sort()
	var mean := float(runs_all.reduce(func(a, b): return a + b, 0)) / n
	var p10 := _pct(runs_all, 1, 10)
	var p50 := _pct(runs_all, 1, 2)
	var p90 := _pct(runs_all, 9, 10)
	var r2 := float(doubles) / maxi(drops, 1)
	var r3 := float(triples) / maxi(drops, 1)
	var sec := (Time.get_ticks_msec() - t0) / 1000.0
	var stat := {"people": n, "mean": snappedf(mean, 0.01), "p10": p10, "median": p50, "p90": p90,
		"double_rate": snappedf(r2, 0.0001), "triple_rate": snappedf(r3, 0.0001), "boss_set_drops": drops,
		"boss_runs": boss_total, "runs_per_set_drop": snappedf(float(boss_total) / maxi(drops, 1), 0.01),
		"runs_per_weapon": snappedf(float(boss_total) / maxi(weapons, 1), 0.01), "true_rate": snappedf(float(trues_total) / maxi(items_total, 1), 0.0001),
		"max_set_gap": max_set_gap, "max_weapon_gap": max_weapon_gap, "max_true_gap": max_true_gap, "seconds": snappedf(sec, 0.1)}
	print("QIYIN_STAT=" + JSON.stringify(stat))
	_check("统计：平均 30～36 次", mean >= 30.0 and mean <= 36.0, stat)
	_check("统计：中位 27～33 次", p50 >= 27 and p50 <= 33, stat)
	_check("统计：十分位 13～19、九十分位 47～57（设计约 16、52）", p10 >= 13 and p10 <= 19 and p90 >= 47 and p90 <= 57, stat)
	_check("统计：两连约 10%（9%～11%）", r2 >= 0.09 and r2 <= 0.11, r2)
	_check("统计：三连约 1%（0.7%～1.3%）", r3 >= 0.007 and r3 <= 0.013, r3)
	_check("统计：套装件连空不超过 20 次", max_set_gap <= 20, max_set_gap)
	_check("统计：武器连空不超过 20 次", max_weapon_gap <= 20, max_weapon_gap)
	_check("统计：真印连空不超过 30 件", max_true_gap <= 30, max_true_gap)


func _distinct(owned: Array) -> int:
	var d := {}
	for p in owned:
		d[p] = true
	return d.size()
