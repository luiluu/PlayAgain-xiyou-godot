class_name XPingbi
extends RefCounted
## 屏蔽掉落（SiShiTan-PingBi-fix2，正式 v0.21 由 installUnifiedQualityRuntime 改成按七档分组）：
## - $gameSystem._pingbiQuality（随存档，XState.pingbi_quality）按旧档 0～7 记屏蔽；$gameParty.isPinbi() 开局即为真，
##   所以每场战斗的全部掉落（含额外掉落，PingBi 排在掉落插件最后）都过滤：武器/防具里 Number(meta.quality) 号被屏蔽的去掉。
## - 子页每个七档一行（只列含旧档 0～7 的档：普通/优秀/精良/史诗/传说），「屏蔽X装备 关/开/部分」；
##   切换时整档成员一起改：原来全关就全开，否则（全开或部分）全关。

const MAX_LEGACY := 7


static func members(g: int) -> Array:
	var out := []
	var grades: Array = XQuality.config().itemGrades
	for q in grades.size():
		if int(grades[q]) == g and q <= MAX_LEGACY:
			out.append(q)
	return out


static func blocked(s: XState, q: int) -> bool:
	return q >= 0 and q < s.pingbi_quality.size() and bool(s.pingbi_quality[q])


## "none" / "all" / "partial"；该档没有旧档 0～7 成员时为 ""
static func state(s: XState, g: int) -> String:
	var ids := members(g)
	if ids.is_empty():
		return ""
	var n := ids.filter(func(q): return blocked(s, q)).size()
	return "none" if n == 0 else ("all" if n == ids.size() else "partial")


## 子页的行：[七档, 名字]
static func rows(s: XState) -> Array:
	var out := []
	for g in XQuality.config().names.size():
		var st := state(s, g)
		if st != "":
			out.append([g, "屏蔽%s装备 %s" % [XQuality.config().names[g], {"none": "关", "all": "开", "partial": "部分"}[st]]])
	return out


static func toggle(s: XState, g: int) -> void:
	var enable := state(s, g) == "none"
	for q in members(g):
		while s.pingbi_quality.size() <= q:
			s.pingbi_quality.append(false)
		s.pingbi_quality[q] = enable


## 掉落过滤（drops 为 {kind, id}）。Number(meta.quality)：空字符串为 0，非整数不对应任何档。
static func filter_drops(s: XState, drops: Array) -> Array:
	return drops.filter(func(d):
		var table: String = {2: "Weapons", 3: "Armors"}.get(int(d.kind), "")
		if table == "":
			return true
		var meta: Dictionary = XDB.rec(table, int(d.id)).get("meta", {})
		if not meta.has("quality"):
			return true
		var text := str(meta.quality).strip_edges()
		var q := 0 if text == "" else (int(text) if text.is_valid_int() else -1)
		return not blocked(s, q))
