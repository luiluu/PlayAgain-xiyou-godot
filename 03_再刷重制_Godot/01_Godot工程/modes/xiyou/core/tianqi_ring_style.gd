class_name XTianqiRingStyle
extends RefCounted
## 【cc·天启篇·未经审查】环纹（天启篇_装备环样式设计 v0.2.1，私密仓 a491070；卡 1）：装备页栏位环跟着身上穿的变样子，只是外观、不加任何数值。
## 三层各认一种东西（第 1、3 节）：
## - 环身（band）：七印套装穿满 5 件 → 本印环身（优先级 50）；1～30 层「旧金微亮」（glint，10）：本线第三档净印／原版重做套装穿齐／生效的符文之语。
##   后两条等养成线重做落地，现在由 orig_set_full_hook／runeword_hook 接（没接恒为假）。
## - 环心（center）：神器栏的骑士遗物（残缺版亮度 ×0.6、说明加「（残）」）；七印神器全队只生效一件（出战顺序第一个戴的人，
##   同 XTianqiQiyinEffects.start），别人戴着的、后备戴着的保持默认环心，说明写「七印神器（未生效）」。成长神器、纪念装备没有标记，不改环心。
## - 单颗球（orbs）：毕业武器（qiyin.kind＝weapon）、刻印过的专属武器（engrave，按刻印来源武器的印）、备注写 <ring_style:键> 或 <ring_style:键:印> 的件。
## - 套装进度小点（dots）：七印套装件穿到 2 件起，每件所在的球外侧一颗印色小点。
## resolve 只按槽位号出，界面自己把槽位号换成环项序号（装备页 items[i].key）。
## 数据 tianqi_data/ring_styles.json；图在 content/tianqi/ring_style/，没有的用程序画的同尺寸灰圈占位（texture()）。
##
## 开关：ENABLED（O-待定-1）false＝resolve 一律空、环和现状一模一样；GLINT（O-待定-2）false＝不认微亮名单（路 A 退回路 B）；
## 玩家设置「装备环纹」codexRingStyle（默认开，D101）。非天启篇存档不生效；新皮肤关、非分支摆法时装备页根本不调。

static var ENABLED := true
static var GLINT := true

const PATH := "res://modes/xiyou/tianqi_data/ring_styles.json"
const ART_DIR := "res://content/tianqi/ring_style/"
const SETTING := "codexRingStyle"
## 判「正红」的门（7.5「不出正红」）：R≥200、G≤90、B≤70
const RED_R := 200
const RED_G := 90
const RED_B := 70

## 养成线重做落地后由那条车道接：func(actor) -> bool。没接（无效 Callable）时恒为假
static var orig_set_full_hook := Callable()
static var runeword_hook := Callable()

static var _data: Dictionary = {}
static var _tex := {}
## 测试用：resolve 被调了几次（挪光标不该重算）
static var resolve_calls := 0


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiRingStyle: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			push_error("XTianqiRingStyle: JSON 解析失败 " + PATH)
			return {}
		_data = parsed
	return _data


static func reload() -> void:
	_data = {}
	_tex.clear()


## 开不开（不看新皮肤和摆法，那两样装备页自己判）
static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return s != null and XTianqi.active(s) and XConfig.flag(SETTING)


static func style(key: String) -> Dictionary:
	var st = data().get("styles", {}).get(key, {})
	return st if st is Dictionary else {}


static func style_name(key: String) -> String:
	return str(style(key).get("name", ""))


static func seal_tint(seal: String) -> Color:
	var c = data().get("seal_tints", {}).get(seal, "")
	return Color.html(str(c)) if str(c) != "" else XUiSkin.GOLD


static func empty_result() -> Dictionary:
	return {"band": "", "center": "", "center_name": "", "center_dim": 1.0, "center_note": "", "orbs": {}, "dots": {}, "sig": ""}


## 七印神器全队生效的那一位：出战成员按顺序第一个 artifact_key 非空的（同 XTianqiQiyinEffects.start）；没有为 null
static func artifact_owner(party: Array):
	for m in party:
		if m is XActor and not XTianqiQiyinEffects.artifact_key(m).is_empty():
			return m
	return null


## 一人的环纹。party：出战成员（按出战顺序），判七印神器是不是这个人生效；不给时当他生效（测试用）。
## 返回 {band, center, center_name, center_dim, center_note, orbs: {槽位: {style, tint}}, dots: {槽位: Color}, sig}
static func resolve(actor, party: Array = [], s = null) -> Dictionary:
	resolve_calls += 1
	var out := empty_result()
	if s == null:
		s = XState.current
	if not (actor is XActor) or not on(s) or data().is_empty():
		return out
	var a := actor as XActor
	var slots := _slots(a)
	# 各印套装件：槽位
	var set_slots := {}
	for sl in slots:
		var m := XTianqiQiyinEffects.mark_of(slots[sl])
		if str(m.get("kind", "")) == "set" and str(m.get("seal", "")) != "":
			if not set_slots.has(str(m.seal)):
				set_slots[str(m.seal)] = []
			set_slots[str(m.seal)].append(sl)
	var band_cands := []
	var center_cands := []
	var rules: Array = data().get("rules", [])
	for ri in rules.size():
		var rule: Dictionary = rules[ri]
		var w: Dictionary = rule.get("when", {})
		var key := str(rule.get("style", ""))
		if w.has("qiyin_set_pieces"):
			for seal in set_slots:
				var n: int = (set_slots[seal] as Array).size()
				if n >= int(w.qiyin_set_pieces):
					_cand(band_cands, key.replace("{seal}", seal), n, ri)
		elif w.has("orig_set_full"):
			if GLINT and orig_set_full_hook.is_valid() and bool(orig_set_full_hook.call(a)):
				_cand(band_cands, key, 0, ri)
		elif w.has("runeword_active"):
			if GLINT and runeword_hook.is_valid() and bool(runeword_hook.call(a)):
				_cand(band_cands, key, 0, ri)
		elif w.has("jingyin"):
			var jw: Dictionary = w.jingyin
			var line := XTianqi.line_of(s) if str(jw.get("line", "current")) == "current" else str(jw.line)
			if GLINT and line != "" and XTianqiRewards.seal_tier(a, line) >= int(jw.get("tier", 3)):
				_cand(band_cands, key, 0, ri)
		elif w.has("relic"):
			var r := XTianqiRewards.relic_of(a)
			if not r.is_empty():
				var c := _cand(center_cands, key.replace("{line}", str(r.line)), 0, ri)
				if not c.is_empty():
					c["half"] = bool(r.half)
		elif w.has("qiyin_artifact"):
			if not XTianqiQiyinEffects.artifact_key(a).is_empty():
				var c := _cand(center_cands, key, 0, ri)
				if not c.is_empty() and bool(style(key).get("team_active_only", false)) and not party.is_empty() and not is_same(artifact_owner(party), a):
					c["inactive"] = true
	# 环身
	var band := _pick(band_cands)
	if not band.is_empty():
		out.band = str(band.key)
	# 环心：没生效的七印神器不改环心，只在说明里写「（未生效）」
	var center := _pick(center_cands)
	if not center.is_empty():
		var cst := style(str(center.key))
		out.center_name = str(cst.get("name", ""))
		if bool(center.get("inactive", false)):
			out.center_note = str(cst.get("inactive_suffix", "（未生效）"))
		else:
			out.center = str(center.key)
			if bool(center.get("half", false)):
				out.center_dim = float(cst.get("half", {}).get("dim", 0.6))
				out.center_note = str(cst.get("half", {}).get("suffix", "（残）"))
	# 球：毕业武器、刻印专属武器、备注挂的
	for sl in slots:
		var e: Dictionary = slots[sl]
		var m := XTianqiQiyinEffects.mark_of(e)
		var seal := ""
		match str(m.get("kind", "")):
			"weapon":
				seal = str(m.get("seal", ""))
			"engrave":
				seal = str(XTianqiQiyinGear.weapon(str(m.get("key", ""))).get("seal", ""))
		if seal != "" and _has_rule("qiyin_weapon" if str(m.kind) == "weapon" else "qiyin_engrave"):
			out.orbs[sl] = {"style": "orb_seal", "tint": seal_tint(seal)}
			continue
		var tag := note_tag(e)
		if not tag.is_empty() and _has_rule("item_tag") and str(style(str(tag[0])).get("layer", "")) == "orb":
			out.orbs[sl] = {"style": str(tag[0]), "tint": seal_tint(str(tag[1])) if str(tag[1]) != "" else Color.html(str(style(str(tag[0])).get("tint", "#e3bd72")))}
	# 小点
	var min_pieces := int(data().get("dots", {}).get("min_pieces", 2))
	for seal in set_slots:
		if (set_slots[seal] as Array).size() >= min_pieces:
			for sl in set_slots[seal]:
				out.dots[sl] = seal_tint(seal)
	out.sig = signature(out)
	return out


## 槽位 → 装备（只取非空的；178 光着手时第 0 格不算，同 XActor.equip_list）
static func _slots(a: XActor) -> Dictionary:
	var out := {}
	for i in range(1 if a._cat_bare else 0, a.equips.size()):
		var e = a.equips[i]
		if e is Dictionary and not e.is_empty():
			out[i] = e
	return out


static func _has_rule(cond: String) -> bool:
	for r in data().get("rules", []):
		if (r.get("when", {}) as Dictionary).has(cond):
			return true
	return false


static func _cand(list: Array, key: String, count: int, order: int) -> Dictionary:
	var st := style(key)
	if st.is_empty():
		return {}
	var c := {"key": key, "priority": int(st.get("priority", 0)), "count": count, "order": order}
	list.append(c)
	return c


## 每层只认一个来源：优先级大的赢，一样大件数多的赢，再一样后出现的赢（第 3 节）
static func _pick(list: Array) -> Dictionary:
	var best := {}
	for c in list:
		if best.is_empty() or int(c.priority) > int(best.priority) \
			or (int(c.priority) == int(best.priority) and (int(c.count) > int(best.count) or (int(c.count) == int(best.count) and int(c.order) >= int(best.order)))):
			best = c
	return best


## 备注 <ring_style:键> 或 <ring_style:键:印> → [键, 印]；没有为空
static func note_tag(e: Dictionary) -> Array:
	var note := str(e.get("note", ""))
	var at := note.find("<ring_style:")
	if at < 0:
		return []
	var end := note.find(">", at)
	if end < 0:
		return []
	var parts := note.substr(at + 12, end - at - 12).strip_edges().split(":")
	return [parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else ""]


## 这身环纹的指纹（判断要不要演出）
static func signature(r: Dictionary) -> String:
	var orbs: Dictionary = r.get("orbs", {})
	var dots: Dictionary = r.get("dots", {})
	var ok := orbs.keys()
	ok.sort()
	var dk := dots.keys()
	dk.sort()
	var o := []
	for k in ok:
		o.append("%d:%s:%s" % [k, orbs[k].style, (orbs[k].tint as Color).to_html()])
	var d := []
	for k in dk:
		d.append("%d:%s" % [k, (dots[k] as Color).to_html()])
	return "%s|%s|%s|%s|%s" % [r.get("band", ""), r.get("center", ""), str(r.get("center_dim", 1.0)), ",".join(o), ",".join(d)]


## 从旧环纹换到新环纹该演什么：burn（0.6 秒铺开）／fade（0.3 秒淡入淡出）／""（不演）。
## 新环身或新环心是 burn 样式（七印、遗物、生效七印神器）→ burn；残缺遗物不演铺开（D96）；其余变化（微亮进出、脱下回默认）→ fade；只是球、小点变了不演
static func intro_kind(old: Dictionary, new: Dictionary) -> String:
	var band_new := str(new.get("band", ""))
	var center_new := str(new.get("center", ""))
	var band_changed := band_new != str(old.get("band", ""))
	var center_changed := center_new != str(old.get("center", "")) or float(new.get("center_dim", 1.0)) != float(old.get("center_dim", 1.0))
	if not band_changed and not center_changed:
		return ""
	if band_changed and band_new != "" and str(style(band_new).get("intro", "")) == "burn":
		return "burn"
	if center_changed and center_new != "" and float(new.get("center_dim", 1.0)) >= 1.0 and str(style(center_new).get("intro", "")) == "burn":
		return "burn"
	return "fade"


## 环下说明的后缀（4.1）：「 · 黑印 · 死亡遗物（残）」；微亮态不写字；没有为空串
static func caption_suffix(r: Dictionary) -> String:
	var parts := []
	var bn := style_name(str(r.get("band", "")))
	if bn != "":
		parts.append(bn)
	var cn := str(r.get("center_name", ""))
	if cn != "":
		parts.append(cn + str(r.get("center_note", "")))
	return "" if parts.is_empty() else " · " + " · ".join(parts)


# ---- 贴图（缺图用程序占位） ----

## layer 的 art 里某一项的贴图：band／frame 按文件名在 ART_DIR 下找、circle 是完整路径；缺了 band／frame 给同尺寸灰圈占位，circle 给 null
static func texture(file: String, kind: String) -> Texture2D:
	if file == "":
		return null
	var key := kind + ":" + file
	if _tex.has(key):
		return _tex[key]
	var path := file if file.begins_with("res://") else ART_DIR + file
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null and kind != "circle":
		t = placeholder(kind)
	_tex[key] = t
	return t


## 占位图（卡 1：图没到时先跑通）：环身 288（主圈 112、装饰带 100～138 两条细边）；环心 96（框 33～38、12 点小尖到 46）；
## 球框 56 灰阶（框身 21～24、四个 45° 斜角饰到 28）。都是原生像素、无柔边、灰色（球框白灰，程序染色）
static func placeholder(kind: String) -> Texture2D:
	var size := {"band": 288, "center": 96, "orb": 56}.get(kind, 56) as int
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size, size) / 2.0
	var grey := Color("9a968c")
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			var deg := rad_to_deg(p.angle())
			var col := Color(0, 0, 0, 0)
			match kind:
				"band":
					if absf(d - 112.0) <= 1.0:
						col = grey
					elif absf(d - 100.5) <= 0.5 or absf(d - 137.5) <= 0.5:
						col = Color(grey, 0.6)
				"center":
					if d >= 33.0 and d <= 38.0:
						col = grey if d <= 34.0 or d >= 37.0 else Color(grey, 0.55)
					elif d > 38.0 and d <= 46.0 and absf(deg + 90.0) <= 15.0 * (46.0 - d) / 8.0:
						col = grey
				"orb":
					if d >= 21.0 and d <= 24.0:
						col = Color("d8d8d8")
					else:
						var diag := absf(absf(p.x) - absf(p.y)) <= 1.5 and d > 24.0 and d <= 28.0
						if diag:
							col = Color("f0f0f0")
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 贴图乘上颜色后有没有正红像素（7.5「不出正红」，查图本身）
static func red_pixels(t: Texture2D, tint := Color.WHITE) -> int:
	if t == null:
		return 0
	var img := t.get_image()
	if img == null:
		return 0
	if img.is_compressed():
		img.decompress()
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y) * tint
			if p.a > 0.05 and p.r8 >= RED_R and p.g8 <= RED_G and p.b8 <= RED_B:
				n += 1
	return n
