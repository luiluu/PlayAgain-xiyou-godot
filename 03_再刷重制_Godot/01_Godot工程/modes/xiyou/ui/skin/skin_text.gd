class_name XSkinText
extends RefCounted
## 新界面段落折行共用件（T338 界面细节 D2，私密仓 重制设定/界面细节规范_v0.1.md 规范 7）：
## 中文避头尾（行首不出标点、行尾不留开括号）＋防单字孤行回拉＋英文／数字串不腰斩。
## 返回字符索引区间，所以普通纯文本与按 spans 分色的多色行（XSkinCard._span_line）都能直接用。
## 回退：XUiSkin.DETAIL_V1 = false → 走改造前的 TextParagraph（不传语言、默认折行标志），逐像素同旧。

const NO_START := "，。、！？；：）》】」』”’·…—～％%.,!?;:)]}"
const NO_END := "（《【「『“‘([{#"
const BREAK_FLAGS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
## 行尾允许挂出的标点宽度（× 字号）
const HANG_K := 0.35
## 防孤字回拉后，倒数第二行至少还要剩多宽（× 行宽），宁可留孤字也不造半行空洞
const WIDOW_FILL_K := 0.52
## 每行不足这么多个字宽时（窄列）跳过防孤字，避免死循环
const NARROW_CHARS := 4.0


## 把 text（可含 \n，每个 \n 另起一行）按宽度 max_w 拆行，返回 [起, 止) 字符区间
static func wrap_ranges(text: String, font: Font, fs: int, max_w: float, prevent_widow := true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if text == "" or max_w <= 0.0 or not XUiSkin.detail_on():   # 空串、宽度无效也交给 TextParagraph，行数同旧
		return _legacy_ranges(text, font, fs, max_w)
	var base := 0
	for seg in text.split("\n"):
		out.append_array(_wrap_segment(seg, base, font, fs, max_w, prevent_widow))
		base += seg.length() + 1
	return out


static func line_count(text: String, font: Font, fs: int, max_w: float) -> int:
	return wrap_ranges(text, font, fs, max_w).size()


## 同 wrap_ranges，直接返回每行文字（不含换行符）
static func wrap_lines(text: String, font: Font, fs: int, max_w: float, prevent_widow := true) -> Array:
	var out := []
	for rg in wrap_ranges(text, font, fs, max_w, prevent_widow):
		out.append(text.substr(rg.x, rg.y - rg.x))
	return out


static func _legacy_ranges(text: String, font: Font, fs: int, max_w: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tp := TextParagraph.new()
	tp.width = max_w
	tp.add_string(text, font, fs)
	for i in tp.get_line_count():
		out.append(Vector2i(tp.get_line_range(i)))
	return out


static func _width(seg: String, a: int, b: int, font: Font, fs: int) -> float:
	var s := seg.substr(a, b - a).rstrip(" \t　")
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


static func _is_alnum(c: String) -> bool:
	var u := c.unicode_at(0)
	return (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122)


static func _is_digit(c: String) -> bool:
	var u := c.unicode_at(0)
	return u >= 48 and u <= 57


## 位置 i（第 i 个字之前）是不是落在一个英文／数字整体里：Lv12、TP、+120%、4,567、3.5
static func _in_token(seg: String, i: int) -> bool:
	if i <= 0 or i >= seg.length():
		return false
	var a := seg[i - 1]
	var b := seg[i]
	if _is_alnum(a) and (_is_alnum(b) or b == "%"):
		return true
	if (a == "+" or a == "-") and _is_digit(b):
		return true
	if _is_alnum(a) and b == "-" and i + 1 < seg.length() and _is_alnum(seg[i + 1]):
		return true
	if a == "-" and _is_alnum(b) and i >= 2 and _is_alnum(seg[i - 2]):
		return true
	if (a == "." or a == ",") and _is_digit(b) and i >= 2 and _is_digit(seg[i - 2]):
		return true
	if _is_digit(a) and (b == "." or b == ",") and i + 1 < seg.length() and _is_digit(seg[i + 1]):
		return true
	return false


static func _token_start(seg: String, i: int) -> int:
	while _in_token(seg, i):
		i -= 1
	return i


static func _token_end(seg: String, i: int) -> int:
	while _in_token(seg, i):
		i += 1
	return i


## 单段（无 \n）：自己按像素宽贪心折行（可断点只落在合规位置），再防孤字回拉。cuts＝第 2 行起每行的起点
## 为什么不用 TextParagraph 的 ICU 折行：它不让我们控制「行尾挂出」，避头尾靠系统 locale，且长西文会被劈断（实测 Final-|Strike）
static func _wrap_segment(seg: String, base: int, font: Font, fs: int, max_w: float, prevent_widow: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if seg == "":
		out.append(Vector2i(base, base))
		return out
	var n := seg.length()
	var cuts: Array[int] = []
	var start := 0
	while start < n:
		var e := _fit_end(seg, start, font, fs, max_w)
		if e >= n:
			break
		cuts.append(e)
		start = e
	if prevent_widow and not cuts.is_empty():
		_fix_widow(seg, cuts, font, fs, max_w)
	start = 0
	for c in cuts:
		out.append(Vector2i(base + start, base + c))
		start = c
	out.append(Vector2i(base + start, base + n))
	return out


## 一个切点是否合规：行首不是避头字（含空格）、行尾不是避尾字、不在英文数字串中间
static func _cut_ok(seg: String, at: int) -> bool:
	return not NO_START.contains(seg[at]) and seg[at] != " " and not NO_END.contains(seg[at - 1]) and not _in_token(seg, at)


## 这一行（从 start 起）该在哪一位截断：塞得下的最远处→行首标点挂出→退到合规切点
static func _fit_end(seg: String, start: int, font: Font, fs: int, max_w: float) -> int:
	var n := seg.length()
	if _width(seg, start, n, font, fs) <= max_w:
		return n
	var lo := start + 1
	var hi := n
	while lo < hi:   # 最大的 e 使 width(start, e) <= max_w（至少 1 个字）
		var mid := (lo + hi + 1) / 2
		if _width(seg, start, mid, font, fs) <= max_w:
			lo = mid
		else:
			hi = mid - 1
	var fit := lo
	var e := fit
	while e < n and seg[e] == " ":
		e += 1
	while e < n and NO_START.contains(seg[e]) and _width(seg, start, e + 1, font, fs) <= max_w + HANG_K * fs:
		e += 1
		while e < n and seg[e] == " ":
			e += 1
	if e >= n:
		return n
	while e > start + 1 and not _cut_ok(seg, e):
		e -= 1
	if e <= start + 1 and not _cut_ok(seg, e):   # 退无可退（整串比一行还宽）：硬切在塞得下的位置
		e = maxi(fit, start + 1)
	return e


static func _eff_chars(s: String) -> int:
	var n := 0
	for ch in s:
		if ch.strip_edges() != "" and ch != "　" and not NO_START.contains(ch):
			n += 1
	return n


static func _fix_widow(seg: String, cuts: Array[int], font: Font, fs: int, max_w: float) -> void:
	if max_w < NARROW_CHARS * fs:
		return
	var last := cuts.size() - 1
	var s := cuts[last]
	if _eff_chars(seg.substr(s)) > 1:
		return
	var prev_start := 0 if last == 0 else cuts[last - 1]
	# 要拉的最小语义单元：1 个字，或整串英文／数字；紧挨避尾标点就连它一起
	var p := s
	while p > prev_start + 1 and seg[p - 1] == " ":
		p -= 1
	var u := _token_start(seg, p - 1) if _in_token(seg, p - 1) else p - 1
	while u > prev_start and (NO_START.contains(seg[u]) or NO_END.contains(seg[u - 1])):
		u -= 1
	if u <= prev_start:
		return
	if _eff_chars(seg.substr(prev_start, u - prev_start)) < 2:
		return
	if not _cut_ok(seg, u):
		return
	if _width(seg, prev_start, u, font, fs) < max_w * WIDOW_FILL_K:
		return
	if _width(seg, u, seg.length(), font, fs) > max_w:
		return
	cuts[last] = u
