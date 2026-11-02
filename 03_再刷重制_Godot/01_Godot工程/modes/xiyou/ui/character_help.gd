class_name XCharacterHelp
extends RefCounted
## 专属角色技能说明卡（正式 installDisplayPreferencesRuntime.js 的 characterHelpView，技能 10122～10299）：
## XHelpCard.content 对这一段技能改走这里，其余技能仍走 genericHelpView（XHelpCard._generic_view）。
## 照原版次序：
## 1. characterHelpActor：按技能号定所属角色（≤10139 渡鸦 167、≤10167 米拉 168、10168 奈叶 166、≤10186 黄泉 169、≤10202 镜流 170、
##    ≤10228 甚尔 171、≤10249 宿傩 172、≤10269 饿狼 173、≤10287 云裳 174，其余谷雨 175；10170 也算渡鸦），
##    有这个角色（XState.current.actors）就用它，否则是初始状态的预览（null：等级取 initialLevel、0 阶、没学技能）。
##    原版在技能界面／战斗技能窗里取窗口正在看的角色；重制说明卡不知道窗口，一律按所属角色取。
## 2. 备注 <pos=APs text=…> 的行（及插进来的「伤害属性」行，去色后与备注同文）算作者行；技能里与描述相同的行不显示；
##    名字、描述、品质进抬头；数据库 MP／TP 消耗行在有作者消耗行时不显示，否则改成「基础MP消耗：」。
##    10168 只在备注与旧副本 source 完全一致时换成副本 rows（全库只有它一致）。
## 3. 作者行逐行 compactHelpText→currentHelpText→keep；「伤害：…」与紧邻的「＋…／×…」行并成一行。
##    currentHelpText：「角色等级×n%」「1＋技能等级×n%」代入当前值；消耗行（有角色时）换成实际 skillMpCost／skillTpCost；
##    DYN2 里的技能到此为止（10122～10287 除 10168、10169、10197～10199、10227、10228 外全在内），其余再按阶位／等级门槛取当前分支。
## 4. 分组上色：专属 \c[2] 进抬头、基本信息 \c[0]、公式 \c[5]、成长 \c[3]（不以成长类字头开头的补「成长：」）、其余效果 \c[1]；
##    渡鸦 10137 另加「成长：冥河成长倍率×n」；伤害属性行字号取基本信息首行，排在基本信息前；
##    基本信息按 目标→伤害类型→伤害属性→命中→暴击→段数→冷却→准备时间 排序，「目标＋伤害属性／类型」「命中＋暴击」「暴击／段数＋段数／冷却」
##    同字号且合计不超过 28 字时并成一行；六组之间分隔。
## 5. dyn2View：按前缀把行换成当前数值（渡鸦魄倍率／阶位系数／魔防穿透／魂海池，米拉人形倍率与共鸣，黄泉段数，宿傩术式威力／斩击强化，甚尔暴君成长与咒具成长系数，
##    饿狼形态系数／进化／解析／当前形态）。
## 未移植：listCosts（技能界面／战斗里消耗行不显示；重制说明卡不知道窗口，一律显示）、helpRankChanges「进阶变化」行（只在已进阶时出现）、
## 镜流星魂行（镜流第二期）、云裳的 dyn2、各角色第二期才有的战斗内字段（渡鸦灵魂恒 0、
## 宿傩斩击强化恒「未储存」）、专属装备（4001、4577～4581、破限之心等）的角色说明。

const VIEW_COLOR := "rgba(235,240,247,1)"
## DYN2_IDS：currentHelpText 在消耗行之后直接返回，改由 dyn2 按前缀换行
const DYN2_GAPS := [10168, 10169, 10197, 10198, 10199, 10227, 10228]
## characterHelpCopies 里与现行备注一致的只有 10168（其余备注都改过，副本不生效）
const COPIES := {10168: {"rows": ["生效条件：奈叶出场", "效果：队友击败敌人时，奈叶的“适应”成长同样触发一次", "成长：每次永久增加最大生命10、最大魔法30"],
	"source": ["效果:队友击败敌人时，奈叶的“适应”成长同样触发一次；最大生命永久+10，最大魔法永久+30"]}}


static func target(obj: Dictionary) -> bool:
	var id := int(obj.get("id", 0))
	return obj.has("stypeId") and id >= 10122 and id <= 10299


static func owner(obj: Dictionary) -> int:
	var id := int(obj.get("id", 0))
	var note := str(obj.get("note", ""))
	if note.contains("<CodexTusu:"):
		return 176
	if note.contains("<CodexXuan:"):
		return 177
	if note.contains("<GuyuSkill:"):
		return 175
	if id <= 10139: return 167
	if id <= 10167: return 168
	if id == 10168: return 166
	if id == 10170: return 167
	if id <= 10186: return 169
	if id <= 10202: return 170
	if id <= 10228: return 171
	if id <= 10249: return 172
	if id <= 10269: return 173
	if id <= 10287: return 174
	return 175


## 所属角色；没有时返回 null（预览）
static func actor(obj: Dictionary):
	var s := XState.current
	var who := owner(obj)
	return s.actors[who] if s != null and s.actors.has(who) else null


static func _level(obj: Dictionary, a) -> int:
	return int(a.level) if a != null else maxi(1, int(XDB.rec("Actors", owner(obj)).get("initialLevel", 1)))


static func _rank(obj: Dictionary, a) -> int:
	return XAdvance.rank(XState.current, owner(obj)) if a != null and XState.current != null else 0


static func _learned(a, id: int) -> bool:
	return a != null and a.skill_ids.has(id)


## helpNumber：四舍五入到 6 位小数
static func num(v: float) -> String:
	return XCat._js_num(roundf(v * 1000000.0) / 1000000.0)


static func _re(p: String, t: String) -> bool:
	return RegEx.create_from_string(p).search(t) != null


static func _sub(p: String, t: String, r: String) -> String:
	return RegEx.create_from_string(p).sub(t, r, true)


static func _note_rows(note: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)<pos=APs\\s+text=([\\s\\S]*?)\\s+size=").search_all(note):
		out.append(XHelpCard.plain(m.get_string(1)))
	return out


static func _unlock_text(t: String) -> bool:
	return _re("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]\\s*(?:[\\x{4e00}-\\x{9fff}]{0,4})?\\d+级?\\s*$", XHelpCard.plain(t))


static func resource_cost(t: String) -> bool:
	return _re("^(?:(?:基础)?(?:MP|TP)?)?消耗[：:]", t) and _re("(?:MP|TP|魔法)", t) and not _re("(?:行动|生命|残梦|朔望|唤醒)", t)


## currentHelpText 调原生 skillMpCost／skillTpCost：与实扣同一条链（XBattleLogic.skill_cost，含最大 MP 比例、减耗、下限、鬼族）
static func _cost(a, item: Dictionary, kind: String) -> int:
	return int(XBattleLogic.new().skill_cost(a, item)["mp" if kind == "MP" else "tp"])


## currentHelpText；返回 null 表示这一行不显示
static func current_text(text: String, item: Dictionary, a):
	var id := int(item.get("id", 0))
	var lv := _level(item, a)
	var rank := _rank(item, a)
	var mastery := float(a.skillMasteryLevel(id)) if a != null else 0.0
	for m in RegEx.create_from_string("角色等级[×*](\\d+(?:\\.\\d+)?)%").search_all(text):
		text = text.replace(m.get_string(), num(lv * float(m.get_string(1))) + "%")
	for m in RegEx.create_from_string("1[＋+]技能等级[×*](\\d+(?:\\.\\d+)?)%").search_all(text):
		text = text.replace(m.get_string(), num(1 + mastery * float(m.get_string(1)) / 100.0))
	if resource_cost(text) and a != null:
		var cost := []
		var mp := _cost(a, item, "MP")
		var tp := _cost(a, item, "TP")
		if mp != 0:
			cost.append(num(mp) + "MP")
		if tp != 0:
			cost.append(num(tp) + "TP")
		return "消耗：" + "／".join(cost) if not cost.is_empty() else null
	if not DYN2_GAPS.has(id) and id <= 10287:
		return text
	# 不在 DYN2 里的（奈叶 10168、琦玉 10169、镜流 10197～10199、甚尔 10227／10228、谷雨 10288 起）：只取当前阶位／等级的分支
	text = _tiers(text, rank)
	var gate := RegEx.create_from_string("^(?:([^：:]{1,8})[：:])?(\\d+)级起(.+)$").search(text)
	if gate != null:
		if lv < int(gate.get_string(2)):
			return null
		text = (gate.get_string(1) if gate.get_string(1) != "" else "效果") + "：" + gate.get_string(3)
	if _re("进阶后(?:由|替换为)|第[一二三四五六七八九十\\d]+次进阶后由|(?:\\d+级)?进阶后替换", text):
		return null
	text = _sub("×\\(1\\)$", text.replace("进阶后获得对应形态的", "获得当前形态的"), "")
	var range_m := RegEx.create_from_string("^(?:效果：)?([0-9]+)[～~]([0-9]+)阶(?:[：:]|(?=命中))").search(text)
	if range_m != null:
		if rank < int(range_m.get_string(1)) or rank > int(range_m.get_string(2)):
			return null
		text = text.replace(range_m.get_string(), "效果：")
	var step := RegEx.create_from_string("^(?:效果：)?([一二三四五六七八九]|\\d+)阶(?:起|时)[：:]?").search(text)
	if step != null:
		var n := int(step.get_string(1)) if step.get_string(1).is_valid_int() else "一二三四五六七八九".find(step.get_string(1)) + 1
		if rank < n:
			return null
		text = text.replace(step.get_string(), "效果：")
	var level_gate := RegEx.create_from_string("^(\\d+)级起[：:]").search(text)
	if level_gate != null:
		if lv < int(level_gate.get_string(1)):
			return null
		text = text.replace(level_gate.get_string(), "效果：")
	return text


## helpCurrentTiers：「（0～N阶）a／b／…」只取当前阶的值；「x%＋每阶y%」直接算出
static func _tiers(text: String, rank: int) -> String:
	var tier := RegEx.create_from_string("[（(](?:按[^（）()]*?)?0[～~](\\d)阶[）)]").search(text)
	if tier == null:
		tier = RegEx.create_from_string("[（(]?(?:按[^（）()，,]*?)?0[～~](\\d)阶(?:依次为)?[）)]?").search(text)
	if tier != null:
		var n := int(tier.get_string(1)) + 1
		var idx := clampi(rank, 0, n - 1)
		var list := RegEx.create_from_string("(×?)((?:[\\d.]+%?)(?:[／/][\\d.]+%?){%d})" % (n - 1)).search(text)
		if list != null:
			var vals := RegEx.create_from_string("[／/]").sub(list.get_string(2), "\n", true).split("\n")
			text = text.replace(list.get_string(), list.get_string(1) + vals[idx]).replace(tier.get_string(), "")
			text = _sub("：\\s*[，,]", _sub("[，,；;：:]\\s*$", text, ""), "：")
	for m in RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%[＋+]每阶(\\d+(?:\\.\\d+)?)%").search_all(text):
		text = text.replace(m.get_string(), num(float(m.get_string(1)) + float(m.get_string(2)) * rank) + "%")
	return _sub("×\\((\\d+(?:\\.\\d+)?%)\\)", text, "×$1")


static func _keep(text, skill: bool, list_costs: bool) -> bool:
	if text == null or str(text) == "" or _unlock_text(text) or _re("^(?:装备限制|冷却(?:时间)?)[：:]无$", text):
		return false
	if _re("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]", text):
		return false
	if _re("^条件[：:]", text) and _re("(?:\\d+级|进阶)", text):
		return false
	if _re("^(?:生效)?条件[：:]已(?:学会|习得)本被动$", text) or _re("^条件[：:]完成第?[一二三四五六七八九十\\d]+次?进阶$", text):
		return false
	if skill and resource_cost(text) and (list_costs or _re("^(?:基础)?消耗[：:]0MP[／/]0TP$", text)):
		return false
	return true


static func _styled(row: Array, text: String) -> Array:
	var s := row.duplicate()
	s[0] = text
	s[2] = VIEW_COLOR
	s[3] = false
	s[4] = 0
	return s


## characterHelpView（rows 为 getDescParams 加伤害属性包装后的行）
static func view(obj: Dictionary, rows: Array, list_costs := false) -> Array:
	var a = actor(obj)
	var id := int(obj.get("id", 0))
	var texts := _note_rows(str(obj.get("note", "")))
	var extra := {}
	for t in texts:
		extra[t] = true
	var copy = COPIES.get(id)
	var use_copy: bool = copy != null and texts == copy.source
	var header := []
	var info := []
	var effects := []
	var growth := []
	var formula := []
	var footer := []
	var authored := []
	var element_rows := []
	var seen := {}
	var has_cost := texts.any(func(t): return resource_cost(t))
	var actual_segments := texts.any(func(t): return _re("^实际段数[：:]", t))
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	for row in rows:
		var text := XHelpCard.plain(str(row[0]))
		if extra.has(text):
			authored.append(row)
			continue
		if str(row[0]) == desc:
			continue
		if str(row[0]) == name or _re("^品质[：:]", text):
			header.append(row)
			continue
		if _re("^(?:伤害属性|攻击属性|触发攻击属性)[：:]", text):
			var er: Array = row.duplicate()
			er[0] = "\\c[0]" + _sub("(?i)^(?:\\\\c\\[\\d+\\])+", str(row[0]), "")
			er[2] = VIEW_COLOR
			er[3] = false
			er[4] = 0
			element_rows.append(er)
			continue
		if _re("^(?:购买价格|出售价格|无法出售)", text):
			footer.append(row)
			continue
		if _re("^(?:MP消耗|TP消耗)[：:]", text):
			if list_costs or has_cost:
				continue
			text = _sub("^(MP|TP)消耗：", XHelpCard._compact(text), "基础$1消耗：")
		if _re("^(?:MP消耗|TP消耗|基础MP消耗|基础TP消耗|分类|咒具熟练)[：:]|^(?:当前咒具|切换至此咒具)", text) or _re("^(?:特效|效果)[：:]", text):
			var dyn: Array = row.duplicate()
			dyn[0] = text
			authored.append(dyn)
		elif text != "":
			header.append(row)
	if use_copy and not authored.is_empty():
		var native := authored.filter(func(r): return not extra.has(XHelpCard.plain(str(r[0]))))
		var marked := authored.filter(func(r): return extra.has(XHelpCard.plain(str(r[0]))))
		var proto: Array = marked[0] if not marked.is_empty() else authored[0]
		authored = []
		for t in copy.rows:
			var r := proto.duplicate()
			r[0] = t
			r[3] = false
			r[4] = 0
			authored.append(r)
		authored.append_array(native)
	var joined := []
	var lead := "^(?:伤害|每段(?:基础)?|基础伤害|基式)[：:=＝]"
	for row in authored:
		var raw := XHelpCard.plain(str(row[0]))
		var text = XHelpCard._compact(raw)
		if actual_segments and _re("^攻击次数[：:]", raw):
			continue
		if _re("^实际段数[：:]", raw) and texts.any(func(t): return _re("^攻击次数[：:]", t) and t.contains("追加伤害另计")):
			text += "（追加伤害另计）"
		text = current_text(text, obj, a)
		if not _keep(text, true, list_costs):
			continue
		if _re("^消耗[：:]\\s*(?:自己)?[一二三四五六七八九十\\d]+次?", text) and text.contains("行动"):
			text = _sub("^消耗[：:]", text, "代价：")
		var last = joined.back() if not joined.is_empty() else null
		if last != null and _re("^[＋+×－−-]", text) and _re(lead, str(last[0])):
			last[0] = str(last[0]) + text
			continue
		if last != null and _re("^[＋+×－−-]", str(last[0])) and _re(lead, text):
			text += str(last[0])
			joined.pop_back()
		var next: Array = row.duplicate()
		next[0] = text
		next[3] = false
		next[4] = 0
		joined.append(next)
	for row in joined:
		var text := str(row[0])
		if seen.has(text):
			continue
		seen[text] = true
		if _re("^专属[：:]", text):
			header.append(_styled_keep(row, "\\c[2]" + text))
		elif XHelpCard._is_info(text):
			info.append(_styled_keep(row, "\\c[0]" + _sub("([\\x{4e00}-\\x{9fff}])[:]", text, "$1：")))
		elif XHelpCard._is_formula(text):
			formula.append(_styled_keep(row, "\\c[5]" + text))
		elif XHelpCard._is_growth(text):
			if not _re("^(?:成长|每级|法宝每级|星魂预览|升级)", text):
				text = "成长：" + text
			growth.append(_styled_keep(row, "\\c[3]" + text))
		else:
			effects.append(_styled_keep(row, "\\c[1]" + text))
	if a != null and int(a.actor_id) == 167 and id == 10137:
		var gtxt := "成长：冥河成长倍率×" + num(XRaven.growth_rate(a))
		if not seen.has(gtxt):
			seen[gtxt] = true
			var base: Array = (growth + effects + info + header)[0]
			growth.append(_styled(base, "\\c[3]" + gtxt))
	var size_row = info[0] if not info.is_empty() else (formula[0] if not formula.is_empty() else (effects[0] if not effects.is_empty() else null))
	if size_row != null:
		for r in element_rows:
			r[1] = size_row[1]
	info = element_rows + info
	var priority := ["目标", "伤害类型", "伤害属性", "命中", "暴击", "段数", "冷却", "准备时间"]
	var basic := []
	var other := []
	for row in info:
		var rank := priority.find(XHelpCard.plain(str(row[0])).split("：")[0])
		if rank < 0:
			other.append(row)
		else:
			basic.append([rank, basic.size(), row])
	basic.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	info = basic.map(func(x): return x[2]) + other
	var compact := []
	for row in info:
		var last = compact.back() if not compact.is_empty() else null
		var left := XHelpCard.plain(str(last[0])) if last != null else ""
		var right := XHelpCard.plain(str(row[0]))
		var pair := last != null and ((_re("^目标[：:]", left) and _re("^伤害(?:属性|类型)[：:]", right)) or
			(_re("^命中[：:]", left) and _re("^暴击[：:]", right)) or (_re("^(?:暴击|段数)[：:]", left) and _re("^(?:段数|冷却)[：:]", right)))
		if pair and left.length() + right.length() <= 28 and last[1] == row[1]:
			last[0] = str(last[0]) + "；" + _sub("^\\\\c\\[0\\]", str(row[0]), "")
		else:
			compact.append(row.duplicate())
	var groups := [header, formula, compact, effects, growth, footer].filter(func(g): return not g.is_empty())
	for i in range(groups.size() - 1):
		var g: Array = groups[i]
		var tail: Array = g.back().duplicate()
		tail[3] = true
		g[g.size() - 1] = tail
	var out := []
	for g in groups:
		out.append_array(g)
	return _now_growth_view(obj, _dyn2_view(obj, out, a), a)


## nowGrowthView 包在 characterHelpView 最外层，也管走 genericHelpView 的技能（屠苏、璇的技能号在 10299 之后）
static func now_growth(obj: Dictionary, rows: Array) -> Array:
	return _now_growth_view(obj, rows, actor(obj))


## nowGrowthRows（谷雨部分；屠苏、璇在 _tusu_xuan_growth_rows）：按技能所属角色当前等级／阶位算的「成长：」行；null＝不换
static func _now_growth_rows(obj: Dictionary, a) -> Variant:
	var note := str(obj.get("note", ""))
	if note.contains("<CodexTusu:") or note.contains("<CodexXuan:"):
		return _tusu_xuan_growth_rows(obj, a)
	if owner(obj) != XGuyu.ACTOR or not note.contains("<GuyuSkill:"):
		return null
	var lv := _level(obj, a)
	var rank := clampi(_rank(obj, a), 0, 5)
	var c := func(v: Array, l := [1, 20, 40, 60]) -> float: return XGuyu.curve(lv, v, l)
	var pct := func(n: float) -> String: return num(roundf(n * 1000.0) / 10.0) + "%"
	var x := func(n: float) -> String: return num(roundf(n * 100.0) / 100.0)
	match int(obj.get("id", 0)):
		10290:
			return ["成长：转移比例可选25%／50%／75%" if lv >= 10 else "成长：转移比例50%"]
		10298:
			return ["成长：待绽比例" + ("50%" if lv >= 60 else "35%") + "；花荫倍率×" + ("1.2" if lv >= 60 else "1.1" if lv >= 20 else "1")]
		10288:
			return ["成长：治疗比例" + pct.call(c.call([0.25, 0.30, 0.35, 0.40]))]
		10293:
			return ["成长：队友储备比例" + pct.call(c.call([1, 1.25, 1.5, 1.75]) + 0.15 * rank), "成长：绽放系数" + x.call(c.call([5, 6, 7, 8]))]
		10292:
			return ["成长：归春系数" + x.call(c.call([33, 50], [40, 60]))]
	return null


## nowGrowthRows 的屠苏 176、璇 177 部分（【cc·悟空·未经审查】events3）：按所属角色等级（B.curve），没有该角色时按初始等级、没学技能
const TUSU_GROWTH := {10312: "zhanfeng", 10313: "hengsao", 10314: "dianshe", 10315: "guanri", 10317: "chiling", 10318: "zhenji", 10319: "jianqi", 10323: "zhenhun", 10324: "body_phys", 10325: "body_mag"}


static func _tusu_xuan_growth_rows(obj: Dictionary, a) -> Variant:
	var lv := _level(obj, a)
	var c := func(v: Array, l: Array) -> float: return XGuyu.curve(lv, v, l)
	var pct := func(n: float) -> String: return num(roundf(n * 1000.0) / 10.0) + "%"
	var x := func(n: float) -> String: return num(roundf(n * 100.0) / 100.0)
	var coef := func(actor_id: int, k: String) -> String: return str(floori(XGuyu.curve(lv, XTusuXuan.DAMAGE[actor_id].get(k, [0, 0, 0, 0]), XTusuXuan.LEVELS)))
	var w: float = c.call([0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 1], [1, 10, 20, 30, 40, 50, 60])
	var id := int(obj.get("id", 0))
	if TUSU_GROWTH.has(id):
		return ["成长：伤害系数" + coef.call(XTusuXuan.TUSU, TUSU_GROWTH[id])]
	var lock: String = "锁定倍率×" + x.call(c.call([1.3, 1.5], [20, 60]))
	var heming: String = "和鸣倍率×" + x.call(c.call([1.2, 1.5], [20, 60]))
	var huzhen: String = "护阵倍率×" + x.call(c.call([0.85, 0.70], [20, 60]))
	var hg: String = "回光系数" + x.call(c.call([10, 20], [1, 60]))
	var hgf: String = pct.call(c.call([0.20, 0.35], [1, 60]))
	var lbf: String = pct.call(c.call([0.15, 0.35], [1, 60]))
	# X.gongsuDefenseRate／gongsuDamageRate：学会共宿且 10 级解锁才有
	var gongsu := _learned(a, XTusuXuan.skill_id(XTusuXuan.XUAN, "gongsu")) and XTusuXuan.unlocked(XTusuXuan.XUAN, a, "gongsu")
	var gs: String = "双防共享比例" + pct.call(c.call([0.15, 0.30], [20, 60]) if gongsu else 0.0)
	var offense: String = "直接伤害提高" + pct.call(c.call([0.10, 0.30], [10, 60]) if gongsu else 0.0)
	var shadow := "成长：星影人数" + ("全部队友" if lv >= 60 else "3名" if lv >= 50 else "2名" if lv >= 40 else "1名" if lv >= 30 else "0名")
	var m := RegEx.create_from_string("<Codex(?:Tusu|Xuan):\\s*(passive\\.(?:temper|relay))\\s*>").search(str(obj.get("note", "")))
	var passive := m.get_string(1) if m != null else ""
	if passive == "passive.temper":  # T.temperRate：TEMPER 等级起 ×1.1，60 级 ×1.2（剑气纵横保持 ×1.1）
		var tr := func(at: int, keep := false) -> String: return "×" + x.call(1.0 if lv < at else 1.1 if lv < 60 or keep else 1.2)
		return ["成长：剑气纵横伤害" + tr.call(10, true), "成长：横扫、点射、贯日伤害" + tr.call(20), "成长：金汤护盾量、敕令伤害" + tr.call(30), "成长：震击、镇魂重击伤害" + tr.call(40)]
	if passive == "passive.relay":
		return ["成长：接力比例" + pct.call(0.3 if lv >= 60 else 0.2 if lv >= 20 else 0.0)]
	match id:
		10316:
			return ["成长：" + huzhen]
		10320:
			return ["成长：" + lock]
		10321:
			return ["成长：成长权重" + pct.call(w) + "；保底比例" + pct.call(c.call([0.1, 0.3], [1, 60]))]
		10322:
			return ["成长：" + heming]
		10358:
			return ["成长：成长权重" + pct.call(w)]
		10359:
			return ["成长：" + lock + "；" + heming, "成长：" + huzhen, "成长：挫势－" + pct.call(1.0 - c.call([0.90, 0.80], [20, 60])) + "（霸体目标－" + pct.call(1.0 - c.call([0.85, 0.70], [20, 60])) + "）",
				"成长：横扫对后续目标增伤" + pct.call(c.call([1, 1.2], [20, 60]) - 1.0)]
		10360:
			return ["成长：额外提高" + pct.call(c.call([1, 1.2], [40, 60]) - 1.0 if lv >= 40 else 0.0)]
		10335:
			return ["成长：" + hg + "；保底比例" + hgf]
		10336:
			return ["成长：成长权重" + pct.call(w) + "；保底比例" + lbf]
		10337:
			return ["成长：伤害系数" + coef.call(XTusuXuan.XUAN, "lengguang")]
		10338, 10363:
			return [shadow]
		10339:
			return ["成长：" + gs, "成长：" + offense]
		10361:
			return ["成长：" + hg + "；回光保底比例" + hgf, "成长：璃壁成长权重" + pct.call(w) + "；璃壁保底比例" + lbf]
		10362:
			return ["成长：" + gs.replace("双防共享比例", "共宿比例") + "；额外默契" + str(floori(c.call([1, 3], [20, 60])) if lv >= 20 else 0) + "点"]
	return null


## nowGrowthView：把所有「成长：」行换成 nowGrowthRows（放在第一条成长行处，末行沿用原最后一条成长行的分隔）
static func _now_growth_view(obj: Dictionary, rows: Array, a) -> Array:
	var now = _now_growth_rows(obj, a)
	if now == null:
		return rows
	var old := range(rows.size()).filter(func(i): return _re("^成长[：:]", XHelpCard.plain(str(rows[i][0]))))
	if old.is_empty():
		return rows
	var line = rows[old.back()][3]
	var out := []
	for i in rows.size():
		var r: Array = rows[i]
		if i != old[0]:
			if not old.has(i):
				out.append(r)
			continue
		for k in now.size():
			var v: Array = r.duplicate()
			v[0] = "\\c[3]" + now[k]
			v[3] = line if k == now.size() - 1 else false
			out.append(v)
	return out


## styled：只换文字与颜色，保留行的字号（分隔、对齐在作者行阶段已清掉）
static func _styled_keep(row: Array, text: String) -> Array:
	var s := row.duplicate()
	s[0] = text
	s[2] = VIEW_COLOR
	return s


## dyn2：前缀 → 当前数值的整行
static func _dyn2(obj: Dictionary, a) -> Dictionary:
	var id := int(obj.get("id", 0))
	var who := owner(obj)
	var lv := _level(obj, a)
	var rank := _rank(obj, a)
	var out := {}
	var n2 := func(v: float) -> String: return num(roundf(v * 100.0) / 100.0)
	var pc := func(v: float) -> String: return num(roundf(v * 10.0) / 10.0) + "%"
	if who == 167:
		var st := XRaven.stage(a)
		var soul := XRaven.soul(a)
		var p := XRaven.progress(a) if a != null else 0.0
		if id >= 10122 and id <= 10126:
			out["成长：魄倍率"] = "成长：魄倍率" + n2.call(XRaven.legion_rate(a)) + "；阶位系数" + n2.call(XRaven.skill_coefficient(a, id))
		if id == 10128 or id == 10135:
			out["成长：下一阶门槛"] = "成长：下一阶门槛" + str(XRaven.REQUIRE[st + 1]) + "灵魂（已有" + str(floori(soul)) + "）" if st < 5 else "成长：已完成五阶"
		if id == 10130:
			out["成长：魔防穿透率"] = "成长：魔防穿透率" + pc.call((1 - XRaven.defense_factor(a)) * 100)
		if id == 10131:
			var has := XRaven.has(a, id)
			out["成长：专属黑暗"] = "成长：专属黑暗魔法伤害＋" + pc.call(200 + p * 100 if has else 0.0) + "；专属魔法最终伤害×" + n2.call(1 + 1.5 * minf(1, (st + p) / 5.0) if has else 1.0)
		if id == 10137:
			var pools := XRaven.growth_pools(a) if _learned(a, id) else [0.0, 0.0]
			out["成长：爆伤"] = "成长：爆伤＋" + pc.call(pools[0]) + "；终伤＋" + pc.call(pools[1])
			out["成长：专属魔法暴击率"] = "成长：专属魔法暴击率＋" + pc.call(p * 1000 if _learned(a, id) else 0.0)
			out["成长：冥河成长倍率"] = "成长：冥河成长倍率×" + n2.call(XRaven.growth_rate(a))
		if id == 10138:
			out["成长：魄倍率"] = "成长：魄倍率" + n2.call(XRaven.legion_rate(a))
		if id == 10139:
			out["成长：冠冕倍率"] = "成长：冠冕倍率×" + n2.call(XRaven.crown_rate(a))
	if who == 168:
		var dragon := XMira.dragon(a)
		if id == 10144:
			out["成长：人形物防"] = "成长：人形物防、魔防×" + n2.call(1.25 * (1 + 0.25 * minf(1, (lv - 30) / 5.0)) if not dragon and lv >= 30 and _learned(a, id) else 1.0)
		if id == 10145:
			out["成长：人形速度"] = "成长：人形速度×" + n2.call(1.1 * (1 + 0.25 * minf(1, (lv - 40) / 5.0)) if not dragon and lv >= 40 and _learned(a, id) else 1.0)
		if id == 10156:
			var on := _learned(a, id)
			var dmg := 2.0 if lv >= 60 else (1.8 + 0.02 * (lv - 50) if lv >= 50 else (1.66 + 0.14 * (lv - 15) / 35.0 if lv >= 15 else 1.15 + 0.051 * maxi(0, lv - 5)))
			var cr := 0.0 if lv < 5 else (0.15 + 0.08 * (lv - 5) if lv <= 15 else 0.95 + 7.93 * minf(1, (lv - 15) / 55.0))
			out["成长：共鸣倍率"] = "成长：共鸣倍率×" + n2.call(dmg if on and not dragon and lv >= 5 else 1.0) + "；暴击率＋" + pc.call(cr * 100 if on else 0.0)
	if who == 169 and id >= 10171 and id <= 10174:
		var seg := XYomiJingliu.repeats(a, id)
		out["段数："] = "段数：" + str(seg) + "（幸运每6666点＋1段，最多＋6）"
	if who == 171:
		if id == 10205:
			out["成长：最大生命"] = "成长：最大生命＋" + pc.call(lv * 10) + "；物攻、速度＋" + pc.call(lv * 5)
			out["成长：暴击率"] = "成长：暴击率＋" + pc.call(lv * 10) + "；爆伤、终伤＋" + pc.call(lv * 40)
		if id == 10205 or id == 10211 or (id >= 10216 and id <= 10223):
			out["成长：咒具成长系数"] = "成长：咒具成长系数×" + num(roundf(XToji.output_growth_at(lv, id == 10205 or (id >= 10216 and id <= 10219)) * 1000.0) / 1000.0)
	if who == 172:
		if [10239, 10247, 10248, 10249].has(id):
			out["成长：术式威力"] = "成长：术式威力" + num(XSukuna.coefficient(a) if a != null else 88888.0)
		if id == 10242:
			out["成长：斩击强化"] = "成长：斩击强化：未储存"  # 斩击强化层数是第二期的战斗内字段
	if who == 173:
		var f := XGarou.form(a)
		var ps: Dictionary = f.passives
		if id >= 10250 and id <= 10263:
			out["成长：形态系数"] = "成长：形态系数" + str(f.scale)
		if id == 10266:
			out["成长：每层进化"] = "成长：每层进化伤害＋" + str(ps.evolution_base_per_stack_percent if ps.evolution_enabled else 0) + "%"
		if id == 10267:
			var mag: int = ps.analysis_magic_defense_ignore_percent_per_stack
			out["成长：每层无视"] = "成长：每层无视物防" + str(ps.analysis_defense_ignore_percent_per_stack) + "%" + ("、魔防" + str(mag) + "%（最多99%）" if mag else "")
		if id == 10269:
			out["成长：当前形态"] = "成长：当前形态：" + str(f.name) + ("；每回合行动" + str(f.actions) + "次" if int(f.actions) > 1 else "")
	return out


## dyn2View：整行以「成长…」前缀开头的整行换；否则按「；」分段，只换以前缀开头的那一段
static func _dyn2_view(obj: Dictionary, rows: Array, a) -> Array:
	var id := int(obj.get("id", 0))
	if DYN2_GAPS.has(id) or id > 10287:
		return rows
	var map := _dyn2(obj, a)
	if map.is_empty():
		return rows
	var out := []
	for r in rows:
		var raw := str(r[0])
		var p := XHelpCard.plain(raw)
		var color_m := RegEx.create_from_string("(?i)^(?:\\\\c\\[\\d+\\])+").search(raw)
		var color := color_m.get_string() if color_m != null else ""
		var whole := ""
		for k in map:
			if k.begins_with("成长") and p.begins_with(k):
				whole = k
				break
		if whole != "":
			var w: Array = r.duplicate()
			w[0] = color + map[whole]
			out.append(w)
			continue
		var done := false
		var parts := []
		for part in p.split("；"):
			var hit := ""
			for k in map:
				if hit == "" and part.begins_with(k):
					hit = k
			if hit == "":
				parts.append(part)
			else:
				done = true
				parts.append(map[hit])
		if not done:
			out.append(r)
			continue
		var row: Array = r.duplicate()
		row[0] = color + "；".join(parts)
		out.append(row)
	return out
