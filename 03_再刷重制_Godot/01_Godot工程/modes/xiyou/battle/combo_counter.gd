class_name XComboCounter
extends Node2D
## MOG_ComboCounter v1.4（正式西游参数为空，全用脚本缺省值）：角色打中敌人时左上显示「N 击中」。
## - 计数（Game_Action.executeDamage，即命中且技能有伤害类型时，数值为 0 也算）：角色 → 敌人 +1；
##   敌人 → 角色 打断连击并结束「行动中」；角色对敌人未命中（apply 后 !isHit）也打断。
## - 每帧（Spriteset_Battle.update，画面在战斗者与伤害数字之上、窗口之下）：有新击中就重建数字，保持 90 帧；
##   「行动中」（startAction～endAction）不倒数；被打断立即归零；归零时计数清空。
##   归零后底图与数字每帧不透明度 −10、整体右移 1px。数字每次重建从 2 倍缩到 1 倍（每帧 −0.1）。
## - 「总伤害」层（Combo_B 与第二组数字）的坐标参数在西游版被注释掉，x 为 NaN 不显示，照做不画；
##   计数仍累计总伤害（total）。
## 坐标为原版 1280×720 画面坐标，节点放在战斗画面原点。

const HIT_LAYOUT := Vector2(118, 124)
const HIT_NUMBER := Vector2(115, 135)
const HOLD_FRAMES := 90

var hits := 0
var total := 0.0
var _fresh := false        # combo_data[0]
var _broken := false       # combo_data[3]
var acting := false        # combo_data[4]
var timer := 0             # combo_sprite_data[0]
var slide := 0             # combo_sprite_data[3]
var layout_alpha := 0      # combo_sprite_a.opacity
var digits: Array = []     # [{n, dx, scale, alpha}]
var _tex_a: Texture2D
var _tex_d: Texture2D


func _ready() -> void:
	var a := XDB.img_path("system", "Combo_A")
	var d := XDB.img_path("system", "Combo_D")
	_tex_a = load(a) if a != "" else null
	_tex_d = load(d) if d != "" else null


## BattleManager.startAction / endAction
func action_started() -> void:
	acting = true


func action_ended() -> void:
	acting = false


## Game_Action.apply 一次（含其中的 executeDamage）
func applied(user: XBattler, target: XBattler, hit: bool, damage_type: int, value: float) -> void:
	if hit and damage_type > 0:
		if user is XActor and target is XEnemy:
			_fresh = true
			hits += 1
			total += value
		elif user is XEnemy and target is XActor:
			_broken = true
			acting = false
	if user is XActor and target is XEnemy and not hit:
		_broken = true


func _physics_process(_delta: float) -> void:
	step()


## Spriteset_Battle.update_combo_sprites 一帧
func step() -> void:
	if _fresh:
		_refresh()
	if timer <= 0 and layout_alpha > 0:
		layout_alpha = maxi(0, layout_alpha - 10)
		slide += 1
	for g in digits:
		if g.scale > 1.0:
			g.scale -= 0.1
		if timer <= 0:
			g.alpha = maxi(0, g.alpha - 10)
	if timer > 0:
		if not acting:
			timer -= 1
		if _broken:
			timer = 0
		if timer == 0:
			hits = 0
			total = 0.0
			_fresh = false
			_broken = false
			acting = false
	queue_redraw()


func _refresh() -> void:
	_fresh = false
	_broken = false
	timer = HOLD_FRAMES
	layout_alpha = 255
	slide = 0
	digits.clear()
	if _tex_d == null:
		return
	var w := _tex_d.get_width() / 10.0
	var text := str(absi(hits))
	for i in range(text.length()):
		digits.append({"n": int(text[i]), "dx": i * w - text.length() * w, "scale": 2.0, "alpha": 255})


func _draw() -> void:
	if _tex_a != null and layout_alpha > 0:
		draw_texture(_tex_a, HIT_LAYOUT + Vector2(slide, 0), Color(1, 1, 1, layout_alpha / 255.0))
	if _tex_d == null:
		return
	var w := _tex_d.get_width() / 10.0
	var h := float(_tex_d.get_height())
	for g in digits:
		if g.alpha <= 0:
			continue
		var size := Vector2(w, h) * float(g.scale)
		var center := HIT_NUMBER + Vector2(slide + float(g.dx), 0)
		draw_texture_rect_region(_tex_d, Rect2(center - size / 2.0, size), Rect2(g.n * w, 0, w, h), Color(1, 1, 1, g.alpha / 255.0))
