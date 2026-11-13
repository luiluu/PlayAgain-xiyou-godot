class_name XVegetaTune
extends RefCounted
## 【cc·未经审查】贝吉特（164）优化调整（Kyo 11-13：v0.01.08 削弱贝吉特，更新说明只写「贝吉特优化调整」；天启篇以后按数值重构方案另做）。
## 在原版数值体系里改，读表时就地改原件（XDB.table）：
## - 自我极意功（10568 → 状态 2777 终伤 1.5×变量 1543、公共事件 1722 每次挨打 +1 封顶 20）：原版变量从不清零，挨够 20 次后永久 ×31。
##   改成每场战斗开局清零（battle_setup）、每层 ego_per、封顶 ego_cap。
## - 吃瘪之力（9942 → 状态 2561 受到伤害 ×0.1）：改成 ×chibie。
## - 合体赛亚人（9940 → 状态 2565 终伤 +188%、暴击再 +188%）：fusion／fusion_crit（<0＝不改）。
## - 自在极意功（状态 2775）原版读错变量（1586 不是掷骰的 1590），实际从不免伤；修好等于加强，不动。
## 技能说明里的数字跟着改。ENABLED＝false 回原版；TIER 选档（Kyo 定）。

const ACTOR := 164
const VAR_EGO := 1543
const ST_CHIBIE := 2561
const ST_FUSION := 2565
const ST_EGO := 2777
const CE_EGO := 1722
const SK_FUSION := 9940
const SK_CHIBIE := 9942
const SK_EGO := 10568

const TIERS := {
	"甲": {"ego_per": 0.5, "ego_cap": 10, "ego_reset": true, "chibie": 0.5, "fusion": -1.0, "fusion_crit": -1.0},
	"乙": {"ego_per": 0.3, "ego_cap": 10, "ego_reset": true, "chibie": 0.7, "fusion": 1.0, "fusion_crit": 0.5},
}

static var ENABLED := true
static var TIER := "甲"


static func cfg() -> Dictionary:
	return TIERS.get(TIER, TIERS["甲"]) if ENABLED else {}


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## 每场战斗开局：自我极意功的层数清零（原版是全局变量、从不清零）
static func battle_setup(s) -> void:
	var c := cfg()
	if c.is_empty() or not bool(c.ego_reset) or s == null:
		return
	if int(s.variable(VAR_EGO)) != 0:
		s.set_variable(VAR_EGO, 0)


static func patch_states(t: Array) -> void:
	var c := cfg()
	if c.is_empty():
		return
	_set_literal(t, ST_CHIBIE, 0.1, float(c.chibie))
	_set_literal(t, ST_EGO, 1.5, float(c.ego_per))
	if float(c.fusion) >= 0.0 and ST_FUSION < t.size() and t[ST_FUSION] is Dictionary:
		for e in t[ST_FUSION].get("effects", []):
			for g in e.get("groups", []):
				for st in g.get("steps", []):
					if is_equal_approx(float(st.get("k", 0.0)), 1.88):
						st.k = float(c.fusion_crit) if bool(st.get("criticalOnly", false)) else float(c.fusion)


## 状态效果程序（转换器预编译）里把唯一的那个字面量改掉；找不到或不唯一就报错、不改
static func _set_literal(t: Array, id: int, old: float, new: float) -> void:
	if id >= t.size() or not t[id] is Dictionary:
		return
	var hits := []
	for e in t[id].get("effects", []):
		_find_literal(e.get("program", {}), old, hits)
	if hits.size() != 1:
		push_error("XVegetaTune: 状态 %d 找到 %d 处 %s" % [id, hits.size(), old])
		return
	hits[0].value = new


static func _find_literal(node, old: float, out: Array) -> void:
	if node is Dictionary:
		if str(node.get("op", "")) == "literal" and (node.get("value") is float or node.get("value") is int) and is_equal_approx(float(node.value), old):
			out.append(node)
		for k in node:
			_find_literal(node[k], old, out)
	elif node is Array:
		for x in node:
			_find_literal(x, old, out)


## 公共事件 1722：层数封顶（条件分歧「变量 1543 ≥ 20」）
static func patch_common_events(t: Array) -> void:
	var c := cfg()
	if c.is_empty() or CE_EGO >= t.size() or not t[CE_EGO] is Dictionary:
		return
	for l in t[CE_EGO].get("list", []):
		var p = l.get("parameters", [])
		if int(l.get("code", 0)) == 111 and p.size() >= 5 and int(p[0]) == 1 and int(p[1]) == VAR_EGO and int(p[3]) == 20:
			p[3] = int(c.ego_cap)


## 技能说明（备注里的 <pos=APs text=…> 行与 meta）
static func patch_skills(t: Array) -> void:
	var c := cfg()
	if c.is_empty():
		return
	_desc(t, SK_CHIBIE, "减少90%受到的伤害", "减少%s受到的伤害" % _pct(1.0 - float(c.chibie)))
	_desc(t, SK_EGO, "受到伤害后，增加150%终伤，最多叠加20次", "每场战斗中受到伤害后，增加%s终伤，最多叠加%d次" % [_pct(float(c.ego_per)), int(c.ego_cap)])
	if float(c.fusion) >= 0.0:
		_desc(t, SK_FUSION, "最终伤害+188%", "最终伤害+%s，暴击时再+%s" % [_pct(float(c.fusion)), _pct(float(c.fusion_crit))])


static func _desc(t: Array, id: int, old: String, new: String) -> void:
	if id >= t.size() or not t[id] is Dictionary:
		return
	var r: Dictionary = t[id]
	if not str(r.get("note", "")).contains(old):
		push_error("XVegetaTune: 技能 %d 说明里没有「%s」" % [id, old])
		return
	r.note = str(r.note).replace(old, new)
	var meta = r.get("meta", {})
	if meta is Dictionary:
		for k in meta.keys():
			if meta[k] is String and str(meta[k]).contains(old):
				meta[k] = str(meta[k]).replace(old, new)
