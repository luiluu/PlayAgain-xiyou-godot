class_name XSafeSell
extends RefCounted
## 安全出售（正式西游 installSafeSellRuntime v0.40～v0.53.01，CodexSafeSell）：一键出售与挂机自动卖出共用一套「保留」判断。
## O-293（机制，总装二十七批）：ENABLED 关＝换源前的筛法（XItemMarks.sellable_gear：只按品质与锁定，没品质备注的跳过、价为 0 也卖）。
## - 筛选：背包里的装备，旧档（Q.legacy：没有品质备注按 1）在该档成员里（一键出售按七档 Q.members，含旧档 15；挂机按 SellWA 开着的档）。
## - 保留原因（S.reason，有原因就不卖）：锁定（名字带「[锁定]」）→ 模板找不到「装备来源待确认」→ 专属（模板 <req_actors:>，
##   v0.53.01 起专属法宝即带 <Magic Weapon> 的护甲照常卖）→ 已培养或镶嵌（法宝升过级或有经验、异化、心钢／狂妄层数、强化、宝珠孔有东西）
##   → 吞器占用的供体「已被借用」→ 不可出售（既没有金币售价也没有别的出售货币）→ 词条达到保留门槛（九档，默认「不朽及以上」）或词条待确认。
## - 门槛存在挂机卖出配置里（$gameParty._XdRsData_hangUp_SellWeapon.keepAffixTier41，旧键 keepAffixGrade40；两处共用、随存档）。
## - 未移植的来源：深渊商人的吞噬／额外词条（_codexAbsorbed29、_codexExtraAffix29）重制版没有，不判；
##   CodexElements 的备注元素文字统一（baseNote46）重制版不改实例备注，模板与实例原样比。

static var ENABLED := true
## O-442（性能，卖装卡顿）：原版按计划卖时每件卖前再判一次保留原因（doSell 前 if(!S.reason(i))），整批要判两遍。
## 同一帧里刚算出来的计划（挂机战后自动卖出、商店确认时重算的计划）中间没有别的东西能改保留原因：
## 吞器本身带异化标记不卖、被借的供体卖不掉，卖一件只加钱和报酬、拿掉这一件，所以第二遍结果必然相同。
## ONE_PASS 开着时这种计划卖前只查「还在背包里」；跨帧的旧计划照原版再判。设 false 恢复每件都再判。
static var ONE_PASS := true

const TIERS := [{"label": "普通及以上", "rank": 0}, {"label": "优秀及以上", "rank": 18}, {"label": "精良及以上", "rank": 35},
	{"label": "史诗及以上", "rank": 52}, {"label": "传说及以上", "rank": 69}, {"label": "不朽及以上", "rank": 88},
	{"label": "神话★及以上", "rank": 108}, {"label": "神话特效★★及以上", "rank": 110}, {"label": "混沌神话★★★", "rank": 111}]
const HELP := "词条达到保留品质，整件装备保留；关闭仅取消词条筛选。\n锁定、已装备、已培养或镶嵌（含已升级的法宝）装备始终保留；专属武器保留，专属法宝按普通装备出售。"


static func _cfg(s: XState) -> Dictionary:
	return XHangUpAuto.sell_config(s)


static func _int_in(v, lo: int, hi: int) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi


## S.threshold：-1 关闭，0～8 九档；新键非法时读旧键（-1～6），都没有为 5（不朽及以上）
static func threshold(s: XState) -> int:
	var c := _cfg(s)
	if _int_in(c.get("keepAffixTier41"), -1, 8):
		return int(c.keepAffixTier41)
	if _int_in(c.get("keepAffixGrade40"), -1, 6):
		return int(c.keepAffixGrade40)
	return 5


static func label(s: XState) -> String:
	var n := threshold(s)
	return "关闭" if n < 0 else str(TIERS[n].label)


## S.cycle：-1～8 循环（dir<0 往回）
static func cycle(s: XState, dir: int) -> String:
	var n := threshold(s)
	_cfg(s)["keepAffixTier41"] = ((n + 1 + (9 if dir < 0 else 1)) % 10) - 1
	return label(s)


static func rank(q: int) -> int:
	return XQuality.grade_of(q) * 16 + q


static func template(e: Dictionary) -> Dictionary:
	return XDB.rec("Weapons" if str(e.get("kind", "")) == "weapon" else "Armors", int(e.get("base", e.get("id", 0))))


static func _qualities(note: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)<quality:\\s*(\\d+)>").search_all(note):
		out.append(int(m.get_string(1)))
	return out


static func _lines(note: String) -> Array:
	var t := RegEx.create_from_string("(?i)<prefix:[^>]*>|<suffix:[^>]*>").sub(note, "", true)
	var out := []
	for line in RegEx.create_from_string("\\r?\\n").sub(t, "\n", true).split("\n"):
		if line.strip_edges() != "":
			out.append(line.strip_edges())
	return out


## addedNote44：实例备注比模板多出来的行（按行计数抵消）
static func added_note(e: Dictionary, b: Dictionary) -> String:
	var counts := {}
	for t in _lines(str(b.get("note", ""))):
		counts[t] = int(counts.get(t, 0)) + 1
	var out := PackedStringArray()
	for t in _lines(str(e.get("note", ""))):
		if int(counts.get(t, 0)) > 0:
			counts[t] -= 1
		else:
			out.append(t)
	return "\n".join(out)


## S.affixInfo：词条（掷出的前后缀、实例比模板多的 <quality:N>、多出行里的「X特效：」头）各自的旧档与 rank
static func affix_info(e: Dictionary) -> Dictionary:
	var ranks := []
	var grades := []
	var unknown := [false]
	var add := func(q) -> void:
		var n := float(q)
		if n != floorf(n) or n < 0 or n > 15:
			unknown[0] = true
			return
		grades.append(XQuality.grade_of(int(n)))
		ranks.append(rank(int(n)))
	for d in e.get("affixIds", []):
		var r := XDB.rec(str(d.get("table", "")), int(d.get("id", 0))) if d is Dictionary else {}
		if r.is_empty():
			unknown[0] = true
		else:
			add.call(XQuality.legacy(r))
	var b := template(e)
	var tags := _qualities(str(e.get("note", "")))
	for q in _qualities(str(b.get("note", ""))):
		var p := tags.find(q)
		if p >= 0:
			tags.remove_at(p)
	for q in tags:
		add.call(q)
	var extra := added_note(e, b)
	for m in RegEx.create_from_string("(?i)(混沌神话|神话|太古|mod)特效\\s*[:：]").search_all(extra):
		var k := m.get_string(1)
		add.call(15 if k == "混沌神话" else 14 if k == "神话" else 11 if k == "太古" else 13)
	if b.is_empty() or grades.is_empty() and extra.strip_edges() != "":
		unknown[0] = true
	return {"ranks": ranks, "maxRank": ranks.max() if not ranks.is_empty() else -1, "grades": grades, "unknown": unknown[0],
		"max": grades.max() if not grades.is_empty() else -1}


## S.sellable：没标 <Cannot Sell>，且有金币售价（有 sellPrice 看它，否则看 price）或别的出售货币
static func sellable(e: Dictionary) -> bool:
	if e.is_empty() or bool(e.get("cannotSell", false)):
		return false
	var gold := float(e.sellPrice) > 0 if e.has("sellPrice") else float(e.get("price", 0)) > 0
	return gold or XItemMarks.has_sell_rewards(e)


## S.magicGrown：法宝等级或经验高于模板初始值
static func magic_grown(e: Dictionary, b: Dictionary) -> bool:
	if b.is_empty() or not str(b.get("note", "")).to_lower().contains("<magic weapon>"):
		return false
	var t := XGear.template(str(e.get("kind", "armor")), int(e.get("base", 0)))
	return XMagicWeapon.level_of(e) > XMagicWeapon.level_of(t) or XMagicWeapon.exp_of(e) > XMagicWeapon.exp_of(t)


static func _grown(e: Dictionary, b: Dictionary) -> bool:
	if magic_grown(e, b) or not XAlienation.mark(e).is_empty():
		return true
	for k in [XHeartsteel.LEGACY_HP, XHeartsteel.STACKS, XHubris.FAME, "boostCount", "Level", "_upgradeLevel"]:
		if float(e.get(k, 0) if e.get(k) is int or e.get(k) is float else 0) > 0:
			return true
	for v in e.get("augmentSlotItems", []):
		if v != null and str(v) != "" and str(v) != XOrbs.NONE:
			return true
	return false


## S.reason：背包里一件装备的保留原因，空串＝可以卖（已装备的不在背包里，不经过这里）
static func reason(s: XState, e: Dictionary) -> String:
	if str(e.get("name", "")).contains(XItemMarks.LOCK):
		return "锁定"
	var b := template(e)
	if b.is_empty():
		return "装备来源待确认"
	var note := str(b.get("note", ""))
	var magic_armor := str(e.get("kind", "")) != "weapon" and note.to_lower().contains("<magic weapon>")
	if RegEx.create_from_string("(?i)<req_actors\\s*:").search(note) != null and not magic_armor:
		return "专属"
	if _grown(e, b):
		return "已培养或镶嵌"
	if XAlienation.reserved(s, e):
		return "已被借用"
	if not sellable(e):
		return "不可出售"
	var n := threshold(s)
	if n >= 0:
		var a := affix_info(e)
		if a.unknown or int(a.maxRank) >= int(TIERS[n].rank):
			return "词条待确认" if a.unknown else "词条保留"
	return ""


## S.plan：grade≥0 按七档成员（一键出售），grade<0 按挂机 SellWA 开着的旧档；{sell: [装备], keep: [{item, reason}]}，按背包顺序
static func plan(s: XState, grade := -1) -> Dictionary:
	var members := XHangUpAuto.legacy_of(grade) if grade >= 0 else XHangUpAuto.sell_legacy(s)
	var sell := []
	var keep := []
	XAlienation.begin_batch(s)  # O-441：整批查吞器供体表
	for e in s.gear:
		if not members.has(XQuality.legacy(e)):
			continue
		var why := reason(s, e)
		if why != "":
			keep.append({"item": e, "reason": why})
		else:
			sell.append(e)
	XAlienation.end_batch()
	return {"sell": sell, "keep": keep, "frame": Engine.get_process_frames()}


## 按计划卖：每件卖前再判一次（原版 doSell 前 if(!S.reason(i))）。返回 [件数, 金额]
static func sell_plan(s: XState, p: Dictionary) -> Array:
	var n := 0
	var gold := 0
	XAlienation.begin_batch(s)  # O-441：整批查吞器供体表
	var fresh: bool = ONE_PASS and int(p.get("frame", -1)) == Engine.get_process_frames()   # O-442：同一帧的计划不再判第二遍
	for e in p.sell:
		if s.gear.has(e) and (fresh or reason(s, e) == ""):
			gold += XItemMarks.selling_price(e)
			XItemMarks.sell(s, e, 1)
			n += 1
	XAlienation.end_batch()
	return [n, gold]
