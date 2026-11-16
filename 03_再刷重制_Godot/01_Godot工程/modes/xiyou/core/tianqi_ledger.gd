class_name XTianqiLedger
extends RefCounted
## 【cc·天启篇·未经审查】伤害加成总账·期一「总账入口（不改数）」（设计仓《天启篇_伤害加成总账_v0.4》第八节期一细则）。只对天启篇存档生效，原版档不进这里。
## 表：modes/xiyou/tianqi_data/damage_ledger.json（只读）。每个「乘」一行，三种状态：
##   pooled 已归池（出现就失败）／exempt 豁免（写到期 expires，到期那一期起出现就失败）／allowed 永久允许（不判）。
## 守卫（GUARD）：天启篇里我方出手的每一下伤害，把落在单独相乘字段上的操作（钩子帧、技能专属被动起点、种族乘数、原版独立乘区）
##   按「来源」认一遍；来源没登记、字段不在这一行、已归池或豁免到期 → push_error（并行测试把 ERROR 行判失败）并记进 violations。
##   只记、不改数：伤害照算。来源由 XActorDamageHooks.capture 分段打标签（tags 跟 ops 一一对应），别的注册表模块按模块号认。
## 来源分桶（BUCKETS）：被动缓存（XActor._refresh_passive_now）并排多存一份 bySource，按秘籍格、符文之语、宝珠、原版装备、种族、成长装备、
##   天启篇、角色自带、状态分；原合计字段不动、西游档不建这份。
## 五池明细（DETAIL）：伤害详情（breakdown.row.pools）多一份五池和单独相乘残余，只加明细。
## 开关都默认开；全关＝回到 main（数值本来就不变）。
## 期二「归池清场」（第五节第 1 条全表，D16＝乙）：表的 phase＝2，期一「豁免·期二到期」的七行改成已归池，每样一个回退开关（POOL_* 等，见下）；
##   另加套装确认阶段乘、万灵增元丹被动、暴击敏捷挪 combat_rules；确认阶段运行期守卫 audit_confirm（期一核查 P2）。

const PATH := "res://modes/xiyou/tianqi_data/damage_ledger.json"
## 单独相乘的口子（第三节第 1 条）：落在这些字段上的操作就算「乘」，不论 add／mul／set
const MUL_FIELDS := ["skillMultiplier", "elementMultiplier", "finalMultiplier", "settlementMultiplier",
	"physicalDamageMultiplier", "magicalDamageMultiplier", "growthMultiplier"]
## 注册表模块号 → 总账来源（actor-modules 按 tags 逐条认）
const MODULE_SOURCE := {"orb-sets": "orb_resonance", "race-blessings": "race", "cat-sword": "module.cat", "alienation": "alienation"}

static var GUARD := true
static var BUCKETS := true
static var DETAIL := true
## 测试用：不 push_error，只记（专项故意造违规时用）
static var QUIET := false

# ---- 期二「归池清场」（设计稿第五节第 1 条全表；D16＝乙，qiyin_gear.json 的数一个不改）----
## 每样一个回退开关，默认开；关掉＝这一样回到期一的单独相乘（守卫把那一行当作「回退中」，不报）。只对天启篇存档生效。
static var POOL_QIYIN := true        # 七印条件增伤 ×(1＋x) → 各自 ＋x 进池（群体、天平进①，元素进②，其余进③；末段 ×2 → ＋100% 进③）
static var POOL_ORB := true          # 宝珠共鸣 finalMultiplier ×(1＋g) → ＋g 进③
static var POOL_RACE := true         # 种族祝福 finalMultiplier／物理魔法伤害乘数 ×(1＋q) → ＋q 进③（魔族爆伤本来就进④）
static var POOL_ENEMY_RACE := true   # 对某族敌人增伤 <EnemyRaceBo> 种族乘数 → 进③
static var NO_SELF_RATE := true      # 原版独立乘区 <SelfPhysRate>／<SelfElemRate> 天启篇不读
static var POOL_SUIT := true         # 原版套装给的状态在确认阶段的「结果 ×k」（铁头娃II ×2）→ ＋(k−1) 进③
static var POOL_AFFIX_SKILL := true  # 词条技能伤 skillMultiplier 加项 → normalAdd（①）
static var POOL_SKILL_PASS := true   # 技能专属被动 skillPass.rate（skillMultiplier 起点）→ normalAdd（①）
static var NO_PILL_PASSIVES := true  # 万灵增元丹类被动 5974～5977 的开战状态天启篇不挂
static var COMBAT_RULES := true      # 暴击 ＋50%、战斗中敏捷 ×0.8 改读档位表全局规则 balance_table.combat_rules（数不变）

# ---- 期三「丹药下架」（设计稿第五节第 3 条）----
## 天启篇里这些丹药不上架、「使用」不可用并提示；背包里已有的不删、不收回。
## 已吃下去的：淬元丹计数天启篇不读（XPercentPills.param）；万灵增元丹类学到的被动 5974～5977 期二已不生效（NO_PILL_PASSIVES）；
## 一品到四品、养神丹、破厄丹加进永久加值合计（mv_param_plus），分不出来源、照算（只影响本地测试档）。
static var NO_PILLS := true
const PILL_RANGES := [[1497, 1500], [1685, 1700], [1702, 1717], [1726, 1728], [2882, 2887]]
const PILL_NOTICE := "天启篇已下架"


static func is_pill_item(id: int) -> bool:
	for r in PILL_RANGES:
		if id >= int(r[0]) and id <= int(r[1]):
			return true
	return false


## 这件物品在天启篇是不是已下架的丹药（开关开、天启篇存档）
static func pill_delisted(id: int) -> bool:
	return NO_PILLS and is_pill_item(id) and active()


## 淬元丹已吃的计数天启篇不读
static func pill_counts_ignored() -> bool:
	return NO_PILLS and active()


## 商店进货行 [类型 0物品/1武器/2防具, ID, …]：天启篇滤掉下架丹药
static func filter_pill_goods(rows: Array) -> Array:
	if not NO_PILLS or not active():
		return rows
	return rows.filter(func(g): return not (int(g[0]) == 0 and is_pill_item(int(g[1]))))


## 万灵增元丹类：物品 1497～1500 学到的被动（全属性 ×120%、结算伤害 ×120%／×150%、降敌暴击闪避），天启篇不生效
const PILL_PASSIVES := [5974, 5975, 5976, 5977]

static var _data: Dictionary = {}
static var _rows: Dictionary = {}
static var _load_failed := false
static var violations: Array = []
static var _reported := {}


static func data() -> Dictionary:
	if _data.is_empty():
		if _load_failed or XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiLedger: 读不到或解析不了 " + PATH)
			return {}
		_data = parsed
		_rows = {}
		for r in _data.get("rows", []):
			_rows[str(r.id)] = r
	return _data


static func reload() -> void:
	_data = {}
	_rows = {}
	_confirm_ids = {}
	_load_failed = false


static func phase() -> int:
	return int(data().get("phase", 1))


static func row(source: String) -> Dictionary:
	data()
	var r = _rows.get(source)
	return r if r is Dictionary else {}


static func active() -> bool:
	return XTianqi.active(XState.current)


static func auditing(a = null) -> bool:
	return GUARD and (a == null or a is XActor) and active() and not data().is_empty()


static func bucketing() -> bool:
	return BUCKETS and active() and not data().is_empty()


static func detail_on() -> bool:
	return DETAIL and active()


## 归池开关名 → 当前值（damage_ledger.json 的行用 "switch" 指过来；关着的行守卫当回退中、不报）
static func switch_on(name: String) -> bool:
	match name:
		"POOL_QIYIN": return POOL_QIYIN
		"POOL_ORB": return POOL_ORB
		"POOL_RACE": return POOL_RACE
		"POOL_ENEMY_RACE": return POOL_ENEMY_RACE
		"NO_SELF_RATE": return NO_SELF_RATE
		"POOL_SUIT": return POOL_SUIT
		"POOL_AFFIX_SKILL": return POOL_AFFIX_SKILL
		"POOL_SKILL_PASS": return POOL_SKILL_PASS
		"NO_PILL_PASSIVES": return NO_PILL_PASSIVES
		"COMBAT_RULES": return COMBAT_RULES
		"NO_PILLS": return NO_PILLS
		"CAP_NINE": return CAP_NINE
		"TURN_BUDGET": return TURN_BUDGET
	return true


## 这一样现在归不归池：开关开、天启篇存档（读不到总账表也照归：归池是数值口径，不靠守卫）
static func pool_on(name: String) -> bool:
	return switch_on(name) and active()


## 期二要关的全部开关（基准对照 --ledger=off、专项回退用）
static func set_all_p2(on: bool) -> void:
	POOL_QIYIN = on
	POOL_ORB = on
	POOL_RACE = on
	POOL_ENEMY_RACE = on
	NO_SELF_RATE = on
	POOL_SUIT = on
	POOL_AFFIX_SKILL = on
	POOL_SKILL_PASS = on
	NO_PILL_PASSIVES = on
	COMBAT_RULES = on


## 原版套装给的状态（XEquipSuits.ids "states"）里，确认阶段的「结果 ×k」（op mul、k>1，如铁头娃II 713 ×2）：
## 天启篇我方打敌人时改成 ＋(k−1) 进③（damage._calculate 加 finalAdd），确认阶段那一步对敌人的伤害不再乘（suit_confirm_rows 加 skipTypes）。
## 治疗、打自己人照旧乘（skipTypes 只在目标是敌人、伤害类型 1/2/5/6 时跳过）。返回 [[状态号, 效果], ...]
const SUIT_SKIP_TYPES := [1, 2, 5, 6]
const SUIT_POOLED := "_ledgerSuitPooled"

static func suit_confirm_effects(a) -> Array:
	var out := []
	if not a is XActor or not pool_on("POOL_SUIT"):
		return out
	for sid in XEquipSuits.ids(a, "states"):  # 套装状态不进 state_ids，只在 states() 里（XActor._actor_states_memo）
		for e in XDB.rec("States", int(sid)).get("effects", []):
			if e is Dictionary and str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) == "mul" and float(e.get("k", 1.0)) > 1.0:
				out.append([int(sid), e])
	return out


## damage._calculate：这一下（我方打敌人、伤害类型 dmg_type）套装确认阶段乘改进③的量
static func suit_confirm_add(a, b, dmg_type := 1) -> float:
	if not b is XEnemy or not dmg_type in SUIT_SKIP_TYPES:
		return 0.0
	var add := 0.0
	for pair in suit_confirm_effects(a):
		var e: Dictionary = pair[1]
		if bool(e.get("hpOnly", false)) and not dmg_type in [1, 5]:
			continue
		add += float(e.k) - 1.0
	return add


## XStateEffects.run("confirm")：把这些状态的那一步换成带 skipTypes 的副本（对敌人的伤害不乘，已进③）
static func suit_confirm_rows(holder, rows: Array) -> Array:
	var pairs := suit_confirm_effects(holder)
	if pairs.is_empty():
		return rows
	var ids := {}
	for pair in pairs:
		ids[int(pair[0])] = true
	var out := []
	for st in rows:
		if not ids.has(int(st.get("id", 0))):
			out.append(st)
			continue
		var copy: Dictionary = st.duplicate()
		var effects := []
		for e in st.get("effects", []):
			if e is Dictionary and str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) == "mul" and float(e.get("k", 1.0)) > 1.0:
				var e2: Dictionary = e.duplicate()
				e2.skipTypes = SUIT_SKIP_TYPES
				e2[SUIT_POOLED] = true  # audit_confirm 只认这个标记放行（期三收紧 T004 P3-1：原来凡带 skipTypes 的都放行）
				effects.append(e2)
			else:
				effects.append(e)
		copy.effects = effects
		out.append(copy)
	return out


## 天启篇里不挂开战状态的被动（XActor.battle_start_state_tags 跳过）
static func skips_passive(skill_id: int) -> bool:
	return PILL_PASSIVES.has(skill_id) and pool_on("NO_PILL_PASSIVES")


## 一个操作是不是「乘」：落在单独相乘字段上、且不是恒等（mul/set 1、add 0）
static func is_mul(op: Dictionary) -> bool:
	var f := str(op.get("field", ""))
	if not MUL_FIELDS.has(f):
		return false
	var kind := str(op.get("op", ""))
	var v := float(op.get("value", 1.0 if kind != "add" else 0.0))
	return not (v == 0.0 if kind == "add" else v == 1.0)


## 来源 source 在字段 field 上乘一次合不合规：返回 "" 合规，否则是原因
static func check(source: String, field: String) -> String:
	var r := row(source)
	if r.is_empty():
		return "unregistered"
	if not (r.get("fields", []) as Array).has(field):
		return "field_not_registered"
	if r.has("switch") and not switch_on(str(r.switch)):
		return ""  # 期二归池的回退开关关着：这一样回到单独相乘，是有意回退，不报
	match str(r.get("status", "")):
		"allowed":
			return ""
		"exempt":
			return "" if phase() < int(r.get("expires", 0)) else "exempt_expired"
		"pooled":
			return "pooled"
	return "bad_status"


static func _flag(source: String, field: String, reason: String, ctx: Dictionary) -> void:
	var v := {"source": source, "field": field, "reason": reason}
	v.merge(ctx)
	violations.append(v)
	var key := source + "|" + field + "|" + reason
	if not QUIET and not _reported.has(key):
		_reported[key] = true
		push_error("伤害加成总账：天启篇出现没登记的乘区 %s.%s（%s，技能 %s）——登记进 tianqi_data/damage_ledger.json 或归池" % [source, field, reason, str(ctx.get("skill", ""))])


## 守卫本体：damage._calculate 在钩子之后调用。trace＝注册表 dispatch 的 trace；facts 里 actorModules.tags 跟 ops 一一对应。
## extras：{skill_pass, race, independent}（不走钩子的三处，值是这一下的倍率）
static func audit(item: Dictionary, a, trace: Array, facts: Dictionary, extras: Dictionary) -> Array:
	var found := []
	if not auditing(a):
		return found
	var ctx := {"skill": int(item.get("id", 0)), "actor": int(a.actor_id) if a is XActor else 0}
	for t in trace:
		var mod := str(t.get("module", ""))
		var ops: Array = t.get("ops", [])
		var tags: Array = facts.get("actorModules", {}).get("tags", []) if mod == "actor-modules" else []
		for i in ops.size():
			var op = ops[i]
			if not op is Dictionary or not is_mul(op):
				continue
			var source: String = str(tags[i]) if i < tags.size() else str(MODULE_SOURCE.get(mod, "module:" + mod))
			var why := check(source, str(op.field))
			found.append({"source": source, "field": str(op.field), "op": str(op.op), "value": float(op.get("value", 0.0)), "ok": why == ""})
			if why != "":
				_flag(source, str(op.field), why, ctx)
	for pair in [["skill_pass", "skillMultiplier"], ["race", "race"], ["independent", "independent"]]:
		var v := float(extras.get(pair[0], 1.0))
		if v == 1.0:
			continue
		var source: String = {"skill_pass": "skill_pass", "race": "enemy_race_bonus", "independent": "self_rate"}[pair[0]]
		var why := check(source, pair[1])
		found.append({"source": source, "field": pair[1], "op": "mul", "value": v, "ok": why == ""})
		if why != "":
			_flag(source, pair[1], why, ctx)
	return found


## 原版状态确认阶段乘：只认登记的那批状态号（state_confirm_ids）
static var _confirm_ids := {}

static func state_confirm_registered(state_id: int) -> bool:
	if _confirm_ids.is_empty():
		for id in data().get("state_confirm_ids", []):
			_confirm_ids[int(id)] = true
	return _confirm_ids.has(state_id)


## 一个状态确认阶段效果的指纹（只取 phase＝confirm、op 不是 noop 的那几条，键排序后 md5 前 8 位）；
## damage_ledger.json 的 state_confirm_fp 存期一快照，专项比对：既有状态号的确认阶段效果改了也认得出（期一核查 P2）。
static func confirm_fingerprint(st: Dictionary) -> String:
	var effects := (st.get("effects", []) as Array).filter(func(e): return e is Dictionary and str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) != "noop")
	return "" if effects.is_empty() else JSON.stringify(effects, "", true).md5_text().substr(0, 8)


## 确认阶段（XStateEffects.run "confirm"）的运行期守卫（期一核查 P2：原来只在专项里认状态号，不过 check，到期也不报）：
## 天启篇我方打敌人时，身上每个带确认阶段效果的状态逐个认来源——套装状态那一步已进③（套装行，只认 suit_confirm_rows 打的 SUIT_POOLED 标记；
##   原版数据自带 skipTypes 的确认阶段效果照样要过 check，期三收紧）；天启篇难度被动等价行不算；
## 其余按 state_confirm 那一行判（没登记的状态号＝unregistered，到期＝exempt_expired）。只记不改数。
const CONFIRM_SYNTH := "天启篇·难度被动等价"

static func audit_confirm(holder, rows: Array, ctx: Dictionary) -> Array:
	var found := []
	if not auditing(holder) or not ctx.get("defender") is XEnemy:
		return found
	var ctxx := {"skill": int(ctx.get("item", {}).get("id", 0)), "actor": int(holder.actor_id)}
	for st in rows:
		if not st is Dictionary or str(st.get("name", "")) == CONFIRM_SYNTH:
			continue
		var effects := (st.get("effects", []) as Array).filter(func(e): return e is Dictionary and str(e.get("phase", "")) == "confirm" and str(e.get("op", "")) != "noop" and not bool(e.get(SUIT_POOLED, false)))
		if effects.is_empty():
			continue
		var sid := int(st.get("id", 0))
		var why := "" if state_confirm_registered(sid) else "unregistered"
		if why == "":
			why = check("state_confirm", "confirm")
		found.append({"source": "state_confirm", "state": sid, "ok": why == ""})
		if why != "":
			var c := ctxx.duplicate()
			c.state = sid
			_flag("state_confirm", "confirm#%d" % sid, why, c)
	return found


# ---- MODULE_CAP 白名单 ----
## 卡开着时模块的增伤默认拦；白名单 [{module, skill, field}] 才放（skill 0＝该模块全部技能）
static func whitelisted(module: String, skill: int, field: String) -> bool:
	for w in data().get("module_whitelist", []):
		if str(w.get("module", "")) == module and str(w.get("field", "")) == field and (int(w.get("skill", 0)) == 0 or int(w.get("skill", 0)) == skill):
			return true
	return false


# ---- 来源分桶（第五节第 4 条（3））----
const BUCKET_NAMES := {"secret": "秘籍格（功法、通用被动书）", "runeword": "符文之语", "orb": "宝珠", "equip": "原版装备", "race": "种族",
	"hubris": "成长装备", "tianqi": "天启篇自己的", "actor": "角色自带、技能", "state": "状态", "suit": "原版套装", "zhenqi": "真气"}


## 一个特性对象（装备实例、技能、状态）归哪个桶
static func bucket_of(o: Dictionary, a = null) -> String:
	if o.has("kind") and str(o.kind) in ["weapon", "armor"]:
		if o.has("qiyin") or o.has("tianqi_affixes") or o.has("tq_reward") or XTianqiAlienGear.is_tq(o):
			return "tianqi"
		if XHubris.is_gear(o):
			return "hubris"
		if not (o.get("runewords", []) as Array).is_empty() or str(o.get("runewordName", "")) != "":
			return "runeword"
		return "equip"
	if a is XActor and o.has("id") and not o.has("stypeId") and not is_same(o, a.data()) and not is_same(o, a.class_data()) \
			and XEquipSuits.ids(a, "states").has(int(o.id)):
		return "suit"  # 原版套装给的状态（期三九线封顶要分得出来）；角色、职业本体号可能和套装状态同号（赤狐 97 穿套装 55 给状态 97），先排掉（小A 核 P1）
	if a is XBattler and a.states().has(o):
		return "state"
	if o.has("stypeId"):
		var id := int(o.get("id", 0))
		if not XRace.skill_info(id).is_empty():
			return "race"
		if is_secret_skill(id, int(o.get("stypeId", 0))):
			return "secret"
		return "actor"
	return "actor"


## 秘籍格占格的技能（养成线 v0.3：功法、通用被动书、转换书都占格）：洪荒权能书，或者由物品「学会技能」（效果 43）教的
## 被动 4／其他 5／功法 6 类技能。不算：种族技能（种族桶）、天启篇号卷（另有 3／2／1 卷）、万灵增元丹被动（期二已不生效）、
## 没有书教的「其他」类（羁绊、套装这类角色自带的）。期三核查 P1：原来只认权能书和类型 5，真功法（6）、通用被动书（4）漏进角色桶、羁绊误占格。
static var _book_skills := {}
## 期三补（复核遗留）：超越极限 1240／1241／1242／1244 是进阶被动（XGojo、进阶给的），小药丸 CE645～648 开头 `var i = 1240` 只是要忘掉的旧被动，
## 被 `var kX = N` 那条规则顺带扫进来；诸葛孔明专属被动 2498 由伙伴号角招募事件（CE342）用「学会技能」给固定角色，_ce_skills 已按招募排掉。
const NOT_BOOK := [1240, 1241, 1242, 1244]

static func is_secret_skill(id: int, stype: int) -> bool:
	if PILL_PASSIVES.has(id) or XTianqiTrumpet.of_skill(id) != 0:
		return false  # 号卷占的是号卷格（3／2／1），不占秘籍格；号卷物品带 <CodexPower>，要先排掉
	if NOT_BOOK.has(id):
		return false  # 期三补：进阶被动「超越极限」，小药丸事件里只是忘掉的旧被动（见 NOT_BOOK）
	if XPowerBooks.is_power(id):
		return true
	if not stype in [4, 5, 6]:
		return false
	if _book_skills.is_empty():
		_book_skills[0] = true
		for it in XDB.table("Items"):
			if it is Dictionary:
				for e in it.get("effects", []):
					if int(e.get("code", 0)) == 43:
						_book_skills[int(e.get("dataId", 0))] = true
					elif int(e.get("code", 0)) == 44:
						_ce_skills(int(e.get("dataId", 0)))
	return _book_skills.has(id)


## 物品「公共事件」（效果 44）教的技能（复核 P2①：精通 5189～5308、谢幕 3680、莫等闲 3184、吾之剑道 3687、小药丸 5091～5098 这类）：
## 事件里的「增减技能·学会」（318）、脚本里写死的 learnSkill(N)，和精通系列脚本开头列的 var kX = N（穿心枪术精通★ 5214 只在这里出现）
static func _ce_skills(ce_id: int) -> void:
	var ces = XDB.table("CommonEvents")
	if not ces is Array or ce_id <= 0 or ce_id >= ces.size() or not ces[ce_id] is Dictionary:
		return
	var re_learn := RegEx.create_from_string("learnSkill\\((\\d+)\\)")
	var re_var := RegEx.create_from_string("var\\s+\\w+\\s*=\\s*(\\d+)\\s*;")
	# 期三补：伙伴号角的招募事件（同一事件里「增减队伍成员·加入」129 加的那个固定角色）用「学会技能」给的是角色专属被动，不是书
	var recruits := {}
	for c in ces[ce_id].get("list", []):
		var p0: Array = c.get("parameters", [])
		if int(c.get("code", 0)) == 129 and p0.size() > 1 and int(p0[1]) == 0:
			recruits[int(p0[0])] = true
	for c in ces[ce_id].get("list", []):
		var code := int(c.get("code", 0))
		var p: Array = c.get("parameters", [])
		if code == 318 and p.size() > 3 and int(p[2]) == 0:
			if int(p[0]) == 0 and recruits.has(int(p[1])):
				continue
			_book_skills[int(p[3])] = true
		elif code in [355, 655] and not p.is_empty():
			var line := str(p[0])
			for m in re_learn.search_all(line):
				_book_skills[int(m.get_string(1))] = true
			for m in re_var.search_all(line):
				var sid := int(m.get_string(1))
				if int(XDB.rec("Skills", sid).get("stypeId", 0)) == 4:
					_book_skills[sid] = true


static func _add(d: Dictionary, key, bucket: String, v: float) -> void:
	if v == 0.0:
		return
	var row: Dictionary = d.get(key, {})
	row[bucket] = float(row.get(bucket, 0.0)) + v
	d[key] = row


## 被动缓存的按来源分桶：和 _refresh_passive_now 同一批对象、同样的扫描，求和前按对象的桶分开记。
## 返回 {globalHarmRi: {桶: 值}, critHarmRi, skillTypeDvup: {类型: {桶: 值}}, SkETypeHarmRi, skillPass: {技能: {桶: rate}}, passiveELUP: {元素: {桶}}, elementAmplify: {元素: {桶}}}
static func passive_buckets(a, objs: Array) -> Dictionary:
	var out := {"globalHarmRi": {}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "passiveELUP": {}, "elementAmplify": {}}
	# 期三九线封顶：秘籍格按本数封，所以秘籍桶再并排按本记一份（同样的形状，桶名 "#技能号"）
	var books := {"globalHarmRi": {}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "passiveELUP": {}, "elementAmplify": {}}
	for o in objs:
		var bucket := bucket_of(o, a)
		var book := "#%d" % int(o.get("id", 0)) if bucket == "secret" else ""
		var sc := XActor._note_scans(str(o.get("note", "")))
		var meta: Dictionary = o.get("meta", {})
		var put := func(key: String, sub, v: float) -> void:
			for pair in [[out, bucket], [books, book]]:
				if pair[1] == "":
					continue
				if sub == null:
					_add(pair[0], key, pair[1], v)
				else:
					_add(pair[0][key], sub, pair[1], v)
		for m in sc[4]:
			put.call("globalHarmRi", null, float(m[0]) / 100.0)
		for m in sc[5]:
			put.call("critHarmRi", null, float(m[0]) / 100.0)
		for m in sc[2]:
			put.call("skillTypeDvup", str(m[0]), XActor._num(m[1]) / 100.0)
		for m in sc[3]:
			put.call("SkETypeHarmRi", int(m[0]), XActor._num(m[1]) / 100.0)
		for k in meta:
			var tag := str(k)
			if tag.begins_with("SkillPass") and str(meta[k]).contains("%"):
				put.call("skillPass", int(tag.substr(9)), XActor._num(meta[k]) / 100.0)
			elif tag.begins_with("passiveELUP") and o.has("stypeId"):
				put.call("passiveELUP", int(tag.substr(11)), XActor._num(meta[k]) / 100.0)
	out["books"] = books
	# 元素增幅（damage.own_bonus 的 elementAmplify 来源：状态＋装备＋角色＋职业）；宝珠镶进装备的那份单列
	var amp_objs: Array = a.states() + (a.stat_equips() if a.has_method("stat_equips") else []) + ([a.data(), a.class_data()] if a is XActor else [])
	for o in amp_objs:
		var amp: Dictionary = o.get("yep", {}).get("elementAmplify", {})
		if amp.is_empty():
			continue
		var bucket := bucket_of(o, a) if not (o is Dictionary and (is_same(o, a.data()) or is_same(o, a.class_data()))) else "actor"
		var orb := orb_amplify(o)
		for e in amp:
			var own := float(amp[e]) - float(orb.get(str(e), 0.0))
			_add(out.elementAmplify, int(e), bucket, own)
			_add(out.elementAmplify, int(e), "orb", float(orb.get(str(e), 0.0)))
	return out


## 装备孔里宝珠加的元素增幅（XOrbs.effect 的 ELEMENT AMPLIFY 行，按孔的类型取镶嵌行）
static func orb_amplify(eq: Dictionary) -> Dictionary:
	var out := {}
	var held: Array = eq.get("augmentSlotItems", [])
	for i in held.size():
		var gem := XOrbs.gem_in_slot(eq, i)
		if gem.is_empty():
			continue
		var p := XOrbs.parse(gem)
		var lines: Array = p.attach.get(XOrbs.socket_type(eq).to_upper(), [])
		for line in lines:
			var m := RegEx.create_from_string("(?i)ELEMENT AMPLIFY[ ](\\d+):[ ]([\\+\\-]\\d+)[%％]").search(str(line))
			if m:
				out[m.get_string(1)] = float(out.get(m.get_string(1), 0.0)) + float(m.get_string(2)) / 100.0
	return out


## 合计（期三九线封顶接这里：caps {桶: 上限}，不给就是原合计）
static func bucket_total(buckets: Dictionary, caps := {}) -> float:
	var total := 0.0
	for b in buckets:
		var v := float(buckets[b])
		total += minf(v, float(caps[b])) if caps.has(b) else v
	return total


# ---- 期三「回合预算」（设计稿第五节第 2 条）----
## 我方角色每人每回合最多多 1 次完整出手（1＋skill_rework.rules.max_extra_actions）：追加行动（插队）和再释放共用；
## 回合开始掷出来的再动、九九六插进顺序的那次也占（按「本回合已行动＋顺序里还排着的－1」算，不重复记）。
## 派生攻击、连击段数不占出手预算；派生攻击按 damage_ledger.json 的 derived 表各自每回合最多几次（take_derived）。
## 骑士、怪物不管（照旧）。预算记在战斗对象的 meta 上，每回合换号即清；不进存档。
static var TURN_BUDGET := true
const BUDGET_META := "xtq_turn_budget"


static func budget_on(logic, u) -> bool:
	return TURN_BUDGET and u is XActor and logic != null and active() and logic.actors.has(u)


static func _budget(logic) -> Dictionary:
	var b: Dictionary = logic.get_meta(BUDGET_META) if logic.has_meta(BUDGET_META) else {}
	if int(b.get("turn", -1)) != int(logic.turn):
		b = {"turn": int(logic.turn), "recast": {}, "free": {}, "derived": {}, "log": []}
		logic.set_meta(BUDGET_META, b)
	return b


static func max_extra() -> int:
	return int(XTianqiSkills.rules().get("max_extra_actions", 1))


## 本回合已经用掉的「多出来的完整出手」：已行动＋顺序里还排着的－1（不算不占预算的 free 插队）＋直接再释放的次数。
## in_action：在 u 自己这次行动的结算中途问（这次还没记进已行动）
static func extra_used(logic, u, in_action := false) -> int:
	var b := _budget(logic)
	var planned: int = int(logic._acted.get(u, 0)) + int(logic.current_order.count(u)) + (1 if in_action else 0) - int(b.free.get(u, 0))
	return maxi(0, planned - 1) + int(b.recast.get(u, 0))


## 统一入口：还有预算就扣掉、返回真；没有返回假（调用方就不插队／不再放）。不归预算管的（敌人、西游档、开关关）恒真。
## recast＝直接再打一次（不经行动顺序，要自己记数）；插队的调用方在返回真后自己 push_front（顺序里的次数就是记数）。
static func take_extra(logic, u, source: String, recast := false, in_action := false) -> bool:
	if not budget_on(logic, u):
		return true
	var b := _budget(logic)
	var ok := extra_used(logic, u, in_action) < max_extra()
	if ok and recast:
		b.recast[u] = int(b.recast.get(u, 0)) + 1
	b.log.append({"actor": int(u.actor_id), "source": source, "ok": ok})
	return ok


## 不占预算的插队（技能卡 free_action 里不造成伤害的）：记一笔，extra_used 扣掉它
static func note_free(logic, u) -> void:
	if budget_on(logic, u):
		var b := _budget(logic)
		b.free[u] = int(b.free.get(u, 0)) + 1


## 昏迷醒来补排当前回合（battle_logic._insert_orders）：不重掷，用「1＋max_extra − 已行动 − 已用预算」；-1＝不归预算管（照原来掷）
static func wake_times(logic, u) -> int:
	if not budget_on(logic, u):
		return -1
	var b := _budget(logic)
	return maxi(0, 1 + max_extra() - int(logic._acted.get(u, 0)) - int(b.recast.get(u, 0)))


## 派生攻击每回合次数（damage_ledger.json derived 表）：还没到上限就记一次、返回真
static func take_derived(logic, u, source: String) -> bool:
	if not budget_on(logic, u):
		return true
	var row: Dictionary = derived_row(source)
	if row.is_empty():
		_flag("derived:" + source, "per_turn", "unregistered", {"actor": int(u.actor_id)})
		return true
	var b := _budget(logic)
	var key := "%d|%s" % [int(u.actor_id), source]
	var n := int(b.derived.get(key, 0))
	if n >= int(row.get("per_turn", 0)):
		return false
	b.derived[key] = n + 1
	return true


static func derived_row(source: String) -> Dictionary:
	for r in data().get("derived", []):
		if str(r.get("id", "")) == source:
			return r
	return {}


# ---- 期三补「九线来源停用」（设计稿第五节第 2 条表下「九线来源停用（照 v0.1，并进上面的框架）」）----
## NINE_OFF：天启篇我方角色身上，九条养成线带来的多动、多段来源不生效（回合预算之外再收口；西游档、敌人照旧）：
## ① 攻击次数＋（特性 34）、追加行动（特性 61 号 0）：特性来自没有天启篇标记的装备（原版装备、套装件、符文之语、成长装备、人族首领法宝）、
##    原版套装给的状态、镶进任何装备的宝珠特性（_codexOrb）。角色、职业自带的，技能挂上的状态，天启篇装备上的，照算（不是九线）。
## ② <passiveAPLUS> 追加行动：秘籍格的书教的被动（is_secret_skill：功法、通用被动书、抽奖被动、权能书）和原版套装给的技能；
##    天启篇技能重构改写过的技能（技能卡开着时 XTianqiSkills.has）不停——改写稿自己定的再动数。
## ③ 真气道法「连击」「分神」：天启篇不生效（XActor.attack_times_add／action_plus_set 两处）。
## ④ 符文之语再释放 <AgainUseAll>（6 件符石）和被动 atkk：原版是 numRepeats 掷 +1 段；天启篇里只有小猫剑圣 XCat.native_repeats 读（西游档通用出手由 XBattleLogic.passive_repeats 读，T046，天启篇不走），按同样的来源停（XBattleLogic.passive_again）。
## 人族「九九六」走回合预算（race.human996），不在这里。开关关＝回到期三现状。
static var NINE_OFF := true
const NINE_OFF_BUCKETS := ["equip", "runeword", "hubris", "suit"]


static func nine_off(a) -> bool:
	return NINE_OFF and a is XActor and active()


## 一个对象（特性对象、装备、技能、状态）是不是要停的九线来源；不在天启篇／开关关恒假
static func nine_off_source(a, o) -> bool:
	if not nine_off(a) or not o is Dictionary:
		return false
	if o.has("stypeId"):
		return nine_off_skill(a, o)
	return bucket_of(o, a) in NINE_OFF_BUCKETS


static func nine_off_skill(a, sk: Dictionary) -> bool:
	var id := int(sk.get("id", 0))
	if XTianqiSkills.cards_on() and XTianqiSkills.has(id):
		return false
	return is_secret_skill(id, int(sk.get("stypeId", 0))) or XEquipSuits.ids(a, "skills").has(id)


## 天启篇留下的特性（code 34／61 用）：和 XActor.all_traits 同一批对象、同样次序，去掉九线来源的整份和宝珠特性
## （宝珠特性整份停，所以同族超上限丢掉的那几颗不用另算）
static func nine_kept_traits(a, code: int) -> Array:
	var out := []
	for o in a.trait_objects():
		if not o is Dictionary or nine_off_source(a, o):
			continue
		for t in o.get("traits", []):
			if int(t.code) == code and not t.has("_codexOrb"):
				out.append(t)
	return out


## 天启篇的特性 34 合计（Game_BattlerBase.attackTimesAdd 同口径，不小于 0）
static func nine_attack_times(a) -> float:
	var v := 0.0
	for t in nine_kept_traits(a, 34):
		v += float(t.value)
	return maxf(v, 0.0)


## 天启篇的特性 61 号 0 几率表 ＋ 留下的 <passiveAPLUS>（同 XActor.action_plus_set 前半段的次序）
static func nine_action_plus(a) -> Array:
	var out := []
	for t in nine_kept_traits(a, 61):
		if int(t.dataId) == 0:
			out.append(float(t.value))
	return out


static func nine_aplus_values(a) -> Array:
	var out := []
	for sk in a.skills():
		var m: Dictionary = sk.get("meta", {})
		if m.has("passiveAPLUS") and not nine_off_skill(a, sk):
			out.append(m.passiveAPLUS)
	return out


# ---- 期三「九线来源临时封顶」（设计稿第五节第 4 条；养成线三期逐条重做之前）----
## CAP_NINE：天启篇我方出手，九线来源进各池的量封顶（只扣超出的，不足的照算）：
## （1）秘籍格单列：按档位格数（balance_table 档位行 secret_cap：弱者 6、强者 4、超强者 3），每本书每个池最多 ＋8%；
##     学了超过格数的按「对伤害贡献」从高到低取前几本（临时规则：每本各池封后取最大值相加排序，同分技能号小的先），其余不算。
## （2）其余九线（符文之语、宝珠、原版装备与套装、种族、成长装备、真气）每个池合计封顶：①技能池 ＋15%、②元素池 ＋30%（每一系）、
##     ③伤害加成池 ＋35%（含种族祝福、宝珠共鸣、套装确认阶段 ＋(k−1) 这三条钩子来的量）；④暴击只封秘籍（稿子没给其余九线的数）。
## （3）属性 ＋30%：原版套装的属性倍率 × 符文之语、成长装备上的属性倍率特性（param_cap）；宝珠镶进装备的、原版装备本身的分不出来源，不封。
## 白印「持续伤害 ＋20%」（疫，不过伤害帧）不封（期二补记 3）。超出的量记在伤害详情 nineCap（「九线封顶」）。
static var CAP_NINE := true
const NINE_BUCKETS := ["runeword", "orb", "equip", "suit", "race", "hubris", "zhenqi"]
const NINE_DEFAULTS := {"skill": 0.15, "element": 0.30, "bonus": 0.35, "param": 0.30, "secret_slot": 0.08}


static func nine_cap(key: String) -> float:
	return float(data().get("nine_caps", {}).get(key, NINE_DEFAULTS[key]))


static func secret_slots(a) -> int:
	return XTianqiBalance.secret_cap(XTier.tier_of(a)) if a is XActor else 0


## 某一桶（或某一本书 "#id"）在这一下各池的量：skill（①，按这一招的技能类型、装备的武器类型、技能专属被动）、bonus（③）、crit（④）、element {e: ②}
static func _hit_share(by: Dictionary, b: String, hit: Dictionary) -> Dictionary:
	var skill := 0.0
	for wt in hit.wtypes:
		skill += float(by.SkETypeHarmRi.get(wt, {}).get(b, 0.0))
	for t in hit.types:
		skill += float(by.skillTypeDvup.get(str(t), {}).get(b, 0.0))
	if hit.pass_pooled:
		skill += float(by.skillPass.get(hit.skill, {}).get(b, 0.0))
	var elem := {}
	for e in by.elementAmplify:
		elem[int(e)] = float(elem.get(int(e), 0.0)) + float(by.elementAmplify[e].get(b, 0.0))
	for e in by.passiveELUP:
		elem[int(e)] = float(elem.get(int(e), 0.0)) + float(by.passiveELUP[e].get(b, 0.0))
	return {"skill": skill, "bonus": float(by.globalHarmRi.get(b, 0.0)), "crit": float(by.critHarmRi.get(b, 0.0)), "element": elem}


## 一本书各池封到 ＋8% 后的量
static func _book_capped(share: Dictionary, per: float) -> Dictionary:
	var elem := {}
	for e in share.element:
		elem[e] = minf(float(share.element[e]), per)
	return {"skill": minf(share.skill, per), "bonus": minf(share.bonus, per), "crit": minf(share.crit, per), "element": elem}


## 秘籍格：取前几本（按各池封顶后最大可能贡献；书号升序定次序）。返回生效的书 ["#id", ...]
static func secret_kept(a, by: Dictionary) -> Array:
	var books: Dictionary = by.get("books", {})
	var ids := {}
	for key in books:
		for sub in books[key]:
			var row = books[key][sub]
			if row is Dictionary:
				for b in row:
					ids[b] = true
			else:
				ids[sub] = true
	var per := nine_cap("secret_slot")
	var scored := []
	for b in ids:
		var score := minf(_max_of(books.globalHarmRi, b), per) + minf(_max_of(books.critHarmRi, b), per)
		score += minf(maxf(maxf(_max_nested(books.skillTypeDvup, b), _max_nested(books.SkETypeHarmRi, b)), _max_nested(books.skillPass, b)), per)
		score += minf(maxf(_max_nested(books.elementAmplify, b), _max_nested(books.passiveELUP, b)), per)
		scored.append([score, int(str(b).substr(1)), b])
	scored.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	return scored.slice(0, secret_slots(a)).map(func(x): return x[2])


static func _max_of(d: Dictionary, b: String) -> float:
	return float(d.get(b, 0.0))


static func _max_nested(d: Dictionary, b: String) -> float:
	var v := 0.0
	for k in d:
		v = maxf(v, float(d[k].get(b, 0.0)))
	return v


## damage._calculate：钩子之后、算乘区之前调用。扣掉这一下九线超出的部分（frame 的 normalAdd、finalAdd、criticalAdd、elementAdd），
## 记在 frame.nineCap。hooks＝{race, orb, suit}：种族祝福、宝珠共鸣、套装确认阶段这一下进③的量（钩子帧里分不出，调用方给）。
static func apply_nine_cap(item: Dictionary, a, frame: Dictionary, cache: Dictionary, hooks: Dictionary) -> Dictionary:
	if not CAP_NINE or not a is XActor or not active() or not cache.has("bySource"):
		return {}
	var by: Dictionary = cache.bySource
	var types := []
	var parsed = JSON.parse_string(str(item.get("meta", {}).get("SkillTypes", "[]")))
	if parsed is Array:
		types = parsed
	var wtypes := []
	for wt in by.SkETypeHarmRi:
		if (a as XActor).equip_list().any(func(e): return e.kind == "weapon" and int(e.wtypeId) == int(wt)):
			wtypes.append(wt)
	var hit := {"types": types, "wtypes": wtypes, "skill": int(item.get("id", 0)), "pass_pooled": pool_on("POOL_SKILL_PASS")}
	var cut := {"skill": 0.0, "bonus": 0.0, "crit": 0.0, "element": {}}
	# （1）秘籍格
	var raw_secret := _hit_share(by, "secret", hit)
	var kept := {"skill": 0.0, "bonus": 0.0, "crit": 0.0, "element": {}}
	var per := nine_cap("secret_slot")
	for b in secret_kept(a, by):
		var c := _book_capped(_hit_share(by.books, b, hit), per)
		for k in ["skill", "bonus", "crit"]:
			kept[k] += float(c[k])
		for e in c.element:
			kept.element[e] = float(kept.element.get(e, 0.0)) + float(c.element[e])
	for k in ["skill", "bonus", "crit"]:
		cut[k] += maxf(0.0, float(raw_secret[k]) - float(kept[k]))
	for e in raw_secret.element:
		var x := maxf(0.0, float(raw_secret.element[e]) - float(kept.element.get(e, 0.0)))
		if x > 0.0:
			cut.element[e] = x
	# （2）其余九线合计
	var nine := {"skill": 0.0, "bonus": float(hooks.get("race", 0.0)) + float(hooks.get("orb", 0.0)) + float(hooks.get("suit", 0.0)), "element": {}}
	for b in NINE_BUCKETS:
		var sh := _hit_share(by, b, hit)
		nine.skill += sh.skill
		nine.bonus += sh.bonus
		for e in sh.element:
			nine.element[e] = float(nine.element.get(e, 0.0)) + float(sh.element[e])
	cut.skill += maxf(0.0, nine.skill - nine_cap("skill"))
	cut.bonus += maxf(0.0, nine.bonus - nine_cap("bonus"))
	for e in nine.element:
		var x := maxf(0.0, float(nine.element[e]) - nine_cap("element"))
		if x > 0.0:
			cut.element[e] = float(cut.element.get(e, 0.0)) + x
	_cap_derived_elements(a, cut.element)
	if cut.skill == 0.0 and cut.bonus == 0.0 and cut.crit == 0.0 and cut.element.is_empty():
		return {}
	frame.normalAdd = float(frame.normalAdd) - cut.skill
	frame.finalAdd = float(frame.finalAdd) - cut.bonus
	frame.criticalAdd = float(frame.criticalAdd) - cut.crit
	for e in cut.element:
		frame.elementAdd[str(e)] = float(frame.elementAdd.get(str(e), 0.0)) - float(cut.element[e])
	frame.nineCap = cut
	return cut


## 虚空～风（11～15）的元素加成是 max(自身, 火～暗 2～9 里最低的一系)（XDamage.element_bonus）：照同样的取法算封顶前后，
## 差多少就扣多少（期三核查 P2③：原来只按 11～15 自己那份扣，借来的火～暗那份漏封）。cut：{元素: 扣的量}，就地改
static func _cap_derived_elements(a, cut: Dictionary) -> void:
	if cut.is_empty():
		return
	var low_raw := INF
	var low_cap := INF
	for c in [2, 3, 4, 5, 6, 7, 8, 9]:
		var own := XDamage.own_bonus(a, c)
		low_raw = minf(low_raw, own)
		low_cap = minf(low_cap, own - float(cut.get(c, 0.0)))
	for e in [11, 12, 13, 14, 15]:
		var own := XDamage.own_bonus(a, e)
		var x := maxf(own, low_raw) - maxf(own - float(cut.get(e, 0.0)), low_cap)
		if x > 0.0:
			cut[e] = x
		else:
			cut.erase(e)


## 钩子帧里种族祝福、宝珠共鸣写进③（finalAdd add）的量
static func hook_bonus(trace: Array, module: String) -> float:
	var v := 0.0
	for t in trace:
		if str(t.get("module", "")) != module:
			continue
		for op in t.get("ops", []):
			if op is Dictionary and str(op.get("field", "")) == "finalAdd" and str(op.get("op", "")) == "add":
				v += float(op.get("value", 0.0))
	return v


## 属性 ＋30%（XActor.param_rate 里乘）：九线来的属性倍率合计超过 ＋30% 时扣掉超出的部分。
## 口径跟实际一致（期三核查 P2②）：特性 21 在 XBattler.traits_pi 里是加算（1＋Σ(v−1)），原版套装属性倍率在外面另乘。
## 九线的份：符文之语、成长装备整件的特性 21；别的装备上宝珠镶进去的特性 21（XOrbs 打的 _codexOrb 标记）；套装倍率 (suit−1)。
## 超出的先从特性那份扣、不够再从套装那份扣；base＝不含套装的特性倍率（super.param_rate）。返回要再乘的系数。
static func param_cap(a, i: int, base: float, suit_rate: float) -> float:
	if not CAP_NINE or not a is XActor or not active():
		return 1.0
	var from_traits := 0.0
	# 同族宝珠超过上限丢掉的那几颗（XActor.all_traits 经 XOrbs.filter_traits 不算），这里也不算（复核 P1）。
	# stat_equips 可能是视图拷贝，按「装备实例号|宝珠标记」认，不靠同一对象
	var drops := XOrbs.cap_drops((a as XActor).equips)
	var dropped := {}
	for d in drops:
		for eq0 in (a as XActor).equips:
			if eq0 is Dictionary and str(eq0.get("instanceId", "")) != "" and (eq0.get("traits", []) as Array).any(func(t): return is_same(t, d)):
				dropped["%s|%s|%d" % [str(eq0.instanceId), str(d.get("_codexOrb", "")), int(d.get("dataId", -1))]] = true
	for eq in (a as XActor).stat_equips():
		var whole := bucket_of(eq) in ["runeword", "hubris"]
		for t in eq.get("traits", []):
			if t.has("_codexOrb") and (drops.any(func(d): return is_same(d, t)) or (str(eq.get("instanceId", "")) != "" \
					and dropped.has("%s|%s|%d" % [str(eq.instanceId), str(t._codexOrb), int(t.get("dataId", -1))]))):
				continue
			if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == i and (whole or t.has("_codexOrb")):
				from_traits += float(t.get("value", 1.0)) - 1.0
	var excess := from_traits + (suit_rate - 1.0) - nine_cap("param")
	if excess <= 0.0:
		return 1.0
	var cut_t := minf(excess, maxf(0.0, from_traits))
	var cut_s := excess - cut_t
	var f := 1.0
	if base > 0.0:
		f *= maxf(0.0, base - cut_t) / base
	if suit_rate > 0.0:
		f *= maxf(0.0, suit_rate - cut_s) / suit_rate
	return f


# ---- 五池明细（第四节第 1 条）----
## element_pool＝(1＋自身元素增幅＋elementAdd)（不含 elementMultiplier），其余照 damage._calculate 那一行的值
static func pools(frame: Dictionary, element: int, element_pool: float, normal: float, crit: float, tier: float, race: float, independent: float) -> Dictionary:
	var out := {"pools": {"skill": normal, "element": element_pool, "bonus": maxf(0.0, 1.0 + float(frame.finalAdd)), "crit": crit, "tier": tier},
		"residual": {"skillMultiplier": float(frame.skillMultiplier), "elementMultiplier": float(frame.elementMultiplier.get(str(element), 1.0)),
			"finalMultiplier": maxf(0.0, float(frame.finalMultiplier)), "race": race, "independent": independent,
			"physicalDamageMultiplier": float(frame.physicalDamageMultiplier), "magicalDamageMultiplier": float(frame.magicalDamageMultiplier)}}
	if frame.has("nineCap"):
		out["nineCap"] = frame.nineCap  # 「九线封顶」：这一下各池扣掉的量（期三）
	return out
