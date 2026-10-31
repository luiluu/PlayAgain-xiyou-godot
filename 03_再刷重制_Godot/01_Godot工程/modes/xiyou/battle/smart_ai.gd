class_name XSmartAI
extends RefCounted
## Codex_SmartBattleAI（设置「智能战斗AI（自动战斗）」，默认开）：自动战斗时按收益/代价给每个可用技能与药品打分，选最高分。
## 照正式 v0.18 源码移植通用部分（choose → chooseScored → scoreCandidate），对照探针 mv_oracle/smart_ai_probe.cjs。
## - 候选：已会的技能（scope>0、无 <Hide in Battle>、能用；带公共事件效果的只有附在伤害技能上的「纯能力成长」事件可用）＋普通攻击，
##   再加持有的消耗品里含效果 11/12/22/34 的。
## - 伤害估算 safeDamage：只算受限的算式（a/b 的能力值、hpRate、状态、熟练度、变量、Math 函数之外的写法一律 0），
##   × 属性有效度 × pdr/mdr × 段数（YEP 行动序列里 ACTION EFFECT 条数，转换器预算为 yepEffects；攻击另加追加次数）
##   × 熟练度（默认每级 +10%）× 被动全局增伤 globalHarmRi（伤害类型 1）× 引入角色平衡（141～166 号 ×0.01）；
##   期望值再 × 命中（XBattleLogic.item_hit：必中被动、YEP_HitAccuracy 公式）×（1−闪避）×（1＋暴击率×0.5）。
## - 分数：伤害效用（威胁度 ×(11000×伤害/剩余HP ＋ 能击杀 7000 ＋ 4000×伤害/本回合最大伤害)）、治疗/复活/回蓝/TP 急需度、
##   增减益与状态收益（长战才计满）、代价倍率（药 0.65；技能按 MP/TP 消耗比例），全体取合计、单体取最佳目标、随机按期望段数。
## - 护盾（ShieldSystem）：剩余 HP 与急需度按 HP＋护盾算；对友方的加盾技能按 shieldEstimate 加分（缺口＝生命上限 80%−现有护盾）。
##   重制版没有 YEP 吸收屏障与来源护盾账本，shieldPoints 只算原生护盾。
## - 没移植（重制版尚无这些角色/系统）：奈叶小魔炮、米拉/渡鸦/宿傩等角色专属估算与 profile、Boss 霸体（CodexBossDifficulty）。
##   这些在正式版里也只对对应角色/敌人生效；随相关内容接入时补上。
## - 异化行动道具投影（祸祝、恶愿、逆祷，XAlienBattle.project）：见 o_projection。

const MASTERY_NOTE := "<Custom Damage Mastery Formula:\\s*value\\s*\\*\\s*\\(1\\s*\\+\\s*level\\s*\\*\\s*([\\d.]+)\\)\\s*>"
static var _boss_ids := {}
## O-121（优化登记）：异化投影一律读投影估值——目标方向、范围、伤害／治疗／增益全按投影后的技能（逆祷的攻击按治疗友方，
## 治疗量照 XAlienBattle.prayer_heal 借治疗技能平分；祸祝按对敌减益与诅咒；恶愿按除自己外的友方，付不起代价记 0 分）。
## 原版 Codex_SmartBattleAI 目标方向与范围读投影（action.item()）、估值读原技能（candidate.item），逆祷的攻击近乎 0 分；
## 全 0 分时退回「普攻打 HP 最低的敌人」（setTarget 敌人序号，投影成友方单体后落到同序号的队友）。
## true＝读投影；false＝照原版混读（方向、范围读投影，估值读原技能，退回目标落到同序号队友）
static var o_projection := true

var logic: XBattleLogic
var actor: XActor
var context := {}
var _damage_cache := {}


func _init(l: XBattleLogic, a: XActor) -> void:
	logic = l
	actor = a


## 返回 {skill, target(XBattler 或 null＝全体/随机/自动), score, candidates:[{id, item, score, target}]}；没有可选时 skill 为空
static func choose(l: XBattleLogic, a: XActor) -> Dictionary:
	return XSmartAI.new(l, a)._choose()


# ---- 数据判断 ----
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


static func is_boss(e: XBattler) -> bool:
	if not e is XEnemy:
		return false
	if _boss_ids.is_empty():
		var p := XDB.plugin("MOG_BossHP")
		for k in p:
			if RegEx.create_from_string("^boss-\\d+$").search(str(k)) and str(p[k]).is_valid_int() and int(p[k]) > 0:
				_boss_ids[int(p[k])] = true
		_boss_ids[-1] = true
	var meta: Dictionary = e.data().get("meta", {})
	return _boss_ids.has(int(e.data().get("id", 0))) or meta.has("boss") or meta.has("Boss")


## 公共事件只含注释/改能力值时才算安全（usefulCommonEvent）
static func useful_common_event(id: int) -> bool:
	var ev := XDB.rec("CommonEvents", id)
	if ev.is_empty():
		return false
	return ev.get("list", []).all(func(c): return int(c.code) in [0, 108, 408, 317])


func can_use(rec: Dictionary) -> bool:
	return logic.can_use(actor, rec) and (is_item(rec) or XHangUpAuto.wtype_ok(actor, rec))


## legalCandidate
func legal(rec: Dictionary, item: bool) -> bool:
	if rec.is_empty() or scope_of(rec) == 0 or str(rec.get("note", "")).to_lower().contains("<hide in battle>") or not can_use(rec):
		return false
	for e in rec.get("effects", []):
		if int(e.code) == 44:
			var dmg_type := int(rec.get("damage", {}).get("type", 0))
			if item or not dmg_type in [1, 2, 5, 6] or not useful_common_event(int(e.dataId)):
				return false
	return true


static func harmful_state(id: int) -> bool:
	var st := XDB.rec("States", id)
	if st.is_empty():
		return false
	var tag := RegEx.create_from_string("(?i)<BuffType\\s*:\\s*([^>]+)>").search(str(st.get("note", "")))
	if tag and RegEx.create_from_string("(?i)(减益|异常|削弱|debuff|诅咒|毒|破甲|封印|眩晕)").search(tag.get_string(1)):
		return true
	if tag and RegEx.create_from_string("(?i)(增益|强化|buff)").search(tag.get_string(1)):
		return false
	if int(st.get("restriction", 0)) > 0:
		return true
	for t in st.get("traits", []):
		if (int(t.code) == 21 and float(t.value) < 1.0) or (int(t.code) == 22 and float(t.value) < 0.0):
			return true
	return RegEx.create_from_string("(中毒|诅咒|流血|灼伤|眩晕|沉默|封印|虚弱|破甲|麻痹|失明)").search(str(st.get("name", ""))) != null


# ---- 伤害估算 ----
## Codex_SmartBattleAI 只让「安全的」算式参与估算：替换已知只读写法后只剩算术就算，否则 0
static func formula_safe(formula: String) -> bool:
	var s := formula.replace("Math.random()", "0.5")
	var subs := ["user\\.skillMasteryLevel\\(item\\.id\\)", "(?:a|b|user|target)\\.isStateAffected\\(\\d+\\)",
		"(?:a|b|user|target)\\.hpRate\\(\\)", "(?:a|b|user|target)\\.(?:mhp|mmp|hp|mp|tp|atk|def|mat|mdf|agi|luk|level|hit|cri)\\b",
		"v\\[\\d+\\]", "Math\\.(?:floor|ceil|round|max|min|abs|pow|sqrt)\\b"]
	for p in subs:
		s = RegEx.create_from_string(p).sub(s, "1", true)
	if RegEx.create_from_string("^[\\d\\s.+*/()%\\-,?:<>=!&|]+$").search(s) == null:
		return false
	return RegEx.create_from_string("(?:^|[^=!<>])=(?!=)|\\+\\+|--").search(s) == null


func safe_damage(a: XBattler, t: XBattler, rec: Dictionary) -> float:
	var dmg: Dictionary = rec.get("damage", {})
	var type := int(dmg.get("type", 0))
	if not formula_safe(str(dmg.get("formula", "0"))):
		return 0.0
	# 正式 choose 暂时把 Math.random 固定为0.5；预览不能抽走实战随机数。
	var preview := rec.duplicate()
	preview.damage = dmg.duplicate()
	if dmg.get("formulaGd") is String:
		preview.damage.formulaGd = dmg.formulaGd.replace("randf()", "0.5")
	var value := XDamage.eval_formula(preview, a, t, logic.vars())
	if type in [3, 4]:
		value = -value
	var element := int(dmg.get("elementId", 0))
	var rate := t.element_rate(element) if element > 0 else 1.0
	var defense := 1.0
	if not type in [3, 4]:
		defense = t.pdr if int(rec.get("hitType", 0)) == 1 else t.mdr if int(rec.get("hitType", 0)) == 2 else 1.0
	var repeats := XBattleLogic.attack_repeats(a, rec, 1)  # action.numRepeats：普攻（isAttack，看 attackSkillId）时加追加次数
	repeats *= int(rec.get("yepEffects", 1))
	var level := maxf(0.0, float(a.skillMasteryLevel(int(rec.id)))) if not is_item(rec) else 0.0
	var m := RegEx.create_from_string("(?i)" + MASTERY_NOTE).search(str(rec.get("note", "")))
	var mastery := 1.0 + level * (float(m.get_string(1)) if m else 0.10)
	var extra := 1.0
	if type == 1 and a is XActor:
		extra *= maxf(0.0, 1.0 + float(a.passive_cache().get("globalHarmRi", 0.0)))
	var balance := 0.01 if a is XActor and int(a.data().get("id", 0)) >= 141 and int(a.data().get("id", 0)) <= 166 and type in [1, 2, 5, 6] else 1.0
	return maxf(0.0, value) * rate * defense * clampf(repeats, 1, 32) * extra * mastery * balance


func expected_damage(a: XBattler, t: XBattler, rec: Dictionary) -> float:
	var key := "%s|%d|%d|%f|%f|%f" % [str(a.get_instance_id()), t.get_instance_id(), int(rec.id), a.hp, a.mp, t.hp]
	if _damage_cache.has(key):
		return _damage_cache[key]
	var damage := safe_damage(a, t, rec)
	var v := 0.0
	if damage > 0.0:
		var hit := logic.item_hit(a, rec, t) * (1.0 - logic.item_eva(a, rec, t))
		var crit := clampf(a.cri * (1.0 - t.cev), 0.0, 1.0) if bool(rec.get("damage", {}).get("critical", false)) else 0.0
		v = damage * hit * (1.0 + crit * 0.5)
	_damage_cache[key] = v
	return v


# ---- 打分 ----
func threat(t: XBattler, foes: Array) -> float:
	var power := func(b): return maxf(1.0, b.atk + b.mat + b.agi * 0.3)
	var highest := 1.0
	for f in foes:
		highest = maxf(highest, power.call(f))
	return minf(1.4, 0.8 + 0.35 * power.call(t) / highest + (0.15 if is_boss(t) else 0.0))


## shieldPoints：原生护盾（没有吸收屏障与来源护盾账本）
static func shield_points(t: XBattler) -> float:
	return maxf(0.0, t.shield)


## shieldEstimate：公式整条是「b／target.addShield(式子); 0」（对自己时也认 a／user）且式子只含能力值与 Math 函数时，
## 按本次行动预演（不写入）得到的护盾增量，已含受益者护盾加成；其余 0。
static var _shield_formula_re := RegEx.create_from_string("^(?:b|target)\\.addShield\\((.+)\\)\\s*;\\s*0\\s*$")
static var _self_shield_re := RegEx.create_from_string("^(?:a|user)\\.addShield\\((.+)\\)\\s*;\\s*0\\s*$")
static var _shield_reads_re := RegEx.create_from_string("(?:a|b|user|target)\\.(?:mhp|mmp|hp|mp|atk|def|mat|mdf|agi|luk|level)\\b")
static var _shield_math_re := RegEx.create_from_string("Math\\.(?:floor|ceil|round|max|min|abs|pow|sqrt)\\b")
static var _shield_plain_re := RegEx.create_from_string("^[\\d\\s.+*/()%\\-,]+$")
func shield_estimate(a: XBattler, t: XBattler, rec: Dictionary) -> float:
	var formula := str(rec.get("damage", {}).get("formula", ""))
	var m := _shield_formula_re.search(formula)
	if m == null and a == t:
		m = _self_shield_re.search(formula)
	if m == null:
		return 0.0
	var stripped := _shield_math_re.sub(_shield_reads_re.sub(m.get_string(1), "1", true), "1", true)
	if _shield_plain_re.search(stripped) == null:
		return 0.0
	var out := XFormulaExecution.run_item(rec, a, t, logic.vars(), {}, false)
	if not out.get("available", false):
		return 0.0
	var gained := 0.0
	for e in out.effectJournal:
		if e.resource == "shield" and e.receiver == ("a" if a == t else "b"):
			gained += maxf(0.0, float(e.actualDelta))
	return gained


func damage_utility(t: XBattler, damage: float, foes: Array, ctx := {}) -> float:
	var hp := maxf(1.0, t.hp + shield_points(t))
	var effective := minf(hp, maxf(0.0, damage))
	if effective <= 0.0:
		return 0.0
	var relative := 4000.0 * effective / float(ctx.damageScale) if float(ctx.get("damageScale", 0.0)) > 0.0 else 0.0
	return threat(t, foes) * (11000.0 * effective / hp + (7000.0 if damage >= hp else 0.0) + relative)


func healing_amount(t: XBattler, rec: Dictionary, item: bool, mp: bool) -> float:
	var type := 4 if mp else 3
	var mx := t.mmp if mp else t.mhp
	var amount := safe_damage(actor, t, rec) * maxf(0.0, t.rec) if int(rec.get("damage", {}).get("type", 0)) == type else 0.0
	if not mp and XAlienBattle._mode(rec) == "prayer":
		amount = safe_damage(actor, t, XAlienBattle.prayer_healer(logic, actor, rec)) * maxf(0.0, t.rec) / float(prayer_targets(rec))
	for e in rec.get("effects", []):
		if int(e.code) == (12 if mp else 11):
			amount += (mx * float(e.value1) + float(e.value2)) * maxf(0.0, t.rec) * (maxf(0.0, actor.pha) if item else 1.0)
	return maxf(0.0, amount)


## dir：目标方向读的技能（原版 action.item()，即投影），缺省同 rec
func recovery_utility(t: XBattler, rec: Dictionary, item: bool, dir := {}) -> float:
	if for_dead_friend(rec if dir.is_empty() else dir) and t.is_dead():
		var revives: bool = rec.get("effects", []).any(func(e): return int(e.code) == 22 and int(e.dataId) == 1)
		return 60000.0 if revives or int(rec.get("damage", {}).get("type", 0)) == 3 else 0.0
	if t.is_dead():
		return 0.0
	var mx := maxf(1.0, t.mhp)
	var missing := maxf(0.0, mx - t.hp)
	var rate := minf(1.0, (t.hp + shield_points(t)) / mx)
	var score := 0.0
	var effective := minf(missing, healing_amount(t, rec, item, false))
	if missing / mx >= 0.18 or rate < 0.4:
		var urgency := 6.0 if rate < 0.25 else 3.5 if rate < 0.4 else 2.2 if rate < 0.6 else 1.0 if rate < 0.82 else 0.2
		score += 28000.0 * effective / mx * urgency
		if rate < 0.25 and effective / mx >= 0.10:
			score += 22000.0
	var missing_mp := maxf(0.0, t.mmp - t.mp)
	if t.mp / maxf(1.0, t.mmp) < 0.45 and missing_mp > 0.0:
		score += 6500.0 * minf(missing_mp, healing_amount(t, rec, item, true)) / maxf(1.0, t.mmp)
	var tp := 0.0
	for e in rec.get("effects", []):
		if int(e.code) == 13:
			tp += float(e.value1)
	if t.tp < t.max_tp() * 0.4 and t.skills().any(func(s): return int(s.get("tpCost", 0)) > 0):
		score += 3000.0 * minf(t.max_tp() - t.tp, tp) / maxf(1.0, t.max_tp())
	return score


func benefit(t: XBattler, rec: Dictionary, ctx: Dictionary, dir := {}) -> float:
	var score := 0.0
	var opp := for_opponent(rec if dir.is_empty() else dir)
	var fri := for_friend(rec if dir.is_empty() else dir)
	for e in rec.get("effects", []):
		var code := int(e.code)
		var id := int(e.dataId)
		var harmful := harmful_state(id)
		var st := XDB.rec("States", id)
		if code == 21 and id > 1 and harmful == opp and not t.is_state_affected(id) and not t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id):
			var probability := minf(1.0, maxf(0.0, float(e.value1)) * logic.state_rate(t, id))
			var control := int(st.get("restriction", 0)) > 0
			var value := (11000.0 if control else 4200.0) if opp else 5000.0
			score += value * probability * (1.0 if ctx.longFight else 0.18)
		if code == 22 and id > 1 and t.is_state_affected(id):
			if fri and harmful:
				score += 40000.0 if int(st.get("restriction", 0)) > 0 else 16000.0
			if opp and not harmful:
				score += 7000.0
		var weight: float = [0.1, 0.1, 1, 1, 1, 1, 0.25, 0.25][id] if id >= 0 and id < 8 else 1.0
		var buff: int = t.buffs[id] if id >= 0 and id < 8 else 0
		if code == 31 and fri and buff < 2:
			score += 2200.0 * weight * (2 - buff) * (1.0 if ctx.longFight else 0.1)
		if code == 32 and opp and buff > -2:
			score += 3000.0 * weight * (2 + buff) * (1.0 if ctx.longFight else 0.2)
		if code == 33 and opp and buff > 0:
			score += 6500.0
		if code == 34 and fri and buff < 0:
			score += 16000.0
	return score


func cost_multiplier(rec: Dictionary, item: bool) -> float:
	if item:
		return 0.65
	var c := logic.skill_cost(actor, rec)
	return 1.0 / (1.0 + 0.25 * c.mp / maxf(1.0, actor.mmp) + 0.6 * c.mp / maxf(1.0, actor.mp)
		+ 0.25 * c.tp / maxf(1.0, actor.max_tp()) + 0.35 * c.tp / maxf(1.0, actor.tp))


static func has_cooldown(rec: Dictionary) -> bool:
	if rec.has("_alienOriginal"):  # 逆祷投影照抄治愈的备注，冷却看原技能
		rec = XDB.rec("Skills", int(rec._alienOriginal))
	var m := RegEx.create_from_string("(?i)<Cooldown:\\s*(\\d+)>").search(str(rec.get("note", "")))
	return m != null and int(m.get_string(1)) > 0


## 逆祷投影治疗平分的目标数（_alienHealTargets，不含连击）：友方单体 1，原 scope 3～6 随机 n 个，其余全体存活友方
func prayer_targets(rec: Dictionary) -> int:
	var n := XAlienBattle.prayer_random_count(rec)
	if n > 0:
		return n
	return 1 if scope_of(rec) == 7 else maxi(1, logic.alive(context.friends).size())


## 目标方向读的技能：异化投影（原版 action.item()）；候选与返回的仍是原技能，execute 再投影
func directed(rec: Dictionary, item: bool) -> Dictionary:
	return rec if item else XAlienBattle.project(actor, rec)


## 估值读的技能：o_projection 开时为投影，关时照原版读原技能（candidate.item）
func valued(rec: Dictionary, item: bool) -> Dictionary:
	return directed(rec, item) if o_projection else rec


## scoreCandidate：返回 {score, target}。rec 是估值读的技能（valued），dir 是目标方向与范围读的（directed，缺省同 rec）
func score_candidate(rec: Dictionary, item: bool, ctx: Dictionary, dir := {}) -> Dictionary:
	var d: Dictionary = rec if dir.is_empty() else dir
	var targets: Array = ctx.foes if for_opponent(d) else [actor] if for_user(d) else \
		ctx.friends.filter(func(t): return t.is_dead() if for_dead_friend(d) else t.is_alive())
	targets = XAlienBattle.filter_targets(actor, rec, targets)  # 恶愿：除自己外
	if targets.is_empty() or (XAlienBattle._mode(rec) == "wish" and not XAlienBattle.wish_affordable(actor, rec)):
		return {"score": 0.0, "target": null}
	var dmg_type := int(rec.get("damage", {}).get("type", 0))
	var rows := []
	for t in targets:
		var score := recovery_utility(t, rec, item, d) if for_friend(d) else 0.0
		var hit_damage := 0.0
		var hit_score := 0.0
		if for_friend(d):
			var gap := maxf(0.0, t.mhp * 0.8 - shield_points(t))
			score += 16000.0 * minf(gap, shield_estimate(actor, t, rec)) / maxf(1.0, t.mhp) * (1.0 if ctx.longFight else 0.12)
		score += benefit(t, rec, ctx, d)
		if for_opponent(d) and dmg_type in [1, 5]:
			hit_damage = expected_damage(actor, t, rec)
			hit_score = damage_utility(t, hit_damage, ctx.foes, ctx)
			score += hit_score
		elif for_opponent(d) and dmg_type in [2, 6]:
			score += 4000.0 * minf(t.mp, expected_damage(actor, t, rec)) / maxf(1.0, t.mmp)
		rows.append({"target": t, "score": score, "hitDamage": hit_damage, "hitScore": hit_score})
	var best: Dictionary = rows[0]
	var total := 0.0
	for r in rows:
		if r.score > best.score:
			best = r
		total += r.score
	var prayer_n := XAlienBattle.prayer_random_count(rec)  # 逆祷原 scope 3～6：投影 scope 8，实际随机友方 n 个
	var random := for_random(d) or prayer_n > 0
	var score := 0.0 if random else total if for_all(d) else float(best.score)
	if random:
		var weight_sum := 0.0
		for t in targets:
			weight_sum += maxf(0.0, t.tgr)
		if weight_sum <= 0.0:
			weight_sum = targets.size()
		var n := maxf(1.0, prayer_n if prayer_n > 0 else num_targets(d))
		var weighted := 0.0
		for i in targets.size():
			var w := maxf(0.0, targets[i].tgr) / weight_sum
			var r: Dictionary = rows[i]
			weighted += (r.score - r.hitScore) * (1.0 - pow(1.0 - w, n))
			if r.hitDamage > 0.0:
				weighted += damage_utility(targets[i], r.hitDamage * n * w, ctx.foes, ctx)
		score = weighted * 0.9
	score *= cost_multiplier(rec, item)
	if not item and not ctx.longFight and has_cooldown(rec):
		score *= 0.94
	return {"score": score, "target": null if for_all(d) or random else best.target}


func _choose() -> Dictionary:
	var friends: Array = logic.actors
	var foes: Array = logic.alive(logic.enemies)
	var attack := actor.attack_skill()  # $dataSkills[actor.attackSkillId()]
	var candidates := []
	for s in actor.skills():
		if legal(s, false) and int(s.id) != 5692:
			candidates.append({"rec": s, "item": false, "eval": valued(s, false), "dir": directed(s, false)})
	if legal(attack, false) and not candidates.any(func(c): return int(c.rec.id) == int(attack.id)):
		candidates.append({"rec": attack, "item": false, "eval": valued(attack, false), "dir": directed(attack, false)})
	var urgent := friends.any(func(t): return t.is_dead() or (t.hp + shield_points(t)) / maxf(1.0, t.mhp) < 0.25)
	context = {"friends": friends, "foes": foes, "urgent": urgent, "longFight": false, "damageScale": 0.0}
	var scale := 0.0
	for c in candidates:
		var rec: Dictionary = c.eval
		if not int(rec.get("damage", {}).get("type", 0)) in [1, 5] or not for_opponent(c.dir):
			continue
		var reps := maxf(1.0, num_targets(c.dir) / maxf(1.0, foes.size())) if for_random(c.dir) else 1.0
		for t in foes:
			scale = maxf(scale, expected_damage(actor, t, rec) * reps)
	context.damageScale = scale
	var best_attack := 0.0
	for c in candidates:
		if int(c.eval.get("damage", {}).get("type", 0)) in [1, 5]:
			best_attack = maxf(best_attack, float(score_candidate(c.eval, false, context, c.dir).score))
	var whole := 0.0
	for t in foes:
		whole += damage_utility(t, t.hp + shield_points(t), foes)
	context.longFight = not foes.is_empty() and best_attack < whole * 0.92
	var ids := logic.state.items.keys().map(func(k): return int(k))
	ids.sort()
	for id in ids:
		var it := XDB.rec("Items", id)
		if bool(it.get("consumable", false)) and legal(it, true) and it.get("effects", []).any(func(e): return int(e.code) in [11, 12, 22, 34]):
			candidates.append({"rec": it, "item": true, "eval": it, "dir": it})
	var best := {}
	var best_score := 0.0
	var ranking := []
	for c in candidates:
		var r := score_candidate(c.eval, c.item, context, c.dir)
		ranking.append({"id": int(c.rec.id), "item": c.item, "score": roundf(r.score), "target": r.target})
		if r.score > best_score:
			best_score = r.score
			best = {"skill": c.rec, "target": r.target}
	if best.is_empty() and not foes.is_empty() and legal(attack, false):
		var low: XBattler = foes.reduce(func(x, y): return y if y.hp < x.hp else x)
		best = {"skill": attack, "target": low}
		if not o_projection and scope_of(directed(attack, false)) == 7:  # 原版 setTarget(敌人序号)，投影成友方单体后按同序号取队友（smoothTarget）
			var i := logic.enemies.find(low)
			best.target = friends[i] if i >= 0 and i < friends.size() and friends[i].is_alive() else logic.alive(friends)[0]
	if best.is_empty():
		var guard := XDB.rec("Skills", XBattleLogic.GUARD_SKILL)
		if can_use(guard):
			best = {"skill": guard, "target": actor}
	ranking.sort_custom(func(x, y): return x.score > y.score)
	best["score"] = best_score
	best["candidates"] = ranking.slice(0, 6)
	return best
