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


## 取走已提交的记录
func take_logs() -> Array:
	var out := logs.duplicate()
	logs.clear()
	return out


func _make_child(commands: Array) -> MVEventCore:
	return XBattleEventRunner.new(logic, commands, first_subject, logs)


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
		_:
			return super(c)
	return null
