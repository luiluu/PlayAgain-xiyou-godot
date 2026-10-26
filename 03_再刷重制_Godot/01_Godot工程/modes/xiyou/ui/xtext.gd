class_name XText
extends RefCounted
## MV 文字代码 → Godot BBCode。支持：\n<名字>（YEP 名字框）、\c[n] 颜色、\V[n] 变量、\N[n] 角色名、
## \P[n] 队员名、\G 货币、\\ 反斜杠；\| \! \. \{ \} \> \< \^ 等节奏/字号代码去掉。
## 颜色取自正式版 Window.png 的调色格（MV Window_Base.textColor）。

static var _colors: Array = []


static func color(n: int) -> Color:
	if _colors.is_empty():
		var p := XDB.img_path("system", "Window")
		var img: Image = (load(p) as Texture2D).get_image() if p != "" else null
		for i in range(32):
			if img:
				_colors.append(img.get_pixel(96 + (i % 8) * 12 + 6, 144 + floori(i / 8.0) * 12 + 6))
			else:
				_colors.append(Color.WHITE)
	return _colors[n] if n >= 0 and n < _colors.size() else Color.WHITE


## 返回 {"name": 名字框文字, "bbcode": 正文}
static func to_bb(raw: String) -> Dictionary:
	var s := raw.replace("\\\\", "\u001b")
	var name := ""
	var m := RegEx.create_from_string("\\\\n<([^>]*)>").search(s)
	if m:
		name = m.get_string(1)
		s = s.replace(m.get_string(0), "")
	var st := XState.current
	s = _sub(s, "(?i)\\\\V\\[(\\d+)\\]", func(g): return str(int(st.variable(int(g)))) if st else "0")
	s = _sub(s, "(?i)\\\\N\\[(\\d+)\\]", func(g): return XMVText._actor_name(int(g)))  # $gameActors.actor(n).name()：事件改过的名字
	s = _sub(s, "(?i)\\\\P\\[(\\d+)\\]", func(g):
		if st and int(g) >= 1 and int(g) <= st.party.size():
			return st.actor(st.party[int(g) - 1]).display_name()
		return "")
	s = s.replace("\\G", str(XDB.system().get("currencyUnit", "")))
	s = s.replace("[", "[lb]")
	var out := ""
	var open := false
	var i := 0
	var color_re := RegEx.create_from_string("(?i)^\\\\c\\[(\\d+)\\]")
	var icon_re := RegEx.create_from_string("(?i)^\\\\i\\[(\\d+)\\]")
	var any_re := RegEx.create_from_string("^\\\\(?:[|!.{}<>^$]|[A-Za-z]+\\[[^\\]]*\\]|[A-Za-z]+<[^>]*>)?")
	while i < s.length():
		var rest := s.substr(i)
		var cm := color_re.search(rest)
		if cm:
			if open:
				out += "[/color]"
				open = false
			var n := int(cm.get_string(1))
			if n != 0:
				out += "[color=#%s]" % color(n).to_html(false)
				open = true
			i += cm.get_string(0).length()
			continue
		if icon_re.search(rest):
			i += icon_re.search(rest).get_string(0).length()
			continue
		if rest.begins_with("\\"):
			var am := any_re.search(rest)
			i += maxi(1, am.get_string(0).length() if am else 1)
			continue
		out += s[i]
		i += 1
	if open:
		out += "[/color]"
	return {"name": name, "bbcode": out.replace("\u001b", "\\")}


static func plain(raw: String) -> String:
	var r := RegEx.create_from_string("\\[[^\\]]*\\]")
	return r.sub(to_bb(raw).bbcode.replace("[lb]", "["), "", true)


static func _sub(s: String, pattern: String, fn: Callable) -> String:
	var re := RegEx.create_from_string(pattern)
	var m := re.search(s)
	while m:
		var rep: String = fn.call(m.get_string(1))
		s = s.substr(0, m.get_start()) + rep + s.substr(m.get_end())
		m = re.search(s, m.get_start() + rep.length())
	return s
