class_name XCat
extends RefCounted
## 178 哈基米（小猫剑圣，正式 js/codex/runtime/installImportedBalanceRuntime.js「小猫剑圣 v1.0」段，W.CodexCat 1.0.1）第一期：
## - 招募（公共事件 9017 的 CodexCat.recruit()）：学 6216、忘 6235；首次生成独立法宝 7999「抱剑喵铃」装进装备类型 13 的槽
##   （只给一次，记在存档 cat.relicGranted）；没持剑时生成练习剑 2 装进武器槽（记在角色 cat_starter_granted）；入队。已在队时返回 false。
## - 槽位：去掉副手（装备类型 2），不能双持（equipSlots／isDualWield）。
## - 能力值（Game_Actor.param 包装，在 G_StateParam 之外）：学了 10442 且 10 级起速度 ×1.88；装着 7999 时攻击／速度／幸运 ×1.6；取整、夹在上下限。
## - 持剑（学了 10441 且武器槽是剑 wtype 2）：剑的贡献翻倍——paramPlus＝全量＋(全量−去剑)；特性对象与被动缓存用 sword_view
##   （能力值 ×2，特性 11／21／23 的 1+(v−1)×2、22／33／34／61 ×2，备注数值标签 ×2，元素增幅／倍率 ×2）；sparam 6／7 ×0.8／×0.88。
## - 公式 CodexCat.formula(user,item,b)＝(atk×1500＋agi×3000)×权重×成长×(1＋熟练)×段倍率（段倍率只在连携剑段里不是 1）。
## - 剑技连携（CAT BEGIN／CAT STRIKE、剑心、识破／剑痕、喵铃）：见文末「剑技连携」。
## - 使用条件：见文末 legal。
## - 伤害钩子 cat-sword（持剑技加成、抱剑护身、巨龙减伤）在 cat_damage_hooks.gd（沙僧，模块挂接点），读这里的 advanced。
## 进阶 advanced() 读 XAdvance.rank（进阶后成长曲线、说明文字都随之变）。
## 守誓巨龙试炼、进阶速剑多一次行动、178 在队号角不可用：见文末「守誓巨龙试炼」（参照 mv_oracle/cat_trial_probe.cjs，夹具 tests/fixtures/cat_trial_oracle.json，测试 tests/xiyou_cat_trial.gd）。
## 不做：进阶后终技说明品质 10（helpItem）——七档品质里 9 与 10 都是不朽，名字色、边框、品质行都一样。未移植：段间 WAIT 6 的画面节奏。（Map132 商店补号角已在 XItemMarks 的 LOBBY_CAT_HORN。）
## 参照：mv_oracle/cat_probe.cjs（generated/oracle/cat.json），测试 tests/xiyou_cat.gd。

const ACTOR := 178
const RELIC := 7999
const STARTER_SWORD := 2
const SWORD_WTYPE := 2
const SKILL_SWORD := 10441
const SKILL_SPEED := 10442
const SKILL_ADVANCED := 10444
const ACTIVE := [10437, 10438, 10439, 10440]
## 自带图标：280000～280008 画 img/system/CatSwordSaint_Icons 的第 n 格（32×32 横排）
const ICON := 280000
## 各剑技的公式权重（slash／cross／flurry／holy／echo）
const WEIGHTS := {10437: 1.0, 10438: 5.0 / 6.0, 10439: 0.35, 10440: 10.0 / 3.0, 10445: 5.0 / 6.0}
## 备注里要翻倍的数值标签（同原版 doubled() 的正则）
static var _note_re := RegEx.create_from_string("<([^<>:]+):\\s*([+-]?[\\d.]+)(%?)\\s*>")
static var _key_re := RegEx.create_from_string("(?i)^(?:hp|mp|atk|def|mat|mdf|agi|luk|atkk|passive(?:PBST\\d+|XPST\\d+|SPST\\d+|HarmRi|CrHarmRi|HarmRe\\d+|ELUP\\d+|IRUP|APLUS)|DepassiveHarmRe\\d+|SkillPass\\d+|SkETypeHarmRi\\d+|SkillTypesDvup[A-Z]|Element Amplify \\d+|Element Magnify \\d+|Push(?:Self|sub)?State\\d+)$")


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func learned(a, skill_id: int) -> bool:
	return own(a) and a.skill_ids.has(skill_id)


## 武器槽（第 0 格）是剑
static func has_sword(a) -> bool:
	if not a is XActor or a.equips.is_empty():
		return false
	var e = a.equips[0]
	return e is Dictionary and not e.is_empty() and str(e.get("kind", "")) == "weapon" and int(e.get("wtypeId", 0)) == SWORD_WTYPE


static func has_relic(a) -> bool:
	return own(a) and a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == RELIC)


static func enabled_sword(a) -> bool:
	return learned(a, SKILL_SWORD) and has_sword(a)


## 进阶：35 级起、进阶次数（XAdvance.rank）≥1 且学会 10444
static func advanced(a) -> bool:
	return own(a) and int(a.level) >= 35 and XAdvance.rank(XState.current, ACTOR) >= 1 and learned(a, SKILL_ADVANCED)


## 成长：35 级前按 1／10／20／30／35 级插值 0.06～1；35 级起未进阶为 1，进阶后按 35／50／60／70／81 级插值 0.30～0.875（不低于 0.5）
static func growth(a) -> float:
	var l := int(a.level)
	if l >= 35:
		if not advanced(a):
			return 1.0
		var al := [35, 50, 60, 70, 81]
		var ar := [0.30, 0.45, 0.62, 0.80, 0.875]
		if l >= 81:
			return ar[4]
		for j in range(1, al.size()):
			if l <= al[j]:
				return maxf(0.5, ar[j - 1] + (ar[j] - ar[j - 1]) * (l - al[j - 1]) / float(al[j] - al[j - 1]))
		return 1.0
	var ls := [1, 10, 20, 30, 35]
	var rs := [0.06, 0.15, 0.3, 0.7, 1.0]
	for i in range(1, ls.size()):
		if l <= ls[i]:
			return rs[i - 1] + (rs[i] - rs[i - 1]) * (l - ls[i - 1]) / float(ls[i] - ls[i - 1])
	return 1.0


## 已学剑技里最高的技能等级（不超过变量 8）；Godot 技能熟练度首期恒 0
static func mastery(a) -> int:
	var cap := int(XState.current.variable(8)) if XState.current != null else 0
	var best := 0
	for sid in ACTIVE:
		if learned(a, sid):
			best = maxi(best, mini(cap, a.skillMasteryLevel(sid)))
	return best


## 剑段里（a._codexCatFormula）速度取开招时的快照、乘段倍率（连携段 0.6）
static func formula(a, item: Dictionary) -> float:
	var weight: float = WEIGHTS.get(int(item.get("id", 0)), 0.0)
	var snap = _formula_snap if not _formula_snap.is_empty() and _formula_snap.actor == a else null
	var agi: float = snap.agi if snap != null else a.agi
	var rate: float = snap.rate if snap != null else 1.0
	return (a.atk * 1500.0 + agi * 3000.0) * weight * growth(a) * (1.0 + mastery(a)) * rate


## Game_Actor.param 的包装（v 是包装前、已取整夹值的值）
static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	var r := 1.0
	if i == 6 and learned(a, SKILL_SPEED) and int(a.level) >= 10:
		r *= 1.88
	if i in [2, 6, 7] and has_relic(a):
		r *= 1.6
	return roundf(clampf(v * r, a.param_min(i), a.param_max(i)))


static func sparam(a, i: int, v: float) -> float:
	if not enabled_sword(a):
		return v
	return v * (0.8 if i == 6 else (0.88 if i == 7 else 1.0))


static func equip_slots(a, slots: Array) -> Array:
	return slots.filter(func(t): return int(t) != 2) if own(a) else slots


## 剑的能力视图（只给能力值／特性／被动缓存计算用；装备归属、实例、背包仍用真实对象）。按实例缓存。
static var _views := {}

static func sword_view(e: Dictionary) -> Dictionary:
	var stamp := JSON.stringify([e.get("params"), e.get("traits"), e.get("level"), e.get("yep"), e.get("note")])
	var cached = _views.get(hash(stamp))
	if cached != null:
		return cached
	if _views.size() > 256:
		_views.clear()
	var o := e.duplicate(true)
	o.params = (e.get("params", []) as Array).map(func(v): return float(v) * 2.0)
	var traits := []
	for t in e.get("traits", []):
		var n: Dictionary = t.duplicate()
		var code := int(t.code)
		if code in [11, 21, 23]:
			n.value = 1.0 + (float(t.value) - 1.0) * 2.0
		elif code in [22, 33, 34, 61]:
			n.value = float(t.value) * 2.0
		traits.append(n)
	o.traits = traits
	var note := str(e.get("note", ""))
	var meta: Dictionary = o.get("meta", {})
	var out := ""
	var last := 0
	for m in _note_re.search_all(note):
		out += note.substr(last, m.get_start() - last)
		var key := m.get_string(1)
		if _key_re.search(key.strip_edges()) != null:
			var doubled := _js_num(float(m.get_string(2)) * 2.0) + m.get_string(3)
			out += "<" + key + ": " + doubled + ">"
			meta[key] = " " + doubled
		else:
			out += m.get_string()
		last = m.get_end()
	o.note = out + note.substr(last)
	o.meta = meta
	if o.has("yep"):
		for field in ["elementAmplify", "elementAmplifyN", "elementMagnify"]:
			var src: Dictionary = o.yep.get(field, {})
			for k in src:
				src[k] = float(src[k]) * 2.0
	_views[hash(stamp)] = o
	return o


## JS String(Number)：整数不带小数点
static func _js_num(v: float) -> String:
	return str(int(v)) if v == floorf(v) and absf(v) < 1e15 else str(v)


## 招募（公共事件 9017 的 CodexCat.recruit()）。标记照原名存进 s.flags（$gameSystem._codexCatRelicGranted、角色 _codexCatStarterGranted）。
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	a.forget_skill(6235)
	a.learn_skill(6216)
	var slot := a.equip_slots().find(13)
	if slot < 0:
		push_error("[xiyou] 抱剑喵铃装备槽不可用")
		return false
	if not bool(s.flags.get("_codexCatRelicGranted", false)):
		var cur = a.equips[slot]
		if not (cur is Dictionary and int(cur.get("base", 0)) == RELIC):
			a.equips[slot] = _take_gear(s, "armor", RELIC)
		s.flags["_codexCatRelicGranted"] = true
	# 练习剑总是新生成一把（gainIndependentItem）再装上，背包里原有的同款不动；原来武器槽里的东西回背包（changeEquip 的交换）
	if not has_sword(a) and not bool(s.flags.get("_codexCatStarterGranted", false)):
		var sword := XGear.create("weapon", STARTER_SWORD, s)
		s.register_gear(sword)
		if a.equips[0] is Dictionary and not a.equips[0].is_empty():
			s.gear.append(a.equips[0])
		a.equips[0] = sword
		s.flags["_codexCatStarterGranted"] = true
	a.refresh_passive()
	s.add_actor(ACTOR)
	return true


## 法宝：背包里有同基础编号的就拿那件（getMatchingBaseItem），否则生成新实例；从背包取出、装上（changeEquip 的交换）
static func _take_gear(s: XState, kind: String, base_id: int) -> Dictionary:
	var idx := s.gear.find_custom(func(e): return e.kind == kind and int(e.base) == base_id)
	if idx < 0:
		s.gain_gear(kind, base_id, 1)
		idx = s.gear.size() - 1
	var item: Dictionary = s.gear[idx]
	s.gear.remove_at(idx)
	return item


static func icon_texture(index: int) -> AtlasTexture:
	var p := XDB.img_path("system", "CatSwordSaint_Icons")
	if p == "":
		return null
	var a := AtlasTexture.new()
	a.atlas = load(p)
	a.region = Rect2((index - ICON) * 32, 0, 32, 32)
	return a


# ---- 说明卡（C.helpText，installDisplayPreferencesRuntime.characterHelpView 对 <CodexCat:> 物品调用） ----
const SKILL_KEYS := {10437: "slash", 10438: "cross", 10439: "flurry", 10440: "holy", 10441: "sword", 10442: "speed", 10443: "heart",
	10444: "advanced", 10445: "echo", 10446: "trial"}

static func is_cat_item(obj: Dictionary) -> bool:
	return str(obj.get("note", "")).contains("<CodexCat:")


## characterHelpActor：已有 178 就用它，否则是初始状态的预览（1 级、没学技能、速度读不到）
static func help_actor():
	var s := XState.current
	if s != null and s.actors.has(ACTOR):
		return s.actors[ACTOR]
	return null


static func _n(v: float) -> String:
	return _js_num(roundf(v * 1000.0) / 1000.0)


## 返回改写后的一行；actor 为 null 时按预览（等级 1、速度 0）
static func help_text(text: String, item: Dictionary, a) -> String:
	var k: String = SKILL_KEYS.get(int(item.get("id", 0)), "")
	var weight: float = WEIGHTS.get(int(item.get("id", 0)), 0.0)
	var g := growth(a) if a != null else 0.06
	var adv := advanced(a)
	var agi: float = a.agi if a != null else 0.0
	if weight != 0.0 and RegEx.create_from_string("^伤害[：:]").search(text) != null:
		return "伤害：[己·物理攻击×" + _n(1500.0 * weight * g) + "＋己·速度×" + _n(3000.0 * weight * g) + "]×[1＋剑技等级]×[1＋剑技等级×0.1]"
	if k == "sword" and text.contains("抱剑护身"):
		if agi == 0.0:
			return "效果：抱剑护身，速度提供物理及元素固定减伤"
		return "效果：抱剑护身，物理减伤" + str(mini(16000, mini(floori(3.0 * agi), 15030 + floori(agi / 8.0)))) + "；元素减伤" + str(mini(18000, mini(floori(3.2 * agi), 16400 + floori(2.0 * agi / 11.0))))
	if k == "trial" and text.contains("哈基米独自挑战守誓巨龙"):
		return "效果：哈基米独自挑战守誓巨龙，巨龙使用固定试炼难度"
	if k == "heart" and text.contains("进阶后专属剑技"):
		return "效果：专属剑技结算伤害+100%" if adv else "条件：进阶后专属剑技结算伤害+100%"
	if k == "speed" and text.contains("进阶后额外"):
		return "效果：额外行动＋1" if adv else "条件：进阶后额外获得1次行动"
	if k == "heart" and text.contains("进阶后终技"):
		return "效果：终技消费剑心，追加同层数神圣剑段；满层冷却减1" if adv else "条件：进阶后终技消费剑心，追加同层数神圣剑段；满层冷却减1"
	if k == "holy" and text.contains("冷却4"):
		return "冷却时间：4个自然回合；进阶后消耗剑心追加神圣剑影，满层冷却3回合"  # 未进阶（Godot 无进阶）
	return text


# ---- 剑技连携（processActionSequence 包装的 CAT BEGIN／CAT STRIKE、endAction、endTurn） ----
## 四个剑技的行动序列只有 CAT BEGIN：开招时按剑技排出剑段，每段是一个独立的 Game_Action（技能换成该段的剑技，经 invokeAction，
## 有反射／反击／掩护），段间原版插 WAIT 6（画面）；一段剑技打完再按条件连携下一招（连携段伤害 ×0.6，连携招不再连携）。
## - 斩：1 段＋剑心≥1 时 1 段，打完给目标「识破」；十字斩：2 段＋剑心≥2 时 2 段，任一对相邻段都命中时给「剑痕」；
##   连斩：4 段＋剑心 3 层 2 段＋速度段（非连携：开招速度≥目标 1.5 倍 2 段、快于目标 1 段）＋剑痕 2 段，消费剑痕与识破；
##   至圣斩：1 段＋剑痕 2 段剑影（进阶后再加剑心层数段，并清空剑心），消费剑痕与识破，冷却到 回合＋4（进阶满层 3）。
## - 连携：斩→十字斩；十字斩开招时目标有识破→连斩；连斩开招时有剑痕→斩；至圣斩消费了标记→斩。
## - 「必中」段（开招时目标有识破、且不是斩）：命中 1、闪避 0、不被反击；学了 10443 时还必定暴击。
## - 标记归施放者、有效到 放下时回合＋1，回合结束删过期的；目标身上的 2716／2717 状态跟着同步。
## - 行动结束：连携过就剑心＋1（学了 10443）；防御且学了 10443、带法宝时每回合一次剑心＋1，并把最近目标的标记续到下回合。
## 战斗数据挂在本场 XBattleLogic 上（新战斗即清空，同原版 startBattle／endBattle 的 reset）；剑心与标记状态都是 removeAtBattleEnd。
const IDS := {"slash": 10437, "cross": 10438, "flurry": 10439, "holy": 10440, "echo": 10445}
const SKILL_HEART := 10443
const HEART_STATES := [2713, 2714, 2715]
const MARK_STATES := {"read": 2716, "scar": 2717}
## 当前剑段（Game_Action 的 _catSure／_catWeak）与公式快照（_codexCatFormula）
static var segment := {}
static var _formula_snap := {}
## 测试用：非空数组时逐段追加 {key, hit, damage, critical, chain}（同原版 CodexCat.trace）
static var trace = null


static func _key(item: Dictionary) -> String:
	var id := int(item.get("id", 0))
	for k in IDS:
		if IDS[k] == id:
			return k
	return ""


## own(行动者) 且技能是四个剑技（物品不算）
static func casts(u, item: Dictionary) -> bool:
	return own(u) and int(item.get("id", 0)) in ACTIVE and not XBattleLogic.is_item(item)


static func _store(logic) -> Dictionary:
	if not logic.has_meta("xcat"):
		logic.set_meta("xcat", {"actors": {}, "marks": {}, "cast": null})
	return logic.get_meta("xcat")


static func _round(logic) -> int:
	return maxi(1, int(logic.turn))


static func _data(logic, a) -> Dictionary:
	var st := _store(logic)
	if not st.actors.has(a):
		st.actors[a] = {"heart": 0, "holyReady": 0, "bellRound": 0, "recent": null}
	return st.actors[a]


## 本场数据的只读视图（测试、说明卡用）
static func battle_data(logic, a) -> Dictionary:
	return _data(logic, a)


static func heart_of(logic, a) -> int:
	return int(_data(logic, a).heart)


static func marks_of(logic, t) -> Dictionary:
	return _store(logic).marks.get(t, {})


static func _alive(t) -> bool:
	return t != null and t.is_alive() and t.hp > 0.0


static func mark(logic, a, t, k: String) -> bool:
	var m: Dictionary = marks_of(logic, t).get(int(a.actor_id), {})
	return m.has(k) and int(m[k]) >= _round(logic) and _alive(t)


static func _sync_marks(logic, t) -> void:
	if t == null:
		return
	var r := _round(logic)
	for k in MARK_STATES:
		var yes := false
		for id in marks_of(logic, t):
			yes = yes or int(marks_of(logic, t)[id].get(k, -1)) >= r
		var sid: int = MARK_STATES[k]
		if yes and not t.is_state_affected(sid):
			t.add_state(sid)
		elif not yes and t.is_state_affected(sid):
			t.remove_state(sid)


static func _put(logic, a, t, k: String) -> void:
	if not _alive(t):
		return
	var marks: Dictionary = _store(logic).marks
	if not marks.has(t):
		marks[t] = {}
	if not marks[t].has(int(a.actor_id)):
		marks[t][int(a.actor_id)] = {}
	marks[t][int(a.actor_id)][k] = _round(logic) + 1
	_sync_marks(logic, t)


static func _consume(logic, a, t, k: String) -> bool:
	var yes := mark(logic, a, t, k)
	var m: Dictionary = marks_of(logic, t).get(int(a.actor_id), {})
	m.erase(k)
	_sync_marks(logic, t)
	return yes


static func _set_heart(logic, a, n: int) -> void:
	var d := _data(logic, a)
	d.heart = clampi(n, 0, 3)
	for i in range(HEART_STATES.size()):
		var sid: int = HEART_STATES[i]
		if i + 1 == int(d.heart):
			if not a.is_state_affected(sid):
				a.add_state(sid)
		elif a.is_state_affected(sid):
			a.remove_state(sid)


## begin 时捕获的原生重复次数 Math.max(1, floor(nativeRepeats))：Game_Action.numRepeats（技能 repeats，普攻加追加次数）
## 再经 dsPassiveSkill 加被动 atkk 与 AgainUse（全局／战技／魔法／指定技能几率合计，Math.random×100 < 几率时 +1）。
## 被动来源同 dsPassiveSkill：装备＋技能＋状态的备注元数据。每一剑段按这个次数重复（_strike 的 segmentRepeat），不重复整个连携。
static func native_repeats(logic, a, item: Dictionary) -> int:
	var n := float(item.get("repeats", 1))
	if a.is_attack(item):  # isAttack：看此刻的 attackSkillId
		n += a.attack_times_add()
	var atkk := 0
	var again := 0.0
	var by := "AgainUseZj" if int(item.get("stypeId", 0)) == 1 else ("AgainUseMf" if int(item.get("stypeId", 0)) == 2 else "")
	for o in a.equip_list() + a.skills() + a.states():
		var meta: Dictionary = o.get("meta", {})
		if meta.has("atkk"):
			var m := RegEx.create_from_string("(\\d+)").search(str(meta.atkk))
			if m:
				atkk += int(m.get_string(1))
		for k in meta:
			var key := str(k)
			if key == "AgainUseAll" or (by != "" and key == by) or key == "AgainUse%d" % int(item.get("id", 0)):
				again += float(str(meta[k]).to_int())
	n += atkk
	if again > 0.0 and logic._float("cat_again_use") * 100.0 < again:
		n += 1
	return maxi(1, floori(n))


static func _begin(logic, a, item: Dictionary, t) -> Dictionary:
	var st := _store(logic)
	if st.cast != null and st.cast.action == item and st.cast.actor == a:
		return st.cast
	var k := _key(item)
	var c := {"actor": a, "target": t, "key": k, "heart": heart_of(logic, a) if learned(a, SKILL_HEART) else 0, "agi": a.agi,
		"read": mark(logic, a, t, "read"), "scar": mark(logic, a, t, "scar"), "count": native_repeats(logic, a, item), "steps": [], "hits": [], "chain": false,
		"done": false, "ended": false, "action": item, "consumed": false}
	st.cast = c
	_build(logic, c, k, false)
	return c


static func _build(logic, c: Dictionary, k: String, chain: bool) -> void:
	var a = c.actor
	var t = c.target
	var h := int(c.heart)
	var rd := mark(logic, a, t, "read")
	var sc := mark(logic, a, t, "scar")
	var n := 0
	var sure := rd and k != "slash"
	c.phaseKey = k
	c.phaseChain = chain
	c.hits = []
	if k == "slash":
		n = 1 + (1 if h >= 1 else 0)
	elif k == "cross":
		n = 2 + (2 if h >= 2 else 0)
	elif k == "flurry":
		var speed := 0
		if not chain:
			speed = 2 if float(c.agi) >= t.agi * 1.5 else (1 if float(c.agi) > t.agi else 0)
		n = 4 + (2 if h >= 3 else 0) + speed + (2 if sc else 0)
		if sc:
			_consume(logic, a, t, "scar")
		if rd:
			_consume(logic, a, t, "read")
	if k == "holy":
		c.consumed = sc or rd
		if sc:
			_consume(logic, a, t, "scar")
		if rd:
			_consume(logic, a, t, "read")
		var echoes := h if advanced(a) else 0
		if echoes > 0:
			_set_heart(logic, a, 0)
		_data(logic, a).holyReady = _round(logic) + (3 if advanced(a) and h == 3 else 4)
		c.steps.append({"key": k, "rate": 1.0, "sure": sure})
		for j in range((2 if sc else 0) + echoes):
			c.steps.append({"key": "echo", "rate": 1.0, "sure": sure})
	else:
		for i in range(n):
			c.steps.append({"key": k, "rate": 0.6 if chain else 1.0, "sure": sure})
	c.segment = 0
	c.segmentRepeat = 0


static func _complete_phase(logic, c: Dictionary) -> void:
	var a = c.actor
	var t = c.target
	var k: String = c.phaseKey
	if k == "slash":
		_put(logic, a, t, "read")
	if k == "cross":
		var i := 0
		while i + 1 < c.hits.size():
			if c.hits[i] and c.hits[i + 1]:
				_put(logic, a, t, "scar")
				break
			i += 2
	if c.phaseChain:
		c.done = true
		return
	var next := ""
	if k == "slash":
		next = "cross"
	elif k == "cross" and c.read:
		next = "flurry"
	elif k == "flurry" and c.scar:
		next = "slash"
	elif k == "holy" and c.consumed:
		next = "slash"
	if next != "" and learned(a, IDS[next]) and a.is_alive() and _alive(t):
		c.chain = true
		_build(logic, c, next, true)
	else:
		c.done = true


## 一段 CAT STRIKE：返回是否还有下一段
static func _strike(logic, c: Dictionary, logs: Array) -> bool:
	var a = c.actor
	var t = c.target
	if c.done or not a.is_alive() or not _alive(t):
		c.done = true
		return false
	var step: Dictionary = c.steps[c.segment]
	var child := XDB.rec("Skills", int(IDS[step.key]))
	_formula_snap = {"actor": a, "agi": c.agi, "rate": step.rate}
	segment = {"actor": a, "sure": step.sure}
	var raw := formula(a, child) if trace is Array else 0.0
	var got: Array = logic._invoke(a, child, t)
	_formula_snap = {}
	segment = {}
	var r = null
	for e in got:
		if str(e.get("type", "")) == "hit" and e.target == t:
			r = e
	var hit: bool = r != null and not r.missed and not r.evaded
	while c.hits.size() <= int(c.segment):
		c.hits.append(null)
	c.hits[c.segment] = false if c.hits[c.segment] == false else hit
	if trace is Array:
		trace.append({"key": step.key, "raw": raw, "hit": hit, "damage": float(r.hp) if r != null else 0.0,
			"critical": bool(r.critical) if r != null else false, "chain": c.phaseChain})
	logs.append_array(logic.mark_views(got))
	_data(logic, a).recent = t
	c.segmentRepeat += 1
	if c.segmentRepeat >= int(c.count):
		c.segmentRepeat = 0
		c.segment += 1
	if c.segment >= c.steps.size():
		c.steps = []
		_complete_phase(logic, c)
	return not c.done and a.is_alive() and _alive(t)


## 行动序列的 CAT BEGIN：开招并依次打完全部剑段（原版逐条插 CAT STRIKE＋WAIT 6）；目标已倒下时什么都不做
static func cast(logic, u, item: Dictionary, t) -> Array:
	var logs := []
	if t == null or not t.is_alive():
		return logs
	var c := _begin(logic, u, item, t)
	while _strike(logic, c, logs):
		pass
	return logs


## 剑段的必中（itemHit 1、itemEva 0、itemCnt 0）
static func sure_segment(u) -> bool:
	return not segment.is_empty() and segment.actor == u and bool(segment.sure)


## 剑段的必暴（itemCri 1）：必中段且学了 10443
static func weak_segment(u) -> bool:
	return sure_segment(u) and learned(u, SKILL_HEART)


## BattleManager.endAction：结束剑技（连携过则剑心＋1）；防御时的喵铃
static func end_action(logic, u, item) -> void:
	if not own(u) or item == null:
		return
	var st := _store(logic)
	var c = st.cast
	if c != null and c.actor == u and not c.ended:
		c.ended = true
		if c.chain and learned(u, SKILL_HEART) and u.is_alive():
			_set_heart(logic, u, heart_of(logic, u) + 1)
	st.cast = null
	if int(item.get("id", 0)) == XBattleLogic.GUARD_SKILL and not XBattleLogic.is_item(item) and learned(u, SKILL_HEART) and has_relic(u) and u.is_alive():
		var d := _data(logic, u)
		var r := _round(logic)
		if int(d.bellRound) != r:
			d.bellRound = r
			_set_heart(logic, u, int(d.heart) + 1)
			var t = d.recent
			if t != null and t.is_alive():
				var m: Dictionary = marks_of(logic, t).get(int(u.actor_id), {})
				if not m.is_empty():
					for k in ["read", "scar"]:
						if m.has(k) and int(m[k]) >= r:
							m[k] = r + 1
					_sync_marks(logic, t)


## BattleManager.endTurn（进入回合结束时）：删掉已过期的标记
static func end_turn(logic) -> void:
	var r := _round(logic)
	for t in logic.enemies:
		var all: Dictionary = marks_of(logic, t)
		for id in all:
			for k in ["read", "scar"]:
				if all[id].has(k) and int(all[id][k]) <= r:
					all[id].erase(k)
		_sync_marks(logic, t)


# ---- 使用条件（Game_Actor／Game_BattlerBase.meetsSkillConditions 包装） ----
const SKILL_TRIAL := 10446
const LEVELS := {10437: 1, 10438: 10, 10439: 20, 10440: 30}

## 剑技：自己、持剑、学会、到等级，至圣斩还要不在冷却（holyReady > 回合）；试炼：自己、35 级、持剑、不在战斗中；剑影不能直接用；
## 178 的物理技能（stypeId 1）没持剑也不能用。原版按技能编号判断（物品不算）。
static func legal(logic, a, item: Dictionary) -> bool:
	if XBattleLogic.is_item(item):
		return true
	var id := int(item.get("id", 0))
	if id in ACTIVE:
		if not (own(a) and has_sword(a) and learned(a, id) and int(a.level) >= int(LEVELS[id])):
			return false
		return id != IDS.holy or int(_data(logic, a).holyReady) <= _round(logic)
	if id == SKILL_TRIAL:
		return own(a) and int(a.level) >= 35 and has_sword(a) and int(logic.troop_id) == 0
	if id == IDS.echo:
		return false
	return not (own(a) and int(item.get("stypeId", 0)) == 1 and not has_sword(a))


# ---- 守誓巨龙试炼（公共事件 9018 的 CodexCat.startTrial，installImportedBalanceRuntime 第 247～263 行） ----
# 原版把要还原的队伍记在 $gameSystem._codexCatTrial，首胜记 _codexCatTrialWon；这里照原名存进 s.flags（随存档）。
# 队伍只剩 178：party＝[178]、出战栏 [178, 0, 0, 0, 0]（原版另设 _BattleMaxSize 1，重制出战栏固定 5 格，空格不出战，效果相同）。
const TROOP := 1999
const DRAGON := 1999
const STONE := 2900
const HORN := 2899
## 巨龙按 (round−1)%5 出招：爪、蓄息、喷焰、空（不行动）、尾
const DRAGON_SKILLS := [10447, 10448, 10449, 0, 10450]
const SKILL_CHARGE := 10448
const CHARGE_TEXT := "巨龙昂首蓄息！下一回合将喷出铜焰，架剑防御！"
const TRIAL_NOT_READY := "小猫剑圣达到35级并装备剑后，才能挑战。"
const TRIAL_WON := "守誓巨龙认可了你的剑。获得小猫进阶石×1！"
const TRIAL_LOST := "试炼未通过，可再次挑战。"
## trialDifficultyStates：固定预算的个人试炼不继承塔内挑战的怪物强化
const TRIAL_DIFFICULTY_STATES := [1271, 1284, 1460, 1461, 1462, 1463, 1464, 1465, 1466, 1467, 1469, 1470, 1471, 1633, 1634, 1636,
	1641, 1643, 1657, 1658, 1659, 1682]


static func trial_ready(s: XState) -> bool:
	return s.party.has(ACTOR) and int(s.actor(ACTOR).level) >= 35 and has_sword(s.actor(ACTOR))


static func in_trial(s: XState) -> bool:
	return s != null and s.flags.has("_codexCatTrial")


## C.startTrial 换队那一半：记下队伍与出战栏，只留 178；开战（setup(1999, 不能逃, 可以输)）由调用处做。条件不够返回 false
static func start_trial(s: XState) -> bool:
	if not trial_ready(s):
		return false
	s.flags["_codexCatTrial"] = {"actors": s.party.duplicate(), "slots": s.battle_slots.duplicate()}
	s.party.assign([ACTOR])
	s.battle_slots = [ACTOR, 0, 0, 0, 0]
	XZhenqi.pending_trial = {}  # CodexZhenqi._battle＝null：不让一笔待开的瓶颈之战吃掉这场
	return true


## restoreTrial：还原队伍；result 0（胜）首次给小猫进阶石，2（败）178 倒下时留 1 血。返回要提示的文字（没有时为空）
static func restore_trial(s: XState, result: int) -> String:
	if not in_trial(s):
		return ""
	var d: Dictionary = s.flags["_codexCatTrial"]
	s.party.assign(d.actors.map(func(v): return int(v)))
	s.battle_slots = d.slots.map(func(v): return int(v))
	s.flags.erase("_codexCatTrial")
	if result == 0 and not bool(s.flags.get("_codexCatTrialWon", false)):
		s.flags["_codexCatTrialWon"] = true
		s.gain_item(STONE, 1)
		return TRIAL_WON
	if result == 2:
		var a := s.actor(ACTOR)
		if a.is_dead():
			a.hp = 1.0  # setHp(1)：refresh 见 HP 大于 0 就去掉阵亡状态
			if a.state_ids.has(1):
				a.remove_state(1)
		return TRIAL_LOST
	return ""


## BattleManager.startBattle 包装（原 startBattle 之后）：试炼中 178 回满、TP 满
static func trial_start_battle(logic) -> void:
	if not in_trial(logic.state):
		return
	var a: XActor = logic.state.actor(ACTOR)
	a.recover_all()
	a.tp = a.max_tp()


static func is_dragon(b) -> bool:
	return b is XEnemy and int(b.enemy_id) == DRAGON


## Game_Enemy.makeActions 包装（不看是否在试炼）：OTB 下 n＝round()＝max(1, 回合数)；空回合不行动。不是巨龙返回 []
static func dragon_action(logic, e) -> Array:
	if not is_dragon(e):
		return []
	var id: int = DRAGON_SKILLS[(maxi(1, int(logic.turn)) - 1) % 5]
	if id == 0:
		return [null, null]
	var foes: Array = logic.actors.filter(func(a): return a.is_alive())
	var t = logic.actors[0] if not logic.actors.is_empty() and logic.actors[0].is_alive() else (foes[0] if not foes.is_empty() else null)
	return [XDB.rec("Skills", id), t]  # setTarget(0)：smoothTarget(0)，第一位活着的角色


## BattleManager.startAction 包装：巨龙蓄息时日志加一行
static func start_action(u, skill) -> Array:
	if is_dragon(u) and skill is Dictionary and int(skill.get("id", 0)) == SKILL_CHARGE and not XBattleLogic.is_item(skill):
		return [{"type": "battle_text", "text": CHARGE_TEXT}]
	return []


## Game_Enemy.addState 包装：试炼中的巨龙（敌人 1999 只在敌群 1999 里）不吃 22 个难度状态
static func trial_blocks_state(e, id: int) -> bool:
	return is_dragon(e) and in_trial(XState.current) and TRIAL_DIFFICULTY_STATES.has(id)


## Game_Enemy.param 最外层包装（不看是否在试炼）：巨龙用数据库原值。不是巨龙返回 NAN
static func dragon_param(e, i: int) -> float:
	return float(e.data().params[i]) if is_dragon(e) else NAN


## makeActionTimes 包装：进阶且学了速剑 10442，多 1 次行动
static func extra_actions(b) -> int:
	return 1 if advanced(b) and learned(b, SKILL_SPEED) else 0


## Game_BattlerBase.canUse 包装：178 在队时号角 2899 不能用
static func horn_blocked(s: XState, item: Dictionary) -> bool:
	return s != null and XBattleLogic.is_item(item) and int(item.get("id", 0)) == HORN and s.party.has(ACTOR)
