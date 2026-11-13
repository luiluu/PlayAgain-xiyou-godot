class_name XRiftAlien
extends RefCounted
## 发行空壳（手写，07_开发环境/发行空壳手写/）：发行包里漩涡异化只有二阶画面——守层者幽紫一明一暗、稀有以上进场 11% 闪一下；
## 三阶起的异化（级、种类、掉落、图鉴）不进包。画面和真脚本二阶一样：分类、颜色、节奏同 rift_alien.json 的 classes／look，
## 闪不闪用同一条派生随机流、同样的取数顺序。其余钩子都是「没有异化怪」时的结果。改真脚本的二阶画面要同步改这里。

const LOOK := "xrift_look"
static var ENABLED := true
static var STAGE_OVERRIDE := 0
const _CLASSES := {"稀有": "rare", "精英": "rare", "前所未见": "very_rare", "亘古未有": "very_rare", "首领": "very_rare", "守层者": "guardian", "被封印者": "abyss", "未知存在": "abyss", "古神": "abyss"}
const _COLOR := Color(0.62, 0.35, 0.95)
const _PERIOD := 6.0
const _PULSE := 0.3
const _FLASH_RATE := 11.0
const _FLASH := 0.5
const _FADE := 1.0
static var _tag := RegEx.create_from_string("^【([^】]+)】")


static func stage() -> int:
	return clampi(STAGE_OVERRIDE, 1, 5) if STAGE_OVERRIDE > 0 else XRift.stage()


static func on(s: XState) -> bool:
	return ENABLED and s != null and not XTianqi.active(s) and stage() == 2


static func class_of(e) -> String:
	var name := str(e.data().get("name", "")) if e is XEnemy else str(e)
	var m := _tag.search(name)
	return str(_CLASSES.get(m.get_string(1), "")) if m != null else ""


static func stream(logic) -> XRandomStream:
	var seed := str(logic._rule().snapshot().get("seed", "0000000000000000"))
	return XRandomStream.create(XRandomStream.derive(seed, "rift_alien|%d" % int(logic.troop_id)), "rift_alien")


static func setup(logic, s: XState) -> void:
	end(logic)
	if not on(s):
		return
	var rng := stream(logic)
	for i in logic.enemies.size():
		var e = logic.enemies[i]
		var cls := class_of(e)
		if cls == "":
			continue
		var look := {"pulse": cls == "guardian", "flash": false, "tier": ""}
		if cls == "rare" or cls == "very_rare":
			look.flash = rng.next_float("rift_alien.flash", "%d:%d" % [i, int(e.enemy_id)]) * 100.0 < _FLASH_RATE
		e.set_meta(LOOK, look)


static func tint(e, t: float) -> Color:
	if not ENABLED or not e is XEnemy or not e.has_meta(LOOK):
		return Color(0, 0, 0, 0)
	var look: Dictionary = e.get_meta(LOOK)
	var a := 0.0
	var fx := XConfig.flag("codexScreenFx")
	if fx and bool(look.get("pulse", false)):
		a = maxf(a, _PULSE * (0.5 - 0.5 * cos(TAU * t / _PERIOD)))
	if fx and bool(look.get("flash", false)) and t < _FADE:
		a = maxf(a, _FLASH * (1.0 - t / _FADE))
	return Color(_COLOR.r, _COLOR.g, _COLOR.b, a)


static func end(logic) -> void:
	if logic == null:
		return
	for e in logic.enemies:
		if e is XEnemy and e.has_meta(LOOK):
			e.remove_meta(LOOK)


static func take_logs(logic) -> Array:
	return []


static func start_turn(logic) -> Array:
	return []


static func end_turn(logic) -> Array:
	return []


static func hp_damage(logic, u, t, value: float) -> float:
	return value


static func gain(b, resource: String, amount: float) -> float:
	return amount


static func regen(logic, b, dh: float, dm: float) -> Array:
	return [dh, dm]


static func grant(logic) -> Array:
	return []


static func gear_energy(i) -> int:
	return -1


static func gear_prefix(i) -> String:
	return ""
