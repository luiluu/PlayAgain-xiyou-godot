class_name XActionSequence
extends RefCounted
## YEP 行动序列的规则部分（YEP_BattleEngineCore＋YEP_X_ActSeqPack1），按转换器导出的 yepSeq（与正式解析逐项一致）执行。
## - 五段 setup → whole → target → follow → finish。每段开始时目标重置为全部目标（makeTargets，含连击重复）、IF 栈清空；
##   target 段对每个个别目标各跑一遍（IF 栈在目标之间不清）。DEATH BREAK（行动者阵亡时）与 BREAK ACTION 只结束当前段。
## - IF/ELSE IF/ELSE/END 照 actionConditionsMet：假分支里的 IF 不入栈（YEP 原样）；条件由 eval_condition 按白名单求值，
##   正式版 eval 出错（如敌人没有 _skills）时为假。不认识的写法记入 unknown 并当作假。
## - 规则指令：ACTION EFFECT（可指定目标）、ADD/REMOVE STATE、HP/MP/TP ±（数值、百分比、变量）、ADD/REMOVE 能力 BUFF/DEBUFF。
##   其余（动画、移动、等待、镜头、音效、公共事件、变量、EVAL）不影响本函数的结算，跳过。
## - 与正式版的已知差异：setup 里的 IMMORTAL 让目标在序列中 HP 为 0 也不倒下，后续 ACTION EFFECT 继续命中（不再扣血）；
##   这里倒下的目标不再结算（除非技能本来以阵亡者为对象），与 dev.026 以前的行为相同。

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
		if phase == "target":
			for t in all_targets:
				targets = [t]
				_run_list(list)
				if _break:
					break
		else:
			_run_list(list)
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
		_command(name.to_upper(), args)
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
			logs.append_array(logic._invoke(user, skill, t))
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
		change = float(int(logic.state.variable(int(m.get_string(2)))))
		if m.get_string(1) == "-":
			change = -change
	else:
		m = RegEx.create_from_string("(?i)^" + kind + "[ ]([+-]\\d+)([%％])").search(name)
		if m:
			change = float(int(m.get_string(1)))
			percent = true
		else:
			m = RegEx.create_from_string("(?i)^" + kind + "[ ]([+-]\\d+)").search(name)
			if not m:
				return
			change = float(int(m.get_string(1)))
	for t in list:
		var base: float = t.mhp if kind == "HP" else (t.mmp if kind == "MP" else 100.0)
		var value := int(base * change * 0.01) if percent else int(change)
		logic.sequence_gain(t, kind, value)


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
