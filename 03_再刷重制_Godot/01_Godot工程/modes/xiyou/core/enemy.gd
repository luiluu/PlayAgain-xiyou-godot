class_name XEnemy
extends XBattler
## 敌人：MV Game_Enemy ＋ Vitsuno_Difficulty 按难度放大能力值 ＋ EliteEnemy 随机「神话」变体。
## 神话（正式版插件参数）：几率 50%（备注 <elite:几率,能力,经验,金钱,掉率> 可单独设定，NoElite 不会变），
## 基础能力值 ×3.5 取整、经验 ×1.2、金钱 ×1.2、掉率 ×5，名字前加「【神话】」，图像放大 1.8 倍并偏色。
## 开关参数「开启」在正式版被读成 NaN（不看开关），所以总是生效。
## 敌人等级（YEP_EnemyLevels）在正式版只影响显示（已关闭）且不改能力值，不做。

var enemy_id := 0
var difficulty_id := 2
var letter := ""
var _rates: Array = [1, 1, 1, 1, 1, 1, 1, 1]
var _passive_cache := {}
var elite := false
var elite_hue := 0.0              # 0~1，画面偏色用
## 测试用：>= 0 时所有敌人按此值判定神话（0 必为神话，100 必不是）
static var force_roll := -1.0


## roll < 0 时按几率随机决定神话；测试可传 0（必为神话，除非 NoElite）或 100（必不是）。
func setup(id: int, difficulty: int, roll := -1.0) -> XEnemy:
	enemy_id = id
	difficulty_id = difficulty
	_rates = difficulty_rates(difficulty)
	if roll < 0.0:
		roll = force_roll
	var r := randf() * 100.0 if roll < 0.0 else roll
	elite = r < elite_param(0) and not str(data().get("note", "")).contains("NoElite")
	if elite:
		elite_hue = randf_range(100.0, 170.0) / 360.0
	refresh_passive()
	recover_all()
	return self


## EnemyNameColorByDifficulty：任何与数据库敌人原名（去首尾空白）完全相同的文字，改画成当前难度的颜色。
const NAME_COLORS := {1: "#ffffff", 2: "#39ff39", 3: "#4499ff", 4: "#b050ff", 5: "#ff9922", 6: "#ffd700", 7: "#ff2222", 8: "#ee77ee"}
static var _names := {}

static func name_color(text: String, difficulty: int, base := XUI.TEXT) -> Color:
	if _names.is_empty():
		for e in XDB.table("Enemies"):
			if e is Dictionary and str(e.get("name", "")).strip_edges() != "":
				_names[str(e.name).strip_edges()] = true
	if _names.has(text.strip_edges()) and NAME_COLORS.has(difficulty):
		return Color(NAME_COLORS[difficulty])
	return base


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
	return (elite_title() if elite else "") + str(data().get("name", "")) + letter

static func elite_title() -> String:
	return str(XDB.plugin("EliteEnemy").get("EliteEnemyTitle", "【精英】"))

## EliteEnemy 数值：0 几率、1 能力、2 经验、3 金钱、4 掉率；备注 <elite:...> 优先。
func elite_param(i: int) -> float:
	var keys := ["EliteEnemyChances", "EliteEnemyAdditionParamBase", "EliteEnemyAdditionExp", "EliteEnemyAdditionGold", "EliteEnemyAdditionDropItemRate"]
	var defaults := [35.0, 1.5, 3.0, 3.0, 2.0]
	var meta = data().get("meta", {}).get("elite")
	if meta != null:
		var parts := str(meta).split(",")
		# JS：Number(片段 || 默认)——片段为空才用默认
		if i < parts.size() and parts[i].strip_edges() != "":
			return float(parts[i])
	var v := str(XDB.plugin("EliteEnemy").get(keys[i], ""))
	return float(v) if v != "" else defaults[i]

func _level() -> int:
	return 1

func param_base(i: int) -> float:
	var base := float(data().params[i])
	if elite:
		base = floorf(base * elite_param(1))
	return base * float(_rates[i])

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
	return int(float(data().get("exp", 0)) * (elite_param(2) if elite else 1.0))

func gold_reward() -> int:
	return int(float(data().get("gold", 0)) * (elite_param(3) if elite else 1.0))

## 掉率倍数（神话 ×5）
func drop_rate_bonus() -> float:
	return elite_param(4) if elite else 1.0

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
