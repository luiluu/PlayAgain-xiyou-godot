class_name XTianqiQiyinDragon
extends RefCounted
## 天启篇特殊副本「七首之龙」：出现判定、龙隙存放、打赢的奖励和龙血。数在 modes/xiyou/tianqi_data/qiyin_dragon.json。
## 来源：七印祭坛方案 v0.4，Kyo 11-12 定稿。
##
## 纯逻辑：状态是一个 Dictionary，传进来不改，改过的副本放在返回值的 "state" 里；随机数用注入的 XRandomStream。
## 不做战斗本身，不接界面和存档；首杀多招一人只返回 extra_recruit 标记。
##
## 状态字段（new_state() 给初值）：
##   misses       连续没出龙隙的判定次数（暗保底用；存着或开着龙隙时不涨）
##   rift         龙隙状态：none（没有）／offered（刚出现，当场问进不进）／stored（存着）／fighting（进去了，在打）
##   first_kill   打赢过一次没有（首杀多招一人只给一次）
##   blood_stock  手上还没喝的龙血瓶数
##   blood        各角色喝过几瓶 {actor_id(String): 瓶数}

const PATH := "res://modes/xiyou/tianqi_data/qiyin_dragon.json"
const RIFT_NONE := "none"
const RIFT_OFFERED := "offered"
const RIFT_STORED := "stored"
const RIFT_FIGHTING := "fighting"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyinDragon: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyinDragon: JSON 解析失败 " + PATH)
	return _data


## 测试用：清掉缓存，下次重新读文件
static func reload() -> void:
	_data = {}


static func seals() -> Array:
	return data().get("seals", []).duplicate()


static func new_state() -> Dictionary:
	return {"misses": 0, "rift": RIFT_NONE, "first_kill": false, "blood_stock": 0, "blood": {}}


## 补齐缺的字段，返回深拷贝（传进来的不改）
static func _norm(state: Dictionary) -> Dictionary:
	var out := new_state()
	for k in state:
		out[k] = state[k]
	out = out.duplicate(true)
	return out


# ---- 出现 ----

## 本档难度的出现率；没有的难度键返回 0
static func rift_chance(difficulty: String) -> float:
	return float(data().get("rift", {}).get("chance", {}).get(difficulty, 0.0))


static func pity_after() -> int:
	return int(data().get("rift", {}).get("pity_after", 0))


## 打赢一个里副本的 Boss 之后调一次。
## 龙隙存着（或刚出现、正在打）时不判定、不抽随机数、保底计数不涨：rolled=false。
## 否则抽一个随机数（保底那次也抽，消耗固定）；连空 pity_after 次之后这次必出（pity=true）。
## 出了：rift=offered，misses 归零；没出：misses+1。
## 返回 {state, rolled, appeared, pity}；难度键不对返回 {state, error}。
static func roll_rift(state: Dictionary, difficulty: String, rng: XRandomStream) -> Dictionary:
	var s := _norm(state)
	if not data().get("rift", {}).get("chance", {}).has(difficulty):
		return {"state": s, "error": "unknown_difficulty:" + difficulty}
	if str(s.rift) != RIFT_NONE:
		return {"state": s, "rolled": false, "appeared": false, "pity": false}
	var r := rng.next_float("qiyin_dragon.rift")
	var pity := int(s.misses) >= pity_after()
	var appeared := pity or r < rift_chance(difficulty)
	if appeared:
		s.rift = RIFT_OFFERED
		s.misses = 0
	else:
		s.misses = int(s.misses) + 1
	return {"state": s, "rolled": true, "appeared": appeared, "pity": pity and r >= rift_chance(difficulty)}


# ---- 进不进 ----

## 刚出现的龙隙先存着（最多存 1 次；存着时不会再出新的）。不是刚出现的返回 error。
static func store_rift(state: Dictionary) -> Dictionary:
	var s := _norm(state)
	if str(s.rift) != RIFT_OFFERED:
		return {"state": s, "error": "no_offered_rift"}
	s.rift = RIFT_STORED
	return {"state": s}


## 进龙隙：刚出现的或存着的都能进，不要印钥。没有可进的返回 error。
static func enter_rift(state: Dictionary) -> Dictionary:
	var s := _norm(state)
	if str(s.rift) != RIFT_OFFERED and str(s.rift) != RIFT_STORED:
		return {"state": s, "error": "no_rift"}
	s.rift = RIFT_FIGHTING
	return {"state": s}


## 打输了：龙隙合上（存的那次也没了）。不在打的返回 error。
static func lose_rift(state: Dictionary) -> Dictionary:
	var s := _norm(state)
	if str(s.rift) != RIFT_FIGHTING:
		return {"state": s, "error": "not_fighting"}
	s.rift = RIFT_NONE
	return {"state": s}


# ---- 战斗数据（本车道不做战斗）----

## 本档难度的最大生命：艰险 250 万 × 本档敌人血量倍率 ÷ 艰险的敌人血量倍率（XTianqiBalance）。难度键不对返回 0。
static func max_hp(difficulty: String) -> int:
	var base := float(data().get("fight", {}).get("max_hp_jianxian", 0))
	var d := XTianqiBalance.difficulty(difficulty)
	var ref := XTianqiBalance.difficulty("jianxian")
	if d.is_empty() or ref.is_empty() or is_zero_approx(float(ref.enemy_hp)):
		return 0
	return int(round(base * float(d.enemy_hp) / float(ref.enemy_hp)))


## 战斗用的一张表：max_hp、stats_ref、actions_per_turn、segments、segment_hp（每段生命，最后一段补零头）、
## reveal_order（第 i 首断掉揭的印）、grey_reprieve（灰印那段的缓期）。难度键不对返回空。
static func fight_data(difficulty: String) -> Dictionary:
	var hp := max_hp(difficulty)
	if hp <= 0:
		return {}
	var f: Dictionary = data().get("fight", {})
	var n := int(f.get("segments", 0))
	var seg := []
	var left := hp
	for i in n:
		var v: int = floori(float(hp) / n) if i < n - 1 else left
		seg.append(v)
		left -= v
	return {"difficulty": difficulty, "max_hp": hp, "stats_ref": f.get("stats_ref", {}).duplicate(),
		"actions_per_turn": int(f.get("actions_per_turn", 0)), "segments": n, "segment_hp": seg,
		"reveal_order": f.get("reveal_order", []).duplicate(), "grey_reprieve": f.get("grey_reprieve", {}).duplicate()}


# ---- 奖励 ----

## 打赢一次（必须在 fighting）。chosen_seal 是玩家自选的真印套装件的印。
## 抽随机数的顺序固定：部位 → 武器判定 →（中了）武器的印 → 神器判定 →（中了）哪件神器。
## 返回 {state, true_set_piece:{seal, part, true_seal:true}, dragon_blood:1, weapon:null|{seal, true_seal:true},
##       artifact:null|神器键, extra_recruit:bool, recruit_floor}；
## 龙血同时记进 state.blood_stock，first_kill 置 true，龙隙关上。印不对或不在打返回 {state, error}（状态不变）。
static func reward(state: Dictionary, chosen_seal: String, rng: XRandomStream, with_artifact := true) -> Dictionary:
	var s := _norm(state)
	if str(s.rift) != RIFT_FIGHTING:
		return {"state": s, "error": "not_fighting"}
	var all_seals := seals()
	if not all_seals.has(chosen_seal):
		return {"state": s, "error": "unknown_seal:" + chosen_seal}
	var r: Dictionary = data().get("reward", {})
	var parts: Array = r.get("set_parts", [])
	var part := str(parts[rng.next_index_mod(parts.size(), "qiyin_dragon.set_part")])
	var weapon = null
	if rng.next_float("qiyin_dragon.weapon") < float(r.get("weapon_chance", 0.0)):
		weapon = {"seal": str(all_seals[rng.next_index_mod(all_seals.size(), "qiyin_dragon.weapon_seal")]), "true_seal": true}
	var artifact = null
	if with_artifact and rng.next_float("qiyin_dragon.artifact") < float(r.get("artifact_chance", 0.0)):  # false：神器保底开着，调用方掷
		var arts: Array = r.get("artifacts", [])
		artifact = str(arts[rng.next_index_mod(arts.size(), "qiyin_dragon.artifact_pick")])
	var blood := int(r.get("dragon_blood", 0))
	var extra := not bool(s.first_kill)
	s.first_kill = true
	s.rift = RIFT_NONE
	s.blood_stock = int(s.blood_stock) + blood
	return {"state": s, "true_set_piece": {"seal": chosen_seal, "part": part, "true_seal": true},
		"dragon_blood": blood, "weapon": weapon, "artifact": artifact, "extra_recruit": extra,
		"recruit_floor": int(r.get("recruit_floor", 0))}


# ---- 龙血 ----

static func max_blood_per_actor() -> int:
	return int(data().get("dragon_blood", {}).get("max_per_actor", 0))


static func _drunk(state: Dictionary, actor_id: String) -> int:
	var b = state.get("blood", {})
	return int(b.get(actor_id, 0)) if b is Dictionary else 0


## 手上有龙血、这名角色还没喝满才能喝
static func can_drink(state: Dictionary, actor_id: String) -> bool:
	return int(state.get("blood_stock", 0)) > 0 and _drunk(state, actor_id) < max_blood_per_actor()


## 给一名角色喝一瓶：成功时 blood_stock−1、该角色瓶数+1；喝满（第 4 瓶）或没有龙血时拒绝、不消耗。
## 返回 {state, ok, reason?}（reason：full／no_blood）
static func drink(state: Dictionary, actor_id: String) -> Dictionary:
	var s := _norm(state)
	if int(s.blood_stock) <= 0:
		return {"state": s, "ok": false, "reason": "no_blood"}
	if _drunk(s, actor_id) >= max_blood_per_actor():
		return {"state": s, "ok": false, "reason": "full"}
	s.blood_stock = int(s.blood_stock) - 1
	s.blood[actor_id] = _drunk(s, actor_id) + 1
	return {"state": s, "ok": true}


## 这名角色的全属性加成：瓶数 × 3%（0、0.03、0.06、0.09）
static func bonus(state: Dictionary, actor_id: String) -> float:
	var n := mini(_drunk(state, actor_id), max_blood_per_actor())
	return n * float(data().get("dragon_blood", {}).get("per_bottle", 0.0))


# ---- 数值要好看（Kyo 11-10）----

## 表里设计数值含数字 4 的：返回「路径=值」列表。豁免键（编号、次数上限）写在表头 nice_number_exempt。
static func nice_number_violations() -> Array:
	var exempt: Array = data().get("nice_number_exempt", [])
	var out := []
	_scan_nice(data(), "", exempt, out)
	return out


static func _scan_nice(v, path: String, exempt: Array, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not exempt.has(k):
				_scan_nice(v[k], path + "/" + str(k), exempt, out)
	elif v is Array:
		for i in v.size():
			_scan_nice(v[i], path + "/" + str(i), exempt, out)
	elif v is float or v is int:
		var x := float(v)
		var s := str(int(x)) if x == floorf(x) else String.num(x, 6).rstrip("0").rstrip(".")
		if s.contains("4"):
			out.append(path + "=" + s)
