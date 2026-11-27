class_name XTianqiOrbs
extends RefCounted
## 【cc·T518·天启篇·未经审查】宝珠新表（T013 第二期 2G；养成线稿 v0.3 第三节第 1 条，D141 丙照稿不让）。只认天启篇存档（XTianqi.active），西游档原样。
## - 读时换表、存档不改写：镶嵌／取下照旧按物品原备注写进装备实例（XOrbs.apply：特性带「族:阶」标记 _codexOrb、元素增幅加进 yep），
##   天启篇读装备时（XTianqiGear.stat_list → views）按「族:阶」换数：标记特性换成新表的值，元素增幅减去这几颗原备注那份、加上新表那份。
##   老档镶着的宝珠不动，效果按新表读；关掉开关就回原表（存档里本来就是原表的数）。
## - 新表（五阶一排，整数）：元素族（锋刃物理、八个元素、水、风、春泽治疗）本系伤害 ELEM＝3/5/6/8/10%；
##   其余百分比行（属性族每行、元素族附带的那点攻防）ATTR＝1/2/3/5/6%。同族一个人只算阶最高的 3 颗（familyCap），元素增幅也算进这条上限
##   （原表只限特性，稿：「同族最多算 3 颗，所以一个人本系最多 +30%」）。
## - 补水、风两族（第 16、17 族，镶武器孔、不进任何共鸣套）：表外物品号段 3301～3310（水 3301～3305、风 3306～3310，各五阶），
##   按寒霜／雷霆同阶那颗复制，备注照新表写；只在天启篇存档里读得到（XDB.rec 挂点），神秘珠鉴定 18 族等概率。
## - 原作 91 颗旧宝珠天启篇不再掉：鉴定不出（legacyShare 0）、怪物掉落行去掉（535 那一行）、地图事件给的（13～30 层守层者首胜、Map132）
##   换成同值的宝珠残片（＝宝珠坊分解它能拿到的残片数 × 颗数），提示里的宝珠名同步换。已经在背包里、镶在装备上的照旧能用、能分解。
## - 显示：宝珠物品说明（备注 <pos> 行、description 第二行）、宝珠坊说明、插槽页（gear_detail.socket_rows）每颗新宝珠下一行新表效果。
##   光耀度（T164）只管固定加值；新宝珠全是百分比行，没有固定加值，光耀行照旧不出——插槽页由本模块补上新表效果行。
## 回退开关 TABLE：false 整个回原表（含水风两族读不到、旧宝珠照旧掉）。专项 xiyou_tianqi_orbs 设过回退值。

static var TABLE := true

const ELEM := [3, 5, 6, 8, 10]   # 元素族本系伤害（养成线稿 第三节第 1 条「数值」）
const ATTR := [1, 2, 3, 5, 6]    # 属性族每颗每行；元素族附带的攻防也按这排（稿：宝珠的副属性「很小」）
## 特性 22 的行（每回合回复 HRG/MRG、闪避 EVA/MEV、暴击 CRI、命中 HIT）另排小表 1/3/6/10/15%（Kyo 11-26 事项81，
## 预算稿 v0.16 第 83、169 行已回写；原九.6 五阶 3% 已被改）。同属性 3 颗封顶 45%；长生三颗五阶 45% 入九.7甲 回复额度
const SMALL := [1, 3, 6, 10, 15]
## 回退开关（专项设过回退值）：SMALL_ON false＝特性 22 行回到属性排；ATTR_CAP false＝不限同属性跨族 3 颗（只限同族）；
## CAT_SWORD_X2 false＝小猫持剑不翻宝珠（Kyo 11-26 事项81：照原版翻倍、翻倍后封顶照算）
static var SMALL_ON := true
static var ATTR_CAP := true
static var CAT_SWORD_X2 := true
const NEW_FIRST := 3301
const NEW_LAST := 3310
## 新两族：template＝复制物品记录用的同阶族（寒霜 2、雷霆 4）
const NEW_FAMILIES := [
	{"key": "water", "name": "沧澜", "role": "水系输出", "slot": "武器宝珠", "sets": [], "template": 2, "first": 3301,
		"lines": [["Element Amplify 14", 3, "水系伤害"], ["MAT", 1, "魔法攻击"], ["MDF", 1, "魔法防御"]]},
	{"key": "wind", "name": "啸风", "role": "风系输出", "slot": "武器宝珠", "sets": [], "template": 4, "first": 3306,
		"lines": [["Element Amplify 15", 3, "风系伤害"], ["MAT", 1, "魔法攻击"], ["AGI", 1, "敏捷"]]},
]
const FRAGMENT_TOAST_RE := "窃取了[一二三四五六七八九十\\d]+个宝珠：[^！!']*[！!]"
const FRAGMENT_TOAST := "获得了%d枚宝珠残片！"
const CAP_TEXT_OLD := "同一件装备同类最多1颗，全身同类只算最高3颗"
const CAP_TEXT := "同一件装备同类最多1颗，全身同类、同项属性各只算最高3颗"

static var _cfg := {}
static var _item_views := {}
static var _new_items := {}


static func on(s = null) -> bool:
	if not TABLE:
		return false
	var st = s if s != null else XState.current
	return st is XState and XTianqi.active(st)


static func clear_cache() -> void:
	_cfg = {}
	_item_views = {}
	_new_items = {}


# ---- 配置（XOrbs.config 的天启篇版）----
## 原表加水风两族、物品效果换新表、鉴定不出旧宝珠
static func config(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return raw
	if not _cfg.is_empty() and is_same(_cfg.get("_src"), raw):
		return _cfg.cfg
	var c: Dictionary = raw.duplicate(true)
	for f in NEW_FAMILIES:
		var ids := []
		for r in 5:
			ids.append(int(f.first) + r)
		c.families.append({"key": f.key, "name": f.name, "role": f.role, "lines": (f.lines as Array).duplicate(true),
			"ids": ids, "sets": [], "slot": f.slot})
	for fi in c.families.size():
		var fam: Dictionary = c.families[fi]
		for r in 5:
			var id := int(fam.ids[r])
			c.items[str(id)] = {"family": fi, "rank": r + 1, "effects": effects(fam, r + 1)}
	c["legacyShare"] = 0
	_cfg = {"_src": raw, "cfg": c}
	return c


## 一行在新表里的百分数
static func line_value(line: String, rank: int) -> int:
	var r := clampi(rank, 1, 5) - 1
	var u := line.to_upper().strip_edges()
	if u.begins_with("ELEMENT AMPLIFY"):
		return int(ELEM[r])
	if SMALL_ON and XOrbs.XPARAMS.has(u):
		return int(SMALL[r])
	return int(ATTR[r])


## 某族某阶的效果文字（同原表 items.effects 的写法「物理伤害+3%」）
static func effects(fam: Dictionary, rank: int) -> Array:
	return (fam.get("lines", []) as Array).map(func(l): return "%s+%d%%" % [str(l[2]), line_value(str(l[0]), rank)])


static func is_new_family(family: int) -> bool:
	return family >= 16


# ---- 读时换表（装备视图）----
## 孔里的新宝珠 [{slot, family, rank, id}]（只认 "item N" 且 CodexOrbs 里有的；不编译正则，战斗里每次行动调几千次）
static func _orbs_of(eq: Dictionary, cfg: Dictionary) -> Array:
	var out := []
	var held = eq.get("augmentSlotItems")
	if not held is Array:
		return out
	var items: Dictionary = cfg.get("items", {})
	for i in (held as Array).size():
		var h := str(held[i])
		if not h.begins_with("item "):
			continue
		var sp = items.get(h.substr(5).strip_edges())
		if sp is Dictionary:
			out.append({"slot": i, "family": int(sp.family), "rank": int(sp.rank), "id": int(h.substr(5))})
	return out


## stat_list 末尾：天启篇存档里带新宝珠的装备换成新表视图，其余原样（同一对象）
static func views(list: Array) -> Array:
	if not on():
		return list
	var cfg := XOrbs.config()
	if cfg.is_empty():
		return list
	var found := []
	var any := false
	for e in list:
		var o: Array = _orbs_of(e, cfg) if e is Dictionary and not (e as Dictionary).is_empty() and not (e as Dictionary).has("_tq_orb_amp") else []
		found.append(o)
		any = any or not o.is_empty()
	if not any:
		return list
	var mults := list.map(func(e): return sword_mult(e))
	var alloc := _alloc(found, mults, int(cfg.get("familyCap", 0)), cfg)
	var out := []
	for i in list.size():
		out.append(list[i] if (found[i] as Array).is_empty() else view(list[i], found[i], alloc.get(i, {}), int(mults[i])))
	return out


## 单件装备的说明卡、战力（XHelpCard）：只看这一件的新表数（一件上同族只能一颗，族上限不涉及）；已是视图的原样
static func card_view(obj):
	if not obj is Dictionary or (obj as Dictionary).is_empty() or not on():
		return obj
	return views([obj])[0]


## 小猫（178）持剑翻倍视图（XCat.sword_view 打的 _xcat_sword 标记）的倍数；不是剑视图为 1
static func sword_mult(e) -> int:
	return int(e.get("_xcat_sword", 1)) if e is Dictionary else 1


## 一行的统一键：元素增幅「A<元素号>」、能力值「P<号>」、特性 22「X<号>」（宝珠行写法与装备特性两头都能认）
static func line_key(line: String) -> String:
	var u := line.to_upper().strip_edges()
	if u.begins_with("ELEMENT AMPLIFY "):
		return "A%d" % int(u.substr(16))
	var xi := XOrbs.XPARAMS.find(u)
	if xi >= 0:
		return "X%d" % xi
	for pi in XOrbs.PARAM_NAMES.size():
		if (XOrbs.PARAM_NAMES[pi] as Array).has(u):
			return "P%d" % pi
	return u


static func trait_key(t: Dictionary) -> String:
	match int(t.get("code", 0)):
		21: return "P%d" % int(t.get("dataId", -1))
		22: return "X%d" % int(t.get("dataId", -1))
	return ""


## 算数的那几颗、每行给多少 {装备下标: {族: {行键: 百分数}}}：
## ① 同族全身只留阶最高的 familyCap 颗（阶同装备靠前优先，同 XOrbs.cap_drops）；
## ② 同一项属性（行键）跨族全身只算阶最高的 familyCap 颗（预算稿 v0.16 九.6，D290；ATTR_CAP 开关）；
## ③ 小猫持剑翻倍之后，一项属性的宝珠合计不超过 familyCap × 五阶值（本系 30%、属性 18%、小表 45%），超的从翻倍那份扣（Kyo 11-26 事项81：翻倍不能绕封顶）。
## 超上限的在视图里直接不给（不再靠下游 filter_traits 按身份剔，视图深拷贝过就认不出——核查 P1-2）。
static func _alloc(found: Array, mults: Array, cap: int, cfg: Dictionary) -> Dictionary:
	var by_fam := {}
	for i in found.size():
		var best := {}
		for o in found[i]:
			best[o.family] = maxi(int(best.get(o.family, 0)), int(o.rank))
		for f in best:
			if not by_fam.has(f):
				by_fam[f] = []
			by_fam[f].append({"i": i, "f": int(f), "rank": int(best[f])})
	var by_line := {}
	for f in by_fam:
		var rows: Array = by_fam[f]
		rows.sort_custom(_rank_first)
		if cap > 0:
			rows = rows.slice(0, cap)
		for x in rows:
			for l in cfg.families[int(f)].lines:
				var k := line_key(str(l[0]))
				if not by_line.has(k):
					by_line[k] = []
				by_line[k].append({"i": x.i, "f": x.f, "rank": x.rank, "line": str(l[0])})
	var alloc := {}
	for k in by_line:
		var rows: Array = by_line[k]
		rows.sort_custom(_rank_first)
		if cap > 0 and ATTR_CAP:
			rows = rows.slice(0, cap)
		var total := 0
		for x in rows:
			x["pct"] = line_value(str(x.line), int(x.rank)) * (int(mults[x.i]) if CAT_SWORD_X2 else 1)
			total += int(x.pct)
		var limit := line_value(str(rows[0].line), 5) * cap if cap > 0 else total
		for x in rows:
			if total <= limit:
				break
			if int(mults[x.i]) > 1:
				var cut := mini(total - limit, int(x.pct))
				x.pct = int(x.pct) - cut
				total -= cut
		for x in rows:
			if not alloc.has(x.i):
				alloc[x.i] = {}
			if not alloc[x.i].has(x.f):
				alloc[x.i][x.f] = {}
			alloc[x.i][x.f][k] = int(x.pct)
	return alloc


static func _rank_first(x: Dictionary, y: Dictionary) -> bool:
	if int(x.rank) != int(y.rank):
		return int(x.rank) > int(y.rank)
	if int(x.i) != int(y.i):
		return int(x.i) < int(y.i)
	return int(x.f) < int(y.f)


## 一件装备的新表视图：浅拷贝，宝珠特性按 alloc 换新表值（不在 alloc 里的直接不给），yep 深拷贝后改元素增幅：
## 减去孔里所有新宝珠原备注那份（剑视图已乘 mult，按 mult 倍扣），加上 alloc 给的。_tq_orb_amp 记新表算进来的元素增幅（伤害加成总账 orb 桶读它）
static func view(eq: Dictionary, orbs: Array, alloc: Dictionary, mult: int = 1) -> Dictionary:
	var v: Dictionary = eq.duplicate(false)
	var traits := []
	for t in eq.get("traits", []):
		if t is Dictionary and t.has("_codexOrb"):
			var f := int(str(t._codexOrb).get_slice(":", 0))
			var got = (alloc.get(f, {}) as Dictionary).get(trait_key(t))
			if got == null:
				continue
			var nt: Dictionary = t.duplicate()
			var pct := float(got) / 100.0
			nt["value"] = pct if int(t.get("code", 0)) == 22 else 1.0 + pct
			traits.append(nt)
			continue
		traits.append(t)
	v["traits"] = traits
	var amp_old := {}
	var amp_new := {}
	var slots: Array = eq.get("augmentSlots", []) if eq.get("augmentSlots") is Array else []
	for o in orbs:
		var gem := XDB.rec("Items", int(o.id))
		var type := str(slots[o.slot] if o.slot < slots.size() else "").to_upper().strip_edges()
		for line in XOrbs.parse(gem).attach.get(type, []):
			var m := _amp_re().search(str(line))
			if m:
				amp_old[m.get_string(1)] = float(amp_old.get(m.get_string(1), 0.0)) + float(m.get_string(2)) / 100.0 * mult
	for f in alloc:
		for k in alloc[f]:
			if str(k).begins_with("A"):
				var ek := str(k).substr(1)
				amp_new[ek] = float(amp_new.get(ek, 0.0)) + float(alloc[f][k]) / 100.0
	if not amp_old.is_empty() or not amp_new.is_empty():
		var yep: Dictionary = (eq.get("yep", {}) as Dictionary).duplicate(true) if eq.get("yep") is Dictionary else {}
		var amp: Dictionary = yep.get("elementAmplify", {}) if yep.get("elementAmplify") is Dictionary else {}
		for k in amp_old:
			amp[k] = float(amp.get(k, 0.0)) - float(amp_old[k])
		for k in amp_new:
			amp[k] = float(amp.get(k, 0.0)) + float(amp_new[k])
		for k in amp.keys():
			if absf(float(amp[k])) < 1e-9:
				amp.erase(k)
		yep["elementAmplify"] = amp
		v["yep"] = yep
	v["_tq_orb_amp"] = amp_new
	return v


static var _amp_re_c: RegEx
static func _amp_re() -> RegEx:
	if _amp_re_c == null:
		_amp_re_c = RegEx.create_from_string("(?i)ELEMENT AMPLIFY[ ](\\d+):[ ]([\\+\\-]\\d+)[%％]")
	return _amp_re_c


# ---- 表外物品（水、风两族 3301～3310）----
static func has_new(name: String, id: int) -> bool:
	return name == "Items" and id >= NEW_FIRST and id <= NEW_LAST and on()


static func new_rec(id: int, t: Array) -> Dictionary:
	if not has_new("Items", id):
		return {}
	if _new_items.has(id):
		return _new_items[id]
	var k := id - NEW_FIRST
	var f: Dictionary = NEW_FAMILIES[k / 5]
	var rank := k % 5 + 1
	var raw: Dictionary = XDB.table("CodexOrbs") if XDB.table("CodexOrbs") is Dictionary else {}
	if raw.is_empty():
		return {}
	var tpl_id := int(raw.families[int(f.template)].ids[rank - 1])
	if tpl_id >= t.size() or not t[tpl_id] is Dictionary:
		return {}
	var tier := str(raw.tiers[rank - 1])
	var out: Dictionary = (t[tpl_id] as Dictionary).duplicate(true)
	out["id"] = id
	out["name"] = "宝珠·%s·%s" % [f.name, tier]
	var fx := effects(f, rank)
	var aug := ["<Augment: %s>" % f.slot]
	for l in f.lines:
		aug.append("%s: +%d%%" % [str(l[0]), line_value(str(l[0]), rank)])
	aug.append("</Augment: %s>" % f.slot)
	var q := 4 + rank
	var note := aug + ["<quality:%d>" % q, "<ici:%d>" % q, "<CodexOrb: %s:%d>" % [f.key, rank],
		_pos("镶嵌部位：%s孔" % f.slot), _pos(CAP_TEXT if ATTR_CAP else CAP_TEXT_OLD)]
	for x in fx:
		note.append(_pos(str(x)))
	out["note"] = "\n".join(note)
	out["meta"] = XTianqiSkills.parse_meta(out.note)
	out["description"] = "%s｜%s（镶武器孔）\n%s" % [f.role, tier, "；".join(fx)]
	_new_items[id] = out
	return out


static func _pos(text: String) -> String:
	return "<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % text


# ---- 原表宝珠物品的说明换新表（只改显示用的 <pos> 行与 description，<Augment> 镶嵌行不动）----
static func touches_item(id: int) -> bool:
	return id >= 2947 and id < NEW_FIRST and on() and (XDB.table("CodexOrbs") as Dictionary).get("items", {}).has(str(id))


static func item_view(id: int, rec: Dictionary) -> Dictionary:
	if not on():
		return rec
	var c = _item_views.get(id)
	if c is Array and is_same(c[0], rec):
		return c[1]
	var raw: Dictionary = XDB.table("CodexOrbs")
	var sp: Dictionary = raw.items[str(id)]
	var old: Array = sp.get("effects", [])
	var fx := effects(raw.families[int(sp.family)], int(sp.rank))
	var out: Dictionary = rec.duplicate()
	var note := str(rec.get("note", ""))
	var desc := str(rec.get("description", ""))
	for i in mini(old.size(), fx.size()):
		note = note.replace("text=%s size=" % str(old[i]), "text=%s size=" % str(fx[i]))
	if old.size() > 0:
		desc = desc.replace("；".join(old), "；".join(fx))
	if ATTR_CAP:
		note = note.replace("text=%s size=" % CAP_TEXT_OLD, "text=%s size=" % CAP_TEXT)
	out["note"] = note
	out["description"] = desc
	out["meta"] = XTianqiSkills.parse_meta(note)
	_item_views[id] = [rec, out]
	return out


# ---- 原作旧宝珠不再掉 ----
static func legacy(id: int) -> bool:
	var raw = XDB.table("CodexOrbs")
	return raw is Dictionary and raw.get("legacyRefund", {}).has(str(id))


## 怪物掉落行（battle_logic.drop_chances 末尾）：天启篇去掉旧宝珠那几行
static func drop_rows(s, rows: Array) -> Array:
	if not on(s):
		return rows
	return rows.filter(func(r): return not (int(r.get("kind", 0)) == 1 and legacy(int(r.get("id", 0)))))


## 地图事件（XDB.map 读图时改缓存副本；换档时 XTextFix.sync_mode 清地图缓存）：「增减物品」给旧宝珠的换成同值宝珠残片，
## 紧跟的提示「窃取了N个宝珠：名字！」换成「获得了M枚宝珠残片！」。只换加（操作 0、常量）的；扣的不动
static func patch_map(_map_id: int, data) -> void:
	if not on() or not data is Dictionary:
		return
	var raw = XDB.table("CodexOrbs")
	if not raw is Dictionary:
		return
	var frag := int(raw.get("fragment", 0))
	var refund: Dictionary = raw.get("legacyRefund", {})
	var re := RegEx.create_from_string(FRAGMENT_TOAST_RE)
	for ev in data.get("events", []):
		if not ev is Dictionary:
			continue
		for page in ev.get("pages", []):
			var list: Array = page.get("list", []) if page is Dictionary else []
			for k in list.size():
				var c = list[k]
				if not c is Dictionary or int(c.get("code", 0)) != 126:
					continue
				var p: Array = c.get("parameters", [])
				if p.size() < 4 or int(p[1]) != 0 or int(p[2]) != 0 or not refund.has(str(int(p[0]))):
					continue
				var n := int(refund[str(int(p[0]))]) * int(p[3])
				var np := p.duplicate()
				np[0] = frag
				np[3] = n
				list[k] = c.duplicate()
				list[k]["parameters"] = np
				if k + 1 < list.size() and list[k + 1] is Dictionary and int(list[k + 1].get("code", 0)) == 355:
					var tp: Array = list[k + 1].get("parameters", [])
					if tp.size() > 0 and re.search(str(tp[0])) != null:
						var nt := tp.duplicate()
						nt[0] = re.sub(str(tp[0]), FRAGMENT_TOAST % n)
						list[k + 1] = (list[k + 1] as Dictionary).duplicate()
						list[k + 1]["parameters"] = nt


# ---- 插槽页 ----
## 第 n 个孔是新宝珠时，下面补一行新表效果（「　　水系伤害+3%　魔法攻击+1%……」）
static func slot_lines(eq: Dictionary, slot: int, size: int, color: String) -> Array:
	if not on():
		return []
	var gem := XOrbs.gem_in_slot(eq, slot)
	var sp := XOrbs.spec(int(gem.get("id", 0))) if not gem.is_empty() else {}
	if sp.is_empty():
		return []
	return [["　　" + "　".join(XOrbs.config().items[str(int(gem.id))].effects), size, color, false, 0]]
