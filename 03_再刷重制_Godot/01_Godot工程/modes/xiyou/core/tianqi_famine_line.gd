class_name XTianqiFamineLine
extends RefCounted
## 【cc·天启篇·未经审查】饥荒线（小镇做题家＝三层训练场的吕茂）的关卡流程、事件和对话（四线剧情与关卡设计稿 v0.4 第 4.3、5.1、5.4、5.7 节；
## Kyo 11-11 09:41「首期先做饥荒线」）。台词、地点、敌群、异化数值都在 tianqi_data/famine_line.json（只读）。
## 和线无关的流程（进度、门、开场、使徒、15／25 层、35／36 层）走 XTianqiLine；这里只放饥荒线自己的：
## - 序幕：1～5 层时第一次到三层训练场，吕茂在做题（所有天启篇存档都有，不分线）；饥荒线通关后再到三层，说一次「这次我慢慢做。」
## - 25 层传闻之后的可选「模拟考」：三道题，答对的题数记在 flags.tianqi.famine.quiz（余粮还没有物品，先只记分）。
## 开场三节：1「异兆」三层训练场，侵染·枯竭者的哥布林巫师（教饥饿和口粮）；2「蔓延」伐木者小屋，蚀骨·荒年者的光头强；
## 3「天外裂」天外天，饥荒骑士生存战（XTianqiHorsemen 的 survival：开场即绝粮，吃身边的小怪来打你）。
## 使徒：10 层侵染·枯竭者、20 层蚀骨·掠夺者、30 层化形·透支者（XTianqiFamineAlien）。
##
## 开关 ENABLED（false＝饥荒线一概不出：选线里不能选、开场和楼层节点都不跑、使徒不异化、序幕也不说）；只认天启篇存档，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档都不受影响。

const KEY := "famine"
const STAGE_DONE := 3

## 开关：false＝饥荒线一概不出
static var ENABLED := true


static func data() -> Dictionary:
	return XTianqiLine.data(KEY)


static func allowed(s: XState = null) -> bool:
	return XTianqiLine.allowed(KEY, s)


static func progress(s: XState) -> Dictionary:
	return XTianqiLine.progress(KEY, s)


static func _said(s: XState) -> Array:
	if not s.flags.tianqi.get("famine_prologue") is Array:
		s.flags.tianqi["famine_prologue"] = []
	return s.flags.tianqi["famine_prologue"]


## 三层训练场的序幕：天启篇存档第一次到（不分线）说 prologue；饥荒线通关后第一次到说 after_clear
static func prologue_beat(s: XState, map_id: int) -> String:
	if not ENABLED or not XTianqiLine.open_for(s) or map_id != XTianqiLine.map_of(KEY, str(data().get("prologue", {}).get("map", ""))):
		return ""
	var said := _said(s)
	if not said.has("prologue"):
		return "prologue"
	if allowed(s) and bool(progress(s).get("cleared", false)) and not said.has("after_clear"):
		return "after_clear"
	return ""


static func run_prologue(host, s: XState, beat: String) -> void:
	_said(s).append(beat)
	await XTianqiLine.say(host, KEY, beat)


## 楼层节点说完之后的本线小事件（XTianqiLine.run_arrival 调）：25 层传闻后的模拟考
static func after_beat(host, s: XState, beat: String) -> void:
	if beat != "rumor25" or not allowed(s):
		return
	await XTianqiLine.say(host, KEY, "quiz_offer")
	var take: int = await host.show_text_with_choices("", 0, ["要做这份模拟考吗？"], ["做", "不做"], 1)
	if take != 0:
		return
	var right := 0
	for q in data().get("quiz", {}).get("questions", []):
		var i: int = await host.show_text_with_choices("", 0, [str(q.q)], q.options, -1)
		if i == int(q.answer):
			right += 1
	progress(s)["quiz"] = right
	await host.show_text("", 0, ["答对了 %d 道。" % right])
	await XTianqiLine.say(host, KEY, "quiz_done")


static func run_shadow(host, s: XState) -> int:
	return await XTianqiLine.run_shadow(host, s, KEY)


static func run_final(host, s: XState) -> int:
	return await XTianqiLine.run_final(host, s, KEY)
