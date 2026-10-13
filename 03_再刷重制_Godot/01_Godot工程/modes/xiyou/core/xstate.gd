class_name XState
extends RefCounted
## 西游模式的一局游戏状态（相当于 MV 的 $gameParty/$gameSwitches/$gameVariables/$gameSelfSwitches/$gamePlayer 位置）。
## 只属于西游模式；存档读写 to_dict()/from_dict()，保存位置由 GameApp.save_directory() 决定。

const SAVE_VERSION := 2
static var current: XState

var difficulty := 3
var party: Array[int] = []          # 队伍顺序（前 5 位出战）
var actors := {}                    # actor_id -> XActor
var gold := 0
var items := {}                     # item_id -> 数量
var next_gear_id := 1
var gear: Array = []                # 背包里的装备实例
var switches := {}                  # id -> bool
var variables := {}                 # id -> 数值
var self_switches := {}             # "map,event,A" -> bool
var map_id := 0
var x := 0
var y := 0
var direction := 2
var steps := 0
var play_seconds := 0.0
var encounter_count := 0
## Star_RomGetItems 的装备预掷随机池（见 XGear），随存档保存
var rom := {"x": [], "xn": 0, "xs": [], "xsn": 0, "g": [], "gn": 0}
## Galv_NewItemIndication 的 $gameSystem._seenItems：看过的物品（物品 ID／装备实例 ID）不再画 NEW
var seen := {}
## 事件脚本里给 $gameParty / $gamePlayer 挂的零散标记（DCultyL1～8 等），按原名保存
var flags := {}
## $gamePlayer.SaveActorName：开局输入的名字（称号、成就里用）
var actor_name := ""
## 事件脚本「所有角色学会/忘记技能」：MV 会当场建出全部角色；这里按顺序记下，角色第一次建出时补上（见 actor()）
## 每条 {"op": "learn"/"forget", "skill": N, "ids": [] 为全体, "exclude": [], "named": 只限有名字的角色}
var actor_ops: Array = []


static func new_game(difficulty_id: int, starter_id: int, companions: Array) -> XState:
	var s := XState.new()
	s.difficulty = difficulty_id
	for id in [starter_id] + companions:
		s.add_actor(int(id))
	current = s
	return s


## MV setupNewGame：System 的初始队伍（西游为空）与起点（Map001 (7,10)），难度取 Vitsuno_Difficulty 的 Init Difficulty ID。
## 之后由 Map001/Map002/Map221 的原版事件选存档位、难度、英雄与教派。
static func new_game_blank() -> XState:
	var s := XState.new()
	var sys := XDB.system()
	s.difficulty = int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2))
	for id in sys.get("partyMembers", []):
		s.add_actor(int(id))
	s.map_id = int(sys.get("startMapId", 1))
	s.x = int(sys.get("startX", 0))
	s.y = int(sys.get("startY", 0))
	s.direction = 2
	XSave.current_slot = 0
	current = s
	return s


func actor(id: int) -> XActor:
	if not actors.has(id):
		actors[id] = XActor.new().setup(id)
		for op in actor_ops:
			_apply_actor_op(actors[id], op)
		actors[id].refresh_passive()
		for e in actors[id].equip_list():register_gear(e)
	return actors[id]


## 记下一条「所有角色学会/忘记技能」，并对已经建出的角色立刻生效
func add_actor_op(op: Dictionary) -> void:
	actor_ops.append(op)
	for a in actors.values():
		_apply_actor_op(a, op)
		a.refresh_passive()


static func _apply_actor_op(a: XActor, op: Dictionary) -> void:
	var ids: Array = op.get("ids", [])
	if not ids.is_empty() and not ids.has(a.actor_id):
		return
	if op.get("exclude", []).has(a.actor_id):
		return
	if bool(op.get("named", false)) and str(a.data().get("name", "")) == "":
		return
	if str(op.op) == "forget":
		a.forget_skill(int(op.skill))
	else:
		a.learn_skill(int(op.skill))


## 开局选的固定存档位：开关 161～165 → 1～5，276～280 → 6～10（公共事件 1「存档」等按它保存）；未选为 0
func fixed_save_slot() -> int:
	for i in range(5):
		if switch(161 + i):
			return i + 1
	for i in range(5):
		if switch(276 + i):
			return i + 6
	return 0

func add_actor(id: int) -> void:
	if not party.has(id) and not XDB.rec("Actors", id).is_empty():
		actor(id)
		party.append(id)

func remove_actor(id: int) -> void:
	party.erase(id)

func members() -> Array:
	return party.map(func(id): return actor(id))

## 出战上限 5：YEP_PartySystem 参数写 4，但后加载的 MrTS_BattleCharacterLimit 把 maxBattleMembers 改为 5（参数为空取默认）。
## YEP 的编队界面（自选出战成员）未做，暂按队伍前 5 人。
const MAX_BATTLE_MEMBERS := 5

func battle_members() -> Array:
	return members().slice(0, MAX_BATTLE_MEMBERS)


func switch(id: int) -> bool:
	return switches.get(id, false)

func set_switch(id: int, on: bool) -> void:
	switches[id] = on

func variable(id: int) -> float:
	return variables.get(id, 0)

func set_variable(id: int, value: float) -> void:
	variables[id] = value

## 公式用的变量表 v[...]：未定义的按 0。
func variable_array(size := 5000) -> Array:
	var out := []
	out.resize(size)
	out.fill(0)
	for k in variables:
		if int(k) < size:
			out[int(k)] = variables[k]
	return out

func self_switch(map: int, event: int, letter: String) -> bool:
	return self_switches.get("%d,%d,%s" % [map, event, letter], false)

func set_self_switch(map: int, event: int, letter: String, on: bool) -> void:
	self_switches["%d,%d,%s" % [map, event, letter]] = on


func item_count(id: int) -> int:
	return items.get(id, 0)

func gain_item(id: int, amount: int) -> void:
	items[id] = clampi(item_count(id) + amount, 0, 9999)  # $gameParty.maxItems（正式版运行时为 9999）
	if items[id] == 0:
		items.erase(id)

func gain_gear(kind: String, base_id: int, amount: int) -> void:
	if amount > 0:
		for i in range(amount):
			var inst := XGear.create(kind, base_id)
			if not inst.is_empty():
				register_gear(inst)
				gear.append(inst)
	else:
		for i in range(-amount):
			var idx := gear.find_custom(func(e): return e.kind == kind and int(e.base) == base_id)
			if idx >= 0:
				gear.remove_at(idx)

func register_gear(item: Dictionary) -> void:
	var defaults := XGear.template(str(item.kind),int(item.base))
	for key in ["equipment","upgradeSlots","originalUpgradeSlots","boostCount","upgrades","affixIds","baseName"]:
		if not item.has(key):item[key]=defaults.get(key)
	if not item.has("instanceId"):
		item.instanceId = "xg:%d" % next_gear_id
		next_gear_id += 1
	else:
		next_gear_id = maxi(next_gear_id,int(str(item.instanceId).get_slice(":",1))+1)

func owns_gear(item: Dictionary) -> bool:
	for e in gear:
		if is_same(e,item):return true
	for a in actors.values():
		for e in a.equip_list():
			if is_same(e,item):return true
	return false

func gear_count(kind: String, base_id: int) -> int:
	return gear.filter(func(e): return e.kind == kind and int(e.base) == base_id).size()

## 物品记 "i:<ID>"，装备记实例 ID（原版独立装备各有自己的 ID）
static func seen_key(rec: Dictionary) -> String:
	return str(rec.instanceId) if rec.has("instanceId") else "i:%d" % int(rec.get("id", 0))

func is_new(rec: Dictionary) -> bool:
	return not rec.is_empty() and not seen.has(seen_key(rec))

func mark_seen(rec: Dictionary) -> void:
	if not rec.is_empty():
		seen[seen_key(rec)] = true

func gain_gold(amount: int) -> void:
	gold = clampi(gold + amount, 0, 999999999)


# ---- 存档 ----
func to_dict() -> Dictionary:
	var a := {}
	for id in actors:
		var x2: XActor = actors[id]
		a[str(id)] = {"level": x2.level, "exp": x2.exp_total, "skills": x2.skill_ids, "equips": x2.equips,
			"hp": x2.hp, "mp": x2.mp, "states": x2.state_ids, "cooldowns": x2.cooldowns}
	return {"version": SAVE_VERSION, "mode": "xiyou", "difficulty": difficulty, "party": party, "actors": a, "gold": gold,
		"items": items, "gear": gear, "nextGearId":next_gear_id, "switches": switches, "variables": variables, "selfSwitches": self_switches,
		"mapId": map_id, "x": x, "y": y, "direction": direction, "steps": steps, "playSeconds": play_seconds, "rom": rom,
		"seen": seen.keys(), "flags": flags, "actorName": actor_name, "actorOps": actor_ops}

static func from_dict(d: Dictionary) -> XState:
	var s := XState.new()
	s.difficulty = int(d.difficulty)
	for id_s in d.actors:
		var row: Dictionary = d.actors[id_s]
		var x2 := XActor.new().setup(int(id_s))
		x2.change_level(int(row.level))
		x2.exp_total = int(row.exp)
		x2.skill_ids.assign(row.skills.map(func(v): return int(v)))
		x2.equips = row.equips
		x2.state_ids.assign(row.states.map(func(v): return int(v)))
		x2.refresh_passive()
		x2.hp = float(row.hp)
		x2.mp = float(row.mp)
		for k in row.get("cooldowns", {}):
			x2.cooldowns[int(k)] = float(row.cooldowns[k])
		s.actors[int(id_s)] = x2
	s.party.assign(d.party.map(func(v): return int(v)))
	s.gold = int(d.gold)
	for k in d.items:
		s.items[int(k)] = int(d.items[k])
	s.gear = d.gear
	s.next_gear_id = int(d.get("nextGearId",1))
	for a in s.actors.values():
		for e in a.equip_list():s.register_gear(e)
	for e in s.gear:s.register_gear(e)
	for a in s.actors.values():a.refresh_passive()
	for k in d.switches:
		s.switches[int(k)] = bool(d.switches[k])
	for k in d.variables:
		s.variables[int(k)] = d.variables[k]
	s.self_switches = d.selfSwitches
	s.map_id = int(d.mapId)
	s.x = int(d.x)
	s.y = int(d.y)
	s.direction = int(d.direction)
	s.steps = int(d.steps)
	s.play_seconds = float(d.playSeconds)
	var rom: Dictionary = d.get("rom", {})
	s.rom = {"x": rom.get("x", []).map(func(v): return float(v)), "xn": int(rom.get("xn", 0)),
		"xs": rom.get("xs", []).map(func(v): return int(v)), "xsn": int(rom.get("xsn", 0)),
		"g": rom.get("g", []).map(func(v): return int(v)), "gn": int(rom.get("gn", 0))}
	s.flags = d.get("flags", {})
	s.actor_name = str(d.get("actorName", ""))
	for op in d.get("actorOps", []):
		s.actor_ops.append({"op": str(op.op), "skill": int(op.skill), "ids": op.get("ids", []).map(func(v): return int(v)),
			"exclude": op.get("exclude", []).map(func(v): return int(v)), "named": bool(op.get("named", false))})
	for k in d.get("seen", []):
		s.seen[str(k)] = true
	current = s
	return s
