extends Node
const Kit := preload("res://tests/lib/tq_save_kit.gd")
## T199（T187 验收 5 遗留；T187 文案草稿，小A R1 P3-2）：归池增伤的说明文字接线，只在天启篇存档套用。
## 一、rules.json tianqi_note_by_id：表名→记录号→[[原文, 改成]]，天启篇备注恰好等于「西游档备注把原文换成改成」，西游档逐字不变。
## 二、写法：半角带前导空格「伤害加成 +20%」；秘籍格带「（秘籍格每本伤害加成最多 +8%）」，九线带「（装备、套装、种族、宝珠的伤害加成合计最多 +35%）」，角色桶不带；数＝damage_ledger.json 池表的 add。
## 三、States 1168 名字；DICT 开关关了回原貌；西游档↔天启篇切档不串。
## 四、171 武器库·万里锁 10223 卡面去掉失效的「（万里锁的一半）」（T191 取整后万里锁×1，这张 60% 不是一半；系数不动）。

const RULES := "res://modes/xiyou/text_fix/rules.json"
const SUF_SECRET := "（秘籍格每本伤害加成最多 +8%）"
const SUF_NINE := "（装备、套装、种族、宝珠的伤害加成合计最多 +35%）"
## 单条 add 已超桶上限的（R1 小A P1-1）：直接写实效上限＋「本条已达上限」
const OVER_SECRET := "（秘籍格每本伤害加成最多 +8%，本条已达上限）"
const OVER_NINE := "（装备、套装、种族、宝珠合计最多 +35%，本条已达上限）"

var results: Array = []
var by_id := {}
var pool := {}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _t(table: String, id: int) -> Dictionary:
	return XDB.table(table)[id]


## 池表一条的期望说明：不超桶上限＝「+add%」＋括号；超了＝「+上限%」＋「本条已达上限」括号；角色桶不带括号
func _want_text(e: Dictionary) -> String:
	var add := int(e.add)
	match str(e.cap):
		"secret":
			return "伤害加成 +%d%%" % add + SUF_SECRET if add <= 8 else "伤害加成 +8%" + OVER_SECRET
		"nine":
			return "伤害加成 +%d%%" % add + SUF_NINE if add <= 35 else "伤害加成 +35%" + OVER_NINE
	return "伤害加成 +%d%%" % add


func _entries() -> Array:
	var out := []
	for tab in by_id:
		if str(tab).begins_with("_"):
			continue
		for id in by_id[tab]:
			out.append([tab, int(id), by_id[tab][id]])
	return out


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_pool_text")
	by_id = XDB.parse_file(RULES).get("tianqi_note_by_id", {})
	var ledger = XDB.parse_file("res://modes/xiyou/tianqi_data/damage_ledger.json")
	for e in ledger.state_confirm_class.pool:
		pool[int(e.id)] = e
	var ents := _entries()
	_check("by_id_loaded", ents.size() >= 50, ents.size())

	# 西游档：逐字不变（原文都在、改成都不在）
	XState.current = XState.new_game_blank()
	XTextFix.sync_mode()
	_check("plain_mode", not XTextFix.tq_on())
	var plain := {}
	var bad := []
	for en in ents:
		var note := str(_t(en[0], en[1]).note)
		plain[[en[0], en[1]]] = note
		for p in en[2]:
			if not note.contains(p[0]) or note.contains(p[1]) or note.contains("伤害加成"):
				bad.append([en[0], en[1], p[0]])
	_check("plain_untouched", bad.is_empty(), bad)
	_check("plain_1168_name", str(_t("States", 1168).name) == "结算伤害*120%，暴击命中+100%", _t("States", 1168).name)

	# 天启篇：备注恰好等于西游档备注换了原文
	var s := Kit.new_game("jiusi")
	_check("tq_mode", XTextFix.tq_on())
	bad = []
	for en in ents:
		var want: String = plain[[en[0], en[1]]]
		for p in en[2]:
			want = want.replace(p[0], p[1])
		want = want.replace("<RightDownNote:\"挣脱天道的枷锁\">", "<RightDownNote:\"挣脱启示的枷锁\">")  # T193 的天启篇备注替换（1001～1003、2442）与本单叠在同一条备注上
		var got := str(_t(en[0], en[1]).note)
		if got != want:
			bad.append([en[0], en[1], got.substr(0, 80)])
	_check("tq_notes_exact", bad.is_empty(), bad)

	# 写法：半角带前导空格，没有全角＋，每条原文在备注里恰好一处
	bad = []
	var re := RegEx.create_from_string("^伤害加成 \\+\\d+%(（[^）]*）|，最终结算受伤 −26%)?$")
	for en in ents:
		for p in en[2]:
			if re.search(str(p[1])) == null or str(p[1]).contains("＋") or plain[[en[0], en[1]]].count(p[0]) != 1:
				bad.append([en[0], en[1], p])
	_check("text_format", bad.is_empty(), bad)

	# 数与封顶说明对上池表（States：add、cap）
	bad = []
	var covered := 0
	for id in pool:
		var e: Dictionary = pool[id]
		if e.action != "pool" or not by_id.States.has(str(id)):
			continue
		covered += 1
		var want: String = _want_text(e)
		if not str(_t("States", id).note).contains(want):
			bad.append([id, want])
	_check("states_match_pool", bad.is_empty() and covered >= 20, [bad, covered])
	# 池表里 pool 的状态：没有备注说明的（DNShow 等）才允许不在表里，且备注里没有旧乘数说法
	bad = []
	for id in pool:
		if pool[id].action != "pool" or by_id.States.has(str(id)):
			continue
		var n := str(_t("States", id).note)
		var r2 := RegEx.create_from_string("(?:所有伤害结果|结算伤害)\\*[\\d.]+")
		if r2.search(n) != null:
			bad.append(id)
	_check("states_unlisted_have_no_old_text", bad.is_empty(), bad)

	# 抽查几句
	_check("spot_secret", str(_t("States", 978).note).contains("<StateNote>\n伤害加成 +8%" + OVER_SECRET + "\n</StateNote>") and str(_t("Skills", 6139).note).contains("效果:伤害加成 +8%" + OVER_SECRET + " size=18") and str(_t("Skills", 6325).note).contains("效果:伤害加成 +5%" + SUF_SECRET + " size=18"), _t("Skills", 6139).note)
	_check("spot_none", str(_t("Skills", 5565).note).contains("\\c[1]效果:伤害加成 +20% size=18") and str(_t("Skills", 5565).note).contains("效果:再动+1 全属性*150%"), _t("Skills", 5565).note)
	_check("spot_nine_armor", str(_t("Armors", 4717).note).contains("\\c[6]神话特效:伤害加成 +30%" + SUF_NINE + " size=18"), _t("Armors", 4717).note)
	_check("spot_nine_weapon_349", str(_t("Weapons", 76).note).contains("特效:伤害加成 +35%" + OVER_NINE) and str(_t("Armors", 129).note).contains("特效:伤害加成 +35%" + OVER_NINE) and str(_t("States", 2301).note).contains("伤害加成 +35%" + OVER_NINE) and not str(_t("States", 2302).note).contains("+900%"))
	_check("spot_mixed_line_kept", str(_t("Skills", 6530).note).contains("效果:伤害加成 +8%" + OVER_SECRET + " 全伤全属性+50% 终伤爆伤+100% 命中率暴击率+300%"), _t("Skills", 6530).note)
	_check("spot_hongmo", str(_t("Skills", 2822).note).contains("效果:伤害加成 +8%" + OVER_SECRET + "，但是封印头盔，护甲、裤子和鞋子"), _t("Skills", 2822).note)
	_check("tq_1168_name", str(_t("States", 1168).name) == "伤害加成 +20%，暴击命中+100%" and str(_t("Skills", 5644).note).contains("效果:伤害加成 +20%，暴击率命中率+100%"), [_t("States", 1168).name])
	# 伤害公式、Custom Confirm Effect、StartPushState 逐字不变（只换了说明）
	var raw_states: Array = XDB.parse_file(XDB.BASE + "db/States.json")
	_check("code_kept", str(_t("States", 978).note).contains("value = Math.ceil(value * 1.1);") and str(_t("Skills", 6139).note).contains("<StartPushState0978: 100%>") and str(raw_states[978].note).contains("Custom Confirm Effect"))
	# 不动的：天顶剑 2300、紫炎莲华 2010、超赛 2771、水晶 1311
	_check("untouched_scope", not by_id.States.has("2300") and not by_id.Weapons.has("2010") and not by_id.Weapons.has("2025") and str(_t("States", 2300).note).contains("造成的所有伤害结果*200%") and str(_t("Weapons", 2025).note).contains("结算伤害*200%"))

	# DICT 开关关了：天启篇回原貌
	XTextFix.DICT = false
	XTextFix.clear_cache()
	bad = []
	for en in ents:
		if str(_t(en[0], en[1]).note).contains("伤害加成"):
			bad.append([en[0], en[1]])
	_check("dict_off_raw", bad.is_empty() and str(_t("States", 1168).name) == "结算伤害*120%，暴击命中+100%", bad)
	XTextFix.DICT = true
	XTextFix.clear_cache()
	# 换档不串
	XState.current = XState.new_game_blank()
	XTextFix.sync_mode()
	bad = []
	for en in ents:
		if str(_t(en[0], en[1]).note) != plain[[en[0], en[1]]]:
			bad.append([en[0], en[1]])
	_check("plain_again", bad.is_empty() and str(_t("States", 1168).name) == "结算伤害*120%，暴击命中+100%", bad)
	XState.current = s
	XTextFix.sync_mode()
	_check("tq_again", str(_t("States", 978).note).contains("伤害加成 +8%") and str(_t("States", 1168).name).begins_with("伤害加成"))

	# P1-2（小A 定稿）：超赛 10563～10566 效果行、水晶 7316（备注兜底＋天启篇卡面）；真·剑九 2539 没有玩家可见乘数说明，不插新行
	var sup := {10563: "\\c[1]超级赛亚人:伤害加成 +150% size", 10564: "\\c[1]超级赛亚人:伤害加成 +240% size", 10565: "\\c[1]超级赛亚人:伤害加成 +320% size", 10566: "\\c[1]神之力:伤害加成 +500% 双攻+500% 再动+1 size"}
	bad = []
	for id in sup:
		var n := str(_t("Skills", id).note)
		if not n.contains(sup[id]) or n.contains("最终伤害+") or n.contains("伤害+"):
			bad.append([id, n])
	_check("sup_lines", bad.is_empty(), bad)
	var n7316 := str(_t("Skills", 7316).note)
	_check("crystal_note_fallback", n7316.contains("伤害加成 +13%，最终结算受伤 −26%") and not n7316.contains("提高13%的最终结算伤害"), n7316)
	_check("crystal_card", XTianqiSkills.spec(7316).desc == ["效果：处于「始源之律者」状态时，普通攻击变为「星海圆舞曲」，伤害加成 +13%，承伤 −13%"], XTianqiSkills.spec(7316).desc)
	_check("sword9_untouched", not by_id.States.has("2539") and not by_id.Skills.has("9998"))
	# 四、10223 卡面（系数不动）
	var d23: Array = XTianqiSkills.spec(10223).get("desc", [])
	_check("toji_10223_desc", d23 == ["伤害：物理攻击×60%"] and is_equal_approx(float(XTianqiSkills.spec(10223).damage.coef), 0.6), d23)
	bad = []
	for id in [10220, 10221, 10222, 10223]:
		for line in XTianqiSkills.spec(id).get("desc", []):
			if str(line).contains("一半"):
				bad.append([id, line])
	_check("toji_no_half_left", bad.is_empty(), bad)
	_check("toji_10217_main", XTianqiSkills.spec(10217).desc[0].begins_with("伤害：物理攻击×1；"), XTianqiSkills.spec(10217).desc)

	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
