class_name XSvPngFd
extends RefCounted
## dsPassiveSkill SvPngFd（角色战斗立绘放大）。参照 oracle/svpng.json（mv_oracle/svpng_probe.cjs 量冻结正式源）：
##  - 备注 <SvPngFd: N>，在装备→技能→状态里依次扫，后面的覆盖前面的（不取最大）；多件时 equips 顺序里最后一件生效；
##  - 只在开战时（Scene_Battle.start：initPassiveCache→refreshPassiveCache）算一次，战斗中换装／加状态不刷新；
##  - 放大的是角色身体（_mainSprite.scale = N），影子不放大。

static func scale(a: XActor) -> float:
	var out := 1.0
	var objs: Array = a.equip_list().duplicate()
	for sid in a.skill_ids:
		objs.append(XDB.rec("Skills", int(sid)))
	objs.append_array(a.states())
	for o in objs:
		var v = o.get("meta", {}).get("SvPngFd")
		if v == null:
			continue
		var m := RegEx.create_from_string("(\\d+)").search(str(v))
		if m:
			out = float(m.get_string(1))
	return out
