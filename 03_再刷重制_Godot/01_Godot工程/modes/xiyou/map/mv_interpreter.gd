class_name MVInterpreter
extends RefCounted
## MV 事件指令解释器（Game_Interpreter 的子集）。按缩进和 _branch 记录处理分支，与 MV 一致。
## host 提供画面服务（文字、选项、场所移动、战斗、商店、淡入淡出、移动路线、动画、气泡、提示、输入名字、存档），见 map_scene.gd。
## 脚本(355/655) 由 MVScript 按已知写法翻译；插件指令(356) 认得 Difficulty SetID、GhostButtons、ProhibitHangUp；
## 副本相关（Difficulty SetID、挂机开关、顶层事件结束、事件战斗结束）交给 XDungeon；214 暂时消除交给宿主 erase_event；
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
## 作为公共事件子解释器运行时的公共事件 ID（顶层为 0）
var common_id := 0
## installV010UsabilityRuntime：宝箱事件（开始时本事件图像为 BaoXiangGuai）把 125～128 的所得合并成一条「宝箱收获」提示，
## 子公共事件共用同一份；CodexV010Fixes.rewardNotice 在宝箱里不再单独提示。rows：[{key, name, amount}]
var receipt = null
## 本解释器最近一条 125～128 的实际所得 {kind, id, amount}（CodexV010Fixes.awardQuantity）
var last_gain := {}
## $gameMessage 里还没显示的文字（升级提示等由指令直接 add 的）：到下一个会等待的指令或事件结束时一起显示，
## 同 MV 消息窗在解释器下一次等待时才出现（等级提升各人之间以 \f 分页）
var pending_lines: Array = []
## 会让 MV 解释器等待（或在消息忙时停住）的指令：执行前先显示待显示的文字
const FLUSH_BEFORE := [101, 102, 103, 104, 201, 205, 212, 213, 217, 221, 222, 230, 301, 302, 303, 353, 354]
static var skip_common_events := [1386, 1435]   # 战斗背景、轮回模式：首期无对应系统
## 对照工具用：全部解释器（含公共事件子解释器）合计最多执行的指令数，0 为不限；超过就停止并置 aborted
static var max_steps := 0
static var steps := 0
static var aborted := false
## 对照工具用：≥0 时随机数固定为该值（同参照引擎把 Math.random 固定），默认 −1 不固定
static var fixed_random := -1.0
## O-027：原版事件把玩家传到四个方向都不能通行的格子（正式引擎 isMapPassable 实测）时，改传到同图的正常落点。
## 键「来源地图:事件:目的地图:x:y」。七层、十二层辛德瑞（Map061 事件 9、Map065 事件 3）原版传回大厅 (12,18)，那里是钓鱼池水面，
## 传过去就走不动；其余各层的辛德瑞都传到 (14,23)。设为空字典 {} 恢复原版。
const TRANSFER_FIX := {"61:9:4:12:18": Vector2i(14, 23), "65:3:4:12:18": Vector2i(14, 23)}


## MV Math.random()
static func random_float() -> float:
	return fixed_random if fixed_random >= 0.0 else randf()


## MV Math.randomInt(hi − lo + 1) + lo
static func random_int(lo: int, hi: int) -> int:
	if fixed_random >= 0.0:
		return lo + floori((hi - lo + 1) * fixed_random)
	return randi_range(lo, hi)


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
	if _depth == 0 and event_id > 0:
		var ch = host.character(event_id, event_id)
		if ch != null and str(ch.get("character_name")) == "BaoXiangGuai":
			receipt = {"rows": []}
	while index < list.size():
		if max_steps > 0:
			steps += 1
			if steps > max_steps:
				aborted = true
				break
		var c: Dictionary = list[index]
		if not pending_lines.is_empty() and FLUSH_BEFORE.has(int(c.code)):
			await flush_message()
		var go = await _execute(c)
		if go == false:
			break
		index += 1
	if _depth == 0:
		await flush_message()
		if receipt != null and not receipt.rows.is_empty():
			host.toast("宝箱收获：<br>" + "<br>".join(PackedStringArray(receipt.rows.map(func(r): return "%s ×%d" % [str(r.name).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;"), int(r.amount)]))))
		XDungeon.event_finished(state())
	finished.emit()


## Game_Message.newPage：已有文字时给最后一行加 \f
func new_page() -> void:
	if not pending_lines.is_empty():
		pending_lines[pending_lines.size() - 1] = str(pending_lines[-1]) + "\f"


func flush_message() -> void:
	if pending_lines.is_empty():
		return
	var lines := pending_lines.duplicate()
	pending_lines.clear()
	await host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": lines})


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
					sub.pending_lines = pending_lines
					sub.common_id = ce_id
					sub.receipt = receipt
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
			var before := state().gold
			state().gain_gold(v if int(p[0]) == 0 else -v)
			_treasure_popup({}, v if int(p[0]) == 0 else -v)
			_record_gain("gold", 0, state().gold - before, str(XDB.system().get("currencyUnit", "")))
		126:
			var n := _operand(int(p[2]), int(p[3]))
			var before := state().item_count(int(p[0]))
			state().gain_item(int(p[0]), n if int(p[1]) == 0 else -n)
			_treasure_popup(XDB.rec("Items", int(p[0])), n if int(p[1]) == 0 else -n)
			_record_gain("item", int(p[0]), state().item_count(int(p[0])) - before, str(XDB.rec("Items", int(p[0])).get("name", "")))
			host.refresh_events()
		127, 128:
			var n := _operand(int(p[2]), int(p[3]))
			var kind := "weapon" if int(c.code) == 127 else "armor"
			state().gain_gear(kind, int(p[0]), n if int(p[1]) == 0 else -n)
			var rec := XDB.rec("Weapons" if int(c.code) == 127 else "Armors", int(p[0]))
			_treasure_popup(rec, n if int(p[1]) == 0 else -n)
			# 装备都是独立物品（YEP_ItemCore）：原版按数据库原件数 $gameParty.numItems 计，所得恒为 0，不进宝箱收获
			_record_gain(kind, int(p[0]), 0, str(rec.get("name", "")))
		129:
			if int(p[1]) == 0:
				state().add_actor(int(p[0]))
			else:
				state().remove_actor(int(p[0]))
			host.refresh_events()
		201:
			if int(p[0]) == 0:
				var to: Vector2i = TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [map_id, event_id, int(p[1]), int(p[2]), int(p[3])], Vector2i(int(p[2]), int(p[3])))
				await host.transfer(int(p[1]), to.x, to.y, int(p[4]))
			else:
				var s := state()
				await host.transfer(int(s.variable(int(p[1]))), int(s.variable(int(p[2]))), int(s.variable(int(p[3]))), int(p[4]))
		221:
			await host.fade(true)
		222:
			await host.fade(false)
		225:
			# 画面震动 [强度, 速度, 时间, 等待]
			if host.has_method("shake_screen"):
				host.shake_screen(int(p[0]), int(p[1]), int(p[2]))
			if bool(p[3]):
				for i in range(int(p[2])):
					await host.get_tree().process_frame
		230:
			for i in range(int(p[0])):
				await host.get_tree().process_frame
		241:
			host.play_bgm(p[0])
		245:
			host.play_bgs(p[0])
		249:
			host.play_me(p[0])
		250:
			host.play_se(p[0])
		301:
			var troop := int(p[1]) if int(p[0]) == 0 else int(state().variable(int(p[1])))
			var result: int = await host.start_battle(troop, bool(p[2]), bool(p[3]))
			XDungeon.battle_finished(troop, result, state().map_id)
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
		214:
			# 暂时消除事件（Game_Map.eraseEvent）：换地图重建事件后复原
			if event_id > 0 and host.has_method("erase_event"):
				host.erase_event(event_id)
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
		136:
			# 更改禁止遇敌 [0 禁止 1 允许]
			state().encounter_enabled = int(p[0]) != 0
		216:
			# 更改队伍跟随 [0 显示 1 隐藏]
			host.set_followers_visible(int(p[0]) == 0)
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
		316:
			# 增减等级 [指定方式, 角色/变量, 0 增 1 减, 操作数类型, 操作数, 显示升级]；角色 0 为全队（iterateActorEx）
			var value := _operand(int(p[3]), int(p[4]))
			if int(p[2]) == 1:
				value = -value
			for a in _actors_ex(int(p[0]), int(p[1])):
				var before: int = a.level
				var learned: Array = a.change_level_mv(a.level + value)
				if bool(p[5]) and a.level > before:
					_display_level_up(a, learned)
		313:
			# 更改状态 [指定方式, 角色/变量, 0 附加 1 解除, 状态]
			for a in _actors_ex(int(p[0]), int(p[1])):
				if int(p[2]) == 0:
					a.add_state(int(p[3]))
				else:
					a.remove_state(int(p[3]))
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


## 插件指令：Vitsuno_Difficulty「Difficulty SetID N」；Mehmet_GhostButtons 只记标记（重制版没有虚拟按钮）；
## XdRs_HangUp「EnableHangUp / ProhibitHangUp」开关挂机（XHangUp.enabled）
func _plugin_command(line: String) -> void:
	var args := line.split(" ", false)
	if args.is_empty():
		return
	match args[0]:
		"Difficulty":
			if args.size() >= 3 and args[1] == "SetID":
				# installWeakChallengeRuntime：混沌（9）时公共事件 714 难度修复不改难度
				if common_id == 714 and state().difficulty == 9:
					return
				XDungeon.set_difficulty(state(), int(args[2]), self)
				return
		"GhostButtons":
			state().flags["GhostButtons"] = args[1] if args.size() > 1 else ""
			return
		"maxlevel", "MaxLevel", "MAXLEVEL":
			# YEP_CoreEngine：maxlevel add N（在当前上限上加）/ maxlevel equal N
			if args.size() > 2 and str(args[2]).is_valid_int():
				var s := state()
				if str(args[1]).to_lower() == "add":
					s.actor_max_level = s.max_level() + int(args[2])
					return
				if str(args[1]).to_lower() == "equal":
					s.actor_max_level = int(args[2])
					return
		"ProhibitHangUp", "EnableHangUp":
			XDungeon.set_hang_up(state(), args[0] == "EnableHangUp")
			return
		"ShopInventory":
			XShopStock.plugin_command(state(), args)  # KMS_ShopInventory 限购（八戒车道）
			return
	skipped.append({"code": 356, "text": line.left(80)})


## Game_Interpreter.iterateActorEx：0 指定（ID 0 为全队）、1 按变量
func _actors_ex(kind: int, param: int) -> Array:
	var s := state()
	var id := param if kind == 0 else int(s.variable(param))
	if id == 0:
		return s.members()
	return [s.actor(id)] if not XDB.rec("Actors", id).is_empty() else []


## Game_Actor.displayLevelUp：新的一页写「%1升到了 %2 %3！」，再逐个「学会了%1！」
func _display_level_up(a: XActor, learned: Array) -> void:
	var terms: Dictionary = XDB.system().terms
	new_page()
	pending_lines.append(str(terms.messages.levelUp).replace("%1", a.display_name()).replace("%2", str(terms.basic[0])).replace("%3", str(a.level)))
	for id in learned:
		pending_lines.append(str(terms.messages.obtainSkill).replace("%1", str(XDB.rec("Skills", int(id)).get("name", ""))))


## installV010UsabilityRuntime：记下 125～128 的实际所得（数量差，不计负数），宝箱里并入收获清单
func _record_gain(kind: String, id: int, amount: int, name: String) -> void:
	amount = maxi(0, amount)
	last_gain = {"kind": kind, "id": id, "amount": amount}
	if receipt != null and amount > 0:
		var key := "%s:%d" % [kind, id]
		for r in receipt.rows:
			if r.key == key:
				r.amount += amount
				return
		receipt.rows.append({"key": key, "name": name, "amount": amount})


## MOG_TreasurePopup：数量为正、本事件（按 ID）在当前地图上时浮出获得提示
func _treasure_popup(rec: Dictionary, amount: int) -> void:
	if amount > 0 and event_id > 0 and host.has_method("treasure_popup"):
		host.treasure_popup(rec, amount, event_id)


func _operand(type: int, value: int) -> int:
	return int(state().variable(value)) if type != 0 else value


## Game_Interpreter.gameDataOperand（变量操作数「游戏数据」）；战斗中的敌人等首期没有的项目返回 null
func _game_data(type: int, p1: int, p2: int):
	var s := state()
	match type:
		0: return s.item_count(p1)
		1: return s.gear_count("weapon", p1)
		2: return s.gear_count("armor", p1)
		3:
			if XDB.rec("Actors", p1).is_empty():
				return 0
			var a := s.actor(p1)
			match p2:
				0: return a.level
				1: return a.exp_total
				2: return a.hp
				3: return a.mp
			if p2 >= 4 and p2 <= 11:
				return a.param(p2 - 4)
			return 0
		5:
			var ch = host.character(p1, event_id)
			if ch == null:
				return null
			match p2:
				0: return ch.grid.x
				1: return ch.grid.y
				2: return ch.direction
			return null
		6:
			var m := s.members()
			return m[p1].actor_id if p1 >= 0 and p1 < m.size() else 0
		7:
			match p1:
				0: return s.map_id
				1: return s.members().size()
				2: return s.gold
				3: return s.steps
				4: return floori(s.play_seconds)
	return null


func _set_variables(p: Array) -> void:
	var value := 0.0
	match int(p[3]):
		0: value = float(p[4])
		1: value = state().variable(int(p[4]))
		2: value = random_int(int(p[4]), int(p[5]))
		3:
			var gd = _game_data(int(p[4]), int(p[5]), int(p[6]))
			if gd == null:
				skipped.append({"code": 122, "text": "游戏数据 %d,%d,%d" % [int(p[4]), int(p[5]), int(p[6])]})
				return
			value = float(gd)
		4:
			var r = MVScript.eval_expr(str(p[4]))
			if r == null or not (r is float or r is int or r is bool):
				skipped.append({"code": 122, "text": "脚本 " + str(p[4]).left(60)})
				return
			value = float(r)
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
			# 角色 [4, 角色, 种类, 值]（Game_Interpreter.command111）：0 在队 1 名字 2 职业 3 技能 4 武器 5 防具 6 状态
			var aid := int(p[1])
			if XDB.rec("Actors", aid).is_empty():
				return false
			match int(p[2]):
				0: return s.party.has(aid)
				1: return s.actor(aid).display_name() == str(p[3])
				2: return s.actor(aid).class_id == int(p[3])
				3: return s.actor(aid).skills().any(func(k): return int(k.id) == int(p[3]))
				4, 5:
					# 按底材编号比（未对照独立装备实例的 hasWeapon/hasArmor）
					var kind := "weapon" if int(p[2]) == 4 else "armor"
					return s.actor(aid).equip_list().any(func(e): return e.get("kind", "") == kind and int(e.get("base", 0)) == int(p[3]))
				6: return s.actor(aid).is_state_affected(int(p[3]))
			return false
		7:
			var g := float(p[1])
			match int(p[2]):
				0: return s.gold >= g
				1: return s.gold <= g
				2: return s.gold < g
		8:
			return s.item_count(int(p[1])) > 0
		6:
			# 角色朝向 [6, 角色, 方向]
			var ch = host.character(int(p[1]), event_id)
			return ch != null and int(ch.direction) == int(p[2])
		12:
			# 脚本条件：白名单表达式（MVScript.eval_expr）；挂机相关写法与认不出的视为 false
			var code := str(p[1])
			if code.contains("hangUp"):
				return false
			var r = MVScript.eval_expr(code)
			if r != null:
				return bool(r)
			skipped.append({"code": 111, "text": "脚本条件 " + code.left(60)})
			return false
		13:
			# 首期没有车辆；Game_Player.isInVehicle 在这些地图始终为 false。
			return false
	skipped.append({"code": 111, "text": "条件类型 %d" % int(p[0])})
	return false
