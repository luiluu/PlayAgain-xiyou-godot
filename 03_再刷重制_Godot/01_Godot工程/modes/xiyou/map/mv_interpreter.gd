class_name MVInterpreter
extends RefCounted
## MV 事件指令解释器（Game_Interpreter 的子集）。按缩进和 _branch 记录处理分支，与 MV 一致。
## host 提供画面服务（文字、选项、场所移动、战斗、商店、淡入淡出、移动路线、动画、气泡、提示、输入名字、存档），见 map_scene.gd。
## 脚本(355/655) 由 MVScript 按已知写法翻译；插件指令(356) 认得 Difficulty SetID、GhostButtons、ProhibitHangUp；
## 认不出的脚本语句、插件指令与未支持的指令跳过并记进 skipped，便于之后逐条补齐。

signal finished

var host: Node
var map_id := 0
var event_id := 0
var list: Array = []
var index := 0
var _branch := {}
var _depth := 0
var skipped: Array = []        # [{code, text}]
static var skip_common_events := [714, 1386, 1435]   # 难度修复、战斗背景、轮回模式：首期无对应系统


func _init(h: Node, map: int, event: int, commands: Array, depth := 0) -> void:
	host = h
	map_id = map
	event_id = event
	list = commands
	_depth = depth


func state() -> XState:
	return XState.current


func run() -> void:
	index = 0
	while index < list.size():
		var c: Dictionary = list[index]
		var go = await _execute(c)
		if go == false:
			break
		index += 1
	finished.emit()


## YEP_X_ExtMesPack1 setupExtendedChoices：同一缩进上一组选项结束（404）后紧跟另一组「显示选项」时并成一个窗口，
## 删去中间的 404 与 102、后面的选项分支（402）续编号；后一组的默认项与取消项按前面已有的项数平移。
## 与原版一样直接改指令列表（同一事件再次执行时已是合并后的样子）。ci 为第一组 102 的位置。
func _merge_choices(ci: int) -> void:
	var params: Array = list[ci].parameters
	var indent := int(list[ci].indent)
	var total := 0
	var i := ci + 1
	while i < list.size():
		var c: Dictionary = list[i]
		if int(c.indent) == indent:
			if int(c.code) == 404 and not (i + 1 < list.size() and int(list[i + 1].code) == 102):
				break
			elif int(c.code) == 102:
				var cp: Array = c.parameters
				if int(cp[2]) >= 0:
					params[2] = int(cp[2]) + total
				if int(cp[1]) >= 0:
					params[1] = int(cp[1]) + total
				elif int(cp[1]) == -2:
					params[1] = -2
				params[0].append_array(cp[0])
				list.remove_at(i - 1)
				list.remove_at(i - 1)
				i -= 2
			elif int(c.code) == 402:
				c.parameters[0] = total
				total += 1
		i += 1


## Game_Interpreter.setupChoices：[选项, 取消类型, 默认, 位置, 背景]
func _choice_params(msg: Dictionary, cp: Array) -> void:
	msg.choices = cp[0]
	msg.cancel = int(cp[1])
	msg.default = int(cp[2]) if cp.size() > 2 else 0
	msg.choice_position = int(cp[3]) if cp.size() > 3 else 2
	msg.choice_background = int(cp[4]) if cp.size() > 4 else 0


## Game_Interpreter.setupNumInput：[变量, 位数]
func _number_input(msg: Dictionary, np: Array) -> void:
	var var_id := int(np[0])
	msg.digits = int(np[1])
	msg.number_value = int(state().variable(var_id))
	var v: int = await host.show_message(msg)
	state().set_variable(var_id, v)


func _skip_branch() -> void:
	var indent := int(list[index].indent)
	while index + 1 < list.size() and int(list[index + 1].indent) > indent:
		index += 1


func _execute(c: Dictionary):
	var p: Array = c.parameters
	var indent := int(c.indent)
	match int(c.code):
		101:
			# MV command101：文字、紧跟的选项/数值输入合成一条消息
			var msg := {"face": str(p[0]), "index": int(p[1]), "background": int(p[2]) if p.size() > 2 else 0,
				"position": int(p[3]) if p.size() > 3 else 2, "lines": []}
			while index + 1 < list.size() and int(list[index + 1].code) == 401:
				index += 1
				msg.lines.append(str(list[index].parameters[0]))
			if index + 1 < list.size() and int(list[index + 1].code) == 102:
				index += 1
				_merge_choices(index)
				_choice_params(msg, list[index].parameters)
				_branch[int(list[index].indent)] = await host.show_message(msg)
			elif index + 1 < list.size() and int(list[index + 1].code) == 103:
				index += 1
				await _number_input(msg, list[index].parameters)
			else:
				await host.show_message(msg)
		102:
			var msg := {}
			_merge_choices(index)
			_choice_params(msg, list[index].parameters)
			_branch[indent] = await host.show_message(msg)
		103:
			await _number_input({}, p)
		402:
			if _branch.get(indent) != int(p[0]):
				_skip_branch()
		403:
			if _branch.get(indent) != -2:
				_skip_branch()
		111:
			var ok := _condition(p)
			_branch[indent] = ok
			if not ok:
				_skip_branch()
		411:
			if _branch.get(indent) != false:
				_skip_branch()
		112:
			pass
		413:
			# 回到对应的循环开始
			var i := index
			while i > 0:
				i -= 1
				if int(list[i].code) == 112 and int(list[i].indent) == indent:
					index = i
					break
		113:
			var depth := indent
			while index + 1 < list.size():
				index += 1
				if int(list[index].code) == 413 and int(list[index].indent) < depth:
					break
		115:
			return false
		117:
			var ce_id := int(p[0])
			if skip_common_events.has(ce_id):
				skipped.append({"code": 117, "text": "公共事件 %d（首期跳过）" % ce_id})
			else:
				var ce := XDB.rec("CommonEvents", ce_id)
				if not ce.is_empty() and _depth < 30:
					var sub := MVInterpreter.new(host, map_id, event_id, ce.list, _depth + 1)
					await sub.run()
					skipped.append_array(sub.skipped)
		121:
			for id in range(int(p[0]), int(p[1]) + 1):
				state().set_switch(id, int(p[2]) == 0)
			host.refresh_events()
		122:
			_set_variables(p)
			host.refresh_events()
		123:
			if event_id > 0:
				state().set_self_switch(map_id, event_id, str(p[0]), int(p[1]) == 0)
				host.refresh_events()
		125:
			var v := _operand(int(p[1]), int(p[2]))
			state().gain_gold(v if int(p[0]) == 0 else -v)
			_treasure_popup({}, v if int(p[0]) == 0 else -v)
		126:
			var n := _operand(int(p[2]), int(p[3]))
			state().gain_item(int(p[0]), n if int(p[1]) == 0 else -n)
			_treasure_popup(XDB.rec("Items", int(p[0])), n if int(p[1]) == 0 else -n)
			host.refresh_events()
		127, 128:
			var n := _operand(int(p[2]), int(p[3]))
			state().gain_gear("weapon" if int(c.code) == 127 else "armor", int(p[0]), n if int(p[1]) == 0 else -n)
			_treasure_popup(XDB.rec("Weapons" if int(c.code) == 127 else "Armors", int(p[0])), n if int(p[1]) == 0 else -n)
		129:
			if int(p[1]) == 0:
				state().add_actor(int(p[0]))
			else:
				state().remove_actor(int(p[0]))
			host.refresh_events()
		201:
			if int(p[0]) == 0:
				await host.transfer(int(p[1]), int(p[2]), int(p[3]), int(p[4]))
			else:
				var s := state()
				await host.transfer(int(s.variable(int(p[1]))), int(s.variable(int(p[2]))), int(s.variable(int(p[3]))), int(p[4]))
		221:
			await host.fade(true)
		222:
			await host.fade(false)
		230:
			for i in range(int(p[0])):
				await host.get_tree().process_frame
		241:
			host.play_bgm(p[0])
		250:
			host.play_se(p[0])
		301:
			var troop := int(p[1]) if int(p[0]) == 0 else int(state().variable(int(p[1])))
			var result: int = await host.start_battle(troop, bool(p[2]), bool(p[3]))
			_branch[indent] = result
			if result == 2 and not bool(p[3]):
				host.game_over()
				return false
		601:
			if _branch.get(indent) != 0:
				_skip_branch()
		602:
			if _branch.get(indent) != 1:
				_skip_branch()
		603:
			if _branch.get(indent) != 2:
				_skip_branch()
		302:
			var goods := [p]
			while index + 1 < list.size() and int(list[index + 1].code) == 605:
				index += 1
				goods.append(list[index].parameters)
			await host.open_shop(goods, bool(p[4]))
		314:
			for a in state().members():
				a.recover_all()
		205:
			# 设置移动路线 [角色, 路线]；路线勾选「等待完成」时等角色走完
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.force_move_route(p[1])
				if bool(p[1].get("wait", false)):
					# 等待中若场所移动，旧地图的角色已释放
					while is_instance_valid(ch) and ch.is_route_forcing():
						await host.get_tree().physics_frame
		211:
			host.player.transparent = int(p[0]) == 0
			host.player.queue_redraw()
		212:
			# 显示动画 [角色, 动画, 等待]
			var ch = host.character(int(p[0]), event_id)
			if ch:
				var anim = host.show_animation(ch, int(p[1]))
				if bool(p[2]) and anim:
					await anim.done
		213:
			# 显示气泡 [角色, 气泡, 等待]
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.start_balloon(int(p[1]))
				if bool(p[2]):
					while is_instance_valid(ch) and ch.is_balloon_playing():
						await host.get_tree().physics_frame
		217:
			await host.gather_followers()
		318:
			# 增减技能 [指定方式, 角色/变量, 0 学会 1 遗忘, 技能]；角色 0 为全队
			var aid := int(p[1]) if int(p[0]) == 0 else int(state().variable(int(p[1])))
			var targets: Array = state().members() if aid == 0 else ([state().actor(aid)] if not XDB.rec("Actors", aid).is_empty() else [])
			for a in targets:
				if int(p[2]) == 0:
					a.learn_skill(int(p[3]))
				else:
					a.forget_skill(int(p[3]))
				a.refresh_passive()
		354:
			host.return_to_title()
			return false
		355:
			var code := str(p[0])
			while index + 1 < list.size() and int(list[index + 1].code) == 655:
				index += 1
				code += "\n" + str(list[index].parameters[0])
			for st in await MVScript.run(code, self):
				skipped.append({"code": 355, "text": str(st).left(80)})
		356:
			_plugin_command(str(p[0]))
		118:
			pass
		119:
			# 跳转标签（Game_Interpreter.command119 / jumpTo）：找同名标签，分支记录按缩进清空
			for i in range(list.size()):
				if int(list[i].code) == 118 and str(list[i].parameters[0]) == str(p[0]):
					_branch.clear()
					index = i
					break
		_:
			var code := int(c.code)
			if code in [401, 405, 408, 655, 404, 412, 604, 0, 108, 505]:
				pass
			else:
				var text := str(p[0]) if p.size() > 0 else ""
				skipped.append({"code": code, "text": text.left(80)})
	return true


## 插件指令：Vitsuno_Difficulty「Difficulty SetID N」；Mehmet_GhostButtons 与 XdRs_HangUp 的开关只记标记（重制版没有这两种界面）
func _plugin_command(line: String) -> void:
	var args := line.split(" ", false)
	if args.is_empty():
		return
	match args[0]:
		"Difficulty":
			if args.size() >= 3 and args[1] == "SetID":
				state().difficulty = int(args[2])
				return
		"GhostButtons":
			state().flags["GhostButtons"] = args[1] if args.size() > 1 else ""
			return
		"ProhibitHangUp", "PermitHangUp":
			state().flags["HangUpProhibited"] = args[0] == "ProhibitHangUp"
			return
	skipped.append({"code": 356, "text": line.left(80)})


## MOG_TreasurePopup：数量为正、本事件（按 ID）在当前地图上时浮出获得提示
func _treasure_popup(rec: Dictionary, amount: int) -> void:
	if amount > 0 and event_id > 0 and host.has_method("treasure_popup"):
		host.treasure_popup(rec, amount, event_id)


func _operand(type: int, value: int) -> int:
	return int(state().variable(value)) if type != 0 else value


func _set_variables(p: Array) -> void:
	var value := 0.0
	match int(p[3]):
		0: value = float(p[4])
		1: value = state().variable(int(p[4]))
		2: value = randi_range(int(p[4]), int(p[5]))
		_:
			skipped.append({"code": 122, "text": "变量操作数类型 %d" % int(p[3])})
			return
	for id in range(int(p[0]), int(p[1]) + 1):
		var old := state().variable(id)
		var r := value
		match int(p[2]):
			1: r = old + value
			2: r = old - value
			3: r = old * value
			4: r = old / value if value != 0 else old
			5: r = fmod(old, value) if value != 0 else old
		state().set_variable(id, r)


func _condition(p: Array) -> bool:
	var s := state()
	match int(p[0]):
		0:
			return s.switch(int(p[1])) == (int(p[2]) == 0)
		1:
			var v1 := s.variable(int(p[1]))
			var v2 := float(p[3]) if int(p[2]) == 0 else s.variable(int(p[3]))
			match int(p[4]):
				0: return v1 == v2
				1: return v1 >= v2
				2: return v1 <= v2
				3: return v1 > v2
				4: return v1 < v2
				5: return v1 != v2
		2:
			return event_id > 0 and s.self_switch(map_id, event_id, str(p[1])) == (int(p[2]) == 0)
		4:
			return s.party.has(int(p[1]))
		7:
			var g := float(p[1])
			match int(p[2]):
				0: return s.gold >= g
				1: return s.gold <= g
				2: return s.gold < g
		8:
			return s.item_count(int(p[1])) > 0
		12:
			# 脚本条件：首期已知的几条按语义处理，其余视为 false
			var code := str(p[1])
			if code.contains("hangUp"):
				return false
			skipped.append({"code": 111, "text": "脚本条件 " + code.left(60)})
			return false
		13:
			# 首期没有车辆；Game_Player.isInVehicle 在这些地图始终为 false。
			return false
	skipped.append({"code": 111, "text": "条件类型 %d" % int(p[0])})
	return false
