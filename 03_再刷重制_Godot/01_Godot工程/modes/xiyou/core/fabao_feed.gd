class_name XFabaoFeed
extends RefCounted
## 法宝吃装备升级（法宝与积分重构方案 v0.3 第二节，Kyo 11-13 定「法宝不靠经验丹，靠吃装备」「本来就是刷子游戏」）。
## O-待定-3：
## - ENABLED：背包里的装备可以喂给法宝换经验。一件给的经验只看品质（UnifiedQuality.itemGrades 的档）：
##   普通 18、优秀 24、精良 30、史诗 40、传说 52、不朽 68、神话 88。
##   品质门槛按法宝当前等级：1～24 级能吃普通，25～44 至少优秀，45～64 精良，65～84 史诗，85 以上传说；不够的喂不进去。
##   法宝已到当层上限（XMagicWeapon.max_level，跟楼层走）就不让喂；一次喂一批时喂到上限就停，剩下的装备不扣。
##   不能喂：法宝本身、出售锁定的、不在背包里的（穿在身上的不在背包）。
## - 入口：物品页（武器／护甲分类列表含队员身上的）选中法宝 → 操作菜单在宝珠孔之后，从门槛档到神话每档一行
##   「喂入背包里全部 X 装备（N 件，每件 E 经验）」，确定就把这一档没锁定的全部喂进去、到上限停，提示结果。想留的装备先「出售锁定」。
## - NO_PILLS：法宝经验丹（1901～1908、1987、1997）不上架、不能使用，MagicWeaponAllGainExp 不再加经验。
## 回退：`XFabaoFeed.ENABLED = false`（不能喂）；`XFabaoFeed.NO_PILLS = false`（经验丹照原版）。

static var ENABLED := true
static var NO_PILLS := true

const GRADE_EXP := [18, 24, 30, 40, 52, 68, 88]
const GRADE_NAMES := ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话"]
## [法宝等级上界, 至少要的档]
const GATE := [[24, 0], [44, 1], [64, 2], [84, 3], [99, 4]]
const PILLS := [1901, 1902, 1903, 1906, 1907, 1908, 1987, 1997]


## 装备的品质档（0 普通～6 神话）；没有品质的按普通
static func grade_of(item: Dictionary) -> int:
	var q := str(item.get("meta", {}).get("quality", "0")).strip_edges()
	var grades: Array = XDB.table("UnifiedQuality").get("itemGrades", []) if XDB.table("UnifiedQuality") is Dictionary else []
	var qi := int(q) if q.is_valid_int() else 0
	return clampi(int(grades[qi]) if qi >= 0 and qi < grades.size() else 0, 0, GRADE_EXP.size() - 1)


static func exp_of(item: Dictionary) -> int:
	return GRADE_EXP[grade_of(item)]


## 法宝在这个等级至少要吃哪一档
static func min_grade(level: float) -> int:
	for row in GATE:
		if level <= float(row[0]):
			return int(row[1])
	return int(GATE[-1][1])


## 这件装备能不能喂给这件法宝；能喂返回 ""，否则返回原因
static func reason(s: XState, fabao: Dictionary, item: Dictionary) -> String:
	if not ENABLED:
		return "未开放"
	if not XMagicWeapon.is_magic(fabao):
		return "不是法宝"
	if XMagicWeapon.level_of(fabao) >= XMagicWeapon.max_level(fabao):
		return "法宝已到本层上限"
	if not item.has("instanceId") or XMagicWeapon.is_magic(item) or is_same(item, fabao):
		return "不能喂"
	if not s.gear.any(func(e): return is_same(e, item)):
		return "不在背包里"
	if XItemMarks.is_locked(s, item):
		return "已锁定"
	if grade_of(item) < min_grade(XMagicWeapon.level_of(fabao)):
		return "品质不够（至少%s）" % GRADE_NAMES[min_grade(XMagicWeapon.level_of(fabao))]
	return ""


## 喂一批：按给的顺序逐件喂，到上限就停。preview 为真时只算不改。
## 返回 {used: 喂掉的件数, exp: 加的经验, from: 原等级, to: 新等级, skipped: [{item, reason}], capped: 到上限停下}
static func feed(s: XState, fabao: Dictionary, items: Array, owner: XActor = null, preview := false) -> Dictionary:
	var out := {"used": 0, "exp": 0, "from": XMagicWeapon.level_of(fabao), "to": XMagicWeapon.level_of(fabao), "skipped": [], "capped": false}
	var work := fabao if not preview else fabao.duplicate(true)
	for item in items:
		var why := reason(s, work, item) if not preview else _preview_reason(s, work, item)
		if why == "法宝已到本层上限":
			out.capped = true
			break
		if why != "":
			out.skipped.append({"item": item, "reason": why})
			continue
		var gain := exp_of(item)
		XMagicWeapon.gain_exp(work, float(gain), null if preview else owner)
		if not preview:
			s.lose_gear(item)
		out.used += 1
		out.exp += gain
	out.to = XMagicWeapon.level_of(work)
	if not out.capped and out.to >= XMagicWeapon.max_level(work):
		out.capped = true
	return out


## 预览时法宝是副本：is_same 判断换成看原件
static func _preview_reason(s: XState, work: Dictionary, item: Dictionary) -> String:
	if XMagicWeapon.level_of(work) >= XMagicWeapon.max_level(work):
		return "法宝已到本层上限"
	if not item.has("instanceId") or XMagicWeapon.is_magic(item):
		return "不能喂"
	if not s.gear.any(func(e): return is_same(e, item)):
		return "不在背包里"
	if XItemMarks.is_locked(s, item):
		return "已锁定"
	if grade_of(item) < min_grade(XMagicWeapon.level_of(work)):
		return "品质不够（至少%s）" % GRADE_NAMES[min_grade(XMagicWeapon.level_of(work))]
	return ""


## 背包里某一档、能喂给这件法宝的装备（没锁定、不是法宝）
static func eligible(s: XState, fabao: Dictionary, grade: int) -> Array:
	return s.gear.filter(func(e): return e is Dictionary and grade_of(e) == grade and reason(s, fabao, e) == "")


## 穿着这件法宝的角色（没人穿为 null）
static func owner_of(s: XState, fabao: Dictionary) -> XActor:
	for id in s.party:
		var a := s.actor(int(id))
		if a.equips.any(func(e): return is_same(e, fabao)):
			return a
	return null


## 物品页法宝的操作菜单：从门槛档到神话，每档一行「喂入背包里全部 X 装备（N 件）」
static func actions(s: XState, fabao: Dictionary) -> Array:
	if not ENABLED or not XMagicWeapon.is_magic(fabao):
		return []
	var out := []
	var full := XMagicWeapon.level_of(fabao) >= XMagicWeapon.max_level(fabao)
	for g in range(min_grade(XMagicWeapon.level_of(fabao)), GRADE_EXP.size()):
		var n := 0 if full else eligible(s, fabao, g).size()
		out.append({"text": "喂入背包里全部%s装备（%d 件，每件 %d 经验）" % [GRADE_NAMES[g], n, GRADE_EXP[g]], "symbol": "feed", "ext": g, "enabled": n > 0})
	return out


## 菜单「喂入」：喂完返回提示文字
static func feed_grade(s: XState, fabao: Dictionary, grade: int) -> String:
	var r := feed(s, fabao, eligible(s, fabao, grade), owner_of(s, fabao))
	var text := "喂入 %d 件，经验 +%d，Lv %d → %d" % [int(r.used), int(r.exp), int(r.from), int(r.to)]
	if r.capped:
		text += "（已到本层上限 %d 级）" % int(XMagicWeapon.max_level(fabao))
	return text


# ---- 经验丹下架 ----

static func is_pill(id: int) -> bool:
	return NO_PILLS and PILLS.has(id)


## 商店进货行 [类型 0物品/1武器/2防具, ID, …]
static func filter_goods(rows: Array) -> Array:
	if not NO_PILLS:
		return rows
	return rows.filter(func(g): return not (int(g[0]) == 0 and PILLS.has(int(g[1]))))
