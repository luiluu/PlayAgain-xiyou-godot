class_name XTianqiBattleRules
extends RefCounted
## 【cc·天启篇·未经审查】战中「本场规则」统一数据源（T386 / K1b；设计稿 T254_战中规则条.md 第五节，Kyo 11-22 五问按推荐）。
## 只读聚合三个模块的只读出口 battle_rules(logic)：
##   1. XTianqiHorsemen（四骑士本体／生存战／35 层影子）
##   2. XTianqiQiyinRule（七印里副本／七印书卷／七首之龙揭印）
##   3. XTianqiSegAlien（按段异化与本线预设异化，转给四线异化模块）
## 界面 XSkinRuleStrip 每 0.1 秒读一次 collect。全程只读：不调会重算属性、消耗随机数、改存档的函数。
##
## 每条规则一个 Dictionary（字段见 entry()）：id、source、line、seal、name、summary、icon、counter、value、max_value、
## countdown、tone（warn／buff／line／gold）、priority（10 紧迫、20 主规则、30 光环／异化、40 补充）、badge、detail_extra。
##
## 开关 ENABLED（O-635）：false＝collect 恒返回 []，规则条不建（回到现状）；西游档、非天启篇战斗本来就是空。

static var ENABLED := true

const SOURCE_ORDER := {"horsemen": 0, "qiyin": 1, "alien": 2}
const LINE_NAMES := {"war": "战争", "death": "死亡", "famine": "饥荒", "plague": "瘟疫"}
## O3 骑士徽记（XTianqiQiyinArt.SMALL 800 块：死亡、战争、饥荒、瘟疫）
const LINE_ICONS := {"death": 310800, "war": 310801, "famine": 310802, "plague": 310803}


## 本场生效的规则（已排序）；开关关、没有天启篇规则时 []
static func collect(logic) -> Array:
	if not ENABLED or logic == null:
		return []
	var out := []
	var seq := 0
	for part in [XTianqiHorsemen.battle_rules(logic), XTianqiQiyinRule.battle_rules(logic), XTianqiSegAlien.battle_rules(logic)]:
		for r in part:
			if r is Dictionary and str(r.get("name", "")) != "":
				var e: Dictionary = r
				e["_seq"] = seq
				seq += 1
				out.append(e)
	out.sort_custom(func(a, b):
		if int(a.priority) != int(b.priority):
			return int(a.priority) < int(b.priority)
		var sa := int(SOURCE_ORDER.get(str(a.source), 9))
		var sb := int(SOURCE_ORDER.get(str(b.source), 9))
		if sa != sb:
			return sa < sb
		return int(a._seq) < int(b._seq))
	return out


## 详卡顶栏的来源胶囊（如「骑士战 · 证道」「默印 · 里副本」「异化 · 饥荒」；文字照小A 文字审定稿 T387）；没有规则时 ""
static func source_label(logic) -> String:
	if not ENABLED or logic == null:
		return ""
	if XTianqiHorsemen.active(logic):
		var f := XTianqiHorsemen.fight(logic)
		match str(f.get("mode", "body")):
			"survival":
				return "骑士战 · 生存战"
			"shadow":
				return "骑士战 · 骑士之影"
		return "骑士战 · 证道" if not XTianqiHorsemen.zd_rule(f).is_empty() else "骑士战"
	if XTianqiQiyinRule.active(logic):
		var q := XTianqiQiyinRule.fight(logic)
		if bool(q.get("dragon", false)):
			return "七首之龙"
		if XTianqiQiyinRule.enemy_only(logic):
			return "七印书卷"
		var info := XTianqiQiyin.seal_info(str(q.get("seal", "")))
		return "%s · 里副本" % str(info.get("seal", "七印")) if not info.is_empty() else "里副本"
	var line := XTianqiSegAlien.active_line(logic)
	if line != "":
		return "异化 · %s" % str(LINE_NAMES.get(line, "")) if LINE_NAMES.has(line) else "异化战"
	return ""


## 拼一条规则（没给的字段按默认补）
static func entry(id: String, source: String, name: String, summary: String, opts := {}) -> Dictionary:
	var e := {"id": id, "source": source, "line": "", "seal": "", "name": name, "summary": summary, "icon": 0, "counter": "",
		"value": -1.0, "max_value": 0.0, "countdown": -1, "tone": "gold", "priority": 30, "badge": "", "detail_extra": ""}
	e.merge(opts, true)
	return e


## 倒数读数（T387 定稿）：≥2「N 回合后」；1「下回合」；0「本回合」
static func countdown_text(n: int) -> String:
	if n <= 0:
		return "本回合"
	if n == 1:
		return "下回合"
	return "%d 回合后" % n


## 减益读数用真减号（U+2212，T387 定稿）
const MINUS := "−"


## 按档位拼化形／终焉尾句（化形起加 huaxing，终焉再加 zhongyan）
static func tier_tail(text: String, idx: int, huaxing := "", zhongyan := "") -> String:
	if idx >= 2 and huaxing != "":
		text += "化形：" + huaxing
	if idx >= 3 and zhongyan != "":
		text += "终焉：" + zhongyan
	return text


static func pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## 四线异化模块共用：场上活着的异化 {kind: 最高档位 idx}，按首次出现顺序
static func alien_kinds(f: Dictionary) -> Dictionary:
	var out := {}
	var units: Dictionary = f.get("units", {})
	for e in units:
		if e == null or not is_instance_valid(e) or not e.is_alive():
			continue
		var k := str(units[e].get("kind", ""))
		out[k] = maxi(int(out.get(k, -1)), int(units[e].get("idx", 0)))
	return out


## 档位名（侵染、蚀骨、化形、终焉；四线 tiers 表同名）
static func tier_name(idx: int) -> String:
	return ["侵染", "蚀骨", "化形", "终焉"][clampi(idx, 0, 3)]


## 档位名的角标：化形、终焉才标（侵染、蚀骨不标）
static func tier_badge(idx: int) -> String:
	return ["", "", "化形", "终焉"][clampi(idx, 0, 3)]
