class_name XTianqiCardVariance
extends RefCounted
## 【cc·天启篇·未经审查】T590 改写过的招的说明卡浮动写法（只改显示，优化登记）。XHelpCard._content 里接；只认改写表里的招、卡开着时。
## 原版的随机倍率改写成了伤害浮动（真火连击 ±67%），改写稿的说明多数没写幅度。
## 一、改写稿已写的幅度统一成「浮动±N%」，N 读生效记录；「0～200%浮动」写成「浮动±100%」；「×a～b随机」统一成「×a～b 随机」。
## 二、浮动大于 20%（20% 是引擎常见默认值，原版说明一向不写）而说明里没有幅度的补上，调数值时说明跟着变。
## 三、改写稿删行时留下了以「消耗」开头的原版费用句，跟改写后的消耗对不上：10462 改成只收能量，整行删掉；
##    10458 那句把状态效果写成了扣生命（收尾挂状态 2720，生命上限×0.01、2 回合），换成状态的说法。
## 本文件不依赖西游通用显示修正（XSkillHelpFix），两边可以分开合入。

## 回退开关：false＝改写稿说明照旧
static var VARIANCE_FIX := true
const VARIANCE_QUIET := 20
## 回退开关：false＝改写稿残留的原版费用句照旧
static var OLD_COST_FIX := true
## 技能号 → 换成的说明（空串＝整行删掉）。通用修正改过的字样也认得（本文件先跑）
const OLD_COST_LINES := {10458: "施放后生命上限降至原来的1%，持续2回合", 10462: ""}
const OLD_COST := "\\n*<pos=APs text=消耗[：:]\\s*\\d+怒气[^>]*?( size=[^>]*)>"

const LINE := "\n<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>"
const WRITTEN := "浮动\\s*±?\\s*(\\d+)\\s*%"


## 没有要改的原样返回 obj，否则返回浅拷贝（只换 note）
static func view(obj: Dictionary) -> Dictionary:
	var id := int(obj.get("id", 0))
	if not obj.has("stypeId") or not XTianqiSkills.has(id) or not XTianqiSkills.cards_on():
		return obj
	var before := str(obj.get("note", ""))
	var note := before
	if VARIANCE_FIX:
		note = _words(note)
		var dmg: Dictionary = obj.get("damage", {})
		if int(dmg.get("type", 0)) != 0:
			note = _amount(note, int(dmg.get("variance", 0)), int(dmg.type) in [3, 4])
	if OLD_COST_FIX and OLD_COST_LINES.has(id):
		note = _old_cost(note, str(OLD_COST_LINES[id]))
	if note == before:
		return obj
	var v := obj.duplicate(false)
	v.note = note
	return v


static func _old_cost(note: String, text: String) -> String:
	return RegEx.create_from_string(OLD_COST).sub(note, "" if text == "" else "\n<pos=APs text=%s$1>" % text, true)


## 只换写法、数字照原文：「浮动N%」「0～200%浮动」写成「浮动±N%」，「随机」前留一个空格
static func _words(note: String) -> String:
	for m in _reversed("在?0～(\\d+)%(?:之间)?浮动", note):
		note = note.substr(0, m.get_start()) + "浮动±%d%%" % (int(m.get_string(1)) / 2) + note.substr(m.get_end())
	note = RegEx.create_from_string(WRITTEN).sub(note, "浮动±$1%", true)
	return RegEx.create_from_string("(×[\\d.]+～[\\d.]+)随机").sub(note, "$1 随机", true)


## 这一招自己的幅度：已写的按记录校对（记录没有浮动、写的是追加那一下时不动数字）；没写且大于 20% 的补上
static func _amount(note: String, n: int, heal: bool) -> String:
	if RegEx.create_from_string(WRITTEN).search(note) != null:
		if n <= 0:
			return note
		# 数字已经写了，同一张卡上不带数字的「随机浮动」删掉（命运·混沌重铸）
		for old in ["伤害随机浮动；", "伤害大幅随机浮动；"]:
			note = note.replace(old, "")
		return RegEx.create_from_string(WRITTEN).sub(note, "浮动±%d%%" % n, true)
	if n <= VARIANCE_QUIET:
		return note
	var text := "浮动±%d%%" % n
	for old in ["伤害随机浮动", "伤害大幅随机浮动"]:
		if note.contains(old):
			return note.replace(old, "伤害" + text)
	var m := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]伤害[：:][^>]*?(?= size=)").search(note)
	if m != null:
		return note.substr(0, m.get_end()) + "，" + text + note.substr(m.get_end())
	return note + LINE % ("\\c[1]效果：%s%s" % ["治疗" if heal else "伤害", text])


static func _reversed(pattern: String, note: String) -> Array:
	var out := RegEx.create_from_string(pattern).search_all(note)
	out.reverse()
	return out
