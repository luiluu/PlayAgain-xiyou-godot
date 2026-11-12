class_name XTianqiWarLine
extends RefCounted
## 【cc·天启篇·未经审查】战争线（莉co）的关卡流程、事件和对话（四线剧情与关卡设计稿 v0.4 第 2、4.2、5.1、5.7、9.1 节）。
## 台词、地点、敌群、异化数值都在 tianqi_data/war_line.json（只读）。
##
## 流程（存档 flags.tianqi.war = {stage, seen, survived, cleared}）：
## - 选线：通关 5 层回大厅、抽完角色后，小小鱼在方桌主持选线（XTianqi.run_line_choice）；选了战争线就接着跑本线开场。
## - 开场三节（stage 0→3）：选定后接着跑；输了回大厅，之后走大厅的门（去 6 层的那扇）就从输的那一节接着打：
##   1「异兆」大厅时空漩涡 → 六层哥布林部族：侵染·战狂的火焰哥布林，教火花；
##   2「蔓延」部族深处：节末精英蚀骨·战意「巨棒」帕斯诺夫；打完天上出现扔炸弹的小身影；
##   3「天外裂」天外天（新图做好前借 158）：战争骑士生存战（XTianqiHorsemen 的 survival，撑过 6 回合；输了剧情照走，记 survived）。
##   打完回大厅，6 层的门打开（没选线或开场没打完时大厅的门不放人去 6 层，XTianqi.door_blocked）。
## - 楼层节点：10、20、30 层守层者开战前骑士的声音，守层者变成使徒（固定战意／号令官／烟火师，XTianqiWarAlien）；
##   15 层黑暗废墟「原身的回声」、25 层上行天「另外三位的传闻」：第一次到这张图时小小鱼和旁白说一次。
## - 35 层影子（run_shadow）、36 层决战与结局（run_final）：流程和战斗都做了，但 31～36 层还没重做（门上限 34、没有 35／36 层的图），
##   地图上还没有入口，先由测试和以后的 36 层事件调。
##
## 和线无关的流程（进度、门、台词、开场、楼层节点、35／36 层）在 XTianqiLine（四线共用，cc 饥荒线车道抽出）；这里只留战争线的开关和
## 原来的调用名（都转给 XTianqiLine），地图场景改调 XTianqiLine。
##
## 开关 ENABLED（false＝战争线一概不出：选线里不能选、开场和楼层节点都不跑、使徒不异化）；只认天启篇存档且这一档选了战争线，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档、别的线都不受影响。

const PATH := "res://modes/xiyou/tianqi_data/war_line.json"
const KEY := "war"
const STAGE_DONE := 3

## 开关：false＝战争线一概不出
static var ENABLED := true


static func data() -> Dictionary:
	return XTianqiLine.data(KEY)


static func reload() -> void:
	XTianqiLine.reload(KEY)


static func nice_number_violations() -> Array:
	return XTianqiLine.nice_number_violations(KEY)


static func open_for(s: XState) -> bool:
	return ENABLED and XTianqiLine.open_for(s)


static func allowed(s: XState = null) -> bool:
	return XTianqiLine.allowed(KEY, s)


static func progress(s: XState) -> Dictionary:
	return XTianqiLine.progress(KEY, s)


static func stage(s: XState) -> int:
	return XTianqiLine.stage(KEY, s)


static func opening_done(s: XState) -> bool:
	return XTianqiLine.opening_done(KEY, s)


static func due(s: XState) -> bool:
	return XTianqiLine.due(KEY, s)


static func scene(key: String) -> Array:
	return XTianqiLine.scene(KEY, key)


static func line_text(row: Array) -> String:
	return XTianqiLine.line_text(row)


static func say(host, key: String) -> void:
	await XTianqiLine.say(host, KEY, key)


static func on_chosen(host) -> void:
	await say(host, "choose")


static func run_due(host, s: XState) -> void:
	await XTianqiLine.run_due(host, s, KEY)


static func door_blocked(s: XState) -> bool:
	return XTianqiLine.door_blocked(s)


static func before_battle(host, s: XState, troop_id: int) -> void:
	await XTianqiLine.before_battle(host, s, troop_id)


static func arrival_beat(s: XState, map_id: int) -> String:
	return XTianqiLine.arrival_beat(s, map_id)


static func run_arrival(host, s: XState, map_id: int) -> void:
	await XTianqiLine.run_arrival(host, s, map_id)


static func is_door(map_id: int, event_id: int) -> bool:
	return XTianqiLine.is_door(map_id, event_id)


static func run_door(host, s: XState) -> bool:
	return await XTianqiLine.run_door(host, s)


static func run_shadow(host, s: XState) -> int:
	return await XTianqiLine.run_shadow(host, s, KEY)


static func run_final(host, s: XState) -> int:
	return await XTianqiLine.run_final(host, s, KEY)
