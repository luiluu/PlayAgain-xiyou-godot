class_name XEnemyBook
extends RefCounted
## 怪物图鉴的数据部分（AB_EnemyBook v1.36，正式版参数 ResisterTiming=2；界面在 ui/enemy_book.gd）。
## 存档字段 XState.enemy_book：{flags: {敌人ID: true}（$gameSystem._enemyBookFlags）、defeat: {敌人ID: 次数}（_defeatNumbers）、
## maps: {敌人ID: [地图显示名…]}（_recordEnemyMap）}，键为字符串。
## - 登记（ResisterTiming 2，战斗结束时）：开战时出现着的成员、战斗中 335 出现、336 变身后的敌人 ID 记进本场名单，
##   Game_Troop.onBattleEnd（胜、逃、败都会走）时全部登记。变身照原版也记隐藏成员。
## - 击败数：Game_Enemy.die 每次 +1。重制在战斗结束时按倒下的成员计（倒下又被复活再倒下的只记一次，与原版差这一点）。
## - 出没于：Game_Map.setup 把该图遇敌表敌群的成员记上地图显示名；BattleManager.setup 把本场敌群成员记上当前地图显示名（不重复）。
## - 插件指令 EnemyBook open（公共事件 2）由地图宿主打开图鉴；complete（Map004、Map137 兑换大厅）全登记；另接 add／remove／clear。

## 图鉴里的敌人：数据库有名字、备注没有 <book:no>
static func listed(id: int) -> bool:
	var e := XDB.rec("Enemies", id)
	return str(e.get("name", "")) != "" and str(e.get("meta", {}).get("book", "")) != "no"


## 图鉴目录：全部 listed 的敌人 ID（Window_EnemyBookIndex.refresh 的 isAllEnemies 分支）
static func ids() -> Array:
	var out := []
	var t: Array = XDB.table("Enemies")
	for i in range(1, t.size()):
		if listed(i):
			out.append(i)
	return out


static func _book(s: XState) -> Dictionary:
	for k in ["flags", "defeat", "maps"]:
		if not s.enemy_book.get(k) is Dictionary:
			s.enemy_book[k] = {}
	return s.enemy_book


static func registered(s: XState, id: int) -> bool:
	return s != null and bool(_book(s).flags.get(str(id), false))


static func add(s: XState, id: int) -> void:
	_book(s).flags[str(id)] = true


static func remove(s: XState, id: int) -> void:
	if _book(s).flags.has(str(id)):
		_book(s).flags[str(id)] = false


static func clear(s: XState) -> void:
	_book(s).flags = {}


## completeEnemyBook：1 号起全部敌人（含无名与 <book:no>）
static func complete(s: XState) -> void:
	clear(s)
	var t: Array = XDB.table("Enemies")
	for i in range(1, t.size()):
		_book(s).flags[str(i)] = true


static func defeat_number(s: XState, id: int) -> int:
	return int(_book(s).defeat.get(str(id), 0)) if s != null else 0


static func add_defeat(s: XState, id: int) -> void:
	_book(s).defeat[str(id)] = defeat_number(s, id) + 1


static func record_maps(s: XState, id: int) -> Array:
	return _book(s).maps.get(str(id), []) if s != null else []


static func _record(s: XState, troop_id: int, name: String) -> void:
	for m in XDB.rec("Troops", troop_id).get("members", []):
		var key := str(int(m.enemyId))
		var list: Array = _book(s).maps.get(key, [])
		if not list.has(name):
			list.append(name)
		_book(s).maps[key] = list


## Game_Map.setup：遇敌表里每个敌群的成员记上本图显示名
static func on_map_setup(s: XState, map: Dictionary) -> void:
	for en in map.get("encounterList", []):
		_record(s, int(en.troopId), str(map.get("displayName", "")))


## 战斗开始（BattleManager.setup＋Game_Troop.setup）：记出没地图，返回本场名单（开战时出现着的成员）
static func on_battle_start(s: XState, troop_id: int, map: Dictionary, enemies: Array) -> Array:
	_record(s, troop_id, str(map.get("displayName", "")))
	var appeared := []
	for e in enemies:
		if not e.hidden:
			appeared.append(e.enemy_id)
	return appeared


## Game_Troop.onBattleEnd：本场名单全部登记；倒下的成员各记一次击败
static func on_battle_end(s: XState, appeared: Array, enemies: Array) -> void:
	for id in appeared:
		add(s, int(id))
	for e in enemies:
		if not e.hidden and e.is_dead():
			add_defeat(s, e.enemy_id)


## 插件指令 EnemyBook（open 由地图宿主处理）；正式数据只用到 open 与 complete，另接 add／remove／clear。返回是否认得
static func plugin_command(s: XState, args: PackedStringArray) -> bool:
	if args.size() < 2:
		return false
	match args[1]:
		"add": add(s, int(args[2]) if args.size() > 2 else 0)
		"remove": remove(s, int(args[2]) if args.size() > 2 else 0)
		"complete": complete(s)
		"clear": clear(s)
		_:
			return false
	return true
