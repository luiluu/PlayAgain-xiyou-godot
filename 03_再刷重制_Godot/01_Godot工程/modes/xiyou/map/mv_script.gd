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
## - v0.27 轮回入口（installReincarnationRandomRuntime）：CodexReincarnationRandom.open(this) → 选「轮回普通／困难」再选阵容规则；
##   条件 entryAccepted()／entryHard() 读选择结果；finishEntry() 无操作。随机角色模式暂不开放（O-035），菜单只列「常规阵容」。
## - 副本 Boss 奖励（CE1439）：CodexEconomy.bossReward、CodexOrbs.rollInt、CodexV010Fixes.rewardNotice／awardQuantity、
##   甚尔／宿傩 rollAdvanceStone（见 XDungeon）；洪荒的 grantTicketBonus／rollPower 在非洪荒难度无操作。

const _NAMED := "\\$dataActors\\[j\\]\\.name\\s*!==?\\s*['\"]{2}"
## CodexReincarnationRandom.entry：open 之后的选择结果 {accepted, hard}
static var reincarnation_entry := {}


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
				pool.append(MVInterpreter.random_int(1, 9999))
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
		# ---- 副本 Boss 胜利奖励（CE1439 肝帝积分券里的 Codex 脚本，见 XDungeon） ----
		if st == "if(window.CodexEconomy)CodexEconomy.bossReward()":
			for t in XDungeon.boss_reward(s):
				interp.host.toast(t)
			continue
		# 洪荒（难度 8）的诅咒加成券与不朽之力：其他难度不做任何事
		if st in ["if(window.CodexHonghuang)CodexHonghuang.grantTicketBonus()", "if(window.CodexHonghuang)CodexHonghuang.rollPower()"] and s.difficulty != 8:
			continue
		m = RegEx.create_from_string("^\\$gameVariables\\.setValue\\((\\d+),window\\.CodexOrbs&&CodexOrbs\\.rollInt\\?CodexOrbs\\.rollInt\\('(\\w+)',(\\d+),(\\d+)\\):1\\+Math\\.randomInt\\(\\d+\\)\\)$").search(st)
		if m:
			s.set_variable(int(m.get_string(1)), XOrbs.roll_int(s, m.get_string(2), int(m.get_string(3)), int(m.get_string(4))))
			continue
		# CodexV010Fixes.rewardNotice(this, '前'+CodexV010Fixes.awardQuantity(this,'种类',ID,默认)+'后')：宝箱里不提示；数量取本解释器最近一次实际所得
		m = RegEx.create_from_string("^CodexV010Fixes\\.rewardNotice\\(this,\\s*'([^']*)'\\s*\\+\\s*CodexV010Fixes\\.awardQuantity\\(this,'(\\w+)',(\\d+),(\\d+)\\)\\s*\\+\\s*'([^']*)'\\)$").search(st)
		if m:
			if interp.receipt == null:
				var g: Dictionary = interp.last_gain
				var qty := int(g.amount) if str(g.get("kind", "")) == m.get_string(2) and int(g.get("id", -1)) == int(m.get_string(3)) else int(m.get_string(4))
				interp.host.toast(m.get_string(1) + str(qty) + m.get_string(5))
			continue
		m = RegEx.create_from_string("^\\$gameVariables\\.setValue\\((\\d+),window\\.CodexMijing\\?CodexMijing\\.pickHere\\(\\):(\\d+)\\)$").search(st)
		if m:
			s.set_variable(int(m.get_string(1)), XDungeon.mijing_pick_here(s))
			continue
		if st == "CodexToji.rollAdvanceStone()" or st == "CodexSukuna.rollAdvanceStone()":
			var got := XDungeon.roll_advance_stone(s, XDungeon.TOJI if st.begins_with("CodexToji") else XDungeon.SUKUNA)
			if got != "":
				interp.host.toast(got)
			continue
		if st == "CodexGuide.advise(this)":
			await _guide_advise(interp)  # 方桌大厅「商店向导」→「下一步建议」
			continue
		if st == "CodexZhenqi.retreat(this)":
			await XZhenqiRetreat.run(interp.host)  # 方桌大厅「闭关」NPC
			continue
		if st == "CodexReincarnationRandom.open(this)":
			await _reincarnation_open(interp)
			continue
		if st == "CodexReincarnationRandom.finishEntry()":
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


## CodexGuide.advise：interp.setupChild 插入建议文字（每段一页），显示完回到原事件
static func _guide_advise(interp) -> void:
	var sub := MVInterpreter.new(interp.host, interp.map_id, interp.event_id, XGuide.page_list(XGuide.advice_texts(XState.current)), interp._depth + 1)
	sub.pending_lines = interp.pending_lines
	await sub.run()
	interp.skipped.append_array(sub.skipped)


## CodexReincarnationRandom.open（Scene_ReincarnationDraft）：本局已开启轮回（开关 2307／2303）时提示后关闭；
## 否则先选难度（轮回普通／轮回困难／返回），再选阵容规则（常规阵容／返回：回到难度）。随机角色（9 选 5）暂不开放（O-035）。
static func _reincarnation_open(interp) -> void:
	var s := XState.current
	reincarnation_entry = {"accepted": false, "hard": false}
	if s.switch(2307) or s.switch(2303):
		interp.host.toast("本局轮回已经开启，阵容规则不能中途更换。")
		return
	while true:
		var d: int = await interp.host.show_text_with_choices("", 0, ["选择轮回难度，再选择阵容规则。"], ["轮回普通", "轮回困难", "返回"], 2)
		if d < 0 or d == 2:
			return
		var m: int = await interp.host.show_text_with_choices("", 0, ["请选择本局阵容规则。"], ["常规阵容", "返回"], 1)
		if m == 0:
			reincarnation_entry = {"accepted": true, "hard": d == 1}
			return


## $.toaster({ message : '…' })：字面文字与下列部分用 + 拼接（引号里的 + 不算）：
## $dataItems[$gameVariables.value(N)].name、$gameVariables.value(N)（JS 数字写法）
static func _toaster_text(js: String) -> String:
	var m := RegEx.create_from_string("\\$\\.toaster\\(\\s*\\{\\s*message\\s*:\\s*(.*?)\\s*\\}\\s*\\)").search(js)
	if m == null:
		return ""
	var out := ""
	for part in _concat_parts(m.get_string(1)):
		var p := str(part).strip_edges()
		var lit := RegEx.create_from_string("^['\"](.*)['\"]$").search(p)
		if lit:
			out += lit.get_string(1)
			continue
		var item := RegEx.create_from_string("^\\$dataItems\\[\\$gameVariables\\.value\\((\\d+)\\)\\]\\.name$").search(p)
		if item:
			out += str(XDB.rec("Items", int(XState.current.variable(int(item.get_string(1))))).get("name", ""))
			continue
		var v := RegEx.create_from_string("^\\$gameVariables\\.value\\((\\d+)\\)$").search(p)
		if v:
			out += js_number(XState.current.variable(int(v.get_string(1))))
			continue
		return ""
	return out


## 按引号外的 + 切开字符串拼接表达式
static func _concat_parts(expr: String) -> Array:
	var parts := []
	var cur := ""
	var quote := ""
	for ch in expr:
		if quote != "":
			cur += ch
			if ch == quote:
				quote = ""
		elif ch == "'" or ch == "\"":
			quote = ch
			cur += ch
		elif ch == "+":
			parts.append(cur)
			cur = ""
		else:
			cur += ch
	parts.append(cur)
	return parts


## JS 数字转字符串（整数不带小数点）
static func js_number(v: float) -> String:
	return "%d" % int(v) if v == floorf(v) and absf(v) < 9.0e18 else str(v)


## 只认白名单的简单 JS 表达式（事件条件 111 脚本、变量操作数 122 脚本）：数字、+ - * / ( )、比较、&& || !，
## 以及 $gameVariables.value(N)、$gameSwitches.value(N)、$gameSystem.playtime()、$gameParty.gold()/steps()/size()、
## $gameMap.mapId()、$gameParty.numItems($dataItems[N])、Math.floor/ceil/max/min/abs。认不出返回 null（调用方记进 skipped）。
static func eval_expr(js: String) -> Variant:
	var e := js.strip_edges()
	while e.ends_with(";"):
		e = e.left(-1).strip_edges()
	if e == "" or e.contains("%") or e.contains("=>") or e.contains("\"") or e.contains("'"):
		return null
	var subs := [["$gameVariables.value(", "v("], ["$gameSwitches.value(", "sw("], ["$gameSystem.playtime()", "playtime()"],
		["$gameParty.gold()", "gold()"], ["$gameParty.steps()", "steps()"], ["$gameParty.size()", "party_size()"],
		["$gameMap.mapId()", "map_id()"], ["$gameMap._mapId", "map_id()"], ["Math.floor(", "floor("], ["Math.ceil(", "ceil("],
		["Math.max(", "max("], ["Math.min(", "min("], ["Math.abs(", "abs("], ["===", "=="], ["!==", "!="], ["&&", " and "], ["||", " or "],
		["CodexReincarnationRandom.entryAccepted()", "entry_accepted()"], ["CodexReincarnationRandom.entryHard()", "entry_hard()"]]
	for s in subs:
		e = e.replace(s[0], s[1])
	e = RegEx.create_from_string("\\$gameParty\\.numItems\\(\\$dataItems\\[(\\d+)\\]\\)").sub(e, "items($1)", true)
	e = RegEx.create_from_string("!(?!=)").sub(e, " not ", true)
	var allowed := ["v", "sw", "playtime", "gold", "steps", "party_size", "map_id", "items", "entry_accepted", "entry_hard", "floor", "ceil", "max", "min", "abs", "true", "false", "and", "or", "not"]
	for w in RegEx.create_from_string("[A-Za-z_$][A-Za-z_0-9$.]*").search_all(e):
		if not allowed.has(w.get_string()):
			return null
	# JS 除法是浮点：整数字面量一律写成浮点
	e = RegEx.create_from_string("(?<![\\d.])(\\d+)(?![\\d.])").sub(e, "$1.0", true)
	var ex := Expression.new()
	if ex.parse(e) != OK:
		return null
	var r = ex.execute([], ExprEnv.new(), false)
	return null if ex.has_execute_failed() else r


class ExprEnv:
	extends RefCounted
	func v(id: float) -> float: return XState.current.variable(int(id))
	func sw(id: float) -> bool: return XState.current.switch(int(id))
	func playtime() -> float: return floorf(XState.current.play_seconds)
	func gold() -> float: return float(XState.current.gold)
	func steps() -> float: return float(XState.current.steps)
	func party_size() -> float: return float(XState.current.members().size())
	func map_id() -> float: return float(XState.current.map_id)
	func items(id: float) -> float: return float(XState.current.item_count(int(id)))
	func entry_accepted() -> bool: return bool(MVScript.reincarnation_entry.get("accepted", false))
	func entry_hard() -> bool: return bool(MVScript.reincarnation_entry.get("hard", false))


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
