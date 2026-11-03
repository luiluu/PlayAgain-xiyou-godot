class_name XShieldLedger
extends RefCounted
## 【cc·白龙_14·未经审查】共用来源护盾账本（正式 js/codex/runtime/installSourceShieldLedgerRuntime.js，W.CodexShieldLedger 1.0.0）。
## 有期限的护盾按「来源＋受益者」分账；原生 ShieldSystem 的护盾（XBattler.shield）照旧是另一份、无期限。
## - grant(目标, 来源, 量, 回合, 施加者 id, opts)：只在战斗中；量×(1＋护盾效果加成，noBonus 不加)向下取整；同源取较高、期限取较晚、
##   不相加；期限按自然回合计（含施加回合）：到 round()＋回合−1。opts：noDecay 不衰减、noHalve 击穿后本来源不触发减半、
##   noBonus 不吃加成、skip（Callable，返回真时这一行暂不吸收，例：谷雨支付生命费用时）。
## - 吸收（executeHpDamage／gainHp／setHp 三处最外层，hp）：到期早的先扣；扣到 0 的行删掉；有非 noHalve 的行挡下过、
##   还有剩余且原生护盾为 0 时，剩余按 damageReduction 减半一次（原生护盾还有时交给它减半）。挡下过就通知各角色（onAbsorb）。
## - 种族自己的伤害（absorb_race，absorbRaceDamage）：账本静默先扣，再扣原生护盾；击穿减半同上。
## - 自然回合结束（endTurn 之后，按回合数去重）：撤销到期的行，其余不带 noDecay 的减 floor(量×decayRate)，减到 0 删掉。
## - 战斗开始、结束、读档清空。
## - 重制差异：原版用子类 getter 把账本并进 b.shield（护盾栏显示合计）；重制 b.shield 只是原生那份，护盾栏读 total(b)。
##   别处读 b.shield 的（宿傩真伤免护盾、异化蚀术等）仍只看原生护盾，同谷雨一期起的做法。
## 账本存在静态表里，按战斗者的 instance id 分；只存弱引用，不存战斗对象本身（静态变量存战斗对象会崩）。

## instance id → {"ref": WeakRef, "list": [行]}；行 {source, amount, until, owner, noDecay, noHalve, skip, lastAbsorbed, absorbed}
static var _rows := {}
## instance id → 本场累计被账本挡下的量（_codexShieldAbsorbed）
static var absorbed_total := {}
static var active := false
static var _logic_ref: WeakRef = null
static var _last_round := -1


static func _num(v) -> float:
	var f := float(v) if v is float or v is int else 0.0
	return f if not is_nan(f) and not is_inf(f) else 0.0


static func decay_rate() -> float:
	return XBattler._shield_param("decayRate", "0.25")


static func reduction() -> float:
	return XBattler._shield_param("damageReduction", "0.5")


## round()：max(1, turnCount)（current_round）
static func current_round() -> int:
	var logic = _logic_ref.get_ref() if _logic_ref != null else null
	return maxi(1, int(logic.turn) if logic != null else 1)


static func _list(b) -> Array:
	if b == null:
		return []
	var e = _rows.get(b.get_instance_id())
	return e.list if e != null else []


## L.amount：某来源（不给就全部）的合计
static func amount(b, source := "") -> float:
	var n := 0.0
	for r in _list(b):
		if source == "" or r.source == source:
			n += float(r.amount)
	return n


## L.rows：副本
static func rows(b) -> Array:
	return _list(b).map(func(r): return r.duplicate())


## 护盾栏显示的合计（原版 shield getter）：原生护盾＋账本
static func total(b) -> float:
	return float(b.shield) + amount(b) if b != null else 0.0


static func grant(target, source: String, value: float, turns: float, owner := 0, opts := {}) -> float:
	if target == null or not active:
		return 0.0
	value *= XTusu.book_rate()  # 止戈环 L.grant 包装：开刃·书的护持护盾 ×hemingRate
	var bonus := 0.0 if bool(opts.get("noBonus", false)) else _num(target.shield_effect_bonus())
	var v := floorf(maxf(0.0, _num(value)) * (1.0 + bonus))
	if v <= 0.0:
		return 0.0
	var id: int = target.get_instance_id()
	if not _rows.has(id):
		_rows[id] = {"ref": weakref(target), "list": []}
	var list: Array = _rows[id].list
	var until := current_round() + maxi(1, floori(turns if turns != 0.0 else 1.0)) - 1  # Math.floor(num(turns) || 1)
	for r in list:
		if r.source == source:
			if v > float(r.amount):
				r.amount = v
			r.until = maxi(int(r.until), until)
			if owner != 0:
				r.owner = owner
			return v
	list.append({"source": source, "amount": v, "until": until, "owner": owner, "noDecay": bool(opts.get("noDecay", false)),
		"noHalve": bool(opts.get("noHalve", false)), "skip": opts.get("skip", Callable()), "lastAbsorbed": 0.0, "absorbed": 0.0})
	return v


## L.revoke：撤掉某来源，返回撤掉的量
static func revoke(target, source: String) -> float:
	var removed := 0.0
	var keep := []
	for r in _list(target):
		if r.source == source:
			removed += float(r.amount)
		else:
			keep.append(r)
	if target != null and _rows.has(target.get_instance_id()):
		_rows[target.get_instance_id()].list = keep
	return removed


## L.revokeOwner：撤掉某施加者给所有人的护盾
static func revoke_owner(owner: int) -> void:
	for id in _rows:
		_rows[id].list = _rows[id].list.filter(func(r): return int(r.owner) != owner)


## L.clear
static func clear(b) -> void:
	if b != null and _rows.has(b.get_instance_id()):
		_rows[b.get_instance_id()].list = []


## absorb：先扣期限护盾（到期早的先扣），返回 {absorbed, remaining, halve}
static func absorb(b, damage: float, quiet := false) -> Dictionary:
	var list := _list(b)
	if list.is_empty() or damage <= 0.0:
		return {"absorbed": 0.0, "remaining": damage, "halve": false}
	var got := 0.0
	var halve := false
	for r in list:
		r.lastAbsorbed = 0.0
	list.sort_custom(func(x, y): return int(x.until) < int(y.until))
	for r in list:
		if damage <= 0.0:
			break
		var skip: Callable = r.skip
		if skip.is_valid() and bool(skip.call()):
			continue
		var take := minf(float(r.amount), damage)
		if take > 0.0 and not bool(r.noHalve):
			halve = true
		r.lastAbsorbed = take
		r.amount = float(r.amount) - take
		damage -= take
		got += take
		r.absorbed = float(r.absorbed) + take
	_rows[b.get_instance_id()].list = list.filter(func(r): return float(r.amount) > 0.0)
	if got > 0.0:
		var id: int = b.get_instance_id()
		absorbed_total[id] = float(absorbed_total.get(id, 0.0)) + got
		if not quiet:
			_on_absorb(b, got, list)
	return {"absorbed": got, "remaining": damage, "halve": halve}


## onAbsorb：各角色挡下后的反应（原版是串起来的回调；这里直接列出）
static func _on_absorb(b, _got: float, list: Array) -> void:
	XXuanBattle.on_absorb(b, list)  # 璇 onAbsorb 包装：护主记录；三法宝成长：星盾流转定轨
	if list.any(func(r): return r.source == "guyu.shield" and float(r.lastAbsorbed) > 0.0):
		XGuyu.spring_shield_hit(b)  # 三法宝成长 onAbsorb：花荫挡下过 → 谷雨 springShieldHit


## O-144：skip 跳过的行不替角色挡伤害。原版账本行的量经子类 getter 并进 b.shield，跳过的行还留着量，
## 后面 ShieldSystem 的吸收读到合计 > 0，按合计「吸收」、却只扣原生那份（扣到 0 为止）：跳过的行白挡一份伤害、自己不少
## （谷雨付生命费用时花荫还在就是这样）。false 照原版。
static var o_skip_unshielded := true


## executeHpDamage／gainHp／setHp 的最外层：返回剩下的伤害（afterLedger：需要时减半一次）
static func hp(b, damage: float) -> float:
	if damage <= 0.0 or _list(b).is_empty():
		return damage
	var r := absorb(b, damage)
	var remaining: float = r.remaining
	if float(r.absorbed) > 0.0 and remaining > 0.0 and bool(r.halve) and float(b.shield) <= 0.0:
		remaining = floorf(remaining * (1.0 - reduction()))
	var phantom := amount(b) if not o_skip_unshielded and remaining > 0.0 else 0.0
	if phantom > 0.0:
		# 回退支：替原生 ShieldSystem 按合计吸收一次（原生只扣它自己那份），之后原生护盾已是 0 或伤害已是 0，不会再吸收
		var native := maxf(0.0, float(b.shield))
		var take := minf(native + phantom, remaining)
		b.shield = maxf(0.0, native - take)
		remaining -= take
		remaining = floorf(remaining * (1.0 - reduction())) if remaining > 0.0 else 0.0
	return remaining


## L.absorbRaceDamage：账本静默先扣，再扣原生护盾；返回 {remaining, absorbed}
static func absorb_race(b, value: float) -> Dictionary:
	var r := absorb(b, maxf(0.0, _num(value)), true)
	var remaining: float = r.remaining
	var got: float = r.absorbed
	var base := maxf(0.0, float(b.shield))
	if base > 0.0 and remaining > 0.0:
		var take := minf(base, remaining)
		b.shield -= take
		remaining -= take
		got += take
		if remaining > 0.0:
			remaining = floorf(remaining * (1.0 - reduction()))
	elif got > 0.0 and remaining > 0.0 and bool(r.halve):
		remaining = floorf(remaining * (1.0 - reduction()))
	return {"remaining": remaining, "absorbed": got}


## 自然回合结束（endTurn 之后）：撤销到期、衰减；同一回合只做一次
static func round_end() -> void:
	if not active:
		return
	var r := current_round()
	if _last_round == r:
		return
	_last_round = r
	var rate := decay_rate()
	for id in _rows:
		var keep := []
		for x in _rows[id].list:
			if int(x.until) <= r:
				continue
			if not bool(x.noDecay):
				x.amount = maxf(0.0, float(x.amount) - floorf(float(x.amount) * rate))
			if float(x.amount) > 0.0:
				keep.append(x)
		_rows[id].list = keep


## L.clearAll（startBattle、endBattle、extractSaveContents）
static func clear_all() -> void:
	_last_round = -1
	_rows.clear()
	absorbed_total.clear()


## BattleManager.setup／startBattle
static func setup(logic) -> void:
	clear_all()
	active = true
	_logic_ref = weakref(logic)


## endBattle（finally）
static func end_battle() -> void:
	clear_all()
	active = false
	_logic_ref = null
