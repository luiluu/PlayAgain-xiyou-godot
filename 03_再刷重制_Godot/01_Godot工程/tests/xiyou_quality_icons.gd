extends Node
## 超出 IconSet 网格的图标（XQualityIcons）对照 tests/fixtures/quality_icons_oracle.json（mv_oracle/quality_icons_probe.cjs，原版 CodexQualityIcons.lookup 的结果）。
## 再扫全库：每条技能、物品、武器、防具、状态的 iconIndex 都取得到图（图标号在 IconSet 网格之外又没人管会显示空白）。
const FIXTURE := "res://tests/fixtures/quality_icons_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


func _shape(i: Dictionary) -> Dictionary:
	if i.has("hd"):
		return {"image": i.image, "source": i.hd}
	if i.has("strip"):
		return {"image": i.image, "source": i.strip}
	var out := {"image": i.get("image", "IconSet"), "source": i.get("source", -1)}
	if i.has("item"):
		out.color = XQuality.color_text(i.item).replace(" ", "")
	return out


func _run() -> void:
	XState.current = XState.new_game_blank()
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var c: Dictionary = ref.cases[0]
	check("oracle", (c.errors as Array).is_empty(), c.errors)
	var rows: Dictionary = c.observed.rows
	check("oracle_rows", rows.size() == 73, rows.size())
	var bad := []
	for k in rows:
		var want: Dictionary = rows[k]
		var got := _shape(XQualityIcons.info(int(k)))
		var w := {"image": want.image, "source": int(want.source)}
		if want.has("color"):
			w.color = str(want.color).replace(" ", "")
		if str(got) != str(w):
			bad.append([k, got, w])
	check("lookup", bad.is_empty(), bad.slice(0, 8))
	var blank := []
	for t in ["Skills", "Items", "Weapons", "Armors", "States"]:
		for rec in XDB.table(t):
			if rec is Dictionary and int(rec.get("iconIndex", 0)) > 0 and str(rec.get("name", "")) != "":
				var tex := XUI.icon_texture(int(rec.iconIndex))
				if tex == null or tex.atlas == null:
					blank.append([t, rec.id, rec.name, rec.iconIndex])
	check("no_blank", blank.is_empty(), blank.slice(0, 20))
	# 染色：有笔画；5789 画圈
	var img: Image = XQualityIcons.icon_texture(130225).atlas.get_image()
	check("skill_tint_has_pixels", not img.is_invisible())
	var ring: Image = XQualityIcons._skill_image({"item": XDB.rec("Skills", 10225), "source": 5789})
	check("ring", ring.get_pixel(16, 6).a > 0.5 and ring.get_pixel(16, 16).a == 0.0, ring.get_pixel(16, 6))
	check("hd_size", XQualityIcons.icon_texture(130229).region.size == Vector2(32, 32) and XQualityIcons.icon_texture(130229, 128).atlas.get_width() == 128)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"name": "xiyou_quality_icons", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
