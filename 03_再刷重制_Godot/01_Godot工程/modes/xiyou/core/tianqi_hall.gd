class_name XTianqiHall
extends RefCounted
## 【cc·天启篇·未经审查】天启篇大厅 NPC 清理（T079，D138 Kyo 11-16；清单 私密仓 协作交接/T078_大厅NPC清单.md）。
## 只认天启篇存档（XTianqi.active），西游档原样；不改 generated 原数据，全是运行时：
## - 删：DELETED 里的事件在天启篇整件不出（挂点 MVEvent._is_hidden_event）。天启篇没有旧档，不做迁移／清理（D138）。
## - 并：MERGED 里的事件（源）在天启篇也不出，改由宿主（HOSTS）开口时多一层选单：「宿主原来的事」＋各源的条目＋「离开」。
##   选了源，就按源事件自己此刻成立的那一页原样跑（事件号仍是源的，独立开关、冷却变量、费用、已领记录全照旧），
##   源那一页不成立（领完了、条件不够）或被别的模块下架（O-410 洪荒、包甲教派页等）就不列；一个源都不列时宿主照原样跑。
## - 破阵·投影 EV041 的强者／超强者名单挪到改版向导 EV071（名字框换成改版向导）；灭世／洪荒切难度与灭世福利不迁
##   （天启篇五档都借原版难度 3，2489 不开，这几页本来就出不来；协调 11-17 同意，D173 待 Kyo）。
## - 七印祭坛入口 EV048：原版那页是天顶剑合成提示（天启篇删了天顶剑），没有一印揭开时不出；揭开后照 XTianqiQiyin 当祭坛入口。
## - 治愈辅 5978：唯一的学习入口是 EV057（全工程只此一处），EV057 删了，天启篇里学不到、也就不生效。五只猫（110～114）的数据不动。
## 回退开关 ENABLED（O-待定）：false 回到清理前（大厅照原样，各事件按原条件出现）。

static var ENABLED := true

const MAP := 4
## 删（D138）：3／16／35 包甲、乙已下架，这里一并列上，回退时只回本卡
const DELETED := [3, 16, 35, 41, 46, 47, 51, 52, 53, 55, 57, 67, 68]
## 并：源 → 宿主（19→15、65→54、66→27 的宿主本身不接：15 原版最后一页无条件空页、整件从不出现；
## 65、66 在 O-410 已下架、仙道模式已并进 54；27 是踩上去就传送的门，不弹选单）
const MERGED := {
	5: 6, 10: 6,
	9: 1, 11: 1, 26: 1, 42: 1, 45: 1, 58: 1, 59: 1,
	18: 17,
	19: 15,
	23: 73, 40: 73,
	24: 8,
	44: 71,
	50: 60,
	65: 54,
	66: 27,
}
## 弹合并选单的宿主：事件号 → [脸图, 脸号, 开场白, 宿主自己那一项]
const HOSTS := {
	1: ["Evil1", 6, "\\n<奥尔夫尼>聊两句，还是来领东西？", "聊聊"],
	6: ["People12", 1, "\\n<阿卡拉>要买东西，还是要歇一歇？", "买东西／治疗"],
	8: ["People14", 6, "\\n<仓库管理员>存取东西，还是整理存档？", "仓库"],
	17: ["People5_mvt", 4, "\\n<衣橱管理员>换身衣服，还是修一修形象？", "衣橱"],
	60: ["face1", 1, "\\n<希禾>来赌一把？", "赌局"],
	71: ["People5_mvt", 7, "\\n<改版向导>想了解什么？", "玩法介绍"],
	73: ["People5_mvt", 6, "\\n<商店向导>想问哪方面？", "商店指引"],
}
## 源在宿主选单里的条目
const LABELS := {
	5: "限时免费治疗",
	10: "付费治疗",
	9: "开局补给",
	11: "强者证明的奖励",
	26: "滑稽币（十分钟一次）",
	42: "召唤符文赠礼",
	45: "武器碎片（16、22 层）",
	58: "寻宝诀下篇",
	59: "难度赠礼",
	18: "修复形象",
	24: "整理存档",
	23: "商人交易提示",
	40: "符文图鉴",
	44: "调节移动速度",
	50: "讨债人的限制与福利",
}
## 改版向导多出来的两项（原破阵·投影 EV041）
const ROSTER_LABELS := ["强者名单", "超强者名单"]
const ROSTER_WHO := ["People5_mvt", 7, "改版向导"]
const ROSTER_HOST := 71
## 源那一页一句话都不说（只发东西）时，跑完宿主补一句
const GIVEN_LINE := "收好了。"
## 七印祭坛入口（XTianqiQiyin 的大厅入口）
const ALTAR_EVENT := 48
const LEAVE := "离开"


static func on(s) -> bool:
	return ENABLED and s != null and XTianqi.active(s)


# ---- 事件隐藏（MVEvent._is_hidden_event）----

static func hides(map_id: int, event_id: int) -> bool:
	if map_id != MAP or not on(XState.current):
		return false
	if DELETED.has(event_id) or MERGED.has(event_id):
		return true
	if event_id == ALTAR_EVENT:
		return not XTianqiQiyin.intercepts(XState.current, MAP, ALTAR_EVENT)
	return false


# ---- 合并选单（XMapScene.run_event）----

## 别的模块有意下架的事件（洪荒 O-410、包甲／乙／丙、O-265 等）：合并后也不出
static func _hidden_elsewhere(event_id: int) -> bool:
	return MVEvent.removed_events.has("%d:%d" % [MAP, event_id]) or XTianqiTrim.hides(MAP, event_id) or XTianqiSect.hides(MAP, event_id)


## 源事件此刻成立的那一页（照 MVEvent._find_page，只是不看本模块的隐藏）；不成立、领完（空页）、被别处下架为空
static func source_page(host, event_id: int) -> Dictionary:
	if _hidden_elsewhere(event_id):
		return {}
	var e: MVEvent = _event(host, event_id)
	if e == null or e.erased:
		return {}
	for i in range(e.data.pages.size() - 1, -1, -1):
		if e._meets(e.data.pages[i].conditions):
			var pg: Dictionary = e.data.pages[i]
			return pg if _has_commands(pg.get("list", [])) else {}
	return {}


static func _has_commands(list: Array) -> bool:
	return list.any(func(c): return int(c.get("code", 0)) != 0)


static func _event(host, event_id: int) -> MVEvent:
	for e in host.events:
		if is_instance_valid(e) and e.event_id == event_id:
			return e
	return null


## 宿主选单的条目：[[文字, 动作]]，动作 ["host"] / ["src", 源事件号] / ["roster", "strong"|"super"] / []（离开）
static func menu(host, s, event_id: int) -> Array:
	if not on(s) or not HOSTS.has(event_id):
		return []
	var out := [[str(HOSTS[event_id][3]), ["host"]]]
	if event_id == ROSTER_HOST:
		out.append([ROSTER_LABELS[0], ["roster", "strong"]])
		out.append([ROSTER_LABELS[1], ["roster", "super"]])
	for src in MERGED:
		if int(MERGED[src]) == event_id and not source_page(host, int(src)).is_empty():
			out.append([str(LABELS.get(src, "")), ["src", int(src)]])
	if out.size() == 1:
		return []   # 一个源都没成立：宿主照原样跑
	out.append([LEAVE, []])
	return out


static func intercepts(host, s, map_id: int, event_id: int) -> bool:
	return map_id == MAP and on(s) and not menu(host, s, event_id).is_empty()


## 宿主开口：先选，再跑宿主原页／源页／名单
static func run_host(host, s, e: MVEvent) -> void:
	var opts := menu(host, s, e.event_id)
	if opts.is_empty():
		return
	var h: Array = HOSTS[e.event_id]
	var labels := opts.map(func(o): return str(o[0]))
	var i: int = await host.show_text_with_choices(str(h[0]), int(h[1]), [str(h[2])], labels, labels.size() - 1)
	if i < 0 or i >= opts.size():
		return
	var act: Array = opts[i][1]
	if act.is_empty():
		return
	match str(act[0]):
		"host":
			await _run_list(host, e.event_id, e.command_list())
		"roster":
			await _run_roster(host, s, str(act[1]))
		"src":
			var src := int(act[1])
			var list: Array = source_page(host, src).get("list", [])
			await _run_list(host, src, list)
			if not list.any(func(c): return int(c.get("code", 0)) == 101) and host.map_id == MAP:
				await host.show_text(str(h[0]), int(h[1]), ["\\n<%s>%s" % [_host_name(h), GIVEN_LINE]])
			# 大厅初步异化：源原来跑完追加的那一句（猫哥、讨债人），并过来照旧追加（每存档一次）
			if "lobby_fx" in host and host.lobby_fx != null and is_instance_valid(host.lobby_fx) and host.map_id == MAP:
				await host.lobby_fx.after_event(src)


static func _host_name(h: Array) -> String:
	var t := str(h[2])
	var a := t.find("<")
	var b := t.find(">")
	return t.substr(a + 1, b - a - 1) if a >= 0 and b > a else ""


## 照 XMapScene.run_event 跑一段指令：事件号用 event_id（独立开关、「本事件」都认它）
static func _run_list(host, event_id: int, list: Array) -> void:
	if list.is_empty():
		return
	var interp := MVInterpreter.new(host, host.map_id, event_id, list)
	if "running_event_id" in host:
		host.running_event_id = event_id
	await interp.run()
	if "running_event_id" in host:
		host.running_event_id = 0
	if "skipped_log" in host and not interp.skipped.is_empty():
		host.skipped_log.append_array(interp.skipped)


static func _run_roster(host, s, kind: String) -> void:
	var interp := MVInterpreter.new(host, host.map_id, ROSTER_HOST, [])
	var tq := XTianqiTrim.roster(kind, s)
	if not tq.is_empty():
		await MVScript._boss_roster(kind, interp, tq.ids, tq.notes, ROSTER_WHO)
	else:
		await MVScript._boss_roster(kind, interp, XState.tier_ids(["超强者"] if kind == "super" else ["强者"]), null, ROSTER_WHO)
