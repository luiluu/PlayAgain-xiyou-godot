class_name XParamPlus
extends RefCounted
## 事件指令 317（更改能力值）的永久加成：Game_Actor.addParam → _paramPlus[能力编号] += 值。
## 存档 XState.mv_param_plus {"角色ID": [8 项]}（旧档没有为空）；XActor.param_base 末尾读 bonus（和修炼加成并排，只读、不挂角色字段）。
## 沙僧的「永久加算」复用这里，不另起一套。


static func add(s: XState, actor_id: int, param_id: int, value: int) -> void:
	if param_id < 0 or param_id > 7:
		return
	var key := str(actor_id)
	var row: Array = s.mv_param_plus.get(key, [0, 0, 0, 0, 0, 0, 0, 0])
	row[param_id] = int(row[param_id]) + value
	s.mv_param_plus[key] = row


static func bonus(a: XActor, i: int) -> float:
	var s := XState.current
	if s == null or i < 0 or i >= 8:
		return 0.0
	var row = s.mv_param_plus.get(str(a.actor_id))
	return float(row[i]) if row is Array and row.size() > i else 0.0
