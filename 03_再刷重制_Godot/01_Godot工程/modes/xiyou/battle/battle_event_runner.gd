class_name XBattleEventRunner
extends MVEventCore
## 战斗内事件（敌群事件页）的游标：指令语义在共用核心 MVEventCore，这里只接战斗环境（Game_Troop／BattleManager）。
## XBattleLogic 逐步调 advance()：
##   message          101 文字（及选项、数值输入）：规则停在游标处，画面显示后由 XBattleLogic.resume_event 续上
##   forced_action    339 强制行动已当场结算，记录已写进 logs；调用方直接继续 advance
##   done             本页执行完
## 不引用 XMessageBox 或场景节点；logs 是本页（含公共事件子游标）已提交的记录，父子共用同一个数组。

var logic: XBattleLogic
## 回合开始时已取出的首位行动者（被强制行动时清掉它本回合的普通行动，见 XBattleLogic._force_action）
var first_subject: XBattler = null
var logs: Array = []


func _init(l: XBattleLogic = null, commands: Array = [], first: XBattler = null, shared_logs = null) -> void:
	logic = l
	list = commands
	first_subject = first
	if shared_logs != null:
		logs = shared_logs


func state() -> XState:
	return logic.state


func rule_random() -> XRandomStream:
	return logic._rule()


func _random_event_key() -> String:
	return str(logic.turn)


## 取走已提交的记录
func take_logs() -> Array:
	var out := logs.duplicate()
	logs.clear()
	return out


func _make_child(commands: Array) -> MVEventCore:
	return XBattleEventRunner.new(logic, commands, first_subject, logs)


## 公共事件 1393「天锁地缚」（Map055 引路人第 3 页）的脚本：
##   var actorN = $gameParty.battleMembers()[k]; … if (actorN && $gameVariables.value(V)<=M) { actorN.addState(S); }
## 按出战成员下标与变量条件附加状态（同 313 的附加：logic.sequence_add_state）。整段都认得才执行，返回 true；否则不动、返回 false。
func _member_states_script(code: String) -> bool:
	var js := RegEx.create_from_string("//[^\\n]*").sub(code, "", true)
	var slots := {}
	for m in RegEx.create_from_string("var\\s+(\\w+)\\s*=\\s*\\$gameParty\\.battleMembers\\(\\)\\[(\\d+)\\]\\s*;?").search_all(js):
		slots[m.get_string(1)] = int(m.get_string(2))
		js = js.replace(m.get_string(0), "")
	var ops := []
	var re := RegEx.create_from_string("if\\s*\\(\\s*(\\w+)\\s*&&\\s*\\$gameVariables\\.value\\((\\d+)\\)\\s*<=\\s*(\\d+)\\s*\\)\\s*\\{\\s*(\\w+)\\.addState\\((\\d+)\\)\\s*;?\\s*\\}")
	for m in re.search_all(js):
		if not slots.has(m.get_string(1)) or m.get_string(4) != m.get_string(1):
			return false
		ops.append([slots[m.get_string(1)], int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(5))])
		js = js.replace(m.get_string(0), "")
	if slots.is_empty() or ops.is_empty() or js.strip_edges() != "":
		return false
	var members: Array = logic.actors
	for op in ops:
		if op[0] < members.size() and members[op[0]] != null and state().variable(op[1]) <= op[2]:
			logic.sequence_add_state(members[op[0]], op[3])
			members[op[0]].refresh_resources()
	return true


## 战斗中 $gameParty.members() 是出战成员
func _party_members() -> Array:
	return logic.actors


func _change_actor_state(p: Array) -> void:
	logic._change_actor_state(p)


## 敌人 [5, 序号, 0 出现／1 状态, 状态]（command111：出现即 isAlive）
func _condition_env(p: Array):
	if int(p[0]) == 5:
		var e := logic.enemy_at(int(p[1]))
		if e == null:
			return false
		return e.is_alive() if int(p[2]) == 0 else e.is_state_affected(int(p[3]))
	return null


## 游戏数据 4：敌人 [序号, 0 HP 1 MP 2～9 能力值]（gameDataOperand）
func _game_data(type: int, p1: int, p2: int):
	if type == 4:
		var e := logic.enemy_at(p1)
		if e == null:
			return 0
		match p2:
			0: return e.hp
			1: return e.mp
		if p2 >= 2 and p2 <= 9:
			return e.param(p2 - 2)
		return 0
	return super(type, p1, p2)


## 战斗背景卷动（插件 battleback … scroll speed）：只是画面，记一条记录给画面层，不影响规则
func _plugin_env(args: PackedStringArray, line: String) -> bool:
	if str(args[0]).to_lower() == "battleback":
		logs.append({"type": "event_view", "plugin": line})
		return true
	return false


func _execute_env(c: Dictionary):
	var p: Array = c.get("parameters", [])
	match int(c.code):
		333:
			logic._change_enemy_state(p)
		334:
			logs.append_array(logic.enemy_recover_all(int(p[0])))
		335:
			logs.append_array(logic.enemy_appear(int(p[0])))
		336:
			logs.append_array(logic.enemy_transform(int(p[0]), int(p[1])))
		339:
			logs.append_array(logic._force_action(p, first_subject))
			index += 1
			return {"kind": "forced_action"}
		355:
			var code := str(p[0])
			var at := index
			while at + 1 < list.size() and int(list[at + 1].code) == 655:
				at += 1
				code += "\n" + str(list[at].parameters[0])
			if _member_states_script(code):
				index = at
				return null
			if code.strip_edges() == "Star.PetSystem.PetGet()":  # 公共事件 173：捕获网（XPetCapture）
				logs.append_array(XPetCapture.pet_get(logic))
				index = at
				return null
			# 整段只有一条 $.toaster（技能公共事件里的「当前剑思为 N」之类）：文字照地图的 MVScript 拼，记成提示
			var one := code.strip_edges()
			if RegEx.create_from_string("^\\$\\.toaster\\(\\{[^;]*\\}\\);?$").search(one) != null and MVScript._toaster_text(one) != "":
				logs.append({"type": "toast", "text": MVScript._toaster_text(one)})
				index = at
				return null
			return super(c)
		_:
			return super(c)
	return null
