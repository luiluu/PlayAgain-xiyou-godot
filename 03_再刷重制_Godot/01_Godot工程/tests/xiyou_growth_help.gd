extends Node
## 【cc·八戒·未经审查】成长装备说明（growth3）XGrowthHelp：照参照 growth_help_probe（tests/fixtures/growth_help_oracle.json）逐行比。
## 每例拿参照实例刚建好时的备注 note0／说明 description0，加层数／盛名字段，HELP_FIX 关（原版口径）走 XHelpCard.content，
## 文字、字号、颜色、对齐、行 y 与卡高同 xiyou_help_card；装备评分（总分、逐行）比参照 power；再开 HELP_FIX（O-151，默认）看「本场成长」「当前增益」「装备战力」三行。
const FIXTURE := "res://tests/fixtures/growth_help_oracle.json"
const POWER_PREFIX := "装备战力："
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


class FakeLogic extends RefCounted:
	var state: XState
	var turn := 2


func _obj(c: Dictionary) -> Dictionary:
	var base := XDB.rec("Armors", int(c.base))
	var meta: Dictionary = base.get("meta", {}).duplicate()
	meta.quality = str(int(c.quality))
	var o := {"kind": "armor", "base": int(c.base), "id": 9000 + int(c.base), "etypeId": int(base.get("etypeId", 0)), "atypeId": int(base.get("atypeId", 0)), "name": c.name,
		"note": c.note0, "description": c.description0, "params": c.params, "price": c.price, "traits": c.traits, "meta": meta, "yep": {}}
	for k in c.fields:
		o[k] = c.fields[k]
	return o


func _texts(rows: Array) -> Array:
	return rows.map(func(r): return str(r[0]))


func _faithful(c: Dictionary, obj: Dictionary) -> void:
	XGrowthHelp.HELP_FIX = false
	var got := XHelpCard.content(obj, "armor")
	var want: Array = c.rows
	var tag := "oracle." + str(c.id)
	if got.size() != want.size():
		check(tag, false, {"got": _texts(got), "want": _texts(want)})
		return
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(obj), func(t: String, s: int): return t.length() * s * 0.6)
	for i in want.size():
		var g: Array = got[i]
		var w: Array = want[i]
		var ok: bool = str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) \
			and (null if g[4] == null else int(g[4])) == (null if w[4] == null else int(w[4])) and is_equal_approx(float(lay.lines[i].y), float(w[3]))
		if not ok:
			check(tag, false, {"row": i, "got": [g[0], g[1], g[2], g[4], lay.lines[i].y], "want": w})
			return
	check(tag, is_equal_approx(float(lay.height), float(c.height)), [lay.height, c.height])
	check(tag + ".desc", str(XGrowthHelp.view(obj).description) == str(c.description), [XGrowthHelp.view(obj).description, c.description])


## 装备评分：成长装备按阶加成（XPower._growth_gear）
func _power(c: Dictionary, obj: Dictionary) -> void:
	var p := XPower.equipment(obj)
	var got: Array = p.rows.map(func(r): return [r.label, r.parts])
	var want: Array = c.power.rows.map(func(r): return [r.label, r.parts])
	var ok: bool = int(p.total) == int(c.power.total) and got.size() == want.size()
	for i in range(mini(got.size(), want.size())):
		ok = ok and got[i][0] == want[i][0]
		for k in 3:
			ok = ok and absf(float(got[i][1][k]) - float(want[i][1][k])) < 1e-6 * maxf(1.0, absf(float(want[i][1][k])))
	check("power." + str(c.id), ok, {"got": [p.total, got], "want": [c.power.total, want]})


## HELP_FIX 开：原件比，待结算与增益两行出现在成长行前（APs 后插的在前），战力行在名字后
func _fixed(c: Dictionary, obj: Dictionary, s: XState) -> void:
	XGrowthHelp.HELP_FIX = true
	var heart := XHeartsteel.is_gear(obj)
	var pend := int(c.pending)
	if pend:
		(XHeartsteel._ledger if heart else XHubris._ledger).append({"item": obj, "gain": pend})
	var logic := FakeLogic.new()
	logic.state = s
	var a: XActor = s.actor(1)
	if c.buff != null:
		s.gear.append(obj)
		XEquipment.change(s, a, a.equip_slots().find(int(obj.etypeId)), obj)
		XHeartsteel.in_battle = true
		XHubris._logic = weakref(logic)
		XHubris._buff[a.actor_id] = {"item": obj, "rate": float(c.buff.rate), "round": 2 if c.buff.sameRound else 1, "remaining": int(c.buff.remaining)}
	var t := _texts(XHelpCard.content(obj, "armor"))
	var base := _texts(c.rows)
	var extra := []
	if pend:
		extra.append("本场成长：%s＋%d层，胜利后保存" % ["心钢" if heart else "盛名", pend])
	if c.buff != null:
		extra.append("当前增益：扬名使物理攻击×%s；剩余%d个完整回合%s" % [XGrowthHelp.number(float(c.buff.rate)), int(c.buff.remaining), "（本回合不计）" if c.buff.sameRound else ""])
	var at := base.find(base.filter(func(x): return x.begins_with("成长："))[0])
	var want := base.duplicate()
	for x in extra:  # APs 同位置后插的在前：增益行在待结算行前
		want.insert(at, x)
	if XPower.enabled():
		want.insert(1, t[1] if t.size() > 1 and str(t[1]).begins_with(POWER_PREFIX) else POWER_PREFIX + "?")
	check("fix." + str(c.id), t == want, {"got": t, "want": want})
	XHeartsteel._ledger.clear()
	XHubris._ledger.clear()
	XHubris._buff.clear()
	XHubris._logic = null
	XHeartsteel.in_battle = false
	if c.buff != null:
		XEquipment.change(s, a, a.equip_slots().find(int(obj.etypeId)), {})


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for c in data.cases:
		_faithful(c, _obj(c))
		_power(c, _obj(c))
		_fixed(c, _obj(c), s)
	# 渡鸦／米拉／甚尔专属法宝的装备评分（XPower._exclusive_gear）
	for c in data.powerOnly:
		_power({"id": c.id, "power": c}, XDB.rec("Armors", int(c.id)))
	# helpNumber：浮点误差抹掉、整数不带小数点
	check("number", XGrowthHelp.number(1.0) == "1" and XGrowthHelp.number(1.1 + 0.2) == "1.3" and XGrowthHelp.number(1.2000004) == "1.2")
	# 旧版说明开头换回数据库说明
	var old := {"base": XHeartsteel.LEVIATHAN, "description": "神武\n奥恩杰作。13层旧说明\n第二行", "note": ""}
	XGrowthHelp.describe(old)
	check("describe.legacy", old.description == str(XDB.rec("Armors", XHeartsteel.LEVIATHAN).description) + "\n第二行", old.description)
	XGrowthHelp.HELP_FIX = true
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_growth_help", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
