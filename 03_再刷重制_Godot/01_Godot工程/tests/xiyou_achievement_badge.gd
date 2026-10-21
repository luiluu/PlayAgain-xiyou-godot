extends Node
## 成就 142「本质高手」／143「kyo专属」专用徽章与特殊样式：对照 mv_oracle achievement_badge_probe（generated/oracle/achievement_badges.json）
## 里列表行与弹窗的 canvas 级绘制调用（徽章目标位置／尺寸／透明度、渐变停点与 baseline、描边与阴影参数、上下 1px 线、窗宽与窗口不透明度）。
## 渐变字在 Godot 里用中间色近似，参数逐项对照，画面不比像素。
var results: Array = []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _r(v) -> float:
	return snappedf(float(v), 0.000001)


func _ops(c: Dictionary, op: String) -> Array:
	return Array(c.canvas).filter(func(x): return x.get("op", "") == op)


func _sets(c: Dictionary, key: String) -> Array:
	return Array(c.canvas).filter(func(x): return x.get("set", "") == key).map(func(x): return x.value)


func _image(c: Dictionary) -> Dictionary:
	var m := _ops(c, "drawImage")
	return m[0] if not m.is_empty() else {}


func _same_image(img: Dictionary, op: Dictionary) -> bool:
	var a: Array = img.args
	return not img.is_empty() and _r(a[5]) == _r(op.x) and _r(a[6]) == _r(op.y) and _r(a[7]) == _r(op.w) and _r(a[8]) == _r(op.h) and _r(img.alpha) == _r(op.alpha) \
		and int(a[3]) == 256 and int(a[4]) == 256


## 渐变描边字：渐变区间与停点、baseline、描边与阴影参数、字号
func _same_name(c: Dictionary, p: Dictionary, size: int) -> bool:
	var g := _ops(c, "createLinearGradient")
	var t := _ops(c, "fillText").filter(func(x): return x.args[0] == XAchievementBadge.NAME)
	var s := _ops(c, "strokeText").filter(func(x): return x.args[0] == XAchievementBadge.NAME)
	if g.size() != 1 or t.size() != 1 or s.size() != 1:
		return false
	var stops: Array = g[0].stops
	var want: Array = p.stops
	if stops.size() != want.size():
		return false
	for i in range(stops.size()):
		if _r(stops[i][0]) != _r(want[i][0]) or str(stops[i][1]) != str(want[i][1]):
			return false
	var fonts := _sets(c, "font").filter(func(f): return str(f).begins_with("%dpx" % size))
	return _r(g[0].args[1]) == _r(p.gradientFrom) and _r(g[0].args[3]) == _r(p.gradientTo) \
		and _r(t[0].args[1]) == _r(p.x) and _r(t[0].args[2]) == _r(p.baseline) and _r(s[0].args[2]) == _r(p.baseline) \
		and _sets(c, "lineWidth").has(float(p.lineWidth)) and _sets(c, "strokeStyle").has(p.stroke) \
		and _sets(c, "shadowColor").has(p.shadow) and _sets(c, "shadowBlur").has(float(p.shadowBlur)) and not fonts.is_empty()


func _run() -> void:
	var ref = XDB.load_json("oracle/achievement_badges.json")
	var manifest: Dictionary = XDB.load_json("manifest.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("files", XAchievementBadge.file_of(240201) == "EssenceMaster" and XAchievementBadge.file_of(240202) == "KYO" and XAchievementBadge.file_of(1) == "")
	check("defs_icons", int(XAchievement.def(142).icon) == 240201 and int(XAchievement.def(143).icon) == 240202)
	# 徽章 PNG 随切片导出并能加载为 256² 贴图
	for f in ["EssenceMaster", "KYO"]:
		var bp := XDB.img_path("codex_achievements", f)
		var tex = load(bp) if bp != "" else null
		check("png.%s" % f, tex is Texture2D and tex.get_width() == 256 and tex.get_height() == 256, bp)
	for c in ref.cases:
		var id := int(c.ach)
		var name := str(c.id)
		if c.kind == "list":
			var y := float(c.rect.y)
			var owned: bool = c.owned
			check(name + ".row_height", float(c.rect.height) == XAchievementScene.LIST_LH and float(c.rect.width) == 920.0 and float(c.lineHeight) == XAchievementScene.LIST_LH)
			var plan := XAchievementBadge.list_plan(id, y, float(c.rect.height), owned)
			if id == 143:
				check(name + ".only_badge", not plan.is_empty() and plan.only_badge and Array(c.calls).is_empty(), [plan, c.calls])
				check(name + ".badge", _same_image(_image(c), plan.badge), [_image(c), plan.badge])
				check(name + ".alpha", _r(plan.badge.alpha) == (1.0 if owned else _r(80.0 / 255.0)), plan.badge.alpha)
			elif owned:
				check(name + ".badge", _same_image(_image(c), plan.badge), [_image(c), plan.badge])
				check(name + ".badge_not_shifted", float(plan.badge.x) == 6.0 and float(plan.badge.y) == y)
				check(name + ".name", _same_name(c, plan.name, 26), plan.name)
				# 其余仍是普通行：触发文字、已获得、完成于
				var texts := Array(c.calls).filter(func(x): return x.f != "icon").map(func(x): return str(x.t))
				check(name + ".rest_texts", texts.size() == 3 and texts[1] == "已获得" and str(texts[2]).begins_with("完成于"), texts)
			else:
				var t := Array(c.calls).filter(func(x): return x.f == "text").map(func(x): return str(x.t))
				check(name + ".locked_plain", plan.is_empty() and t == ["未获得"], [plan, t])
		else:
			var d := XAchievement.def(id)
			var pp := XAchievementBadge.popup_plan(id, 300.0, 50.0)
			check(name + ".window", float(c.window.width) == float(pp.width) and float(c.window.height) == 50.0 and int(c.window.opacity) == (0 if id == 143 else 255)
				and int(pp.opacity) == (0 if id == 143 else -1), [c.window, pp])
			var imgs: Array = pp.ops.filter(func(o): return o.op == "drawImage")
			check(name + ".badge", imgs.size() == 1 and _same_image(_image(c), imgs[0]), [_image(c), imgs])
			if id == 143:
				check(name + ".bare", c.canvas.size() == 1 and not pp.message and not pp.title, c.canvas)
			else:
				var names: Array = pp.ops.filter(func(o): return o.op == "gradientText")
				check(name + ".title", names.size() == 1 and _same_name(c, names[0], 20), names)
				var rects := _ops(c, "fillRect")
				var want: Array = pp.after
				check(name + ".lines", rects.size() == 2 and _r(rects[0].args[3]) == 1.0 and _r(rects[1].args[1]) == 49.0 and want.size() == 2 and want[0].color == "#b391d5" and want[1].color == "#c7a261"
					and _sets(c, "fillStyle").has("#b391d5") and _sets(c, "fillStyle").has("#c7a261"), [rects, want])
				check(name + ".message_kept", pp.message and _ops(c, "fillText").any(func(x): return str(x.args[0]) == str(XAchievementPopup.settings().get("Popup Message", ""))))
			check(name + ".icon_id", int(d.icon) == int(Array(c.calls).filter(func(x): return x.f == "icon")[0].id) if id == 142 else true)
	# 实际弹窗节点：143 窄窗、窗口不透明度 0、居中位置用实际窗宽；142 照常 300 宽
	var scene := Node2D.new()
	get_tree().root.add_child(scene)
	for id in [142, 143]:
		var pop := XAchievementPopup.new()
		pop.item = XAchievement.def(id)
		scene.add_child(pop)
		await get_tree().process_frame
		pop._apply(1.0)
		check("node.%d.size" % id, pop.size.x == (64.0 if id == 143 else 300.0) and pop.size.y == 50.0, pop.size)
		check("node.%d.opacity" % id, pop.win.opacity == (0 if id == 143 else 255), pop.win.opacity)
		pop.queue_free()
	scene.queue_free()
	finish()


func _ready() -> void:
	_run.call_deferred()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
