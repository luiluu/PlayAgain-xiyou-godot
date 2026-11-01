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


## 按角色号加／解状态（CE43「PUA」给 13～15 加 708、CE92、CE1094 给 82 加 896～899 等）：
##   var a1 = $gameActors.actor(K); … 之后若干 a1.addState(S); / a1.removeState(S);（整段都认得才执行）。
## 原版 $gameActors.actor(K) 不看在不在队：在战斗里的走战斗加状态（抗性、倒下照 addState），不在队的直接加在角色身上
## （参照 script_gaps actorStates.inParty／notInParty：两种都加上）。
func _actor_states_script(code: String) -> bool:
	var js := _compact_js(code)
	var who := {}
	var head := RegEx.create_from_string("^var(\\w+)=\\$gameActors\\.actor\\((\\d+)\\);")
	var m := head.search(js)
	while m != null:
		who[m.get_string(1)] = int(m.get_string(2))
		js = js.substr(m.get_end())
		m = head.search(js)
	if who.is_empty():
		return false
	var ops := []
	var op := RegEx.create_from_string("^(\\w+)\\.(addState|removeState)\\((\\d+)\\);?")
	while js != "":
		m = op.search(js)
		if m == null or not who.has(m.get_string(1)):
			return false
		ops.append([who[m.get_string(1)], m.get_string(2), int(m.get_string(3))])
		js = js.substr(m.get_end())
	if ops.is_empty():
		return false
	for o in ops:
		if XDB.rec("Actors", o[0]).is_empty():
			return true   # 原版读到 null 抛错、YEP 吞掉：这句起都不做
		var b = null
		for a in logic.actors:
			if a != null and int(a.actor_id) == o[0]:
				b = a
		if o[1] == "addState":
			if b != null:
				logic.sequence_add_state(b, o[2])
				b.refresh_resources()
			else:
				state().actor(o[0]).add_state(o[2])
		elif b != null:
			b.remove_state(o[2])
		else:
			state().actor(o[0]).remove_state(o[2])
	return true


## 去注释、去空白后的脚本（下面两段只认这种紧凑写法，脚本里没有字符串）
static func _compact_js(code: String) -> String:
	return RegEx.create_from_string("\\s+").sub(RegEx.create_from_string("//[^\\n]*").sub(code, "", true), "", true)


## 公共事件 1373「血脉数量统计」：var actor = $gameActors.actor(N); 之后若干段
##   for(var i=A;i<B;i++){ if(actor.hasSkill(i)){ var j = $gameVariables.value(V); $gameVariables.setValue(V, j+1); } }
## 角色 N 每会（hasSkill：含特性附加）一个 [A, B) 里的技能，变量 V 加一。整段都认得才执行。
func _count_skills_script(code: String) -> bool:
	var js := _compact_js(code)
	var head := RegEx.create_from_string("^var(\\w+)=\\$gameActors\\.actor\\((\\d+)\\);").search(js)
	if head == null:
		return false
	var who := head.get_string(1)
	var aid := int(head.get_string(2))
	js = js.substr(head.get_end())
	var re := RegEx.create_from_string("^for\\(var(\\w+)=(\\d+);\\1<(\\d+);\\1\\+\\+\\)\\{if\\(" + who
		+ "\\.hasSkill\\(\\1\\)\\)\\{var(\\w+)=\\$gameVariables\\.value\\((\\d+)\\);\\$gameVariables\\.setValue\\(\\5,\\4\\+1\\);\\}\\}")
	var loops := []
	while js != "":
		var m := re.search(js)
		if m == null:
			return false
		loops.append([int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(5))])
		js = js.substr(m.get_end())
	if loops.is_empty():
		return false
	if XDB.rec("Actors", aid).is_empty():
		return true
	var learned := {}
	for k in state().actor(aid).skills():
		learned[int(k.id)] = true
	for lp in loops:
		for id in range(lp[0], lp[1]):
			if learned.has(id):
				state().set_variable(lp[2], state().variable(lp[2]) + 1)
	return true


## 公共事件 1375「半人马上阵统计」：出战成员里角色 ID 在数组中的个数加到变量 V，再减一（「减去自身」）。
##   var ids = [41, 42, 43, 44]; var actors = $gameParty.battleMembers();
##   actors.forEach(function(actor) { if (ids.includes(actor.actorId())) { var j = …value(V); …setValue(V, j+1); } });
##   var j = $gameVariables.value(V); $gameVariables.setValue(V, j-1);
func _count_members_script(code: String) -> bool:
	var re := RegEx.create_from_string("^var(\\w+)=\\[([\\d,]+)\\];var(\\w+)=\\$gameParty\\.battleMembers\\(\\);\\3\\.forEach\\(function\\((\\w+)\\)\\{if\\(\\1\\.includes\\(\\4\\.actorId\\(\\)\\)\\)\\{var(\\w+)=\\$gameVariables\\.value\\((\\d+)\\);\\$gameVariables\\.setValue\\(\\6,\\5\\+1\\);\\}\\}\\);var(\\w+)=\\$gameVariables\\.value\\(\\6\\);\\$gameVariables\\.setValue\\(\\6,\\7-1\\);$")
	var m := re.search(_compact_js(code))
	if m == null:
		return false
	var ids := Array(m.get_string(2).split(",")).map(func(x): return int(x))
	var v := int(m.get_string(6))
	var n := logic.actors.filter(func(a): return a != null and ids.has(int(a.actor_id))).size()
	state().set_variable(v, state().variable(v) + n - 1)
	return true


## 331 改敌人 HP [敌人序号（<0 全体）, 0 增／1 减, 0 常数／1 变量, 数值, 允许倒下]（command331 → changeHp）：
## 只改活着的；不允许倒下时减到 1；gainHp 走护盾与夹值（XBattleLogic.sequence_gain，HP 归零即倒下），不弹伤害数字
func _change_enemy_hp(p: Array) -> void:
	var value := float(_operand(int(p[2]), int(p[3])))
	if int(p[1]) != 0:
		value = -value
	for i in logic._enemy_slots(int(p[0])):
		var e: XEnemy = logic.enemies[i]
		if not e.is_alive():
			continue
		var v := value
		if not bool(p[4]) and e.hp <= -v:
			v = 1.0 - e.hp
		var before := logic._enemy_reading(e)
		logic.sequence_gain(e, "HP", v)
		logs.append(logic._enemy_change("hp", i, before))


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
		331:
			_change_enemy_hp(p)
		250:
			logs.append({"type": "se", "se": p[0]})  # 播放音效（CE46 一掷千金，战斗场合）：画面层 XBattleScene.play_se 放
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
			if _member_states_script(code) or _count_skills_script(code) or _count_members_script(code) or _actor_states_script(code):
				index = at
				return null
			if code.strip_edges() == "Star.PetSystem.PetGet()":  # 公共事件 173：捕获网（XPetCapture）
				logs.append_array(XPetCapture.pet_get(logic))
				index = at
				return null
			# 整段只有一条 $gameVariables.setValue(N, 数字)（公共事件 1401「敌人恢复所有血量」：先把变量 40 设成极大值）；
			# JS 数字按双精度，9999999999999999 读成 1e16
			var sv := RegEx.create_from_string("^\\$gameVariables\\.setValue\\(\\s*(\\d+)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\s*\\);?$").search(code.strip_edges())
			if sv != null:
				state().set_variable(int(sv.get_string(1)), float(sv.get_string(2)))
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
