class_name XBattleCommonEvent
extends RefCounted
## 战斗中技能／物品带的公共事件（使用效果 44）。冻结 v0.28 的流程：
## - YEP_BattleEngineCore 把 Game_Action.applyGlobal 在战斗中关掉，改由行动序列预约：默认收尾段的 ACTION COMMON EVENT
##   （actionActionCommonEvent）把这次行动道具的每个 44 效果依次 $gameTemp.reserveCommonEvent——单槽，后一个盖前一个；
##   ActSeqPack1 的 COMMON EVENT: X 没有事件在跑时同样预约；有事件在跑时（事件里强制行动）直接给敌群解释器装子解释器
##   （setupChild，换掉已有的子解释器），强制行动结束后先跑完它再接着父事件（run_or_reserve）。
## - 行动结束后 BattleManager.updateEventMain → Game_Troop.setupBattleEvent：解释器空闲时预约的公共事件优先于敌群页
##   （setupReservedCommonEvent），跑完下一次检查再看敌群页或新的预约。YEP 的 checkBattleEnd 在行动刚结束的 actionList 阶段
##   与事件进行中都不判定，所以**打倒最后一只敌人后预约的公共事件照样跑完**（参照 thunder_battle_end：84 仍强制 533），之后才胜利；
##   重制的战斗画面在打赢／打输后、进结算前先跑一次（XBattleScene._main），无界面 run_turn 本来就先查事件。
## 重制：预约记在 XBattleLogic 的 meta "battle_ce"；XBattleLogic._drive_events 选页之前调 take 取成 XBattleEventRunner 执行，
## 指令与敌群页同一套（MVEventCore＋战斗环境），没翻译的记进 XBattleLogic.common_event_skipped（敌群页的另记 troop_event_skipped）。
## 一次事件检查里接连预约（强制行动再预约）最多 CHAIN_LIMIT 次，防止条件写错时死循环（原版会一直跑）。
## 开战：本版改过的 BattleManager.startBattle 先 reserveCommonEvent(1320)，XBattleLogic.setup 末尾同样预约（START_EVENT）。
## Star_PetSystem 的 PetGet 读「最后一个 setItem 的行动」：用道具时记在 meta "last_item_action"（XPetCapture.pet_get 读）。

const CHAIN_LIMIT := 64
## O-247：CE1365 三咒凝魄（会心法 6927 时强制 6930「三魔术*火」，6930 自己的效果 44 又是 1365）原版会一直强制下去
## （参照 2 万帧里放了 700 多次还没完）；心法写的是「额外释放一次」。true＝公共事件自己强制出来的行动再带同一个公共事件时不再预约
## （只额外放一次），false＝回到原版的无限连放（靠 CHAIN_LIMIT 截停）。
## 只认 EXTRA_ONCE_IDS 里的公共事件：CE28 风怒、CE110、CE621／979／980／985 堕天一击、CE945、CE1154 雪岭舞等同结构的
## 概率连发（每次再放都重掷，可连多次）照原版（审查第 75 期 P1-1）。
static var EXTRA_ONCE := true
const EXTRA_ONCE_IDS := [1365]
## T523：天启篇里 7492 气傲天苍是空壳（天熄乱舞／气伤链未实装），下面这些公共事件却照样会领悟它。只在天启篇存档收口，
## 西游档拿原事件。false＝回退。
## CE1406／1408（天虎令红尘一步）、CE9022（首领版 10503，写给炭治郎但他不在队也会弹提示）：删掉领悟它的那一支
## （条件、领悟、记开关、提示整段），剑思和其他领悟支照跑。
## CE1627（西西卡流派选择的火遁）：原版拿 7492 当「学过火遁」的记号。只删领悟它的那一条，随机领悟、次数和提示照旧；
## 重复判定改认火遁给的 7517／7518（原来的 7492 判定留着，认修之前学到过它的存档）。
## 读 7492 的 CE1625 只由遁术招 7826／7827 触发，这批招没有任何领悟来源，不用改。
static var TIANQI_SKIP_SHELL_LEARN := true
const TIANQI_SHELL_LEARN := {1406: 7492, 1408: 7492, 9022: 7492}
const TIANQI_FIRE_CE := 1627
const TIANQI_FIRE_MARK := 7492
const TIANQI_FIRE_LEARNED := [7517, 7518]
## 本版 BattleManager.startBattle 每场开战预约的公共事件「战斗开始时调整变量」（调 1315／1372／1373／1375，变量 13＝1 时截上限）
const START_EVENT := 1320


static func reserve(logic, id: int, user = null) -> void:
	if id > 0:
		logic.set_meta("battle_ce", id)
		# 预约它的行动者（ACTION COMMON EVENT 才有）；CE1327 再释放按它（O-149）
		if user != null:
			logic.set_meta("battle_ce_user", user)
		elif logic.has_meta("battle_ce_user"):
			logic.remove_meta("battle_ce_user")


## ActSeqPack1 actionCommonEvent：$gameTroop 事件运行中 → $gameTroop._interpreter.setupChild(list, 0)，否则预约。
## 参照 tests/fixtures/battle_common_event_child_oracle.json（mv_oracle/battle_common_event_child_probe.cjs）。
static func run_or_reserve(logic, id: int) -> void:
	if logic._runner == null:
		reserve(logic, id)
		return
	var ce := XDB.rec("CommonEvents", id)
	if not ce.is_empty():
		logic._runner.setup_child(command_list(id, ce), id)


## 公共事件实际要跑的指令表（天启篇收口见 TIANQI_SKIP_SHELL_LEARN；只返回副本，不改数据库）
static func command_list(id: int, ce: Dictionary) -> Array:
	var list: Array = ce.get("list", [])
	if not TIANQI_SKIP_SHELL_LEARN or not XTianqi.active(XState.current):
		return list
	if id == TIANQI_FIRE_CE:
		return _without_fire_mark(list)
	if TIANQI_SHELL_LEARN.has(id):
		return _without_learn_branch(list, int(TIANQI_SHELL_LEARN[id]))
	return list


## 火遁分支「111 会 7492 → 已经学过了（跳回流派选择） 411 → 领悟 7492 …」：删掉领悟 7492，并在原判定前按
## TIANQI_FIRE_LEARNED 各插一份「会它 → 已经学过了」（那段以跳转标签结尾，不会往下走）；找不到就原样返回
static func _without_fire_mark(list: Array) -> Array:
	var guard := -1
	var other := -1
	for i in list.size():
		var code := int(list[i].code)
		var p: Array = list[i].get("parameters", [])
		if code == 111 and int(p[0]) == 4 and int(p[2]) == 3 and int(p[3]) == TIANQI_FIRE_MARK:
			guard = i
			other = -1
		elif guard >= 0 and other < 0 and code == 411 and int(list[i].indent) == int(list[guard].indent):
			other = i
		elif other >= 0 and code == 318 and int(p[2]) == 0 and int(p[3]) == TIANQI_FIRE_MARK:
			var depth := int(list[guard].indent)
			var already := list.slice(guard + 1, other)
			var extra := []
			for sid in TIANQI_FIRE_LEARNED:
				var cond: Array = list[guard].parameters.duplicate()
				cond[3] = sid
				extra.append({"code": 111, "indent": depth, "parameters": cond})
				extra.append_array(already)
				extra.append({"code": 412, "indent": depth, "parameters": []})
			return list.slice(0, guard) + extra + list.slice(guard, i) + list.slice(i + 1)
	return list


## 删掉直接包着「318 领悟 skill」的最内层条件分支（111 起到同缩进的 412）；找不到就原样返回
static func _without_learn_branch(list: Array, skill: int) -> Array:
	for i in list.size():
		var p: Array = list[i].get("parameters", [])
		if int(list[i].code) != 318 or int(p[2]) != 0 or int(p[3]) != skill:
			continue
		var depth := int(list[i].indent) - 1
		var from := i
		while from >= 0 and not (int(list[from].code) == 111 and int(list[from].indent) == depth):
			from -= 1
		var to := i
		while to < list.size() and not (int(list[to].code) == 412 and int(list[to].indent) == depth):
			to += 1
		if from >= 0 and to < list.size():
			return list.slice(0, from) + list.slice(to + 1)
	return list


## ACTION COMMON EVENT：这次行动的道具里每个 44 效果依次预约（单槽，最后一个生效）
static func reserve_action(logic, user, item: Dictionary, targets: Array) -> void:
	if XBattleLogic.is_item(item):
		logic.set_meta("last_item_action", {"user": user, "item": item, "target": targets[0] if not targets.is_empty() else null})
	for e in item.get("effects", []):
		if int(e.code) == 44:
			if EXTRA_ONCE and int(e.dataId) in EXTRA_ONCE_IDS and in_common_event(logic, int(e.dataId)):
				continue
			reserve(logic, int(e.dataId), user)


## 正在跑公共事件 id（它里面强制出来的行动，其效果 44 又指回它自己）
static func in_common_event(logic, id: int) -> bool:
	var r = logic._runner
	return r != null and r.has_meta("common_event") and int(r.get_meta("common_event")) == id


## 排在当前预约之后的公共事件（奈叶领域做活 O-183 用：2478 排在开战 1320 之后，不顶掉单槽）：
## 单槽空了（预约的跑完、它自己接着预约的也跑完）才轮到队首
static func reserve_after(logic, id: int) -> void:
	if id <= 0:
		return
	var q: Array = logic.get_meta("battle_ce_after", [])
	q.append(id)
	logic.set_meta("battle_ce_after", q)

static func _promote_after(logic) -> void:
	if int(logic.get_meta("battle_ce", 0)) > 0 or not logic.has_meta("battle_ce_after"):
		return
	var q: Array = logic.get_meta("battle_ce_after")
	if q.is_empty():
		logic.remove_meta("battle_ce_after")
		return
	logic.set_meta("battle_ce", int(q.pop_front()))
	if q.is_empty():
		logic.remove_meta("battle_ce_after")


static func reserved(logic) -> int:
	_promote_after(logic)
	return int(logic.get_meta("battle_ce", 0))


static func last_item_action(logic) -> Dictionary:
	return logic.get_meta("last_item_action", {})


## setupBattleEvent 的预约分支：取走预约，返回执行游标（没有时 null）
static func take(logic) -> XBattleEventRunner:
	var id := reserved(logic)
	if id <= 0:
		return null
	var user = null
	if logic.has_meta("battle_ce_user"):
		user = logic.get_meta("battle_ce_user")
		logic.remove_meta("battle_ce_user")
	logic.remove_meta("battle_ce")
	var ce := XDB.rec("CommonEvents", id)
	if ce.is_empty():
		return null
	var n := int(logic._check.get("ce_chain", 0)) + 1
	logic._check.ce_chain = n
	if n > CHAIN_LIMIT:
		push_warning("XBattleCommonEvent: 公共事件 %d 接连预约超过 %d 次，停下" % [id, CHAIN_LIMIT])
		return null
	var r := XBattleEventRunner.new(logic, command_list(id, ce), logic._check.get("first"))
	r.set_meta("page", -1)
	r.set_meta("common_event", id)
	if user != null:
		r.set_meta("ce_user", user)
	return r
