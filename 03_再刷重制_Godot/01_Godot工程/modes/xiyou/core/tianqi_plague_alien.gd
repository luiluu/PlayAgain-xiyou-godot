class_name XTianqiPlagueAlien
extends RefCounted
## 【cc·天启篇·未经审查】瘟疫线异化怪的战斗规则（四线异化 v0.8 第 2.2、3.4 节；四线剧情与关卡设计稿 v0.4 第 4.4、5.1 节；带 4 的参数按 v0.4 附录换）。
## 用在瘟疫线自己的几场战斗：开场第 1 节「异兆」、第 2 节「蔓延」，10／20／30 层的使徒守层者（XTianqiLine 开战前 prepare）；
## 1～30 层「按段异化」由 XTianqiSegAlien 抽好后经 XTianqiLine.alien_apply 调 apply（种类键 gland、chaos、taunt、contagion、source）。
##
## - 级（侵染／蚀骨／化形／终焉）：生命 ×1.25／×1.5／×2／×3，名字前加「级·」。数值按第 1～4 档；化形效果从化形起；终焉效果没做（终焉只给骑士和 31～36 层 Boss）。
## - 毒腺：命中我方附加中毒（3 回合，每回合扣最大生命 3／5／8／12%）；化形起中毒可叠 3 层（否则刷新回合）。
## - 混乱者：命中我方 20／35／50／80% 几率混乱 1 回合（状态 124）。化形效果「优先打队友」没做。
## - 挑衅者：我方单体攻击只能打它（群体不受限）；打它的人「不服」（物攻、魔攻 −20%，2 回合）；自身双攻 −33%（附录，原 40%）、双防 +20／30／60／100%（附录，原 40%）；
##   化形起群体攻击打到它伤害减半。
## - 传染者：回合结束时，把一名我方身上的减益复制给另一名，1／1／2 个；化形起复制的持续回合 +1。
## - 疫源：光环，本模块加的减益（中毒、不服、混乱）和敌人技能给我方挂的减益状态持续 +1／+1／+2 回合；我方净化（技能解除状态）
##   失败几率 0／20／33／60%（原 40% 按避开 4 改 33%）；化形起净化成功时施放者自己染上被清掉的那个减益。
## - 病弱（线规则）：场上有活着的瘟疫异化怪时，我方每有一个减益，八项属性 −3%，上限 −30%。
## - 病灶（本线核心计量）：我方身上减益的总层数（中毒按层、能力弱化按级）；满 12 爆发一次：中毒立刻结算一次、混乱的人多乱 1 回合；
##   降回 12 以下才会再爆发。开战时、每回合开始在战斗日志里报。
## 减益怎么数：本模块的中毒、不服，加上我方身上 XBossStatus.kind_of 判为 Debuff 的状态（不含阵亡）和能力弱化。每次行动后、回合首尾重数一次（缓存），属性按缓存算。
## - 终焉（cc/tianqi-alien-finale）：终焉瘟疫异化在场时病灶满 8 就爆发、病弱上限 −60%；毒腺：中毒期间不能被治疗（XResourceContext._gain）；
##   混乱者：混乱一次 2 回合；传染者：每回合传两次；疫源：我方对减益状态的免疫无效（BattleLogic 附加状态时不认抵抗）；
##   挑衅者：全体挑衅（我方群体攻击也只打它），打它的人改为混乱（不再是不服）。
## 没做（交付单「未做」）：混乱者化形「优先打队友」。
##
## 开关：XTianqiPlagueLine.ENABLED（瘟疫线整条）；只认天启篇存档、发行构建里还要 XTianqi.RELEASE_OPEN。没 prepare／apply 的战斗一概不动。

const META := "xplague_alien"
const DEATH_STATE := 1

static var _pending := ""
## 正在打的瘟疫异化战（属性挂钩不带 logic，从这里取）
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	return XTianqiLine.data(XTianqiPlagueLine.KEY).get("alien", {})


static func preset(key: String) -> Dictionary:
	return XTianqiLine.alien_preset(XTianqiPlagueLine.KEY, key)


## 下一场战斗按这个预设异化（omen／spread／apostle10／apostle20／apostle30）。不收时返回 false。
static func prepare(key: String, s: XState = null) -> bool:
	if preset(key).is_empty() or not XTianqiPlagueLine.allowed(s):
		_pending = ""
		return false
	_pending = key
	return true


static func pending() -> String:
	return _pending


static func active(logic) -> bool:
	return logic != null and logic.has_meta(META)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if active(logic) else {}


static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if active(l) else null


static func tier_info(tier: String) -> Dictionary:
	var t = data().get("tiers", {}).get(tier)
	return t if t is Dictionary else {}


static func kind_info(kind: String) -> Dictionary:
	var k = data().get("kinds", {}).get(kind)
	return k if k is Dictionary else {}


## 本线异化种类里已经做好战斗规则的（按段异化 XTianqiSegAlien 只从这里面抽）
static func kinds() -> Array:
	return data().get("kinds", {}).keys()


## 某只敌人的异化记录 {tier, kind, idx}；不是异化怪为空
static func unit(logic, e) -> Dictionary:
	return fight(logic).get("units", {}).get(e, {}) if active(logic) else {}


static func is_alien(logic, e) -> bool:
	return not unit(logic, e).is_empty()


## BattleLogic.setup：敌群建完后调（四骑士 setup 之后）
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var key := _pending
	_pending = ""
	if key == "" or not XTianqiPlagueLine.allowed(s):
		return
	var p := preset(key)
	var picks := _pick_units(logic.enemies, p.get("units", "all"))
	apply(logic, s, key, picks.map(func(e): return {"enemy": e, "tier": str(p.tier), "kind": str(p.kind)}))


## 把指定的敌人变成异化怪（预设和按段异化 XTianqiSegAlien 共用）：list 每项 {enemy, tier, kind}；返回 true＝这场有异化
static func apply(logic, s: XState, key: String, list: Array) -> bool:
	if logic.has_meta(META):
		logic.remove_meta(META)
	if list.is_empty() or not XTianqiPlagueLine.allowed(s):
		return false
	var f := {"preset": key, "units": {}, "queue": [], "marks": {}, "debuffs": {}, "layers": 0, "burst": false}
	var names := PackedStringArray()
	for row in list:
		var e = row.enemy
		var ti := tier_info(str(row.tier))
		var ki := kind_info(str(row.kind))
		if ti.is_empty() or ki.is_empty():
			continue
		var idx := int(ti.get("idx", 0))
		f.units[e] = {"tier": str(row.tier), "kind": str(row.kind), "idx": idx}
		e.add_param(0, e.param_base_unscaled(0) * (float(ti.hp) - 1.0))
		if str(row.kind) == "taunt":  # 挑衅者自己是坦克：双攻降、双防升
			for i in [2, 4]:
				e.add_param(i, -e.param_base_unscaled(i) * float(ki.self_atk_down))
			for i in [3, 5]:
				e.add_param(i, e.param_base_unscaled(i) * float(ki.def_up[idx]))
		e.param_refresh()  # 开战后（按段异化、测试）才变的：能力值缓存当场变冷
		e.hp = e.mhp
		e.mp = e.mmp
		e.set_meta("tianqi_prefix", str(ti.name) + "·")
		names.append("%s（%s·%s）" % [e.original_name(), str(ti.name), str(ki.name)])
	if f.units.is_empty():
		return false
	logic.set_meta(META, f)
	_logic_ref = weakref(logic)
	_say(f, "瘟疫的异化：%s。" % "、".join(names))
	refresh(logic)
	_say(f, focus_text(logic))
	return true


static func _pick_units(enemies: Array, spec) -> Array:
	var list := enemies.filter(func(e): return not e.hidden)
	if spec is Array:
		var out := []
		for i in spec:
			if int(i) >= 0 and int(i) < list.size():
				out.append(list[int(i)])
		return out
	if str(spec) == "guardian":
		var g := list.filter(func(e): return str(e.original_name()).contains("守层者"))
		return g if not g.is_empty() else list.slice(0, 1)
	return list


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


# ---- 场上异化 ----

## 场上活着的某种异化的档位（0 起）列表
static func _idx_of(logic, kind: String) -> Array:
	var f := fight(logic)
	var out := []
	for e in f.get("units", {}):
		if e.is_alive() and str(f.units[e].kind) == kind:
			out.append(int(f.units[e].idx))
	return out


static func _max_idx(logic, kind: String) -> int:
	var l := _idx_of(logic, kind)
	return -1 if l.is_empty() else int(l.max())


## 场上有活着的瘟疫异化怪
static func sick(logic) -> bool:
	return active(logic) and fight(logic).units.keys().any(func(e): return e.is_alive())


## 场上有活着的终焉瘟疫异化怪（病灶阈值 8、病弱上限 −60%）
static func finale(logic) -> bool:
	if not active(logic):
		return false
	var f := fight(logic)
	return f.units.keys().any(func(e): return e.is_alive() and int(f.units[e].idx) >= 3)


static func _focus_full(logic) -> int:
	return int(data().focus.full_end) if finale(logic) else int(data().focus.full)


## 疫源：减益多几回合（场上最高级）
static func extend_turns(logic) -> int:
	var i := _max_idx(logic, "source")
	return 0 if i < 0 else int(kind_info("source").extend[i])


static func _our(logic, b) -> bool:
	return b is XActor and logic.actors.has(b)


static func _mark(f: Dictionary, a) -> Dictionary:
	if not f.marks.has(a):
		f.marks[a] = {"poison": [], "defy": 0}
	return f.marks[a]


static func mark_of(logic, a) -> Dictionary:
	return fight(logic).get("marks", {}).get(a, {}) if active(logic) else {}


# ---- 减益、病弱、病灶 ----

## 我方一人身上的减益：[{type: poison, turns}, {type: defy, turns}, {type: state, id, turns}, {type: buff, id, level}]
static func debuffs_of(logic, a) -> Array:
	var out := []
	var m := mark_of(logic, a)
	for t in m.get("poison", []):
		out.append({"type": "poison", "turns": int(t)})
	if int(m.get("defy", 0)) > 0:
		out.append({"type": "defy", "turns": int(m.defy)})
	for st in a.states():
		var id := int(st.get("id", 0))
		if id != DEATH_STATE and XBossStatus.kind_of(st) == "Debuff":
			out.append({"type": "state", "id": id, "turns": int(a.state_turns.get(id, 0))})
	for i in a.buffs.size():
		if int(a.buffs[i]) < 0:
			out.append({"type": "buff", "id": i, "level": -int(a.buffs[i])})
	return out


## 重数我方的减益（病弱按个数、病灶按层数），属性标脏；病灶满了爆发
static func refresh(logic) -> void:
	if not active(logic):
		return
	var f := fight(logic)
	var layers := 0
	f.debuffs = {}
	for a in logic.actors:
		if not a.is_alive():
			continue
		var list := debuffs_of(logic, a)
		var poisons := list.filter(func(d): return str(d.type) == "poison").size()
		f.debuffs[a] = list.size() - poisons + mini(1, poisons)  # 中毒几层都算一个减益
		for d in list:
			layers += int(d.get("level", 1))
	f.layers = layers
	for a in logic.actors:
		if a is XBattler:
			a.param_mark_dirty()
	var full := _focus_full(logic)
	if not sick(logic):
		f.burst = false
		return
	if layers >= full and not bool(f.burst):
		f.burst = true
		_burst(logic, f)
	elif layers < full:
		f.burst = false


## 病灶爆发：中毒立刻结算一次，混乱的人多乱 1 回合
static func _burst(logic, f: Dictionary) -> void:
	_say(f, "病灶爆发了（%d 层）！" % int(f.layers))
	var cid := int(data().confusion_state)
	for a in logic.alive(logic.actors):
		_poison_tick(logic, f, a, false)
		if a.is_state_affected(cid):
			a.state_turns[cid] = int(a.state_turns.get(cid, 0)) + 1


## 病弱：减益个数 × 3%，上限 30%
static func frail_rate(logic, a) -> float:
	if not sick(logic):
		return 0.0
	var fr: Dictionary = data().frail
	return minf(float(fr.cap_end) if finale(logic) else float(fr.cap), XTianqiRewards.frail_per(a, float(fr.per)) * int(fight(logic).debuffs.get(a, 0)))  # 天启篇奖励：净印·清心


static func focus_text(logic) -> String:
	if not sick(logic):
		return "瘟疫散去了。"
	return "病灶 %d／%d：我方每个减益让八项属性 −%d%%（最多 −%d%%）。" % [int(fight(logic).layers), _focus_full(logic),
		roundi(float(data().frail.per) * 100.0), roundi(float(data().frail.cap_end if finale(logic) else data().frail.cap) * 100.0)]


# ---- 施加 ----

static func _add_poison(logic, f: Dictionary, e, a, idx: int) -> void:
	var k := kind_info("gland")
	var m := _mark(f, a)
	var turns := int(k.turns) + extend_turns(logic)
	var list: Array = m.poison
	var cap := int(k.stack_max) if idx >= 2 else 1
	if list.size() < cap:
		list.append(turns)
	else:
		list.sort()
		list[0] = turns  # 叠满了刷新最快到期的那层
	m.poison = list
	_say(f, "%s中毒了（%d 层）。" % [a.display_name(), list.size()])


static func _confuse(logic, f: Dictionary, a, turns: int) -> void:
	var id := int(data().confusion_state)
	var fresh: bool = not a.is_state_affected(id)
	logic._state_add(a, id)
	if a.is_state_affected(id):
		var n := turns + extend_turns(logic)
		a.state_turns[id] = n if fresh else maxi(int(a.state_turns.get(id, 0)), n)  # 新挂上的按本线回合，已经乱着的不缩短
		_say(f, "%s混乱了。" % a.display_name())


static func _poison_tick(logic, f: Dictionary, a, count_down: bool) -> void:
	var list: Array = _mark(f, a).poison
	if list.is_empty() or not a.is_alive():
		return
	var rate := float(kind_info("gland").poison[maxi(0, _max_idx(logic, "gland"))])
	var lose := floorf(float(a.mhp) * rate * list.size())
	if lose > 0.0:
		var before: float = a.hp
		a.hp = maxf(0.0, a.hp - lose)
		a.refresh_resources()
		f.queue.append({"type": "regen", "target": a, "hp": before - a.hp, "views": logic.views([a])})
		if a.is_dead():
			logic._die(a)
			f.queue.append({"type": "collapse", "target": a, "views": logic.views([a])})
	if count_down:
		var left := []
		for t in list:
			if int(t) > 1:
				left.append(int(t) - 1)
		_mark(f, a).poison = left


# ---- 挂钩 ----

## BattleLogic.start_turn：每回合报一次病灶
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	refresh(logic)
	_say(fight(logic), focus_text(logic))
	return take_logs(logic)


## BattleLogic.act 末尾：重数减益（病弱、病灶），交出本次行动里的日志
static func after_action(logic, _u) -> Array:
	if not active(logic):
		return []
	refresh(logic)
	return take_logs(logic)


## BattleLogic.targets_for：挑衅者活着时，我方打敌人的单体技能只能打它（群体不受限）
static func filter_targets(logic, a, skill: Dictionary, list: Array) -> Array:
	if not active(logic) or not _our(logic, a) or not list.any(func(t): return t is XEnemy):
		return list
	var f := fight(logic)
	var taunters := []
	var total := false
	for e in f.units:
		if e.is_alive() and str(f.units[e].kind) == "taunt":
			taunters.append(e)
			total = total or int(f.units[e].idx) >= 3  # 终焉挑衅者：全体挑衅，群体攻击也只打它
	if taunters.is_empty() or (int(skill.get("scope", 0)) != 1 and not total):
		return list
	if int(skill.get("scope", 0)) != 1:
		return list.filter(func(t): return not (t is XEnemy) or taunters.has(t))
	var kept := list.filter(func(t): return taunters.has(t))
	return kept if not kept.is_empty() else [taunters[0]]


## BattleLogic.execute_hp_damage：毒腺、混乱者命中我方附加中毒、混乱；打挑衅者的人「不服」，化形挑衅者被群体打减半
static func hp_damage(logic, u, t, value: float, item := {}) -> float:
	if value <= 0.0 or not active(logic):
		return value
	var f := fight(logic)
	var r := unit(logic, u)
	if not r.is_empty() and u.is_alive() and _our(logic, t) and t.is_alive():
		match str(r.kind):
			"gland":
				_add_poison(logic, f, u, t, int(r.idx))
			"chaos":
				if logic._float("plague_chaos") < float(kind_info("chaos").chance[int(r.idx)]):
					_confuse(logic, f, t, int(kind_info("chaos").get("finale_turns", 2)) if int(r.idx) >= 3 else int(kind_info("chaos").turns))
	var rt := unit(logic, t)
	if not rt.is_empty() and str(rt.kind) == "taunt" and _our(logic, u):
		var k := kind_info("taunt")
		var m := _mark(f, u)
		if int(rt.idx) >= 3:  # 终焉挑衅者：打它的人混乱（不再是不服）
			if u.is_alive() and not u.is_state_affected(int(data().confusion_state)):
				_confuse(logic, f, u, int(kind_info("chaos").turns))
			if not item.is_empty() and int(item.get("scope", 1)) != 1:
				return floorf(value * float(k.group_cut))
			return value
		if int(m.defy) <= 0:
			_say(f, "%s不服了：物攻、魔攻 −%d%%。" % [u.display_name(), roundi(float(k.defy_down) * 100.0)])
		m.defy = maxi(int(m.defy), int(k.defy_turns) + extend_turns(logic))
		if int(rt.idx) >= 2 and not item.is_empty() and int(item.get("scope", 1)) != 1:
			return floorf(value * float(k.group_cut))
	return value


## BattleLogic._apply_effect（效果 21 附加状态，挂上之后）：疫源让敌人给我方挂的减益多几回合
static func on_state_added(logic, u, t, id: int) -> void:
	if not active(logic) or not _our(logic, t) or _our(logic, u) or not t.is_state_affected(id):
		return
	var ext := extend_turns(logic)
	if ext > 0 and XBossStatus.kind_of(XDB.rec("States", id)) == "Debuff":
		t.state_turns[id] = int(t.state_turns.get(id, 0)) + ext


## BattleLogic._apply_effect（效果 22 解除状态，掷中之后）：疫源在场时我方净化减益可能失败。返回 true＝这次没解掉
static func purge_blocked(logic, u, t, id: int) -> bool:
	if not active(logic) or not _our(logic, t) or not t.is_state_affected(id) or id == DEATH_STATE:
		return false
	var i := _max_idx(logic, "source")
	if i < 0 or XBossStatus.kind_of(XDB.rec("States", id)) != "Debuff":
		return false
	if logic._float("plague_purge") < float(kind_info("source").purge_fail[i]):
		_say(fight(logic), "疫源压住了净化：%s身上的减益没解掉。" % t.display_name())
		return true
	if i >= 2 and _our(logic, u) and u.is_alive() and not is_same(u, t):
		logic._state_add(u, id)  # 化形疫源：净化成功时施放者自己染上被清掉的减益
		if u.is_state_affected(id):
			_say(fight(logic), "%s替%s染上了被清掉的减益。" % [u.display_name(), t.display_name()])
	return false


## BattleLogic.end_turn：中毒扣血、传染、减益回合数往下走
static func end_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	for a in logic.alive(logic.actors):
		_poison_tick(logic, f, a, true)
		var m := _mark(f, a)
		if int(m.defy) > 0:
			m.defy = int(m.defy) - 1
	var ci := _max_idx(logic, "contagion")
	if ci >= 0:
		for i in _idx_of(logic, "contagion"):
			for _k in (2 if int(i) >= 3 else 1):  # 终焉传染者：每回合传两次
				_spread(logic, f, int(kind_info("contagion").copies[ci]), 1 if ci >= 2 else 0)
	refresh(logic)
	return take_logs(logic)


## 传染：挑一个身上有减益的人，复制 n 个减益给另一个人
static func _spread(logic, f: Dictionary, n: int, plus: int) -> void:
	var live: Array = logic.alive(logic.actors)
	var sources := live.filter(func(a): return not debuffs_of(logic, a).filter(func(d): return str(d.type) != "buff").is_empty())
	if sources.is_empty() or live.size() < 2:
		return
	var from = sources[logic._int(0, sources.size() - 1, "plague_spread_from")]
	var others := live.filter(func(a): return not is_same(a, from))
	var to = others[logic._int(0, others.size() - 1, "plague_spread_to")]
	var list := debuffs_of(logic, from).filter(func(d): return str(d.type) != "buff")
	var copied := 0
	for d in list:
		if copied >= n:
			break
		var turns := maxi(1, int(d.turns)) + plus
		match str(d.type):
			"poison":
				var m := _mark(f, to)
				if m.poison.size() < int(kind_info("gland").stack_max):
					m.poison.append(turns)
			"defy":
				var m := _mark(f, to)
				m.defy = maxi(int(m.defy), turns)
			"state":
				logic._state_add(to, int(d.id))
				if to.is_state_affected(int(d.id)):
					to.state_turns[int(d.id)] = maxi(int(to.state_turns.get(int(d.id), 0)), turns)
		copied += 1
	if copied > 0:
		_say(f, "传染：%s身上的 %d 个减益传给了%s。" % [from.display_name(), copied, to.display_name()])


## XResourceContext._gain：终焉毒腺在场时，我方中毒（本模块的中毒）期间不能被治疗
static func gain(b, resource: String, amount: float) -> float:
	if amount <= 0.0 or resource != "hp" or _logic_ref == null:
		return amount
	var logic = active_logic()
	if logic == null or not _our(logic, b) or _max_idx(logic, "gland") < 3:
		return amount
	return 0.0 if not (mark_of(logic, b).get("poison", []) as Array).is_empty() else amount


## BattleLogic 附加状态判抵抗时：终焉疫源在场，我方对减益状态的免疫无效
static func forced_state(t, id: int) -> bool:
	if _logic_ref == null or id == DEATH_STATE:
		return false
	var logic = active_logic()
	if logic == null or not _our(logic, t) or _max_idx(logic, "source") < 3:
		return false
	return XBossStatus.kind_of(XDB.rec("States", id)) == "Debuff"


## XActor.param：病弱（八项属性按减益个数降）、不服（物攻、魔攻 −20%）
static func actor_param(a, i: int, v: float) -> float:
	if _logic_ref == null:
		return v
	var logic = active_logic()
	if logic == null or not logic.actors.has(a):
		return v
	var mult := 1.0 - frail_rate(logic, a)
	if (i == 2 or i == 4) and int(mark_of(logic, a).get("defy", 0)) > 0:
		mult *= 1.0 - float(kind_info("taunt").defy_down)
	return roundf(v * mult) if mult != 1.0 else v


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		var f := fight(logic)
		for e in f.get("units", {}):
			if e.has_meta("tianqi_prefix"):
				e.remove_meta("tianqi_prefix")
		logic.remove_meta(META)
		for a in logic.actors:
			if a is XBattler:
				a.param_mark_dirty()
		f.clear()
	_logic_ref = null
