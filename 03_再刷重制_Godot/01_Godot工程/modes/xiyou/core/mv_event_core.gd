class_name MVEventCore
extends RefCounted
## 地图与战斗共用的游标式事件解释器核心（Game_Interpreter 的指令语义只写这一份）。
## advance() 从游标处一直执行到需要外部处理为止，返回请求：
##   {kind: "done"}                          本列表（含公共事件子游标）执行完
##   {kind: "message", msg}                  显示文字／选项／数值输入；处理完调 waiting_frame().resume(应答)
##   {kind: "command", command}              宿主指令（地图：场所移动、战斗、商店、脚本…）；处理完调 waiting_frame().resume(go)
##   以及子类自己的请求（战斗的 forced_action，见 XBattleEventRunner）。
## 公共事件（117）同 MV 的 _childInterpreter 建子游标，子游标发出的请求原样向上传，waiting_frame() 是发出请求的那一层。
## 请求字典里不放游标自己（挂起的协程带着它会让宿主先释放时游标留在内存里）。
## 环境相关的部分是虚函数：_execute_env（本核心不认的指令）、_condition_env、_game_data、_party_members、
## _change_actor_state、_plugin_env、_data_changed、_treasure_popup、_make_child、_map_id、_event_id。
## 地图的 MVInterpreter 在外面包一层 await；战斗的 XBattleEventRunner 由 XBattleLogic 逐步推进。

## 会让 MV 解释器等待（或在消息忙时停住）的指令：执行前先显示待显示的文字
const FLUSH_BEFORE := [101, 102, 103, 104, 201, 205, 212, 213, 217, 221, 222, 230, 301, 302, 303, 353, 354]
## 勾了「等待」才等的指令 → 等待参数下标（225 画面震动 wait(时间)）
const FLUSH_IF_WAIT := {225: 3}
## 只是续行、注释或分支结尾，执行时什么也不做
const PASS_CODES := [401, 405, 408, 655, 404, 412, 604, 0, 108, 505]
static var skip_common_events := [1386, 1435]   # 战斗背景、轮回模式：首期无对应系统
## 对照工具用：全部解释器（含公共事件子游标、战斗事件）合计最多执行的指令数，0 为不限；超过就停止并置 aborted
static var max_steps := 0
static var steps := 0
static var aborted := false
## 对照工具用：≥0 时随机数固定为该值（同参照引擎把 Math.random 固定），默认 −1 不固定
static var fixed_random := -1.0

## No-state tooling fallback stays independent of presentation/global RNG.
static var _fallback_random := XRandomStream.create(XRandomStream.fresh_seed(), "world")

static func _world(owner: XState) -> XRandomStream:
	var s := owner if owner != null else XState.current
	return s.world_random() if s != null else _fallback_random

## MV Math.random()
static func random_float(owner: XState = null) -> float:
	return fixed_random if fixed_random >= 0.0 else _world(owner).next_float("event_random")


## MV Math.randomInt(hi − lo + 1) + lo
static func random_int(lo: int, hi: int, owner: XState = null) -> int:
	if fixed_random >= 0.0:
		return lo + floori((hi - lo + 1) * fixed_random)
	return _world(owner).next_int_inclusive(lo, hi, "event_random_int")


var list: Array = []
var index := 0
var _branch := {}
var _depth := 0
var skipped: Array = []        # [{code, text}]
## 作为公共事件子游标运行时的公共事件 ID（顶层为 0）
var common_id := 0
## $gameMessage 里还没显示的文字（升级提示等由指令直接 add 的）：到下一个会等待的指令或事件结束时一起显示，
## 同 MV 消息窗在解释器下一次等待时才出现（等级提升各人之间以 \f 分页）。父子游标共用同一个数组。
var pending_lines: Array = []
## installV010UsabilityRuntime：宝箱收获（见 MVInterpreter）；不在宝箱里为 null。父子共用。
var receipt = null
## 本游标最近一条 125～128 的实际所得 {kind, id, amount}（CodexV010Fixes.awardQuantity）
var last_gain := {}
var _child: MVEventCore = null
## 宿主指令回 false（全军覆没、回标题）后置位；父游标见子游标 halted 也跟着结束
var halted := false
## 正在等待的应答："" 不在等待、"message" 文字、"choice" 选项（_wait_arg＝缩进）、"number" 数值（_wait_arg＝变量）、
## "flush" 待显示文字（应答后不前进）、"command" 宿主指令
var _wait := ""
var _wait_arg = null


func state() -> XState:
	return XState.current


## 战斗宿主透传本场规则流；地图保留 fixed_random 的参照接口。
func rule_random() -> XRandomStream:
	return null


func _variable_random(lo: int, hi: int) -> int:
	var stream := rule_random()
	return stream.next_int_inclusive(lo, hi, "event_variable", _random_event_key()) if stream != null else random_int(lo, hi, state())


func _random_event_key() -> String:
	return ""


## 执行到下一个需要外部处理的地方（见文件头）。还在等应答时调用返回 {kind: "waiting"}。
func advance() -> Dictionary:
	while true:
		if _child != null:
			var r := _child.advance()
			if r.kind != "done":
				return r
			skipped.append_array(_child.skipped)
			if _child.halted:
				# 全军覆没（301 战败不可败）／回标题：整串事件到此为止，不接着跑上层（地图事件、上一级公共事件）后面的指令；
				# 参照引擎 SceneManager.goto 离开地图场景，父解释器不会再往下走
				halted = true
				index = list.size() - 1
			_child = null
			index += 1
			continue
		if _wait != "":
			return {"kind": "waiting"}
		if index >= list.size() or aborted:
			if _depth == 0 and not pending_lines.is_empty():
				return _flush_request()
			return {"kind": "done"}
		var c: Dictionary = list[index]
		if not pending_lines.is_empty() and _waits(c):
			return _flush_request()
		if max_steps > 0:
			steps += 1
			if steps > max_steps:
				aborted = true
				continue
		var r = _execute(c)
		if r == null or (r is bool and r):
			index += 1
		elif r is bool:
			index = list.size()
		elif r is Dictionary:
			if r.kind == "child":
				continue
			return r
	return {"kind": "done"}


## 这条指令会让 MV 解释器等待：先显示待显示的文字
static func _waits(c: Dictionary) -> bool:
	var code := int(c.code)
	if FLUSH_IF_WAIT.has(code):
		var p: Array = c.parameters
		return p.size() > FLUSH_IF_WAIT[code] and bool(p[FLUSH_IF_WAIT[code]])
	return FLUSH_BEFORE.has(code)


## 外部处理完本层发出的请求后调用：选项结果、数值、宿主指令是否继续（false 结束本列表）
func resume(response = null) -> void:
	var w := _wait
	_wait = ""
	match w:
		"", "flush":
			return
		"choice":
			_branch[int(_wait_arg)] = int(response) if response != null else 0
		"number":
			state().set_variable(int(_wait_arg), int(response) if response != null else 0)
		"command":
			if response is bool and not response:
				halted = true
				index = list.size()
				return
	index += 1


## 正在等应答的那一层（公共事件子游标里发出的请求由子游标应答）
func waiting_frame() -> MVEventCore:
	if _child != null and _child.is_waiting():
		return _child.waiting_frame()
	return self


func is_waiting() -> bool:
	return _wait != "" or (_child != null and _child.is_waiting())


func _request(kind: String, wait: String, data: Dictionary, arg = null) -> Dictionary:
	_wait = wait
	_wait_arg = arg
	data.kind = kind
	return data


func _flush_request() -> Dictionary:
	var lines := pending_lines.duplicate()
	pending_lines.clear()
	return _request("message", "flush", {"msg": {"face": "", "index": 0, "background": 0, "position": 2, "lines": lines}})


## Game_Message.newPage：已有文字时给最后一行加 \f
func new_page() -> void:
	if not pending_lines.is_empty():
		pending_lines[pending_lines.size() - 1] = str(pending_lines[-1]) + "\f"


func _skip_branch() -> void:
	var indent := int(list[index].get("indent", 0))
	while index + 1 < list.size() and int(list[index + 1].get("indent", 0)) > indent:
		index += 1


## 返回 null／true 前进到下一条；false 结束本列表；字典为请求（见 advance）
func _execute(c: Dictionary):
	var p: Array = c.get("parameters", [])
	var indent := int(c.get("indent", 0))
	var code := int(c.code)
	match code:
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
				return _request("message", "choice", {"msg": msg}, int(list[index].indent))
			elif index + 1 < list.size() and int(list[index + 1].code) == 103:
				index += 1
				return _number_request(msg, list[index].parameters)
			return _request("message", "message", {"msg": msg})
		102:
			var msg := {}
			_merge_choices(index)
			_choice_params(msg, list[index].parameters)
			return _request("message", "choice", {"msg": msg}, indent)
		103:
			return _number_request({}, p)
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
			while index + 1 < list.size():
				index += 1
				if int(list[index].code) == 413 and int(list[index].indent) < indent:
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
					_child = _make_child(ce.get("list", []))
					_child._depth = _depth + 1
					_child.common_id = ce_id
					_child.pending_lines = pending_lines
					_child.receipt = receipt
					return {"kind": "child"}
		118:
			pass
		119:
			# 跳转标签（Game_Interpreter.command119 / jumpTo）：找同名标签，分支记录按缩进清空
			for i in range(list.size()):
				if int(list[i].code) == 118 and str(list[i].parameters[0]) == str(p[0]):
					_branch.clear()
					index = i
					break
		121:
			for id in range(int(p[0]), int(p[1]) + 1):
				state().set_switch(id, int(p[2]) == 0)
			_data_changed()
		122:
			_set_variables(p)
			_data_changed()
		123:
			if _event_id() > 0:
				state().set_self_switch(_map_id(), _event_id(), str(p[0]), int(p[1]) == 0)
				_data_changed()
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
			_data_changed()
		127, 128:
			var n := _operand(int(p[2]), int(p[3]))
			var kind := "weapon" if code == 127 else "armor"
			state().gain_gear(kind, int(p[0]), n if int(p[1]) == 0 else -n)
			var rec := XDB.rec("Weapons" if code == 127 else "Armors", int(p[0]))
			_treasure_popup(rec, n if int(p[1]) == 0 else -n)
			# 装备都是独立物品（YEP_ItemCore）：原版按数据库原件数 $gameParty.numItems 计，所得恒为 0，不进宝箱收获
			_record_gain(kind, int(p[0]), 0, str(rec.get("name", "")))
		129:
			if int(p[1]) == 0:
				state().add_actor(int(p[0]))
			else:
				state().remove_actor(int(p[0]))
			_data_changed()
		132:
			state().battle_bgm = (p[0] as Dictionary).duplicate() if p[0] is Dictionary else {}
		136:
			# 更改禁止遇敌 [0 禁止 1 允许]
			state().encounter_enabled = int(p[0]) != 0
		313:
			_change_actor_state(p)
		314:
			for a in _party_members():
				a.recover_all()
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
		318:
			# 增减技能 [指定方式, 角色/变量, 0 学会 1 遗忘, 技能]；角色 0 为全队
			var aid := int(p[1]) if int(p[0]) == 0 else int(state().variable(int(p[1])))
			var targets: Array = _party_members() if aid == 0 else ([state().actor(aid)] if not XDB.rec("Actors", aid).is_empty() else [])
			for a in targets:
				if int(p[2]) == 0:
					a.learn_skill(int(p[3]))
				else:
					a.forget_skill(int(p[3]))
				a.refresh_passive()
		356:
			# 要宿主画面的插件指令（怪物图鉴 EnemyBook open）交给宿主，其余在这里执行
			if _host_plugin(str(p[0])):
				return _request("command", "command", {"command": c})
			_plugin_command(str(p[0]))
		601:
			if _branch.get(indent) != 0:
				_skip_branch()
		602:
			if _branch.get(indent) != 1:
				_skip_branch()
		603:
			if _branch.get(indent) != 2:
				_skip_branch()
		_:
			if PASS_CODES.has(code):
				return null
			return _execute_env(c)
	return null


# ---- 环境钩子（子类覆盖）----

## 本核心不认的指令：地图交给宿主，战斗处理敌人相关指令；默认记进 skipped
func _execute_env(c: Dictionary):
	var p: Array = c.get("parameters", [])
	var text := str(p[0]) if p.size() > 0 else ""
	skipped.append({"code": int(c.code), "text": text.left(80)})
	return null


## 公共事件子游标（同类、同环境）；_depth、common_id、pending_lines、receipt 由调用方设置
func _make_child(commands: Array) -> MVEventCore:
	var sub := MVEventCore.new()
	sub.list = commands
	return sub


func _map_id() -> int:
	return 0


func _event_id() -> int:
	return 0


## 开关、变量、物品等改变后（地图：刷新事件页）
func _data_changed() -> void:
	pass


## MOG_TreasurePopup（地图才有）
func _treasure_popup(_rec: Dictionary, _amount: int) -> void:
	pass


## $gameParty.members()：地图是全队，战斗是出战成员
func _party_members() -> Array:
	return state().members()


## 313 [指定方式, 角色/变量, 0 附加 1 解除, 状态]
func _change_actor_state(p: Array) -> void:
	for a in _actors_ex(int(p[0]), int(p[1])):
		if int(p[2]) == 0:
			a.add_state(int(p[3]), rule_random())
		else:
			a.remove_state(int(p[3]))


## 本核心不认的条件类型；返回 null 记进 skipped 并视为不成立
func _condition_env(_p: Array):
	return null


## 本核心不认的插件指令；认得返回 true
func _plugin_env(_args: PackedStringArray, _line: String) -> bool:
	return false


## 由宿主画面执行的插件指令（地图解释器覆盖）
func _host_plugin(_line: String) -> bool:
	return false


## Game_Interpreter.gameDataOperand（变量操作数「游戏数据」）；认不出的返回 null
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


# ---- 共用指令语义 ----

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
func _number_request(msg: Dictionary, np: Array) -> Dictionary:
	var var_id := int(np[0])
	msg.digits = int(np[1])
	msg.number_value = int(state().variable(var_id))
	return _request("message", "number", {"msg": msg}, var_id)


## 插件指令：Vitsuno_Difficulty「Difficulty SetID N」；Mehmet_GhostButtons 只记标记（重制版没有虚拟按钮）；
## XdRs_HangUp「EnableHangUp / ProhibitHangUp」开关挂机（XHangUp.enabled）；其余交给 _plugin_env
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
		"EnemyBook":
			if XEnemyBook.plugin_command(state(), args):  # AB_EnemyBook 登记（八戒车道）
				return
	if _plugin_env(args, line):
		return
	skipped.append({"code": 356, "text": line.left(80)})


## Game_Interpreter.iterateActorEx：0 指定（ID 0 为全队）、1 按变量
func _actors_ex(kind: int, param: int) -> Array:
	var s := state()
	var id := param if kind == 0 else int(s.variable(param))
	if id == 0:
		return _party_members()
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


func _operand(type: int, value: int) -> int:
	return int(state().variable(value)) if type != 0 else value


func _set_variables(p: Array) -> void:
	var value := 0.0
	match int(p[3]):
		0: value = float(p[4])
		1: value = state().variable(int(p[4]))
		2: value = _variable_random(int(p[4]), int(p[5]))
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
			return _event_id() > 0 and s.self_switch(_map_id(), _event_id(), str(p[1])) == (int(p[2]) == 0)
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
	var env = _condition_env(p)
	if env != null:
		return bool(env)
	skipped.append({"code": 111, "text": "条件类型 %d" % int(p[0])})
	return false
