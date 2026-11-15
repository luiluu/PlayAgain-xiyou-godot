class_name XFestRoad
extends RefCounted
## 【cc·未经审查】冠军庆典·冠军之路「一穿四」（Kyo 11-15；方案：私密设计仓 重制设定/冠军庆典活动_v0.2.md 2.3 节；三档与奖励按 v0.3.1 第 1、2.1 节）。
## 五打五（建议满五人；不满五人报名时提示一句，确认后照样能打）连打四支五人队：网吧队 → 银河战舰队 → 大魔王队 → 内战幻神队（决赛）。队名、敌人名都是自创，不写真实战队与选手。
##
## - 敌人、敌群、辅助的群体治疗都是运行时追加（XDB.rec 表外号段），不改生成数据：敌人 9300／9400／9500 三段、敌群 9300 起、技能 19300。
##   每只敌人照本档基准守层者复制（特性、属性抗性、伤害抵抗被动跟着走），再按「队强度×位置倍率」重算能力值、换名字换图换技能。
## - 四关连战：中间不回大厅；血量、蓝量、阵亡带进下一关（游戏本来就不在战后回复）。四关都不能逃跑，输了不结束游戏。
## - 势如破竹：每赢一关全队伤害 +10%，最多三层；只在冠军之路的战斗里生效（XActorDamageHooks 的 finalMultiplier），退出或输了清零。
## - 场间暂停：整趟一次，两关之间全队回三成血蓝、复活阵亡的人。
## - 输了：回到大厅、队伍回满；下次可以从输的那关接着打，但接着打的这趟不算「不败」。
## - 三档（v0.3.1 第 1 节，Kyo 11-15 定 D46「丰富」）：欢庆档（大众）对标「普通」难度 10 层守层者（灵狼祭祀，敌人 72，一只），
##   天灾档、洪荒档对标「天灾」「洪荒」难度 26 层守层者（金角 529、银角两只）。敌人的难度倍率固定按本档（普通 3／天灾 6／洪荒 8），
##   不看玩家存档的难度（battle_setup）。四队相对强度 ×0.8／1.0／1.2／1.5 在三档上各乘。
## - 旧进度迁移（第 7 节第 1 条）：改三档前的「普通版」进度在存档键 road、「困难版」在 road_hard，正好对上天灾档、洪荒档；欢庆档用新键 road_fest。
## - 奖励三档分开给、互不顶替（每个存档各算各的；称号全局），见 REWARDS：每关首胜庆典币、四关全胜（冠军戒指＋币＋称号「冠军之路」）、
##   从第一关起一次不败连穿（称号＋币）。戒指每档一枚（XFestRing.grant，记在进度的 ring 上），输过也给。
##   改三档前的「冠军之路·洪荒」（45）没发给玩家过，并进「冠军之路」（41）：洪荒档全胜也发 41，45 不再发（XFestReward 读档时把手里有 45 的补成 41）。
## - 只开给重制版存档（天启篇档的守层者另有一套血量，进去打不动；报名处说一句就走，见 talk）。
## 开关 ENABLED＝false 或总开关 XFest.ENABLED＝false：表外记录都不认、伤害加成不生效、入口不开，回到没有冠军之路的样子。O-待定·冠军之路。

static var ENABLED := true

const ENEMY_BASE := 9300   # 敌人号＝ENEMY_BASE＋档位序×100＋关序×10＋位置序（欢庆 9300～9334，天灾 9400～9434，洪荒 9500～9534）
const TROOP_BASE := 9300   # 敌群号＝TROOP_BASE＋档位序×10＋关序（欢庆 9300～9303，天灾 9310～9313，洪荒 9320～9323）
const HEAL_SKILL := 19300  # 辅助的「应援」：全体友方回复最大生命的 HEAL_RATE
const HEAL_RATE := 0.04
const HEAL_FROM := 906     # 外观、动画照「治愈之歌」

## 势如破竹：每层伤害 +10%，最多 3 层
const STREAK_STEP := 0.10
const STREAK_MAX := 3
## 场间暂停回复比例
const PAUSE_RATE := 0.3

## 四支战队（Kyo 11-15 定）：mult＝相对基准的强度；role_mul 是本队特色在位置倍率上再乘的（按位置下标）
const TEAMS := [
	{"name": "网吧队", "mult": 0.8, "feature": "均衡，热身局",
		"sprites": ["SF_Actor1_1", "SF_Actor1_2", "SF_Actor1_3", "SF_Actor1_4", "SF_Actor1_5"], "role_mul": {}},
	{"name": "银河战舰队", "mult": 1.0, "feature": "铁壁：上单、辅助特别硬，辅助会加血",
		"sprites": ["Actor2_2", "Actor2_1", "Actor2_6", "Actor2_8", "Actor2_5"], "role_mul": {0: {"hp": 1.2, "def": 1.2}, 4: {"hp": 1.3, "def": 1.2}}},
	{"name": "大魔王队", "mult": 1.2, "feature": "快攻：全队速度高，打野伤害高",
		"sprites": ["DF_Actor7", "2_DF_Actor3", "Enemy_Mage", "DF_Actor2", "2_DF_Actor2"], "role_mul": {-1: {"agi": 1.15}, 1: {"atk": 1.2}}},
	{"name": "内战幻神队", "mult": 1.5, "feature": "决赛：五人属性全面最高，中单群伤很疼",
		"sprites": ["Package1_8", "Actor13_7", "Package2_1", "Package3_3_mvt", "Package1_2"], "role_mul": {2: {"mat": 1.2}}},
]

## 五个位置（四队共用一套模板）：能力值倍率＋技能表。hp_share／atk_share 是把一只守层者的血量、攻击摊到五个人身上的比例
const ROLES := [
	{"name": "上单", "hp": 1.6, "atk": 0.7, "mat": 0.7, "def": 1.4, "mdf": 1.4, "agi": 1.0,
		"actions": [[1025, 5], [1001, 3]]},
	{"name": "打野", "hp": 1.0, "atk": 1.2, "mat": 1.0, "def": 1.0, "mdf": 1.0, "agi": 1.4,
		"actions": [[3558, 5], [1025, 3]]},
	{"name": "中单", "hp": 0.9, "atk": 0.8, "mat": 1.3, "def": 0.9, "mdf": 1.1, "agi": 1.0,
		"actions": [[3805, 5], [2453, 4]]},
	{"name": "下路", "hp": 0.7, "atk": 1.4, "mat": 0.8, "def": 0.8, "mdf": 0.8, "agi": 1.1,
		"actions": [[481, 5], [1025, 4]]},
	{"name": "辅助", "hp": 1.0, "atk": 0.8, "mat": 1.0, "def": 1.1, "mdf": 1.1, "agi": 1.0,
		"actions": [[HEAL_SKILL, 5], [1025, 3]]},
]
## 摊比（按档写在 TIERS 的 hp_share／atk_share）：按「×1.0 的队≈守层者那一场」摊。五人血量倍率合计 5.2。
## - 26 层那场是金角、银角两只（敌群 462），血量合计约金角的 1.83 倍、两只出手：每人血量＝金角 ×0.35×位置×队强度（×1.0 队合计 ≈1.82 只金角）；
##   每人攻击、魔攻＝金角 ×0.4（五人出手合计 ≈2 只）。
## - 10 层那场只有灵狼祭祀一只（敌群 69）：每人血量 ×0.19（合计 ≈1 只）、攻击 ×0.2（五人出手合计 ≈1 只）。
## 防御、速度不摊，按守层者×位置×队强度。数值实测见交付单（虚拟玩家 fest_road_probe）
const HP_SHARE := 0.35
const ATK_SHARE := 0.4

## 站位（照 853 号五人敌群的范围摆）：上单、打野、下路前排，中单、辅助后排
const POS := [[470, 340], [440, 230], [250, 290], [440, 450], [250, 410]]

## 档位：base＝基准守层者敌人号（复制它的特性、伤害抵抗被动；26 层敌群 462 的第一只金角 529），difficulty＝敌人固定吃的难度倍率（Vitsuno_Difficulty 编号）
const TIERS := [
	{"key": "fest", "name": "欢庆档", "base": 72, "guard_troop": 69, "floor": 10, "difficulty": 3, "diff_name": "普通", "save_key": "road_fest",
		"hp_share": 0.19, "atk_share": 0.2},
	{"key": "normal", "name": "天灾档", "base": 529, "guard_troop": 462, "floor": 26, "difficulty": 6, "diff_name": "天灾", "save_key": "road",
		"hp_share": HP_SHARE, "atk_share": ATK_SHARE},
	{"key": "hard", "name": "洪荒档", "base": 529, "guard_troop": 462, "floor": 26, "difficulty": 8, "diff_name": "洪荒", "save_key": "road_hard",
		"hp_share": HP_SHARE, "atk_share": ATK_SHARE},
]

## 三档奖励（v0.3.1 2.1，互不顶替）：本档合计 200／150／150 币。ring＝冠军戒指的档（XFestRing.RINGS）
const REWARDS := [
	{"first": 30, "clear": 30, "flawless": 50, "title_clear": XFest.TITLE_ROAD, "title_flawless": XFest.TITLE_ONE_FOUR, "ring": 0},
	{"first": 20, "clear": 30, "flawless": 40, "title_clear": XFest.TITLE_ROAD, "title_flawless": XFest.TITLE_ONE_FOUR_DISASTER, "ring": 1},
	{"first": 20, "clear": 30, "flawless": 40, "title_clear": XFest.TITLE_ROAD, "title_flawless": XFest.TITLE_ONE_FOUR_HARD, "ring": 2},
]


static func on() -> bool:
	return ENABLED and XFest.ENABLED


static func tier_count() -> int:
	return TIERS.size()


static func troop_id(tier: int, stage: int) -> int:
	return TROOP_BASE + tier * 10 + stage


static func enemy_id(tier: int, stage: int, role: int) -> int:
	return ENEMY_BASE + tier * 100 + stage * 10 + role


## 敌人号 → [档, 关, 位置]；不是本活动的返回 []
static func _decode_enemy(id: int) -> Array:
	var k := id - ENEMY_BASE
	if k < 0:
		return []
	var tier := k / 100
	var stage := (k % 100) / 10
	var role := k % 10
	if tier >= TIERS.size() or stage >= TEAMS.size() or role >= ROLES.size():
		return []
	return [tier, stage, role]


static func _decode_troop(id: int) -> Array:
	var k := id - TROOP_BASE
	if k < 0:
		return []
	var tier := k / 10
	var stage := k % 10
	if tier >= TIERS.size() or stage >= TEAMS.size():
		return []
	return [tier, stage]


static func has_enemy(id: int) -> bool:
	return on() and not _decode_enemy(id).is_empty()


static func has_troop(id: int) -> bool:
	return on() and not _decode_troop(id).is_empty()


static func is_road_troop(id: int) -> bool:
	return has_troop(id)


static func has_skill(id: int) -> bool:
	return on() and id == HEAL_SKILL


## XDB.rec 的表外入口（id 已确认超出表长）
static func has(table_name: String, id: int) -> bool:
	match table_name:
		"Enemies": return has_enemy(id)
		"Troops": return has_troop(id)
		"Skills": return has_skill(id)
	return false


static func rec(table_name: String, id: int, table: Array) -> Dictionary:
	match table_name:
		"Enemies": return enemy_rec(id, table)
		"Troops": return troop_rec(id)
		"Skills": return skill_rec(id, table)
	return {}


static var _enemy_cache := {}
static var _enemy_table_ref: Array = []


## 敌人显示名「网吧队·上单」
static func enemy_name(stage: int, role: int) -> String:
	return "%s·%s" % [TEAMS[stage].name, ROLES[role].name]


static func _role_mul(stage: int, role: int, key: String) -> float:
	var m := float(ROLES[role].get(key, 1.0))
	var rm: Dictionary = TEAMS[stage].role_mul
	for k in [-1, role]:
		if rm.has(k):
			m *= float(rm[k].get(key, 1.0))
	return m


## 能力值（不含难度倍率；难度倍率由 XEnemy 照常乘）
static func enemy_params(tier: int, stage: int, role: int, base_params: Array) -> Array:
	var t := float(TEAMS[stage].mult)
	var hp_share := float(TIERS[tier].get("hp_share", HP_SHARE))
	var atk_share := float(TIERS[tier].get("atk_share", ATK_SHARE))
	var p: Array = []
	for i in 8:
		p.append(float(base_params[i]) if i < base_params.size() else 0.0)
	var out := [
		floor(p[0] * hp_share * t * _role_mul(stage, role, "hp")),
		p[1],
		floor(p[2] * atk_share * t * _role_mul(stage, role, "atk")),
		floor(p[3] * t * _role_mul(stage, role, "def")),
		floor(p[4] * atk_share * t * _role_mul(stage, role, "mat")),
		floor(p[5] * t * _role_mul(stage, role, "mdf")),
		floor(p[6] * sqrt(t) * _role_mul(stage, role, "agi")),
		p[7],
	]
	return out.map(func(v): return int(v))


## 表外敌人记录（XDB.rec 调）：复制基准守层者，换名字、图、能力值、技能；不掉东西、不给经验金钱、不会变神话
static func enemy_rec(id: int, table: Array) -> Dictionary:
	if not is_same(_enemy_table_ref, table):
		_enemy_cache.clear()
		_enemy_table_ref = table
	if _enemy_cache.has(id):
		return _enemy_cache[id]
	var d := _decode_enemy(id)
	if d.is_empty():
		return {}
	var tier: int = d[0]
	var stage: int = d[1]
	var role: int = d[2]
	var base_id := int(TIERS[tier].base)
	if base_id >= table.size() or not table[base_id] is Dictionary:
		return {}
	var base: Dictionary = table[base_id]
	var out: Dictionary = base.duplicate(true)
	out["id"] = id
	out["name"] = enemy_name(stage, role)
	out["battlerName"] = ""
	out["battlerHue"] = 0
	out["params"] = enemy_params(tier, stage, role, base.get("params", []))
	out["exp"] = 0
	out["gold"] = 0
	out["dropItems"] = []
	# 伤害抵抗等被动照基准守层者（行动表里条件 4 的那几条），再接本位置的技能
	var acts: Array = []
	for a in base.get("actions", []):
		if a is Dictionary and int(a.get("conditionType", 0)) == 4:
			acts.append((a as Dictionary).duplicate())
	for pair in ROLES[role].actions:
		acts.append({"skillId": int(pair[0]), "rating": int(pair[1]), "conditionType": 0, "conditionParam1": 0, "conditionParam2": 0})
	out["actions"] = acts
	var sprite: String = TEAMS[stage].sprites[role]
	out["note"] = "NoElite\n<EnemyNote>\n冠军庆典·冠军之路：%s（%s）\n</EnemyNote>\n<EnemyRace: 1>\n<Sideview Battler: %s>\n<Breathing Speed: 11>\n<Sideview No Collapse>\n<Sideview Weapon: 0, swing, 1>\n<Sideview Show Shadow>\n<DontEsc>" % [TEAMS[stage].name, ROLES[role].name, sprite]
	var meta: Dictionary = (out.get("meta", {}) as Dictionary).duplicate() if out.get("meta") is Dictionary else {}
	for k in ["hp", "mp", "atk", "def", "mat", "mdf", "agi", "luk", "Enemy Drops", "/Enemy Drops", "Hide HP Gauge", "elite", "boss", "Boss"]:
		meta.erase(k)
	meta["Sideview Battler"] = " " + sprite
	meta["EnemyRace"] = " 1"
	out["meta"] = meta
	_enemy_cache[id] = out
	return out


static var _troop_cache := {}


## 表外敌群记录
static func troop_rec(id: int) -> Dictionary:
	if _troop_cache.has(id):
		return _troop_cache[id]
	var d := _decode_troop(id)
	if d.is_empty():
		return {}
	var tier: int = d[0]
	var stage: int = d[1]
	var members := []
	for r in ROLES.size():
		members.append({"enemyId": enemy_id(tier, stage, r), "x": int(POS[r][0]), "y": int(POS[r][1]), "hidden": false})
	_troop_cache[id] = {"id": id, "name": "冠军之路·%s" % TEAMS[stage].name, "members": members, "pages": []}
	return _troop_cache[id]


static var _skill_cache := {}
static var _skill_table_ref: Array = []


## 辅助的「应援」：照治愈之歌复制，公式改成按目标最大生命的比例回复
static func skill_rec(id: int, table: Array) -> Dictionary:
	if id != HEAL_SKILL or HEAL_FROM >= table.size() or not table[HEAL_FROM] is Dictionary:
		return {}
	if not is_same(_skill_table_ref, table):
		_skill_cache.clear()
		_skill_table_ref = table
	if _skill_cache.has(id):
		return _skill_cache[id]
	var out: Dictionary = (table[HEAL_FROM] as Dictionary).duplicate(true)
	out["id"] = id
	out["name"] = "应援"
	out["description"] = "为全体队友回复最大生命的 %d%%。" % int(HEAL_RATE * 100)
	out["scope"] = 8
	out["mpCost"] = 0
	out["tpCost"] = 0
	var dmg: Dictionary = (out.get("damage", {}) as Dictionary).duplicate()
	dmg["type"] = 3
	dmg["formula"] = "b.mhp * %s" % str(HEAL_RATE)
	dmg["formulaGd"] = dmg["formula"]
	# 伤害结算读转换器预编译的公式程序（XFormulaExecution），不读 formula 字符串，所以手写同一条式子的程序
	dmg["formulaProgram"] = {"version": 1, "source": {"table": "Skills", "id": id, "custom": false, "sha256": ""}, "status": "pure",
		"capabilities": ["read.battler"], "locals": [], "result": "completion",
		"steps": [{"op": "expr", "pos": 0, "value": {"op": "binary", "pos": 0, "operator": "*",
			"left": {"op": "property", "pos": 0, "receiver": "b", "name": "mhp"},
			"right": {"op": "literal", "pos": 8, "value": HEAL_RATE}}}]}
	dmg["variance"] = 0
	dmg["critical"] = false
	out["damage"] = dmg
	out["note"] = ""
	out["meta"] = {}
	_skill_cache[id] = out
	return out


## 开战（XBattleLogic.setup 建完敌人后调）：冠军之路的敌人固定吃本档难度倍率（天灾／洪荒），不看玩家存档的难度，
## 也不吃存档 DCultyL1～5 的仓库倍率（warehouse_rate），再回满
static func battle_setup(logic) -> void:
	var d := _decode_troop(int(logic.troop_id))
	if not on() or d.is_empty():
		return
	var rates := XEnemy.difficulty_rates(int(TIERS[int(d[0])].difficulty))
	for e in logic.enemies:
		if not _decode_enemy(int(e.enemy_id)).is_empty():
			e._rates = rates
			e.set_meta("fest_road", true)  # XEnemy.warehouse_rate 见此恒为 1：不读存档的 DCultyL1～5（Star_Warehouse 难度怪物属性）
			e.recover_all()


## 本档敌人的实际能力值（不含等级、状态；测试和说明用）：基准×摊比×位置×队强度×本档难度倍率
static func effective_param(tier: int, stage: int, role: int, i: int) -> float:
	var base: Dictionary = XDB.table("Enemies")[int(TIERS[tier].base)]
	return float(enemy_params(tier, stage, role, base.params)[i]) * float(XEnemy.difficulty_rates(int(TIERS[tier].difficulty))[i])


# ==== 势如破竹（本场伤害加成） ====

## 当前这场冠军之路战斗的层数；只在 run 里开战前设、打完清零（不进存档）
static var battle_streak := 0
## 当前在不在冠军之路战斗里
static var in_road_battle := false


## 伤害钩子（XActorDamageHooks.capture）：冠军之路战斗里，我方角色出手的伤害 ×(1＋10%×层数)
static func damage_ops(a) -> Array:
	if not on() or not in_road_battle or battle_streak <= 0 or not (a is XActor):
		return []
	return [{"op": "mul", "field": "finalMultiplier", "value": 1.0 + STREAK_STEP * float(mini(battle_streak, STREAK_MAX))}]


# ==== 存档进度 ====

## 存档 flags.fest_champion.road_fest（欢庆档）／road（天灾档；改三档前的「普通版」进度就在这个键）／road_hard（洪荒档；原「困难版」）：
##   next     下一关（0～3；4 以上＝没在打）
##   flawless 这趟从第一关起没输过、也没中途接着打
##   pause    这趟的场间暂停用过没有
##   streak   这趟当前势如破竹层数
##   first    [四个布尔] 每关首胜（发过庆典币）
##   cleared  四关全胜过（发过「冠军之路」）
##   flawless_done  一次不败连穿过（发过本档一穿四称号和币）
##   ring     发过本档的冠军戒指（和 cleared 分开记：改三档前已全胜的旧进度，下次全胜补发戒指）
static func progress(s, tier := 0) -> Dictionary:
	var d := XFest.data(s)
	var key := str(TIERS[tier].save_key)
	if not d.get(key) is Dictionary:
		d[key] = {}
	var r: Dictionary = d[key]
	if not r.has("next"):
		r["next"] = TEAMS.size()
	if not r.get("first") is Array or (r["first"] as Array).size() != TEAMS.size():
		r["first"] = [false, false, false, false]
	for k in ["flawless", "pause", "cleared", "flawless_done", "ring"]:
		if not r.has(k):
			r[k] = false
	if not r.has("streak"):
		r["streak"] = 0
	return r


## 有没有中途输掉、能接着打的关（1～3；0 表示没有）
static func resume_stage(s, tier := 0) -> int:
	var n := int(progress(s, tier).next)
	return n if n > 0 and n < TEAMS.size() else 0


## 开新的一趟（从第一关起，可以拿「一穿四」）
static func begin_run(s, tier := 0) -> void:
	var r := progress(s, tier)
	r["next"] = 0
	r["flawless"] = true
	r["pause"] = false
	r["streak"] = 0


## 从输掉的那关接着打（不算不败；势如破竹清零）
static func continue_run(s, tier := 0) -> void:
	var r := progress(s, tier)
	r["flawless"] = false
	r["streak"] = 0


## 一关打完结算（result：0 胜 1 逃 2 败）。返回发了什么 {coins, titles: [], finished: bool, ring: 发的戒指实例或 {}}
static func settle(s, stage: int, result: int, tier := 0) -> Dictionary:
	var r := progress(s, tier)
	var rw: Dictionary = REWARDS[tier]
	var out := {"coins": 0, "titles": [], "finished": false, "ring": {}}
	if result != 0:
		r["next"] = stage  # 下次从这关接着打
		r["flawless"] = false
		r["streak"] = 0
		return out
	var first: Array = r["first"]
	if not bool(first[stage]):
		first[stage] = true
		XFest.add_coins(s, int(rw.first))
		out.coins += int(rw.first)
	r["streak"] = mini(int(r.get("streak", 0)) + 1, STREAK_MAX)
	r["next"] = stage + 1
	if stage + 1 >= TEAMS.size():
		out.finished = true
		if not bool(r.cleared):
			r["cleared"] = true
			XFest.add_coins(s, int(rw.clear))
			out.coins += int(rw.clear)
		if not bool(r.ring):
			var inst := XFestRing.grant(s, int(rw.ring))
			if not inst.is_empty():
				r["ring"] = true
				out.ring = inst
		if not XDesignation.unlocked(int(rw.title_clear)):
			out.titles.append(int(rw.title_clear))
		XFest.unlock_title(int(rw.title_clear))
		XFestReward.achieve(s, "road")
		if bool(r.flawless):
			if not bool(r.flawless_done):
				r["flawless_done"] = true
				XFest.add_coins(s, int(rw.flawless))
				out.coins += int(rw.flawless)
			if not XDesignation.unlocked(int(rw.title_flawless)):
				out.titles.append(int(rw.title_flawless))
			XFest.unlock_title(int(rw.title_flawless))
			XFestReward.achieve(s, "one_four")
		r["streak"] = 0
		r["flawless"] = false
		r["pause"] = false
	return out


## 场间暂停：全队回三成血蓝、复活阵亡的人（整趟一次）。返回是否用成
static func use_pause(s, tier := 0) -> bool:
	var r := progress(s, tier)
	if bool(r.pause):
		return false
	r["pause"] = true
	for a in s.battle_members():
		var mhp := float(a.mhp)
		var mmp := float(a.mmp)
		if a.is_dead():
			a.remove_state(1)
			a.hp = maxf(1.0, floorf(mhp * PAUSE_RATE))
		else:
			a.hp = minf(mhp, a.hp + floorf(mhp * PAUSE_RATE))
		a.mp = minf(mmp, a.mp + floorf(mmp * PAUSE_RATE))
	return true


## 成就组（第 2 天）按档读：四关全胜过／一次不败连穿过
static func cleared(s, tier := 0) -> bool:
	return bool(progress(s, tier).cleared)


static func flawless_done(s, tier := 0) -> bool:
	return bool(progress(s, tier).flawless_done)


## 输了或打完回大厅：队伍回满
static func recover_party(s) -> void:
	for a in s.members():
		a.recover_all()


# ==== 流程（报名处 NPC 调；大厅叠加层由乙车道接） ====

const SPEAKER := "\\n<冠军之路报名处>"


static func _say(host, lines: Array) -> void:
	await host.show_text("", 0, lines)


static func _ask(host, lines: Array, choices: Array, cancel: int) -> int:
	return int(await host.show_text_with_choices("", 0, lines, choices, cancel))


static func intro_lines() -> Array:
	return [SPEAKER + "冠军之路·一穿四：五打五，连打四支五人战队，中间不回大厅。",
		"血量、蓝量、阵亡都带进下一关；每赢一关全队伤害 +10%（最多三层）。",
		"整趟有一次场间暂停：全队回三成血蓝、复活阵亡的人。四关都不能逃跑。",
		"一共三档：欢庆档按「普通」难度 10 层守层者的强度来，天灾档、洪荒档按对应难度 26 层守层者的强度来。",
		"每档四关全胜送一枚冠军戒指，输过也算；三档的奖励分开拿。"]


static func lineup_text() -> String:
	var parts := []
	for i in TEAMS.size():
		parts.append(("决赛" if i == TEAMS.size() - 1 else "第%d关" % (i + 1)) + " " + str(TEAMS[i].name))
	return "　".join(parts)


## 报名处入口。活动外（XFest.active() 为假）或开关关着只说一句就走
static func talk(host, s = null) -> void:
	if s == null:
		s = XState.current
	if not on() or not XFest.active():
		await _say(host, [SPEAKER + "冠军之路现在没有开放。"])
		return
	if s == null or s.battle_members().is_empty():
		await _say(host, [SPEAKER + "先组好出战的队伍再来报名吧。"])
		return
	if XTianqi.active(s):
		# 天启篇守层者另有一套血量，本表按原版守层者定的数值，进去第一关就打不动：天启篇存档不开（v0.3.1 第 4 节）
		await _say(host, XFestText.ENROLL_TIANQI.map(func(row): return SPEAKER + str(row)))
		return
	# 先选档：欢庆／天灾／洪荒（三档奖励分开、互不顶替）
	var top := tier_labels()
	top.append_array(["规则说明", "离开"])
	var tp := await _ask(host, [SPEAKER + "欢迎来到冠军之路！今天的对手：", lineup_text()], top, top.size() - 1)
	if tp == TIERS.size():
		await _say(host, intro_lines())
		return
	if tp < 0 or tp >= TIERS.size():
		return
	var tier := tp
	var resume := resume_stage(s, tier)
	var opts := ["从第一关开始", "接着打第%d关（不算不败）" % (resume + 1), "返回"] if resume > 0 else ["从第一关开始", "返回"]
	var keys := ["new", "resume", "leave"] if resume > 0 else ["new", "leave"]
	var pick := await _ask(host, [SPEAKER + "%s：对手按「%s」难度 %d 层守层者的强度来。" % [TIERS[tier].name, TIERS[tier].diff_name, int(TIERS[tier].floor)]], opts, opts.size() - 1)
	var key: String = keys[pick] if pick >= 0 and pick < keys.size() else "leave"
	if (key == "new" or key == "resume") and not await _confirm_small_party(host, s):
		return
	match key:
		"new":
			begin_run(s, tier)
			await run(host, s, tier, 0)
		"resume":
			continue_run(s, tier)
			await run(host, s, tier, resume)


## 报名处选档的选项文字
static func tier_labels() -> Array:
	return TIERS.map(func(t): return "%s（对标%s难度 %d 层守层者）" % [t.name, t.diff_name, int(t.floor)])


## 出战不满五人：提示一句，选「仍要出战」才进（co 核查 P2，协调 11-15 裁定不强制五人：角色不够或想挑战的不挡）
static func _confirm_small_party(host, s) -> bool:
	if s.battle_members().size() >= 5:
		return true
	var pick := await _ask(host, [SPEAKER + "冠军之路是五打五，建议满五人出战。你现在只有 %d 人出战。" % s.battle_members().size()],
		["仍要出战", "回去整队"], 1)
	return pick == 0


## 大厅报名处（乙车道 XFestLobby 按 ROAD_CLASS／ROAD_METHOD 调 enter）：同 talk
static func enter(host, s = null) -> void:
	await talk(host, s)


## 从 stage 起连打到决赛（tier：档位序）
static func run(host, s, tier: int, stage: int) -> void:
	var r := progress(s, tier)
	var i := stage
	while i < TEAMS.size():
		if not on():
			return
		var streak := int(r.get("streak", 0))
		XToast.show_text("%s：%s%s" % ["决赛" if i == TEAMS.size() - 1 else "第%d关" % (i + 1), TEAMS[i].name,
			"　势如破竹×%d：全队伤害 +%d%%" % [streak, int(round(streak * STREAK_STEP * 100))] if streak > 0 else ""])
		battle_streak = streak
		in_road_battle = true
		var result: int = await host.start_battle(troop_id(tier, i), false, true)
		in_road_battle = false
		battle_streak = 0
		var got := settle(s, i, result, tier)
		if result != 0:
			recover_party(s)
			await _say(host, [SPEAKER + "这一关输给了%s。队伍已经回满，下次可以从这一关接着打。" % TEAMS[i].name])
			return
		if int(got.coins) > 0:
			XToast.show_text("获得庆典币 ×%d（现有 %d）" % [int(got.coins), XFest.coins(s)])
		if bool(got.finished):
			recover_party(s)
			var lines := [SPEAKER + "%s四关全胜，冠军之路完成！" % TIERS[tier].name]
			if not (got.ring as Dictionary).is_empty():
				lines.append("获得「%s」！已经放进背包，默认锁定。" % str(XFestRing.RINGS[int(REWARDS[tier].ring)].name))
			for t in got.titles:
				lines.append("获得称号「%s」！" % _title_name(int(t)))
			await _say(host, lines)
			return
		i += 1
		# 两关之间：继续／暂停（整趟一次）／退出
		while true:
			var opts := ["继续：%s" % TEAMS[i].name]
			var keys := ["go"]
			if not bool(r.pause):
				opts.append("场间暂停（全队回三成、复活阵亡；整趟一次）")
				keys.append("pause")
			opts.append("退出（势如破竹清零）")
			keys.append("quit")
			var pick := await _ask(host, [SPEAKER + "拿下%s！势如破竹 ×%d。" % [TEAMS[i - 1].name, int(r.streak)]], opts, -1)
			var key: String = keys[pick] if pick >= 0 and pick < keys.size() else "go"
			if key == "pause":
				use_pause(s, tier)
				XToast.show_text("场间暂停：全队回复三成")
				continue
			if key == "quit":
				r["flawless"] = false
				r["streak"] = 0
				recover_party(s)
				return
			break


static func _title_name(id: int) -> String:
	for t in XFest.TITLES:
		if int(t.id) == id:
			return str(t.name)
	return ""
