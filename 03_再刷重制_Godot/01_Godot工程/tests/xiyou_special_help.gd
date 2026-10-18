extends Node
## 特殊角色说明卡验收：XHelpCard.content()（XCharacterHelp）与正式版 Sprite_ItemHelp.setItem 实际画出的行
## （generated/oracle/special_help_cards.json，探针 03_转换工具/mv_oracle/special_help_probe.cjs）逐行一致——
## 文字、字号、颜色、对齐、每行 y 与卡高。范围：渡鸦～哈基米（167～178）的图鉴技能与 10122～10299 全部技能、
## 专属装备，按图鉴预览态（未招募、初始等级、未学会、0 阶）。另核图鉴技能表与转换器导出的原文表。
## 卡宽照备注 <HelpWidth: N>（XHelpCard.width_for）。

const ORACLE := "res://modes/xiyou/generated/oracle/special_help_cards.json"
const POWER_PREFIX := "装备战力："

var results := []
var detail_left := 400


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok and detail_left > 0:
		detail_left -= 1
		print("FAIL ", name, " ", JSON.stringify(detail))


static func oracle_measure(t: String, s: int) -> float:
	return t.length() * s * 0.6


## 还没对上的卡：都靠尚未接入的系统（法宝等级／经验与法宝战力、饿狼破限之心的形态说明、云裳天衣铺的法宝行）。
## 这些卡仍逐行比对；一旦对上就报失败，提醒把它从这里删掉。
const PENDING := {
	"armors_4001": "法宝战力：XPower 未算渡鸦法宝的魂海加成",
	"armors_4577": "法宝战力：XPower 未算米拉法宝的倍率",
	"armors_4580": "法宝战力：XPower 未算甚尔法宝的倍率",
	"armors_7904": "破限之心：installNativeGarouRuntime 按形态现编的说明",
	"armors_7905": "破限之心：同上",
	"armors_7906": "破限之心：同上",
	"armors_7908": "破限之心：同上",
	"armors_7909": "破限之心：同上",
	"armors_7910": "破限之心：同上",
	"armors_7911": "破限之心：同上",
	"armors_7935": "天衣铺：installNativeYunshangRuntime 的法宝等级、经验与按等级的能力行",
}


## 不一致时返回差异，一致时返回 null
func _diff(cat: String, card: Dictionary):
	var table: String = {"skills": "Skills", "weapons": "Weapons", "armors": "Armors"}[cat]
	var obj := XDB.rec(table, int(card.id))
	var got := XHelpCard.content(obj, {"skills": "skill", "weapons": "weapon", "armors": "armor"}[cat])
	var want: Array = card.rows
	if not want.any(func(r): return str(r[0]).begins_with(POWER_PREFIX)):
		got = got.filter(func(r): return not str(r[0]).begins_with(POWER_PREFIX))
	if not is_equal_approx(XHelpCard.width_for(obj), float(card.width)):
		return {"width": [XHelpCard.width_for(obj), card.width]}
	var lay := XHelpCard.layout(got, 0, XHelpCard.width_for(obj), oracle_measure)
	if got.size() != want.size():
		return {"rows": [got.size(), want.size()], "got": got.map(func(r): return r[0]), "want": want.map(func(r): return r[0])}
	for i in range(want.size()):
		var g: Array = got[i]
		var w: Array = want[i]
		var g_align = null if g[4] == null else int(g[4])
		var w_align = null if w[4] == null else int(w[4])
		var row_ok: bool = str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) and g_align == w_align
		if not (row_ok and is_equal_approx(float(lay.lines[i].y), float(w[3]))):
			return {"row": i, "got": [g[0], g[1], g[2], g_align, lay.lines[i].y], "want": [w[0], w[1], w[2], w_align, w[3]]}
	var h_ok: bool = is_equal_approx(float(lay.height), float(card.height)) if float(card.height) > 0 else want.is_empty()
	return null if h_ok else {"height": [lay.height, card.height]}


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", data is Dictionary and data.has("skills") and data.get("state") == "preview")
	var help := XCharacterHelp.data()
	_check("copies_exported", help.get("copies", {}).size() > 0 and help.get("dyn2Ids", []).size() > 0)
	XHelpCard.REAL_SELL_PRICE = false
	if data is Dictionary:
		var pending_seen := []
		for cat in ["skills", "weapons", "armors"]:
			var same := 0
			var cards: Array = data.get(cat, [])
			for card in cards:
				var key := "%s_%d" % [cat, int(card.id)]
				var d = _diff(cat, card)
				if d == null:
					same += 1
				if PENDING.has(key):
					pending_seen.append(key)
					_check(key + "_still_pending", d != null, "已与正式版一致，从 PENDING 删掉")
				else:
					_check("%s_%s" % [key, card.name], d == null, d)
			print("%s %d/%d" % [cat, same, cards.size()])
		_check("pending_listed", pending_seen.size() == PENDING.size(), {"seen": pending_seen, "listed": PENDING.keys()})
		# 图鉴技能表：12 名角色，每人至少 8 个技能，都在参照里有卡
		var ids := {}
		for c in data.skills:
			ids[int(c.id)] = true
		var book: Dictionary = data.get("actors", {})
		_check("book_actors", book.size() == 12, book.keys())
		for aid in book:
			var list: Array = book[aid].skills
			_check("book_%s" % aid, list.size() >= 8 and list.all(func(i): return ids.has(int(i))), list)
	XHelpCard.REAL_SELL_PRICE = true
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
