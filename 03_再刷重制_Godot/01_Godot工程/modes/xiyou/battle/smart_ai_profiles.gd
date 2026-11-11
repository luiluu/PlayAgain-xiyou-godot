class_name XSmartAIProfiles
extends RefCounted
## Codex_SmartBattleAI（v0.62.12）里写在插件自己身上的角色部分，对照探针 mv_oracle/smart_ai_profile_probe.cjs：
## - registerProfile 第一条（第 508～526 行，排在甚尔、云裳之前）：黄泉 169 的 10172／10173／10174 溅射 0.33／0.5／0.66、
##   流萤 179 的天火 10622 溅射 0.5；宿傩 172 领域里的神灶：开 10233 holdInLongFight（长战且不急需时 0 分，留给领域到期自动放）、
##   伏魔御厨子 10231（不带 2636 时）futureActor＋ongoingSkill 10237×4 回合；渡鸦 167 神话封解 10127（不在神话形态时）futureActor＋
##   setupActions 1＋duration 3；米拉 168 解放 10146 futureActor＋followupSkill 10151。
## - safeDamage 的受控估算分支（第 96～172 行）：米拉 10140～10151（CodexMira.damage，按统一伤害的攻防比例折防御）、
##   渡鸦 10122～10126（整条公式）、黄泉 10171～10174（CodexYomi.damage）、宿傩 10229～10233（神灶要目标蓄力、神灶：开要准备层）。
##   镜流 10187～10193、饿狼 10250～10263 两支不在这里（见交付单）。
## - 段数：估伤乘的 action.numRepeats 要过角色的包装（黄泉 2／6＋幸运段、流萤天火 5／8 与燃烧 9、渡鸦冥羽连葬加追加次数），见 repeats。
## - boosts（第 67～83 行）：米拉 30 级学了 10144 ×7.66、70 级三阶学了 10164 ×2；渡鸦 damageMultiplier、25 级学了 10132 ×1.15、
##   60 级五阶学了 10136 ×4.25。
## - expectedDamage（第 206～213 行）：米拉 40 级学了 10145、渡鸦五技 45 级学了 10134 的暴击增量 +9.99；渡鸦神话形态学了 10136 ×1.85。
## 铺垫后的角色视图（futureActor）：原版 Object.create 一份只读视图再改几个字段；重制在同一个角色上临时改、估完还原（enter／leave）。

## O-待定（优化登记）：原版这条档案对黄泉、流萤每个技能都返回对象（溅射 0 也算），后面登记的档案（云裳天衣的倍率与
## 换锦、赠行、储行的目标收益）就问不到了——黄泉、流萤穿天衣时自动战斗不会用天衣的技能。true＝溅射之外接着问后面的档案；false＝照原版
static var o_profile_chain := true
## O-待定（优化登记）：铺垫档案按铺垫后的真实状态估。原版三处读到的是旧值：① 米拉的黑龙视图只在状态表里加了 2592，
## 状态缓存没刷新，能力值是「人形去掉人形加成」，没有黑龙的加成；② 宿傩的领域视图只加了状态 2636，领域回合数仍是 0，
## 领域里斩击 ×1.3、解／捌半价都没算进；③ 领域每回合的御厨子·斩击 10237 不在受控估算名单里，ongoingSkill 的估伤恒为 0。
## true＝米拉视图刷新能力值、宿傩视图领域生效、10237 按公式估；false＝照原版
static var o_future_real := true

const YOMI := 169
const LIUYING := 179
const SUKUNA := 172
const RAVEN := 167
const MIRA := 168
const YOMI_SPLASH := {10172: 0.33, 10173: 0.5, 10174: 0.66}
static var _mira_formula_re := RegEx.create_from_string("^CodexMira\\.damage\\(a,b,\\d+\\)$")
static var _yomi_formula_re := RegEx.create_from_string("^CodexYomi\\.damage\\(a,b,1017[1-4]\\)$")
static var _sukuna_formula_re := RegEx.create_from_string("^CodexSukuna\\.damage\\(a,b,102(?:29|30|31|32|33),this\\)$")
static var _sukuna_ongoing_re := RegEx.create_from_string("^CodexSukuna\\.damage\\(a,b,10237,this\\)$")


static func _id(a) -> int:
	return int(a.actor_id) if a is XActor else 0


static func _learned(a, id: int) -> bool:
	return a is XActor and a.skill_ids.has(id)


## registerProfile 第一条：不适用返回空。future＝铺垫后的角色视图种类（原版 futureActor）
static func profile(a, rec: Dictionary) -> Dictionary:
	var actor := _id(a)
	var id := 0 if XBattleLogic.is_item(rec) else int(rec.get("id", 0))
	if actor == YOMI:
		return {"splash": float(YOMI_SPLASH.get(id, 0.0))}
	if actor == LIUYING:
		return {"splash": 0.5 if id == XLiuying.TIANHUO else 0.0}
	if actor == SUKUNA and id == 10233 and int(XSukuna.temp(a).domain) > 0:
		return {"holdInLongFight": true}
	if actor == RAVEN and id == XRaven.MYTH and XRaven.myth_turns(a) <= 0:
		return {"future": "raven", "setupActions": 1, "duration": 3}
	if actor == SUKUNA and id == 10231 and not a.state_ids.has(XSukuna.DOMAIN):
		return {"future": "sukuna", "setupActions": 0, "ongoingSkill": 10237, "ongoingRounds": 4}
	if actor == MIRA and id == XMira.LIBERATE:
		return {"future": "mira", "setupActions": 0, "followupSkill": 10151}
	return {}


## 这条档案只给了溅射（黄泉、流萤）：o_profile_chain 开时还要接着问后面的档案
static func splash_only(a) -> bool:
	return _id(a) in [YOMI, LIUYING]


## safeDamage 的受控估算分支：返回原始公式值；不适用返回 null
static func raw(a, t, rec: Dictionary):
	if XBattleLogic.is_item(rec):
		return null
	var id := int(rec.get("id", 0))
	var formula := str(rec.get("damage", {}).get("formula", ""))
	if id >= 10140 and id <= 10151 and _mira_formula_re.search(formula) != null:
		var value := XMira.formula(a, t, rec)
		var physical := XDamage.defense_rate(a.atk, t.def)
		var magical := XDamage.defense_rate(a.mat, t.mdf)
		return value * (magical if id in [10142, 10143, 10149] else (physical + magical) / 2.0 if id in [10146, 10147, 10151] else physical)
	if id >= 10122 and id <= 10126 and str(rec.get("damage", {}).get("formulaProgram", {}).get("module", "")) == "raven":
		return XRaven.formula(a, t, rec)
	if id >= 10171 and id <= 10174 and _yomi_formula_re.search(formula) != null:
		return XYomiJingliu.formula(a, t, rec)
	if id >= 10229 and id <= 10233 and _sukuna_formula_re.search(formula) != null:
		if id == 10232 and not bool(XSukuna.target_data(t).charged):
			return 0.0
		if id == 10233 and int(XSukuna.temp(a).prep) <= 0:
			return 0.0
		return _sukuna_raw(a, t, rec)
	if o_future_real and id == 10237 and _sukuna_ongoing_re.search(formula) != null:
		return _sukuna_raw(a, t, rec)
	return null


## CodexSukuna.damage 在伤害计算之外调用（CodexDamage.isCalculating 为假）：攻击项先减固定防御（神灶类魔防×0.5，捌防御×0.15，其余防御×0.5）。
## 重制的 XSukuna.formula 只有计算中的口径（不减），这里按「攻击项−防御」的比例折回去；按一个新行动算（不带施放帧、内部行动）
static func _sukuna_raw(a, t, rec: Dictionary) -> float:
	var id := int(rec.id)
	var fire := id == 10232 or id == 10233
	var weight := float(XSukuna.WEIGHTS[id]) * (float(XSukuna.temp(a).prep) if id == 10233 else 1.0)
	var attack: float = (a.mat if fire else a.atk) * weight
	if attack <= 0.0:
		return 0.0
	var defense: float = t.mdf * 0.5 if fire else t.def * (0.15 if id == 10230 else 0.5)
	var saved := [XSukuna.cast, XSukuna.part, XSukuna.internal]
	XSukuna.cast = {}
	XSukuna.part = ""
	XSukuna.internal = false
	var value := XSukuna.formula(a, t, rec)
	XSukuna.cast = saved[0]
	XSukuna.part = saved[1]
	XSukuna.internal = saved[2]
	return value * maxf(0.0, attack - defense) / attack


## action.numRepeats 的角色包装（只读：实战那几层包装顺带开新行动帧，这里不开）：渡鸦冥羽连葬加额外攻击次数、
## 黄泉／镜流技能换成各自的段数、流萤天火 5 段（学了星河 8 段）与完全燃烧 9 段
static func repeats(a, rec: Dictionary, base: int) -> int:
	if XBattleLogic.is_item(rec):
		return base
	var id := int(rec.get("id", 0))
	if XRaven.own(a) and id == XRaven.FEATHER:
		base += maxi(0, floori(a.attack_times_add()))
	if XYomiJingliu._j_action(a, rec):
		return int(XYomiJingliu.J_REPEATS[id])
	if XYomiJingliu._yomi_action(a, rec):
		return XYomiJingliu.repeats(a, id)
	if XLiuying._action(a, rec):
		return 5 + (3 if XLiuying.learned(a, XLiuying.XING_HE) else 0) if id == XLiuying.TIANHUO else 9
	return base


## boosts
static func boosts(a, rec: Dictionary) -> float:
	var actor := _id(a)
	var id := int(rec.get("id", 0))
	if actor == 0 or XBattleLogic.is_item(rec):
		return 1.0
	var m := 1.0
	if actor == MIRA and id >= 10140 and id <= 10151:
		if int(a.level) >= 30 and _learned(a, 10144):
			m *= 7.66
		if int(a.level) >= 70 and XMira.rank(a) >= 3 and _learned(a, 10164):
			m *= 2.0
	elif actor == RAVEN and id >= 10122 and id <= 10126:
		m *= raven_multiplier(a, rec)
		if int(a.level) >= 25 and _learned(a, 10132):
			m *= 1.15
		if int(a.level) >= 60 and XRaven.stage(a) >= 5 and _learned(a, 10136):
			m *= 4.25
	return m


## CodexRaven.damageMultiplier（原版 makeDamageValue 包装用的整体倍率；重制实战拆成伤害帧操作 XRaven.damage_ops，这里照原式合成）
static func raven_multiplier(a, rec: Dictionary) -> float:
	if not XRaven.own(a) or not rec.get("meta", {}).has("CodexRavenDamage"):
		return 1.0
	var p := XRaven.progress(a)
	var tempered := XRaven.has(a, 10131)
	var magical := 1.0 + 1.5 + p if tempered else 1.0
	var darkness := 1.0 + 2.0 + p if tempered else 1.0
	var final_rate := 1.0 + 1.5 * minf(1.0, (XRaven.stage(a) + p) / 5.0) if tempered else 1.0
	if XRaven.has(a, 10136):
		final_rate *= 1.10
	if XRaven.myth_power(a):
		magical += 1.0
		darkness += 1.0
		final_rate += 1.5
	var artifact := 1.6 if XRaven.artifact_equipped(a) else 1.0
	return (darkness if int(rec.get("damage", {}).get("elementId", 0)) == 9 else magical) * final_rate * XRaven.crown_rate(a) * artifact


## expectedDamage：暴击增量（基础 0.5 之外）
static func crit_bonus(a, rec: Dictionary) -> float:
	var actor := _id(a)
	var id := int(rec.get("id", 0))
	if actor == MIRA and int(a.level) >= 40 and _learned(a, 10145):
		return 9.99
	if actor == RAVEN and not XBattleLogic.is_item(rec) and id >= 10122 and id <= 10126 and int(a.level) >= 45 and _learned(a, 10134):
		return 9.99
	return 0.0


## expectedDamage：渡鸦神话形态的伤害倍率
static func expected_rate(a, rec: Dictionary) -> float:
	if _id(a) == RAVEN and rec.get("meta", {}).has("CodexRavenDamage") and XRaven.myth_turns(a) > 0 and _learned(a, 10136):
		return 1.85
	return 1.0


## 进入铺垫后的角色视图（临时改同一个角色），返回还原用的记录；leave 还原。生命、魔法、TP 由调用处存取（能力值缓存刷新不截资源）
static func enter(a, kind: String) -> Dictionary:
	var token := {"kind": kind, "actor": a}
	match kind:
		"raven":
			var st := XRaven._store()
			token.myth = st.get("myth", 0)
			st["myth"] = 3
		"sukuna":
			token.had = a.state_ids.has(XSukuna.DOMAIN)
			if not token.had:
				a.state_ids.append(XSukuna.DOMAIN)
			token.domain = XSukuna.temp(a).domain
			if o_future_real:
				XSukuna.temp(a).domain = 4
		"mira":
			token.real = o_future_real
			token.had = a.state_ids.has(XMira.DRAGON)
			if o_future_real and not token.had:
				a.state_ids.append(XMira.DRAGON)
			if not o_future_real:
				XMira.ai_view = a  # 原版：黑龙判定成立，2592 的特性不算（状态缓存没刷新）
			_refresh(a)
	return token


static func leave(token: Dictionary) -> void:
	var a = token.actor
	match str(token.kind):
		"raven":
			XRaven._store()["myth"] = token.myth
		"sukuna":
			if not token.had:
				a.state_ids.erase(XSukuna.DOMAIN)
			XSukuna.temp(a).domain = token.domain
		"mira":
			if token.real and not token.had:
				a.state_ids.erase(XMira.DRAGON)
			XMira.ai_view = null
			_refresh(a)


static func _refresh(a) -> void:
	a.param_mark_dirty()
	a.param_refresh()
