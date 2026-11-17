class_name XTianqiBase
extends RefCounted
## 【cc·T081·未经审查】天启篇基础数值重构期四暗装接线（设计仓库《天启篇_基础数值重构_v0.4》第七节第 2 条、第十节 T012-b）。
## 一个总开关 PHASE4（默认关，T012-c 翻），下面这些只认它（关着＝现在的行为，逐字节不变）：
##
## | 行 | 开着 | 关着 | 接在哪 |
## |---|---|---|---|
## | 角色卡 | 开 | 关（XTianqiSkills.CARDS 只剩测试隔离用） | XTianqiSkills.cards_on |
## | 角色本体 | 读标准线（base_line.json） | 原版职业曲线 | XActor.param_base_direct → param_base |
## | 装备八项 | effective_params（T104 接） | 实例 params | —（本期不接） |
## | K（天启注视） | combat_rules.base_damage × 每人乘数口子 | 1 | XTianqiCombat.dealt_parts |
## | 守层者三张表 | balance_table.guardian_phase4（T012-c 量；缺就退回旧表并警告一次） | 代码里的旧表 | XGuardianRework |
## | 治疗 ×5 | 不乘 | 照乘 | XTianqiNoDiffPassive.confirm_rows（skipTypes 加 3、4） |
## | 绝对值清单 | abs_rescale.json 换算后的数 | 原数 | abs_value（各结算处） |
## | 首领生命临时折算 U | combat_rules.boss_hp_temp_unit | 1 | XTianqiHorsemen |
## | 单段上限、九线爆伤、秘籍格 | skill_rework.rules.single_hit_cap、damage_ledger.phase4 | 现在的键 | XTianqiSkills.formula、XTianqiLedger.apply_nine_cap |
##
## 全部只在代码和表里，不写存档；西游档（XTianqi.active 为假）一律走「关着」那一套。
## 熟练度（XTianqiSkills.MASTERY）照稿单独一个开关，翻开关那张卡（T012-c）和总开关一起改默认值。

const LINE_PATH := "res://modes/xiyou/tianqi_data/base_line.json"
const ABS_PATH := "res://modes/xiyou/tianqi_data/abs_rescale.json"
const STATS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]
## 面板、伤害详情里 K 那一行（D140、D146 已定，照抄；不出现烙印的数）
const GAZE_NAME := "天启注视"
const GAZE_DESC := "全员常驻、无法解除；烙印越深，受此注视的压制越轻。"

## 总开关（暂名，稿第七节第 2 条）。只在代码里改；T012-c 翻成 true。
static var PHASE4 := false

static var _line: Dictionary = {}
static var _abs: Dictionary = {}
static var _abs_index: Dictionary = {}
static var _warned: Dictionary = {}


## 总开关开着、而且是天启篇存档
static func on(s = null) -> bool:
	if not PHASE4:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s)


## 测试用：清缓存
static func clear_cache() -> void:
	_line = {}
	_abs = {}
	_abs_index = {}
	_warned = {}


static func _read(path: String) -> Dictionary:
	if XDataFile.missing(path):  # 发行包里没有（tianqi_data 不发行）
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("XTianqiBase: 读不到 " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("XTianqiBase: JSON 解析失败 " + path)
		return {}
	return parsed


## 同一件事只警告一次（守层者新表缺省等）
static func warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("XTianqiBase: " + msg)


# ---- 角色本体：标准线＋职责模板（稿第四节）----

static func line_data() -> Dictionary:
	if _line.is_empty():
		_line = _read(LINE_PATH)
	return _line


## 标准线：攻击类六项＝A0＋A1×等级；生命再 ×hp_mult，魔法再 ×mp_mult。stat 用 STATS 里的名字
static func line(level: float, stat: String) -> float:
	var l: Dictionary = line_data().get("line", {})
	var v := float(l.get("A0", 20)) + float(l.get("A1", 20)) * level
	if stat == "mhp":
		v *= float(l.get("hp_mult", 25))
	elif stat == "mmp":
		v *= float(l.get("mp_mult", 25))
	return v


## 表里有没有这个人（不开放的 12 人、敌人、表外角色没有：照原版职业曲线）
static func has_actor(actor_id: int) -> bool:
	return line_data().get("actors", {}).has(str(actor_id))


## 这一项的职责×速度档×个人微调
static func actor_mult(actor_id: int, stat: String) -> float:
	var d := line_data()
	var row: Dictionary = d.get("actors", {}).get(str(actor_id), {})
	if row.is_empty():
		return 1.0
	var role: Dictionary = d.get("roles", {}).get(str(row.get("role", "均衡")), {})
	var m := 1.0
	if stat == "mhp":
		m = float(role.get("hp", 1.0))
	elif stat == "def" or stat == "mdf":
		m = float(role.get("def", 1.0))
	elif stat == "agi":
		m = float(d.get("speed", {}).get(str(row.get("speed", "中")), 1.0))
	return m * float(row.get("tweak", {}).get(stat, 1.0))


## XActor.param_base_direct 的替身：开着、表里有这个人时返回标准线本体；否则 NAN（调用方照原版职业曲线）
static func param_base(a, i: int) -> float:
	if i < 0 or i >= STATS.size() or not a is XActor or not on():
		return NAN
	var id := int((a as XActor).actor_id)
	if not has_actor(id):
		return NAN
	return floorf(line(float((a as XActor).level), STATS[i]) * actor_mult(id, STATS[i]))


# ---- K：天启注视（稿第三节第 2、10 条）----

## 表里的 K（combat_rules.base_damage）；关着 1
static func k_base(s = null) -> float:
	if not on(s):
		return 1.0
	return float(XTianqiBalance.data().get("combat_rules", {}).get("base_damage", 1.0))


## 按角色取的乘数口子（D139：和烙印联动，T073-b 接进来）。现在恒 1
static func k_actor_mult(_a) -> float:
	return 1.0


## 这个角色打出伤害要乘的 K（dealt_parts 用；关着 1）
static func k_for(a, s = null) -> float:
	if not on(s):
		return 1.0
	return k_base(s) * k_actor_mult(a)


## 面板一行：[名字, 「伤害 ×K」]；关着为空。只显示表里的 K 本身（不含烙印口子）
static func gaze_row(s = null) -> Array:
	if not on(s):
		return []
	return [GAZE_NAME, "伤害 ×" + _k_text(k_base(s))]


static func _k_text(k: float) -> String:
	var t := "%.3f" % k
	while t.ends_with("0") and not t.ends_with(".0"):
		t = t.substr(0, t.length() - 1)
	return t


# ---- 首领生命临时折算 U（稿第三节第 7 条（2）、D137）----

## crit_immune：这个首领免不免暴击（免暴击的读 no_crit）。关着 1
static func boss_hp_unit(crit_immune := false, s = null) -> float:
	if not on(s):
		return 1.0
	var u = XTianqiBalance.data().get("combat_rules", {}).get("boss_hp_temp_unit", {})
	if not u is Dictionary:
		return 1.0
	return float(u.get("no_crit" if crit_immune else "crit", 1.0))


# ---- 守层者三张表（稿第七节第 2 条；新表 T012-c 实机量）----

## name：atk_scale／hp_base／resist。开着而且 balance_table.guardian_phase4 有这张表：返回 {层: 数}；否则返回 old（开着却缺表时警告一次）
static func guardian_table(name: String, old: Dictionary) -> Dictionary:
	if not on():
		return old
	var g = XTianqiBalance.data().get("guardian_phase4", {})
	var t = g.get(name) if g is Dictionary else null
	if not t is Dictionary or t.is_empty():
		warn_once("guardian:" + name, "总开关开着，但 balance_table.guardian_phase4.%s 还没有（T012-c 实机量），退回旧表" % name)
		return old
	var out := {}
	for k in t:
		if str(k).is_valid_int():
			out[int(k)] = float(t[k])
	return out


# ---- 治疗 ×5（稿第七节第 2 条）----

## 难度被动等价行（XTianqiNoDiffPassive.confirm_rows）要多跳过的伤害类型：开着时 HP、MP 回复（3、4）不再 ×5
static func heal_skip_types() -> Array:
	return [3, 4] if on() else []


# ---- 单段有效系数上限（skill_rework.rules.single_hit_cap，按名单档位）----

## 这个角色单段有效系数（卡面系数×条件）的上限；关着、敌人、没档位为 0（不封）
static func single_hit_cap(a) -> float:
	if not a is XActor or not on():
		return 0.0
	var caps = XTianqiSkills.data().get("rules", {}).get("single_hit_cap", {})
	if not caps is Dictionary:
		return 0.0
	var tier := XTianqiSkills.tier_of(a)
	if tier == "":
		tier = XTier.WEAK
	return float(caps.get(tier, 0.0))


# ---- 九线爆伤封顶、秘籍格（damage_ledger.phase4）----

static func ledger_phase4() -> Dictionary:
	var p = XTianqiLedger.data().get("phase4", {})
	return p if p is Dictionary else {}


## 九线爆伤合计封顶；关着 −1（不封，现在 nine_caps 没有这一项）
static func nine_crit_cap() -> float:
	if not on():
		return -1.0
	return float(ledger_phase4().get("nine_crit_dmg_cap", -1.0))


## 秘籍每格：开着读 phase4.secret_slot，关着返回 old（nine_caps.secret_slot）
static func secret_slot(old: float) -> float:
	if not on():
		return old
	return float(ledger_phase4().get("secret_slot", old))


# ---- 绝对值清单（abs_rescale.json，稿第七节第 4 条）----

static func abs_data() -> Dictionary:
	if _abs.is_empty():
		_abs = _read(ABS_PATH)
		_abs_index = {}
		for e in _abs.get("entries", []):
			if e is Dictionary:
				var eid = e.get("id", "")
				_abs_index[str(e.get("kind", "")) + ":" + (str(int(eid)) if eid is float else str(eid))] = e  # JSON 数字读成浮点，str(1.0) 是 "1.0"
	return _abs


## 这一条有没有结构化的换算（new＝{pct_of, pct}）。T080 表里只有药品（item_fixed_heal）和纯数字的状态持续伤害（state_dot）是结构化的；
## 其余几类 new 还是文字说明（待逐条定写法），本期不接，交付单列着
static func abs_entry(kind: String, id: int) -> Dictionary:
	abs_data()
	var e = _abs_index.get(kind + ":" + str(id))
	if not e is Dictionary or not e.get("new") is Dictionary:
		return {}
	return e


## 一条绝对值换算：开着、表里有这一行时返回 ⌊对象(pct_of 那一项上限) × pct%⌋（保留原数的正负）；关着或没有这一行返回 old。
## target：按谁的上限算（药品＝用在谁身上，持续伤害＝持有者）
static func abs_value(kind: String, id: int, old: float, target) -> float:
	if old == 0.0 or target == null or not on():
		return old
	var e := abs_entry(kind, id)
	if e.is_empty():
		return old
	var n: Dictionary = e.new
	var cap := float(target.mmp) if str(n.get("pct_of", "mhp")) == "mmp" else float(target.mhp)
	var v := floorf(cap * float(n.get("pct", 0.0)) / 100.0)
	return -v if old < 0.0 else v


# ---- 一致性（稿第七节第 2 条：上表任何一行和总开关不一致就失败）----

## 每一行现在的状态（开着＝读期四那一套）。专项断言：PHASE4 开、关两种情形下每一行都等于 on()
static func rows_state() -> Dictionary:
	var o := on()
	return {
		"cards": XTianqiSkills.cards_on(),
		"base": o and has_actor(1),
		"k": k_base() != 1.0 or o,
		"guardian": o,
		"heal_x5_off": not heal_skip_types().is_empty(),
		"abs": o,
		"boss_u": o,
		"phase4_ledger": nine_crit_cap() >= 0.0,
	}
