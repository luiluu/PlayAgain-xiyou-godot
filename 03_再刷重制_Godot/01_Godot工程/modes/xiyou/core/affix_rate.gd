class_name XAffixRate
extends RefCounted
## 【cc·悟空·未经审查】v0.62 神话／混沌神话词条概率随难度浮动（新源 v0.62.12 js/codex/runtime/installAffixDifficultyRateRuntime.js，
## window.CodexAffixRate v1）。参照 mv_oracle/affix_rate_probe.cjs → tests/fixtures/affix_rate_oracle.json（tests/xiyou_affix_rate）。
## - 只管「整行都是神话／混沌神话」的词条行：行内全部有效词条（XGear.valid_affix）备注带 <quality:14> 或 <quality:15>（line_tier）。
## - 倍率 M 按路线开关取第一个开着的（ROUTES 顺序，高难度在前）：洪荒 2＋3×(诅咒倍率−1)÷(6.075−1)（诅咒倍率夹在 1～6.075），
##   灭世 1.5、天灾 1、地狱 0.75、困难 0.55、普通 0.4、简单 0.3、宝宝 25；都没开为 1。不读难度编号（副本会临时改成 1）。
## - M＝1 或不是高阶行：走原来的掷法（XGear.roll_item 那段，整数骰 floor(r×100)+1）。
##   否则每行仍取一个预掷随机数 roll＝r×100，各选项概率改成 min(配置×M, 50)，按配置概率升序逐项减，roll 小于该项就中；都不中＝不出词条。
## - 修行·详细页（G.detailRows 包装）末尾加一段「高阶词条概率」（detail_rows，XGuide.detail_rows 调）。
## O-302：ENABLED＝false 回 v0.28（一律原掷法，修行页不加这段）。
## O-305（原版 bug，Kyo 2026-11-07「原版的bug要修」）：原版 min(配置×M, 50) 把配置本来就超过 50% 的行
## （落芸之力等 100% 行）在 M≠1 时一律压到 50%——灭世、洪荒、宝宝反而比天灾（M＝1 走原掷法、100%）低，地狱 75% 也被压到 50%。
## 修好：封顶取 max(50, 配置)，即 min(配置×M, max(50, 配置))，高于 50% 的行只会被低难度按倍率降低、不会被高难度压低。
## FIX_CAP_BASE＝false 照原版。
static var ENABLED := true
static var FIX_CAP_BASE := true
## O-303（原版 bug）：原版这段包装 G.detailRows 装在 main.js 第 201 行，而「修行·详细」窗口
## （installNativeGuidanceRuntime 第 201 行 panelWindow(JAH_Window_Status_ZhenqiDetail, G.detailRows)）在第 160 行装引导模块时
## 就把旧的 G.detailRows 抓走了，包装从来到不了页面：v0.62.12 实机与 zhenqi_probe 的「修行·详细」都没有这一段。
## 作者本意是显示（方案 v0.3「修行页末尾加一段」），修好＝显示；DETAIL_SHOWN＝false 照原版不显示。
static var DETAIL_SHOWN := true
const CAP := 50.0
const HH_MAX := 6.075
const ROUTES := [
	{"key": "primordial", "name": "洪荒", "sw": [2483, 2463]},
	{"key": "doom", "name": "灭世", "sw": [2487, 2462], "m": 1.5},
	{"key": "calamity", "name": "天灾", "sw": [2489, 2461], "m": 1.0},
	{"key": "hell", "name": "地狱", "sw": [2494], "m": 0.75},
	{"key": "hard", "name": "困难", "sw": [2500], "m": 0.55},
	{"key": "normal", "name": "普通", "sw": [2491], "m": 0.4},
	{"key": "easy", "name": "简单", "sw": [2492], "m": 0.3},
	{"key": "baby", "name": "宝宝", "sw": [2496], "m": 25.0},
]
static var _quality_re: RegEx = null


## C.route：没开任何路线开关为空字典
static func route(s: XState) -> Dictionary:
	if s == null:
		return {}
	for r in ROUTES:
		if r.sw.any(func(id): return s.switch(int(id))):
			return r
	return {}


## C.curse：CodexHonghuang.curseBonus()，至少 1
static func curse(s: XState) -> float:
	var holder := XHonghuang.curse_holder(s) if s != null else null
	return maxf(1.0, XHonghuang.curse_bonus(holder) if holder != null else 1.0)


static func factor_of(r: Dictionary, curse_bonus: float) -> float:
	if r.is_empty():
		return 1.0
	if r.key == "primordial":
		var h := minf(HH_MAX, curse_bonus)
		return 2.0 + 3.0 * (h - 1.0) / (HH_MAX - 1.0)
	return float(r.m)


static func factor(s: XState) -> float:
	var r := route(s)
	return factor_of(r, curse(s) if not r.is_empty() and r.key == "primordial" else 1.0)


static func rate(s: XState, base: float) -> float:
	return minf(CAP, base * factor(s))


## Math.round(x*100)/100 再按 JS 数字转字符串
static func _round2(v: float) -> String:
	return MVScript.js_number(roundf(v * 100.0) / 100.0)


## Number.toFixed(2).replace(/\.?0+$/, '')
static func _fixed_trim(v: float) -> String:
	var t := "%.2f" % v
	var m := XRx.re("\\.?0+$").search(t)
	return t.substr(0, m.get_start()) if m != null else t


static func label(s: XState) -> String:
	var r := route(s)
	return (str(r.name) if not r.is_empty() else "未选路线") + " ×" + _round2(factor(s))


static func _quality(rec: Dictionary) -> int:
	if _quality_re == null:
		_quality_re = XRx.re("(?i)<quality:\\s*(\\d+)>")
	var m := _quality_re.search(str(rec.get("note", "")))
	return int(m.get_string(1)) if m != null else 0


## C.lineTier：行内全部有效词条都是 14／15 品质时返回最高档，否则 0
static func line_tier(choices: Array, table: String) -> int:
	var top := 0
	var any := false
	for c in choices:
		for n in c.ids:
			if not XGear.valid_affix(table, int(n)):
				continue
			any = true
			var q := _quality(XDB.rec(table, int(n)))
			if q < 14:
				return 0
			top = maxi(top, q)
	return top if any else 0


## 浮动后的掷法要不要用：开关开着、M≠1、是高阶行
static func applies(s: XState, choices: Array, table: String) -> bool:
	return ENABLED and factor(s) != 1.0 and line_tier(choices, table) > 0


## 浮动掷法（DreamX.RandomPrefixSuffix.choose 包装）：roll＝r×100（r 已从预掷池取出）；返回 [选项的有效词条, 是否中]，没中返回 []
static func pick(s: XState, choices: Array, table: String, r: float) -> Array:
	var m := factor(s)
	var roll := r * 100.0
	var list := []
	for c in choices:
		var ids: Array = c.ids.filter(func(n): return XGear.valid_affix(table, int(n)))
		if not ids.is_empty():
			var cap := maxf(CAP, float(c.chance)) if FIX_CAP_BASE else CAP
			list.append({"chance": minf(cap, float(c.chance) * m), "base": float(c.chance), "ids": ids})
	list.sort_custom(func(a, b): return a.base < b.base)
	for c in list:
		if roll < c.chance:
			return c.ids
		roll -= c.chance
	return []


## G.detailRows 包装：末尾加的几行（开关关着返回空）
static func detail_rows(s: XState) -> Array:
	if not ENABLED or not DETAIL_SHOWN:
		return []
	var m := factor(s)
	var r := route(s)
	var out := [{"type": "blank"}, {"type": "head", "text": "高阶词条概率　" + (str(r.name) if not r.is_empty() else "未选路线")},
		{"type": "text", "text": "神话、混沌神话词条概率：天灾的 ×%s（单行最高 %d%%）" % [_round2(m), int(CAP)]}]
	if not r.is_empty() and r.key == "primordial":
		out.append({"type": "text", "text": "\\C[8]洪荒按诅咒倍率 ×%.2f 取值：全轻 ×2，四重一中 ×5\\C[0]" % curse(s)})
	out.append({"type": "text", "text": "\\C[8]例：星辰耀光的混沌行 %s%%\\C[0]" % _fixed_trim(rate(s, 1.0))})
	return out
