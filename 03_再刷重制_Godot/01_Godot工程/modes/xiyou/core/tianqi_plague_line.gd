class_name XTianqiPlagueLine
extends RefCounted
## 【cc·天启篇·未经审查】瘟疫线（混子）的关卡流程、事件和对话（四线剧情与关卡设计稿 v0.4 第 4.4、5.1、5.5、5.7、9.2 节）。
## 台词、地点、敌群、异化数值都在 tianqi_data/plague_line.json（只读）。和线无关的流程（进度、门、开场、使徒、15／25 层、35／36 层）走 XTianqiLine；
## 这里只放瘟疫线自己的：25 层传闻之后的可选小事件「混子之盾的碎片」（捡了记 flags.tianqi.plague.shard，36 层决战打碎盾要的累计伤害降低）。
## 开场三节：1「异兆」大厅漩涡飘出绿雾 → 七层猪猪农场，侵染·毒腺的野猪头目（教病灶和病弱）；2「蔓延」农场深处，蚀骨·混乱者的「指挥官」拉布；
## 3「天外裂」天外天，瘟疫骑士生存战（XTianqiHorsemen 的 survival：开场即疫病、嘲讽常驻）。
## 使徒：10 层侵染·毒腺、20 层蚀骨·挑衅者、30 层化形·疫源（XTianqiPlagueAlien）。
##
## 开关 ENABLED（false＝瘟疫线一概不出：选线里不能选、开场和楼层节点都不跑、使徒不异化）；只认天启篇存档，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档都不受影响。

const KEY := "plague"
const STAGE_DONE := 3

## 开关：false＝瘟疫线一概不出
static var ENABLED := true


static func data() -> Dictionary:
	return XTianqiLine.data(KEY)


static func allowed(s: XState = null) -> bool:
	return XTianqiLine.allowed(KEY, s)


static func progress(s: XState) -> Dictionary:
	return XTianqiLine.progress(KEY, s)


## 楼层节点说完之后的本线小事件（XTianqiLine.run_arrival 调）：25 层传闻后捡盾碎片
static func after_beat(host, s: XState, beat: String) -> void:
	if beat != "rumor25" or not allowed(s):
		return
	await XTianqiLine.say(host, KEY, "shard_offer")
	var take: int = await host.show_text_with_choices("", 0, ["要捡起来吗？"], ["捡", "不捡"], 1)
	if take != 0:
		return
	progress(s)["shard"] = true
	await XTianqiLine.say(host, KEY, "shard_take")


## 36 层混子之盾碎掉要的累计伤害倍率（XTianqiHorsemen._shield_hit）：捡了碎片 ×(1－down)
static func shield_need_mult(s: XState = null) -> float:
	if s == null:
		s = XState.current
	if s == null or not allowed(s) or not bool(progress(s).get("shard", false)):
		return 1.0
	return 1.0 - float(data().get("shard", {}).get("down", 0.0))


static func run_shadow(host, s: XState) -> int:
	return await XTianqiLine.run_shadow(host, s, KEY)


static func run_final(host, s: XState) -> int:
	return await XTianqiLine.run_final(host, s, KEY)
