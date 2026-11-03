class_name XGrowthHelp
extends RefCounted
## 【cc·八戒·未经审查】成长装备说明（growth3）：心之钢／杰作利维坦（H.helpRows／describe／helpView）、狂妄／杰作无我（U.*），
## 都是 Sprite_ItemHelp.setItem 包装。参照 growth_help_probe（tests/fixtures/growth_help_oracle.json），专项 xiyou_growth_help。
## - describe：说明里旧版「神武\n13层…／奥恩杰作。…／由狂妄原件…」开头换回数据库说明；备注里旧的成长行（helpPatterns）删掉，
##   按当前层数／盛名重写（H.rewriteHelpRows：效果／战技／冷却／条件行加 \c[1]，倒着追加到 APs）。
## - helpView：拷一份 describe，加「本场成长」（待结算）与狂妄「当前增益」两行，重算 descParams，再按颜色把同色行排在一起（groupHelpRows）。
## O-151 HELP_FIX：原版这两个包装装得早（第 15、17 个），外层的元素包装先 Object.assign 拷了一份再往里传，
##   ①H/U.pending 与 U.gear(a)===i 拿拷贝去比，「本场成长」「当前增益」两行永远不出；②helpView 里重算 descParams，
##   把外层战力包装插的「装备战力」行和元素包装的改动都冲掉。默认按原件比（两行照常出）、元素与战力包装在说明之后照常做；
##   设 false 回到原版（参照逐行比）。
static var HELP_FIX := true

const HEART_PATTERNS := ["^(?:心之钢品质|已叠生命|物防结算|心钢层数|心钢|结算)：",
	"^等级需求：无$", "^基础属性：生命\\+", "^特效：全局回合结束回复", "^战技：巨人吞噬",
	"^伤害：(\\(?[17]000?＋|\\[(?:700|1000)＋)", "^成长：(巨人吞噬|有效造成生命伤害|心钢层数)",
	"^效果：(全局回合结束|每回合结束|巨人吞噬|敌方物防)", "^冷却：巨人吞噬", "^进度：心钢", "^旧版生命：", "^成长：额外最大生命", "^本场成长：心钢"]
const HUBRIS_PATTERNS := ["^(?:盛名层数|盛名|扬名|Boss战|阶|参与|结算|增益|持续|穿透|扬名增益|本场待结算盛名)：",
	"^等级需求：无$", "^基础属性：物攻\\+", "^成长：(普通|盛名层数)",
	"^效果：(物理伤害忽略|物防穿透|参与击杀|首领|增益刷新|扬名)", "^条件：参与需", "^进度：盛名", "^本场成长：盛名", "^当前增益：扬名"]
const GOLD := "rgba(255,220,100,1)"


static func target(obj) -> bool:
	return XHeartsteel.is_gear(obj) or XHubris.is_gear(obj)


## H.helpNumber：保留 6 位小数，整数不带小数点
static func number(n: float) -> String:
	var v := roundf(n * 1000000.0) / 1000000.0
	return str(int(v)) if v == floorf(v) else str(v)


static func heart_rows(item: Dictionary) -> Array:
	var k := XHeartsteel.stacks(item)
	var n := XHeartsteel.stage(item)
	var lev := XHeartsteel.is_leviathan(item)
	var rows := ["成长：心钢层数%d；最大生命×%s" % [k, number(XHeartsteel.hp_rate(item))],
		"进度：心钢升阶还需%d层" % (XHeartsteel.stage_need(n + 1) - k),
		"伤害：[%d＋常态最大生命×%s]×%s" % [1000 if lev else 700, "8%" if lev else "6%", number(1.0 + 0.1 * n)],
		"效果：每回合结束回复%d%%最大生命" % (5 if lev else 3),
		"战技：巨人吞噬；物理，单体，不可暴击",
		"冷却：巨人吞噬开战后行动2次可用；施放后行动3次恢复",
		"效果：巨人吞噬命中积累心钢，胜利后保留"]
	if XHeartsteel.growth(item) > 0:
		rows.insert(2, "成长：额外最大生命＋%d" % XHeartsteel.growth(item))
	return rows


static func hubris_rows(item: Dictionary) -> Array:
	var k := XHubris.growth(item)
	var n := XHeartsteel.stage_of(k)
	var lev := XHubris.is_ataraxia(item)
	return ["成长：盛名层数%d；扬名时物理攻击×%s" % [k, number(XHubris.rate_for(item, k))],
		"进度：盛名升阶还需%d层" % (XHeartsteel.stage_need(n + 1) - k),
		"效果：物防穿透%d%%" % (27 if lev else 18),
		"效果：参与击杀获得扬名；首领战中持续造成伤害也可触发",
		"效果：扬名积累盛名，胜利后保留",
		"效果：扬名持续%d个完整回合，触发回合不计" % (4 if lev else 3),
		"效果：扬名刷新不叠加；死亡、卸装或战斗结束时清除"]


## H.rewriteHelpRows：删掉 APs 里匹配 patterns 的旧行，再把 rows 倒着追加
static func rewrite(item: Dictionary, patterns: Array, rows: Array) -> void:
	var tag := RegEx.create_from_string("<pos=APs text=([\\s\\S]*?) size=[^>]*>\\s*")
	var code := RegEx.create_from_string("(?i)\\\\c\\[\\d+\\]")
	var res: Array = patterns.map(func(p): return RegEx.create_from_string(p))
	var note := str(item.get("note", ""))
	var out := ""
	var at := 0
	for m in tag.search_all(note):
		out += note.substr(at, m.get_start() - at)
		var plain := code.sub(m.get_string(1), "", true).replace(":", "：")
		if not res.any(func(r): return r.search(plain) != null):
			out += m.get_string()
		at = m.get_end()
	out += note.substr(at)
	out = out.strip_edges()
	var head := RegEx.create_from_string("^(?:效果|战技|冷却|条件)：")
	for i in range(rows.size() - 1, -1, -1):
		var text := str(rows[i])
		if head.search(text) != null:
			text = "\\c[1]" + text
		out += "\n<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % text
	item.note = out


## H.describe／U.describe（就地改）
static func describe(item: Dictionary) -> void:
	var heart := XHeartsteel.is_gear(item)
	if not heart and not XHubris.is_gear(item):
		return
	var old := "^神武\\n(?:13层[^\\n]*|奥恩杰作。[^\\n]*)" if heart else "^神武\\n(?:13层[^\\n]*|由狂妄原件[^\\n]*)"
	var base := XDB.rec("Armors", XHeartsteel.base_id(item))
	item.description = RegEx.create_from_string(old).sub(str(item.get("description", "")), str(base.get("description", "")))
	if heart:
		rewrite(item, HEART_PATTERNS, heart_rows(item))
	else:
		rewrite(item, HUBRIS_PATTERNS, hubris_rows(item))


static func _gold(text: String) -> String:
	return "\n<pos=APs text=%s size=18 color=%s line=false align=0>" % [text, GOLD]


## H/U.helpView 的备注部分：live 是原件（HELP_FIX 关时原版拿到的是拷贝，待结算与增益对不上）
static func view(live: Dictionary) -> Dictionary:
	var v := live.duplicate(true)
	if not HELP_FIX:
		# 外层元素包装的 proxy：备注与说明先做元素别名
		v.note = XHelpCard.gear_text(str(v.get("note", "")))
		v.description = XHelpCard.gear_text(str(v.get("description", "")))
	describe(v)
	if not HELP_FIX:
		return v
	if XHeartsteel.is_gear(live):
		var pending := XHeartsteel.pending(live)
		if pending:
			v.note += _gold("本场成长：心钢＋%d层，胜利后保存" % pending)
		return v
	var pending := XHubris.pending(live)
	if pending:
		v.note += _gold("本场成长：盛名＋%d层，胜利后保存" % pending)
	var b = XHubris.wearer_buff(live)
	if b != null:
		v.note += _gold("当前增益：扬名使物理攻击×%s；剩余%d个完整回合%s" % [number(float(b.rate)), int(b.remaining), "（本回合不计）" if b.same_round else ""])
	return v


## H.groupHelpRows：同色行排在一起（\c[n] 开头的按调色板号，其余按颜色），各组按第一次出现的次序
static func group(rows: Array) -> Array:
	var order := []
	var groups := {}
	var code := RegEx.create_from_string("^\\\\[cC]\\[(\\d+)\\]")
	for r in rows:
		var m := code.search(str(r[0]))
		var key := "palette:" + m.get_string(1) if m != null else XHelpCard.css_key(str(r[2]))
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(r)
	var out := []
	for k in order:
		out.append_array(groups[k])
	return out


## 说明卡行：describe 后的视图算 descParams，再按色分组
static func rows(obj: Dictionary, type: int) -> Array:
	return group(XHelpCard.desc_params(view(obj), type))
