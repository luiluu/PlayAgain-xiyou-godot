extends Node
## 【cc·八戒·未经审查】成长装备说明（growth3）XGrowthHelp：照参照 growth_help_probe（tests/fixtures/growth_help_oracle.json）逐行比。
## 尾项三（DL ③）：心钢技能说明卡（skills，XGrowthHelp.skill_view）同样逐行比。
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
	# HELP_FIX 开：比照原版行（参照 rows）再加本场成长／当前增益行（插在「成长：」行前，后插的在前）；
	# 外层包装加的行（装备战力一行、元素／穿透行）另核：v0.43 版式把它们挪到属性块之后，不按原位置比
	var lk := "\\lock[1]" if XHelpCard.LAYOUT_V043 else ""
	var outer := func(x) -> bool: return str(x).contains("装备战力：") or str(x).contains("穿透")
	var base := _texts(c.rows).filter(func(x): return not outer.call(x))
	var extra := []
	if pend:
		extra.append(lk + "本场成长：%s＋%d层，胜利后保存" % ["心钢" if heart else "盛名", pend])
	if c.buff != null:
		extra.append(lk + "当前增益：扬名使物理攻击×%s；剩余%d个完整回合%s" % [XGrowthHelp.number(float(c.buff.rate)), int(c.buff.remaining), "（本回合不计）" if c.buff.sameRound else ""])
	# v0.43 版式每行带 \lock[1]，找「成长：」行时去掉再比；找不到记失败，不越界
	var grow := base.filter(func(x): return str(x).trim_prefix("\\lock[1]").begins_with("成长："))
	check("fix." + str(c.id) + ".growth_row", not grow.is_empty(), base)
	var at := base.find(grow[0]) if not grow.is_empty() else 0
	var want := base.duplicate()
	for x in extra:  # APs 同位置后插的在前：增益行在待结算行前
		want.insert(at, x)
	var power_rows := t.filter(func(x): return str(x).contains("装备战力："))
	check("fix." + str(c.id) + ".power_row", power_rows.size() == (1 if XPower.enabled() else 0), power_rows)
	t = t.filter(func(x): return not outer.call(x))
	check("fix." + str(c.id), t == want, {"got": t, "want": want})
	XHeartsteel._ledger.clear()
	XHubris._ledger.clear()
	XHubris._buff.clear()
	XHubris._logic = null
	XHeartsteel.in_battle = false
	if c.buff != null:
		XEquipment.change(s, a, a.equip_slots().find(int(obj.etypeId)), null)


## 尾项三：心钢技能说明卡 H.skillHelpView（XGrowthHelp.skill_view）。参照 skills：装上的心钢／利维坦、战斗中的回合与就绪回合、施放过没有
func _skill(c: Dictionary, s: XState) -> void:
	var a: XActor = s.actor(1)
	var obj := {}
	if c.gear != null:
		obj = XDB.rec("Armors", int(c.gear.base)).duplicate(true)
		obj.kind = "armor"
		obj.base = int(c.gear.base)
		obj.id = 9100 + int(c.gear.base)
		for k in c.gear.fields:
			obj[k] = c.gear.fields[k]
		s.gear.append(obj)
		XEquipment.change(s, a, a.equip_slots().find(int(obj.etypeId)), obj)
	var logic := FakeLogic.new()
	logic.state = s
	if c.battle != null:
		XHeartsteel.in_battle = true
		XHeartsteel._logic_ref = weakref(logic)
		logic.turn = int(c.battle.turn)
		if c.battle.has("ready"):
			XHeartsteel._ready_turn[a.actor_id] = int(c.battle.ready)
		XHeartsteel._casted[a.actor_id] = bool(c.battle.get("casted", false))
	var view := XGrowthHelp.skill_view(XDB.rec("Skills", int(c.skill)), null if c.noActor else a)
	var got := XHelpCard.content(view)
	var want: Array = c.rows
	var tag := "skill." + str(c.id).trim_prefix("skill.")
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(view), func(t: String, sz: int): return t.length() * sz * 0.6)
	var ok := got.size() == want.size()
	var bad = null
	for i in range(mini(got.size(), want.size())):
		var g: Array = got[i]
		var w: Array = want[i]
		if not (str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) \
				and (null if g[4] == null else int(g[4])) == (null if w[4] == null else int(w[4])) and is_equal_approx(float(lay.lines[i].y), float(w[3]))):
			ok = false
			bad = {"row": i, "got": [g[0], g[1], g[2], g[4], lay.lines[i].y], "want": w}
			break
	check(tag, ok, bad if bad != null else {"got": _texts(got), "want": _texts(want)})
	check(tag + ".height", is_equal_approx(float(lay.height), float(c.height)), [lay.height, c.height])
	XHeartsteel.in_battle = false
	XHeartsteel._logic_ref = null
	XHeartsteel._ready_turn.clear()
	XHeartsteel._casted.clear()
	if not obj.is_empty():
		XEquipment.change(s, a, a.equip_slots().find(int(obj.etypeId)), null)


func _ready() -> void:
	XPower.SHOW_POWER_UI = true  # 战力先藏（默认关）：本专项测战力显示，开着才与藏之前逐字一致
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for c in data.cases:
		_faithful(c, _obj(c))
		_power(c, _obj(c))
		_fixed(c, _obj(c), s)
	for c in data.get("skills", []):
		_skill(c, s)
	check("skill.count", data.get("skills", []).size() >= 11)
	# 回退：TURN_CD_V035 关（v0.28）＝没有这张卡，原样返回
	XHeartsteel.TURN_CD_V035 = false
	var raw := XDB.rec("Skills", XHeartsteel.SKILL)
	check("skill.v028", is_same(XGrowthHelp.skill_view(raw, s.actor(1)), raw))
	XHeartsteel.TURN_CD_V035 = true
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
