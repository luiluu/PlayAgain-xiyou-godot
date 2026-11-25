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
const FRAGMENT_TOAST := "窃取了%d枚宝珠残片！"

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
static func line_value(line_key: String, rank: int) -> int:
	var r := clampi(rank, 1, 5) - 1
	return int(ELEM[r]) if line_key.to_upper().begins_with("ELEMENT AMPLIFY") else int(ATTR[r])


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
		var o: Array = _orbs_of(e, cfg) if e is Dictionary and not (e as Dictionary).is_empty() else []
		found.append(o)
		any = any or not o.is_empty()
	if not any:
		return list
	var keep := _kept(found, int(cfg.get("familyCap", 0)))
	var out := []
	for i in list.size():
		out.append(list[i] if (found[i] as Array).is_empty() else view(list[i], found[i], keep.get(i, {}), cfg))
	return out


## 每件装备上算数的族 {装备下标: {族: 阶}}：同族全身只留阶最高的 cap 件（阶同装备靠前优先，同 XOrbs.cap_drops）
static func _kept(found: Array, cap: int) -> Dictionary:
	var by := {}
	for i in found.size():
		var best := {}
		for o in found[i]:
			best[o.family] = maxi(int(best.get(o.family, 0)), int(o.rank))
		for f in best:
			if not by.has(f):
				by[f] = []
			by[f].append({"i": i, "rank": int(best[f])})
	var keep := {}
	for f in by:
		var rows: Array = by[f]
		rows.sort_custom(func(x, y): return x.rank > y.rank or (x.rank == y.rank and x.i < y.i))
		if cap > 0:
			rows = rows.slice(0, cap)
		for x in rows:
			if not keep.has(x.i):
				keep[x.i] = {}
			keep[x.i][f] = x.rank
	return keep


## 一件装备的新表视图：浅拷贝，特性数组换新（超上限的族照旧留原对象，由 XOrbs.filter_traits 按身份剔掉），yep 深拷贝后改元素增幅。
## _tq_orb_amp 记新表算进来的元素增幅（伤害加成总账 orb 桶读它）
static func view(eq: Dictionary, orbs: Array, keep: Dictionary, cfg: Dictionary) -> Dictionary:
	var v: Dictionary = eq.duplicate(false)
	var traits := []
	for t in eq.get("traits", []):
		if t is Dictionary and t.has("_codexOrb"):
			var parts := str(t._codexOrb).split(":")
			var f := int(parts[0])
			if keep.has(f) and parts.size() > 1:
				var nt: Dictionary = t.duplicate()
				var pct := float(line_value("", int(parts[1]))) / 100.0
				nt["value"] = pct if int(t.get("code", 0)) == 22 else 1.0 + pct
				traits.append(nt)
				continue
		traits.append(t)
	v["traits"] = traits
	var amp_old := {}
	var amp_new := {}
	var seen := {}
	for o in orbs:
		var gem := XDB.rec("Items", int(o.id))
		var type := str((eq.get("augmentSlots", []) as Array)[o.slot] if o.slot < (eq.get("augmentSlots", []) as Array).size() else "").to_upper().strip_edges()
		for line in XOrbs.parse(gem).attach.get(type, []):
			var m := _amp_re().search(str(line))
			if m:
				amp_old[m.get_string(1)] = float(amp_old.get(m.get_string(1), 0.0)) + float(m.get_string(2)) / 100.0
		if seen.has(o.family) or not keep.has(o.family) or int(keep[o.family]) != int(o.rank):
			continue
		seen[o.family] = true
		for l in cfg.families[int(o.family)].lines:
			var lk := str(l[0])
			if lk.to_upper().begins_with("ELEMENT AMPLIFY "):
				var ek := lk.substr(16).strip_edges()
				amp_new[ek] = float(amp_new.get(ek, 0.0)) + float(line_value(lk, int(o.rank))) / 100.0
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
		_pos("镶嵌部位：%s孔" % f.slot), _pos("同一件装备同类最多1颗，全身同类只算最高3颗")]
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
## 紧跟的提示「窃取了N个宝珠：名字！」换成「窃取了M枚宝珠残片！」。只换加（操作 0、常量）的；扣的不动
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
