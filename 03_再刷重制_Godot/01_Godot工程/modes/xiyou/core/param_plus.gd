class_name XParamPlus
extends RefCounted
## 事件指令 317（更改能力值）的永久加成：Game_Actor.addParam → _paramPlus[能力编号] += 值。
## 存档 XState.mv_param_plus {"角色ID": [8 项]}（旧档没有为空）；XActor._param_plus 读 bonus（和装备同层，保留小数）。
## 沙僧的「永久加算」复用这里，不另起一套。


static func add(s: XState, actor_id: int, param_id: int, value: float) -> void:
	if param_id < 0 or param_id > 7:
		return
	var key := str(actor_id)
	var row: Array = s.mv_param_plus.get(key, [0, 0, 0, 0, 0, 0, 0, 0])
	row[param_id] = float(row[param_id]) + value
	s.mv_param_plus[key] = row
	# addParam 最后 refresh；不为尚未实例化的角色额外建对象。
	var a: XActor = s.actors.get(actor_id)
	if a != null:
		a.param_mark_dirty()
		a.release_to_party()
		a.refresh_passive()
		a.refresh_resources()


static func bonus(a: XActor, i: int) -> float:
	var s := XState.current
	if s == null or i < 0 or i >= 8:
		return 0.0
	var row = s.mv_param_plus.get(str(a.actor_id))
	return float(row[i]) if row is Array and row.size() > i else 0.0
