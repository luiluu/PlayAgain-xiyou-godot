class_name MVScript
extends RefCounted
## 事件脚本（MV 指令 355/655 的 JavaScript）的翻译：不执行 JS，只认正式版里出现过的写法，按语义改成 Godot 版操作。
## 认不出的语句原样记进解释器的 skipped，便于之后逐条补齐。目前认得：
## - 所有角色学会/忘记技能的循环（$dataActors.length 带或不带名字检查、j < 999、按 ID 列表 forEach、列表外的角色）→ XState.add_actor_op；
##   `$gameActors.length+1` 的循环（length 未定义，原版一次也不执行）→ 无操作。
## - 固定存档位存档：$gamePlayer.SaveGameId = N; DataManager.saveGame(...) 成功/失败分支（音效与提示）。
## - $gamePlayer.SaveActorName = prompt(提示, 默认) → 输入名字窗口。
## - $.toaster({message: '...'}) → 右上角提示；$gameParty.gainItem($dataItems[$gameVariables.value(N)], n) 与对应的提示。
## - $gameParty.DCultyL1～8 等标记、ConfigManager 界面选项（无对应设置，忽略）、$gameSystem.onBeforeSave()（无操作）、
##   Star_RomGetItems 的 RomGet 预掷池初始化。

const _NAMED := "\\$dataActors\\[j\\]\\.name\\s*!==?\\s*['\"]{2}"


## 执行一段脚本；返回认不出的语句（空数组表示全部认得）。
static func run(code: String, interp) -> Array:
	var js := _strip_comments(code).strip_edges()
	if js == "":
		return []
	var s := XState.current
	# ---- 整段写法 ----
	var loop := _actor_loop(js)
	if not loop.is_empty():
		for op in loop:
			s.add_actor_op(op)
		return []
	if js.contains("$gameActors.length+1") or js.contains("$gameActors.length + 1"):
		return []
	if js.contains("$gameParty.RomGet") and js.contains("Math.random"):
		if s.rom.get("g", []).size() < 35:
			var pool := []
			for i in range(35):
				pool.append(randi_range(1, 9999))
			s.rom.g = pool
			s.rom.gn = 0
		return []
	var unknown := []
	# 存档分支：if (DataManager.saveGame($gamePlayer.SaveGameId)) { …成功… } else { …失败… }
	var at := js.find("DataManager.saveGame(")
	if at >= 0:
		var if_at := js.rfind("if", at)
		var ok_block := _block(js, js.find("{", at))
		var end: int = ok_block[1]
		var fail := ""
		var tail := js.substr(end).strip_edges()
		if tail.begins_with("else"):
			var fail_block := _block(js, js.find("{", end))
			fail = fail_block[0]
			end = fail_block[1]
		unknown.append_array(await _statements(js.substr(0, if_at), interp))
		var ok: bool = interp.host.save_game(int(s.flags.get("SaveGameId", 0)))
		XSound.system(5 if ok else 3)
		var msg := _toaster_text(ok_block[0] if ok else fail)
		if msg != "":
			interp.host.toast(msg)
		unknown.append_array(await _statements(js.substr(end), interp))
		return unknown
	return await _statements(js, interp)


## 逐条处理简单语句（分号或换行分隔）
static func _statements(js: String, interp) -> Array:
	var s := XState.current
	var unknown := []
	for raw in js.replace("\n", ";").split(";"):
		var st := raw.strip_edges()
		if st == "" or st == "}" or st == "{":
			continue
		var m := RegEx.create_from_string("^\\$gameParty\\.(DCultyL\\d+)\\s*=\\s*(true|false)$").search(st)
		if m:
			s.flags[m.get_string(1)] = m.get_string(2) == "true"
			continue
		m = RegEx.create_from_string("^\\$gamePlayer\\.SaveGameId\\s*=\\s*(\\d+)$").search(st)
		if m:
			s.flags["SaveGameId"] = int(m.get_string(1))
			continue
		m = RegEx.create_from_string("^ConfigManager\\.MapXy\\s*=\\s*(true|false)$").search(st)
		if m:
			XConfig.set_map_xy(m.get_string(1) == "true")
			continue
		if RegEx.create_from_string("^ConfigManager\\.\\w+\\s*=\\s*\\w+$").search(st) or st == "$gameSystem.onBeforeSave()":
			continue
		m = RegEx.create_from_string("^\\$gamePlayer\\.SaveActorName\\s*=\\s*prompt\\(\\s*\"([^\"]*)\"\\s*,\\s*\"([^\"]*)\"\\s*\\)$").search(st)
		if m:
			s.actor_name = await interp.host.input_text(m.get_string(1), m.get_string(2))
			continue
		m = RegEx.create_from_string("^\\$gameParty\\.gainItem\\(\\$dataItems\\[\\$gameVariables\\.value\\((\\d+)\\)\\]\\s*,\\s*(\\d+)").search(st)
		if m:
			s.gain_item(int(s.variable(int(m.get_string(1)))), int(m.get_string(2)))
			continue
		if st.begins_with("$.toaster"):
			var text := _toaster_text(st)
			if text != "":
				interp.host.toast(text)
			else:
				unknown.append(st)
			continue
		unknown.append(st)
	return unknown


## $.toaster({ message : '…' })：字面文字；'获得了：'+$dataItems[$gameVariables.value(N)].name+'！' 这种拼接也认
static func _toaster_text(js: String) -> String:
	var m := RegEx.create_from_string("\\$\\.toaster\\(\\s*\\{\\s*message\\s*:\\s*(.*?)\\s*\\}\\s*\\)").search(js)
	if m == null:
		return ""
	var out := ""
	for part in m.get_string(1).split("+"):
		var p := part.strip_edges()
		var lit := RegEx.create_from_string("^['\"](.*)['\"]$").search(p)
		if lit:
			out += lit.get_string(1)
			continue
		var item := RegEx.create_from_string("^\\$dataItems\\[\\$gameVariables\\.value\\((\\d+)\\)\\]\\.name$").search(p)
		if item:
			out += str(XDB.rec("Items", int(XState.current.variable(int(item.get_string(1))))).get("name", ""))
			continue
		return ""
	return out


## 「所有角色学会/忘记技能」的几种循环写法 → actor_op 列表；认不出返回空
static func _actor_loop(js: String) -> Array:
	var flat := js.replace("\n", " ")
	# 按 ID 列表：var ids = [..]; ids.forEach(function(actorId){ …forgetSkill(A); learnSkill(B); }); 以及列表外有名字的角色 learnSkill(C)
	var list := RegEx.create_from_string("var\\s+(\\w+)\\s*=\\s*\\[([\\d,\\s]*)\\]").search(flat)
	if list and flat.contains(list.get_string(1) + ".forEach"):
		var name := list.get_string(1)
		var ids := Array(list.get_string(2).split(",", false)).map(func(v): return int(v.strip_edges()))
		var ops := []
		var each := RegEx.create_from_string(name + "\\.forEach\\(function\\s*\\(\\w+\\)\\s*\\{(.*?)\\}\\s*\\)").search(flat)
		if each == null:
			return []
		for call in RegEx.create_from_string("(forgetSkill|learnSkill)\\((\\d+)\\)").search_all(each.get_string(1)):
			ops.append({"op": "forget" if call.get_string(1) == "forgetSkill" else "learn", "skill": int(call.get_string(2)), "ids": ids, "exclude": [], "named": false})
		var rest := flat.substr(each.get_end())
		if rest.contains("!" + name + ".includes"):
			var others := RegEx.create_from_string("learnSkill\\((\\d+)\\)").search(rest)
			if others:
				ops.append({"op": "learn", "skill": int(others.get_string(1)), "ids": [], "exclude": ids, "named": RegEx.create_from_string(_NAMED).search(rest) != null})
		return ops
	# for (var j = 1; j < $dataActors.length 或 999; j++) { [if (名字非空)] …actor(j)…learnSkill(N) / forgetSkill(N) }
	var head := RegEx.create_from_string("^for\\s*\\(\\s*(?:var|let)\\s+j\\s*=\\s*1\\s*;\\s*j\\s*<\\s*(\\$dataActors\\.length|999)\\s*;\\s*j\\+\\+\\s*\\)\\s*\\{(.*)\\}$").search(flat.strip_edges().trim_prefix("var j = $gameParty._targetActorId;").strip_edges())
	if head == null:
		return []
	var body := head.get_string(2)
	var calls := RegEx.create_from_string("(forgetSkill|learnSkill)\\((\\d+)\\)").search_all(body)
	if calls.is_empty() or RegEx.create_from_string("\\b(if|else)\\b").search(body.replace("if($dataActors[j].name != '')", "").replace("if ($dataActors[j].name != '')", "")):
		return []
	var named := RegEx.create_from_string(_NAMED).search(body) != null
	var out := []
	for call in calls:
		out.append({"op": "forget" if call.get_string(1) == "forgetSkill" else "learn", "skill": int(call.get_string(2)), "ids": [], "exclude": [], "named": named})
	return out


## from 处是「{」：返回 [括号里的内容, 右括号之后的位置]
static func _block(js: String, from: int) -> Array:
	var depth := 0
	for i in range(from, js.length()):
		if js[i] == "{":
			depth += 1
		elif js[i] == "}":
			depth -= 1
			if depth == 0:
				return [js.substr(from + 1, i - from - 1), i + 1]
	return [js.substr(from + 1), js.length()]


## 去掉 // 行注释（引号里的 // 不算，如提示文字里的网址）
static func _strip_comments(code: String) -> String:
	var out := []
	for line in code.split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "'" or ch == "\"":
				quote = ch
			elif ch == "/" and i + 1 < line.length() and line[i + 1] == "/":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)
