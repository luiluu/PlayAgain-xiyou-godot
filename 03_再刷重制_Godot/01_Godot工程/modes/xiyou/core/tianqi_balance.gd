class_name XTianqiBalance
extends RefCounted
## 天启篇档位与五档难度的数值表（只读）：modes/xiyou/tianqi_data/balance_table.json。
## 数来自设计仓库的天启篇数值测算 参数.json（Kyo 拍板的档位出伤／承伤、弱者协力；敌人倍率、品质偏移、助力位光环是占位，表里标 draft）。
##
## 本类只读数据；接进流程的是 XTianqiCombat（敌人倍率、伤害结算）和 XTianqi.difficulty()（候选池、超强者上限、至少弱者），第三批起。
## 档位名用 XTier.WEAK／STRONG／SUPER；难度键与 XTianqi.DIFFICULTIES 的 key 相同。

const PATH := "res://modes/xiyou/tianqi_data/balance_table.json"
## 同一场上场人数（助力位不算），弱者协力最多按这么多人算
const FIELD_SIZE := 4

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiBalance: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiBalance: JSON 解析失败 " + PATH)
	return _data


## 测试用：清掉缓存，下次重新读文件
static func reload() -> void:
	_data = {}


# ---- 档位 ----

static func tier_names() -> Array:
	return [XTier.WEAK, XTier.STRONG, XTier.SUPER]


## 档位一行：damage_dealt（出伤加成，读攻击者）、damage_taken（承伤加成，读目标；负数＝少受）、secret_cap（秘籍上限）。没有为空。
static func tier(name: String) -> Dictionary:
	var t = data().get("tiers", {}).get(name)
	return t if t is Dictionary else {}


## 档位出伤倍率：1＋出伤加成（独立乘区，只乘一次）
static func tier_damage_mult(name: String) -> float:
	return 1.0 + float(tier(name).get("damage_dealt", 0.0))


## 档位承伤倍率：1＋承伤加成
static func tier_taken_mult(name: String) -> float:
	return 1.0 + float(tier(name).get("damage_taken", 0.0))


static func secret_cap(name: String) -> int:
	return int(tier(name).get("secret_cap", 0))


# ---- 弱者协力与助力位 ----

## 上场弱者给全队的协力：{"damage_dealt": 出伤加成, "damage_taken": 承伤加成}。按上场人数封顶，助力位不要算进 weak_count。
static func assist_bonus(weak_count: int) -> Dictionary:
	var w: Dictionary = data().get("weak_assist", {})
	var n := clampi(weak_count, 0, FIELD_SIZE)
	return {"damage_dealt": n * float(w.get("damage_dealt_per", 0.0)),
		"damage_taken": n * float(w.get("damage_taken_per", 0.0))}


## 助力位光环给全队的出伤加成（占位）
static func assist_slot_aura() -> float:
	return float(data().get("assist_slot", {}).get("team_damage_dealt", 0.0))


## 全队相对出伤：Σ(1＋档位出伤) ×(1＋上场弱者数×协力出伤)。tiers 是上场各人的档位名。测算与测试用，不进战斗。
static func team_damage(tiers: Array) -> float:
	var sum := 0.0
	for t in tiers:
		sum += tier_damage_mult(t)
	return sum * (1.0 + float(assist_bonus(tiers.count(XTier.WEAK)).damage_dealt))


## 全队相对承伤：Σ(1＋档位承伤) ×(1＋上场弱者数×协力承伤)。越小越耐打。
static func team_taken(tiers: Array) -> float:
	var sum := 0.0
	for t in tiers:
		sum += tier_taken_mult(t)
	return sum * (1.0 + float(assist_bonus(tiers.count(XTier.WEAK)).damage_taken))


# ---- 路线系数与副本档（O-待定-8、O-待定-7） ----

## 本档按吸收的旧路线取的系数：zhenqi_coef、liuying_core、starburst_denom、lottery_cap。没有这一档为空
static func route(key: String) -> Dictionary:
	var r = data().get("routes", {}).get(key)
	return r if r is Dictionary else {}


## 副本档（变量 450：1 普通…4 王者）的敌人系数 {enemy_hp, enemy_atk}；档号不在表里为空
static func dungeon_tier(n: int) -> Dictionary:
	var list: Array = data().get("dungeon_tiers", {}).get("list", [])
	if n < 1 or n > list.size() or not list[n - 1] is Dictionary:
		return {}
	return list[n - 1]


# ---- 五档难度 ----

static func difficulty_keys() -> Array:
	return data().get("difficulties", []).map(func(d): return str(d.get("key", "")))


## 难度一行，拍平成：key、name、enemy_hp、enemy_atk、party_damage、quality_offset（占位）、pool（档位名）、super_cap、min_weak。没有为空。
static func difficulty(key: String) -> Dictionary:
	for d in data().get("difficulties", []):
		if str(d.get("key", "")) == key:
			var out := {"key": key, "name": str(d.get("name", ""))}
			var sc: Dictionary = d.get("scaling", {})
			for k in ["enemy_hp", "enemy_atk", "party_damage", "quality_offset"]:
				out[k] = float(sc.get(k, 0.0))
			var r: Dictionary = d.get("roster", {})
			out["pool"] = r.get("pool", []).duplicate()
			out["super_cap"] = int(r.get("super_cap", 0))
			out["min_weak"] = int(r.get("min_weak", 0))
			return out
	return {}


# ---- 数值要好看（Kyo 11-10）----

## 表里设计数值含数字 4 的：返回「路径=值」列表。豁免键（个数类）写在表头 nice_number_exempt。
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
		var s := _num_text(float(v))
		if s.contains("4"):
			out.append(path + "=" + s)


## 和 Python 版一样的写法：整数不带小数点，其余去掉尾零
static func _num_text(x: float) -> String:
	if x == floorf(x):
		return str(int(x))
	return String.num(x, 6).rstrip("0").rstrip(".")
