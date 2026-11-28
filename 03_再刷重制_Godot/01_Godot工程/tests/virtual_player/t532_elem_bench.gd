extends "res://tests/virtual_player/t438_d271_benchmark.gd"
## 【cc·T532】防具本体元素伤合计上限 开／关 对照量数：在 T438 D271 脚手架上跑，多一个参数：
##   --t532=on|off   XTianqiGear.ARMOR_ELEM_CAP 开（默认）／关（ARMOR_FINAL 照默认关）
## 每场开打前打一行 T532_GEAR|模板|层|种子|角色号|元素|防具本体合计(未封)|封后|武器本体：只列防具本体合计 > 0 的元素里最大的那一系。
## 其余参数同 t438_d271_benchmark.gd。不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑务必带 --audio-driver Dummy、临时 HOME。

var _cur_tpl := ""


func _ready() -> void:
	var on := true
	for a in OS.get_cmdline_user_args():
		if a == "--t532=off":
			on = false
	XTianqiGear.ARMOR_ELEM_CAP = on
	print("T532_BENCH|switch=%s|final=%s" % ["on" if on else "off", str(XTianqiGear.ARMOR_FINAL)])
	super._ready()


func _build_state(tpl: String, diff: String, tinfo: Dictionary, f: int, lv: int, ln: String, sd: int) -> Dictionary:
	_cur_tpl = tpl
	return super._build_state(tpl, diff, tinfo, f, lv, ln, sd)


func _fight_floor(s: XState, f: int, ln: String, sd: int) -> Dictionary:
	XState._become_current(s)
	for a in s.battle_members():
		var views: Array = []
		var raw := {}
		var weap := {}
		for e in a.equip_list():
			var v = XTianqiGear.elem_amp_view(e)
			if not (v is Dictionary and v.get("_tq_ea_amp") is Dictionary):
				continue
			views.append(v)
			for ek in v._tq_ea_amp:
				if XTianqiGear._armor_capped_slot(v):
					raw[ek] = float(raw.get(ek, 0.0)) + float(v._tq_ea_amp[ek])
				elif XTianqiGear._kind(v) == "weapon":
					weap[ek] = float(weap.get(ek, 0.0)) + float(v._tq_ea_amp[ek])
		if raw.is_empty():
			continue
		var best := ""
		for ek in raw:
			if best == "" or float(raw[ek]) > float(raw[best]):
				best = ek
		print("T532_GEAR|%s|%d|%d|%d|%s|%.0f|%.0f|%.0f" % [_cur_tpl, f, sd, int(a.actor_id), best, float(raw[best]), minf(float(raw[best]), XTianqiGear.armor_cap_pct()), float(weap.get(best, 0.0))])
	return super._fight_floor(s, f, ln, sd)
