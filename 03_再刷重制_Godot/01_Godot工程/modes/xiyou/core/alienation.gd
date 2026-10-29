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


## O-待定（优化登记）：原版一键出售（Scene_Shop.sellUnifiedQuality→doSell）不查吞器占用，供体照给钱，loseItem 包装（Adv:88）
## 又不让它失去——每卖一次白拿一次钱。true＝一键出售跳过占用的供体；false＝照原版（XItemMarks.sellable_gear）
static var o_reserved_onekey := true


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


## ---- 期二：配置异化与就绪判定（installAlienationAffixes／installAlienationAdvanced） ----

const AFFIX_ERROR := "配置不合法：替换技能必须已学会，借入技能必须来自另一名已拥有角色且通过白名单。"
const ADVANCED_ERROR := "配置不兼容：请选择已拥有队友、登记技能或未占用的供体装备。"
## 首发六种（Affixes 模块）；其余 14 种由 Advanced 模块接管就绪判定与配置
const FIRST_SIX := ["inversebone", "blessing", "mimic", "prayer", "pest", "faceless"]
const LIFE_KEYS := ["lifelink", "scapegoat", "possession"]
const PARTNER_TAKEN := ["lifelink", "scapegoat", "possession", "offer", "sacrifice", "hollow", "jail", "insulation"]


static func templates() -> Dictionary:
	return config().get("templates", {})


## templates 各表首次查时转成集合（jailStates 172 项，每次 addState 都查，线性扫太慢）
static var _template_sets := {}


static func _in(list_key: String, id: int) -> bool:
	if not _template_sets.has(list_key):
		var d := {}
		for x in templates().get(list_key, []):
			d[int(x)] = true
		_template_sets[list_key] = d
	return (_template_sets[list_key] as Dictionary).has(id)


## A.actors：队伍全员（$gameParty._actors 顺序）
static func actors(s: XState) -> Array:
	return s.members()


static func _member(s: XState, id) -> XActor:
	return s.actor(int(id)) if id != null and s.party.has(int(id)) else null


## A.forActor：战斗中是开战时冻结的那份（XAlienBattle.locked），战斗外是身上第一件异化装备
static func for_actor(a: XActor) -> Dictionary:
	var frozen = XAlienBattle.locked(a)
	if frozen != null:
		return frozen
	for e in a.equip_list():
		if not mark(e).is_empty():
			return {"item": e, "affix": str(mark(e).affix), "config": mark(e).get("config", {})}
	return {}


## CodexYunshang.key：身上云裳天衣（本体 7920～7934）的序号，没有为 -1
static func yunshang_key(a: XActor) -> int:
	for e in a.equip_list():
		var b := int(e.get("base", 0))
		if b >= 7920 and b < 7935:
			return b - 7920
	return -1


## A.nativeSkills：角色的技能（不含异化改动）
static func native_skills(a: XActor) -> Array:
	return a.native_skills()


## A.originalActive：已学会的主动技能（不含被动、仅菜单／不能用的、普攻防御与百相切换）
static func original_active(a: XActor) -> Array:
	var sw := int(config().ids.switch)
	var out := []
	for sk in native_skills(a):
		var id := int(sk.id)
		if a.skill_ids.has(id) and id > 2 and int(sk.get("stypeId", 0)) != 4 and int(sk.get("occasion", 0)) != 3 and int(sk.get("occasion", 0)) != 2 and id != sw:
			out.append(sk)
	return out


## A.borrowable：登记攻击技能、名字不含处决等字样、效果只有可传播的减益或可共享的增益
static func borrowable(sk: Dictionary) -> bool:
	if sk.is_empty() or int(sk.id) <= 2 or not _in("attack", int(sk.id)):
		return false
	if RegEx.create_from_string("处决|秒杀|剧情|阶段|召唤|变身").search(str(sk.get("name", ""))):
		return false
	var debuffs: Array = config().get("transferDebuffs", [])
	var buffs: Array = config().get("shareBuffs", [])
	for e in sk.get("effects", []):
		var code := int(e.code)
		var id := int(e.dataId)
		if not (code == 21 and (_in("pestStates", id) or debuffs.any(func(x): return int(x) == id)) or code == 22 and buffs.any(func(x): return int(x) == id)):
			return false
	return true


## A.lifeCompatible：不穿云裳第 3 件、特性里没有免死／复活类备注
static func life_compatible(a: XActor) -> bool:
	if a == null or yunshang_key(a) == 3:
		return false
	var re := RegEx.create_from_string("(?:死亡免疫|不死|自动复活|复活自己|濒死复活|<Custom (?:React|Respond|Confirm|Establish|Deselect) Effect>[\\s\\S]*(?:revive|deathStateId|\\.die\\(|setHp\\())")
	return not a.trait_objects().any(func(o): return o is Dictionary and re.search(str(o.get("note", ""))) != null)


## A.bindingOptions：可绑定的队友（不是自己；生命类双方都要兼容；对方身上没有生命／绑定类异化；对方不穿云裳第 3 件）
static func binding_options(s: XState, a: XActor, k: String) -> Array:
	return actors(s).filter(func(p): return p != a and (not LIFE_KEYS.has(k) or life_compatible(a) and life_compatible(p)) and (for_actor(p).is_empty() or not PARTNER_TAKEN.has(str(for_actor(p).affix))) and yunshang_key(p) != 3)


## A.effectGhost：装备能借出的登记效果（特性限 gearTraitCodes，备注限护盾、自身物理／元素倍率）；唯一、神话等不借
static func effect_ghost(i) -> Dictionary:
	if not (i is Dictionary) or i.is_empty() or not mark(i).is_empty():
		return {}
	if RegEx.create_from_string("(?i)Unique|Myth|Heartsteel|Yunshang|MagicWeapon|神器|唯一|神话|<quality:\\s*10>").search(str(i.get("note", ""))):
		return {}
	var codes: Array = templates().get("gearTraitCodes", [])
	var traits := []
	for t in i.get("traits", []):
		var code := int(t.code)
		var id := int(t.dataId)
		if codes.any(func(x): return int(x) == code) and not (code == 22 and id >= 6) and not (code == 23 and [1, 3, 4, 5, 6, 7, 8, 9].has(id)):
			traits.append(t.duplicate())
	var note := ""
	for tag in ["ShieldEffect", "SelfPhysRate", "SelfElemRate"]:
		for m in RegEx.create_from_string("(?i)<" + tag + "\\s*:\\s*([+-]?[\\d.]+%?)\\s*>").search_all(str(i.get("note", ""))):
			note += m.get_string() + "\n"
	if traits.is_empty() and note == "":
		return {}
	return {"id": 0, "name": "异化借用效果", "note": note, "meta": {}, "traits": traits, "params": [0, 0, 0, 0, 0, 0, 0, 0], "_alienEffect": true}


## 原版 bound（未含吞器占用）：已装备（或另有占用记号）
static func _bound_base(s: XState, i: Dictionary) -> bool:
	return _has(_equipped(s), i)


static func _gear_by_id(s: XState, id) -> Dictionary:
	for e in owned(s) + _equipped(s):
		if str(e.get("instanceId", "")) == str(id):
			return e
	return {}


## A.ready：异化装备在这名角色身上能否生效（穿戴与配置都用它）
static func ready(s: XState, a: XActor, i: Dictionary) -> bool:
	var m := mark(i)
	if m.is_empty():
		return true
	var k := str(m.affix)
	var c: Dictionary = m.get("config", {})
	var natives := native_skills(a)
	var attack_id := a.attack_skill_id()  # 原版 actor.attackSkillId()（武器／状态等的 <Replace Attack> 与甚尔、宿傩）
	if FIRST_SIX.has(k):
		var owned_ids := original_active(a).map(func(sk): return int(sk.id))
		match k:
			"blessing":
				return natives.any(func(sk): return _in("blessing", int(sk.id)))
			"prayer":
				return _in("attack", attack_id) or natives.any(func(sk): return _in("attack", int(sk.id)))
			"inversebone":
				return _in("inversebone", attack_id) or natives.any(func(sk): return _in("inversebone", int(sk.id)))
			"mimic":
				return c.has("actorId") and int(c.actorId) == a.actor_id and owned_ids.has(int(c.get("replace", -1)))
			"faceless":
				var pairs: Array = c.get("pairs", [])
				if not (c.has("actorId") and int(c.actorId) == a.actor_id and pairs.size() > 0 and pairs.size() <= 2):
					return false
				var used := []
				for p in pairs:
					var owner := _member(s, p.get("ownerId"))
					var sk := XDB.rec("Skills", int(p.get("skillId", 0)))
					var rid := int(p.get("replaceId", 0))
					if owner == null or owner == a or used.has(rid) or not owned_ids.has(rid) or a.skill_ids.has(int(p.get("skillId", 0))) \
							or not borrowable(sk) or not owner.skill_ids.has(int(p.get("skillId", 0))):
						return false
					used.append(rid)
				return true
		return k == "pest"
	if Array(config().boundKeys).has(k):
		var p := _member(s, c.get("partnerId"))
		if not c.has("actorId") or int(c.actorId) != a.actor_id or p == null or not binding_options(s, a, k).has(p):
			return false
		if k == "possession" and not native_skills(p).any(func(sk): return p.skill_ids.has(int(sk.id)) and _in("possessionSkills", int(sk.id))):
			return false
		if k == "offer" and not a.equip_list().any(func(e): return not effect_ghost(e).is_empty()):
			return false
		return true
	if k == "swallow":
		var donor := _gear_by_id(s, c.get("donorId", ""))
		return c.has("actorId") and int(c.actorId) == a.actor_id and kind(i) == "w" and not donor.is_empty() and str(donor.kind) == "weapon" \
			and _has(owned(s), donor) and not locked(donor) and not _bound_base(s, donor) and not reserved(s, donor, i) and not effect_ghost(donor).is_empty()
	if Array(config().skillKeys).has(k):
		var sid := int(c.get("skillId", 0))
		return c.has("actorId") and int(c.actorId) == a.actor_id and original_active(a).any(func(sk): return int(sk.id) == sid) and _in("silence" if k == "silence" else "attack", sid)
	if k == "wish":
		return natives.any(func(sk): return _in("wish", int(sk.id)))
	return true


## A.configure：先查能否操作，换上新配置后用 ready 验，不合法就还原
static func configure(s: XState, i: Dictionary, c: Dictionary) -> Dictionary:
	if not can_operate(s, i):
		return {"error": OPERATE_ERROR}
	var m := mark(i)
	var prev = m.get("config", {})
	m.config = c.duplicate(true)
	var a := _member(s, c.get("actorId"))
	if a == null or not ready(s, a, i):
		m.config = prev
		return {"error": AFFIX_ERROR if FIRST_SIX.has(str(m.affix)) else ADVANCED_ERROR}
	return {"ok": true}


static func clear_configuration(s: XState, i: Dictionary) -> Dictionary:
	if not can_operate(s, i):
		return {"error": OPERATE_ERROR}
	mark(i).config = {}
	return {"ok": true}


## ---- 期二：穿戴限制（Game_Actor.changeEquip／forceChangeEquip／canEquip 的异化部分） ----

static func is_pending(s: XState, i) -> bool:
	var p = ledger(s).pending
	return p != null and i is Dictionary and not mark(i).is_empty() and str(mark(i).uid) == str(p.uid)


## canEquip 附加条件：异化装备要在这名角色身上就绪
static func can_wear(s: XState, a: XActor, i) -> bool:
	return not (i is Dictionary) or mark(i).is_empty() or ready(s, a, i)


## changeEquip 附加条件：待选重抽的装备不能换上换下；同一角色只能穿一件异化装备；要就绪（战斗中不换装，菜单外不涉及）
static func can_change(s: XState, a: XActor, slot: int, next) -> bool:
	var current = a.equips[slot] if slot >= 0 and slot < a.equips.size() else null
	if is_pending(s, next) or is_pending(s, current):
		return false
	# installAlienationAdvanced 87：吞器占用的供体不能穿；战斗中吞器、献器者与献器的队友不能换装
	if next is Dictionary and reserved(s, next) or XAlienBattle.gear_locked(a):
		return false
	if next is Dictionary and not mark(next).is_empty():
		for n in a.equips.size():
			if n != slot and a.equips[n] is Dictionary and not mark(a.equips[n]).is_empty():
				return false
		if not ready(s, a, next):
			return false
	return true
