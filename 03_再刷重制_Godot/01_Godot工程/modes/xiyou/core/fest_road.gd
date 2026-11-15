class_name XFestRoad
extends RefCounted
## 【cc·未经审查】冠军庆典·冠军之路「一穿四」（Kyo 11-15；方案：私密设计仓 重制设定/冠军庆典活动_v0.2.md 2.3 节）。
## 五打五连打四支五人队：网吧队 → 银河战舰队 → 大魔王队 → 内战幻神队（决赛）。队名、敌人名都是自创，不写真实战队与选手。
##
## - 敌人、敌群、辅助的群体治疗都是运行时追加（XDB.rec 表外号段），不改生成数据：敌人 9300 起、敌群 9300 起、技能 19300。
##   每只敌人照本档基准守层者复制（特性、属性抗性、伤害抵抗被动跟着走），再按「队强度×位置倍率」重算能力值、换名字换图换技能。
## - 四关连战：中间不回大厅；血量、蓝量、阵亡带进下一关（游戏本来就不在战后回复）。四关都不能逃跑，输了不结束游戏。
## - 势如破竹：每赢一关全队伤害 +10%，最多三层；只在冠军之路的战斗里生效（XActorDamageHooks 的 finalMultiplier），退出或输了清零。
## - 场间暂停：整趟一次，两关之间全队回三成血蓝、复活阵亡的人。
## - 输了：回到大厅、队伍回满；下次可以从输的那关接着打，但接着打的这趟不算「不败」。
## - 奖励（每个存档各算各的；称号全局）：每关首胜庆典币 ×30；四关全胜称号「冠军之路」；从第一关起一次不败连穿称号「一穿四」（金）＋庆典币 ×100。
##   庆典成就（第 2 天，模块 G）读存档 flags.fest_champion.road 的 cleared／flawless_done 就够，本文件不发成就。
## - 只开给原版档（天启篇档的守层者另有一套血量，第 1 天不开）。
## - 档位：第 1 天只开正赛（基准 20 层守层者石日天，敌群 456）；海选（10 层）、巅峰（30 层）第 2 天补进 TIERS。
## 开关 ENABLED＝false 或总开关 XFest.ENABLED＝false：表外记录都不认、伤害加成不生效、入口不开，回到没有冠军之路的样子。O-待定·冠军之路。

static var ENABLED := true

const ENEMY_BASE := 9300   # 敌人号＝ENEMY_BASE＋档位序×100＋关序×10＋位置序
const TROOP_BASE := 9300   # 敌群号＝TROOP_BASE＋档位序×10＋关序
const HEAL_SKILL := 19300  # 辅助的「应援」：全体友方回复最大生命的 HEAL_RATE
const HEAL_RATE := 0.04
const HEAL_FROM := 906     # 外观、动画照「治愈之歌」

## 势如破竹：每层伤害 +10%，最多 3 层
const STREAK_STEP := 0.10
const STREAK_MAX := 3
## 场间暂停回复比例
const PAUSE_RATE := 0.3
## 奖励
const COIN_FIRST_WIN := 30
const COIN_FLAWLESS := 100

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
## 第一版（11-15，没实测）：一关五人血量合计约 0.4～0.8 只守层者、四关合计约 2.4 只；每人攻击、魔攻是守层者的 0.35 倍再乘位置与队强度。
## 守层者基准队探针（tests/virtual_player/fest_road_probe）用的是天启篇弱者队，不代表原版档玩家，数值要等试打再调
const HP_SHARE := 0.1
const ATK_SHARE := 0.35

## 站位（照 853 号五人敌群的范围摆）：上单、打野、下路前排，中单、辅助后排
const POS := [[470, 340], [440, 230], [250, 290], [440, 450], [250, 410]]

## 档位：base＝基准守层者敌人号（复制它的特性、伤害抵抗被动），guard_troop 只作说明
const TIERS := [
	{"key": "main", "name": "正赛", "base": 523, "guard_troop": 456, "hint": "二十层上下"},
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
	var p: Array = []
	for i in 8:
		p.append(float(base_params[i]) if i < base_params.size() else 0.0)
	var out := [
		floor(p[0] * HP_SHARE * t * _role_mul(stage, role, "hp")),
		p[1],
		floor(p[2] * ATK_SHARE * t * _role_mul(stage, role, "atk")),
		floor(p[3] * t * _role_mul(stage, role, "def")),
		floor(p[4] * ATK_SHARE * t * _role_mul(stage, role, "mat")),
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

## 存档 flags.fest_champion.road：
##   next     下一关（0～3；4 以上＝没在打）
##   flawless 这趟从第一关起没输过、也没中途接着打
##   pause    这趟的场间暂停用过没有
##   streak   这趟当前势如破竹层数
##   first    [四个布尔] 每关首胜（发过庆典币）
##   cleared  四关全胜过（发过「冠军之路」）
##   flawless_done  一次不败连穿过（发过「一穿四」和 100 币）
static func progress(s) -> Dictionary:
	var d := XFest.data(s)
	if not d.get("road") is Dictionary:
		d["road"] = {}
	var r: Dictionary = d["road"]
	if not r.has("next"):
		r["next"] = TEAMS.size()
	if not r.get("first") is Array or (r["first"] as Array).size() != TEAMS.size():
		r["first"] = [false, false, false, false]
	for k in ["flawless", "pause", "cleared", "flawless_done"]:
		if not r.has(k):
			r[k] = false
	if not r.has("streak"):
		r["streak"] = 0
	return r


## 有没有中途输掉、能接着打的关（1～3；0 表示没有）
static func resume_stage(s) -> int:
	var n := int(progress(s).next)
	return n if n > 0 and n < TEAMS.size() else 0


## 开新的一趟（从第一关起，可以拿「一穿四」）
static func begin_run(s) -> void:
	var r := progress(s)
	r["next"] = 0
	r["flawless"] = true
	r["pause"] = false
	r["streak"] = 0


## 从输掉的那关接着打（不算不败；势如破竹清零）
static func continue_run(s) -> void:
	var r := progress(s)
	r["flawless"] = false
	r["streak"] = 0


## 一关打完结算（result：0 胜 1 逃 2 败）。返回发了什么 {coins, titles: [], finished: bool}
static func settle(s, stage: int, result: int) -> Dictionary:
	var r := progress(s)
	var out := {"coins": 0, "titles": [], "finished": false}
	if result != 0:
		r["next"] = stage  # 下次从这关接着打
		r["flawless"] = false
		r["streak"] = 0
		return out
	var first: Array = r["first"]
	if not bool(first[stage]):
		first[stage] = true
		XFest.add_coins(s, COIN_FIRST_WIN)
		out.coins += COIN_FIRST_WIN
	r["streak"] = mini(int(r.get("streak", 0)) + 1, STREAK_MAX)
	r["next"] = stage + 1
	if stage + 1 >= TEAMS.size():
		out.finished = true
		if not bool(r.cleared):
			r["cleared"] = true
		if not XDesignation.unlocked(XFest.TITLE_ROAD):
			out.titles.append(XFest.TITLE_ROAD)
		XFest.unlock_title(XFest.TITLE_ROAD)
		if bool(r.flawless):
			if not bool(r.flawless_done):
				r["flawless_done"] = true
				XFest.add_coins(s, COIN_FLAWLESS)
				out.coins += COIN_FLAWLESS
			if not XDesignation.unlocked(XFest.TITLE_ONE_FOUR):
				out.titles.append(XFest.TITLE_ONE_FOUR)
			XFest.unlock_title(XFest.TITLE_ONE_FOUR)
		r["streak"] = 0
		r["flawless"] = false
		r["pause"] = false
	return out


## 场间暂停：全队回三成血蓝、复活阵亡的人（整趟一次）。返回是否用成
static func use_pause(s) -> bool:
	var r := progress(s)
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
		"整趟有一次场间暂停：全队回三成血蓝、复活阵亡的人。四关都不能逃跑。"]


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
		# 天启篇守层者另有一套血量（XGuardianRework），本表按原版守层者定的数值对不上；天启篇档先不开（第 1 天）
		await _say(host, [SPEAKER + "这份存档暂时不能报名冠军之路。"])
		return
	var resume := resume_stage(s)
	var opts := ["从第一关开始", "接着打第%d关（不算不败）" % (resume + 1), "规则说明", "离开"] if resume > 0 else ["从第一关开始", "规则说明", "离开"]
	var keys := ["new", "resume", "rules", "leave"] if resume > 0 else ["new", "rules", "leave"]
	var pick := await _ask(host, [SPEAKER + "欢迎来到冠军之路！今天的对手：", lineup_text()], opts, opts.size() - 1)
	var key: String = keys[pick] if pick >= 0 and pick < keys.size() else "leave"
	match key:
		"rules":
			await _say(host, intro_lines())
		"new":
			begin_run(s)
			await run(host, s, 0, 0)
		"resume":
			continue_run(s)
			await run(host, s, 0, resume)


## 大厅报名处（乙车道 XFestLobby 按 ROAD_CLASS／ROAD_METHOD 调 enter）：同 talk
static func enter(host, s = null) -> void:
	await talk(host, s)


## 从 stage 起连打到决赛（tier：档位序）
static func run(host, s, tier: int, stage: int) -> void:
	var r := progress(s)
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
		var got := settle(s, i, result)
		if result != 0:
			recover_party(s)
			await _say(host, [SPEAKER + "这一关输给了%s。队伍已经回满，下次可以从这一关接着打。" % TEAMS[i].name])
			return
		if int(got.coins) > 0:
			XToast.show_text("获得庆典币 ×%d（现有 %d）" % [int(got.coins), XFest.coins(s)])
		if bool(got.finished):
			recover_party(s)
			var lines := [SPEAKER + "四关全胜，冠军之路完成！"]
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
				use_pause(s)
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
