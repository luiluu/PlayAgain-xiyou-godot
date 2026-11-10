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


## 覆盖记录（只给对照测试用，默认 null＝关，不改游戏行为；cc events13）：设成字典后每执行一条指令记「位置:下标」——
## 敌群页根游标记 tTpP（T 敌群号、P 页号），公共事件（117 子游标或预约公共事件的根游标）记 ceN，其余子游标不记。
## 101 连带消费的 401／102 续行下标也算执行到（同 xiyou_event_compare 的 CoverInterp）。
static var COVER = null


func _execute(c: Dictionary):
	if COVER == null:
		return super._execute(c)
	var where := _cover_where()
	var start := index
	var r = super._execute(c)
	if where != "":
		var last := index if int(c.code) == 101 else start
		for i in range(start, last + 1):
			COVER["%s:%d" % [where, i]] = true
	return r


func _cover_where() -> String:
	if common_id > 0:
		return "ce%d" % common_id
	if has_meta("common_event"):
		return "ce%d" % int(get_meta("common_event"))
	if _depth == 0 and has_meta("page") and int(get_meta("page")) >= 0 and logic != null:
		return "t%dp%d" % [int(logic.troop_id), int(get_meta("page"))]
	return ""


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


## 投石问路（CE2486，技能 7188）：每个敌人一条提示 (i+1)+'号敌人暴闪为'+cev.toFixed(2)*100+'%!'（$gameTroop.members() 含倒下的）。
## 参照 script_gaps troopCev。toFixed(2) 是字符串，乘 100 转回数字：0.07→7.000000000000001 这类照 JS 数字转字符串。
func _troop_cev_script(code: String) -> bool:
	if _compact_js(code) != "for(vari=0;i<$gameTroop.members().length;i++){$.toaster({message:(i+1)+'号敌人暴闪为'+$gameTroop.members()[i].cev.toFixed(2)*100+'%!'});}":
		return false
	for i in logic.enemies.size():
		var fixed := float("%.2f" % logic.enemies[i].xparam(3))
		logs.append({"type": "toast", "text": str(i + 1) + "号敌人暴闪为" + MVScript.js_number(fixed * 100.0) + "%!"})
	return true


## 猛击（CE78，技能 459）这类：for(let i = 1; i < N; i++){ var actor = $gameActors.actor(i); if(actor._states.includes(S) && actor.hasArmor($dataArmors[A])) {
##   var members = $gameTroop.members(), length = members.length; for(let i = 0; i < length; i++){members[i].addState(T);} } }
## 角色 1～N−1 里有一个带状态 S 且身上穿着防具 A，就给全体敌人加状态 T（倒下的加不上，同 addState）。参照 script_gaps setArmorState.*。
func _set_armor_troop_state_script(code: String) -> bool:
	var m := RegEx.create_from_string("^for\\(leti=1;i<(\\d+);i\\+\\+\\)\\{varactor=\\$gameActors\\.actor\\(i\\);if\\(actor\\._states\\.includes\\((\\d+)\\)&&actor\\.hasArmor\\(\\$dataArmors\\[(\\d+)\\]\\)\\)\\{varmembers=\\$gameTroop\\.members\\(\\),length=members\\.length;for\\(leti=0;i<length;i\\+\\+\\)\\{members\\[i\\]\\.addState\\((\\d+)\\);\\}\\}\\}$").search(_compact_js(code))
	if m == null:
		return false
	var marker := int(m.get_string(2))
	var armor := int(m.get_string(3))
	for i in range(1, int(m.get_string(1))):
		if XDB.rec("Actors", i).is_empty():
			return true   # 原版读 null 的 _states 抛错、YEP 吞掉：后面的都不做
		var a = null
		for b in logic.actors:
			if b != null and int(b.actor_id) == i:
				a = b
		if a == null:
			a = state().actor(i)
		var worn: bool = a.equip_list().any(func(e): return e.get("kind", "") == "armor" and int(e.get("base", 0)) == armor)
		if a.is_state_affected(marker) and worn:
			for e in logic.enemies:
				logic.sequence_add_state(e, int(m.get_string(4)))
	return true


## 「套装再放一次」一族（CE17 水流、18 锋芒、107 影杀、325 乱披风、628～631 滑稽弹再次等 34 个，及 CE100 三魔术、1354 冥花葬、1370 斩天拔剑术）：
##   for(let i = 1; i < N; i++){ var actor = $gameActors.actor(i); if(条件 && …){ ACT } [if(…){ ACT }] }
##   var actor = $gameActors.actor($gameVariables.value(V)); if(actor.hasSkill(K)){ ACT } [else { if(actor.hasSkill(K)){ ACT } }]
## ACT＝new Game_Action(actor, true) → setSkill(S) → decideRandomTarget → _actions.splice(1, 0, action) → !$gameTroop.isAllDead() && BattleManager.forceAction(actor)。
## 条件认：actor、!actor.isDeathStateAffected()、actor._states.includes(S)、actor._skills.includes(K)（学会的，不含特性附加）、
## actor.hasArmor／hasWeapon（按基础编号）、actor.hasSkill(K)、($gameVariables.value(V)==K)、!BattleManager.checkBattleEnd()。
## forceAction 只记最后一个（logic.pending_force），事件跑完后才结算；读到没有数据的角色（无 actor 守卫）抛错、YEP 吞掉，后面都不做。
## 第三种写法 CE1327 三千烦恼风再释放：var actor = $gameActors.actor($gameParty._targetActorId); if(actor.hasSkill(6184)){ ACT }。
## 原版 _targetActorId 是菜单里最后一次用物品选中的角色，与这次谁放的百八烦恼风无关：别人最后用过物品就不触发、
## 新开局（0 号没有角色）抛错不做（O-149）。重制默认按预约这条公共事件的行动者（XBattleCommonEvent.take 记的 ce_user），
## 没有行动者（开战预约、事件里装子事件）时退回物品选中的角色；O_RECAST_CASTER 设 false 回到原版。
## 参照 battle_common_event recast_*。整段都认得才执行。
static var O_RECAST_CASTER := true

func _recast_script(code: String) -> bool:
	var js := _compact_js(code)
	var act := "varaction=newGame_Action\\(actor,true\\);action\\.setSkill\\((\\d+)\\);action\\.decideRandomTarget\\(\\);actor\\._actions\\.splice\\(1,0,action\\);(?:!\\$gameTroop\\.isAllDead\\(\\)&&)?BattleManager\\.forceAction\\(actor\\);"
	var loop := RegEx.create_from_string("^for\\(leti=1;i<(\\d+);i\\+\\+\\)\\{varactor=\\$gameActors\\.actor\\(i\\);(.*)\\}$").search(js)
	var by_var := RegEx.create_from_string("^varactor=\\$gameActors\\.actor\\(\\$gameVariables\\.value\\((\\d+)\\)\\);(.*)$").search(js)
	if by_var == null:
		by_var = RegEx.create_from_string("^varactor=\\$gameActors\\.actor\\(\\$gameParty\\.(_targetActorId)\\);(.*)$").search(js)
	if loop == null and by_var == null:
		return false
	var body := (loop if loop != null else by_var).get_string(2)
	var branch := RegEx.create_from_string("^if\\(([^{}]*)\\)\\{" + act + "\\}")
	var clauses := []   # [[条件…], 技能, 是否 else 分支]
	var is_else := false
	while body != "":
		if by_var != null and body.begins_with("else{") and body.ends_with("}") and not clauses.is_empty():
			body = body.substr(5, body.length() - 6)
			is_else = true
			continue
		var m := branch.search(body)
		if m == null:
			return false
		var conds := []
		for t in m.get_string(1).split("&&"):
			var c := _recast_cond(t)
			if c.is_empty():
				return false
			conds.append(c)
		clauses.append([conds, int(m.get_string(2)), is_else])
		body = body.substr(m.get_end())
	if clauses.is_empty():
		return false
	var ids: Array = range(1, int(loop.get_string(1))) if loop != null else [_recast_actor_id(by_var.get_string(1))]
	for i in ids:
		var a = null if XDB.rec("Actors", int(i)).is_empty() else state().actor(int(i))
		var taken := false
		for cl in clauses:
			if bool(cl[2]) and taken:
				continue
			var ok = _recast_meets(a, cl[0])
			if ok == null:
				return true   # 读了 null 的 actor：抛错，后面都不做
			taken = ok
			if ok and logic.actors.has(a) and not logic.alive(logic.enemies).is_empty():
				logic.pending_force = {"user": a, "skill": int(cl[1])}
	return true


## 零度*冻结术再释放（CE1321，技能 6171）：原版 applyGlobal 记下放 6171 的角色（只记角色），takeCaster 取出；学了极寒天地 6175、活着、敌人没死光就强制放一次 6172。
## 只有 6171 预约这条公共事件，施放者就是预约它的行动者 ce_user。
const FREEZE_FOLLOWUP := "varactor=window.CodexFreezeFollowup&&CodexFreezeFollowup.takeCaster();if(actor&&actor.isAlive()&&actor.hasSkill(6175)&&!$gameTroop.isAllDead()){varaction=newGame_Action(actor,true);action.setSkill(6172);action.decideRandomTarget();actor._actions.splice(1,0,action);BattleManager.forceAction(actor);}"
func _freeze_followup_script(code: String) -> bool:
	if _compact_js(code) != FREEZE_FOLLOWUP:
		return false
	var a = get_meta("ce_user") if has_meta("ce_user") else null
	if a is XActor and a.is_alive() and _recast_meets(a, [["has_skill", 6175, 0]]) and logic.actors.has(a) and not logic.alive(logic.enemies).is_empty():
		logic.pending_force = {"user": a, "skill": 6172}
	return true


## 新源 CE1370 斩天拔剑术再释放（技能 2826 的公共事件，会天魔星 2829 时再放一次 2827）：
##   var s = BattleManager._subject; var actor = (s && s.isActor && s.isActor() && s.isLearnedSkill(2826)) ? s : $gameActors.actor($gameVariables.value(884));
##   if(actor && actor.hasSkill(2829)){ var action = new Game_Action(actor, true); action.setSkill(2827); action.decideRandomTarget(); actor._actions.push(action); }
## 原版（OTB）：公共事件在行动结束后才跑，这时 _subject 已清空，取变量 884 的角色；push 进 _actions 的行动没人取，
## 轮到这人时 makeActions 先清空，2827 从不出手（参照 ce1370 探针：会不会 2829 行动序列一模一样）。这是代码错误
## （天魔星说明「斩天拔剑术会额外释放一次」、旧版写法是 splice＋forceAction）：O_PUSH_RECAST（O 号待分配）默认按旧版
## 强制行动补上——施法者取预约这条公共事件的行动者（会 2826 的角色），没有才用变量 884，学了 2829、在战斗里、敌人没死光就强制放一次；
## 设 false 回到原版（认得、什么都不做）
static var O_PUSH_RECAST := true

func _push_recast_script(code: String) -> bool:
	var m := RegEx.create_from_string("^vars=BattleManager\\._subject;varactor=\\(s&&s\\.isActor&&s\\.isActor\\(\\)&&s\\.isLearnedSkill\\((\\d+)\\)\\)\\?s:\\$gameActors\\.actor\\(\\$gameVariables\\.value\\((\\d+)\\)\\);if\\(actor&&actor\\.hasSkill\\((\\d+)\\)\\)\\{varaction=newGame_Action\\(actor,true\\);action\\.setSkill\\((\\d+)\\);action\\.decideRandomTarget\\(\\);actor\\._actions\\.push\\(action\\);\\}$").search(_compact_js(code))
	if m == null:
		return false
	if not O_PUSH_RECAST:
		return true
	var user = get_meta("ce_user") if has_meta("ce_user") else null
	var a = null
	if user is XActor and user.skill_ids.has(int(m.get_string(1))):
		a = user
	else:
		var aid := int(state().variable(int(m.get_string(2))))
		a = null if XDB.rec("Actors", aid).is_empty() else state().actor(aid)
	if a is XActor and _recast_meets(a, [["has_skill", int(m.get_string(3)), 0]]) and logic.actors.has(a) and not logic.alive(logic.enemies).is_empty():
		logic.pending_force = {"user": a, "skill": int(m.get_string(4))}
	return true


## by_var 写法的角色号：变量号，或 _targetActorId（见 O_RECAST_CASTER）
func _recast_actor_id(src: String) -> int:
	if src != "_targetActorId":
		return int(state().variable(int(src)))
	var user = get_meta("ce_user") if has_meta("ce_user") else null
	if O_RECAST_CASTER and user is XActor:
		return int(user.actor_id)
	return int(state().item_target_actor_id)


## 条件一项：[种类, 数]；认不得返回 []
func _recast_cond(t: String) -> Array:
	for pat in [["guard", "^actor$"], ["alive", "^!actor\\.isDeathStateAffected\\(\\)$"], ["state", "^actor\\._states\\.includes\\((\\d+)\\)$"],
			["learned", "^actor\\._skills\\.includes\\((\\d+)\\)$"], ["has_skill", "^actor\\.hasSkill\\((\\d+)\\)$"],
			["armor", "^actor\\.hasArmor\\(\\$dataArmors\\[(\\d+)\\]\\)$"], ["weapon", "^actor\\.hasWeapon\\(\\$dataWeapons\\[(\\d+)\\]\\)$"],
			["variable", "^\\(\\$gameVariables\\.value\\((\\d+)\\)==(\\d+)\\)$"], ["not_end", "^!BattleManager\\.checkBattleEnd\\(\\)$"]]:
		var m := RegEx.create_from_string(pat[1]).search(t)
		if m != null:
			return [pat[0], int(m.get_string(1)) if m.get_group_count() >= 1 else 0, int(m.get_string(2)) if m.get_group_count() >= 2 else 0]
	return []


## 按 && 从左到右短路求值；读到 null 的 actor 返回 null（抛错）
func _recast_meets(a, conds: Array):
	for c in conds:
		var kind := str(c[0])
		var ok := true
		if kind == "guard":
			ok = a != null
		elif kind == "variable":
			ok = state().variable(int(c[1])) == float(c[2])
		elif kind == "not_end":
			ok = not (logic.is_won() or logic.is_lost())
		elif a == null:
			return null
		elif kind == "alive":
			ok = not a.is_dead()
		elif kind == "state":
			ok = a.is_state_affected(int(c[1]))
		elif kind == "learned":
			ok = a.skill_ids.has(int(c[1]))
		elif kind == "has_skill":
			ok = a.skills().any(func(k): return int(k.id) == int(c[1]))
		else:
			ok = a.has_base_equip(kind, int(c[1]))   # armor／weapon
		if not ok:
			return false
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


## 播放电影（CE1514 亲朋好友倒下时、CE1516 万花筒血轮眼技能）：记一条 movie，画面层 XBattleScene._play 放完再往下演
func _play_movie(name: String):
	logs.append({"type": "movie", "name": name})
	return null


func _execute_env(c: Dictionary):
	var p: Array = c.get("parameters", [])
	match int(c.code):
		333:
			logic._change_enemy_state(p)
		331:
			_change_enemy_hp(p)
		241:
			logs.append({"type": "bgm", "bgm": p[0]})  # 播放 BGM（v0.62 死神觉醒敌群页换战斗曲）：画面层 XBattleScene 换 bgm
		250:
			logs.append({"type": "se", "se": p[0]})  # 播放音效（CE46 一掷千金，战斗场合）：画面层 XBattleScene.play_se 放
		334:
			logs.append_array(logic.enemy_recover_all(int(p[0])))
		335:
			logs.append_array(logic.enemy_appear(int(p[0])))
		336:
			logs.append_array(logic.enemy_transform(int(p[0]), int(p[1])))
		214:
			# 暂时消除事件：command214 只在地图上、事件号 >0 时 eraseEvent；敌群页（及其调用的公共事件）事件号是 0，原版什么都不做（嘤嘤怪 1 第 3 页，rules-gaps7）
			pass
		221, 222:
			# 淡出／淡入画面（圣劫使 825 第 30 回合灭世雷劫）：只是画面，记一条给画面层，不影响规则（rules-gaps6）
			# 画面层 XBattleScene._event_view 照 Game_Screen 演 24 帧黑幕（rules-gaps11）
			logs.append({"type": "event_view", "fade": "out" if int(c.code) == 221 else "in"})
		224:
			# 闪烁画面 [颜色 r,g,b,强度, 帧数, 等待]（小明基因锁 CE1551～1554 的红闪）：只是画面，画面层 XBattleScreen 演（rules-gaps11）
			logs.append({"type": "event_view", "flash": (p[0] as Array).duplicate(), "duration": int(p[1]), "wait": bool(p[2])})
		353:
			# 游戏结束（command353 → SceneManager.goto(Scene_Gameover)）：战斗场景随即离开，本页后面的指令（825 的 222 淡入）不再执行，
			# 上层公共事件也到此为止（halted）。XBattleLogic.game_over 置位后 is_lost 成立，战斗按全军覆没收场（rules-gaps6）
			# 与原版的差异（审查 69 P3-1，有意保留）：原版切到 Scene_Gameover 后 BattleManager 不再 update，endBattle 及各模块的
			# endBattle 包装都不跑，只有 Scene_Battle.terminate 的 onBattleEnd；重制走普通全灭收场，会跑 end_battle(2)
			# （XStateEffects 的 defeat、谷雨／云裳／心钢等包装、「全军覆没」字样），随后同样走 O-244 结束画面回标题。清理更干净、不留战斗残留，
			# 玩家可见只多一行战败字样，所以不照搬（rules-gaps7）
			logic.game_over = true
			logs.append({"type": "game_over"})
			halted = true
			return false
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
			if _member_states_script(code) or _count_skills_script(code) or _count_members_script(code) or _actor_states_script(code) \
					or _troop_cev_script(code) or _set_armor_troop_state_script(code) or _recast_script(code) or _freeze_followup_script(code) or _push_recast_script(code):
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
			# rules-gaps9：角色技能脚本（物品选中角色 $gameParty._targetActorId 的火法天下第一 CE942～946、逐个角色学技能的 CE1501 等）：
			# 照地图的 MVScript._target_actor_script（整段认得才执行，认不得返回 null 走下面的通用跳过）；提示记成 toast。
			# 那边是协程（地图解释器要 await），这些写法里没有真正的等待，经 Callable 调用直接得到结果
			if code.contains("$gameActors.actor("):
				var sink := _ToastSink.new()
				sink.logs = logs
				var picked = Callable(MVScript, "_target_actor_script").call(code, {"host": sink})
				if picked is Array:
					index = at
					return null
			return super(c)
		_:
			return super(c)
	return null


## rules-gaps9：给 MVScript._target_actor_script 当 interp.host，提示记进本次事件的日志
class _ToastSink:
	var logs: Array

	func toast(text: String) -> void:
		logs.append({"type": "toast", "text": text})
