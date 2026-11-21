extends Node
## 【cc·T338·未经审查】界面细节 D2 段落折行（私密仓 重制设定/界面细节规范_v0.1.md 规范 7、卡 D2）：
## 10 组中文／混排边界，每组在一串行宽里扫过，断言：零孤字、零行首避头标点、零行尾开括号、零英文数字腰斩、零越界（挂出不超 0.35 字号）、
## 区间连续覆盖原文；DETAIL_V1＝false 逐行同旧 TextParagraph。再用旧折行（不传 zh_CN、默认标志）证明断言咬得住。
##   godot --headless --audio-driver Dummy --path <工程> res://tests/xiyou_skin_text.tscn
const NO_START := XSkinText.NO_START
const NO_END := XSkinText.NO_END
const FS := 18

var results: Array = []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	var f := XUiSkin.font("body")
	# 每组：[名, 文本, 要整体保留的串, 行宽扫描（字数）起, 止]
	var cases := [
		["g1_widow_period", "这件装备会在战斗开始时为持有者附带一层护盾，并在第三回合结束时造成额外伤害。", [], 9, 22],
		["g2_kinsoku_head", "他说：“你好吗？”然后离开了。你呢？我去了、看了、听了；还是回来了！", [], 6, 20],
		["g3_kinsoku_tail", "请注意「危险」区域，另有《天启》与【印纹】之说（见下）以及“传闻”。", [], 7, 20],
		["g4_latin_percent", "攻击力提升 +120% 并获得 Lv12 技能，TP 回复 4,567 点，持续 3 层 2 回合。", ["+120%", "Lv12", "TP", "4,567"], 7, 20],
		["g5_narrow_guard", "魔法攻击力提升，持续两回合。", [], 2.5, 4.5],
		["g6_spans", "自带：暴击率 +15%，暴击伤害 +40%，穿透 8%。", ["+15%", "+40%"], 6, 18],
		["g7_digits", "共计造成 123456789 点伤害，并恢复 3.5% 生命。", ["123456789", "3.5%"], 6, 18],
		["g8_ellipsis", "魔法攻击力提升了很多很多很多很多很多……真的。", [], 6, 20],
		["g9_newlines", "第一段说明文字比较长一些，需要折行才行。\n第二段也很长，并且以句号结尾。\n\n短。", [], 6, 20],
		["g10_ascii_long", "Reach Lv99 to unlock Skill: Final-Strike, 效果 +30% 持续 5 回合。", ["Lv99", "Final-Strike", "+30%"], 7, 22],
	]
	var legacy_bad := 0
	var new_bad := 0
	for c in cases:
		var r := _sweep(f, c)
		check(c[0] + "_zero_violations", r.new == 0, r)
		legacy_bad += int(r.legacy)
		new_bad += int(r.new)
	check("legacy_would_violate_somewhere", legacy_bad > 0, legacy_bad)   # 证明断言咬得住
	check("new_total_zero", new_bad == 0, new_bad)
	_narrow_terminates(f)
	_spans_cover(f)
	_switch_off(f)
	XUiSkin.FORCE = false
	XUiSkin.DETAIL_V1 = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _legacy(text: String, f: Font, max_w: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tp := TextParagraph.new()
	tp.width = max_w
	tp.add_string(text, f, FS)
	for i in tp.get_line_count():
		out.append(Vector2i(tp.get_line_range(i)))
	return out


func _eff(s: String) -> int:
	var n := 0
	for ch in s:
		if ch.strip_edges() != "" and ch != "　" and not NO_START.contains(ch):
			n += 1
	return n


## 一组扫描：返回 {legacy: 旧折行违例数, new: 新折行违例数, first: 第一个违例的说明}
func _sweep(f: Font, c: Array) -> Dictionary:
	var text: String = c[1]
	var res := {"legacy": 0, "new": 0, "first": ""}
	var w_chars := float(c[3])
	while w_chars <= float(c[4]) + 0.001:
		var max_w := w_chars * FS
		res.legacy += _violations(text, _legacy(text, f, max_w), f, max_w, c[2], false).size()
		var errs := _violations(text, XSkinText.wrap_ranges(text, f, FS, max_w), f, max_w, c[2], true)
		res.new += errs.size()
		if not errs.is_empty() and res.first == "":
			var dump := []
			for rg in XSkinText.wrap_ranges(text, f, FS, max_w):
				dump.append(text.substr(rg.x, rg.y - rg.x))
			res.first = "w=%s %s %s" % [w_chars, errs[0], "|".join(PackedStringArray(dump))]
		w_chars += 0.5
	return res


func _violations(text: String, ranges: Array, f: Font, max_w: float, keep: Array, strict_cover: bool) -> Array:
	var errs := []
	var narrow := max_w < XSkinText.NARROW_CHARS * FS
	if strict_cover:
		var pos := 0
		for rg in ranges:
			var skip := 1 if pos < text.length() and text[pos] == "\n" and rg.x == pos + 1 else 0
			if rg.x != pos + skip and not (rg.x == pos and rg.y >= rg.x):
				errs.append("覆盖不连续 %s≠%s" % [rg.x, pos])
				break
			pos = rg.y
		if pos != text.length():
			errs.append("没覆盖到末尾 %d/%d" % [pos, text.length()])
	var lines: Array = []
	for rg in ranges:
		lines.append(text.substr(rg.x, rg.y - rg.x))
	# 以段为单位判（\n 切开）：段内行
	var k := 0
	var seg_lines: Array = []
	for rg in ranges:
		var s := text.substr(rg.x, rg.y - rg.x).rstrip("\n")
		seg_lines.append([rg.x, s])
	for i in seg_lines.size():
		var s: String = seg_lines[i][1]
		var st := s.strip_edges()
		if st == "":
			continue
		if NO_START.contains(st[0]):
			errs.append("行首避头 %s" % st)
		if NO_END.contains(st[st.length() - 1]):
			errs.append("行尾开括号 %s" % st)
		var wpx := f.get_string_size(s.rstrip(" "), HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		if wpx > max_w + XSkinText.HANG_K * FS + 0.5 and s.length() > 1:
			errs.append("越界 %.1f>%.1f %s" % [wpx, max_w, s])
		# 孤字：同一段的末行（下一行起点前是 \n 或已到末尾）且段内行数 ≥ 2
		var end_of_seg: bool = (i == seg_lines.size() - 1) or text[ranges[i].y - 1 + 0] == "\n" or (ranges[i].y < text.length() and text[ranges[i].y] == "\n")
		if end_of_seg and i > 0 and not narrow:
			var prev_end: int = ranges[i - 1].y
			var same_seg: bool = prev_end == ranges[i].x and not (prev_end > 0 and text[prev_end - 1] == "\n")
			if same_seg and _eff(s) <= 1:
				errs.append("末行孤字 %s" % st)
	# 英文数字串不腰斩
	for token in keep:
		var from := 0
		while true:
			var idx := text.find(token, from)
			if idx < 0:
				break
			for rg in ranges:
				if rg.x > idx and rg.x < idx + token.length():
					errs.append("腰斩 %s" % token)
			from = idx + token.length()
	return errs


# ---- 超窄列：不死循环、覆盖全文、不丢字 ----
func _narrow_terminates(f: Font) -> void:
	var text := "魔法攻击力提升，持续两回合。ABCDEFGHIJ"
	for w in [FS * 1.0, FS * 1.5, FS * 2.0, FS * 3.0]:
		var rs := XSkinText.wrap_ranges(text, f, FS, float(w))
		var joined := ""
		for rg in rs:
			joined += text.substr(rg.x, rg.y - rg.x)
		check("narrow_covers_%d" % int(w), joined == text and not rs.is_empty(), [w, rs.size(), joined])


# ---- 多色 spans：按区间切，拼回去等于每行原文 ----
func _spans_cover(f: Font) -> void:
	var text := "自带：暴击率 +15%，暴击伤害 +40%，穿透 8%。"
	var spans := [["自带：", Color.WHITE], ["暴击率 +15%，", Color.RED], ["暴击伤害 +40%，穿透 8%。", Color.GREEN]]
	var ok := true
	for chars in [6.0, 8.0, 10.0, 14.0]:
		for rg in XSkinText.wrap_ranges(text, f, FS, chars * FS):
			var off := 0
			var got := ""
			for sp in spans:
				var s := str(sp[0])
				var a := maxi(rg.x, off)
				var b := mini(rg.y, off + s.length())
				if b > a:
					got += s.substr(a - off, b - a)
				off += s.length()
			if got != text.substr(rg.x, rg.y - rg.x):
				ok = false
	check("spans_pieces_equal_line", ok)


# ---- DETAIL_V1 关：逐行同旧 TextParagraph ----
func _switch_off(f: Font) -> void:
	XUiSkin.DETAIL_V1 = false
	var same := true
	for t in ["这件装备会在战斗开始时为持有者附带一层护盾，并在第三回合结束时造成额外伤害。", "A+B 123%\n第二段。", ""]:
		for chars in [6.0, 10.0, 20.0]:
			var a := XSkinText.wrap_ranges(t, f, FS, chars * FS)
			var b := _legacy(t, f, chars * FS)
			if a != b:
				same = false
	check("detail_off_same_as_legacy", same)
	XUiSkin.DETAIL_V1 = true
