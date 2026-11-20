class_name XTianqiSixDim
extends RefCounted
## 【cc·六维卡1·未经审查】天启篇角色／敌人六维只读查询（T275；设定稿 天启篇_角色六维_v0.3定稿，Kyo D234）。
## 六维＝输出、生存、速度、战商、韧性、辅助；刻度 E～SSS＝1～8 分。数据 tianqi_data/six_dim.json，全整数（附则 E）。
## 本模块只读表，不碰伤害、血防、敏捷；战斗只接了卡 2 的 control_state_rate（T276，乘进 battle_logic.state_rate），卡 3～5 另接。只认天启篇存档（XTianqi.active），西游档或 ENABLED＝false
## 全部返回中性值（六维全 C、韧性抗控 0、战商 3 档、各权重 100）。没录的角色／敌人也回中性。
## 查找：角色按 actor_id；敌人先查 enemies[enemy_id]（可带 template 继承模板），没有回中性；骑士按 horsemen 键（death／war／famine／plague）。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/six_dim.json"
const DIMS := ["output", "survive", "speed", "wit", "resolve", "support"]
const LETTERS := ["E", "D", "C", "B", "A", "S", "SS", "SSS"]
const NEUTRAL_LETTER := "C"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容）
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## 只认天启篇存档且开关开着
static func active() -> bool:
	return ENABLED and XState.current != null and XTianqi.active(XState.current) and not data().is_empty()


static func neutral() -> Dictionary:
	var r := {}
	for d in DIMS:
		r[d] = NEUTRAL_LETTER
	return r


## 把一行表里的六维抄成纯 {维度: 字母}；缺的、不认识的档补 C
static func _six(row: Dictionary) -> Dictionary:
	var r := {}
	for d in DIMS:
		var l := str(row.get(d, NEUTRAL_LETTER))
		r[d] = l if LETTERS.has(l) else NEUTRAL_LETTER
	return r


static func of_actor(actor_id: int) -> Dictionary:
	if not active():
		return neutral()
	var row = data().get("actors", {}).get(str(actor_id))
	return _six(row) if row is Dictionary else neutral()


static func of_enemy(enemy_id: int) -> Dictionary:
	if not active():
		return neutral()
	var row = data().get("enemies", {}).get(str(enemy_id))
	if not row is Dictionary:
		return neutral()
	var base: Dictionary = {}
	var tpl = data().get("templates", {}).get(str(row.get("template", "")))
	if tpl is Dictionary:
		base = tpl.duplicate()
	for k in row:
		base[k] = row[k]  # 单只覆盖模板
	return _six(base)


## 骑士键：death／war／famine／plague
static func of_knight(line: String) -> Dictionary:
	if not active():
		return neutral()
	var row = data().get("knights", {}).get(line)
	return _six(row) if row is Dictionary else neutral()


## 战斗里的单位（XActor 按 actor_id、XEnemy 按 enemy_id）；logic 给了且它是本场骑士就按骑士键
static func of_battler(b, logic = null) -> Dictionary:
	if b == null or not active():
		return neutral()
	if logic != null and XTianqiHorsemen.is_knight(logic, b):
		return of_knight(str(XTianqiHorsemen.fight(logic).get("line", "")))
	if b.is_actor():
		return of_actor(int(b.actor_id))
	return of_enemy(int(b.enemy_id))


static func letter(six: Dictionary, dim: String) -> String:
	return str(six.get(dim, NEUTRAL_LETTER))


static func score(l: String) -> int:
	if LETTERS.has(l):
		return LETTERS.find(l) + 1
	return 3


static func total(six: Dictionary) -> int:
	var t := 0
	for d in DIMS:
		t += score(letter(six, d))
	return t


## 韧性控制抗性（整数百分点，−10～＋10）；不生效时 0
static func resist_pct_of(six: Dictionary) -> int:
	if not active():
		return 0
	return int(data().get("resist_pct", {}).get(letter(six, "resolve"), 0))


static func control_resist_pct(b, logic = null) -> int:
	return resist_pct_of(of_battler(b, logic)) if active() else 0


## 卡 2（T276）：韧性控制抗性乘进 battle_logic.state_rate（敌我共用）。只管控制状态（XEnemy.boss_control_state：
## 不含死亡、霸体；中毒、流血、降攻防等一律 1.0）；乘算，0 乘多少还是 0，不破任何免控。
## 返回 (100 − 控制抗性) ／ 100：E＝110／100 … C＝1.0 … SSS＝90／100。不生效（西游档、开关关）、韧性 C 或非控制都回 1.0。
static func control_state_rate(b, id: int, logic = null) -> float:
	if b == null or not active():
		return 1.0
	var pct := control_resist_pct(b, logic)
	if pct == 0 or not XEnemy.boss_control_state(id):
		return 1.0
	return float(100 - pct) / 100.0


## 战商 AI 档 1～5；不生效或没录回 3（中性）
static func ai_tier_of(six: Dictionary) -> int:
	if not active():
		return 3
	return int(data().get("ai_tier", {}).get(letter(six, "wit"), 3))


static func ai_tier(b, logic = null) -> int:
	return ai_tier_of(of_battler(b, logic))


## 敌方 AI 整数百分比权重：support_pct／summon_pct／aggro_pct／guard_hp_pct／guard_score_pct／repeat_pct／panic_pct 各按对应维度查；
## 不生效或没录全部回中性（权重 100、血线按 C 档、慌乱 0）
static func ai_weights_of(six: Dictionary) -> Dictionary:
	var w: Dictionary = data().get("ai_weights", {}) if active() else {}
	var src := {"support_pct": "support", "summon_pct": "support", "aggro_pct": "output", "guard_hp_pct": "survive",
		"guard_score_pct": "survive", "repeat_pct": "speed", "panic_pct": "resolve"}
	var neutral_val := {"support_pct": 100, "summon_pct": 100, "aggro_pct": 100, "guard_hp_pct": 35, "guard_score_pct": 130,
		"repeat_pct": 100, "panic_pct": 0}
	var r := {}
	for k in src:
		var tbl = w.get(k, {})
		r[k] = int(tbl.get(letter(six, src[k]), neutral_val[k])) if tbl is Dictionary else int(neutral_val[k])
	return r


static func ai_weights(b, logic = null) -> Dictionary:
	return ai_weights_of(of_battler(b, logic))
