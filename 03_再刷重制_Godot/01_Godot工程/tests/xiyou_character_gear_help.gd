extends Node
## 【cc·悟空·未经审查】专属装备说明卡（chars-gaps1）：照 character_gear_help_probe（tests/fixtures/character_gear_help_oracle.json，v0.62.12）
## 逐行比文字、字号、颜色、对齐、y 与卡高：
## - characterHelpTarget 认的专属装备（4001 武器／防具、4577～4581、7904～7911、7920～7935）走 XCharacterHelp.view（分组上色）；
## - 饿狼 G.describeRelic：破限之心说明卡加十行（XGarou.relic_help_lines 接在 XHelpCard.desc_params 备注行之后），另比一个独立实例
##   （7906、garouStage 2、5 级、经验 12）。
## 「装备战力：」行开着显示（XPower.SHOW_POWER_UI）比在不在，数值不比（战力先藏、重构前不对数）。
const FIXTURE := "res://tests/fixtures/character_gear_help_oracle.json"
const POWER_PREFIX := "装备战力："
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func _texts(rows: Array) -> Array:
	return rows.map(func(r): return str(r[0]))


func _is_power(r: Array) -> bool:
	return str(r[0]).replace("\\lock[1]", "").begins_with(POWER_PREFIX)


## 去掉战力行（和它留下的连续空行）
func _no_power(rows: Array) -> Array:
	var out := []
	for r in rows:
		if _is_power(r):
			continue
		if str(r[0]) == " " and (out.is_empty() or str(out.back()[0]) == " "):
			continue
		out.append(r)
	return out


func _card(tag: String, obj: Dictionary, c: Dictionary) -> void:
	var got := XHelpCard.content(obj)
	var want: Array = c.rows
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(obj), func(t: String, sz: int): return t.length() * sz * 0.6)
	var ys: Array = lay.lines.map(func(l): return float(l.y))
	var with_y := got.any(_is_power) == want.any(_is_power)
	if not with_y:
		# 战力行有无不同（破限之心原版没有这一行；战力先藏、重构前不对）：两边都去掉再比，不比 y 与卡高
		got = _no_power(got)
		want = _no_power(want)
	var ok := got.size() == want.size()
	var bad = null
	for i in range(mini(got.size(), want.size())):
		var g: Array = got[i]
		var w: Array = want[i]
		var same_text := str(g[0]) == str(w[0]) or (_is_power(g) and _is_power(w))
		if not (same_text and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) \
				and (null if g[4] == null else int(g[4])) == (null if w[4] == null else int(w[4])) and (not with_y or is_equal_approx(float(ys[i]), float(w[3])))):
			ok = false
			bad = {"row": i, "got": [g[0], g[1], g[2], g[4], ys[i] if with_y else null], "want": w}
			break
	check(tag, ok, bad if bad != null else {"got": _texts(got), "want": _texts(want)})
	if with_y:
		check(tag + ".height", is_equal_approx(float(lay.height), float(c.height)), [lay.height, c.height])


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	XPower.SHOW_POWER_UI = true
	XConfig.path_override = "user://xiyou_character_gear_help_none.json"  # 不读本机设置（正式默认：战力开）
	check("template.count", data.templates.size() == 30, data.templates.size())
	for c in data.templates:
		var rec := XDB.rec("Weapons" if str(c.kind) == "weapon" else "Armors", int(c.id))
		check("target.%s%d" % [c.kind, int(c.id)], XCharacterHelp.target(rec))
		_card("template.%s%d" % [c.kind, int(c.id)], rec, c)
	var o: Dictionary = data.instance
	var inst: Dictionary = XDB.rec("Armors", int(o.base)).duplicate(true)
	inst.kind = "armor"
	inst.base = float(o.base)
	inst.level = float(o.level)
	inst.exp = float(o.exp)
	inst.garouStage = int(o.stage)
	inst.garouOwner = XGarou.ACTOR
	_card("instance", inst, o)
	# 画两次不叠：原版先删旧块再写；重制不写备注
	check("again", _no_power(XHelpCard.content(inst)).size() == int(data.againRows), [_no_power(XHelpCard.content(inst)).size(), data.againRows])
	var raw := XDB.rec("Armors", XGarou.RELICS[0])
	XHelpCard.content(raw)
	check("db_untouched", not str(raw.get("note", "")).contains("法宝形态"))
	# 别的防具不加、不算专属装备
	check("other_none", XGarou.relic_help_lines(XDB.rec("Armors", 12)).is_empty() and not XCharacterHelp.target(XDB.rec("Armors", 12)))
	# 形态字段坏了按模板号
	var odd := inst.duplicate(true)
	odd.garouStage = 9
	check("bad_stage_falls_back", str(XGarou.relic_help_lines(odd).back()).contains("法宝形态:半怪人"), XGarou.relic_help_lines(odd))
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_character_gear_help", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
