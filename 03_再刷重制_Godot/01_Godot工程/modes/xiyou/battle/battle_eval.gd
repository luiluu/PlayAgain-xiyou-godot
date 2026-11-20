class_name XBattleEval
extends RefCounted
## 敌我共用的只读估值内核（T282，Neon 评估卡 2「统一预览引擎＋同源估值底座」）。
## 我方 XSmartAI（策略壳：角色档案、背包、异化投影、魔炮、铺垫）和将来的敌方 AI（T277：六维只调 opts 与温度，不进本类）都从这里取：
## - 统一估伤：XDamage.calculate(..., preview) → XDamage.finish(execute=false)，跟正式结算同一条乘区链
##   （技能重构公式、元素牌组弱点／耐性／免疫／高阶、伤害加成总账五池与九线封顶、统一防御率、天启档位、烙印破防 ×1.3、弱者词条、七印器印、防御减半）；
##   公式本身的值（rawValue）由调用方给（我方走角色档案的受控估算），缺省走 raw_value（随机固定 0.5 的只读求值，不安全的写法 0）。
## - 打分零件：威胁度 threat、伤害效用 damage_utility、护盾 shield_points、急需度 recovery_score、增减益 benefit、目标列表 targets、
##   通用一招打分 score_skill（敌方 AI 直接用；我方 XSmartAI 有自己的、与原版插件对齐的 score_candidate，只借零件）。
## 全程只读：不改 HP／MP／TP／状态／护盾／账本／印记，不抽战斗随机流也不抽全局 randf（专项 xiyou_tianqi_smart_ai_eval 逐项比指纹）。
## 不读六维（D234）：阵营差别只在调用方传的 allies／foes 与 opts。

## opts 约定（缺省全开＝我方口径）：
##   check_weakness  元素弱点／耐性／免疫算进估伤（关＝元素按 1 估，给低战商敌人用）
##   check_kill      能击杀加分
##   check_shield    剩余血量算上护盾（原生＋来源账本）
##   ally_weight     对友方的治疗／护盾／增益分的倍率（配合）
##   raw             Callable(a, t, rec) -> float：公式本身的值（调用方的受控估算）；不给走 raw_value
const DEFAULT_OPTS := {"check_weakness": true, "check_kill": true, "check_shield": true, "ally_weight": 1.0}

var logic: XBattleLogic
var user: XBattler
var allies: Array
var foes: Array
var opts: Dictionary
## 缓存的附加键（我方铺垫后的视图序号：同一个人换了视图，能力值和状态都变了，缓存各记各的）
var view := 0
var _hit_cache := {}
var _vars = null
## 缓存命中统计（性能基准看：一次选招算了几次结算链、命中几次）
static var stat_calls := 0
static var stat_hits := 0


## 变量表（logic.vars() 每次现拼 5000 格）：一次估值里不变，只拼一次
func vars() -> Array:
	if _vars == null:
		_vars = logic.vars()
	return _vars


## allies／foes：从 user 这一方看的友方（含已阵亡，复活要用）与敌方（存活）
func _init(l: XBattleLogic, u: XBattler, a: Array, f: Array, o := {}) -> void:
	logic = l
	user = u
	allies = a
	foes = f
	opts = DEFAULT_OPTS.duplicate()
	opts.merge(o, true)


## 我方：create_for(logic, actor)；敌方：create_for(logic, enemy)
static func create_for(l: XBattleLogic, u: XBattler, o := {}) -> XBattleEval:
	var mine := u is XActor
	var a: Array = l.actors if mine else l.enemies
	var f: Array = l.alive(l.enemies) if mine else l.alive(l.actors)
	return XBattleEval.new(l, u, a, f, o)


# ---- 技能范围（RPG Maker scope）----
static func is_item(rec: Dictionary) -> bool:
	return rec.has("itypeId")


static func scope_of(rec: Dictionary) -> int:
	return int(rec.get("scope", 0))


static func for_opponent(rec: Dictionary) -> bool:
	return scope_of(rec) in [1, 2, 3, 4, 5, 6]


static func for_friend(rec: Dictionary) -> bool:
	return scope_of(rec) in [7, 8, 9, 10, 11]


static func for_user(rec: Dictionary) -> bool:
	return scope_of(rec) == 11


static func for_dead_friend(rec: Dictionary) -> bool:
	return scope_of(rec) in [9, 10]


static func for_all(rec: Dictionary) -> bool:
	return scope_of(rec) in [2, 8, 10]


static func for_random(rec: Dictionary) -> bool:
	return scope_of(rec) in [3, 4, 5, 6]


static func num_targets(rec: Dictionary) -> int:
	return scope_of(rec) - 2 if for_random(rec) else 0


## 这招能落到谁身上（从 user 这一方看）；嘲讽／挑衅预过滤留给卡 3
func targets(rec: Dictionary) -> Array:
	if for_opponent(rec):
		return foes
	if for_user(rec):
		return [user]
	return allies.filter(func(t): return t.is_dead() if for_dead_friend(rec) else t.is_alive())


# ---- 状态判断（热循环里调，正则预编译：T281 核查 P3-3）----
static var _buff_tag_re := RegEx.create_from_string("(?i)<BuffType\\s*:\\s*([^>]+)>")
static var _harm_tag_re := RegEx.create_from_string("(?i)(减益|异常|削弱|debuff|诅咒|毒|破甲|封印|眩晕)")
static var _good_tag_re := RegEx.create_from_string("(?i)(增益|强化|buff)")
static var _harm_name_re := RegEx.create_from_string("(中毒|诅咒|流血|灼伤|眩晕|沉默|封印|虚弱|破甲|麻痹|失明)")


static func harmful_state(id: int) -> bool:
	var st := XDB.rec("States", id)
	if st.is_empty():
		return false
	var tag := _buff_tag_re.search(str(st.get("note", "")))
	if tag and _harm_tag_re.search(tag.get_string(1)):
		return true
	if tag and _good_tag_re.search(tag.get_string(1)):
		return false
	if int(st.get("restriction", 0)) > 0:
		return true
	for t in st.get("traits", []):
		if (int(t.code) == 21 and float(t.value) < 1.0) or (int(t.code) == 22 and float(t.value) < 0.0):
			return true
	return _harm_name_re.search(str(st.get("name", ""))) != null


static var _boss_ids := {}
static var _boss_key_re := RegEx.create_from_string("^boss-\\d+$")


static func is_boss(e: XBattler) -> bool:
	if not e is XEnemy:
		return false
	if _boss_ids.is_empty():
		var p := XDB.plugin("MOG_BossHP")
		for k in p:
			if _boss_key_re.search(str(k)) and str(p[k]).is_valid_int() and int(p[k]) > 0:
				_boss_ids[int(p[k])] = true
		_boss_ids[-1] = true
	var meta: Dictionary = e.data().get("meta", {})
	return _boss_ids.has(int(e.data().get("id", 0))) or meta.has("boss") or meta.has("Boss")


## 护盾量：原生护盾；ledger 开时再加来源护盾账本（谷雨、屠苏、璇等）
static func shield_points(t: XBattler, ledger: bool) -> float:
	return maxf(0.0, t.shield) + (XShieldLedger.amount(t) if ledger else 0.0)


# ---- 统一估伤（XDamage 预览）----
const _UNSAFE_SUBS := ["user\\.skillMasteryLevel\\(item\\.id\\)", "(?:a|b|user|target)\\.isStateAffected\\(\\d+\\)",
	"(?:a|b|user|target)\\.hpRate\\(\\)", "(?:a|b|user|target)\\.(?:mhp|mmp|hp|mp|tp|atk|def|mat|mdf|agi|luk|level|hit|cri)\\b",
	"v\\[\\d+\\]", "Math\\.(?:floor|ceil|round|max|min|abs|pow|sqrt)\\b"]
static var _safe_subs: Array = []
static var _safe_plain_re := RegEx.create_from_string("^[\\d\\s.+*/()%\\-,?:<>=!&|]+$")
static var _safe_assign_re := RegEx.create_from_string("(?:^|[^=!<>])=(?!=)|\\+\\+|--")
static var _safe_cache := {}


## Codex_SmartBattleAI 只让「安全的」算式参与估算：替换已知只读写法后只剩算术就算，否则 0
static func formula_safe(formula: String) -> bool:
	if _safe_cache.has(formula):
		return _safe_cache[formula]
	if _safe_subs.is_empty():
		for p in _UNSAFE_SUBS:
			_safe_subs.append(RegEx.create_from_string(p))
	var s := formula.replace("Math.random()", "0.5")
	for re in _safe_subs:
		s = (re as RegEx).sub(s, "1", true)
	var ok := _safe_plain_re.search(s) != null and _safe_assign_re.search(s) == null
	_safe_cache[formula] = ok
	return ok


## 天启篇重构技（技能重构模块、五条悟茈）
static func tq_module(rec: Dictionary) -> bool:
	var program: Dictionary = rec.get("damage", {}).get("formulaProgram", {})
	return str(program.get("status", "")) == "module" and str(program.get("module", "")) in [XTianqiSkills.MODULE, "gojo"]


## 公式只读求值：randf 固定 0.5（不抽实战随机数）；五条悟茈读当前对数（XGojo.ai_preview，只读）
func formula_preview(a: XBattler, t: XBattler, rec: Dictionary) -> float:
	var dmg: Dictionary = rec.get("damage", {})
	var preview := rec.duplicate()
	preview.damage = dmg.duplicate()
	if dmg.get("formulaGd") is String:
		preview.damage.formulaGd = dmg.formulaGd.replace("randf()", "0.5")
	XGojo.ai_preview = tq_module(rec) and XTianqiSkills.cards_on()
	var value := XDamage.eval_formula(preview, a, t, vars())
	XGojo.ai_preview = false
	return value


## 缺省的公式值：重构技和「安全的」算式只读求值，其余 0（不认识的写法不猜）
func raw_value(a: XBattler, t: XBattler, rec: Dictionary) -> float:
	if tq_module(rec) or formula_safe(str(rec.get("damage", {}).get("formula", "0"))):
		return formula_preview(a, t, rec)
	return 0.0


## 一段的结算值（正＝伤害，负＝回复／吸收），同正式 _damage_value 的 calculate → finish 链（XDamage.preview_detail），但 preview、不浮动、不执行：
## Confirm／固定减伤／React 都只算不写；不传 random（混沌元素取第一档、不掷骰）；伤害加成总账守卫静音（选招试算不是真出手）。
## raw：公式本身的值（带符号，治疗为负）。返回 {value, criticalIf（暴击倍率）, tianqiKind（元素判定）}
func hit_detail(a: XBattler, t: XBattler, rec: Dictionary, raw: float) -> Dictionary:
	var key := "%d|%d|%d|%f|%f|%f|%f|%f|%d" % [a.get_instance_id(), t.get_instance_id(), int(rec.get("id", 0)), raw, a.hp, a.mp, a.tp, t.hp, view]
	if _hit_cache.has(key):
		stat_hits += 1
		return _hit_cache[key]
	stat_calls += 1
	var o := {"critical": false, "vars": vars(), "rawValue": raw, "battleRound": maxi(1, logic.turn), "tianqi_logic": logic}
	if not bool(opts.check_weakness):
		o.elements = [0]  # 低战商：不看元素（按无属性估）
	var d := XDamage.preview_detail(rec, a, t, o)
	_hit_cache[key] = d
	return d


func hit_value(a: XBattler, t: XBattler, rec: Dictionary, raw: float) -> float:
	return float(hit_detail(a, t, rec, raw).value)


## 期望伤害（HP 伤害类 1／5、MP 伤害 2／6）：每段 = 不暴击 ×(1−p ＋ p×暴击倍率)，再 × 段数 × 命中 ×（1−闪避）。
## 暴击按 criticalIf 折算、不再整条重算（一次 calculate 两三毫秒；暴击只差这一个乘项，Confirm 里看暴击的少数状态忽略）
func expected_damage(a: XBattler, t: XBattler, rec: Dictionary, raw: float, hits := 1.0) -> float:
	var d := hit_detail(a, t, rec, maxf(0.0, raw))
	var normal := float(d.value)
	if not is_finite(normal) or normal <= 0.0:
		return 0.0
	var p := clampf(logic.item_cri(a, rec, t), 0.0, 1.0) if bool(rec.get("damage", {}).get("critical", false)) else 0.0
	var hit := logic.item_hit(a, rec, t) * (1.0 - logic.item_eva(a, rec, t))
	return normal * (1.0 - p + p * maxf(1.0, float(d.criticalIf))) * clampf(hits, 1.0, 32.0) * hit


## 回复量（类型 3／4）：结算值取正（已含受益者 rec、治疗加成）
func heal_value(a: XBattler, t: XBattler, rec: Dictionary, raw: float) -> float:
	return maxf(0.0, -hit_value(a, t, rec, -absf(raw)))


## 这招对这个目标的元素判定（天启篇元素牌组）：weak／resist／immune／higher_*／neutral 等；不看元素时 neutral
func element_kind(t: XBattler, rec: Dictionary) -> String:
	if not bool(opts.check_weakness):
		return "neutral"
	if not t is XEnemy or not XTianqiElements.deck_on():
		return _rate_kind(t, rec)  # 我方（敌方 AI 看我方）或没开元素牌组：按属性有效度（T282 核查 P2-1）
	var best := "neutral"
	var best_rate := -INF
	for raw_e in XDamage.action_elements(rec, user):
		var e := XTianqiElements.map_element_id(int(raw_e))
		if e <= 0:
			continue
		var info := XTianqiElements.element_rate_for(t, e, false, logic, {"preview": true})
		if float(info.rate) > best_rate:
			best_rate = float(info.rate)
			best = str(info.kind)
	return best


## 属性有效度口径：取这招各属性里对目标最有利的一个；0＝immune，<1＝resist，>1＝weak，<0 记 absorb
func _rate_kind(t: XBattler, rec: Dictionary) -> String:
	var best := -INF
	for raw_e in XDamage.action_elements(rec, user):
		if int(raw_e) > 0:
			best = maxf(best, t.element_rate(int(raw_e)))
	if best == -INF or is_equal_approx(best, 1.0):
		return "neutral"
	return "absorb" if best < 0.0 else "immune" if best == 0.0 else "resist" if best < 1.0 else "weak"


# ---- 打分零件（数值同 XSmartAI 原版移植，敌我共用）----
## 威胁度：0.8＋0.35×(攻＋魔＋0.3速)/本方对手里最高的，首领 +0.15，封顶 1.4
func threat(t: XBattler) -> float:
	return threat_in(t, foes)


static func threat_in(t: XBattler, list: Array) -> float:
	var power := func(b): return maxf(1.0, b.atk + b.mat + b.agi * 0.3)
	var highest := 1.0
	for f in list:
		highest = maxf(highest, power.call(f))
	return minf(1.4, 0.8 + 0.35 * power.call(t) / highest + (0.15 if is_boss(t) else 0.0))


## 伤害效用：威胁度 ×(11000×伤害/剩余HP ＋ 能击杀 7000 ＋ 4000×伤害/本回合最大伤害)；剩余 HP 按 HP＋护盾
func damage_utility(t: XBattler, damage: float, damage_scale := 0.0, ledger := true) -> float:
	var hp := maxf(1.0, t.hp + (shield_points(t, ledger) if bool(opts.check_shield) else 0.0))
	var effective := minf(hp, maxf(0.0, damage))
	if effective <= 0.0:
		return 0.0
	var relative := 4000.0 * effective / damage_scale if damage_scale > 0.0 else 0.0
	return threat(t) * (11000.0 * effective / hp + (7000.0 if damage >= hp and bool(opts.check_kill) else 0.0) + relative)


## 回复急需度：复活 60000；缺血 18% 以上或血＋盾低于 40% 时按急需度给分，低于 25% 还能补一成再 +22000；缺蓝、缺 TP 另算
func recovery_score(t: XBattler, heal_hp: float, heal_mp: float, tp_gain: float, ledger := true) -> float:
	var mx := maxf(1.0, t.mhp)
	var missing := maxf(0.0, mx - t.hp)
	var rate := minf(1.0, (t.hp + (shield_points(t, ledger) if bool(opts.check_shield) else 0.0)) / mx)  # check_shield 同 damage_utility（P3-2）
	var score := 0.0
	var effective := minf(missing, heal_hp)
	if missing / mx >= 0.18 or rate < 0.4:
		var urgency := 6.0 if rate < 0.25 else 3.5 if rate < 0.4 else 2.2 if rate < 0.6 else 1.0 if rate < 0.82 else 0.2
		score += 28000.0 * effective / mx * urgency
		if rate < 0.25 and effective / mx >= 0.10:
			score += 22000.0
	var missing_mp := maxf(0.0, t.mmp - t.mp)
	if t.mp / maxf(1.0, t.mmp) < 0.45 and missing_mp > 0.0:
		score += 6500.0 * minf(missing_mp, heal_mp) / maxf(1.0, t.mmp)
	if t.tp < t.max_tp() * 0.4 and t.skills().any(func(s): return int(s.get("tpCost", 0)) > 0):
		score += 3000.0 * minf(t.max_tp() - t.tp, tp_gain) / maxf(1.0, t.max_tp())
	return score


static func _hyper_armor(t) -> bool:
	return t is XEnemy and t.boss_difficulty_boss and t.boss_hyper_armor


## 增减益与状态收益（长战才计满）；opp／fri：这招对敌／对友（异化投影时由调用方按投影给）
func benefit(t: XBattler, rec: Dictionary, long_fight: bool, opp: bool, fri: bool) -> float:
	var score := 0.0
	for e in rec.get("effects", []):
		var code := int(e.code)
		var id := int(e.dataId)
		var harmful := harmful_state(id)
		var st := XDB.rec("States", id)
		# 有霸体的难度 Boss（CodexBossDifficulty.hasHyperArmor）不估控制状态（isControlState），也不估解除霸体 2651（审查第 76 期）
		if code == 21 and id > 1 and harmful == opp and not t.is_state_affected(id) and not t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) \
				and not (_hyper_armor(t) and XEnemy.boss_control_state(id)):
			var probability := minf(1.0, maxf(0.0, float(e.value1)) * logic.state_rate(t, id))
			var control := int(st.get("restriction", 0)) > 0
			var value := (11000.0 if control else 4200.0) if opp else 5000.0
			score += value * probability * (1.0 if long_fight else 0.18)
		if code == 22 and id > 1 and t.is_state_affected(id) and not (id == XEnemy.BOSS_ARMOR_STATE and _hyper_armor(t)):
			if fri and harmful:
				score += 40000.0 if int(st.get("restriction", 0)) > 0 else 16000.0
			if opp and not harmful:
				score += 7000.0
		var weight: float = [0.1, 0.1, 1, 1, 1, 1, 0.25, 0.25][id] if id >= 0 and id < 8 else 1.0
		var buff: int = t.buffs[id] if id >= 0 and id < 8 else 0
		if code == 31 and fri and buff < 2:
			score += 2200.0 * weight * (2 - buff) * (1.0 if long_fight else 0.1)
		if code == 32 and opp and buff > -2:
			score += 3000.0 * weight * (2 + buff) * (1.0 if long_fight else 0.2)
		if code == 33 and opp and buff > 0:
			score += 6500.0
		if code == 34 and fri and buff < 0:
			score += 16000.0
	return score


## 代价倍率：药 0.65；技能按 MP／TP／HP 消耗比例
func cost_multiplier(rec: Dictionary) -> float:
	if is_item(rec):
		return 0.65
	var c := logic.skill_cost(user, rec)
	var hp := float(XBattleLogic.skill_hp_cost(user, rec))
	var after := (user.hp - hp) / maxf(1.0, user.mhp)
	var danger := (4.0 if after < 0.25 else 1.6 if after < 0.5 else 0.0) if hp > 0.0 else 0.0
	return 1.0 / (1.0 + 0.25 * c.mp / maxf(1.0, user.mmp) + 0.6 * c.mp / maxf(1.0, user.mp)
		+ 0.25 * c.tp / maxf(1.0, user.max_tp()) + 0.35 * c.tp / maxf(1.0, user.tp)
		+ 1.5 * hp / maxf(1.0, user.hp) + danger)


func _raw(t: XBattler, rec: Dictionary) -> float:
	var f = opts.get("raw")
	return float(f.call(user, t, rec)) if f is Callable and f.is_valid() else raw_value(user, t, rec)


## 段数：攻击追加次数 × 行动序列 ACTION EFFECT 条数（转换器 yepEffects）
func hits_of(rec: Dictionary) -> float:
	return float(XBattleLogic.attack_repeats(user, rec, 1)) * maxf(1.0, float(rec.get("yepEffects", 1)))


## 通用一招打分（给敌方 AI 用）：返回 {score, target(XBattler 或 null＝全体／随机)}。
## ctx：{long_fight(bool), damage_scale(float，本回合最大期望伤害；0 不算相对项)}
func score_skill(rec: Dictionary, ctx := {}) -> Dictionary:
	var list := targets(rec)
	if list.is_empty():
		return {"score": 0.0, "target": null}
	var long_fight := bool(ctx.get("long_fight", false))
	var scale := float(ctx.get("damage_scale", 0.0))
	var dmg_type := int(rec.get("damage", {}).get("type", 0))
	var opp := for_opponent(rec)
	var fri := for_friend(rec)
	var ally_w := float(opts.ally_weight)
	var rows := []
	for t in list:
		var score := 0.0
		var hit_damage := 0.0
		if opp and dmg_type in [1, 5]:
			hit_damage = expected_damage(user, t, rec, _raw(t, rec), hits_of(rec))
			score += damage_utility(t, hit_damage, scale)
		elif opp and dmg_type in [2, 6]:
			score += 4000.0 * minf(t.mp, expected_damage(user, t, rec, _raw(t, rec), hits_of(rec))) / maxf(1.0, t.mmp)
		if fri:
			var hp := 0.0
			var mp := 0.0
			var tp := 0.0
			if dmg_type in [3, 4] and t.is_alive():
				var h := heal_value(user, t, rec, _raw(t, rec))
				hp = h if dmg_type == 3 else 0.0
				mp = h if dmg_type == 4 else 0.0
			for e in rec.get("effects", []):
				match int(e.code):
					11: hp += (t.mhp * float(e.value1) + float(e.value2)) * maxf(0.0, t.rec)
					12: mp += (t.mmp * float(e.value1) + float(e.value2)) * maxf(0.0, t.rec)
					13: tp += float(e.value1)
			if for_dead_friend(rec) and t.is_dead():
				var revives: bool = rec.get("effects", []).any(func(e): return int(e.code) == 22 and int(e.dataId) == 1)
				score += 60000.0 if revives or dmg_type == 3 else 0.0
			elif t.is_alive():
				score += recovery_score(t, hp, mp, tp)
		score += benefit(t, rec, long_fight, opp, fri)
		if fri and not for_user(rec) and t != user:
			score *= ally_w  # 配合只折给队友的；自保（scope 11、自己）不折（T282 核查 P2-1）
		rows.append({"target": t, "score": score, "hitDamage": hit_damage})
	var best: Dictionary = rows[0]
	var total := 0.0
	for r in rows:
		if r.score > best.score:
			best = r
		total += r.score
	var out := 0.0
	if for_random(rec):
		out = total / rows.size() * maxf(1.0, num_targets(rec)) * 0.9  # 随机 n 下：按平均目标估
	else:
		out = total if for_all(rec) else float(best.score)
	return {"score": out * cost_multiplier(rec), "target": null if for_all(rec) or for_random(rec) else best.target}
