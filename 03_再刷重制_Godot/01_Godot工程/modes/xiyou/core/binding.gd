class_name XBinding
extends RefCounted
## 【cc·白龙_14·未经审查】形态绑定与行动充能框架（正式 js/codex/runtime/installNativeBindingChargeRuntime.js 1～282，W.CodexBinding 1.0.0；
## 璇的附身、屠苏的武具共用）。本期只有框架，种类由角色模块用 register 登记（屠苏、璇在三期以后）。
## - 种类 spec（Dictionary，Callable 可缺）：is_owner(a)、form_state、empty_state、manual(a)、can_host(本体, 目标)、default_host(a)、
##   on_bind(本体, 宿主, 原因, 前宿主)、on_unbind(本体, 宿主, 原因)、on_round_start(a, n)、on_round_end(a)、on_round_close(a)、
##   charge_counter(a, n)、on_clear(a)、blocks_hp_loss（真＝附身期间隔离扣血，原版只给璇）。
## - 数据（_codexBind，战斗内）：{charges, host_id, bound_round, returned_round}；returned_round 0＝没有。只在开战时给在场的本体建。
## - canHost：本体有种类；目标不是自己、活着、在出战成员里；目标是本体时要它没绑定且不在开战默认绑定中；再问种类。
## - bind：转移时先 onUnbind(…'transfer')；记宿主、绑定回合，清回归；同步状态；onBind。同一宿主直接返回真。
## - unbind：清宿主；本体离场／阵亡（leave-owner／death-owner）充能清零，否则非 manual 记回归回合；onUnbind；同步。
## - 同步 sync：绑定中加形态状态、否则去掉；回归当回合且 0 充能（manual 除外）加充能耗尽状态、否则去掉；charge_counter。
## - 自然回合开始（startTurn 之后，同回合一次）：回归早于本回合的清回归、充能 0；绑定中充能＝能动 ? max(1, 本回合行动次数) : 0
##   （manual 恒 0），onRoundStart(a, n)；同步。
## - 回合末（endTurn 之后，同回合一次）：有充能、活着、绑定中 → onRoundEnd；onRoundClose；充能清零、同步。
## - 行动前（startAction）：validate；记行动者；回归当回合、没绑定、有充能 → 扣 1。行动后（endAction）：清行动者，validate。
## - validate：全队（含后备）里的本体：不在出战成员 → leave-owner 解除、充能 0；死了 → death-owner；宿主不在／宿主是绑定中的本体
##   → leave-host；宿主死了 → death-host。
## - 敌方不可命中（untargetable：战斗中绑定中的角色）：敌方 makeTargets 对敌技能滤掉，全滤光且不是全体时从可打的人里随机补同样个数；
##   敌方行动中 randomTarget／smoothTarget 抽到的换成可打的人里随机一个；敌方 apply 对它整次不生效（clearResult、used 假）。
## - 不移植：脚本直接扣血、加状态的敌方行动期间排除（Game_Battler 上的 gainHp／addState 包装）：角色的 gainHp、addState 由
##   Game_Actor 自己的方法接管（krz_state_re 等），原版这两层对角色不起作用（参照 binding_probe during 例），重制照原版不拦；
##   开战默认绑定（原版算了默认宿主但不绑，「玩家输入或自动战斗再决定」）；指令窗「攻击」换名（画面）；器谱／星谱菜单（画面）；
##   内部施放 cast（三期跟屠苏的支援一起做）；超强者名单 <CodexSuperStrong>（两人的数据没有这个标签）；伙伴号角上架（招募期）。
## 静态表只存角色 id 与弱引用，不存战斗对象（静态变量存战斗对象会崩）。

## 种类名 → spec
static var kinds := {}
## 角色 id → 绑定数据
static var _data := {}
static var _logic_ref: WeakRef = null
static var _acting_ref: WeakRef = null
static var _opening := false
static var _started_round := -1
static var _ended_round := -1


static func register(kind: String, spec: Dictionary) -> Dictionary:
	spec.kind = kind
	kinds[kind] = spec
	return spec


static func _logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


static func in_battle() -> bool:
	return _logic() != null


## B.round：max(1, turnCount)（current_round）
static func current_round() -> int:
	var logic = _logic()
	return maxi(1, int(logic.turn) if logic != null else 1)


static func members() -> Array:
	var logic = _logic()
	return logic.actors.duplicate() if logic != null else []


static func _live(b) -> bool:
	return b != null and b.is_alive() and b.hp > 0.0


static func _call(spec: Dictionary, name: String, args: Array):
	var f = spec.get(name)
	return f.callv(args) if f is Callable and f.is_valid() else null


static func kind_of(a) -> Dictionary:
	if a == null or not a is XActor:
		return {}
	XTusu.register_kind()  # 原版屠苏模块装入时就 registerBinding；开机没打过仗就读档也得认得屠苏（审查第 24 期 P3-1）
	for k in kinds:
		if bool(_call(kinds[k], "is_owner", [a])):
			return kinds[k]
	return {}


static func is_owner(a) -> bool:
	return not kind_of(a).is_empty()


static func data(a):
	return _data.get(a.actor_id) if a is XActor else null


static func host(a):
	var d = data(a)
	if d == null or int(d.host_id) == 0:
		return null
	var logic = _logic()
	return logic.state.actor(int(d.host_id)) if logic != null else null


static func is_bound(a) -> bool:
	var d = data(a)
	return d != null and int(d.host_id) != 0


static func charges(a) -> int:
	var d = data(a)
	return int(d.charges) if d != null else 0


static func owners_of(h) -> Array:
	return members().filter(func(a): return host(a) == h)


## 敌方不可命中：只看形态中的本体
static func untargetable(b) -> bool:
	return b is XActor and in_battle() and is_bound(b)


static func _manual(k: Dictionary, a) -> bool:
	return bool(_call(k, "manual", [a]))


static func _set_state(a, id: int, on: bool) -> void:
	if id <= 0 or a.is_state_affected(id) == on:
		return
	var logic = _logic()
	if on:
		logic._state_add(a, id)
	else:
		logic._state_remove(a, id)


static func sync(a) -> void:
	var k := kind_of(a)
	var d = data(a)
	if k.is_empty() or d == null or _logic() == null:
		return
	var bound := int(d.host_id) != 0
	var empty: bool = not _manual(k, a) and not bound and int(d.returned_round) == current_round() and int(d.charges) <= 0
	_set_state(a, int(k.get("form_state", 0)), bound)
	_set_state(a, int(k.get("empty_state", 0)), empty)
	_call(k, "charge_counter", [a, int(d.charges)])
	a.param_mark_dirty()
	a.param_refresh()


static func can_host(owner, target) -> bool:
	var k := kind_of(owner)
	if k.is_empty() or target == null or target == owner or not target is XActor or not _live(target) or not members().has(target):
		return false
	# 璇与屠苏只在人形时可以互相绑定（v0.6）：已在形态中的本体不能作宿主；开战默认绑定不选本体
	if is_owner(target) and (is_bound(target) or _opening):
		return false
	var f = k.get("can_host")
	return bool(f.call(owner, target)) if f is Callable and f.is_valid() else true


static func bind(owner, target, reason := "bind") -> bool:
	var k := kind_of(owner)
	if k.is_empty() or not can_host(owner, target) or not _live(owner):
		return false
	if data(owner) == null:
		_data[owner.actor_id] = _fresh()
	var d: Dictionary = data(owner)
	var previous = host(owner)
	if previous == target:
		return true
	if previous != null:
		_call(k, "on_unbind", [owner, previous, "transfer"])
	d.host_id = target.actor_id
	d.bound_round = current_round()
	d.returned_round = 0
	sync(owner)
	_call(k, "on_bind", [owner, target, reason, previous])
	return true


static func unbind(owner, reason := "") -> bool:
	var k := kind_of(owner)
	var d = data(owner)
	if k.is_empty() or d == null or int(d.host_id) == 0:
		return false
	var h = host(owner)
	d.host_id = 0
	if reason == "leave-owner" or reason == "death-owner":
		d.charges = 0
	elif not _manual(k, owner):
		d.returned_round = current_round()
	_call(k, "on_unbind", [owner, h, reason])
	sync(owner)
	return true


static func spend(owner, n := 1) -> bool:
	var d = data(owner)
	n = maxi(1, n)
	if d == null or int(d.charges) < n:
		return false
	d.charges = int(d.charges) - n
	sync(owner)
	return true


static func gain(owner, n: int) -> void:
	var d = data(owner)
	if d == null:
		return
	d.charges = int(d.charges) + maxi(0, n)
	sync(owner)


## B.defaultHost：编队中排在本体之后的第一名合法队友，到末尾从队首找
static func default_host(owner):
	var list := members()
	var i := list.find(owner)
	if i < 0:
		return null
	for n in range(1, list.size()):
		var t = list[(i + n) % list.size()]
		if can_host(owner, t):
			return t
	return null


static func _fresh() -> Dictionary:
	return {"charges": 0, "host_id": 0, "bound_round": 0, "returned_round": 0}


## startBattle（原 startBattle 之后）：在场的本体建新数据、去掉形态状态
static func start_battle(logic) -> void:
	clear_all()
	_logic_ref = weakref(logic)
	_opening = true
	for a in members():
		var k := kind_of(a)
		if k.is_empty():
			continue
		_data[a.actor_id] = _fresh()
		var form := int(k.get("form_state", 0))
		if form > 0 and a.is_state_affected(form):
			logic._state_remove(a, form)
		# 本体开战；玩家输入或自动战斗再决定附身／化武（原版在这里算默认宿主但不绑）
	_opening = false


## startTurn（原 startTurn 之后）：行动次数转为充能；上回合回归的本体恢复普通
static func start_turn(logic) -> void:
	var r := current_round()
	if _started_round == r:
		return
	_started_round = r
	for a in members():
		var k := kind_of(a)
		var d = data(a)
		if k.is_empty() or d == null:
			continue
		if int(d.returned_round) != 0 and int(d.returned_round) < r:
			d.returned_round = 0
			d.charges = 0
		if int(d.host_id) != 0:
			var n: int = maxi(1, logic.current_order.count(a)) if logic.can_move(a) else 0
			d.charges = 0 if _manual(k, a) else n
			_call(k, "on_round_start", [a, n])
		sync(a)


## endTurn（原 endTurn 之后）：交给角色模块释放剩余充能，然后清零
static func end_turn() -> void:
	if _logic() == null:
		return
	var r := current_round()
	if _ended_round == r:
		return
	_ended_round = r
	for a in members():
		var k := kind_of(a)
		var d = data(a)
		if k.is_empty() or d == null:
			continue
		if int(d.charges) > 0 and _live(a) and int(d.host_id) != 0:
			_call(k, "on_round_end", [a])
		_call(k, "on_round_close", [a])
		d.charges = 0
		sync(a)


## B.validate：离场、阵亡（行动开始前、结束后统一检查）
static func validate() -> void:
	var logic = _logic()
	if logic == null:
		return
	var list := members()
	for a in logic.state.members():
		var k := kind_of(a)
		var d = data(a)
		if k.is_empty() or d == null:
			continue
		if not list.has(a):
			if int(d.host_id) != 0:
				unbind(a, "leave-owner")
			d.charges = 0
			sync(a)
			continue
		if int(d.host_id) == 0:
			continue
		if not _live(a):
			unbind(a, "death-owner")
			continue
		var h = host(a)
		if h == null or not list.has(h) or (is_owner(h) and is_bound(h)):
			unbind(a, "leave-host")  # 宿主本体离开人形按离场处理
		elif not _live(h):
			unbind(a, "death-host")


## startAction 包装（原 startAction 之前）
static func start_action(u) -> void:
	if _logic() == null:
		return
	validate()
	_acting_ref = weakref(u) if u != null else null
	var d = data(u)
	# 回归后本回合的时点：每次行动扣 1 点充能（0 时由充能耗尽状态只留防御）
	if d != null and int(d.host_id) == 0 and int(d.returned_round) == current_round() and int(d.charges) > 0:
		d.charges = int(d.charges) - 1
		sync(u)


## endAction 包装（原 endAction 之后）
static func end_action() -> void:
	_acting_ref = null
	validate()


static func _acting():
	return _acting_ref.get_ref() if _acting_ref != null else null


static func enemy_acting() -> bool:
	return _acting() is XEnemy


## makeTargets 包装：敌方对敌技能滤掉不可命中的；全滤光且不是全体时从可打的人里随机补同样个数
static func filter_targets(logic, u, skill: Dictionary, list: Array) -> Array:
	if not u is XEnemy or not XSmartAI.for_opponent(skill):
		return list
	var kept := list.filter(func(t): return not untargetable(t))
	if kept.size() == list.size():
		return list
	if kept.is_empty() and not list.is_empty():
		var pool: Array = logic.alive(logic.actors).filter(func(t): return not untargetable(t))
		if not pool.is_empty() and not XSmartAI.for_all(skill):
			for i in list.size():
				kept.append(pool[floori(logic._float("binding_target") * pool.size())])
	return kept


## randomTarget／smoothTarget 包装：敌方行动中抽到不可命中的，换成可打的人里随机一个
static func retarget(logic, t):
	if not enemy_acting() or not untargetable(t):
		return t
	var pool: Array = logic.alive(logic.actors).filter(func(x): return not untargetable(x))
	return pool[floori(logic._float("binding_target") * pool.size())] if not pool.is_empty() else t


## Game_Action.apply 包装：敌方对形态中的本体整次不生效
static func blocks_apply(u, t) -> bool:
	return u is XEnemy and untargetable(t)


## 不生效时 apply 的结果（clearResult、result.used 假：不弹字、不记命中）
static func unused_result(u, skill: Dictionary, t) -> Dictionary:
	t.runtime_result = XResourceContext.empty_result()
	return {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false, "unused": true,
		"hp": 0.0, "mp": 0.0, "tp": 0.0, "record_hp": 0.0, "added": [], "removed": [], "died": false, "popupQueue": []}


## 璇附身期间也隔离回合持续伤害和直接扣血（Game_Actor 的 gainHp／setHp 包装；种类 blocks_hp_loss）
static func blocks_hp_loss(a) -> bool:
	return bool(kind_of(a).get("blocks_hp_loss", false)) and untargetable(a)


static func _clear_actor(a) -> void:
	var k := kind_of(a)
	_data.erase(a.actor_id)
	if k.is_empty():
		return
	for id in [int(k.get("form_state", 0)), int(k.get("empty_state", 0))]:
		if id > 0 and a.state_ids.has(id):
			a.state_ids.erase(id)  # eraseState：不刷新、不触发
			a.state_turns.erase(id)
	_call(k, "on_clear", [a])


## B.clearAll（endBattle finally、extractSaveContents）：s 给了就清它的全部角色
static func clear_all(s = null) -> void:
	_started_round = -1
	_ended_round = -1
	_acting_ref = null
	_opening = false
	if s != null:
		for id in s.actors:
			var a = s.actors[id]
			if a != null and (_data.has(int(id)) or is_owner(a)):
				_clear_actor(a)
	_data.clear()


## endBattle（finally）
static func end_battle(logic) -> void:
	clear_all(logic.state)
	_logic_ref = null
