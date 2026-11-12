class_name XSvPngFd
extends RefCounted
## dsPassiveSkill SvPngFd（角色战斗立绘放大）。参照 oracle/svpng.json（mv_oracle/svpng_probe.cjs 量冻结正式源）：
##  - 备注 <SvPngFd: N>，在装备→技能→状态里依次扫，后面的覆盖前面的（不取最大）；多件时 equips 顺序里最后一件生效；
##  - v0.28 只在开战时（Scene_Battle.start：initPassiveCache→refreshPassiveCache）算一次，战斗中换装／加状态不刷新；
##    v0.51 起（跟到 v0.62.12 dsPassiveSkill refreshPassiveCache 先把 SvPngFd 复位成 1 再解析，状态／装备／技能变了置脏，下一次 refresh 重建；
##    Sprite_Actor.updateFrame 每帧读缓存）战斗中加状态、换装后跟着变。开关 REFRESH_V051（O-291）：
##    true＝战斗图每帧看装备／状态／技能有没有变，变了重算（XBattlerSprite._process）；false＝回到 v0.28 开战算一次；
##  - 放大的是角色身体（_mainSprite.scale = N），影子不放大。

static var REFRESH_V051 := true

## 装备／状态／技能的签名：变了才重算（相当于原版置脏后的下一次 refresh）
static func signature(a: XActor) -> String:
	var gear := a.equip_list().map(func(e): return str(e.get("instanceId", "")) + ":" + str(e.get("kind", "")) + str(e.get("id", e.get("base", 0))))
	return JSON.stringify([gear, a.state_ids, a.skill_ids])

static func scale(a: XActor) -> float:
	var out := 1.0
	# 技能读 skills()（原版 dsPassiveSkill 1318 行 equips.concat(this.skills(), this.states())）：带心钢／异化／谷雨／屠苏璇等包装增减的技能，不是原始 skill_ids
	var objs: Array = a.equip_list().duplicate()
	objs.append_array(a.skills())
	objs.append_array(a.states())
	for o in objs:
		var v = o.get("meta", {}).get("SvPngFd")
		if v == null:
			continue
		var m := RegEx.create_from_string("(\\d+)").search(str(v))
		if m:
			out = float(m.get_string(1))
	return out
