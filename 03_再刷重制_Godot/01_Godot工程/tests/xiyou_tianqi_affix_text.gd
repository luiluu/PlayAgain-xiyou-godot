extends Node
## 天启篇词条的玩家文字（XTianqiAffixText＋tianqi_data/affix_text.json，来源：天启篇词条重构设计稿 v0.3）。
## 只验文字和格式化，不接装备界面：和 03_转换工具/天启篇数据校验.py 的 affix_text 检查验同一套内容。
## 一、表头、51 条键和 affix_table 一一对应、标记与颜色键；二、全部词条×能出的阶×三种成色×变体都填得上，
## 不剩花括号、没有 null／nan，不含数字 4，负号用全角；三、词条行（不算标记）不超过 16 个汉字；
## 四、抽查设计稿数值和行的样子；五、文字表本身不含数字 4。不需要转换产物。

const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
const X := preload("res://modes/xiyou/core/tianqi_affix_text.gd")
const LINE_MAX_HAN := 16

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _han(s: String) -> int:
	var n := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x4e00 and c <= 0x9fff:
			n += 1
	return n


func _extras(a: Dictionary) -> Array:
	var out := [{}]
	if bool(a.get("random_element", false)):
		for e in T.data().get("elements", []):
			out.append({"element": str(e.key)})
	for v in a.get("variants", []):
		out.append({"variant": str(v.key)})
	return out


func _ici_ids() -> Array:
	var src := FileAccess.get_file_as_string("res://modes/xiyou/core/quality.gd")
	var m := RegEx.create_from_string("const ICI_COLORS := \\{([^}]*)\\}").search(src)
	var out := []
	if m:
		for k in RegEx.create_from_string("(\\d+):").search_all(m.get_string(1)):
			out.append(int(k.get_string(1)))
	return out


func _run() -> void:
	T.reload()
	X.reload()
	var d := X.data()
	var td := T.data()
	_check("能读文字表", not d.is_empty())

	# 一、表头、键、标记与颜色
	for h in ["version", "source", "dev"]:
		_check("表头 " + h, str(d.get(h, "")) != "", d.get(h))
	var keys: Array = d.get("affixes", []).map(func(e): return str(e.get("key", "")))
	var want: Array = td.get("affixes", []).map(func(a): return str(a.key))
	_check("文字条数 51", keys.size() == 51, keys.size())
	var dup := keys.filter(func(k): return keys.count(k) > 1)
	_check("文字键不重复", dup.is_empty(), dup)
	var missing := want.filter(func(k): return not (k in keys))
	var extra := keys.filter(func(k): return not (k in want))
	_check("文字键和词条总表一一对应", missing.is_empty() and extra.is_empty(), {"缺": missing, "多": extra})
	var empty: Array = d.get("affixes", []).filter(func(e): return str(e.get("line", "")) == "" or str(e.get("detail", "")) == "")
	_check("每条都有词条行和说明", empty.is_empty(), empty)
	_check("四层都有名字", td.get("layers", []).all(func(l): return str(d.get("layers", {}).get(str(l.key), {}).get("name", "")) != ""))
	var gr: Dictionary = d.get("grades", {})
	_check("三种成色都有", gr.has("normal") and gr.has("fine") and gr.has("perfect") and gr.size() == 3, gr.keys())
	_check("普通不标，上品和极各有标记", str(gr.normal.get("mark", "x")) == "" and str(gr.fine.get("mark", "")) != ""
		and str(gr.perfect.get("mark", "")) != "")
	_check("稀有有标记", str(d.get("rare", {}).get("mark", "")) != "")
	_check("光环前缀含「全队」", "全队" in str(d.get("aura_prefix", "")), d.get("aura_prefix"))
	var ici := _ici_ids()
	var colors := []
	for v in d.get("layers", {}).values():
		colors.append(v.get("color"))
	for v in gr.values():
		for k in ["color", "line_color"]:
			if v.get(k) != null:
				colors.append(v.get(k))
	colors.append(d.get("rare", {}).get("color"))
	_check("颜色键都是 XQuality.ICI_COLORS 里现成的编号", not ici.is_empty() and colors.all(func(c): return c != null and int(c) in ici), colors)
	var stacks := {}
	for a in td.get("affixes", []):
		stacks[str(a.stack)] = true
	_check("每种叠法都有说明", stacks.keys().all(func(s): return d.get("stack_text", {}).has(s)), stacks.keys())

	# 二、三：全部组合都填得上、行不超长
	var bad_fill := []
	var digit4 := []
	var minus := []
	var too_long := []
	var unavailable := []
	var ascii_minus := RegEx.create_from_string("-\\d")
	for a in td.get("affixes", []):
		var k := str(a.key)
		for tier in range(1, 5):
			if T.value(k, tier, "normal") == null:
				if X.line(k, tier, "normal") != "" or X.detail(k, tier, "normal") != "":
					unavailable.append([k, tier])
				continue
			for g in T.GRADES:
				for ex in _extras(a):
					var tag := "%s/%d/%s/%s" % [k, tier, g, ex]
					for s in [X.line(k, tier, g, ex), X.detail(k, tier, g, ex)]:
						var low := str(s).to_lower()
						if s == "" or "{" in s or "}" in s or "null" in low or "nan" in low:
							bad_fill.append([tag, s])
						if "4" in s:
							digit4.append([tag, s])
						if ascii_minus.search(s):
							minus.append([tag, s])
					var b := X.body(k, tier, g, ex)
					if _han(b) > LINE_MAX_HAN:
						too_long.append([tag, _han(b), b])
	_check("不能出的阶返回空", unavailable.is_empty(), unavailable)
	_check("模板都填得上（不剩花括号、没有 null／nan）", bad_fill.is_empty(), bad_fill.slice(0, 5))
	_check("填好的文字不含数字 4", digit4.is_empty(), digit4.slice(0, 5))
	_check("负号用全角「−」", minus.is_empty(), minus.slice(0, 5))
	_check("词条行不超过 %d 个汉字" % LINE_MAX_HAN, too_long.is_empty(), too_long.slice(0, 5))

	# 四、抽查（设计稿 v0.3 与 Kyo 11-11 01:21 整数版）
	for c in [
		["物攻四阶极", X.line("atk", 4, "perfect"), "极·物攻 +8%"],
		["终伤四阶上品", X.line("final_damage", 4, "fine"), "〔四阶·上品〕最终伤害 +12%"],
		["再动四阶极", X.line("reaction", 4, "perfect"), "极·〔稀有〕每回合有 20% 几率多行动一次"],
		["全能光环四阶极", X.line("aura_versatile", 4, "perfect"), "极·全队·八项属性 +6%"],
		["连击", X.line("combo", 4, "perfect"), "〔稀有〕攻击次数 +1"],
		["暴怒四阶普通", X.line("aura_fury", 4, "normal"), "全队·暴击率 +3%，暴击伤害 +6%"],
		["火焰增伤四阶极", X.line("element_damage", 4, "perfect", {"element": "fire"}), "极·火焰伤害 +22%"],
		["避敌四阶普通", X.line("target_rate", 4, "normal", {"variant": "avoid"}), "避敌：被选为目标的几率 −10%"],
		["物攻一阶普通", X.line("atk", 1, "normal"), "物攻 +1%"],
	]:
		_check("抽查 " + c[0], c[1] == c[2], [c[1], c[2]])
	_check("技能消耗写出 −50% 上限", "−50%" in X.detail("skill_cost", 4, "perfect"), X.detail("skill_cost", 4, "perfect"))
	_check("吸血写出单次不超过最大生命 10%", "不超过自己最大生命的 10%" in X.detail("lifesteal", 4, "perfect"))
	var ex_d := X.detail("expose", 4, "normal")
	_check("破绽写出持续 2 回合、同一目标只有一层", "持续 2 回合" in ex_d and "只有一层" in ex_d, ex_d)
	_check("光环说明写出同名全队只生效最高", "同名光环全队只生效数值最高的一条" in X.detail("aura_guard", 2, "normal"))
	var er := X.detail("element_resist", 3, "fine")
	_check("元素说明写全九系", td.get("elements", []).all(func(e): return str(e.name) in er), er)
	_check("连击说明不写阶和成色", X.detail("combo", 4, "perfect").split("\n")[0] == "传说词条", X.detail("combo", 4, "perfect"))
	var seg := X.segments("reaction", 4, "perfect")
	_check("富文本分段：极、稀有、正文各一段，正文金色", seg.size() == 3 and int(seg[2].color) == int(gr.perfect.line_color)
		and int(seg[1].color) == int(d.rare.color), seg)
	_check("普通传说词条正文用传说层颜色", X.line_color("expose", "normal") == int(d.layers.legendary.color))

	# 五、文字表本身不含数字 4
	var raw := FileAccess.get_file_as_string(X.DATA)
	_check("文字表本身不含数字 4", not ("4" in raw))

	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
