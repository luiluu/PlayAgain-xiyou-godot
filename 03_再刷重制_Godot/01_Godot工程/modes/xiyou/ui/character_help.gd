class_name XCharacterHelp
extends RefCounted
## 特殊角色说明卡：照正式版 installDisplayPreferencesRuntime 的 characterHelpView（＋nowGrowthView、dyn2View）复现。
## 渡鸦 167～哈基米 178 的技能（10122～10299，及谷雨／屠苏／璇等带标签的技能）与专属装备（冥河断罪镰、黑龙心鳞、
## 破限之心、天衣铺……）的说明不在数据库描述里，而是从备注 <pos=APs> 行与 characterHelpCopies 表按角色当前状态现编。
## 原文表由转换器导出到 generated/db/CharacterHelp.json（characterHelpCopies、DYN2_IDS）。
##
## 角色状态：特殊角色尚未接入重制，这里一律按正式版图鉴的预览态（characterHelpActor 的 _characterHelpPreview 分支：
## 未招募、初始等级、未学会、0 阶、0 灵魂）。与 tests/xiyou_special_help 对 generated/oracle/special_help_cards.json
## （探针 03_转换工具/mv_oracle/special_help_probe.cjs）逐行核对。角色接入后，preview_actor() 换成真实角色状态，
## 各角色模块（CodexRaven、CodexSukuna……）的现算数值在 _module_value() 里接上。

const VIEW_COLOR := "rgba(235,240,247,1)"
## characterHelpTarget 认的专属装备号（originalBaseItemId／baseItemId／id）
const TARGET_GEAR := [4001, 4577, 4578, 4579, 4580, 4581, 7904, 7905, 7906, 7908, 7909, 7910, 7911,
	7920, 7921, 7922, 7923, 7924, 7925, 7926, 7927, 7928, 7929, 7930, 7931, 7932, 7933, 7934, 7935]

static var _data: Dictionary
static var _dyn2: Dictionary
static var _cache := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = XDB.load_json("db/CharacterHelp.json")
		_data = d if d is Dictionary else {"copies": {}, "dyn2Ids": []}
		_dyn2 = {}
		for i in _data.get("dyn2Ids", []):
			_dyn2[int(i)] = true
	return _data


static func _re(p: String) -> RegEx:
	if not _cache.has(p):
		_cache[p] = RegEx.create_from_string(p)
	return _cache[p]


static func _has(p: String, t: String) -> bool:
	return _re(p).search(t) != null


static func _sub(p: String, t: String, r: String, all := false) -> String:
	return _re(p).sub(t, r, all)


static func _is_skill(obj: Dictionary) -> bool:
	return obj.has("stypeId")


static func _note(obj: Dictionary) -> String:
	return str(obj.get("note", ""))


## characterHelpTarget
static func target(obj: Dictionary) -> bool:
	if obj.is_empty():
		return false
	if _note(obj).contains("<CodexCat:"):
		return true
	if _is_skill(obj):
		var id := int(obj.get("id", 0))
		return id >= 10122 and id <= 10299
	if not (obj.has("wtypeId") or obj.has("atypeId") or str(obj.get("kind", "")) in ["weapon", "armor"]):
		return false
	var base := int(obj.get("originalBaseItemId", obj.get("baseItemId", obj.get("id", 0))))
	return base in TARGET_GEAR


## characterHelpActor 的预览态：所属角色按标签或技能号区段定
static func owner_of(obj: Dictionary) -> int:
	var note := _note(obj)
	if note.contains("<CodexTusu:"):
		return 176
	if note.contains("<CodexXuan:"):
		return 177
	if note.contains("<GuyuSkill:"):
		return 175
	var id := int(obj.get("id", 0))
	if id == 10168:
		return 166
	if id == 10170:
		return 167
	for pair in [[10139, 167], [10167, 168], [10186, 169], [10202, 170], [10228, 171], [10249, 172], [10269, 173], [10287, 174]]:
		if id <= pair[0]:
			return pair[1]
	return 175


static func preview_actor(obj: Dictionary) -> Dictionary:
	if _note(obj).contains("<CodexCat:"):
		return {"id": 178, "level": 1, "rank": 0, "stage": 0, "soul": 0, "skills": [], "preview": true}
	var who := owner_of(obj)
	var lv := int(XDB.rec("Actors", who).get("initialLevel", 1))
	return {"id": who, "level": maxi(lv, 1), "rank": 0, "stage": 0, "soul": 0, "skills": [], "preview": true}


static func plain(text: String) -> String:
	return _sub("(?i)(?:\\\\|\u001b)c\\[\\d+\\]", text, "", true)


## helpNoteRows：备注里 <pos=APs text=… size=…> 的原文
static func note_rows(note: String) -> Array:
	var out := []
	for m in _re("(?i)<pos=APs\\s+text=([\\s\\S]*?)\\s+size=").search_all(note):
		out.append(plain(m.get_string(1)))
	return out


static func _ordinary_unlock(text: String) -> bool:
	return _has("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]\\s*(?:[\\x{4e00}-\\x{9fff}]{0,4})?\\d+级?\\s*$", plain(text))


static func resource_cost(text: String) -> bool:
	return _has("^(?:(?:基础)?(?:MP|TP)?)?消耗[：:]", text) and _has("(?:MP|TP|魔法)", text) and not _has("(?:行动|生命|残梦|朔望|唤醒)", text)


## helpNumber：Math.round(n×1e6)/1e6 的 JS 数字写法
static func num(n: float) -> String:
	var r := roundf(n * 1000000.0) / 1000000.0
	if is_equal_approx(r, roundf(r)) and absf(r) < 1e15:
		return str(int(roundf(r)))
	var s := String.num(r, 6)
	while s.contains(".") and s.ends_with("0"):
		s = s.left(-1)
	return s


# ======================================================================
# characterHelpView
# ======================================================================

## rows：desc_params＋元素等前置包装之后的行（同 Sprite_ItemHelp.setItem 后的 descParams）
static func view(obj: Dictionary, rows: Array, list_costs := false) -> Array:
	if not target(obj):
		return rows
	data()
	var actor := preview_actor(obj)
	var texts := note_rows(_note(obj))
	var extra := {}
	for t in texts:
		extra[t] = true
	var skill := _is_skill(obj)
	var id := int(obj.get("id", 0))
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	var copy = _data.copies.get(str(id)) if skill else null
	var use_copy: bool = copy != null and JSON.stringify(texts) == JSON.stringify(copy.get("source", []))
	var header := []
	var info := []
	var effects := []
	var growth := []
	var formula := []
	var footer := []
	var authored := []
	var element_rows := []
	var has_authored_cost := texts.any(func(t): return resource_cost(t))
	var has_actual_segments := texts.any(func(t): return _has("^实际段数[：:]", t))
	for row in rows:
		var text := plain(str(row[0]))
		if extra.has(text):
			authored.append(row)
			continue
		if skill and str(row[0]) == desc:
			continue
		if str(row[0]) == name or str(row[0]) == desc or _has("^品质[：:]", text):
			header.append(row)
			continue
		if _has("^(?:伤害属性|攻击属性|触发攻击属性)[：:]", text):
			var er: Array = row.duplicate()
			er[0] = "\\c[0]" + _sub("(?i)^(?:\\\\c\\[\\d+\\])+", str(row[0]), "")
			er[2] = VIEW_COLOR
			er[3] = false
			er[4] = 0
			element_rows.append(er)
			continue
		if _has("^(?:购买价格|出售价格|无法出售)", text):
			footer.append(row)
			continue
		if _has("^(?:MP消耗|TP消耗)[：:]", text):
			if list_costs or has_authored_cost:
				continue
			text = _sub("^(MP|TP)消耗：", XHelpCard._compact(text), "基础$1消耗：")
		if _has("^(?:MP消耗|TP消耗|基础MP消耗|基础TP消耗|分类|咒具熟练)[：:]|^(?:当前咒具|切换至此咒具)", text) or _has("^(?:特效|效果)[：:]", text):
			var dynamic: Array = row.duplicate()
			dynamic[0] = text
			authored.append(dynamic)
		elif text != "":
			header.append(row)
	if use_copy and not authored.is_empty():
		var native_rows := authored.filter(func(r): return not extra.has(plain(str(r[0]))))
		var protos := authored.filter(func(r): return extra.has(plain(str(r[0]))))
		var prototype: Array = protos[0] if not protos.is_empty() else authored[0]
		authored = []
		for t in copy.rows:
			var r: Array = prototype.duplicate()
			r[0] = str(t)
			r[3] = false
			r[4] = 0
			authored.append(r)
		authored.append_array(native_rows)
	var joined := []
	for row in authored:
		var raw := plain(str(row[0]))
		var text := XHelpCard._compact(raw)
		if has_actual_segments and _has("^攻击次数[：:]", raw):
			continue
		if _has("^实际段数[：:]", raw) and texts.any(func(t): return _has("^攻击次数[：:]", t) and t.contains("追加伤害另计")):
			text += "（追加伤害另计）"
		var cur = current_text(text, obj, actor)
		if cur == null or not _keep(str(cur), skill, list_costs):
			continue
		text = str(cur)
		if _has("^消耗[：:]\\s*(?:自己)?[一二三四五六七八九十\\d]+次?", text) and text.contains("行动"):
			text = _sub("^消耗[：:]", text, "代价：")
		var last = joined.back() if not joined.is_empty() else null
		if last != null and _has("^[＋+×－−-]", text) and _has("^(?:伤害|每段(?:基础)?|基础伤害|基式)[：:=＝]", str(last[0])):
			last[0] = str(last[0]) + text
			continue
		if last != null and _has("^[＋+×－−-]", str(last[0])) and _has("^(?:伤害|每段(?:基础)?|基础伤害|基式)[：:=＝]", text):
			text += str(last[0])
			joined.pop_back()
		var next: Array = row.duplicate()
		next[0] = text
		next[3] = false
		next[4] = 0
		joined.append(next)
	var seen := {}
	for row in joined:
		var text := str(row[0])
		if seen.has(text):
			continue
		seen[text] = true
		var styled: Array = row.duplicate()
		styled[2] = VIEW_COLOR
		if _has("^专属[：:]", text):
			styled[0] = "\\c[2]" + text
			header.append(styled)
		elif XHelpCard._is_info(text):
			styled[0] = "\\c[0]" + _sub("([\\x{4e00}-\\x{9fff}])[:]", text, "$1：", true)
			info.append(styled)
		elif XHelpCard._is_formula(text):
			styled[0] = "\\c[5]" + text
			formula.append(styled)
		elif XHelpCard._is_growth(text):
			if not _has("^(?:成长|每级|法宝每级|星魂预览|升级)", text):
				text = "成长：" + text
			styled[0] = "\\c[3]" + text
			growth.append(styled)
		else:
			styled[0] = "\\c[1]" + text
			effects.append(styled)
	# 预览态没有进阶变化（helpRankChanges 对 _characterHelpPreview 返回空）
	var size_row = info[0] if not info.is_empty() else (formula[0] if not formula.is_empty() else (effects[0] if not effects.is_empty() else null))
	if size_row != null:
		for r in element_rows:
			r[1] = size_row[1]
	info = element_rows + info
	var priority := ["目标", "伤害类型", "伤害属性", "命中", "暴击", "段数", "冷却", "准备时间"]
	var basic := []
	var other := []
	for row in info:
		var rank := priority.find(plain(str(row[0])).split("：")[0])
		if rank < 0:
			other.append(row)
		else:
			basic.append([rank, basic.size(), row])
	basic.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	info = basic.map(func(x): return x[2]) + other
	var compact := []
	for row in info:
		var last = compact.back() if not compact.is_empty() else null
		var left := plain(str(last[0])) if last != null else ""
		var right := plain(str(row[0]))
		var pair := last != null and ((_has("^目标[：:]", left) and _has("^伤害(?:属性|类型)[：:]", right))
			or (_has("^命中[：:]", left) and _has("^暴击[：:]", right))
			or (_has("^(?:暴击|段数)[：:]", left) and _has("^(?:段数|冷却)[：:]", right)))
		if pair and left.length() + right.length() <= 28 and last[1] == row[1]:
			last[0] = str(last[0]) + "；" + _sub("^\\\\c\\[0\\]", str(row[0]), "")
		else:
			compact.append(row.duplicate())
	var groups := [header, formula, compact, effects, growth, footer].filter(func(g): return not g.is_empty())
	for i in range(groups.size() - 1):
		var g: Array = groups[i]
		var last: Array = g.back().duplicate()
		last[3] = true
		g[g.size() - 1] = last
	var out := []
	for g in groups:
		out.append_array(g)
	return out


static func _keep(text: String, skill: bool, list_costs: bool) -> bool:
	if text == "" or _ordinary_unlock(text) or _has("^(?:装备限制|冷却(?:时间)?)[：:]无$", text):
		return false
	if _has("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]", text):
		return false
	if _has("^条件[：:]", text) and _has("(?:\\d+级|进阶)", text):
		return false
	if _has("^(?:生效)?条件[：:]已(?:学会|习得)本被动$", text) or _has("^条件[：:]完成第?[一二三四五六七八九十\\d]+次?进阶$", text):
		return false
	if skill and resource_cost(text) and (list_costs or _has("^(?:基础)?消耗[：:]0MP[／/]0TP$", text)):
		return false
	return true


# ======================================================================
# currentHelpText：分阶、等级门槛等改成当前状态；返回 null 表示这一行不显示
# ======================================================================

static func current_text(text: String, obj: Dictionary, actor: Dictionary):
	if not _is_skill(obj):
		return text
	var id := int(obj.get("id", 0))
	var lv := int(actor.level)
	var rank := int(actor.rank)
	var mastery := 0
	if _note(obj).contains("<CodexCat:"):
		return cat_help_text(text, obj, actor)
	text = _replace_num("角色等级[×*](\\d+(?:\\.\\d+)?)%", text, func(n): return num(lv * n) + "%")
	text = _replace_num("1[＋+]技能等级[×*](\\d+(?:\\.\\d+)?)%", text, func(n): return num(1 + mastery * n / 100.0))
	if _dyn2.has(id):
		return text
	var tier_rank := int(actor.stage) if int(actor.id) == 167 else rank
	text = current_tiers(text, tier_rank)
	var gate := _re("^(?:([^：:]{1,8})[：:])?(\\d+)级起(.+)$").search(text)
	if gate != null:
		if lv < int(gate.get_string(2)):
			return null
		text = (gate.get_string(1) if gate.get_string(1) != "" else "效果") + "：" + gate.get_string(3)
	if _has("进阶后(?:由|替换为)|第[一二三四五六七八九十\\d]+次进阶后由|(?:\\d+级)?进阶后替换", text):
		return null
	text = _sub("进阶后获得对应形态的", text, "获得当前形态的")
	text = _sub("×\\(1\\)$", text, "")
	# 角色专属分支（渡鸦、米拉……）只给 DYN2 以外的技能；这些角色的技能全在 DYN2 表里，预览态走不到
	var range_m := _re("^(?:效果：)?([0-9]+)[～~]([0-9]+)阶(?:[：:]|(?=命中))").search(text)
	if range_m != null:
		var current := int(actor.stage) if int(actor.id) == 167 else rank
		if current < int(range_m.get_string(1)) or current > int(range_m.get_string(2)):
			return null
		text = _replace_first(text, range_m.get_string(0), "效果：")
	var rank_gate := _re("^(?:效果：)?([一二三四五六七八九]|\\d+)阶(?:起|时)[：:]?").search(text)
	if rank_gate != null:
		var g := rank_gate.get_string(1)
		var n := int(g) if g.is_valid_int() else "一二三四五六七八九".find(g) + 1
		if rank < n:
			return null
		text = _replace_first(text, rank_gate.get_string(0), "效果：")
	var level_gate := _re("^(\\d+)级起[：:]").search(text)
	if level_gate != null:
		if lv < int(level_gate.get_string(1)):
			return null
		text = _replace_first(text, level_gate.get_string(0), "效果：")
	return text


static func _replace_num(pattern: String, text: String, f: Callable) -> String:
	var re := _re(pattern)
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + str(f.call(float(m.get_string(1))))
		at = m.get_end()
	return out + text.substr(at)


## helpCurrentTiers：「0～N阶依次为a／b／…」只取当前阶；「X%＋每阶Y%」算出
static func current_tiers(text: String, rank: int) -> String:
	var tier := _re("[（(](?:按[^（）()]*?)?0[～~](\\d)阶[）)]").search(text)
	if tier == null:
		tier = _re("[（(]?(?:按[^（）()，,]*?)?0[～~](\\d)阶(?:依次为)?[）)]?").search(text)
	if tier != null:
		var n := int(tier.get_string(1)) + 1
		var idx := clampi(rank, 0, n - 1)
		var list := _re("(×?)((?:[\\d.]+%?)(?:[／/][\\d.]+%?){%d})" % (n - 1)).search(text)
		if list != null:
			var vals := _split_slash(list.get_string(2))
			text = _replace_first(text, list.get_string(0), list.get_string(1) + vals[idx])
			text = _replace_first(text, tier.get_string(0), "")
			text = _sub("[，,；;：:]\\s*$", text, "")
			text = _sub("：\\s*[，,]", text, "：")
	text = _replace_pair("(\\d+(?:\\.\\d+)?)%[＋+]每阶(\\d+(?:\\.\\d+)?)%", text, func(b, s): return num(b + s * rank) + "%")
	text = _sub("×\\((\\d+(?:\\.\\d+)?%)\\)", text, "×$1", true)
	return text


static func _split_slash(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in _re("[^／/]+").search_all(s):
		out.append(m.get_string(0))
	return out


static func _replace_pair(pattern: String, text: String, f: Callable) -> String:
	var out := ""
	var at := 0
	for m in _re(pattern).search_all(text):
		out += text.substr(at, m.get_start() - at) + str(f.call(float(m.get_string(1)), float(m.get_string(2))))
		at = m.get_end()
	return out + text.substr(at)


## JS String.replace(字符串, …)：只换第一处
static func _replace_first(text: String, what: String, with: String) -> String:
	var at := text.find(what)
	return text if at < 0 or what == "" else text.substr(0, at) + with + text.substr(at + what.length())


# ======================================================================
# characterHelpView 外层：nowGrowthView（谷雨／屠苏／璇、「头顶」的「成长：」行）与 dyn2View（渡鸦～云裳）
# ======================================================================

static func after_view(obj: Dictionary, rows: Array) -> Array:
	data()
	rows = _now_growth_view(obj, rows)
	if _is_skill(obj) and _dyn2.has(int(obj.get("id", 0))):
		rows = _dyn2_view(obj, rows)
	return rows


static func _learned(a: Dictionary, id: int) -> bool:
	return id in a.get("skills", [])


static func _n2(v: float) -> String:
	return num(roundf(v * 100.0) / 100.0)


static func _pc(v: float) -> String:
	return num(roundf(v * 10.0) / 10.0) + "%"


## growthOwner：谷雨／屠苏／璇的「成长：」行按技能所属角色（预览态）的等级算
static func _growth_owner(obj: Dictionary):
	var note := _note(obj)
	var id := 176 if note.contains("<CodexTusu:") else (177 if note.contains("<CodexXuan:") else (175 if note.contains("<GuyuSkill:") else 0))
	if id == 0:
		return null
	return {"id": id, "level": maxi(1, int(XDB.rec("Actors", id).get("initialLevel", 1))), "rank": 0, "skills": [], "preview": true}


## CodexBinding.curve：按等级在节点之间线性插值
static func curve(a: Dictionary, values: Array, levels: Array = [1, 20, 40, 60]) -> float:
	var lv := maxf(1.0, float(a.get("level", 1)))
	if lv <= float(levels[0]):
		return float(values[0])
	for i in range(1, levels.size()):
		if lv <= float(levels[i]):
			return float(values[i - 1]) + (float(values[i]) - float(values[i - 1])) * (lv - float(levels[i - 1])) / (float(levels[i]) - float(levels[i - 1]))
	return float(values.back())


static func _now_growth_rows(obj: Dictionary):
	if _is_demon_crown(obj):
		# CodexDemonCrown.bonus：实例上累计的 _codexCrownBonus（上限 D.limit 随「头顶」实例接入再补）；数据库原型为 0
		return ["成长：八项全属性＋" + str(int(roundf(maxf(0.0, float(obj.get("_codexCrownBonus", 0)))))) + "%"]
	var a = _growth_owner(obj)
	if a == null:
		return null
	var lv := int(a.level)
	var rank := clampi(int(a.rank), 0, 5)
	var c := func(v, l = [1, 20, 40, 60]): return curve(a, v, l)
	var pct := func(n: float): return num(roundf(n * 1000.0) / 10.0) + "%"
	var x := func(n: float): return num(roundf(n * 100.0) / 100.0)
	var w := curve(a, [.1, .2, .35, .5, .65, .8, 1], [1, 10, 20, 30, 40, 50, 60])
	var tusu = {10312: "zhanfeng", 10313: "hengsao", 10314: "dianshe", 10315: "guanri", 10317: "chiling", 10318: "zhenji",
		10319: "jianqi", 10323: "zhenhun", 10324: "body_phys", 10325: "body_mag"}.get(int(obj.get("id", 0)))
	if tusu != null:
		return ["成长：伤害系数" + str(binding_coefficient("tusu", tusu, a))]
	var lock: String = "锁定倍率×" + x.call(c.call([1.3, 1.5], [20, 60]))
	var heming: String = "和鸣倍率×" + x.call(c.call([1.2, 1.5], [20, 60]))
	var huzhen: String = "护阵倍率×" + x.call(c.call([.85, .70], [20, 60]))
	var hg: String = "回光系数" + x.call(c.call([10, 20], [1, 60]))
	var hgf: String = pct.call(c.call([.20, .35], [1, 60]))
	var lbf: String = pct.call(c.call([.15, .35], [1, 60]))
	var gs: String = "双防共享比例" + pct.call(xuan_gongsu_defense_rate(a))
	var offense: String = "直接伤害提高" + pct.call(xuan_gongsu_damage_rate(a))
	var shadow := "成长：星影人数" + ("全部队友" if lv >= 60 else ("3名" if lv >= 50 else ("2名" if lv >= 40 else ("1名" if lv >= 30 else "0名"))))
	var passive := _re("<Codex(?:Tusu|Xuan):\\s*(passive\\.(?:temper|relay))\\s*>").search(_note(obj))
	if passive != null and passive.get_string(1) == "passive.temper":
		var tr := func(k: String): return "×" + x.call(tusu_temper_rate(a, k))
		return ["成长：剑气纵横伤害" + tr.call("support.jianqi"), "成长：横扫、点射、贯日伤害" + tr.call("arm.hengsao"),
			"成长：金汤护盾量、敕令伤害" + tr.call("support.jintang"), "成长：震击、镇魂重击伤害" + tr.call("arm.zhenji")]
	if passive != null and passive.get_string(1) == "passive.relay":
		return ["成长：接力比例" + pct.call(.3 if lv >= 60 else (.2 if lv >= 20 else 0.0))]
	match int(obj.get("id", 0)):
		10316:
			return ["成长：" + huzhen]
		10320:
			return ["成长：" + lock]
		10321:
			return ["成长：成长权重" + pct.call(w) + "；保底比例" + pct.call(c.call([.1, .3], [1, 60]))]
		10322:
			return ["成长：" + heming]
		10358:
			return ["成长：成长权重" + pct.call(w)]
		10359:
			return ["成长：" + lock + "；" + heming, "成长：" + huzhen, "成长：挫势－" + pct.call(1 - c.call([.90, .80], [20, 60])) + "（霸体目标－" + pct.call(1 - c.call([.85, .70], [20, 60])) + "）",
				"成长：横扫对后续目标增伤" + pct.call(c.call([1, 1.2], [20, 60]) - 1)]
		10360:
			return ["成长：额外提高" + pct.call(c.call([1, 1.2], [40, 60]) - 1 if lv >= 40 else 0.0)]
		10335:
			return ["成长：" + hg + "；保底比例" + hgf]
		10336:
			return ["成长：成长权重" + pct.call(w) + "；保底比例" + lbf]
		10337:
			return ["成长：伤害系数" + str(binding_coefficient("xuan", "lengguang", a))]
		10338, 10363:
			return [shadow]
		10339:
			return ["成长：" + gs, "成长：" + offense]
		10361:
			return ["成长：" + hg + "；回光保底比例" + hgf, "成长：璃壁成长权重" + pct.call(w) + "；璃壁保底比例" + lbf]
		10362:
			return ["成长：" + gs.replace("双防共享比例", "共宿比例") + "；额外默契" + str(int(floorf(c.call([1, 3], [20, 60]))) if lv >= 20 else 0) + "点"]
		10290:
			return ["成长：转移比例可选25%／50%／75%" if lv >= 10 else "成长：转移比例50%"]
		10298:
			return ["成长：待绽比例" + ("50%" if lv >= 60 else "35%") + "；花荫倍率×" + ("1.2" if lv >= 60 else ("1.1" if lv >= 20 else "1"))]
		10288:
			return ["成长：治疗比例" + pct.call(c.call([.25, .30, .35, .40], [1, 20, 40, 60]))]
		10293:
			return ["成长：队友储备比例" + pct.call(c.call([1, 1.25, 1.5, 1.75], [1, 20, 40, 60]) + .15 * rank), "成长：绽放系数" + x.call(c.call([5, 6, 7, 8], [1, 20, 40, 60]))]
		10292:
			return ["成长：归春系数" + x.call(c.call([33, 50], [40, 60]))]
	return null


static func _now_growth_view(obj: Dictionary, rows: Array) -> Array:
	var found = _now_growth_rows(obj)
	if found == null:
		return rows
	var new_rows: Array = found
	var old := rows.filter(func(r): return _has("^成长[：:]", plain(str(r[0]))))
	if old.is_empty():
		return rows
	var line = old.back()[3]
	var out := []
	for r in rows:
		if not is_same(r, old[0]) and old.any(func(o): return is_same(o, r)):
			continue
		if not is_same(r, old[0]):
			out.append(r)
			continue
		for k in range(new_rows.size()):
			var v: Array = r.duplicate()
			v[0] = "\\c[3]" + str(new_rows[k])
			v[3] = line if k == new_rows.size() - 1 else false
			out.append(v)
	return out


## dyn2：说明行按前缀换成当前数值（预览态：未学会、0 阶、0 灵魂）
static func _dyn2_map(obj: Dictionary, a: Dictionary) -> Dictionary:
	var id := int(obj.get("id", 0))
	var who := int(a.id)
	var lv := int(a.level)
	var rank := int(a.rank)
	var out := {}
	if who == 167:
		var st := clampi(int(a.stage), 0, 5)
		var soul := float(a.soul)
		var p := clampf(soul / 150000.0, 0.0, 1.0)
		var has := func(i: int): return _learned(a, i)  # hasRavenSkill 另看 SKILL_GATE 的等级／阶数；预览态未学会，用不到
		if id >= 10122 and id <= 10126:
			out["成长：魄倍率"] = "成长：魄倍率" + _n2(raven_legion_rate(a)) + "；阶位系数" + _n2(raven_skill_coefficient(a, id))
		if id == 10128 or id == 10135:
			out["成长：下一阶门槛"] = ("成长：下一阶门槛" + str(RAVEN_REQUIRE[st + 1]) + "灵魂（已有" + str(int(floorf(soul))) + "）") if st < 5 else "成长：已完成五阶"
		if id == 10130:
			out["成长：魔防穿透率"] = "成长：魔防穿透率" + _pc((1.0 - raven_defense_factor(a)) * 100.0)
		if id == 10131:
			out["成长：专属黑暗"] = "成长：专属黑暗魔法伤害＋" + _pc(200 + p * 100 if has.call(id) else 0.0) + "；专属魔法最终伤害×" + _n2(1 + 1.5 * minf(1.0, (st + p) / 5.0) if has.call(id) else 1.0)
		if id == 10137:
			var gp := raven_growth_pools(a) if _learned(a, id) else {"critical": 0.0, "final": 0.0}
			out["成长：爆伤"] = "成长：爆伤＋" + _pc(gp.critical) + "；终伤＋" + _pc(gp.final)
			out["成长：专属魔法暴击率"] = "成长：专属魔法暴击率＋" + _pc(p * 1000 if _learned(a, id) else 0.0)
			out["成长：冥河成长倍率"] = "成长：冥河成长倍率×" + _n2(raven_growth_rate(a))
		if id == 10138:
			out["成长：魄倍率"] = "成长：魄倍率" + _n2(raven_legion_rate(a))
		if id == 10139:
			out["成长：冠冕倍率"] = "成长：冠冕倍率×" + _n2(raven_crown_rate(a))
	if who == 168:
		var dragon := false  # 战斗中、三阶、学会 10161 且处于状态 2592；预览态不在战斗
		if id == 10144:
			out["成长：人形物防"] = "成长：人形物防、魔防×" + _n2(1.25 * (1 + .25 * minf(1, (lv - 30) / 5.0)) if not dragon and lv >= 30 and _learned(a, id) else 1.0)
		if id == 10145:
			out["成长：人形速度"] = "成长：人形速度×" + _n2(1.1 * (1 + .25 * minf(1, (lv - 40) / 5.0)) if not dragon and lv >= 40 and _learned(a, id) else 1.0)
		if id == 10156:
			var on := _learned(a, id)
			var dmg := 2.0 if lv >= 60 else (1.8 + .02 * (lv - 50) if lv >= 50 else (1.66 + .14 * (lv - 15) / 35.0 if lv >= 15 else 1.15 + .051 * maxf(0, lv - 5)))
			var cr := 0.0 if lv < 5 else (.15 + .08 * (lv - 5) if lv <= 15 else .95 + 7.93 * minf(1, (lv - 15) / 55.0))
			out["成长：共鸣倍率"] = "成长：共鸣倍率×" + _n2(dmg if on and not dragon and lv >= 5 else 1.0) + "；暴击率＋" + _pc(cr * 100 if on else 0.0)
	if who == 169 and id >= 10171 and id <= 10174:
		var seg := (6 if id == 10174 else 2) + mini(6, int(floorf(float(a.get("luk", 0)) / 6666.0)))
		out["段数："] = "段数：" + str(seg) + "（幸运每6666点＋1段，最多＋6）"
	if who == 170 and id == 10196:
		out["成长：寒川映月上限"] = "成长：寒川映月上限×" + ("2.5" if _learned(a, 10202) else "1.8")
	if who == 171:
		if id == 10205:
			out["成长：最大生命"] = "成长：最大生命＋" + _pc(lv * 10) + "；物攻、速度＋" + _pc(lv * 5)
			out["成长：暴击率"] = "成长：暴击率＋" + _pc(lv * 10) + "；爆伤、终伤＋" + _pc(lv * 40)
		if id == 10205 or id == 10211 or (id >= 10216 and id <= 10223):
			var main := id == 10205 or (id >= 10216 and id <= 10219)
			out["成长：咒具成长系数"] = "成长：咒具成长系数×" + num(roundf(toji_output_growth(a, main) * 1000.0) / 1000.0)
	if who == 172 and id == 10242:
		out["成长：斩击强化"] = "成长：斩击强化：未储存"  # 预览态没有储存的斩击强化
	if who == 174:
		var yh := func(i: int): return _learned(a, i)  # 预览态什么也没学会，门槛不必再看
		if id in [10270, 10271, 10274]:
			out["目标："] = "目标：" + ("敌方全体" if yh.call(10276) else "敌方单体")
			out["段数："] = "段数：" + str(2 if yh.call(10277) else 1)
		var mul := 4.0 if lv >= 50 and rank >= 2 else (3.0 if lv >= 40 and rank >= 1 else (2.5 if lv >= 35 and rank >= 1 else (2.0 if lv >= 30 else (1.5 if lv >= 25 else 1.0))))
		if id >= 10276 and id <= 10281 and id != 10280:
			var t := "成长：生命、魔攻、敏捷成长×" + num(mul)
			if id == 10276:
				t += "；爆伤＋" + _pc(0) + "；终伤＋" + _pc(0)  # offensiveGrowth 只在学会云丝展幅后
			out["成长：生命、魔攻、敏捷成长"] = t
	return out


static func _dyn2_view(obj: Dictionary, rows: Array) -> Array:
	var map := _dyn2_map(obj, preview_actor(obj))
	var keys := map.keys()
	if keys.is_empty():
		return rows
	var out := []
	for r in rows:
		var raw := str(r[0])
		var p := plain(raw)
		var color_m := _re("(?i)^(?:\\\\c\\[\\d+\\])+").search(raw)
		var color := color_m.get_string(0) if color_m != null else ""
		var whole = null
		for k in keys:
			if str(k).begins_with("成长") and p.begins_with(str(k)):
				whole = k
				break
		if whole != null:
			var w: Array = r.duplicate()
			w[0] = color + str(map[whole])
			out.append(w)
			continue
		var done := false
		var parts := []
		for part in p.split("；"):
			var hit = null
			for k in keys:
				if hit == null and part.begins_with(str(k)):
					hit = k
			if hit == null:
				parts.append(part)
			else:
				done = true
				parts.append(str(map[hit]))
		if not done:
			out.append(r)
			continue
		var row: Array = r.duplicate()
		row[0] = color + "；".join(parts)
		out.append(row)
	return out


# ---- 渡鸦（Codex_Raven／installNativeRavenRuntime）----
const RAVEN_REQUIRE := [0, 3000, 12000, 35000, 80000, 150000]
const RAVEN_COEFFICIENTS := {10122: [9, 6.9, 3.9, 2.0, 1.3, 1], 10123: [0, 6.9, 3.9, 2.0, 1.3, 1],
	10124: [0, 0, 0.39, 0.19, 0.13, 0.1], 10125: [0, 0, 0, 0.6, 0.39, 0.33], 10126: [0, 0, 0, 0, 0.19, 0.2]}
const RAVEN_GROWTH := [[10, 16], [15, 35], [20, 50], [25, 33], [30, 27], [35, 191], [40, 22], [45, 6], [50, 7], [55, 3],
	[60, 1.2], [65, 1], [70, 2.66], [75, 2.66], [80, 2.66]]


## 以下 hasRavenSkill 只看是否学会（SKILL_GATE 的等级／阶数门槛随渡鸦接入再补）
static func raven_legion_rate(a: Dictionary) -> float:
	if not _learned(a, 10138):  # R.SKILL.LEGION
		return 1.0
	return [6, 10, 20, 33, 66, 99][clampi(int(a.stage), 0, 5)] / 11.0


static func raven_skill_coefficient(a: Dictionary, id: int) -> float:
	var rates = RAVEN_COEFFICIENTS.get(id)
	return float(rates[clampi(int(a.stage), 0, 5)]) if rates != null else 1.0


static func raven_crown_rate(a: Dictionary) -> float:
	if not _learned(a, 10139):  # R.SKILL.CROWN
		return 1.0
	return [1, 1, 1, 1.5, 1.5, 2][clampi(int(a.stage), 0, 5)]


static func raven_defense_factor(a: Dictionary) -> float:
	if not _learned(a, 10130):
		return 1.0
	var p := clampf(float(a.soul) / 150000.0, 0.0, 1.0)
	return 1.0 - minf(0.90, 0.60 + 0.30 * p)


static func raven_growth_pools(a: Dictionary) -> Dictionary:
	var lv := clampf(float(a.level), 1, 70)
	var knots := [[1, 0, 0], [10, 20, 15], [25, 80, 60], [40, 180, 140], [55, 300, 240], [70, 500, 399]]
	for i in range(1, knots.size()):
		if lv <= knots[i][0]:
			var x: Array = knots[i - 1]
			var y: Array = knots[i]
			var p: float = (lv - x[0]) / float(y[0] - x[0])
			return {"critical": x[1] + p * (y[1] - x[1]), "final": x[2] + p * (y[2] - x[2])}
	return {"critical": 500.0, "final": 399.0}


static func raven_growth_rate(a: Dictionary) -> float:
	var lv := int(a.level)
	var best = null
	for kv in RAVEN_GROWTH:
		if best == null or lv >= kv[0]:
			best = kv
	return float(best[1])


static func _is_demon_crown(obj: Dictionary) -> bool:
	var base := int(obj.get("originalBaseItemId", obj.get("baseItemId", obj.get("id", 0))))
	var armor := obj.has("atypeId") or str(obj.get("kind", "")) == "armor"
	return (armor and base == 7940) or _has("(?i)<CodexDemonCrown>", _note(obj))


# ---- 屠苏、璇（CodexBinding.bindGrowth）----
## 带 <CodexTusu: …>／<CodexXuan: …> 的技能键；没有为 ""
static func bound(obj: Dictionary) -> Array:
	if not _is_skill(obj):
		return []
	var m := _re("<Codex(Tusu|Xuan):\\s*([^>]+?)\\s*>").search(_note(obj))
	return [] if m == null else [m.get_string(1).to_lower(), m.get_string(2)]


## M.coefficient(key, a)：⌊按等级在成长节点之间插值⌋
static func binding_coefficient(who: String, key: String, a) -> int:
	var g: Dictionary = data().get(who + "Growth", {})
	var values: Array = g.get("damage", {}).get(key, [0, 0, 0, 0])
	return int(floorf(curve(a if a is Dictionary else {}, values, g.get("levels", [1, 20, 40, 60]))))


## installNativeBindingChargeRuntime 的 setItem：屠苏／璇的技能把「伤害：…×N」换成当前系数（按已招募的本人；
## 未招募时按 1 级）。另外它把说明交给内层时换成了副本，副本不在 $dataSkills 里，元素说明（installDamageElementRuntime）
## 因此不加「伤害属性」行；正式版第一次看说明时 descParams 还没缓存，不走这里，之后每次都走。重制照常态。
static func binding_rows(obj: Dictionary, rows: Array) -> Array:
	var b := bound(obj)
	if b.is_empty():
		return rows
	var dk: String = str(b[1]).trim_prefix("arm.").trim_prefix("support.").replace("body.phys", "body_phys").replace("body.mag", "body_mag")
	var g: Dictionary = data().get(b[0] + "Growth", {}).get("damage", {})
	if not g.has(dk):
		return rows
	var out := []
	for r in rows:
		var v: Array = r.duplicate()
		var text := str(v[0])
		if _has("伤害[:：]", text):
			var m := _re("×[\\d.]+(?:亿)?(?:（随等级成长）)?").search(text)
			if m != null:
				text = text.substr(0, m.get_start()) + "×" + str(binding_coefficient(b[0], dk, {"level": 1})) + text.substr(m.get_end())
		v[0] = text
		out.append(v)
	return out


static func tusu_temper_rate(a: Dictionary, k: String) -> float:
	var at = {"support.jianqi": 10, "arm.hengsao": 20, "arm.dianshe": 20, "arm.guanri": 20, "support.jintang": 30,
		"arm.chiling": 30, "arm.zhenji": 40, "support.zhenhun": 40}.get(k)
	var lv := int(a.get("level", 1))
	if at == null or lv < at:
		return 1.0
	return 1.1 if lv < 60 or k == "support.jianqi" else 1.2


## 共宿：学会「共宿」且到解锁等级（10）后才有；预览态未学会，为 0
static func xuan_gongsu_damage_rate(a: Dictionary) -> float:
	return curve(a, [.10, .30], [10, 60]) if _xuan_gongsu(a) else 0.0


static func xuan_gongsu_defense_rate(a: Dictionary) -> float:
	return curve(a, [.15, .30], [20, 60]) if _xuan_gongsu(a) else 0.0


static func _xuan_gongsu(a: Dictionary) -> bool:
	var id := tag_skill("<CodexXuan:\\s*gongsu\\s*>")
	return id > 0 and _learned(a, id) and int(a.get("level", 1)) >= 10


static var _tag_ids := {}

## 备注带某个标签的技能号（角色模块的 ids()：按标签找技能，同标签取最后一个）；没有为 0
static func tag_skill(pattern: String) -> int:
	if not _tag_ids.has(pattern):
		_tag_ids[pattern] = 0
		for s in XDB.table("Skills"):
			if s is Dictionary and _has(pattern, str(s.get("note", ""))):
				_tag_ids[pattern] = int(s.id)
	return _tag_ids[pattern]


# ---- 伏黑甚尔（installNativeTojiRuntime T.outputGrowth）----
static func toji_output_growth(a: Dictionary, main: bool) -> float:
	var lv := maxf(1.0, float(a.get("level", 1)))
	var anchor := 20.0 if main else 10.0
	var p := _toji_original(anchor)
	var base := (1 + 0.1 * anchor) * p if main else p
	if lv <= anchor:
		return (1 + 0.1 * lv if main else 1.0) * _toji_original(lv)
	var slope := 0.1 * p + (1 + 0.1 * anchor) * 0.00072 * anchor if main else 0.00072 * anchor
	return _smooth_tail(lv, anchor, base, slope, 0.188208 * (8.0 if main else 1.0))


static func _toji_original(lv: float) -> float:
	return 1.0 if lv >= 50 else 0.10 + 0.90 * pow(lv / 50.0, 2)


static func _smooth_tail(lv: float, anchor: float, base: float, slope: float, end: float) -> float:
	var span := 70.0 - anchor
	var delta := end - base
	var lo := 0.000001
	var hi := 10.0
	for i in range(64):
		var k := (lo + hi) / 2.0
		if delta * k / (1 - exp(-k * span)) > slope:
			hi = k
		else:
			lo = k
	var rate := (lo + hi) / 2.0
	return base + delta * (1 - exp(-rate * (lv - anchor))) / (1 - exp(-rate * span))


# ---- 哈基米（installImportedBalanceRuntime CodexCat.helpText）----
const CAT_WEIGHTS := {"slash": 1.0, "cross": 5.0 / 6.0, "flurry": .35, "holy": 10.0 / 3.0, "echo": 5.0 / 6.0}


static func cat_key(obj: Dictionary) -> String:
	var m := _re("<CodexCat:\\s*([^>]+?)\\s*>").search(_note(obj))
	return "" if m == null else m.get_string(1)


## 进阶：35 级、进阶 1 次、学会 <CodexCat: advanced> 技能
static func _cat_advanced(a: Dictionary) -> bool:
	return int(a.get("level", 1)) >= 35 and int(a.get("rank", 0)) >= 1 and _learned(a, tag_skill("<CodexCat:\\s*advanced\\s*>"))


## C.growth：35 级前 1→10→20→30→35 级 6%→15%→30%→70%→100%；之后要进阶
static func cat_growth(a: Dictionary) -> float:
	var l := float(a.get("level", 1))
	if l >= 35:
		if not _cat_advanced(a):
			return 1.0
		var al := [35, 50, 60, 70, 81]
		var ar := [.30, .45, .62, .80, .875]
		if l >= 81:
			return ar[4]
		for j in range(1, al.size()):
			if l <= al[j]:
				return maxf(.5, ar[j - 1] + (ar[j] - ar[j - 1]) * (l - al[j - 1]) / (al[j] - al[j - 1]))
		return 1.0
	var ls := [1, 10, 20, 30, 35]
	var rs := [.06, .15, .3, .7, 1]
	for i in range(1, ls.size()):
		if l <= ls[i]:
			return rs[i - 1] + (rs[i] - rs[i - 1]) * (l - ls[i - 1]) / (ls[i] - ls[i - 1])
	return 1.0


static func cat_help_text(text: String, obj: Dictionary, a: Dictionary) -> String:
	var k := cat_key(obj)
	var h := 0  # 剑心层数只在战斗中有
	var g := cat_growth(a)
	var weight: float = CAT_WEIGHTS.get(k, 0.0)
	var adv := _cat_advanced(a)
	var n := func(v: float): return num(roundf(v * 1000.0) / 1000.0)
	if _has("^伤害[：:]", text) and weight != 0.0:
		return "伤害：[己·物理攻击×" + n.call(1500 * weight * g) + "＋己·速度×" + n.call(3000 * weight * g) + "]×[1＋剑技等级]×[1＋剑技等级×0.1]"
	if k == "sword" and text.contains("抱剑护身"):
		var agi := float(a.get("agi", 0))
		if agi == 0.0:
			return "效果：抱剑护身，速度提供物理及元素固定减伤"
		return "效果：抱剑护身，物理减伤" + str(mini(16000, mini(int(floorf(3 * agi)), 15030 + int(floorf(agi / 8))))) + "；元素减伤" + str(mini(18000, mini(int(floorf(3.2 * agi)), 16400 + int(floorf(2 * agi / 11)))))
	if k == "trial" and text.contains("哈基米独自挑战守誓巨龙"):
		return "效果：哈基米独自挑战守誓巨龙，巨龙使用固定试炼难度"
	if k == "heart" and text.contains("进阶后专属剑技"):
		return "效果：专属剑技结算伤害+100%" if adv else "条件：进阶后专属剑技结算伤害+100%"
	if k == "speed" and text.contains("进阶后额外"):
		return "效果：额外行动＋1" if adv else "条件：进阶后额外获得1次行动"
	if k == "heart" and text.contains("进阶后终技"):
		return "效果：终技消费剑心，追加同层数神圣剑段；满层冷却减1" if adv else "条件：进阶后终技消费剑心，追加同层数神圣剑段；满层冷却减1"
	if k == "holy" and text.contains("冷却4"):
		if adv:
			return "冷却时间：" + str(3 if h == 3 else 4) + "个自然回合；" + ("消耗剑心追加" + str(h) + "段神圣剑影" if h else "施放时消耗剑心，每层追加1段神圣剑影，满层冷却3回合")
		return "冷却时间：4个自然回合；进阶后消耗剑心追加神圣剑影，满层冷却3回合"
	return text
