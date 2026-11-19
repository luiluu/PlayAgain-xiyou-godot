class_name XTianqiWeakBadges
extends Node2D
## 【cc·T230·未经审查】天启篇弱者专属词条的战斗角标（设计稿 v0.3.1 第二节第 4 条「在对应角色或敌人身上有一个文字角标」；
## Kyo 11-19：角标只写状态不写词条名，如「蓄雷 2/3」「球×2」「受邀」）。只读 XTianqiWeakAffix.badges，不改结算。
## 画在战斗者头顶（加在 BattleScene.fx 层，坐标同 field）；专属模块没开、不在天启篇档时不建。文字交小A 审。

const POLL := 0.1
const FONT_SIZE := 18

var logic
## Callable：返回 {战斗者: XBattlerSprite}
var sprites_source: Callable
## 当前显示：{战斗者: "文字"}（测试读它）
var shown := {}
var _t := 0.0


static func make(battle_logic, sprites_fn: Callable) -> XTianqiWeakBadges:
	if battle_logic == null or not XTianqiWeakAffix.on(battle_logic.state):
		return null
	var n := XTianqiWeakBadges.new()
	n.logic = battle_logic
	n.sprites_source = sprites_fn
	n.z_index = 5
	return n


func poll() -> void:
	var now := {}
	if logic != null:
		for b in logic.actors + logic.enemies:
			if b == null or b.is_dead():
				continue
			var list: Array = XTianqiWeakAffix.badges(logic, b)
			if not list.is_empty():
				now[b] = "  ".join(list)
	if now != shown:
		shown = now
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t < POLL:
		return
	_t = 0.0
	poll()
	if not shown.is_empty():
		queue_redraw()  # 跟着人走（入场、受击位移）


func _draw() -> void:
	if shown.is_empty() or not sprites_source.is_valid():
		return
	var sprites: Dictionary = sprites_source.call()
	var font := XUI.font()
	for b in shown:
		var s = sprites.get(b)
		if s == null or not is_instance_valid(s) or not s.visible:
			continue
		var text: String = shown[b]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var p: Vector2 = s.position + Vector2(-w / 2.0, -s.height() - 10.0)
		draw_rect(Rect2(p + Vector2(-6, -FONT_SIZE), Vector2(w + 12, FONT_SIZE + 8)), Color(0, 0, 0, 0.55))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.86, 0.45))
