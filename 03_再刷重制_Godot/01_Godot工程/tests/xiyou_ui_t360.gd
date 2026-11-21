extends Node
## T360 专项：属性分色（D250 只数值着色、冒号统一、攻击/暴击避开警示橙红）、战技不能用的原因（F-16）、副标题省略号（F-10）。
var results := []


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	var base := Color("a8aaaf")
	var r := XSkinTemplatePage.with_stat_spans({"text": "攻击:+12", "color": base})
	_check("stat_colon_unified", str(r.text) == "攻击：+12", r.text)
	var sp: Array = r.spans
	_check("stat_name_base_color", sp.size() == 3 and sp[0][1] == base and sp[1][1] == base, sp)
	_check("stat_value_colored", sp.size() == 3 and sp[2][1] != base and str(sp[2][0]) == "+12", sp)
	var joined := ""
	for s in sp:
		joined += str(s[0])
	_check("stat_spans_join_text", joined == r.text, joined)
	var r2 := XSkinTemplatePage.with_stat_spans({"text": "暴击+5%  生命：100", "color": base})
	_check("stat_no_colon_form", str(r2.spans[0][0]) == "暴击" and r2.spans[0][1] == base and str(r2.spans[1][0]) == "+5%", r2.spans)
	_check("stat_attack_crit_avoid_warn", _hue_far(XSkinTemplatePage.stat_color("攻击"), XUiSkin.DOWN) and _hue_far(XSkinTemplatePage.stat_color("暴击"), XUiSkin.SEL_LINE), "")
	_check("stat_desaturated", XSkinTemplatePage.stat_color("生命").s < 0.4 and XSkinTemplatePage.stat_color("攻击").s < 0.4, "")
	var f := XUiSkin.font("body")
	var fit := XSkinList.fit_text(f, "白印 · 七印套装 · 真印 · 神话（神话特效很长很长很长很长很长很长）", 120.0, 15, 15)
	_check("subtitle_ellipsis", str(fit[0]).ends_with("…"), fit[0])
	_check("reason_no_repeat_fallback", XSkinBattle.reason(null, null, {}, false) != "现在不能用", "")
	var passed := 0
	for x in results:
		if x.passed:
			passed += 1
		else:
			printerr("FAIL ", x.name, " ", x.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _hue_far(a: Color, b: Color) -> bool:
	return a.s < 0.4 or absf(a.h - b.h) > 0.04
