class_name XTianqiJinran
extends RefCounted
## 【cc·天启篇·未经审查】法宝浸染规则核心（事项 96，设计稿 天启篇_法宝浸染_v0.5 第三、十节；T597 J1）。表 tianqi_data/jinran.json。
## 只管启封（天启篇存档，XTianqi.active）；西游档一律不碰、不写。本文件只有规则，不接线：入队绑定的调用点、fabao_param 取系数、
## 喂入／卖／丢拦本命、本命表、旧档迁移归 J2；器灵词条怎么生效归 J3；异源物品和发放归 J4；界面归 J5。
##
## 存档：
## - 本命实例（装备字典）上 jinran = {tier 1～4, slots [{key, tone} 或 null]×3, sleeping, res {"2","3","4": 次数}, pending,
##   deck {"格号": {left 本轮还剩几次, cards 叠, seen 本轮出过的}}, wash_marks 洗痕, n 操作序号}。登记在 XTianqiSave.GEAR_KEYS（copy＝false）。
##   deck.seen 是稿上没写的一个字段：合法池中途变了时要知道「新变合法的这一轮出没出过」（3.6），只加不改。
## - flags.tianqi.jinran（XTianqiSave 分区，登记了、没接迁移）= {bound {"角色号": instanceId}, got [首胜键…]}；got 归 J4。
##   稿第十节的 ver 用门面的分区版本（flags.tianqi.v.jinran）代替，不另存。
##
## 事务（3.3）：再浸一次、洗一条都在一次调用里改完：查条件 → 扣异源 → 掷 → 改品阶／残留／词条／待选／洗牌堆／洗痕 → n+1，然后才返回给
## 界面放演出。演出跳不跳、窗口关不关都不再动存档；待选（pending）在、就先弹待选，其余操作一律拒绝；choose 只结算一次。
## 随机（3.3 第 8 条）：XTianqiRandom.save_stream(s, "jinran|角色号|n|子键")，子键 ok／key／tone／deck。只看存档种子、角色号和这件的 n，
## 所以没存档就重开、再做一次，掷出同样的结果；存了档读回来做，也同样。
##
## 开关（O-待定，总装合并时换号）：ENABLED＝false（默认，J2 接线、J8 标定前不开）时 on() 为假：不能浸染、不能再浸、不能洗，
## is_benming 为假（本命锁解除，玩家自己的出售锁不归这里管），jinran 字段留着不读不删。

static var ENABLED := false
## 测试用：异源物品号（>0 时代替 jinran.json 的 material_item；J4 建物品前表里是 0）
static var material_override := 0
## 测试用：成功判定的掷数磁带（0～99，非空时先取它，代替存档派生流；只用来摆出「这一步成功／失败」的场面）
static var ok_tape: Array = []

const PATH := "res://modes/xiyou/tianqi_data/jinran.json"
const SECTION := "jinran"
const FIELD := "jinran"
const MAX_TIER := 4
const SLOTS := 3
const SLEEP_SLOT := 2  # 只有第 2 格会沉睡（3.6）
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func on(s: XState) -> bool:
	return ENABLED and s != null and XTianqi.active(s)


# ---- 表 ----

static func material_id() -> int:
	return material_override if material_override > 0 else int(data().get("material_item", 0))


static func material_count(s: XState) -> int:
	var id := material_id()
	return s.item_count(id) if id > 0 else 0


static func tier_name(tier: int) -> String:
	var names: Array = data().get("tier_names", [])
	return str(names[tier - 1]) if tier >= 1 and tier <= names.size() else ""


## 这一品阶有几格词条（异痕 1、蚀纹 2、异态 2、异构 3）
static func slot_count(tier: int) -> int:
	var a: Array = data().get("slots_by_tier", [1, 2, 2, 3])
	return int(a[clampi(tier, 1, a.size()) - 1])


static func _step(to_tier: int) -> Dictionary:
	var v = data().get("steps", {}).get(str(to_tier))
	return v if v is Dictionary else {}


## 冲到 to_tier 每次要的异源
static func step_cost(to_tier: int) -> int:
	return int(_step(to_tier).get("cost", 0))


static func wash_cfg(k: String, dflt: int) -> int:
	return int(data().get("wash", {}).get(k, dflt))


## 全部词条键（固定次序：按键名排序，不受表里写的次序影响）
static func all_keys() -> Array:
	var ks: Array = data().get("affixes", {}).keys()
	ks.sort()
	return ks


static func affix(key: String) -> Dictionary:
	var v = data().get("affixes", {}).get(key)
	return v if v is Dictionary else {}


## 第 slot 格本身能出的词条（不看别格）：第 1 格只出行为类（3.6），第 2、3 格十条都可出
static func base_pool(slot: int) -> Array:
	if slot != 1:
		return all_keys()
	var kinds: Array = data().get("slot1_kinds", [])
	var extra: Array = data().get("slot1_extra", [])
	return all_keys().filter(func(k): return kinds.has(str(affix(k).get("kind", ""))) or extra.has(k))


## 词条幅度：四档起点按品阶取，浓的 ×nong_amp_pct÷100 向下取整（4.3、5.2）
static func amp(entry, tier: int) -> int:
	if not entry is Dictionary:
		return 0
	var a: Array = affix(str(entry.get("key", ""))).get("amp", [])
	if a.is_empty():
		return 0
	var v := int(a[clampi(tier, 1, a.size()) - 1])
	if str(entry.get("tone", "")) == "nong":
		v = v * int(data().get("tone", {}).get("nong_amp_pct", 125)) / 100
	return v


## 品阶系数（4.1 C 案）：原品质百分数 × 品阶倍率 ÷100，向下取整；coef_cap_pct>0 时封顶。J2 在 fabao_param 里用
static func coef_pct(orig_pct: int, tier: int) -> int:
	var m: Array = data().get("tier_mult_pct", [100, 115, 130, 150])
	var v := orig_pct * int(m[clampi(tier, 1, m.size()) - 1]) / 100
	var cap := int(data().get("coef_cap_pct", 0))
	return mini(v, cap) if cap > 0 else v


# ---- 存档 ----

## flags.tianqi.jinran（门面分区）；西游档返回不落盘的空表
static func book(s: XState) -> Dictionary:
	var d: Dictionary = XTianqiSave.section(s, SECTION)
	if not d.get("bound") is Dictionary:
		d["bound"] = {}
	if not d.get("got") is Array:
		d["got"] = []
	return d


static func state_of(item) -> Dictionary:
	if item is Dictionary and item.get(FIELD) is Dictionary:
		return item[FIELD]
	return {}


## 身上和背包里的装备（本命只认这两处，3.2）
static func _owned(s: XState) -> Array:
	var out: Array = s.gear.filter(func(e): return e is Dictionary)
	for a in s.actors.values():
		for e in a.raw_equip_list():
			if e is Dictionary:
				out.append(e)
	return out


## 这个角色的本命实例；没有（还没绑、实例已不在身上和背包里）返回 null
static func bound_item(s: XState, actor_id: int) -> Variant:
	if s == null or not XTianqi.active(s):
		return null
	var b = XTianqiSave.peek(s, SECTION)
	var iid := str(b.get("bound", {}).get(str(actor_id), "")) if b is Dictionary and b.get("bound") is Dictionary else ""
	if iid == "":
		return null
	for e in _owned(s):
		if str(e.get("instanceId", "")) == iid and e.get(FIELD) is Dictionary:
			return e
	return null


## 这件是不是谁的本命（本命锁：不能卖、丢、喂入；J2 在各处调）。开关关着＝锁解除
static func is_benming(s: XState, item) -> bool:
	if not on(s) or not item is Dictionary or not item.get(FIELD) is Dictionary:
		return false
	var b = XTianqiSave.peek(s, SECTION)
	if not b is Dictionary or not b.get("bound") is Dictionary:
		return false
	var iid := str(item.get("instanceId", ""))
	return iid != "" and b.bound.values().any(func(v): return str(v) == iid)


static func _blank() -> Dictionary:
	return {"tier": 1, "slots": [null, null, null], "sleeping": null, "res": {"2": 0, "3": 0, "4": 0},
		"pending": null, "deck": {}, "wash_marks": 0, "n": 0}


## 缺键补默认（老形或 JSON 读回来的都过一遍；只补不改）
static func _norm(j: Dictionary) -> Dictionary:
	var b := _blank()
	for k in b:
		if not j.has(k):
			j[k] = b[k]
	if not j.slots is Array:
		j.slots = [null, null, null]
	while (j.slots as Array).size() < SLOTS:
		j.slots.append(null)
	if not j.res is Dictionary:
		j.res = {}
	for t in ["2", "3", "4"]:
		if not j.res.has(t):
			j.res[t] = 0
	if not j.deck is Dictionary:
		j.deck = {}
	return j


# ---- 随机 ----

static func _stream(s: XState, actor_id: int, n: int, sub: String) -> XRandomStream:
	return XTianqiRandom.save_stream(s, "jinran|%d|%d|%s" % [actor_id, n, sub])


static func _pick(pool: Array, st: XRandomStream) -> String:
	var total := 0
	for k in pool:
		total += maxi(0, int(affix(k).get("weight", 1)))
	if total <= 0:
		return str(pool[st.next_index_mod(pool.size(), "jinran_key")]) if not pool.is_empty() else ""
	var r := st.next_index_mod(total, "jinran_key")
	for k in pool:
		r -= maxi(0, int(affix(k).get("weight", 1)))
		if r < 0:
			return str(k)
	return str(pool[-1])


static func _tone(st: XRandomStream) -> String:
	return "nong" if st.next_index_mod(100, "jinran_tone") < int(data().get("tone", {}).get("nong_pct", 25)) else "dan"


static func _shuffle(a: Array, st: XRandomStream) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := st.next_index_mod(i + 1, "jinran_deck")
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## 第 slot 格当前的合法候选：本格能出的，去掉本件别的格（含沉睡格）已有的名字；可以和本格现有的同名（那就是重掷成色）
static func legal_pool(j: Dictionary, slot: int) -> Array:
	var taken := []
	for i in SLOTS:
		if i + 1 != slot and j.slots[i] is Dictionary:
			taken.append(str(j.slots[i].key))
	if slot != SLEEP_SLOT and j.get("sleeping") is Dictionary:
		taken.append(str(j.sleeping.key))
	return base_pool(slot).filter(func(k): return not taken.has(k))


## 给第 slot 格掷一条新词条（升阶给新格、首次浸染）
static func _roll_entry(s: XState, actor_id: int, j: Dictionary, slot: int) -> Dictionary:
	var pool := legal_pool(j, slot)
	var key := _pick(pool, _stream(s, actor_id, int(j.n), "key"))
	return {"key": key, "tone": _tone(_stream(s, actor_id, int(j.n), "tone"))}


# ---- 操作 ----

## 首次浸染（3.2 第 2、3 步的「写上 jinran」那一下）：把 item 激活成 actor_id 的本命，品阶异痕、掷第 1 格，记进 bound。
## 不花材料、必成。选哪件当本命、穿不穿、何时调，归 J2 的 ensure_bound。返回 {ok: jinran} 或 {error}
static func activate(s: XState, actor_id: int, item: Dictionary) -> Dictionary:
	if not on(s):
		return {"error": "现在不能浸染"}
	if bound_item(s, actor_id) != null:
		return {"error": "已有本命"}
	if item.get(FIELD) is Dictionary:
		return {"error": "这件已浸染过"}
	var iid := str(item.get("instanceId", ""))
	if iid == "":
		return {"error": "这件没有实例号"}
	var j := _blank()
	j.slots[0] = _roll_entry(s, actor_id, j, 1)
	j.n = 1
	item[FIELD] = j
	book(s).bound[str(actor_id)] = iid
	return {"ok": j}


## 强化换件（3.2 唯一例外）：本命的整份 jinran 搬到 new_item、bound 改指新实例，旧件的 jinran 清掉。J2 在原机制换件的同一次提交里调
static func move_to(s: XState, actor_id: int, new_item: Dictionary) -> Dictionary:
	if not on(s):
		return {"error": "现在不能搬"}
	var old = bound_item(s, actor_id)
	if old == null:
		return {"error": "没有本命"}
	var iid := str(new_item.get("instanceId", ""))
	if iid == "" or is_same(old, new_item):
		return {"error": "新件不对"}
	new_item[FIELD] = old[FIELD]
	old.erase(FIELD)
	book(s).bound[str(actor_id)] = iid
	return {"ok": new_item[FIELD]}


## 待选（打开异源池先弹它）：null 或 {kind "pick"/"wash", slot, old, cands}
static func pending(s: XState, actor_id: int) -> Variant:
	var it = bound_item(s, actor_id)
	return state_of(it).get("pending") if it != null else null


## 本步成功率（3.4）：{rate 合计, base, bonus 残留加成}
static func rate_of(j: Dictionary, to_tier: int) -> Dictionary:
	var st := _step(to_tier)
	var base := int(st.get("base", 0))
	var bonus := int(j.res.get(str(to_tier), 0)) * int(st.get("per_fail", 0))
	return {"rate": mini(100, base + bonus), "base": base, "bonus": bonus}


## 界面用（9.2）：下一步要多少、成功率、失败退到哪、哪格会沉睡；不改存档
static func preview(s: XState, actor_id: int) -> Dictionary:
	var it = bound_item(s, actor_id)
	if not on(s) or it == null:
		return {}
	var j := _norm(it[FIELD])
	var tier := int(j.tier)
	var out := {"tier": tier, "material": material_count(s), "pending": j.pending, "wash_marks": int(j.wash_marks)}
	if tier >= MAX_TIER:
		out["wash_cost"] = wash_cfg("cost", 40)
		return out
	var r := rate_of(j, tier + 1)
	out.merge({"next": tier + 1, "cost": step_cost(tier + 1), "rate": r.rate, "base": r.base, "bonus": r.bonus,
		"fail_to": maxi(1, tier - 1), "sleeps": SLEEP_SLOT if tier == 2 else 0})
	return out


static func _check_common(s: XState, actor_id: int) -> Variant:
	if not on(s):
		return {"error": "现在不能浸染"}
	var it = bound_item(s, actor_id)
	if it == null:
		return {"error": "没有本命"}
	var j := _norm(it[FIELD])
	if j.pending != null:
		return {"error": "先选完待选的词条"}
	return it


## 再浸一次（3.3）：一个事务提交。返回 {ok 成功与否, from, to, rate, cost, pending} 或 {error}
static func advance(s: XState, actor_id: int) -> Dictionary:
	var it = _check_common(s, actor_id)
	if it is Dictionary and it.has("error"):
		return it
	var j: Dictionary = it[FIELD]
	var tier := int(j.tier)
	if tier >= MAX_TIER:
		return {"error": "已到顶阶"}
	var to := tier + 1
	var cost := step_cost(to)
	if material_id() <= 0 or material_count(s) < cost:
		return {"error": "异源不足（要 %d）" % cost}
	var rate := int(rate_of(j, to).rate)
	var n := int(j.n)
	s.gain_item(material_id(), -cost)
	var roll := int(ok_tape.pop_front()) if not ok_tape.is_empty() else _stream(s, actor_id, n, "ok").next_index_mod(100, "jinran_ok")
	var ok := roll < rate
	if ok:
		j.tier = to
		j.res[str(to)] = 0
		if slot_count(to) > slot_count(tier):
			var slot := slot_count(to)
			var e := _roll_entry(s, actor_id, j, slot)
			if slot == SLEEP_SLOT and j.sleeping is Dictionary:
				j.pending = {"kind": "pick", "slot": slot, "old": j.sleeping, "cands": [e]}
				j.sleeping = null
			else:
				j.slots[slot - 1] = e
	else:
		j.res[str(to)] = int(j.res.get(str(to), 0)) + 1
		if tier > 1:
			j.tier = tier - 1
			if tier == SLEEP_SLOT:  # 蚀纹退到异痕：第 2 格（当时最终选定的那条）沉睡
				j.sleeping = j.slots[SLEEP_SLOT - 1]
				j.slots[SLEEP_SLOT - 1] = null
	j.n = n + 1
	return {"ok": ok, "from": tier, "to": int(j.tier), "rate": rate, "cost": cost, "pending": j.pending}


## 洗一条（3.6）：异构后，选一格，花异源，按这一格这一轮的洗牌堆出候选，写进待选；洗痕 +1。返回 {ok: pending} 或 {error}
static func wash(s: XState, actor_id: int, slot: int) -> Dictionary:
	var it = _check_common(s, actor_id)
	if it is Dictionary and it.has("error"):
		return it
	var j: Dictionary = it[FIELD]
	if int(j.tier) < MAX_TIER:
		return {"error": "异构后才能洗"}
	if slot < 1 or slot > SLOTS or not j.slots[slot - 1] is Dictionary:
		return {"error": "没有这一格"}
	var cost := wash_cfg("cost", 40)
	if material_id() <= 0 or material_count(s) < cost:
		return {"error": "异源不足（要 %d）" % cost}
	var n := int(j.n)
	s.gain_item(material_id(), -cost)
	var cands := _draw(s, actor_id, j, slot)
	var tst := _stream(s, actor_id, n, "tone")
	var entries := []
	for k in cands:
		entries.append({"key": k, "tone": _tone(tst)})
	j.pending = {"kind": "wash", "slot": slot, "old": j.slots[slot - 1], "cands": entries}
	j.wash_marks = int(j.wash_marks) + 1
	j.n = n + 1
	return {"ok": j.pending}


## 从第 slot 格的洗牌堆抽这一次的候选（3.6）：
## - 轮开始（没有堆或本轮次数用完）：把这一格当时的合法池洗成一叠，本轮次数＝per_round；
## - 轮中：叠里删掉已经不合法的；新变合法、本轮还没出过的随机插进剩下的叠里；
## - 先按叠的次序抽，叠空了从合法池里随便补；同一次的候选不重复。抽到的记进本轮 seen，本轮次数 -1。
## 各格的堆各走各的：洗这一格不碰别格的堆。
static func _draw(s: XState, actor_id: int, j: Dictionary, slot: int) -> Array:
	var n := int(j.n)
	var dst := _stream(s, actor_id, n, "deck")
	var kst := _stream(s, actor_id, n, "key")
	var pool := legal_pool(j, slot)
	var d = j.deck.get(str(slot))
	if not d is Dictionary or int(d.get("left", 0)) <= 0:
		var cards := pool.duplicate()
		_shuffle(cards, dst)
		d = {"left": wash_cfg("per_round", 3), "cards": cards, "seen": []}
		j.deck[str(slot)] = d
	else:
		var cards: Array = (d.get("cards", []) as Array).filter(func(k): return pool.has(k))
		var seen: Array = d.get("seen", [])
		for k in pool:
			if not cards.has(k) and not seen.has(k):
				cards.insert(dst.next_index_mod(cards.size() + 1, "jinran_deck"), k)
		d.cards = cards
		if not d.get("seen") is Array:
			d.seen = []
	var want := wash_cfg("cands", 3)
	var out := []
	while out.size() < want and not (d.cards as Array).is_empty():
		var k = d.cards.pop_front()
		if not out.has(k):
			out.append(k)
	while out.size() < want:
		var rest := pool.filter(func(k): return not out.has(k))
		if rest.is_empty():
			break
		out.append(_pick(rest, kst))
	for k in out:
		if not d.seen.has(k):
			d.seen.append(k)
	d.left = int(d.left) - 1
	return out


## 结算待选：index 0＝留旧的（二选一里是沉睡那条；洗一条里是本格原来那条），1… ＝第几个新候选。只结算一次。返回 {ok: 选中的} 或 {error}
static func choose(s: XState, actor_id: int, index: int) -> Dictionary:
	if not on(s):
		return {"error": "现在不能浸染"}
	var it = bound_item(s, actor_id)
	if it == null:
		return {"error": "没有本命"}
	var j := _norm(it[FIELD])
	var p = j.pending
	if not p is Dictionary:
		return {"error": "没有待选"}
	var opts := [p.get("old")] + (p.get("cands", []) as Array)
	if index < 0 or index >= opts.size() or not opts[index] is Dictionary:
		return {"error": "没有这个选项"}
	j.slots[int(p.slot) - 1] = opts[index]
	j.pending = null
	return {"ok": opts[index]}


## 洗痕攒满：把这件任意一格从淡改浓（同名不换），洗痕清零（3.6）
static func spend_marks(s: XState, actor_id: int, slot: int) -> Dictionary:
	var it = _check_common(s, actor_id)
	if it is Dictionary and it.has("error"):
		return it
	var j: Dictionary = it[FIELD]
	if int(j.wash_marks) < wash_cfg("marks_need", 6):
		return {"error": "洗痕不够"}
	if slot < 1 or slot > SLOTS or not j.slots[slot - 1] is Dictionary:
		return {"error": "没有这一格"}
	if str(j.slots[slot - 1].get("tone", "")) == "nong":
		return {"error": "已经是浓的"}
	j.slots[slot - 1].tone = "nong"
	j.wash_marks = 0
	return {"ok": j.slots[slot - 1]}


## 这一格这一轮还剩几次（界面「这一轮还剩 X 次」；没开过轮或本轮用完＝一整轮）
static func round_left(s: XState, actor_id: int, slot: int) -> int:
	var it = bound_item(s, actor_id)
	var d = state_of(it).get("deck", {}).get(str(slot)) if it != null else null
	var left := int(d.get("left", 0)) if d is Dictionary else 0
	return left if left > 0 else wash_cfg("per_round", 3)
