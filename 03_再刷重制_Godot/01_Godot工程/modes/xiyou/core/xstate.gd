class_name XState
extends RefCounted
## 西游模式的一局游戏状态（相当于 MV 的 $gameParty/$gameSwitches/$gameVariables/$gameSelfSwitches/$gamePlayer 位置）。
## 只属于西游模式；存档读写 to_dict()/from_dict()，保存位置由 GameApp.save_directory() 决定。

const SAVE_VERSION := 1
static var current: XState

var difficulty := 3
var party: Array[int] = []          # 队伍顺序（前 4 位出战）
var actors := {}                    # actor_id -> XActor
var gold := 0
var items := {}                     # item_id -> 数量
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


static func new_game(difficulty_id: int, starter_id: int, companions: Array) -> XState:
	var s := XState.new()
	s.difficulty = difficulty_id
	for id in [starter_id] + companions:
		s.add_actor(int(id))
	current = s
	return s


func actor(id: int) -> XActor:
	if not actors.has(id):
		actors[id] = XActor.new().setup(id)
	return actors[id]

func add_actor(id: int) -> void:
	if not party.has(id) and not XDB.rec("Actors", id).is_empty():
		actor(id)
		party.append(id)

func remove_actor(id: int) -> void:
	party.erase(id)

func members() -> Array:
	return party.map(func(id): return actor(id))

func battle_members() -> Array:
	return members().slice(0, 4)


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
	items[id] = clampi(item_count(id) + amount, 0, 99999)
	if items[id] == 0:
		items.erase(id)

func gain_gear(kind: String, base_id: int, amount: int) -> void:
	if amount > 0:
		for i in range(amount):
			var inst := XActor.make_equip(kind, base_id)
			if not inst.is_empty():
				gear.append(inst)
	else:
		for i in range(-amount):
			var idx := gear.find_custom(func(e): return e.kind == kind and int(e.base) == base_id)
			if idx >= 0:
				gear.remove_at(idx)

func gear_count(kind: String, base_id: int) -> int:
	return gear.filter(func(e): return e.kind == kind and int(e.base) == base_id).size()

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
		"items": items, "gear": gear, "switches": switches, "variables": variables, "selfSwitches": self_switches,
		"mapId": map_id, "x": x, "y": y, "direction": direction, "steps": steps, "playSeconds": play_seconds}

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
	current = s
	return s
