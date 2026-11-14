class_name XTraining
extends RefCounted
## 修炼（Star_ActorAttributePlusPoints）的数据部分；界面在 ui/training_scene.gd。
## - 修炼表 PoLites：插件参数「AttributePlusPoints 1～100」，第 N 项编号 N−1：{name, max 满级, gold 每级精魂, param 能力编号 0～7, value 每级加值}。
## - 入口事件先设 Star.ActorAttributePlusPoints.XiuLian（本次列出的表编号，全局、不存档；没设过时为 0～7），再 SceneManager.push。
## - 存档：原版每名角色 actor.pushattribute[表编号] = [等级, 累计加值, 能力编号]。表固定，累计加值＝等级×每级加值、能力编号＝表里的编号，
##   所以这里只存等级 XState.training {"角色ID": {"表编号": 等级}}；param_bonus 照原版 paramBaseBoost 加在 paramBase 上（被动之后、比率之前）。
## - 修炼（onConfirmOk）：等级 < 满级且精魂 ≥ 费用 → 等级＋1、扣精魂、提示「修炼成功」；否则满级提示「等级已满」、精魂不够提示「精魂不足」。
## 天启篇存档（XTianqiMoney.training_on，金钱重构 v0.2）：原表不用，换成八项各 10 级、全队共享、每 3 层开 1 级，
## 价钱和加值都在 XTianqiMoney；界面照用这一页（列出八项，选哪名角色都一样）。

const PARAM_NAMES := ["最大生命", "最大魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]
const DEFAULT_LIST := [0, 1, 2, 3, 4, 5, 6, 7]

## Star.ActorAttributePlusPoints.XiuLian（入口事件脚本设，界面读）
static var xiulian: Array = DEFAULT_LIST.duplicate()
static var _table := {}


static func table() -> Dictionary:
	if _table.is_empty():
		var p := XDB.plugin("Star_ActorAttributePlusPoints")
		for i in range(1, 101):
			var raw := str(p.get("AttributePlusPoints %d" % i, ""))
			var d = JSON.parse_string(raw) if raw != "" else null
			if d is Dictionary:
				_table[i - 1] = {"id": i - 1, "name": str(d.get("AttributePlusPointsName", "")),
					"max": int(str(d.get("AttributePlusPointsMaXNum", "0"))), "gold": int(str(d.get("AttributePlusPointsGold", "0"))),
					"param": int(str(d.get("AttributePlusPointsID", "0"))), "value": int(str(d.get("AttributePlusPointsV", "0")))}
	return _table


static func entry(id: int) -> Dictionary:
	return table().get(id, {})


## 本次列出的表项（原版 makeCommandList 按表编号从小到大，只列 XiuLian 里有的）
static func listed() -> Array:
	if XTianqiMoney.training_on():
		return tianqi_entries()
	var out := []
	for id in range(0, 101):
		if xiulian.has(id) and table().has(id):
			out.append(table()[id])
	return out


## 天启篇修炼的八项（id＝能力编号，max＝10）
static func tianqi_entries() -> Array:
	var out := []
	for i in 8:
		out.append({"id": i, "name": PARAM_NAMES[i] + "修炼", "max": XTianqiMoney.training_levels(), "param": i, "value": 0, "tianqi": true})
	return out


static func level(s: XState, actor_id: int, id: int) -> int:
	if XTianqiMoney.training_on(s):
		return XTianqiMoney.training_level(s, id)
	return int(s.training.get(str(actor_id), {}).get(str(id), 0))


## paramBaseBoost 里修炼那一份：该角色全部表项 等级×每级加值 中能力编号为 i 的和。XActor.param_base 末尾读它；
## 只读、不写状态，按 actor_id 从 XState.current 取（不在角色上挂字段，公式影子克隆照样可用），没有修炼数据时为 0
static func param_bonus(a: XActor, i: int) -> float:
	var s := XState.current
	if s == null or i >= 8:
		return 0.0
	if XTianqiMoney.training_on(s):
		return XTianqiMoney.training_bonus(a, i)
	var v := 0.0
	var mine: Dictionary = s.training.get(str(a.actor_id), {})
	for k in mine:
		var e := entry(int(k))
		if not e.is_empty() and int(e.param) == i:
			v += float(int(mine[k]) * int(e.value))
	return v


## 指令行文（Window_AddLittleConfirm.makeCommandList；空格照原版按能力编号补齐）
static func line(s: XState, actor_id: int, e: Dictionary) -> String:
	if e.get("tianqi", false):
		return tianqi_line(s, e)
	var lv := level(s, actor_id, int(e.id))
	if lv == int(e.max):
		return "%s %d/%d 等级已满" % [e.name, lv, e.max]
	var pid := int(e.param)
	var space := "       "
	if pid == 0 or pid == 1:
		space = "     "
	elif pid == 2 or pid == 4:
		space = "         "
	elif pid == 6 or pid == 7:
		space = "              "
	return "%s  %d/%d 增加%s%d%s下一级费用%sw" % [e.name, lv, e.max, PARAM_NAMES[pid], e.value, space, _wan(int(e.gold))]


## 天启篇一行：名字 等级/满级 每级＋1%（全队）　下一级费用 Nw；没开放到的写开放到几级
static func tianqi_line(s: XState, e: Dictionary) -> String:
	var lv := XTianqiMoney.training_level(s, int(e.id))
	if lv >= int(e.max):
		return "%s %d/%d 等级已满" % [e.name, lv, e.max]
	var pct := roundi(float(XTianqiMoney.data().get("training", {}).get("pct_per_level", 0.01)) * 100.0)
	var open := XTianqiMoney.training_open(s)
	var tail := "本层开到 %d 级" % open if lv >= open else _wan(XTianqiMoney.training_price(s, lv + 1)) + "w"
	return "%s  %d/%d 全队%s+%d%%  下一级费用 %s" % [e.name, lv, e.max, PARAM_NAMES[int(e.param)], pct, tail]


## 原版 Gold / 10000 直接接字符串（JS 数字转文字）：整除时不带小数
static func _wan(gold: int) -> String:
	if gold % 10000 == 0:
		return str(gold / 10000)
	return str(float(gold) / 10000.0)


static func lines(s: XState, actor_id: int) -> Array:
	return listed().map(func(e): return line(s, actor_id, e))


## onConfirmOk：返回提示文字（成功、等级已满、精魂不足；都不满足时原版不提示，返回空）
static func confirm(s: XState, actor_id: int, id: int) -> String:
	if XTianqiMoney.training_on(s):
		return XTianqiMoney.train(s, id)
	var e := entry(id)
	if e.is_empty():
		return ""
	var lv := level(s, actor_id, id)
	if lv < int(e.max) and s.gold >= int(e.gold):
		var mine: Dictionary = s.training.get(str(actor_id), {})
		mine[str(id)] = lv + 1
		s.training[str(actor_id)] = mine
		s.gain_gold(-int(e.gold))  # loseGold
		return "修炼成功"
	if lv == int(e.max):
		return "等级已满"
	if s.gold < int(e.gold):
		return XDB.system().get("currencyUnit", "") + "不足"
	return ""
