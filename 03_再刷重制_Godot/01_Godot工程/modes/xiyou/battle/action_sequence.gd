class_name XActionSequence
extends RefCounted
## YEP 行动序列的规则部分（YEP_BattleEngineCore＋YEP_X_ActSeqPack1），按转换器导出的 yepSeq（与正式解析逐项一致）执行。
## - 五段 setup → whole → target → follow → finish。每段开始时目标重置为全部目标（makeTargets，含连击重复）、IF 栈清空；
##   target 段对每个个别目标各跑一遍（IF 栈在目标之间不清）。DEATH BREAK（行动者阵亡时）与 BREAK ACTION 只结束当前段。
## - IF/ELSE IF/ELSE/END 照 actionConditionsMet：假分支里的 IF 不入栈（YEP 原样）；条件由 eval_condition 按白名单求值，
##   正式版 eval 出错（如敌人没有 _skills）时为假。不认识的写法记入 unknown 并当作假。
## - 规则指令：ACTION EFFECT（可指定目标）、ADD/REMOVE STATE、HP/MP/TP ±（数值、百分比、变量）、ADD/REMOVE 能力 BUFF/DEBUFF。
##   ACTION COMMON EVENT／COMMON EVENT: X 预约公共事件（XBattleCommonEvent，行动结束后由敌群事件检查执行）。
##   其余（动画、移动、等待、镜头、音效、变量、EVAL）不影响本函数的结算，跳过。
## - 画面：照执行顺序在记录里插入 seq_phase（段开始）、seq_target（target 段换下一个目标）、seq（每条执行的指令，
##   带当时的目标与画面要用的对象组）与 seq_end，由 XSequencePlayer 逐帧演出；这些条目不影响结算。
## - IMMORTAL 期间 HP 为 0 也不倒下，解除时同步阵亡；资源增减与能力增减后按 MV refresh 同步夹值与阵亡状态。

## 会改数值或状态的指令：执行后记下全体读数（状态栏、血条）
static var STATE_CMD := RegEx.create_from_string("^(?:HP|MP|TP)[ ]|^(?:ADD_STATE|ADD STATE|REMOVE_STATE|REMOVE STATE)[ ]\\d|^(?:ADD|REMOVE)[ ].*[ ](?:BUFF|DEBUFF)|^IMMORTAL$")
const PHASES := ["setup", "whole", "target", "follow", "finish"]
const PARAMS := {"MAXHP": 0, "MHP": 0, "MAX HP": 0, "HP": 0, "MAXMP": 1, "MMP": 1, "MAX MP": 1, "MP": 1, "ATK": 2, "STR": 2,
	"DEF": 3, "MAT": 4, "INT": 4, "SPI": 4, "MDF": 5, "RES": 5, "AGI": 6, "SPD": 6, "LUK": 7}

var logic: XBattleLogic
var user: XBattler
var skill: Dictionary
var all_targets: Array = []
var targets: Array = []
var logs: Array = []
var unknown: Array = []
## 画面：本条 HP/MP/TP 指令实际增减（[对象, 种类, 数值]），记进 seq 条目给伤害数字用
var _gains: Array = []
var _flags: Array = []
var _true_flags: Array = []
var _break := false


static func create(l: XBattleLogic, u: XBattler, rec: Dictionary, list: Array) -> XActionSequence:
	var s := XActionSequence.new()
	s.logic = l
	s.user = u
	s.skill = rec
	s.all_targets = list
	return s


## 有 yepSeq 才走序列；没有（旧数据）时调用方按 repeats 处理
static func has_sequence(rec: Dictionary) -> bool:
	return rec.get("yepSeq") is Dictionary


func run() -> Array:
	var seq: Dictionary = skill.yepSeq
	for phase in PHASES:
		targets = all_targets.duplicate()
		_flags.clear()
		_true_flags.clear()
		_break = false
		var list: Array = seq.get(phase, [])
		logs.append({"type": "seq_phase", "phase": phase, "empty": list.is_empty()})
		if phase == "target":
			# createTargetActions：没有目标时仍以空目标跑一遍（setTargets([undefined])）
			var first := true
			for t in (all_targets if not all_targets.is_empty() else [null]):
				if not first:
					logs.append({"type": "seq_target"})
				first = false
				targets = [t] if t != null else []
				_run_list(list)
				if _break:
					break
		else:
			_run_list(list)
	logs.append({"type": "seq_end"})
	return logs


func _run_list(list: Array) -> void:
	for entry in list:
		var name := str(entry[0])
		var args: Array = entry[1] if entry.size() > 1 else []
		if not _conditions_met(name):
			continue
		var m := RegEx.create_from_string("(?i)IF[ ](.*)").search(name)
		if m:
			var v = eval_condition(m.get_string(1))
			_flags.append(v == true)
			_true_flags.append(false)
			continue
		var mark := _visual_entry(name.to_upper(), args)
		logs.append(mark)
		_gains = []
		_command(name.to_upper(), args)
		if not _gains.is_empty():
			mark.gains = _gains
		if STATE_CMD.search(mark.name):
			mark.views = logic.views()
		mark.broke = _break
		mark.user_dead = user.is_dead()
		if _break:
			return


## BattleManager.actionConditionsMet
func _conditions_met(name: String) -> bool:
	var ci := _flags.size() - 1
	var m := RegEx.create_from_string("(?i)ELSE[ ]IF[ ](.*)").search(name)
	if m:
		if _flags.is_empty():
			return false
		if _flags[ci]:
			_flags[ci] = false
			_true_flags[ci] = true
		elif not _true_flags[ci]:
			var v = eval_condition(m.get_string(1))
			_flags[ci] = v == true
			_true_flags[ci] = v == true
		return false
	if RegEx.create_from_string("(?i)ELSE[ ]*(.*)").search(name):
		if _flags.is_empty():
			return false
		if _flags[ci]:
			_flags[ci] = false
			_true_flags[ci] = true
		elif not _true_flags[ci]:
			_flags[ci] = true
			_true_flags[ci] = true
		return false
	if name.to_upper() == "END":
		if _flags.is_empty():
			return false
		_flags.pop_back()
		_true_flags.pop_back()
		return false
	return _flags.is_empty() or _flags[ci]


func _command(name: String, args: Array) -> void:
	if name == "ACTION EFFECT":
		var list := make_targets(str(args[0])) if not args.is_empty() and str(args[0]) != "" else targets
		for t in list:
			if t == null:
				continue
			if t.is_dead() and not [9, 10].has(int(skill.get("scope", 0))):
				continue
			logs.append_array(logic.mark_views(logic._invoke(user, skill, t)))
		return
	if name == "ACTION COMMON EVENT":
		XBattleCommonEvent.reserve_action(logic, user, skill, all_targets)  # actionActionCommonEvent：44 效果依次预约（单槽）
		return
	if name == "COMMON EVENT":
		XBattleCommonEvent.reserve(logic, int(str(args[0]).to_int()) if not args.is_empty() else 0)  # ActSeqPack1 actionCommonEvent
		return
	if name == "CAT BEGIN" or name == "CAT STRIKE":
		# 小猫剑圣包装 processActionSequence：178 的四个剑技在这里打完全部剑段（XCat.cast）；其余情况原版也什么都不做
		if XCat.casts(user, skill):
			logs.append_array(XCat.cast(logic, user, skill, targets[0] if not targets.is_empty() else null))
		return
	if name == "IMMORTAL":
		# actionImmortal：参数二 eval 成真＝加，否则解除；解除时 HP 为 0 的倒下（removeImmortal → refresh）
		var on := not args.is_empty() and args.size() > 1 and str(args[1]).to_lower() == "true"
		var seen := []
		for t in make_targets(str(args[0]) if not args.is_empty() else ""):
			if seen.has(t):
				continue
			seen.append(t)
			if on:
				t.immortal = true
				continue
			t.param_refresh()  # removeImmortal 对每个目标都 refresh
			if t.immortal:
				t.immortal = false
				if t.hp <= 0.0 and not t.state_ids.has(XBattleLogic.DEATH_STATE):
					logic._die(t)
					logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
		return
	if name == "DEATH BREAK" or name == "BREAK ACTION":
		if name == "BREAK ACTION" or user.is_dead():
			_break = true
		return
	var m := RegEx.create_from_string("^(?:ADD_STATE|ADD STATE)[ ](\\d+(?:\\s*,\\s*\\d+)*)").search(name)
	if m:
		for t in make_targets(str(args[0]) if not args.is_empty() else ""):
			for id in _ids(m.get_string(1)):
				logic.sequence_add_state(t, id)
		return
	m = RegEx.create_from_string("^(?:REMOVE_STATE|REMOVE STATE)[ ](\\d+(?:\\s*,\\s*\\d+)*)").search(name)
	if m:
		for t in make_targets(str(args[0]) if not args.is_empty() else ""):
			for id in _ids(m.get_string(1)):
				if t.is_state_affected(id):
					t.remove_state(id)
		return
	m = RegEx.create_from_string("^(HP|MP|TP)[ ](.*)").search(name)
	if m:
		_modify(m.get_string(1), name, make_targets(str(args[0]) if not args.is_empty() else ""))
		return
	m = RegEx.create_from_string("^(ADD|REMOVE)[ ](.*)[ ](BUFF|DEBUFF)").search(name)
	if m:
		var pid: int = PARAMS.get(m.get_string(2).strip_edges(), -1)
		if pid < 0:
			return
		var turns := int(args[1]) if args.size() > 1 and int(args[1]) > 0 else 5
		for t in make_targets(str(args[0]) if not args.is_empty() else ""):
			logic.sequence_buff(t, pid, m.get_string(1) == "ADD", m.get_string(3) == "BUFF", turns)
		return


static func _ids(text: String) -> Array:
	return Array(text.split(",")).map(func(x): return int(x.strip_edges()))


## actionHpModify / actionMpModify / actionTpModify：变量写法在前（带 % 的变量写法因此永远走不到，照原样）
func _modify(kind: String, name: String, list: Array) -> void:
	var change := 0.0
	var percent := false
	var m := RegEx.create_from_string("(?i)^" + kind + "[ ]([+-])(?:VARIABLE|VAR)[ ](\\d+)").search(name)
	if m:
		change = js_parse_int(logic.state.variable(int(m.get_string(2))))
		if m.get_string(1) == "-":
			change = -change
	else:
		m = RegEx.create_from_string("(?i)^" + kind + "[ ]([+-]\\d+)([%％])").search(name)
		if m:
			change = float(m.get_string(1).to_float())
			percent = true
		else:
			m = RegEx.create_from_string("(?i)^" + kind + "[ ]([+-]\\d+)").search(name)
			if not m:
				return
			change = m.get_string(1).to_float()  # parseInt(很长的数字串) 是大浮点数
	for t in list:
		var base: float = t.mhp if kind == "HP" else (t.mmp if kind == "MP" else t.max_tp())
		var v := js_parse_int(base * change * 0.01 if percent else change)
		_gains.append([t, kind, logic.sequence_gain(t, kind, v, user)])


## JS parseInt(数字)：先转成字符串，绝对值 ≥ 1e21 时是指数写法，只取到小数点/e 之前（-1e+33 → -1）
static func js_parse_int(v: float) -> float:
	if absf(v) >= 1e21 or (absf(v) > 0.0 and absf(v) < 1e-6):
		var mantissa := absf(v) / pow(10.0, floorf(log(absf(v)) / log(10.0)))
		# log(10^n) 的舍入可能让指数少 1；规范化后再取首位。
		while mantissa >= 10.0:
			mantissa /= 10.0
		while mantissa < 1.0:
			mantissa *= 10.0
		return floorf(mantissa) * (-1.0 if v < 0 else 1.0)
	return floorf(absf(v)) * (-1.0 if v < 0 else 1.0)


## BattleManager.makeActionTargets（序列里实际用到的写法；其余写法照原版得到空表）
func make_targets(spec: String) -> Array:
	var s := spec.to_upper()
	var friends := logic.actors if user is XActor else logic.enemies
	var foes := logic.enemies if user is XActor else logic.actors
	match s:
		"SUBJECT", "USER":
			return [user]
		"TARGET", "TARGETS":
			return targets.filter(func(t): return t != null)
		"ACTORS", "EXISTING ACTORS", "ALIVE ACTORS":
			return logic.alive(logic.actors)
		"ACTORS ALL", "ALL ACTORS", "PARTY":
			return logic.actors.duplicate()
		"ENEMIES", "EXISTING ENEMIES", "ALIVE ENEMIES", "TROOP", "TROOPS":
			return logic.alive(logic.enemies)
		"ENEMIES ALL", "ALL ENEMIES":
			return logic.enemies.duplicate()
		"FRIEND", "FRIENDS", "ALLIES":
			return logic.alive(friends)
		"OPPONENT", "OPPONENTS", "RIVALS", "FOES":
			return logic.alive(foes)
		"ALL ALIVE":
			return logic.alive(logic.actors) + logic.alive(logic.enemies)
	return []


# ---- 画面 ----
## 指令名里的对象（MOVE/FACE/FLOAT/JUMP/OPACITY 后面那段）与第一个参数，按执行当时的状态解析好（BattleManager.makeActionTargets）
func _visual_entry(name: String, args: Array) -> Dictionary:
	var e := {"type": "seq", "name": name, "args": args, "user": user, "targets": targets.filter(func(t): return t != null),
		"moves": logic.move_flags()}
	var m := RegEx.create_from_string("^(?:FACE|FLOAT|JUMP|MOVE|OPACITY)[ ](.*)$").search(name)
	if m:
		e.sub = visual_targets(m.get_string(1))
	if not args.is_empty():
		e.a0 = visual_targets(str(args[0]))
		# FACE …：朝向的参照组（FACE 目标 / AWAY FROM 目标）也按执行当时解析
		if name.begins_with("FACE "):
			var cmd := str(args[0]).to_upper()
			e.face_group = visual_targets(cmd.substr(10) if cmd.begins_with("AWAY FROM ") else cmd)
	return e


## YEP makeActionTargets 的全部写法（画面用；不改规则用的 make_targets）
func visual_targets(spec: String) -> Array:
	var s := spec.strip_edges().to_upper()
	var mine: Array = logic.actors if user is XActor else logic.enemies
	var foes: Array = logic.enemies if user is XActor else logic.actors
	var live := func(list: Array) -> Array: return logic.alive(list)
	var dead := func(list: Array) -> Array: return list.filter(func(b): return b.is_dead())
	var not_user := func(list: Array) -> Array: return logic.alive(list).filter(func(b): return b != user)
	match s:
		"SUBJECT", "USER": return [user]
		"TARGET", "TARGETS": return targets.filter(func(t): return t != null)
		"ACTORS", "EXISTING ACTORS", "ALIVE ACTORS": return live.call(logic.actors)
		"ACTORS ALL", "ALL ACTORS", "PARTY": return logic.actors.duplicate()
		"DEAD ACTORS", "DEAD ACTOR": return dead.call(logic.actors)
		"ACTORS NOT USER", "ACTORS NOT SUBJECT": return not_user.call(logic.actors)
		"ENEMIES", "EXISTING ENEMIES", "ALIVE ENEMIES", "TROOP", "TROOPS": return live.call(logic.enemies)
		"ENEMIES ALL", "ALL ENEMIES": return logic.enemies.duplicate()
		"DEAD ENEMIES", "DEAD ENEMY": return dead.call(logic.enemies)
		"ENEMIES NOT USER", "ENEMIES NOT SUBJECT", "TROOP NOT USER", "TROOP NOT SUBJECT": return not_user.call(logic.enemies)
		"FRIEND", "FRIENDS", "ALLIES": return live.call(mine)
		"ALL FRIENDS", "ALL ALLIES": return mine.duplicate()
		"DEAD FRIEND", "DEAD FRIENDS", "DEAD ALLIES": return dead.call(mine)
		"OPPONENT", "OPPONENTS", "RIVALS", "FOES": return live.call(foes)
		"ALL OPPONENTS", "ALL RIVALS", "ALL FOES": return foes.duplicate()
		"DEAD OPPONENT", "DEAD OPPONENTS", "DEAD RIVALS", "DEAD FOES": return dead.call(foes)
		"FRIENDS NOT USER", "ALLIES NOT USER": return not_user.call(mine)
		"ALL ALIVE": return live.call(mine) + live.call(foes)
		"ALL MEMBERS": return mine + foes
		"ALL DEAD": return dead.call(mine) + dead.call(foes)
		"ALL NOT USER": return not_user.call(mine) + not_user.call(foes)
		"FOCUS", "PARTICIPANTS":
			var list := targets.filter(func(t): return t != null)
			if not list.has(user):
				list.append(user)
			return list
		"NOT FOCUS", "NONPARTICIPANTS":
			# 倒下的敌人不算（侧视敌人倒下后仍显示的除外，这里没有）；倒下的角色仍算
			return (mine + foes).filter(func(b): return b != user and not targets.has(b) and (b.is_alive() or b is XActor))
		"FIRST":
			return [targets[0]] if not targets.is_empty() and targets[0] != null else []
	var m := RegEx.create_from_string("^ACTOR[ ](\\d+)").search(s)
	if m:
		var i := int(m.get_string(1))
		return [logic.actors[i]] if i < logic.actors.size() else []
	m = RegEx.create_from_string("^ENEMY[ ](\\d+)").search(s)
	if m:
		var i := int(m.get_string(1))
		return [logic.enemies[i]] if i < logic.enemies.size() else []
	m = RegEx.create_from_string("(?:FRIEND|ALLY)[ ](\\d+)").search(s)
	if m:
		var i := int(m.get_string(1))
		return [mine[i]] if i < mine.size() else []
	m = RegEx.create_from_string("(?:OPPONENT|FOE|RIVAL)[ ](\\d+)").search(s)
	if m:
		var i := int(m.get_string(1))
		return [foes[i]] if i < foes.size() else []
	m = RegEx.create_from_string("(?:CHAR|CHARA|CHARACTER)[ ](\\d+)").search(s)
	if m:
		return logic.actors.filter(func(a): return (a as XActor).actor_id == int(m.get_string(1)))
	return []


# ---- 条件 ----
## 正式版 eval(text) 的白名单翻译：按 &&、|| 拆开（无括号嵌套），逐项求值；出错（原版抛异常）整体为假。
func eval_condition(raw: String):
	var text := raw
	var c := text.find("//")
	if c >= 0:
		text = text.substr(0, c)
	text = text.strip_edges()
	var ors := text.split("||")
	var any := false
	for part in ors:
		var all := true
		for atom in part.split("&&"):
			var v = _atom(atom.strip_edges())
			if v == null:
				return false
			if not v:
				all = false
		if all:
			any = true
	return any


func _atom(a: String):
	var target: XBattler = targets[0] if not targets.is_empty() else null
	var m: RegExMatch
	m = _re("^(user|target)\\._skills\\.includes\\((\\d+)\\)$").search(a)
	if m:
		var b := _who(m.get_string(1), target)
		if not (b is XActor):
			return null
		return (b as XActor).skill_ids.has(int(m.get_string(2)))
	m = _re("^user\\.hasSkill\\((\\d+)\\)$").search(a)
	if m:
		if not (user is XActor):
			return null
		return (user as XActor).skill_ids.has(int(m.get_string(1)))
	m = _re("^user\\.has(Armor|Weapon)\\(\\$data(Armors|Weapons)\\[(\\d+)\\]\\)$").search(a)
	if m:
		if not (user is XActor):
			return null
		return (user as XActor).has_base_equip("armor" if m.get_string(1) == "Armor" else "weapon", int(m.get_string(3)))
	m = _re("^user\\.attackMotion\\(\\)\\s*(!==|===|!=|==)\\s*'(\\w+)'$").search(a)
	if m:
		var eq: bool = attack_motion(user) == m.get_string(2)
		return not eq if m.get_string(1).begins_with("!") else eq
	m = _re("^(user|target)\\._states\\.includes\\((\\d+)\\)$").search(a)
	if m:
		var b := _who(m.get_string(1), target)
		return null if b == null else b.state_ids.has(int(m.get_string(2)))
	m = _re("^user\\.friendsUnit\\(\\)\\.aliveMembers\\(\\)\\[(\\d+)\\]\\.isStateAffected\\((\\d+)\\)$").search(a)
	if m:
		var alive := logic.alive(logic.actors if user is XActor else logic.enemies)
		var i := int(m.get_string(1))
		if i >= alive.size():
			return null
		return (alive[i] as XBattler).is_state_affected(int(m.get_string(2)))
	m = _re("^user\\.friendsUnit\\(\\)\\.aliveMembers\\(\\)\\[(\\d+)\\]\\s*!=\\s*user$").search(a)
	if m:
		var alive := logic.alive(logic.actors if user is XActor else logic.enemies)
		var i := int(m.get_string(1))
		return true if i >= alive.size() else alive[i] != user
	m = _re("^user\\.friendsUnit\\(\\)\\.aliveMembers\\(\\)\\.length\\s*(>=|<=|>|<|==|===)\\s*(\\d+)$").search(a)
	if m:
		return _compare(float(logic.alive(logic.actors if user is XActor else logic.enemies).size()), m.get_string(1), float(m.get_string(2)))
	m = _re("^(user|target)\\.states\\(\\)\\.length\\s*(>=|<=|>|<|==|===)\\s*(\\d+)$").search(a)
	if m:
		var b := _who(m.get_string(1), target)
		return null if b == null else _compare(float(b.states().size()), m.get_string(2), float(m.get_string(3)))
	m = _re("^(user|target)\\.(agi|atk|def|mat|mdf|luk|hp|mp|mhp|mmp|tp)\\s*(>=|<=|>|<|==|===)\\s*(user|target)?\\.?(agi|atk|def|mat|mdf|luk|hp|mp|mhp|mmp|tp)?(\\d+(?:\\.\\d+)?)?$").search(a)
	if m:
		var left := _who(m.get_string(1), target)
		if left == null:
			return null
		var right: float
		if m.get_string(6) != "":
			right = float(m.get_string(6))
		else:
			var rb := _who(m.get_string(4), target)
			if rb == null or m.get_string(5) == "":
				return null
			right = float(rb.get(m.get_string(5)))
		return _compare(float(left.get(m.get_string(2))), m.get_string(3), right)
	if a == "true":
		return true
	if a == "false":
		return false
	unknown.append(a)
	return null


func _who(name: String, target: XBattler) -> XBattler:
	return user if name == "user" else target


static func _compare(l: float, op: String, r: float) -> bool:
	match op:
		">=": return l >= r
		"<=": return l <= r
		">": return l > r
		"<": return l < r
	return l == r


static func _re(p: String) -> RegEx:
	return RegEx.create_from_string(p)


## YEP_BattleEngineCore Game_Actor.attackMotion：第一把武器的武器类型 → System attackMotions 的 type（0 突刺 1 挥舞 2 射击）；
## 敌人与无对应类型时为 thrust。
static func attack_motion(b: XBattler) -> String:
	if not (b is XActor):
		return "thrust"
	var w := (b as XActor).first_weapon()
	var wtype := int(w.get("wtypeId", 0)) if not w.is_empty() else 0
	var motions: Array = XDB.system().get("attackMotions", [])
	if wtype < 0 or wtype >= motions.size() or not motions[wtype] is Dictionary:
		return "thrust"
	return ["thrust", "swing", "missile"][clampi(int(motions[wtype].get("type", 0)), 0, 2)]
