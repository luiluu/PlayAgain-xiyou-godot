class_name XTianqiNature
extends RefCounted
## 【cc·天启篇·未经审查】天启篇自然体质读取（设计稿《天启篇_元素独特效果_v0.3》4.1～4.4；T480）。
## 敌人：tianqi_data/enemy_nature.json（T479，按敌人号；鸿钧、骑士按战斗身份取 special）；
## 我方：tianqi_data/actor_nature.json（T484，按角色号，0 或 1 个）。只读表，不读西游体质／吸收标签。
## 变身后按当前敌人号重读（XEnemy.enemy_id 跟着变），所以不缓存单位。只给元素效果用，不喂弱点牌组。

const ENEMY_PATH := "res://modes/xiyou/tianqi_data/enemy_nature.json"
const ACTOR_PATH := "res://modes/xiyou/tianqi_data/actor_nature.json"

static var _enemy: Dictionary = {}
static var _actor: Dictionary = {}
static var _enemy_failed := false
static var _actor_failed := false


static func _load(path: String) -> Dictionary:
	if XDataFile.missing(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if not parsed is Dictionary:
		push_error("XTianqiNature: 读不到或解析失败 " + path)
		return {}
	return parsed


static func enemy_table() -> Dictionary:
	if _enemy.is_empty() and not _enemy_failed:
		_enemy = _load(ENEMY_PATH)
		_enemy_failed = _enemy.is_empty()
	return _enemy


static func actor_table() -> Dictionary:
	if _actor.is_empty() and not _actor_failed:
		_actor = _load(ACTOR_PATH)
		_actor_failed = _actor.is_empty()
	return _actor


static func reload_table() -> void:
	_enemy = {}
	_actor = {}
	_enemy_failed = false
	_actor_failed = false


static func _ints(a) -> Array:
	var out := []
	if a is Array:
		for v in a:
			if not out.has(int(v)):
				out.append(int(v))
	return out


## 单位的自然体质（基础十系元素号，敌人 0～2 个、我方 0～1 个）；不是战斗单位或表缺时 []
static func of(b) -> Array:
	if b is XEnemy:
		var e := b as XEnemy
		var t := enemy_table()
		var special: Dictionary = t.get("special", {})
		if str(e.horseman.get("rec", {}).get("_ref", "")) == "hongjun":
			return _ints(special.get("hongjun", {}).get("natures", []))
		if bool(e.horseman.get("knight", false)):
			return _ints(special.get("knight", {}).get("natures", []))
		return _ints(t.get("enemies", {}).get(str(e.enemy_id), {}).get("natures", []))
	if b is XActor:
		return _ints(actor_table().get("actors", {}).get(str((b as XActor).actor_id), {}).get("natures", []))
	return []


## 种族号：敌人读 <EnemyRace>，我方不读种族（4.4）
static func races(b) -> Array:
	if b is XEnemy:
		return (b as XEnemy).race_ids()
	return []
