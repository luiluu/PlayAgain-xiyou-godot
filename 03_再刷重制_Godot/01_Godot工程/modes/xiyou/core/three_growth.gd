class_name XThreeGrowth
extends RefCounted
## 三法宝成长（正式 js/codex/runtime/installThreeGrowthRelicRuntime.js，W.CodexThreeGrowth v0.4.0 的 R.syncItem；参照 three_growth_probe）：
## 所属人物 60 级时法宝进化——每级成长由 18（定位四项 36）改为 36（72）、改名、说明换成进化后的那句；进化一次后不退
## （_codex60Evolved，人物再降回 60 级以下也不变）。未进化时说明也改成「法宝」＋第一句。
## 原版在 changeLevel／levelUp／changeEquip／startBattle／读档／magicWeaponCustomParam 时同步；重制在算法宝能力（XActor.magic_param）时同步，
## 名字与说明跟着变。切片里只有谷雨 175 的百谷生 7912（屠苏 176 止戈环 4047、璇 177 璇玑星盘 4048 不在切片，没写）。
## 未移植：说明卡的法宝条目改写（relicLines）、传家宝品质整理（RQ.normalize，原表这些法宝本来就是品质 9）、屠苏与璇的五相／列星特效。

const SPECS := {7912: {"actor": 175, "base": "百谷生", "name": "万象长春盏", "extra": [0, 3, 5, 6],
	"desc": ["一盏盛着百谷新芽的瓷盏。", "盏中万象长春，生生不息。"]}}


## R.syncItem：返回这件法宝现在的每级成长（不归这里管返回空）
static func sync_item(e: Dictionary) -> Array:
	var spec: Dictionary = SPECS.get(int(e.get("base", e.get("id", 0))), {})
	if spec.is_empty() or str(e.get("kind", "armor")) != "armor":
		return []
	var s := XState.current
	var a = s.actors.get(int(spec.actor)) if s != null else null
	var evolved := bool(e.get("_codex60Evolved", false)) or (a != null and int(a.level) >= 60)
	var unit := 36 if evolved else 18
	var per := []
	for i in 8:
		per.append(unit * (2 if (spec.extra as Array).has(i) else 1))
	var name: String = spec.name if evolved else spec.base
	var original := str(e.get("baseItemName", e.get("name", spec.base)))
	var now := str(e.get("name", spec.base)).replace(original, name)
	if now == original or now in [spec.base, spec.name]:
		now = name
	e["name"] = now
	e["baseItemName"] = name
	e["paramPlusPerLevel"] = per
	e["description"] = "法宝\n" + str(spec.desc[1 if evolved else 0])
	if evolved:
		e["_codex60Evolved"] = true
	return per
