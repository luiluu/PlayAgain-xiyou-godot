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
## 未移植（交付单写明）：剑技连携 CAT BEGIN／CAT STRIKE、剑心、识破／剑痕、技能使用条件、进阶（Godot 无 _AdvancedNum，advanced 恒假）、
## 守誓巨龙试炼、伤害钩子 cat-sword（持剑技伤害／抱剑护身减伤／巨龙减伤，要 damage.gd 的模块挂接点）、元素增幅翻倍进伤害
## （damage.gd 的 _yep_objects 直接读 equip_list，提案改读 stat_equips）、号角 2899 入队后不可用、Map132 商店补号角、自定义图标。
## 参照：mv_oracle/cat_probe.cjs（generated/oracle/cat.json），测试 tests/xiyou_cat.gd。

const ACTOR := 178
const RELIC := 7999
const STARTER_SWORD := 2
const SWORD_WTYPE := 2
const SKILL_SWORD := 10441
const SKILL_SPEED := 10442
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


## 进阶（35 级＋小猫进阶石＋学会 10444）：Godot 还没有角色进阶次数（_AdvancedNum），恒为假
static func advanced(_a) -> bool:
	return false


## 成长：35 级前按 1／10／20／30／35 级插值 0.06～1；35 级起未进阶为 1（进阶后的另一条曲线随进阶系统接）
static func growth(a) -> float:
	var l := int(a.level)
	if l >= 35:
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


static func formula(a, item: Dictionary) -> float:
	var weight: float = WEIGHTS.get(int(item.get("id", 0)), 0.0)
	return (a.atk * 1500.0 + a.agi * 3000.0) * weight * growth(a) * (1.0 + mastery(a))


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
	if not has_sword(a) and not bool(s.flags.get("_codexCatStarterGranted", false)):
		a.equips[0] = _take_gear(s, "weapon", STARTER_SWORD)
		s.flags["_codexCatStarterGranted"] = true
	a.refresh_passive()
	s.add_actor(ACTOR)
	return true


## 背包里有同基础编号的就拿那件（getMatchingBaseItem），否则生成新实例；从背包取出、装上（changeEquip 的交换）
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
