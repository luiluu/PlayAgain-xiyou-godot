class_name XXiyouNerf
extends RefCounted
## 【小A·未经审查】T465 西游档离群角色数值削弱：五河琴里（159）、天剑·非天（147）（Kyo 11-24 D283，事项 52）。
## 仅在已载入西游档（XState.current != null 且非天启篇）时经 XDB.rec 返回副本，
## 不修改 XDB.table 共享原表，天启篇（XTianqi.active）与无存档静态表校验零改动。
## 读档（XState.from_dict → after_load）与跨档星级仓库存取（sync_gear_for_state）按当前开关双向同步
## 既有 Weapon 87 实例，保留随机浮动 params、强化、宝珠、符文之语与词缀叠加。
## 回退：ENABLED = false 后 clear_cache() 还原原版；原版参照测试由 XCanglong.original_data() 一并关闭。

static var ENABLED := true

# ---- 五河琴里（159）定稿参数（全部整数）----
const KOTORI_ACTOR := 159
const KOTORI_SKILLS := [10055, 10056, 10057, 10058]
const KOTORI_BASE_DMG := 5000          # 固定底数：原 100000 → 5000
const KOTORI_FIRE_MUL := 2             # 火力值系数：原 10055(*8)/10056(*10)/10057(*10)/10058(*5) → 统一 *2
const KOTORI_WPN := 87                 # 天外天·灼烂歼鬼
const KOTORI_WPN_EL_AMP := 200         # 物/火增幅：原 +1200% → +200%
const KOTORI_WPN_SKILL_PASS := 200     # 专属技能伤 10055~10058：原 +1500% → +200%
const KOTORI_WPN_HARM := 150           # 终伤 passiveHarmRi：原 +600 → +150

# ---- 天剑·非天（147）定稿参数（全部整数）----
const FEITIAN_ACTOR := 147
const FEITIAN_SKILL_COEF := {
	10072: [33000, 12000],             # 基础 剑*非天：33000 → 12000
	10485: [43300, 5500],              # 进化 剑*唯一（13段纯粹）：43300 → 5500
	10481: [43300, 6000],              # 进化 麒麟湮灭斩：43300 → 6000
	10483: [43300, 6000],              # 进化 剑*非天：43300 → 6000
	10484: [43300, 6000],              # 进化 万剑灭：43300 → 6000
	10486: [43300, 6000],              # 进化 三尊·灵宝镇山河：43300 → 6000
	10487: [43300, 6000],              # 进化 三尊·元始炼阴阳：43300 → 6000
	10488: [43300, 6000],              # 进化 三尊·道德漫天下：43300 → 6000
	10489: [43300, 6000],              # 进化 万古一人行：43300 → 6000
}
const FEITIAN_CRI_CAP := 10            # 暴击率进公式封顶 10.0（1000%）
const FEITIAN_ST_2739 := 2739          # 极光剑一*破：原代码 *2.5 → 按卡面修回 *1.5
const FEITIAN_ST_2739_PCT := 150

static var _rec_cache := {}            # "Table:id" -> [base_ref, copy_dict]
static var _gear_tpl_cache := {}       # "weapon:87" -> [orig_ref, nerfed_copy]


static func on() -> bool:
	return ENABLED


static func xiyou_save_on() -> bool:
	return ENABLED and XState.current != null and not XTianqi.active(XState.current)


static func original_data() -> void:
	ENABLED = false
	clear_cache()


static func clear_cache() -> void:
	_rec_cache.clear()
	_gear_tpl_cache.clear()
	XActor.read_touch()


static func touches(table_name: String, id: int) -> bool:
	match table_name:
		"Skills":
			return KOTORI_SKILLS.has(id) or FEITIAN_SKILL_COEF.has(id)
		"Weapons":
			return id == KOTORI_WPN
		"States":
			return id == FEITIAN_ST_2739
	return false


static func rec(table_name: String, id: int, base: Dictionary) -> Dictionary:
	if not ENABLED or base.is_empty():
		return base
	var key := "%s:%d" % [table_name, id]
	var cached = _rec_cache.get(key)
	if cached is Array and cached.size() == 2 and is_same(cached[0], base):
		return cached[1]
	var r: Dictionary = base.duplicate(true)
	match table_name:
		"Skills":
			if KOTORI_SKILLS.has(id):
				_patch_kotori_skill(r, id)
			elif FEITIAN_SKILL_COEF.has(id):
				var pair: Array = FEITIAN_SKILL_COEF[id]
				_patch_feitian_skill(r, int(pair[0]), int(pair[1]))
		"Weapons":
			if id == KOTORI_WPN:
				_patch_kotori_wpn87(r)
		"States":
			if id == FEITIAN_ST_2739:
				_patch_feitian_st2739(r)
	_rec_cache[key] = [base, r]
	return r


# ---- 五河琴里补丁 ----

static func _patch_kotori_skill(sk: Dictionary, id: int) -> void:
	var old_mul := 8 if id == 10055 else (10 if id in [10056, 10057] else 5)
	var dmg: Dictionary = sk.get("damage", {})
	if dmg is Dictionary:
		var f := str(dmg.get("formula", ""))
		f = f.replace("100000+", "%d+" % KOTORI_BASE_DMG)
		f = f.replace("v[1510]*%d" % old_mul, "v[1510]*%d" % KOTORI_FIRE_MUL)
		dmg.formula = f
		if dmg.get("formulaGd") is String:
			var fg := str(dmg.formulaGd)
			fg = fg.replace("100000+", "%d+" % KOTORI_BASE_DMG)
			fg = fg.replace("v[1510]*%d" % old_mul, "v[1510]*%d" % KOTORI_FIRE_MUL)
			dmg.formulaGd = fg
		if dmg.get("formulaProgram") is Dictionary:
			_walk_kotori_ast(dmg.formulaProgram.get("steps", []))
	# 卡面文案同步（10058 原卡面写错为 火力值*8，一并统一为实际系数 *2）
	_replace_note_meta(sk, "[100000+", "[%d+" % KOTORI_BASE_DMG)
	_replace_note_meta(sk, "火力值*10]", "火力值*%d]" % KOTORI_FIRE_MUL)
	_replace_note_meta(sk, "火力值*8]", "火力值*%d]" % KOTORI_FIRE_MUL)
	_replace_note_meta(sk, "火力值*5]", "火力值*%d]" % KOTORI_FIRE_MUL)


static func _walk_kotori_ast(node) -> void:
	if node is Dictionary:
		var op := str(node.get("op", ""))
		if op == "literal" and is_equal_approx(float(node.get("value", 0.0)), 100000.0):
			node.value = float(KOTORI_BASE_DMG)
		elif op == "binary" and str(node.get("operator", "")) == "*":
			var l = node.get("left")
			var r = node.get("right")
			if l is Dictionary and str(l.get("op", "")) == "lookup" and str(l.get("pool", "")) == "v":
				var idx = l.get("index")
				if idx is Dictionary and int(idx.get("value", 0)) == 1510 and r is Dictionary and str(r.get("op", "")) == "literal":
					r.value = float(KOTORI_FIRE_MUL)
		for k in node.keys():
			_walk_kotori_ast(node[k])
	elif node is Array:
		for x in node:
			_walk_kotori_ast(x)


static func _patch_kotori_wpn87(w: Dictionary) -> void:
	for el in [1, 2]:
		_replace_tag(w, "Element Amplify %d" % el, " +%d%%" % KOTORI_WPN_EL_AMP)
	if w.get("yep") is Dictionary and w.yep.get("elementAmplify") is Dictionary:
		var ea: Dictionary = w.yep.elementAmplify
		for ek in ["1", "2"]:
			if ea.has(ek):
				ea[ek] = float(KOTORI_WPN_EL_AMP) / 100.0
	_replace_tag(w, "passiveHarmRi", str(KOTORI_WPN_HARM))
	for sid in KOTORI_SKILLS:
		_replace_tag(w, "SkillPass%d" % sid, " %d%%" % KOTORI_WPN_SKILL_PASS)
	_replace_note_meta(w, "神兵(最终伤害+600%)", "神兵(最终伤害+%d%%)" % KOTORI_WPN_HARM)
	_replace_note_meta(w, "神兵(伤害+600%)", "神兵(伤害+%d%%)" % KOTORI_WPN_HARM)
	_replace_note_meta(w, "火焰/物理伤害+1200%", "火焰/物理伤害+%d%%" % KOTORI_WPN_EL_AMP)
	_replace_note_meta(w, "专属技能伤害+1500%", "专属技能伤害+%d%%" % KOTORI_WPN_SKILL_PASS)


# ---- 天剑·非天补丁 ----

static func _patch_feitian_skill(sk: Dictionary, old_coef: int, new_coef: int) -> void:
	var dmg: Dictionary = sk.get("damage", {})
	if dmg is Dictionary:
		var f := str(dmg.get("formula", ""))
		f = f.replace("* %d *" % old_coef, "* %d *" % new_coef)
		f = f.replace("user.cri", "Math.min(user.cri,%d)" % FEITIAN_CRI_CAP)
		f = f.replace("a.cri", "Math.min(a.cri,%d)" % FEITIAN_CRI_CAP)
		dmg.formula = f
		if dmg.get("formulaGd") is String:
			var fg := str(dmg.formulaGd)
			fg = fg.replace("* %d *" % old_coef, "* %d *" % new_coef)
			fg = fg.replace("a.cri", "minf(a.cri,%d.0)" % FEITIAN_CRI_CAP)
			dmg.formulaGd = fg
		if dmg.get("formulaProgram") is Dictionary:
			_walk_feitian_ast(dmg.formulaProgram.get("steps", []), float(old_coef), float(new_coef))
	# 卡面文案同步标明暴击率计入上限（1000%）
	var cap_txt := "暴击率(上限%d%%)" % (FEITIAN_CRI_CAP * 100)
	if str(sk.get("note", "")).contains("暴击率") and not str(sk.get("note", "")).contains("上限%d%%" % (FEITIAN_CRI_CAP * 100)):
		_replace_note_meta(sk, "暴击率", cap_txt)
	elif str(sk.get("note", "")).contains("暴击*2") and not str(sk.get("note", "")).contains("上限%d%%" % (FEITIAN_CRI_CAP * 100)):
		_replace_note_meta(sk, "暴击*2", "暴击(上限%d%%)*2" % (FEITIAN_CRI_CAP * 100))


static func _walk_feitian_ast(node, old_coef: float, new_coef: float) -> Variant:
	if node is Dictionary:
		var op := str(node.get("op", ""))
		if op == "literal" and is_equal_approx(float(node.get("value", 0.0)), old_coef):
			node.value = new_coef
			return node
		if op == "property" and str(node.get("receiver", "")) == "a" and str(node.get("name", "")) == "cri":
			return {"op": "math", "pos": int(node.get("pos", 0)), "name": "min", "args": [node, {"op": "literal", "pos": 0, "value": float(FEITIAN_CRI_CAP)}]}
		for k in node.keys():
			node[k] = _walk_feitian_ast(node[k], old_coef, new_coef)
		return node
	if node is Array:
		for i in range(node.size()):
			node[i] = _walk_feitian_ast(node[i], old_coef, new_coef)
	return node


static func _patch_feitian_st2739(st: Dictionary) -> void:
	var k := float(FEITIAN_ST_2739_PCT) / 100.0
	for e in st.get("effects", []):
		if e is Dictionary and str(e.get("op", "")) == "mul" and is_equal_approx(float(e.get("k", 0.0)), 2.5):
			e.k = k
	st.note = str(st.get("note", "")).replace("value * 2.5", "value * %.1f" % k)


# ---- 既有 Weapon 87 实例双向同步（读档／星级仓库存取）----

static func is_tracked_gear(item: Dictionary) -> bool:
	return str(item.get("kind", "")) == "weapon" and int(item.get("base", item.get("id", 0))) == KOTORI_WPN


static func after_load(s: XState) -> int:
	if s == null:
		return 0
	var want_nerf := ENABLED and not XTianqi.active(s)
	var all := s.gear.duplicate()
	for a in s.actors.values():
		all.append_array(a.raw_equip_list())
	for w in s.warehouses.values():
		for list in w.get("items", {}).values():
			for v in list:
				if v is Dictionary:
					all.append(v)
	var seen := []
	var changed := 0
	for item in all:
		if not (item is Dictionary) or seen.any(func(x): return is_same(x, item)):
			continue
		seen.append(item)
		if sync_gear_item(item, want_nerf):
			changed += 1
	if changed > 0:
		for a in s.actors.values():
			a.refresh_passive()
	return changed


static func sync_gear_for_state(s: XState, item: Dictionary) -> bool:
	var want_nerf := ENABLED and s != null and not XTianqi.active(s)
	return sync_gear_item(item, want_nerf)


static func _wpn87_pair() -> Array:
	var arr = XDB.table("Weapons")
	if not (arr is Array) or KOTORI_WPN >= arr.size() or not (arr[KOTORI_WPN] is Dictionary):
		return []
	var orig: Dictionary = arr[KOTORI_WPN]
	var cached = _gear_tpl_cache.get("weapon:87")
	if cached is Array and cached.size() == 2 and is_same(cached[0], orig):
		return cached
	var nw: Dictionary = orig.duplicate(true)
	_patch_kotori_wpn87(nw)
	var pair := [orig, nw]
	_gear_tpl_cache["weapon:87"] = pair
	return pair


static func sync_gear_item(item: Dictionary, want_nerf: bool) -> bool:
	if not is_tracked_gear(item):
		return false
	var own_note := str(item.get("note", ""))
	if own_note.is_empty():
		return false
	var from_el := 1200 if want_nerf else KOTORI_WPN_EL_AMP
	var to_el := KOTORI_WPN_EL_AMP if want_nerf else 1200
	var from_sp := 1500 if want_nerf else KOTORI_WPN_SKILL_PASS
	var to_sp := KOTORI_WPN_SKILL_PASS if want_nerf else 1500
	var from_hm := 600 if want_nerf else KOTORI_WPN_HARM
	var to_hm := KOTORI_WPN_HARM if want_nerf else 600
	var new_note := own_note
	for el in [1, 2]:
		new_note = new_note.replace("<Element Amplify %d: +%d%%>" % [el, from_el], "<Element Amplify %d: +%d%%>" % [el, to_el])
	new_note = new_note.replace("<passiveHarmRi:%d>" % from_hm, "<passiveHarmRi:%d>" % to_hm)
	for sid in KOTORI_SKILLS:
		new_note = new_note.replace("<SkillPass%d: %d%%>" % [sid, from_sp], "<SkillPass%d: %d%%>" % [sid, to_sp])
	new_note = new_note.replace("神兵(最终伤害+%d%%)" % from_hm, "神兵(最终伤害+%d%%)" % to_hm)
	new_note = new_note.replace("神兵(伤害+%d%%)" % from_hm, "神兵(伤害+%d%%)" % to_hm)
	new_note = new_note.replace("火焰/物理伤害+%d%%" % from_el, "火焰/物理伤害+%d%%" % to_el)
	new_note = new_note.replace("专属技能伤害+%d%%" % from_sp, "专属技能伤害+%d%%" % to_sp)
	if new_note == own_note:
		return false
	item.note = new_note
	item.meta = XZhenqi.extract_meta(new_note)
	# yep.elementAmplify 按基值差值同步（保留宝珠／词缀／强化／符文之语叠加）
	if item.get("yep") is Dictionary and item.yep.get("elementAmplify") is Dictionary:
		var ea: Dictionary = item.yep.elementAmplify
		var delta := float(to_el - from_el) / 100.0
		for ek in ["1", "2"]:
			if ea.has(ek):
				ea[ek] = snappedf(float(ea[ek]) + delta, 0.0001)
	return true


# ---- 通用替换工具 ----

static func _replace_tag(rec_d: Dictionary, tag: String, new_val: String) -> void:
	var re := RegEx.create_from_string("<" + _re_escape(tag) + ":[^>]*>")
	var note := str(rec_d.get("note", ""))
	if re.search(note) != null:
		rec_d.note = re.sub(note, "<%s:%s>" % [tag, new_val], true)
	var meta = rec_d.get("meta", {})
	if meta is Dictionary and meta.has(tag):
		meta[tag] = new_val


static func _replace_note_meta(rec_d: Dictionary, old: String, rep: String) -> void:
	var note := str(rec_d.get("note", ""))
	if note.contains(old):
		rec_d.note = note.replace(old, rep)
	var meta = rec_d.get("meta", {})
	if meta is Dictionary:
		var updated := {}
		var changed := false
		for k in meta.keys():
			var ks := str(k)
			var nk: Variant = ks.replace(old, rep) if ks.contains(old) else k
			var v = meta[k]
			var nv: Variant = str(v).replace(old, rep) if (v is String and str(v).contains(old)) else v
			if nk != k or nv != v:
				changed = true
			updated[nk] = nv
		if changed:
			rec_d.meta = updated


static func _re_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out
