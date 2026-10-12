class_name XEnemy
extends XBattler
## 敌人：MV Game_Enemy ＋ Vitsuno_Difficulty 按难度放大能力值。
## 精英/神话随机变体（EliteEnemy）、敌人等级（YEP_EnemyLevels）首期不做。

var enemy_id := 0
var difficulty_id := 2
var letter := ""
var _rates: Array = [1, 1, 1, 1, 1, 1, 1, 1]
var _passive_cache := {}


func setup(id: int, difficulty: int) -> XEnemy:
	enemy_id = id
	difficulty_id = difficulty
	_rates = difficulty_rates(difficulty)
	refresh_passive()
	recover_all()
	return self


static func difficulty_rates(difficulty: int) -> Array:
	var p := XDB.plugin("Vitsuno_Difficulty")
	var s := str(p.get("%d : Param Rate" % difficulty, ""))
	if s == "":
		return [1, 1, 1, 1, 1, 1, 1, 1]
	return Array(s.split(",")).map(func(x): return float(x))

static func difficulty_name(difficulty: int) -> String:
	return str(XDB.plugin("Vitsuno_Difficulty").get("%d : Name" % difficulty, ""))


func data() -> Dictionary:
	return XDB.rec("Enemies", enemy_id)

func display_name() -> String:
	return str(data().get("name", "")) + letter

func _level() -> int:
	return 1

func param_base(i: int) -> float:
	return float(data().params[i]) * float(_rates[i])

func trait_objects() -> Array:
	var out := [data()]
	out.append_array(states())
	return out

## 敌人可用的技能对象（来自行动列表），伤害结算按 objects() 扫描标签时会用到。
func skills() -> Array:
	var out := []
	for a in data().get("actions", []):
		var s := XDB.rec("Skills", int(a.skillId))
		if not s.is_empty() and not out.has(s):
			out.append(s)
	return out

func exp_reward() -> int:
	return int(data().get("exp", 0))

func gold_reward() -> int:
	return int(data().get("gold", 0))

func race_ids() -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)<EnemyRace\\s*:\\s*(\\d+)\\s*>").search_all(str(data().get("note", ""))):
		out.append(int(m.get_string(1)))
	return out


## dsPassiveSkill Game_Enemy.refreshPassiveCache：只有元素减伤。
func refresh_passive() -> void:
	var c := {"harmRe": {}, "globalHarmRi": 0.0, "critHarmRi": 0.0}
	for o in trait_objects():
		for m in XActor._scan(str(o.get("note", "")), "<passiveHarmRe(\\d+):\\s*([\\d.]+)>"):
			c.harmRe[int(m[0])] = c.harmRe.get(int(m[0]), 0.0) + float(m[1])
	_passive_cache = c

func passive_cache() -> Dictionary:
	return _passive_cache
