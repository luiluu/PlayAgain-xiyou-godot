class_name XAlienation
extends RefCounted
## 异化（installAlienationRuntime＋installAlienationAdvanced，CodexAlienation）的工坊侧：异化标记、账本、合成、重抽、待选、分解。
## 工坊页在 ui/alien_workshop.gd；参照 mv_oracle/alien_workshop_probe.cjs（测试 tests/xiyou_alien_workshop）。数据 alienation.json（配置与 20 条词条说明）。
## - 异化装备是普通独立装备实例（XState.gear 里的字典）多一个 alien 字段：{uid, origin "mob"/"boss", affix, pool, config, plainName, lastName}，
##   随装备存档；名字改成「词条名·原名」（relabel）。账本 XState.alien_ledger（$gameSystem._alienLedger：sequence、pending 待选重抽、recent 最近掉落）。
## - 原版出错时抛异常、工坊显示在错误条里；这里返回 {"error": 文字}，成功返回 {"ok": 值}。
## 战斗里的异化敌人、掉落发放与词条效果不在这里，接口见交付单「规则接口」。

const DATA := "res://modes/xiyou/alienation.json"
const MAX_ITEMS := 9999
const OPERATE_ERROR := "仅可操作背包中未装备、未锁定、未绑定的异化装备；先完成待选重抽。"
static var _config := {}
## 测试用：≥0 时 Math.random 固定取它
static var force_roll := -1.0


static func config() -> Dictionary:
	if _config.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_config = d if d is Dictionary else {}
	return _config


static func affix(key: String) -> Dictionary:
	for f in config().get("affixes", []):
		if str(f.key) == key:
			return f
	return {}


static func energy_id() -> int:
	return int(config().ids.energy)


static func stone_id() -> int:
	return int(config().ids.stone)


static func choose(xs: Array):
	var r := force_roll if force_roll >= 0 else randf()
	return xs[mini(floori(r * xs.size()), xs.size() - 1)]


static func kind(i: Dictionary) -> String:
	return "w" if str(i.get("kind", "")) == "weapon" else "a"


static func key(i: Dictionary) -> String:
	return kind(i) + ":" + str(int(i.get("base", 0)))


static func mark(i) -> Dictionary:
	return i.get("alien", {}) if i is Dictionary else {}


static func ledger(s: XState) -> Dictionary:
	if s.alien_ledger.is_empty():
		s.alien_ledger = {"sequence": 0, "pending": null, "recent": [], "metrics": {}}
	return s.alien_ledger


static func _serial(i: Dictionary) -> int:
	return int(str(i.get("instanceId", "xg:0")).get_slice(":", 1))


## A.owned：背包里的武器（按获得先后）再接防具；已装备的不算
static func owned(s: XState) -> Array:
	var ws := s.gear.filter(func(e): return str(e.kind) == "weapon")
	var as_ := s.gear.filter(func(e): return str(e.kind) != "weapon")
	ws.sort_custom(func(a, b): return _serial(a) < _serial(b))
	as_.sort_custom(func(a, b): return _serial(a) < _serial(b))
	return ws + as_


static func _equipped(s: XState) -> Array:
	var out := []
	for a in s.actors.values():
		out.append_array(a.equip_list())
	return out


static func _has(list: Array, i: Dictionary) -> bool:
	return list.any(func(e): return is_same(e, i))


static func locked(i: Dictionary) -> bool:
	var n := str(i.get("name", ""))
	return n.contains("[锁定]") or n.contains("【锁定】")


## A.reserved：被某件吞器异化装备选作供体的武器
static func reserved(s: XState, i: Dictionary, except = null) -> bool:
	if kind(i) != "w":
		return false
	for item in owned(s) + _equipped(s):
		var m := mark(item)
		if not m.is_empty() and not is_same(item, except) and str(m.affix) == "swallow" and str(m.get("config", {}).get("donorId", "")) == str(i.get("instanceId", "")):
			return true
	return false


static func bound(s: XState, i: Dictionary) -> bool:
	return _has(_equipped(s), i) or reserved(s, i)


static func can_operate(s: XState, i: Dictionary) -> bool:
	return not mark(i).is_empty() and _has(owned(s), i) and not locked(i) and not bound(s, i) and ledger(s).pending == null


static func needs_configuration(i: Dictionary) -> bool:
	var m := mark(i)
	return not m.is_empty() and (["mimic", "faceless", "swallow"] + Array(config().boundKeys) + Array(config().skillKeys)).has(str(m.affix))


## A.details（含进阶模块追加的配置行）
static func details(s: XState, i: Dictionary) -> Array:
	var m := mark(i)
	var f := affix(str(m.get("affix", "")))
	if f.is_empty():
		return []
	var boss := str(m.origin) == "boss"
	var out := ["异化：" + str(f.name), "收益：" + str(f.benefit), "代价：" + str(f.cost), "来源：" + ("异化Boss" if boss else "异化小怪") + "；分解获得" + ("5" if boss else "1") + "点能量"]
	var c: Dictionary = m.get("config", {})
	if c.has("actorId"):
		out.append("使用角色：" + (s.actor(int(c.actorId)).display_name() if s.actors.has(int(c.actorId)) else "配置失效"))
	if c.has("partnerId"):
		out.append("绑定队友：" + (s.actor(int(c.partnerId)).display_name() if s.actors.has(int(c.partnerId)) else "配置失效"))
	if c.has("skillId"):
		var sk := XDB.rec("Skills", int(c.skillId))
		out.append("作用技能：" + (str(sk.name) if not sk.is_empty() else "配置失效"))
	if c.has("donorId"):
		var donor = (owned(s) + _equipped(s)).filter(func(e): return str(e.get("instanceId", "")) == str(c.donorId))
		out.append("借用武器：" + (str(donor[0].name) if not donor.is_empty() else "配置失效"))
	if ["swallow", "offer", "possession", "wish", "silence", "erosion", "insulation", "jail", "glutton"].has(str(m.affix)):
		out.append("适配：仅作用于已登记的普通特性、技能或状态；身份、剧情、唯一与自定义机制不转换。")
	return out


## A.relabel：名字改成「词条名·原名」；名字被别处改过（如加了锁定）就先按新名字去掉旧词条前缀重新记原名
static func relabel(i: Dictionary) -> void:
	var m := mark(i)
	if m.is_empty():
		return
	if str(i.name) != str(m.lastName):
		var names := PackedStringArray(config().affixes.map(func(f): return str(f.name)))
		m.plainName = RegEx.create_from_string("^(" + "|".join(names) + ")·").sub(str(i.name), "")
	i.name = str(affix(str(m.affix)).name) + "·" + str(m.plainName)
	m.lastName = i.name


## A.poolFor：本体兼容池；小怪来源去掉 Boss 专属词条
static func pool_for(i: Dictionary, origin: String) -> Array:
	var pool: Array = config().pools.get(key(i), [])
	return pool.filter(func(k): return origin == "boss" or not config().bossOnly.has(k))


static func attach(s: XState, i: Dictionary, origin: String, affix_key := "") -> Dictionary:
	var pool := pool_for(i, origin)
	if pool.size() < 3 or (affix_key != "" and not pool.has(affix_key)):
		return {"error": "该来源或本体不兼容此异化"}
	if affix_key == "":
		affix_key = choose(pool)
	ledger(s).sequence = int(ledger(s).sequence) + 1
	i.alien = {"uid": "alien-%d" % int(ledger(s).sequence), "origin": origin, "affix": affix_key, "pool": pool.duplicate(),
		"config": {}, "plainName": str(i.name), "lastName": str(i.name)}
	relabel(i)
	return {"ok": i}


## A.create：新建一件独立装备并异化（不放进背包；期三的掉落发放与测试用）
static func create(s: XState, kind_key: String, id: int, origin: String, affix_key := "") -> Dictionary:
	var inst := XGear.create("weapon" if kind_key == "w" else "armor", id, s)
	if inst.is_empty():
		return {"error": "异化本体缺失"}
	s.register_gear(inst)
	return attach(s, inst, origin, affix_key)


static func craft(s: XState, amount := 1) -> Dictionary:
	if ledger(s).pending != null or amount < 1:
		return {"error": "现在不能合成"}
	var cost := amount * int(config().energyCost)
	if s.item_count(energy_id()) < cost or s.item_count(stone_id()) + amount > MAX_ITEMS:
		return {"error": "能量不足或异化石已达持有上限"}
	s.gain_item(energy_id(), -cost)
	s.gain_item(stone_id(), amount)
	return {"ok": amount}


static func reroll(s: XState, i: Dictionary) -> Dictionary:
	var m := mark(i)
	if not m.is_empty():
		m.pool = pool_for(i, str(m.origin))
	if not can_operate(s, i):
		return {"error": OPERATE_ERROR}
	var pool: Array = m.pool.filter(func(k): return k != m.affix and not affix(str(k)).is_empty())
	if m.pool.size() < 3 or pool.size() < 2:
		return {"error": "本体没有完整随机池"}
	if s.item_count(stone_id()) < 1:
		return {"error": "缺少异化石"}
	s.gain_item(stone_id(), -1)
	ledger(s).pending = {"uid": m.uid, "kind": kind(i), "id": str(i.get("instanceId", "")), "old": m.affix, "next": choose(pool)}
	return {"ok": ledger(s).pending}


static func pending_item(s: XState):
	var p = ledger(s).pending
	if p == null:
		return null
	for i in owned(s) + _equipped(s):
		if str(mark(i).get("uid", "")) == str(p.uid):
			return i
	return null


static func resolve(s: XState, use_new: bool) -> Dictionary:
	var p = ledger(s).pending
	var i = pending_item(s)
	if p == null or i == null or not _has(owned(s), i):
		return {"error": "待选装备不可用"}
	var m := mark(i)
	if str(m.affix) != str(p.old):
		return {"error": "待选装备已发生变化"}
	if use_new:
		m.affix = p.next
		m.config = {}
		relabel(i)
	ledger(s).pending = null
	return {"ok": true}


static func dismantle(s: XState, i: Dictionary) -> Dictionary:
	if not can_operate(s, i):
		return {"error": OPERATE_ERROR}
	var n := 5 if str(mark(i).origin) == "boss" else 1
	if s.item_count(energy_id()) + n > MAX_ITEMS:
		return {"error": "异化能量已达持有上限"}
	var idx := s.gear.find_custom(func(e): return is_same(e, i))
	s.gear.remove_at(idx)
	s.gain_item(energy_id(), n)
	return {"ok": n}
