class_name XGarou
extends RefCounted
## 173 饿狼（正式 js/codex/runtime/installNativeGarouRuntime.js，W.CodexGarou）第一期：招募、开机同步、能力值与基础拳公式。
## - 形态 stage＝进阶次数（原版 a._AdvancedNum，重制读 XAdvance.rank），夹在 0～6。STAGES 照 G.config.stages 抄录。
## - 开机同步（Game_Actor.setup 包装 → G.sync ＋ recoverAll）：只留当前形态的形态状态（2644～2650）；
##   按 0～当前形态逐段「忘 forget、学 learn」得到应学的拳法，非 triggered 的拳法多退少补；
##   被动 10265～10269 按备注 CodexUnlockRank／CodexUnlockLevel 准入（准入就学、不准就忘）。升级（levelUp 包装）后再同步一次。
## - 学技能（learnSkill 包装）：10265～10269 未到形态或等级时不学（职业 20／30／45 级的 10266～10268 因此要进阶后才有）。
## - 公式 CodexGarou.base(a,b,id)：per_hit_formula 去掉 *CURRENT_FORM_SCALE，A＝atk、M＝mat；在 CodexDamage 结算里 D＝R＝0
##   （防御另由结算按物防／魔防率处理），再 × 当前形态 damage_scale。非饿狼或非饿狼拳法为 0。
## - 招募（公共事件 9009 的 CodexGarou.recruit()）：已在队返回 false；没戴饿狼法宝时，背包里有就拿、没有就生成当前形态的
##   独立法宝（人类形态 7904「破限之心·人类」）装进装备类型 13 的槽；同步、入队，提示「饿狼加入队伍，获得并装备破限之心。」。
## 第二期（参照 garou_progress_probe → tests/fixtures/garou_progress_oracle.json，测试 tests/xiyou_garou_progress.gd）：
## - 形态能力倍率（paramRate 包装，XActor.param_rate 经 XActorModules）：× 形态 form_multiplier（生命、物攻、物防、魔攻、魔防、敏捷；
##   魔法、幸运恒 1）；没学 10269 破限成长时按人类形态（全 1）。上限 paramMax 999999999999 在 XActor.param_max。
## - 每回合行动（makeActionTimes 包装，XBattleLogic.make_action_times）：形态 actions_per_round（四臂、星空 2），没学 10269 为 1；
##   整个取代原版，不再掷追加行动。
## - 累计突破（a._garouBreakthroughs，重制存 XState.garou.breakthroughs，存档 codexGarou）：胜利（processVictory 之前，
##   XBattleLogic.grant）开战时在出战栏的饿狼 +1，Boss 战（敌群有 MOG_BossHP 血条的成员）+5，夹到下一形态的门槛（星空 333）；
##   四臂以上、50 级、333 突破的 Boss 战得一次神之触媒 2939（catalyst 记已给过），提示「饿狼突破神之境界，获得神之触媒×1。」
##   （存进 XBattleLogic.victory_texts，画面还没接）。同步时夹到当前门槛。
## - 进阶（Scene_ActorAdvanced 包装，XAdvance.missing／advance 分派到 reason／advance）：条件依次是有下一形态、等级、累计突破、
##   四臂进星空要神之触媒 ×1；进阶＝遗忘 → 学会 → 形态 +1 → 同步（含法宝进化）→ 星空扣 1 个神之触媒（原版表里的金钱、物品不再另扣）。
##   熟练度继承（skillMasteryLevel／Uses）重制没有熟练度，不做；原版出错回滚（snapshotProgression）GDScript 无异常，不做。
## - 法宝进化（G.evolveRelic，同步时）：戴着的饿狼法宝换成当前形态的模板，保留实例与旧模板的差值——能力值、特性（比率类连乘、
##   加值类相加后求差，其他特性按条带走）、多出的备注行；等级、经验、自定名字保留（名字含旧模板名的换成新模板名）。
##   换装（changeEquip 包装，XEquipment.change）后同步一次。法宝只给饿狼由备注 <req_actors: 173> 管（XActor.can_equip）。
## 原版的不合理处（不照搬）：describeRelic 每次同步往法宝备注写 <CodexGarouHelp> 说明块，进化时旧说明块被当成额外备注行带走、
##   再被正则半删，备注里残留旧形态说明行（界面层；重制备注里不写说明块）。
## 未移植（第三期起）：进化／解析／反击／追击与伤害钩子 garou、itemCnt、技能使用条件（认真一拳要琦玉模式）、技能分类与指令窗、
## 进阶界面的饿狼提示（重制走 XAdvance.fail_text）、星空外观 Garou_Cosmic、法宝说明 describeRelic、图鉴立绘、旧档迁移（不迁移 MV 旧存档）。
## 参照：slice_probe（切片角色行与伤害行）、actor_passive_probe（各等级技能表）、garou_progress_probe；测试 tests/xiyou_actor_modules.gd、tests/xiyou_garou_progress.gd。

const ACTOR := 173
const HORN := 2940
const RELICS := [7904, 7905, 7906, 7908, 7909, 7910, 7911]
const STATES := [2644, 2645, 2646, 2647, 2648, 2649, 2650]
## 形态：damage_scale、每回合行动、学／忘的拳法（G.config.stages 的 learn_skill_ids／forget_skill_ids）、
## 能力倍率 form_multiplier（按 paramRate 序：生命、魔法、物攻、物防、魔攻、魔防、敏捷、幸运）、进阶要的等级 minimum_level 与累计突破
const STAGES := [
	{"scale": 66, "actions": 1, "learn": [10250], "forget": [], "rate": [1, 1, 1, 1, 1, 1, 1, 1], "level": 1, "breakthroughs": 0},
	{"scale": 188, "actions": 1, "learn": [10251], "forget": [10250], "rate": [1.11, 1, 1.11, 1.11, 1, 1.11, 1.11, 1], "level": 20, "breakthroughs": 33},
	{"scale": 999, "actions": 1, "learn": [10252], "forget": [10251], "rate": [1.33, 1, 1.33, 1.22, 1.11, 1.22, 1.33, 1], "level": 30, "breakthroughs": 66},
	{"scale": 3888, "actions": 1, "learn": [10253, 10254], "forget": [10252], "rate": [1.66, 1, 1.66, 1.33, 1.22, 1.33, 1.66, 1], "level": 40, "breakthroughs": 99},
	{"scale": 3999, "actions": 1, "learn": [10255, 10256], "forget": [10253], "rate": [1.88, 1, 2.22, 1.5, 1.33, 1.5, 1.88, 1], "level": 45, "breakthroughs": 166},
	{"scale": 5000, "actions": 2, "learn": [10257], "forget": [10256], "rate": [2.22, 1, 3.33, 1.66, 1.66, 1.66, 2.22, 1], "level": 50, "breakthroughs": 266},
	{"scale": 7000, "actions": 2, "learn": [10259, 10260, 10261, 10262, 10263], "forget": [10255, 10257, 10254], "rate": [3.33, 1, 5, 2.22, 5, 2.22, 3.33, 1], "level": 60, "breakthroughs": 333},
]
## G.config.skills 里 role 不是 triggered 的拳法（10258 神杀瞬击是追击，不由同步学忘）
const FISTS := [10250, 10251, 10252, 10253, 10254, 10255, 10256, 10257, 10259, 10260, 10261, 10262, 10263]
const TRIGGERED := 10258
const PASSIVES := [10265, 10266, 10267, 10268, 10269]
## 各拳法 per_hit_formula 去掉 *CURRENT_FORM_SCALE 后、D＝R＝0 时剩下的系数：[A 系数, M 系数]
const COEFF := {10250: [1.88, 0.0], 10251: [1.88, 0.0], 10252: [3.33, 0.0], 10253: [3.33, 0.0], 10254: [3.33, 0.0],
	10255: [3.33, 0.0], 10256: [22.22, 0.0], 10257: [33.33, 0.0], 10258: [3.33, 0.0], 10259: [6.66, 9.99],
	10260: [9.99, 6.66], 10261: [3.33, 6.66], 10262: [0.0, 0.0], 10263: [99.99, 66.66]}
const RECRUIT_TEXT := "饿狼加入队伍，获得并装备破限之心。"
const GROWTH := 10269
const CATALYST := 2939
const CATALYST_TEXT := "饿狼突破神之境界，获得神之触媒×1。"
## garouTraits：比率类（连乘求比）与加值类（相加求差）特性代码
const RATE_CODES := [11, 12, 13, 21, 23]
const ADD_CODES := [22, 32, 61]
## 说明卡用（G.config.stages 的 name 与 passives：进化每层增伤、解析每层无视物防／魔防，均为百分数）
const FORM_NAMES := ["人类", "赤发", "半怪人", "螺旋", "翼化", "四臂", "星空"]
const FORM_PASSIVES := [[false, 0, false, 0, 0], [true, 16, false, 0, 0], [true, 22, true, 11, 0], [true, 33, true, 16, 0],
	[true, 50, true, 22, 0], [true, 66, true, 33, 0], [true, 99, true, 33, 33]]


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(_a = null) -> int:
	return clampi(XAdvance.rank(XState.current, ACTOR), 0, 6)


## G.form(a)（说明卡用）：当前形态；进化／解析要学了 10266／10267 才算开，没学 10269 每回合只行动 1 次。a 为 null（预览）时按什么都没学
static func form(a) -> Dictionary:
	var i := stage(a)
	var p: Array = FORM_PASSIVES[i]
	var learned := func(id): return a != null and a.skill_ids.has(id)
	var analysis: bool = p[2] and learned.call(10267)
	return {"name": FORM_NAMES[i], "scale": STAGES[i].scale, "actions": STAGES[i].actions if learned.call(GROWTH) else 1,
		"passives": {"evolution_enabled": p[0] and learned.call(10266), "evolution_base_per_stack_percent": p[1],
			"analysis_defense_ignore_percent_per_stack": p[3] if analysis else 0, "analysis_magic_defense_ignore_percent_per_stack": p[4] if analysis else 0}}


## learnSkill 包装：被动按形态与等级准入
static func can_learn(a, id: int) -> bool:
	return not own(a) or not PASSIVES.has(id) or _passive_allowed(a, id)


static func _passive_allowed(a, id: int) -> bool:
	var meta: Dictionary = XDB.rec("Skills", id).get("meta", {})
	return stage(a) >= int(str(meta.get("CodexUnlockRank", "0")).to_int()) and int(a.level) >= maxi(1, int(str(meta.get("CodexUnlockLevel", "1")).to_int()))


## G.sync（setup、levelUp 后）：被动准入 → 形态状态 → 拳法
static func sync(a) -> void:
	if not own(a):
		return
	for id in PASSIVES:
		var allowed := _passive_allowed(a, id)
		if allowed and not a.skill_ids.has(id):
			a.learn_skill(id)
		elif not allowed and a.skill_ids.has(id):
			a.forget_skill(id)
	var s := XState.current
	if s != null:
		s.garou["breakthroughs"] = breakthroughs(a)  # G.sync：累计突破夹到当前门槛
	var st := stage(a)
	for i in STATES.size():
		if i != st and a.state_ids.has(STATES[i]):
			a.remove_state(STATES[i])
	if not a.state_ids.has(STATES[st]):
		a.add_state(STATES[st])
	var desired := []
	for i in st + 1:
		desired = desired.filter(func(id): return not STAGES[i].forget.has(id))
		desired.append_array(STAGES[i].learn)
	for id in FISTS:
		if desired.has(id) and not a.skill_ids.has(id):
			a.learn_skill(id)
		elif not desired.has(id) and a.skill_ids.has(id):
			a.forget_skill(id)
	evolve_relic(a)
	a.refresh_passive()


## Game_Actor.setup 包装：同步后回满
static func setup(a) -> void:
	if own(a):
		sync(a)
		a.recover_all()


static func level_up(a) -> void:
	sync(a)


## CodexGarou.base(a,b,id)
static func formula(a, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not own(a) or not COEFF.has(id):
		return 0.0
	var c: Array = COEFF[id]
	return maxf(0.0, float(a.atk) * c[0] + float(a.mat) * c[1]) * STAGES[stage(a)].scale


static func is_relic(e) -> bool:
	return e is Dictionary and not e.is_empty() and str(e.get("kind", "")) == "armor" and RELICS.has(int(e.get("base", e.get("id", 0))))


## CodexGarou.recruit()
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	var slot := a.equip_slots().find(13)
	if slot < 0:
		push_error("[xiyou] 饿狼法宝槽不存在")
		return false
	if not a.equips.any(is_relic):
		var idx := s.gear.find_custom(is_relic)
		if idx < 0:
			s.gain_gear("armor", RELICS[stage(a)], 1)
			idx = s.gear.size() - 1
		var relic: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if a.equips[slot] is Dictionary and not a.equips[slot].is_empty():
			s.gear.append(a.equips[slot])
		a.equips[slot] = relic
	sync(a)
	s.add_actor(ACTOR)
	return true


## paramRate 包装：形态能力倍率（没学 10269 按人类形态）
static func param_rate(a, i: int) -> float:
	if not own(a) or not a.skill_ids.has(GROWTH):
		return 1.0
	return float(STAGES[stage(a)].rate[i])


## makeActionTimes 包装：形态每回合行动次数（没学 10269 为 1）
static func action_times(a) -> int:
	return int(STAGES[stage(a)].actions) if a.skill_ids.has(GROWTH) else 1


# ---- 累计突破与神之触媒（XState.garou：breakthroughs、catalyst）----
## G.breakthroughCap：下一形态的门槛（星空取星空的 333）
static func breakthrough_cap(a = null) -> int:
	return int(STAGES[mini(stage(a) + 1, 6)].breakthroughs)


static func _raw_breakthroughs() -> float:
	var s := XState.current
	return float(s.garou.get("breakthroughs", 0)) if s != null else 0.0


## G.breakthroughs：取整、夹到 0～门槛
static func breakthroughs(a = null) -> int:
	return mini(breakthrough_cap(a), maxi(0, floori(_raw_breakthroughs())))


## Boss 战：敌群（含隐藏成员）有 MOG_BossHP 血条（插件参数 boss-N 列的敌人编号，_bosshp_meter）
static var _boss_ids := {}


static func boss_meter(enemy_id: int) -> bool:
	if _boss_ids.is_empty():
		var p := XDB.plugin("MOG_BossHP")
		for k in p:
			if RegEx.create_from_string("^boss-\\d+$").search(str(k)) and str(p[k]).strip_edges().is_valid_int():
				_boss_ids[int(str(p[k]).strip_edges())] = true
		_boss_ids[0] = false
	return bool(_boss_ids.get(enemy_id, false))


## BattleManager.startBattle 包装：同步一次，记下出战栏里的饿狼（胜利时只给他记突破）
static func start_battle(actors: Array) -> Variant:
	clear_battle()  # G.clearBattle（开战）
	var a = null
	for b in actors:
		if own(b):
			a = b
			break
	if a != null:
		sync(a)
	return a


## G._bossBattle：开战时敌群（含隐藏成员）有 Boss 血条的成员
static func boss_battle(enemies: Array) -> bool:
	return enemies.any(func(e): return boss_meter(int(e.data().get("id", 0))))


## G.creditVictory（processVictory 之前，每场一次）：返回要提示的文字（没有为空）
static func credit_victory(s: XState, a, boss: bool) -> String:
	if a == null or s == null:
		return ""
	s.garou["breakthroughs"] = mini(breakthrough_cap(a), breakthroughs(a) + (5 if boss else 1))
	if boss and stage(a) >= 5 and int(a.level) >= 50 and int(s.garou.breakthroughs) >= 333 and not bool(s.garou.get("catalyst", false)):
		s.gain_item(CATALYST, 1)
		s.garou["catalyst"] = true
		return CATALYST_TEXT
	return ""


# ---- 进阶 ----
## G.reason：空＝可以进阶（累计突破按存的原值比，不先夹）
static func reason(s: XState, a) -> String:
	if not own(a):
		return "角色不匹配"
	var st := stage(a)
	if st >= 6:
		return "已达到星空形态"
	var next: Dictionary = STAGES[st + 1]
	if int(a.level) < int(next.level):
		return "需要等级%d" % int(next.level)
	var bt := _raw_breakthroughs()
	if bt < float(next.breakthroughs):
		return "累计突破需要%d，当前%s" % [int(next.breakthroughs), _js_num(bt)]
	if st == 5 and s.item_count(CATALYST) < 1:
		return "需要神之触媒×1"
	return ""


static func _js_num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## G.advance(a, expectedStage)：expected 不是当前形态时作废；条件不足返回原因
static func advance(s: XState, a, expected: int) -> Dictionary:
	if not own(a):
		return {"ok": false, "reason": "角色不匹配"}
	if expected != stage(a):
		return {"ok": false, "reason": "进阶确认已失效，请重新选择"}
	var why := reason(s, a)
	if why != "":
		return {"ok": false, "reason": why}
	var next: Dictionary = STAGES[expected + 1]
	for id in next.forget:
		a.forget_skill(int(id))
	for id in next.learn:
		a.learn_skill(int(id))
	s.actor_advance[ACTOR] = expected + 1
	sync(a)
	if expected + 1 == 6:
		s.gain_item(CATALYST, -1)
	return {"ok": true, "stage": expected + 1}


# ---- 法宝进化（G.evolveRelic）----
static func gear(a) -> Variant:
	for e in a.equips:
		if is_relic(e):
			return e
	return null


## 戴着的法宝换成当前形态的模板；已是当前形态（garouStage＋模板版本 2）返回 false
static func evolve_relic(a) -> bool:
	var item = gear(a)
	var st := stage(a)
	if item == null or (int(item.get("garouStage", -1)) == st and int(item.get("garouTemplateVersion", 0)) == 2):
		return false
	var prev_id := int(item.get("base", item.get("id", 0)))
	var raw_prev := XDB.rec("Armors", prev_id)
	var raw_base := XDB.rec("Armors", RELICS[st])
	if raw_prev.is_empty() or raw_base.is_empty() or not RELICS.has(prev_id):
		push_error("[xiyou] 无法识别饿狼原法宝模板 %d" % prev_id)
		return false
	var prev := XGear.template("armor", prev_id)
	var base := XGear.template("armor", RELICS[st])
	var old_name := str(prev.name)
	var name := str(item.get("name", old_name))
	var params := []
	for i in 8:
		params.append(float(base.params[i]) + _num(item.params[i] if i < item.params.size() else 0) - _num(prev.params[i]))
	var traits := _traits(prev.traits, base.traits, item.get("traits", []))
	var notes := Array(str(base.get("note", "")).split("\n"))
	notes.append_array(_extras(Array(str(item.get("note", "")).replace("\r\n", "\n").split("\n")), Array(str(prev.get("note", "")).replace("\r\n", "\n").split("\n"))))
	for k in raw_base:
		if not ["id", "level", "exp", "name", "params", "traits", "note"].has(k):
			var v = _blend(raw_prev.get(k), raw_base[k], item.get(k))
			if v == null:
				item.erase(k)
			else:
				item[k] = v
	item.params = params
	item.traits = traits
	item.note = "\n".join(notes)
	item.base = float(RELICS[st])
	item.iconIndex = raw_base.get("iconIndex", item.get("iconIndex", 0))
	item.name = _rename(name, old_name, str(base.name))
	if item.has("baseName"):
		item.baseName = _rename(str(item.baseName), old_name, str(base.name))
	item.garouOwner = ACTOR
	item.garouStage = st
	item.garouTemplateVersion = 2
	return true


static func _rename(name: String, old_name: String, new_name: String) -> String:
	if name == old_name:
		return new_name
	return name.replace(old_name, new_name) if name.contains(old_name) else name


static func _num(v) -> float:
	return float(v) if v is int or v is float else 0.0


static func _key(v) -> String:
	return JSON.stringify(v, "", false)


## garouExtras：values 里扣掉 baseline 逐条配对后多出来的
static func _extras(values: Array, baseline: Array) -> Array:
	var pending := baseline.map(func(v): return _key(v))
	var out := []
	for v in values:
		var i := pending.find(_key(v))
		if i >= 0:
			pending.remove_at(i)
		else:
			out.append(v.duplicate(true) if v is Dictionary or v is Array else v)
	return out


## garouBlend：实例没改过（等于旧模板）就取新模板；数组＝新模板＋实例多出的；对象逐键；其他保留实例的
static func _blend(old_base, new_base, current):
	if current == null or _key(current) == _key(old_base):
		return new_base.duplicate(true) if new_base is Dictionary or new_base is Array else new_base
	if new_base is Array and current is Array:
		var out: Array = new_base.duplicate(true)
		out.append_array(_extras(current, old_base if old_base is Array else []))
		return out
	if new_base is Dictionary and current is Dictionary:
		var result := {}
		var keys := []
		for o in [old_base if old_base is Dictionary else {}, new_base, current]:
			for k in o:
				if not keys.has(k):
					keys.append(k)
		for k in keys:
			var v = _blend(old_base.get(k) if old_base is Dictionary else null, new_base.get(k), current.get(k))
			if v != null:
				result[k] = v
		return result
	return current.duplicate(true) if current is Dictionary or current is Array else current


## garouTraits：比率类、加值类按 代码:数据 归组，把实例相对旧模板的变化（乘／差）追加到新模板后面；其他特性按条带走
static func _traits(old_base: Array, new_base: Array, current: Array) -> Array:
	var groups := {}
	var out: Array = new_base.duplicate(true)
	for pair in [[old_base, "old"], [current, "current"]]:
		for t in pair[0]:
			var code := int(t.code)
			if not RATE_CODES.has(code) and not ADD_CODES.has(code):
				continue
			var key := "%d:%d" % [code, int(t.dataId)]
			if not groups.has(key):
				groups[key] = {"code": code, "dataId": int(t.dataId), "rate": RATE_CODES.has(code), "old": [], "current": []}
			groups[key][pair[1]].append(float(t.value))
	for key in groups:
		var g: Dictionary = groups[key]
		var old := _fold(g.old, g.rate)
		var now := _fold(g.current, g.rate)
		var delta := ((now if now != 0.0 else 1.0) if old == 0.0 else now / old) if g.rate else now - old
		if absf(delta - (1.0 if g.rate else 0.0)) > 1e-10:
			out.append({"code": g.code, "dataId": g.dataId, "value": delta})
	var other := func(t): return not RATE_CODES.has(int(t.code)) and not ADD_CODES.has(int(t.code))
	out.append_array(_extras(current.filter(other), old_base.filter(other)))
	return out


static func _fold(values: Array, rate: bool) -> float:
	var v := 1.0 if rate else 0.0
	for n in values:
		v = v * n if rate else v + n
	return v


static func to_save(v: Dictionary) -> Dictionary:
	return {"breakthroughs": float(v.get("breakthroughs", 0)), "catalyst": bool(v.get("catalyst", false))}


static func from_save(v) -> Dictionary:
	if not v is Dictionary:
		return {}
	return {"breakthroughs": float(v.get("breakthroughs", 0)), "catalyst": bool(v.get("catalyst", false))}


# ---- 第三期：战斗内被动（进化、解析、反击、追击，参照 garou_battle_probe）----
## 破限之心每层进化另加（G.config.stages[*].relic.evolution_bonus_per_stack_percent，按当前形态、戴着法宝才加）
const RELIC_EVOLUTION := [3, 5, 7, 11, 15, 18, 22]
const WATER := 10250
const MODE := 10262
const SERIOUS := 10263
## 每个形态的主拳（G.main）：追击、反击借它的熟练度（重制没有熟练度，只记）
const MAIN := [10250, 10251, 10252, 10253, 10255, 10255, 10259]
## G.config.skills 的 stage（未到形态不能用）
const SKILL_STAGE := {10250: 0, 10251: 1, 10252: 2, 10253: 3, 10254: 3, 10255: 4, 10256: 4, 10257: 5, 10258: 4, 10259: 6,
	10260: 6, 10261: 6, 10262: 6, 10263: 6}
## 原版 33% 反击（Math.random() < .33）
const COUNTER_RATE := 0.33

## 战斗数据（a._garouEvolution／_garouAnalysis／_garouReceivedThisRound／_garouSaitama）：开战、结束战斗清空
static var evolution := 0
static var analysis := {}
static var received := false
static var saitama := false
## 施放帧（action._garouFrame）：施放开始时的进化层、各目标第一次被打时的解析层、是否命中与伤害
static var frame := {}


static func is_fist(item) -> bool:
	return item is Dictionary and SKILL_STAGE.has(int(item.get("id", 0))) and not XBattleLogic.is_item(item)


static func _hp_damage(item: Dictionary) -> bool:
	return int(item.get("damage", {}).get("type", 0)) == 1


## G.form 包装后的被动开关（学了对应被动才开）：反击 10265、进化 10266、解析 10267、追击 10268
static func passives(a) -> Dictionary:
	var st := stage(a)
	var p: Array = FORM_PASSIVES[st]
	var learned := func(id): return a != null and a.skill_ids.has(id)
	var ana: bool = p[2] and learned.call(10267)
	return {"counter": learned.call(10265), "evolution": p[0] and learned.call(10266), "evolution_percent": int(p[1]),
		"analysis": ana, "def_percent": int(p[3]) if ana else 0, "mdf_percent": int(p[4]) if ana else 0,
		"followup": st >= 4 and learned.call(10268)}


static func clear_battle() -> void:
	evolution = 0
	analysis = {}
	received = false
	saitama = false
	frame = {}


static func layers(b) -> int:
	return int(analysis.get(b, 0))


## G.addAnalysis：解析开着时给目标加一层，最多 3
static func add_analysis(a, b) -> void:
	if b == null or not passives(a).analysis:
		return
	analysis[b] = mini(3, layers(b) + 1)


## G.beginAction（BattleManager.startAction）：任何人的行动都开新帧
static func begin(u, skill) -> void:
	frame = {"user": u, "skill": skill, "evolution": evolution, "targets": [], "finished": false, "triggered": ""}


## G.targetRow：本帧对这个目标的记录（第一次碰到时记下解析层）
static func target_row(b) -> Dictionary:
	for row in frame.get("targets", []):
		if is_same(row.target, b):
			return row
	var row := {"target": b, "analysis": layers(b) if own(frame.get("user")) else 0, "hit": false, "damage": 0.0}
	if not frame.is_empty():
		frame.targets.append(row)
	return row


## 伤害钩子 garou（CodexDamageHooks）：解析无视物防／魔防、按公式定物理／混合、进化增伤
static func damage_ops(item: Dictionary, a, b) -> Array:
	if not own(a) or not is_fist(item):
		return []
	var id := int(item.id)
	var p := passives(a)
	var in_frame := not frame.is_empty() and is_same(frame.user, a)
	var n: int = target_row(b).analysis if in_frame and b != null else layers(b)
	var e: int = int(frame.evolution) if in_frame else evolution
	if not p.evolution:
		e = 0
	var extra: int = RELIC_EVOLUTION[stage(a)] if gear(a) != null else 0
	var c: Array = COEFF.get(id, [0.0, 0.0])
	return [{"op": "mul", "field": "physicalDefenseRate", "value": 1.0 - minf(0.99, n * p.def_percent / 100.0)},
		{"op": "mul", "field": "magicalDefenseRate", "value": 1.0 - minf(0.99, n * p.mdf_percent / 100.0)},
		{"op": "set", "field": "mode", "value": "mixed" if float(c[1]) != 0.0 and float(c[0]) != 0.0 else ("magical" if float(c[1]) != 0.0 else "physical")},
		{"op": "mul", "field": "skillMultiplier", "value": 1.0 + e * (int(p.evolution_percent) + extra) / 100.0}]


## Game_Action.apply 包装：本帧（不是追击／反击）记命中与伤害；模式：琦玉命中自己开琦玉模式
static func applied(u, skill: Dictionary, t, r: Dictionary, used: bool) -> void:
	var hit: bool = used and not bool(r.get("missed", false)) and not bool(r.get("evaded", false))
	if not frame.is_empty() and is_same(frame.user, u) and str(frame.triggered) == "":
		var row := target_row(t)
		row.hit = row.hit or hit
		row.damage = float(row.damage) + maxf(0.0, float(r.get("hp", 0.0)))
	if own(u) and int(skill.get("id", 0)) == MODE and is_same(t, u) and hit:
		saitama = true


## itemCnt 包装：饿狼不被原生反击
static func no_counter(t) -> bool:
	return own(t)


## meetsSkillConditions 包装：未到形态的拳法、追击不能用；认真一拳要琦玉模式（输入阶段已排了模式：琦玉的不做，重制没有预排）
static func meets(a, skill: Dictionary) -> bool:
	if not own(a) or not is_fist(skill):
		return true
	var id := int(skill.id)
	if int(SKILL_STAGE[id]) > stage(a) or id == TRIGGERED:
		return false
	return id != SERIOUS or saitama


## G.trigger：追击／反击，直接 apply（不经 startAction／endAction）；返回战斗记录
static func trigger(logic, a, b, id: int, kind: String, evo := -1) -> Array:
	if a == null or b == null or not a.is_alive() or not b.is_alive():
		return []
	var saved := frame
	frame = {"user": a, "skill": XDB.rec("Skills", id), "evolution": evolution if evo < 0 else evo, "targets": [], "finished": false, "triggered": kind}
	var used: bool = b.is_alive()
	var r: Dictionary = logic.apply(a, XDB.rec("Skills", id), b)
	r[kind] = true
	if kind == "counter" and used and not r.missed and not r.evaded:
		add_analysis(a, b)
	frame = saved
	return logic.mark_views([r])


## G.finishAction（BattleManager.endAction 之前）
static func finish(logic, u, skill) -> Array:
	var logs := []
	if frame.is_empty() or bool(frame.finished) or not is_same(frame.user, u):
		return logs
	var f: Dictionary = frame
	f.finished = true
	if not skill is Dictionary or skill.is_empty():
		return logs
	if own(u) and is_fist(skill) and _hp_damage(skill):
		var p := passives(u)
		var hit := false
		for row in f.targets:
			if not row.hit:
				continue
			hit = true
			if p.followup and int(row.analysis) == 3:
				logs.append_array(trigger(logic, u, row.target, TRIGGERED, "followup", int(f.evolution)))
			add_analysis(u, row.target)
		if hit and p.evolution:
			evolution = mini(3, evolution + 1)
		if hit and int(skill.id) == WATER and u.is_alive():
			u.tp = minf(u.max_tp(), u.tp + 20.0)  # gainSilentTp(20)：每次完整施放命中一次
	elif u is XEnemy and _hp_damage(skill):
		for row in f.targets:
			var b = row.target
			if not own(b) or not row.hit:
				continue
			var p := passives(b)
			if float(row.damage) > 0.0:
				if p.evolution and not received:
					evolution = mini(3, evolution + 1)
					received = true
				add_analysis(b, u)
			if b.is_alive() and p.counter and logic._float("garou_counter") < COUNTER_RATE:
				logs.append_array(trigger(logic, b, u, WATER, "counter"))
	if own(u) and int(skill.id) == SERIOUS:
		saitama = false
	return logs


## Game_Actor.onTurnEnd 包装（之后）：清本回合受过伤与琦玉模式
static func turn_end(b) -> void:
	if own(b):
		received = false
		saitama = false
