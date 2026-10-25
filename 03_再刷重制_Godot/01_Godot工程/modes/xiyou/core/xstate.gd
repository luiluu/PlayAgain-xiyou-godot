class_name XState
extends RefCounted
## 西游模式的一局游戏状态（相当于 MV 的 $gameParty/$gameSwitches/$gameVariables/$gameSelfSwitches/$gamePlayer 位置）。
## 只属于西游模式；存档读写 to_dict()/from_dict()，保存位置由 GameApp.save_directory() 决定。

const SAVE_VERSION := 2
static var current: XState

## Game_Temp's one runtime slot: menu/map producers overwrite each other.
## Ordinary saves omit it; every new/restored XState starts empty.
var _reserved_common_event_id := 0

func reserve_common_event(id: int) -> void:
	_reserved_common_event_id = id

func peek_common_event() -> int:
	return _reserved_common_event_id

func clear_common_event() -> void:
	_reserved_common_event_id = 0

var difficulty := 3
var party: Array[int] = []          # 队伍顺序（$gameParty._actors；出战成员在前，见 battle_slots）
## YEP_PartySystem 的 $gameParty._battleMembers：出战栏位（长度＝上限 5，空位为 0）
var battle_slots: Array = []
var actors := {}                    # actor_id -> XActor
var gold := 0
var items := {}                     # item_id -> 数量
var last_item := 0
var next_gear_id := 1
## 保存次数（$gameSystem._saveCount：每次存档写盘前加 1；存读档页显示；旧档缺省 0）
var save_count := 0
## 宝珠孔的存档种子（$gameSystem._codexOrbRng.seed：新游戏随机，之后随存档保存；见 XOrbs）
var orb_seed: int = _fresh_seed()
## 宝珠坊：随机流序号 n、暂存宝珠 returns、神秘珠暂存箱 inbox、最近鉴定 recent（见 XOrbs）
var orb_state := {"n": {}, "returns": {}, "inbox": {}, "recent": []}
var gear: Array = []                # 背包里的装备实例
var warehouses := {}                # PH_Warehouse 仓库（存档 phwarehouse，见 XWarehouse；旧档没有为空）
var saved_actors: Array[int] = []   # 角色仓库（Star_ActorWarehouse 的 $gameParty._saveactors，存档 saveactors，见 XActorWarehouse；旧档没有为空）
## 更衣的替换形象（Star_ChangeClothes 的 $gamePlayer.Set_OcharacterName／Set_OcharacterIndex，存档 playerCostume，见 XChangeClothes；
## {"characterName", "characterIndex"}，空＝不替换；旧档没有为空）
var player_costume := {}
## 角色换装开关关掉的角色（installCostumePreferencesRuntime 的 Game_Actor._codexCostumeEnabled === false，存档 costumeOff，见 XCostumes；旧档没有为空＝全启用）
var costume_off: Array[int] = []
## 角色进阶次数（Star_ActorAdvanced 的 Game_Actor._AdvancedNum，存档 actorAdvance，见 XAdvance；角色 ID → 次数，旧档没有为空＝全 0）
var actor_advance := {}
## 技能共享／羁绊／领袖技能的上次记录（XPartySkills，O-095 开着时随存档，存档键 partySkills；旧档没有为空）
var party_skills := {}
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
## Runtime only: ordinary saves keep original rom/orb/gear data, never these streams.
## Loading/previews do not initialize or advance them.
var random_master := ""
var battle_serial := 0
var _equipment_random: XRandomStream
var _world_random: XRandomStream

func _ensure_random_master() -> void:
	if random_master.is_empty():
		random_master = XRandomStream.fresh_seed()

func reserve_battle_random() -> XBattleRandom:
	_ensure_random_master()
	var out := XBattleRandom.create(XRandomStream.derive(random_master, "battle:" + str(battle_serial)), battle_serial)
	battle_serial += 1
	return out

func equipment_random() -> XRandomStream:
	_ensure_random_master()
	if _equipment_random == null:
		_equipment_random = XRandomStream.create(XRandomStream.derive(random_master, "equipment"), "equipment")
	return _equipment_random

func world_random() -> XRandomStream:
	_ensure_random_master()
	if _world_random == null:
		_world_random = XRandomStream.create(XRandomStream.derive(random_master, "world-events"), "world")
	return _world_random

func runtime_random_snapshot() -> Dictionary:
	return {"version": 1, "engine": XRandomStream.ENGINE, "master": random_master,
		"battleSerial": battle_serial, "world": _world_random.snapshot() if _world_random != null else {}, "equipment": _equipment_random.snapshot() if _equipment_random != null else {}}

static func valid_runtime_random(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("engine") != XRandomStream.ENGINE:
		return false
	var serial = data.get("battleSerial")
	if not (serial is int or serial is float) or not is_finite(float(serial)) or float(serial) < 0 or float(serial) != floorf(float(serial)) or float(serial) >= 9007199254740992.0:
		return false
	if not data.get("master") is String or (data.master != "" and not XRandomStream.valid_hex(data.master)):
		return false
	var world = data.get("world", {})
	if not world is Dictionary or (not world.is_empty() and (data.master == "" or not XRandomStream.valid_saved(world) or world.domain != "world" or world.get("scripted", false))):
		return false
	var equipment = data.get("equipment")
	return equipment is Dictionary and (equipment.is_empty() or (data.master != "" and XRandomStream.valid_saved(equipment) and equipment.domain == "equipment" and not equipment.get("scripted", false)))
## Debug replay only. Validate the entire boundary before changing any runtime stream.
func restore_runtime_random(data: Dictionary) -> bool:
	if not valid_runtime_random(data):
		return false
	random_master = data.master
	battle_serial = int(data.battleSerial)
	_equipment_random = XRandomStream.restore(data.equipment) if not data.equipment.is_empty() else null
	_world_random = XRandomStream.restore(data.get("world", {})) if not data.get("world", {}).is_empty() else null
	return true

## Galv_NewItemIndication 的 $gameSystem._seenItems：看过的物品（物品 ID／装备实例 ID）不再画 NEW
var seen := {}
## 事件脚本里给 $gameParty / $gamePlayer 挂的零散标记（DCultyL1～8 等），按原名保存
var flags := {}
## $gamePlayer.SaveActorName：开局输入的名字（称号、成就里用）
var actor_name := ""
## 事件脚本「所有角色学会/忘记技能」：MV 会当场建出全部角色；这里按顺序记下，角色第一次建出时补上（见 actor()）
## 每条 {"op": "learn"/"forget", "skill": N, "ids": [] 为全体, "exclude": [], "named": 只限有名字的角色}
var actor_ops: Array = []
## MapTransferPlugin 的 $gameSystem._unlockedMaps：进入过的配置地图（map_id -> true；见 XMapTransfer）
var unlocked_maps := {}
## XdRs_HangUp：挂机设置（随存档，见 XHangUp.DEFAULTS）与总挂机帧数；运行状态不进存档（读档即不在挂机）
var hang_up := {}
var hang_up_total := 0
var encounter_enabled := true      # Game_System._encounterEnabled（指令 136）
## YEP_CoreEngine 的 $gameParty.ActorMaxLevel：全体角色的等级上限（每次换场景写回 $dataActors[i].maxLevel，
## 所以角色数据库与备注里的上限都被它取代）。初值为插件参数 Max Level（西游 10），插件指令 maxlevel add/equal 改它。
var actor_max_level := 0
## $gameScreen 的色调与天气（指令 223／236；换地图不清，读档保留）
var screen := XScreenFx.new()
var battle_bgm: Dictionary = {}     # $gameSystem._battleBgm（指令 132 更改战斗 BGM；空＝用 System 里的）
## $gameMap._battleback1Name／_battleback2Name 被指令 283 改过时的 [背景1, 背景2]；空＝用地图指定的（Game_Map.setupBattleback）。
## 原版 $gameMap 整个进存档，读档同版本不重设地图，所以随档保存；换到别的地图时由 XMapScene.load_map 清掉。
var battleback: Array = []
## 当前地图上被指令 214 暂时消除的事件 ID（Game_Event._erased）：同上随 $gameMap 进存档，同图移动也保留；换到别的地图时清掉。
## 副本里只靠 214 消失的明雷怪（冻结数据 131 页）读档后不再出现。
var erased_events: Array[int] = []
var followers_visible := true      # Game_Followers._visible（初值 System optFollowers；指令 216、设置「队列跟随」）
var pingbi_quality: Array = []      # 屏蔽掉落：旧档 0～7 是否屏蔽（$gameSystem._pingbiQuality）
## 副本上下文（XDungeon：进门时的 pending、进入后的 context）、副本 Boss 熟练度（$gameSystem._codexBossMastery：敌群 → 次数）、
## 种族补给（$gameSystem._codexRaceSupply：counts／first／inbox）
var dungeon := {}
var boss_mastery := {}
var race_supply := {}
## 种族祝福（XRace：开局默认、每名角色的种族与阶位等），随存档
var race := {}
## 异化账本（XAlienation：$gameSystem._alienLedger 的 sequence／pending／recent／metrics），随存档；异化标记在装备实例的 alien 字段
var alien_ledger := {}
var eco_frac := {}
## KMS_ShopInventory 商店库存（见 XShopStock；随存档）与下一次商店用的库存组（$gameTemp.nextInventoryId，不存档）
var shop_stock := {"inv": {}, "schedules": []}
## 真气：降服过的本命兵武器类型 w、灵根元素 e、完成过的神兵试炼 weaponTrials（$gameSystem._codexZhenqiSpec），全队共用、随存档
var zhenqi_spec := {"w": {}, "e": {}, "weaponTrials": {}}
## 修行指引看过的区段里程碑（$gameSystem._codexGuideSeen：{"seg:a": 1}），随存档
var guide_seen := {}
## $gameParty.SAchievementS：本局得过的成就（ID 字符串→true）；全局记录在 XConfig（见 XAchievement）
var achievements := {}
## 怪物图鉴（AB_EnemyBook）：flags 登记、defeat 击败数、maps 出没地图（$gameSystem._enemyBookFlags／_defeatNumbers／_recordEnemyMap），见 XEnemyBook
var mv_param_plus := {}   # 事件指令 317（更改能力值）的永久加成 {"角色ID": [8 项]}（Game_Actor._paramPlus），见 XParamPlus；旧档没有为空
var enemy_book := {"flags": {}, "defeat": {}, "maps": {}}
## 制作（hc.js）：known 已知配方、level／exp 四类别等级与经验（$gameParty._recipesKnown／_craftingLevel／_craftingExp），见 XCrafting
var crafting := {"known": {}, "level": [1, 1, 1, 1], "exp": [0, 0, 0, 0]}
## 宠物（Star_PetSystem）：list 宠物、war 出战序号、team_a 共享角色序号（$gameParty.Pets／GTWar／TeamATo），见 XPets
var pets := {"list": [], "war": -1, "team_a": 0}
## TeamA 上次接收者，仅运行时；存档技能已保存，读档按当前槽位重建。
var pet_team_actor := 0
## 修炼（Star_ActorAttributePlusPoints）：{"角色ID": {"修炼表编号": 等级}}（actor.pushattribute 的等级一栏），见 XTraining
var training := {}
var shop_pending := ""
var hang_up_active := false
var hang_up_origin := Vector2i(-1, -1)
var hang_up_count := 0
var hang_up_save_pending := false


## 新种子用独立的随机数生成器取，不动全局 randi 序列（战斗等测试按全局种子复现）
static func _fresh_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi()


## 换成另一份游戏状态（新游戏、读档）：清掉依赖上一档的进程内标记（框架维护约定「缓存」）。
## XDungeon.battle 记最近一场事件战斗的胜负与神秘珠／种族补给是否已领，不随存档。
static func _become_current(s: XState) -> void:
	current = s
	XDungeon.battle = {}
	XZhenqi.battle = {}
	XZhenqi.pending_trial = {}
	XZhenqi.trial_done = {}
	XZhenqi.pending_scale = {}


static func new_game(difficulty_id: int, starter_id: int, companions: Array) -> XState:
	var s := XState.new()
	s.difficulty = difficulty_id
	for id in [starter_id] + companions:
		s.add_actor(int(id))
	s.followers_visible = bool(XDB.system().get("optFollowers", false))
	XGlobalVars.apply(s)  # Game_Map.initialize：跨存档变量盖到新局
	_become_current(s)
	return s


## MV setupNewGame：System 的初始队伍（西游为空）与起点（Map001 (7,10)），难度取 Vitsuno_Difficulty 的 Init Difficulty ID。
## 之后由 Map001/Map002/Map221 的原版事件选存档位、难度、英雄与教派。
static func new_game_blank() -> XState:
	var s := XState.new()
	var sys := XDB.system()
	s.followers_visible = bool(sys.get("optFollowers", false))
	s.difficulty = int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2))
	for id in sys.get("partyMembers", []):
		s.add_actor(int(id))
	s.map_id = int(sys.get("startMapId", 1))
	s.x = int(sys.get("startX", 0))
	s.y = int(sys.get("startY", 0))
	s.direction = 2
	XSave.current_slot = 0
	XGlobalVars.apply(s)  # Game_Map.initialize：跨存档变量盖到新局
	_become_current(s)
	return s


static func default_max_level() -> int:
	var v := str(XDB.plugin("YEP_CoreEngine").get("Max Level", "99"))
	return int(v) if v.is_valid_int() else 99


## 当前等级上限（未设置时为插件参数）
func max_level() -> int:
	return actor_max_level if actor_max_level > 0 else default_max_level()


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

## Game_Party.addActor（YEP_PartySystem）：加入队尾；出战栏位有空位时填入第一个空位并重排
## installBossDifficultyRuntime 在外层前后各清一次出战栏里的超强者（XItemMarks.enforce_party）
func add_actor(id: int) -> void:
	XItemMarks.enforce_party(self)
	_add_actor(id)
	XItemMarks.enforce_party(self)


func _add_actor(id: int) -> void:
	if XDB.rec("Actors", id).is_empty():
		return
	# installBossDifficultyRuntime：未持有的超强者在地狱以下不能入队（提示后不加）
	if not party.has(id) and not XItemMarks.can_acquire_actor(self, id):
		XItemMarks.acquisition_notice()
		return
	if not party.has(id):
		actor(id)
		party.append(id)
	_ensure_slots()
	if battle_slots.has(id) or not battle_slots.has(0):
		return
	battle_slots[battle_slots.find(0)] = id
	rearrange_actors()

## Game_Party.removeActor：出战栏位里的变成空位并重排
func remove_actor(id: int) -> void:
	party.erase(id)
	_ensure_slots()
	if not battle_slots.has(id):
		return
	battle_slots[battle_slots.find(id)] = 0
	rearrange_actors()


## initializeBattleMembers：按队伍前 5 人建立出战栏位（不足补 0）
## （前后各清一次超强者，同 add_actor）
func init_battle_slots() -> void:
	XItemMarks.enforce_party(self)
	battle_slots = []
	for i in MAX_BATTLE_MEMBERS:
		battle_slots.append(party[i] if i < party.size() else 0)
	XItemMarks.enforce_party(self)
	XPets.sync_team_a(self)


func _ensure_slots() -> void:
	if battle_slots.size() != MAX_BATTLE_MEMBERS:
		init_battle_slots()


## rearrangeActors：出战栏位（按栏位顺序）在前，其余按角色编号升序（前后各清一次超强者，同 add_actor）
func rearrange_actors() -> void:
	_ensure_slots()
	XItemMarks.enforce_party(self)
	_rearrange_actors()
	XItemMarks.enforce_party(self)
	XPets.sync_team_a(self)


func _rearrange_actors() -> void:
	var battle: Array[int] = []
	for id in battle_slots:
		if int(id) > 0 and party.has(int(id)):
			battle.append(int(id))
	var reserve: Array[int] = []
	for id in party:
		if not battle.has(id):
			reserve.append(id)
	reserve.sort()
	party = battle + reserve

func members() -> Array:
	return party.map(func(id): return actor(id))

## 出战上限 5：YEP_PartySystem 参数写 4，但后加载的 MrTS_BattleCharacterLimit 把 maxBattleMembers 改为 5（参数为空取默认）。
## 出战成员由 battle_slots 决定（整队页 XPartyScene）。
const MAX_BATTLE_MEMBERS := 5

## Game_Party.partyAbility：出战成员任一有该队伍能力（特性 64；0 遇敌减半 1 无遇敌 2 防偷袭 3 先发制人率上升 4 金钱双倍 5 物品掉落双倍）
func party_ability(id: int) -> bool:
	return battle_members().any(func(a): return not a.traits_with_id(64, id).is_empty())


## YEP Game_Party.battleMembers：出战栏位里的非空角色（栏位顺序）；先清掉出战栏里的超强者（XItemMarks.enforce_party）
func battle_members() -> Array:
	_ensure_slots()
	XItemMarks.enforce_party(self)
	var out := []
	for id in battle_slots:
		if int(id) > 0 and party.has(int(id)):
			out.append(actor(int(id)))
	return out


## Game_Party.leader：第一个实际出战成员；出战栏全空时没有队首。
func leader() -> XActor:
	var battle := battle_members()
	return battle[0] if not battle.is_empty() else null


func switch(id: int) -> bool:
	return switches.get(id, false)

func set_switch(id: int, on: bool) -> void:
	switches[id] = on
	XGlobalVars.on_switch(id, on)  # 跨存档开关（Drill_VariablesAcrossArchive）

func variable(id: int) -> float:
	return variables.get(id, 0)

func set_variable(id: int, value: float) -> void:
	variables[id] = floorf(value)  # Game_Variables.setValue：数值一律 Math.floor。
	XGlobalVars.on_variable(id, value)  # 跨存档变量存取整前的原值（同 Drill_VariablesAcrossArchive）

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

## installNativeEconomyRuntime（CodexEconomy.redirect）：得到这些物品时改记肝帝积分（变量 206，每件 30）或换成合并后的货币；
## 小数倍率的零头累计在 eco_frac（$gameSystem._codexEcoFrac），凑满一件再给
const ECO_SCORE_VAR := 206
const ECO_TO_SCORE := {2451: 30, 1919: 30, 1350: 30}
const ECO_TO_ITEM := {184: [188, 1.0], 185: [188, 1.0], 186: [188, 1.0], 187: [188, 1.0], 2251: [2201, 1.0], 2301: [2201, 1.5], 2351: [2201, 1.5],
	1234: [1233, 3.0], 1991: [1981, 1.0], 2495: [2475, 1.0], 2496: [2476, 1.0], 2497: [2477, 1.0], 2498: [2478, 1.0], 2499: [2479, 1.0],
	2500: [2480, 1.0], 2501: [2481, 1.0], 2502: [2482, 1.0], 2503: [2483, 1.0], 2504: [2484, 1.0], 2505: [2485, 1.0], 2506: [2486, 1.0],
	2508: [2509, 1.0], 2510: [2511, 1.0], 2512: [2513, 1.0], 2514: [2515, 1.0], 2516: [2517, 1.0], 2518: [2519, 1.0], 2520: [2521, 1.0]}

func gain_item(id: int, amount: int) -> void:
	var before := id
	# installBossDifficultyRuntime 包在 Game_Party.gainItem 外：超强者伙伴号角在地狱以下得不到（不弹提示）
	if amount > 0 and not XItemMarks.can_acquire_item(self, XDB.rec("Items", id)):
		return
	if amount > 0:
		# installNativeRaceRuntime：得到旧版祝福进阶石时换成正规 ID（CodexRaces.legacyItems）
		var races = XDB.table("CodexRaces")
		if races is Dictionary and int(races.get("legacyItems", {}).get(str(id), id)) != id:
			id = int(races.legacyItems[str(id)])
		if ECO_TO_SCORE.has(id):
			set_variable(ECO_SCORE_VAR, variable(ECO_SCORE_VAR) + amount * ECO_TO_SCORE[id])
			return
		if ECO_TO_ITEM.has(id):
			var t: Array = ECO_TO_ITEM[id]
			var total := float(eco_frac.get(str(t[0]), 0.0)) + amount * float(t[1])
			var n := floori(total + 1e-9)
			eco_frac[str(t[0])] = total - n
			if n > 0:
				_gain_raw(int(t[0]), n)
				XAchievement.on_item_gain(self, int(t[0]), n, before)
			return
	_gain_raw(id, amount)
	# Star_AchievementSystem 包在 Game_Party.gainItem 里层：判定的是改记之后的物品（O-076 另看改记前的）
	XAchievement.on_item_gain(self, id, amount, before)

func _gain_raw(id: int, amount: int) -> void:
	items[id] = clampi(item_count(id) + amount, 0, 9999)  # $gameParty.maxItems（正式版运行时为 9999）
	if items[id] == 0:
		items.erase(id)

func gain_gear(kind: String, base_id: int, amount: int) -> void:
	if amount > 0:
		for i in range(amount):
			var inst := XGear.create(kind, base_id, self)
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
	XOrbs.layout(item, orb_seed)

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

## Game_Party.gainGold：clamp(GOLD_MIN, maxGold)。上限是 YEP_CoreEngine「Gold Max」999999999999（9999 亿）；
## 正式版 rpg_objects 把下限改成 -99999999，精魂可以扣成负数（O-085：重制下限为 0）
const GOLD_MAX := 999999999999
const GOLD_MIN_ORIGINAL := -99999999
## O-085：精魂不扣成负数；设 false 恢复原版下限 -99999999
const GOLD_FLOOR_ZERO := true

func gain_gold(amount: int) -> void:
	gold = clampi(gold + amount, 0 if GOLD_FLOOR_ZERO else GOLD_MIN_ORIGINAL, GOLD_MAX)


# ---- 存档 ----
func to_dict() -> Dictionary:
	_ensure_slots()
	var a := {}
	for id in actors:
		var x2: XActor = actors[id]
		a[str(id)] = {"level": x2.level, "exp": x2.exp_total, "skills": x2.skill_ids, "equips": x2.equips,
			"hp": x2.hp, "mp": x2.mp, "tp": x2.tp, "states": x2.state_ids, "stateTurns": x2.state_turns,
			"buffs": x2.buffs, "buffTurns": x2.buff_turns, "cooldowns": x2.cooldowns,
			"lastCommand": x2.last_command, "lastBattleSkill": x2.last_battle_skill, "zhenqi": x2.zhenqi}
		# A removed-death result can leave a native battler alive at zero HP.
		# Persist only this exceptional state; legacy saves retain their HP fallback.
		if x2.resource_death_blocked:
			a[str(id)]["resourceDeathBlocked"] = true
	return {"version": SAVE_VERSION, "mode": "xiyou", "difficulty": difficulty, "party": party, "battleSlots": battle_slots, "actors": a, "gold": gold,
		"items": items, "lastItem": last_item, "gear": gear, "nextGearId":next_gear_id, "orbSeed": orb_seed, "saveCount": save_count, "orbState": orb_state, "switches": switches, "variables": variables, "selfSwitches": self_switches,
		"mapId": map_id, "x": x, "y": y, "direction": direction, "steps": steps, "playSeconds": play_seconds, "rom": rom,
		"seen": seen.keys(), "flags": flags, "actorName": actor_name, "actorOps": actor_ops,
		"unlockedMaps": unlocked_maps.keys(), "hangUp": hang_up, "hangUpTotal": hang_up_total, "pingbiQuality": pingbi_quality, "followersVisible": followers_visible, "battleBgm": battle_bgm, "battleback": battleback, "erasedEvents": erased_events, "encounterEnabled": encounter_enabled, "screen": screen.to_dict(), "actorMaxLevel": actor_max_level,
		"dungeon": dungeon, "bossMastery": boss_mastery, "raceSupply": race_supply, "race": race, "alienLedger": alien_ledger, "ecoFrac": eco_frac,
		"shopStock": shop_stock, "zhenqiSpec": zhenqi_spec, "guideSeen": guide_seen, "achievements": achievements, "enemyBook": enemy_book, "crafting": crafting, "pets": pets, "training": training, "mvParamPlus": mv_param_plus, "phwarehouse": warehouses, "saveactors": saved_actors, "playerCostume": player_costume, "costumeOff": costume_off, "actorAdvance": XAdvance.to_save(actor_advance), "partySkills": XPartySkills.to_save(party_skills)}

static func from_dict(d: Dictionary) -> XState:
	# dev.099 once persisted strict engine-specific RNG state. Ignore that obsolete
	# field even across engine upgrades; fresh runtime streams start lazily.
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
		for k in row.get("stateTurns", {}):
			x2.state_turns[int(k)] = int(row.stateTurns[k])
		x2.buffs.assign(row.get("buffs", [0, 0, 0, 0, 0, 0, 0, 0]).map(func(v): return int(v)))
		x2.buff_turns.assign(row.get("buffTurns", [0, 0, 0, 0, 0, 0, 0, 0]).map(func(v): return int(v)))
		x2.refresh_passive()
		x2.hp = float(row.hp)
		x2.mp = float(row.mp)
		x2.tp = float(row.get("tp", 0.0))
		x2.resource_death_blocked = bool(row.get("resourceDeathBlocked", false))
		x2.last_command = str(row.get("lastCommand", ""))
		x2.last_battle_skill = int(row.get("lastBattleSkill", 0))
		# 真气：旧档没有这一项时为空，第一次用到时给初值（XZhenqi.data）
		x2.zhenqi = XZhenqi.from_save(row.zhenqi) if row.has("zhenqi") and row.zhenqi is Dictionary and not row.zhenqi.is_empty() else {}
		for k in row.get("cooldowns", {}):
			x2.cooldowns[int(k)] = float(row.cooldowns[k])
		s.actors[int(id_s)] = x2
	s.party.assign(d.party.map(func(v): return int(v)))
	# 旧档没有出战栏位：按队伍前 5 人（toInitializeBattleMembers）
	s.battle_slots = Array(d.get("battleSlots", [])).map(func(v): return int(v))
	s._ensure_slots()
	s.gold = int(d.gold)
	for k in d.items:
		s.items[int(k)] = int(d.items[k])
	s.last_item = int(d.get("lastItem", 0))
	s.gear = d.gear
	s.next_gear_id = int(d.get("nextGearId",1))
	s.save_count = int(d.get("saveCount", 0))
	# 没有宝珠种子的旧档：照正式 seedFromSave 由存档内容算出（同一存档每次读都一样）
	var os: Dictionary = d.get("orbState", {})
	s.orb_state = {"n": {}, "returns": {}, "inbox": {}, "recent": os.get("recent", [])}
	for key in ["n", "returns", "inbox"]:
		for k in os.get(key, {}):
			s.orb_state[key][str(k)] = int(os[key][k])
	s.orb_seed = int(d.orbSeed) if d.has("orbSeed") else XOrbs.hash32(JSON.stringify([float(d.get("playSeconds", 0)), s.gold, d.party]))
	for a in s.actors.values():
		for e in a.equip_list():s.register_gear(e)
	for e in s.gear:s.register_gear(e)
	s.warehouses = XWarehouse.from_save(s, d.get("phwarehouse", {}))
	s.saved_actors = XActorWarehouse.from_save(d.get("saveactors", []))
	s.player_costume = XChangeClothes.from_save(d.get("playerCostume"))
	s.costume_off = XCostumes.from_save(d.get("costumeOff"))
	s.actor_advance = XAdvance.from_save(d.get("actorAdvance"))
	s.party_skills = XPartySkills.from_save(d.get("partySkills"))
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
	s.hang_up = d.get("hangUp", {})
	s.dungeon = d.get("dungeon", {})
	s.boss_mastery = d.get("bossMastery", {})
	s.race_supply = d.get("raceSupply", {})
	var rc = d.get("race", {})
	s.race = rc.duplicate(true) if rc is Dictionary else {}
	var al = d.get("alienLedger", {})
	s.alien_ledger = al.duplicate(true) if al is Dictionary else {}
	var gs = d.get("guideSeen", {})
	s.guide_seen = gs.duplicate() if gs is Dictionary else {}
	s.eco_frac = d.get("ecoFrac", {})
	var ac = d.get("achievements", {})
	s.achievements = ac.duplicate() if ac is Dictionary else {}
	var eb = d.get("enemyBook", {})
	s.enemy_book = eb.duplicate(true) if eb is Dictionary else {}
	var cr = d.get("crafting", {})
	s.crafting = cr.duplicate(true) if cr is Dictionary else {}
	var pt = d.get("pets", {})
	s.pets = pt.duplicate(true) if pt is Dictionary else {}
	var pet_target := XPets.team_a_actor(s) if not XPets.war_pet(s).is_empty() else null
	s.pet_team_actor = pet_target.actor_id if pet_target != null else 0
	var pp = d.get("mvParamPlus", {})
	s.mv_param_plus = pp.duplicate(true) if pp is Dictionary else {}
	var tr = d.get("training", {})
	s.training = tr.duplicate(true) if tr is Dictionary else {}
	s.shop_stock = XShopStock.from_save(d.get("shopStock", {}))
	var zs = d.get("zhenqiSpec", {})
	for part in ["w", "e", "weaponTrials"]:
		for k in (zs.get(part, {}) if zs is Dictionary and zs.get(part, {}) is Dictionary else {}):
			s.zhenqi_spec[part][str(k)] = 1
	s.hang_up_total = int(d.get("hangUpTotal", 0))
	s.pingbi_quality = Array(d.get("pingbiQuality", [])).map(func(v): return bool(v))
	s.followers_visible = bool(d.get("followersVisible", XDB.system().get("optFollowers", false)))
	s.battle_bgm = d.get("battleBgm", {}) if d.get("battleBgm", {}) is Dictionary else {}
	var bb = d.get("battleback", [])
	s.battleback = [str(bb[0]), str(bb[1])] if bb is Array and bb.size() == 2 else []
	s.erased_events.assign(Array(d.get("erasedEvents", [])).map(func(v): return int(v)))
	s.encounter_enabled = bool(d.get("encounterEnabled", true))
	s.screen = XScreenFx.from_dict(d.get("screen"))
	# dev.032 以前的存档没有这一项：按初值（原版开局就是插件参数）
	s.actor_max_level = int(d.get("actorMaxLevel", default_max_level()))
	if d.has("unlockedMaps"):
		for k in d.unlockedMaps:
			s.unlocked_maps[int(k)] = true
	elif s.self_switch(4, 20, "A"):
		# dev.016 及以前的 Godot 档没有解锁记录：已到过大厅的补大厅（所在地图由 load_map 照常解锁）
		s.unlocked_maps[4] = true
	XGlobalVars.apply(s)  # extractSaveContents 之后：跨存档变量盖掉档里的值
	_become_current(s)
	return s
