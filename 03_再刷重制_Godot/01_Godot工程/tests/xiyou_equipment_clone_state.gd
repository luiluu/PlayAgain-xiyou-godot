extends Node
## 装备预览克隆保留状态私有字段：状态 1775 五层（_stateCounter）原样克隆、原样预览、换装预览的层数与能力值。
## 原版 JsonEx 深拷贝整个角色，复制前后层数 5/5；克隆与原件互不影响。
var passed := 0
var total := 0
func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func params(a: XActor) -> Array:
	a.param_refresh()
	return range(8).map(func(i): return a.param(i))

func counter(a: XActor) -> float:
	return float(a.state_data.get("_stateCounter", {}).get("1775", 0.0))

func _ready() -> void:
	var s := XState.new_game(3, 1, [8])
	var a: XActor = s.actor(8)
	s.set_variable(1139, 5)
	a.add_state(1775)
	a.refresh_passive()
	var base := params(a)
	check("original.counter", counter(a) == 5.0, a.state_data)
	var c := XEquipment.clone(a)
	check("clone.counter", counter(c) == 5.0, c.state_data)
	check("clone.params", params(c) == base, [params(c), base])
	var slot := 0
	while slot < a.equips.size() and a.equips[slot] == null:
		slot += 1
	check("has_equip", slot < a.equips.size())
	var same := XEquipment.preview(a, slot, a.equips[slot])
	check("preview_same.counter", counter(same) == 5.0, same.state_data)
	check("preview_same.params", params(same) == base, [params(same), base])
	var bare := XEquipment.preview(a, slot, null)
	check("preview_change.counter", counter(bare) == 5.0, bare.state_data)
	# 换装预览只差装备本身：再按原样装回去，能力值回到原件
	bare.equips[slot] = a.equips[slot].duplicate(true)
	bare.refresh_passive()
	check("preview_change.restored_params", params(bare) == base, [params(bare), base])
	c.state_data["_stateCounter"]["1775"] = 1.0
	check("clone.isolated", counter(a) == 5.0 and params(a) == base, [counter(a), a.state_data])
	print("TEST_RESULT=" + JSON.stringify({"total": total, "passed": passed}))
	get_tree().quit(0 if passed == total else 1)
