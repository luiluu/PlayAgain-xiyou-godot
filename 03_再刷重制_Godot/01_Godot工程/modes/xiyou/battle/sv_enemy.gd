class_name XSvEnemy
extends RefCounted
## YEP_X_AnimatedSVEnemies 的画面规则（纯函数，读敌人备注与插件参数）：脚下影子、呼吸、攻击武器图／动作。
## 参照：mv_oracle/sve_probe.cjs（oracle/sve.json）用真实 Game_Enemy／Sprite_Enemy 量过：
##  - SV 敌人（有 <Sideview Battler>）：186 个全部 <Sideview Show Shadow>、全部不呼吸（SV 默认 Enable Breathing 只在参数 2/3 时呼吸）；
##  - 非 SV 敌人：呼吸周期 2π×Breathing Speed 帧（默认 20，备注可改），横向 0.001、纵向 0.02；影子不画；
##  - <Sideview No Collapse> 实测没有效果（MOG_CollapseEffects 默认死亡效果 0 接管 updateCollapse，SV／非 SV 同样 ~75 帧透明），所以不实现；
##  - 武器：第一条 <Sideview Weapon: 武器号, 动作, 动画>；武器号 0 → 不画武器图、动作取 Attack Motion（thrust）。

static func _meta(e: XEnemy) -> Dictionary:
	var out := {}
	var m: Dictionary = e.data().get("meta", {})
	for k in m:
		out[str(k).to_lower()] = m[k]
	return out


static func _param(name: String, fallback := "") -> String:
	return str(XDB.plugin("YEP_X_AnimatedSVEnemies").get(name, fallback)).strip_edges()


static func _num(v, fallback: float) -> float:
	var s := str(v).strip_edges()
	return float(s) if s.is_valid_float() else fallback


static func is_sv(e: XEnemy) -> bool:
	return _meta(e).has("sideview battler")


## 脚下影子：只有 SV 敌人，<Sideview Show Shadow>／<Sideview Hide Shadow> 覆盖参数 Show Shadow
static func shadow(e: XEnemy) -> bool:
	if not is_sv(e):
		return false
	var m := _meta(e)
	var on := _param("Show Shadow", "false") == "true"
	if m.has("sideview show shadow"):
		on = true
	elif m.has("sideview hide shadow"):
		on = false
	return on


## 呼吸：{on, speed(帧), rx, ry}
static func breathing(e: XEnemy) -> Dictionary:
	var m := _meta(e)
	var mode := int(_num(_param("Enable Breathing", "1"), 1))
	var on := (mode == 2 or mode == 3) if is_sv(e) else (mode == 1 or mode == 3)
	if m.has("breathing"):
		on = true
	if m.has("no breathing"):
		on = false
	var speed := maxf(1.0, _num(m.get("breathing speed"), _num(_param("Breathing Speed", "20"), 20.0)))
	var rx := maxf(0.0, _num(m.get("breathing rate x"), _num(_param("Breathing X Rate", "0.001"), 0.001)))
	var ry := maxf(0.0, _num(m.get("breathing rate y"), _num(_param("Breathing Y Rate", "0.02"), 0.02)))
	return {"on": on, "speed": speed, "rx": rx, "ry": ry}


## 攻击表现：{motion, image}。非 SV 敌人没有动作（空串）；武器号 0 时动作取参数 Attack Motion（备注 <Sideview Attack Motion>）
static func attack_visual(e: XEnemy) -> Dictionary:
	if not is_sv(e):
		return {"motion": "", "image": 0}
	var m := _meta(e)
	var id := int(_num(_param("Weapon Image Index", "0"), 0))
	var motion := _param("Weapon %d Motion" % id, "swing").to_lower()
	var w = m.get("sideview weapon")
	if w != null:
		var parts := str(w).split(",")
		id = int(_num(parts[0], 0))
		motion = parts[1].strip_edges().to_lower() if parts.size() > 1 else _param("Weapon %d Motion" % id, "swing").to_lower()
	if id <= 0:
		var base := str(m.get("sideview attack motion", _param("Attack Motion", "thrust"))).strip_edges().to_lower()
		return {"motion": base, "image": 0}
	return {"motion": motion, "image": id}
