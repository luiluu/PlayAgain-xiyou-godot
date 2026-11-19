class_name XTianqiBase
extends RefCounted
## 【cc·T081·未经审查】天启篇基础数值重构期四暗装接线（设计仓库《天启篇_基础数值重构_v0.4》第七节第 2 条、第十节 T012-b）。
## 一个总开关 PHASE4（默认关，T012-c 翻），下面这些只认它（关着＝现在的行为，逐字节不变）：
##
## | 行 | 开着 | 关着 | 接在哪 |
## |---|---|---|---|
## | 角色卡 | 开 | 关（XTianqiSkills.CARDS 只剩测试隔离用） | XTianqiSkills.cards_on |
## | 角色本体 | 读标准线（base_line.json） | 原版职业曲线 | XActor.param_base_direct → param_base |
## | 原版境界被动 | 数值标签全拦（REALM_OFF；圣者境界／雷劫淬炼／半步圣人 8 个号） | 照原版 | XDB.rec → realm_rec |
## | 职业属性倍率 | 不算（职业特性 21：惠惠魔攻 ×3、蕾姆生命 ×2.5 等；CLASS_RATE_OFF） | 照算 | XActor.param_rate → class_rate_strip |
## | 装备八项 | gear_base.json 新底子＋换算后的词缀、镶嵌、宝珠 | 实例 params | XTianqiGear.effective_params（T104；读八项的地方都走它，清单在交付单） |
## | K（天启注视） | combat_rules.base_damage × 每人乘数口子 | 1 | XTianqiCombat.dealt_parts |
## | 守层者三张表 | balance_table.guardian_phase4（T012-c 量；缺就退回旧表并警告一次） | 代码里的旧表 | XGuardianRework |
## | 治疗 ×5 | 不乘 | 照乘 | XTianqiNoDiffPassive.confirm_rows（skipTypesAny 放 3、4，不论目标；T214） |
## | 绝对值清单 | abs_rescale.json 换算后的数 | 原数 | abs_value（各结算处） |
## | 状态 <G_ShuXing> 固定加减（T228，ABS_SHUXING 可单独关） | 持有者该项 × abs_rescale.json state_shuxing 的整数 % | 原数 | XBattler.param_state → shuxing_value |
## | 技能固定回复、固定吸取的底数（T243，ABS_SKILL 可单独关） | 对象生命／魔法上限 × abs_rescale.json skill_fixed_heal／skill_fixed_drain 的整数 %（只换底数，a.mat×N 等照旧） | 原公式 | XFormulaExecution.run_item → skill_formula |
## | 首领生命临时折算 U（整数百分比） | combat_rules.boss_hp_temp_unit | 100 | XTianqiHorsemen |
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

## 总开关（暂名，稿第七节第 2 条）。只在代码里改；T220（T012-c）翻成 true，false＝回退到期四前。
static var PHASE4 := true
## 【cc·T082】职业上的属性倍率（特性 21）在期四里不算：本体已经是「标准线×职责模板」，职业曲线不读（稿第四节），
## 职业特性里的倍率是同一份差异的另一半（惠惠魔攻 ×3、蕾姆生命 ×2.5、绯红蔷薇双攻 ×2、钟离生命 ×1.5、西西卡双攻 ×1.2、病娇幸运 ×5、嫦娥魔法 ×5）。
## 角色卡都没写保留它们；T082 第 1 步量出惠惠强者 585 万＞超强者，查出是这一条。false＝照算（回退）
static var CLASS_RATE_OFF := true
## 【cc·T082】原版通用境界被动（圣者境界 5707/5778/8083/9976、雷劫淬炼 5714/9982、半步圣人 5777/10018，22 人 81 级会学）不在角色卡里，
## 期四开着时数值标签按角色卡同一张 note_remove 表全拦（协调 11-17 同意：Kyo 已定天启篇境界整套重做、原版这几招不沿用、不参与标定）。
## T082 量 K：拳一 163 靠 9976＋10018 爆伤 +200%、终伤 +200%，峰值是第二名超强者的 5 倍。false＝照原版（回退）
static var REALM_OFF := true
## T163（D189，Kyo 11-18）：标定后逐个调角色的覆盖层（skill_rework.json、base_line.json 的 tune.D189）；false＋XTianqiSkills.reload_table() 照覆盖前
static var TUNE_D189 := true
## T191（D200 A，Kyo 11-18）：原卡小数系数全表取整的覆盖层（skill_rework.json 的 tune.D200，叠在 D189 之后）；false＋XTianqiSkills.reload_table() 照取整前
static var TUNE_D200 := true
## T192（D198 A，Kyo 11-18）：偏弱超强者 9 人往上调的覆盖层（skill_rework.json 的 tune.D198，叠在 D200 之后；含 cap_hits）；false＋XTianqiSkills.reload_table() 照调前
static var TUNE_D198 := true
## T204（D208 A，Kyo 11-18）：宿傩终式按段打、每段不超单段上限的覆盖层（skill_rework.json 的 tune.D208，叠在 D198 之后；10245 的 terminal_hits）；false＋XTianqiSkills.reload_table() 照一段
static var TUNE_D208 := true
## T204＋T209（D209 ABA，Kyo 11-18）：超强者按 Kyo 名次重排的覆盖层（skill_rework.json 的 tune.D209，叠在 D208 之后；可往下调）；false＋XTianqiSkills.reload_table() 照 D208
static var TUNE_D209 := true
## T228（协调 11-19 定 A）：状态备注 <G_ShuXing> 写死的八项加减换成「持有者自身该项的整数百分比」（abs_rescale.json 的 state_shuxing 行）。
## 只在总开关开着时生效；false＝照原数加减（回退）。原版量级的 ±500～±30000 在期四本体（81 级攻击约 3766，原量级主攻中位 1854）上的分量对不上
static var ABS_SHUXING := true
## T242（D226 甲，Kyo 11-19）：备注数字本来就是作者写的百分比的五个状态（1079 敏捷−25%、1080 敏捷−35%、1086 生命−30%、1664 六项−30%、2719 攻击+200% 其余+30%），
## 表里标 new.note_pct＝true、pct 直接取原数，按持有者自身该项的百分比生效。false＝这五个照原数当固定数加减（回退，只影响这五个）；总开关、ABS_SHUXING 关着时本开关不起作用
static var SHUXING_NOTE_PCT := true
## T243：技能公式里写死的固定回复底数（skill_fixed_heal，如「200 + a.mat」的 200、屏障术 1301 的 3000000）和固定吸取量（skill_fixed_drain）
## 换成「对象该项上限的整数百分比」（abs_rescale.json）。只在总开关开着、天启篇存档时生效；false＝照原公式（回退）
static var ABS_SKILL := true
## T243 R1：敌人给敌人（含自疗）的技能固定回复，换算后的百分比统一封顶（整数 %，100＝不封顶，表里各行 pct 照旧可改）。
## T247（D229 乙）：定为 100＝不封顶；16 招敌人自疗的表值已按原版占比填好（占比＝原数÷用这招的首领原版生命上限的中位数）。0＝敌人自疗的底数不回，可作回退
static var ENEMY_HEAL_CAP := 100
const REALM_IDS := [5707, 5714, 5777, 5778, 8083, 9976, 9982, 10018]
const REALM_NOTE_REMOVE := ["passivePBST\\d", "passiveXPBST\\d", "passiveELUP\\d+", "passiveEWPN\\d+", "passiveHarmRi", "passiveCrHarmRi", "passiveHarmRe\\d+",
	"SkillPass\\d+", "passiveAPLUS", "AgainUseAll", "passiveIRUP", "passiveGRUP", "passiveSPBST\\d", "ConsumeReduce\\w+", "passiveEXTTP", "DepassiveHarmRe\\d+",
	"Element Amplify \\d+", "StartPushState\\d+", "StartWTPushState\\d+", "StartAEPushState\\d+", "RecPushState\\d+", "PushState\\d+", "passiveELEM\\d+", "SkETypeHarmRi\\d+"]
static var _realm_recs := {}

static var _line: Dictionary = {}
static var _abs: Dictionary = {}
static var _abs_index: Dictionary = {}
static var _shuxing_ref: Array = []
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
	_shuxing_ref = []
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
	var tw := float(row.get("tweak", {}).get(stat, 1.0))
	if TUNE_D189:  # T163（D189）：逐个调角色的本体成长（base_line.json 的 tune.D189.actors.<id>.tweak），回退同 XTianqiBase.TUNE_D189
		tw = float(d.get("tune", {}).get("D189", {}).get("actors", {}).get(str(actor_id), {}).get("tweak", {}).get(stat, tw))
	return m * tw


## XActor.param_base_direct 的替身：开着、表里有这个人时返回标准线本体；否则 NAN（调用方照原版职业曲线）
static func param_base(a, i: int) -> float:
	if i < 0 or i >= STATS.size() or not a is XActor or not on():
		return NAN
	var id := int((a as XActor).actor_id)
	if not has_actor(id):
		return NAN
	return floorf(line(float((a as XActor).level), STATS[i]) * actor_mult(id, STATS[i]))


## XActor.param_rate 里不含套装的特性倍率 base（加算：1＋Σ(v−1)）扣掉职业那几条的 (v−1)；关着、西游档原样返回
static func class_rate_strip(a, i: int, base: float) -> float:
	if not CLASS_RATE_OFF or not a is XActor or not on() or not has_actor(int((a as XActor).actor_id)):
		return base
	var cut := 0.0
	for t in ((a as XActor).class_data().get("traits", []) as Array):
		if int(t.get("code", 0)) == XBattler.TRAIT_PARAM and int(t.get("dataId", -1)) == i:
			cut += float(t.get("value", 1.0)) - 1.0
	return maxf(0.0, base - cut) if cut != 0.0 else base


## XDB.rec 的 Skills 分支：这个号要不要换成拦掉数值的境界被动
static func realm_touches(id: int) -> bool:
	return REALM_OFF and REALM_IDS.has(id) and on()


static func realm_rec(id: int, base: Dictionary) -> Dictionary:
	var hit = _realm_recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var r: Dictionary = base.duplicate(true)
	var note := XTianqiSkills._note_edit(str(r.get("note", "")), {"note_remove": REALM_NOTE_REMOVE})
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	r.description = "通用境界被动：天启篇里暂不生效（境界整套重做）。"
	_realm_recs[id] = [base, r]
	return r


# ---- K：天启注视（稿第三节第 2、10 条）----

## 表里的 K（combat_rules.base_damage）；关着 1
static func k_base(s = null) -> float:
	if not on(s):
		return 1.0
	return float(XTianqiBalance.data().get("combat_rules", {}).get("base_damage", 1.0))


## 按角色取的乘数口子（D139：和烙印联动）：烙印的伤害乘数 XTianqiBrand.mult（T073-b；烙印开关关着、西游档恒 1）
static func k_actor_mult(a, s = null) -> float:
	return XTianqiBrand.mult(a, s)


## 这个角色打出伤害要乘的 K × 烙印（dealt_parts、scale_direct 用）。总开关关着 K 按 1，烙印开关各管各的；两个都关着恒 1
static func k_for(a, s = null) -> float:
	if not on(s) and not XTianqiBrand.on(s):
		return 1.0
	return k_base(s) * k_actor_mult(a, s)


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

## 整数百分比（D222 丙、附则 E）：100＝不打折，6＝6%。M5 实机标定骑士血量后删掉这一节。crit_immune：这个首领免不免暴击（免暴击的读 no_crit）。关着 100
static func boss_hp_unit(crit_immune := false, s = null) -> int:
	if not on(s):
		return 100
	var u = XTianqiBalance.data().get("combat_rules", {}).get("boss_hp_temp_unit", {})
	if not u is Dictionary:
		return 100
	return int(u.get("no_crit" if crit_immune else "crit", 100))


## 血量 × U ÷ 100，向零取整（整数运算）
static func apply_hp_unit(hp: float, u: int) -> float:
	if u == 100:
		return hp
	return float(int(hp) * u / 100)


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


## T214（O-589）：上面这两类放进合成行的 skipTypesAny——不管目标是谁都跳过。原来并进 skipTypes，
## 而 XStateEffects._active 认 skipTypes 只在目标是敌人时跳过，治疗打的是自己人，期四开着我方回复照样 ×5（T204 谷雨 85042→425210）。
## false＝照原来并进 skipTypes（回退：我方回复照乘 ×5）
static var HEAL_SKIP_ALLY := true


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
				var key := str(e.get("kind", "")) + ":" + (str(int(eid)) if eid is float else str(eid))  # JSON 数字读成浮点，str(1.0) 是 "1.0"
				var st := str(e.get("stat", "")) if e.get("stat") != null else ""
				_abs_index[key + (":" + st if st != "" else "")] = e  # 双回复药（28、51、140…）同一个 id 有 mhp、mmp 两行，按 stat 分开，不互相覆盖
	return _abs


## 这一条有没有结构化的换算（new 是字典）。结构化的类：药品 item_fixed_heal、纯数字状态持续伤害 state_dot（T081）、状态 <G_ShuXing> state_shuxing（T228）、
## 技能固定回复／吸取 skill_fixed_heal／skill_fixed_drain（T243）；公式型 state_dot、state_shield、note_* 还是文字说明，这里返回空
## stat：这一行管的是哪项（药品 mhp／mmp，对应效果 11／12）；表里不分 stat 的类别传空
static func abs_entry(kind: String, id: int, stat := "") -> Dictionary:
	abs_data()
	var e = _abs_index.get(kind + ":" + str(id) + (":" + stat if stat != "" else ""))
	if not e is Dictionary or not e.get("new") is Dictionary:
		return {}
	return e


## 一条绝对值换算：开着、表里有这一行时返回 ⌊对象(pct_of 那一项上限) × pct%⌋（保留原数的正负）；关着或没有这一行返回 old。
## target：按谁的上限算（药品＝用在谁身上，持续伤害＝持有者）
static func abs_value(kind: String, id: int, old: float, target, stat := "") -> float:
	if old == 0.0 or target == null or not on():
		return old
	var e := abs_entry(kind, id, stat)
	if e.is_empty():
		return old
	var n: Dictionary = e.new
	var cap := float(target.mmp) if str(n.get("pct_of", "mhp")) == "mmp" else float(target.mhp)
	var v := floorf(cap * float(n.get("pct", 0.0)) / 100.0)
	return -v if old < 0.0 else v


## T243：技能公式算完（XFormulaExecution.run_item，带正负：回复为负）以后，把表里那一行的固定底数 new.base 换成 ⌊对象 new.pct_of 上限 × new.pct%⌋，
## 公式其余部分（a.mat×N、v[364] 等）照旧：|值| − base + 新底数，不低于 0，正负照伤害类型（3、4 回复为负）。
## 只认技能（有 stypeId；物品同号不算）；mode＝raw 的行、表里没有的技能照原值。公式被改写、跟表里 orig 对不上（天启篇技能卡等）的照原值并警告一次。
## a：出手的人（敌人给敌人回复时套 ENEMY_HEAL_CAP）；b：公式里的 b（回复＝被治疗的人，吸取＝被吸的人）
static func skill_formula(item: Dictionary, a, b, value: float) -> float:
	if not ABS_SKILL or b == null or is_nan(value) or not on():
		return value
	var nb := skill_abs_part(item, a, b)
	if nb < 0.0:
		return value
	var dmg: Dictionary = item.get("damage", {})
	var mag := maxf(0.0, absf(value) - float(_skill_entry(item).new.base) + nb)
	return -mag if int(dmg.get("type", 0)) in [3, 4] else mag


## T243：这条技能换上去的新底数 ⌊对象上限 × pct%⌋（正数）；不换（开关关、西游档、raw、对不上 orig、不是技能）返回 -1。
## XDamage._healing 用它把「新底数」从「原公式剩余项」里分出来：新底数已按对象生命上限（含 1/6、守层者 k）算，不能再乘 XTianqiNoX6.enemy_heal（R1 P1-1）
static func skill_abs_part(item: Dictionary, a, b) -> float:
	if not ABS_SKILL or b == null or not on():
		return -1.0
	var e := _skill_entry(item)
	if e.is_empty():
		return -1.0
	var pct := float(e.new.get("pct", 0))
	if str(e.kind) == "skill_fixed_heal" and a is XEnemy and b is XEnemy:
		pct = minf(pct, float(ENEMY_HEAL_CAP))
	var cap := float(b.mmp) if str(e.new.get("pct_of", "mhp")) == "mmp" else float(b.mhp)
	return floorf(cap * pct / 100.0)


## 表里这条技能的换算行（结构化、不是 raw、公式对得上 orig）；不是就返回空
static func _skill_entry(item: Dictionary) -> Dictionary:
	if not item.has("stypeId"):
		return {}
	var id := int(item.get("id", 0))
	var e := abs_entry("skill_fixed_heal", id)
	if e.is_empty():
		e = abs_entry("skill_fixed_drain", id)
	if e.is_empty() or str(e.new.get("mode", "")) == "raw" or not e.new.has("base"):
		return {}
	var dmg: Dictionary = item.get("damage", {})
	var f := str(dmg.get("formulaGd", ""))
	if f == "":
		f = str(dmg.get("formula", ""))  # R1 P3-2：同生成脚本 formulaGd or formula
	if f != str(e.get("orig", "")):
		warn_once("skill:%d" % id, "技能 %d 的公式跟 abs_rescale.json 对不上（天启篇改写过？），照原公式" % id)
		return {}
	return e


## T228：<G_ShuXing> 换算开着没有（总开关开、ABS_SHUXING 开、天启篇存档）。param_state 每次先问一次，关着整段不碰表
static func shuxing_on() -> bool:
	return ABS_SHUXING and on()


## T228：一个状态在第 i 项上的 <G_ShuXing> 加减（连层数）。raw＝备注原数（一层）；pre＝持有者这一项在加状态固定值之前的数（(基础＋加值)×比率×强化率）；
## ceng＝层数（_stateCounter，没有按 1）。返回 pre × pct% × 层数，最后向零取整一次（R1 P2-1：不先取单层再乘层数）。
## pct 读 abs_rescale.json 的 state_shuxing 行；new.mode＝raw 的计数器状态（R1 P1-1：<G_ShuXing> 写 ±1 当单位，真加值在层数里）照 raw × 层数。
## 备注被天启篇改写、原数跟表里 orig 对不上（或表里没这行）的，按参考值现算（同生成脚本口径）并警告一次；参考值缺（发行包没有 tianqi_data）就照原数
## 关着（发行包、西游档、开关关）原样返回 raw（一层）：param_state 关着不调这里，自己乘层数
static func shuxing_value(state_id: int, i: int, raw: float, pre: float, ceng := 1.0) -> float:
	if raw == 0.0 or not shuxing_on():
		return raw
	if i < 0 or i >= 8:
		return raw * ceng
	var pct := 0.0
	var e := abs_entry("state_shuxing", state_id)
	if not e.is_empty() and str(e.new.get("mode", "")) == "raw":
		return raw * ceng
	if not e.is_empty() and e.new.get("note_pct", false) and not SHUXING_NOTE_PCT:
		return raw * ceng  # T242 回退：备注百分比的五个状态当固定数
	var orig = e.get("orig") if not e.is_empty() else null
	var pa = e.new.get("pct") if not e.is_empty() else null
	if orig is Array and orig.size() == 8 and pa is Array and pa.size() == 8 and float(orig[i]) == raw:
		pct = float(pa[i])
	else:
		var ref := shuxing_ref()
		if ref.size() != 8 or float(ref[i]) <= 0.0:
			return raw * ceng
		var q := floorf(absf(raw) / float(ref[i]) * 100.0 + 0.5)
		pct = maxf(1.0, q) * signf(raw)
		warn_once("shuxing:%d" % state_id, "状态 %d 的 <G_ShuXing> 原数跟 abs_rescale.json 对不上（天启篇改写过？），按参考值现算 %d%%" % [state_id, int(pct)])
	if pre <= 0.0:
		return 0.0
	var x := pre * pct * ceng / 100.0  # T228 复核 P3-3：先乘后除（29×1%×100 不再因 0.29×100 差一点取成 28）
	return signf(x) * floorf(absf(x))


## 参考值八格（base.shuxing_ref，按 STATS 顺序）
static func shuxing_ref() -> Array:
	if _shuxing_ref.is_empty():
		var r = abs_data().get("base", {}).get("shuxing_ref", {})
		if r is Dictionary and not r.is_empty():
			_shuxing_ref = STATS.map(func(k): return float(r.get(k, 0.0)))
	return _shuxing_ref


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
		"gear": XTianqiGear.applies({"kind": "weapon", "etypeId": 1, "meta": {"req_level": "1", "quality": "1"}}),
		"shuxing": shuxing_on(),  # T228 R1 P3-2
	}
