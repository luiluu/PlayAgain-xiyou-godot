extends "res://tests/xiyou_battle_actor_size.gd"
## 【cc·未经审查】T206 米拉黑龙「待机像吃异常」：YEP_BattleEngineCore／YEP_X_VisualStateFX Sprite_Actor.refreshMotion 第一条
## 「输入中或行动中 → idleMotion（walk）」排在濒死之前（XBattlerSprite.INPUT_WALK）。
## - dragon.*：黑龙生命 < 1/4 轮到输入时播 walk（UserSV_MiraDragon0_x），不是濒死 14_0；不轮到时照 MV 播濒死；满血不轮到时 walk；
##   轮到但不是输入（行动演出）且下的是防御指令时照旧防御；回退 INPUT_WALK = false 输入中也趴濒死（修前）。
## - human.*：米拉人形（Codex_Mira_SV_u2）同一条规则，换图不变。
## - xiyou.*：西游档角色（狗逍遥 1）同一条规则；回退照原先。
## 窗口模式加 -- --out=<目录> 存修前／修后原尺寸截图。


func _run() -> void:
	if _windowed():
		get_window().size = Vector2i(1280, 720)
		await _frames(5)
		DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 1
	XSave.dir_override = "user://test_xiyou_mira_dragon_idle"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XEnemy.force_roll = 100.0
	var keep_s: float = XBattleLayout.ACTOR_SIZE
	XBattleLayout.ACTOR_SIZE = 1.6
	XMira.ART = true
	XMira.DRAGON_ART = true
	XMira.LIFT_ART = false
	await _dragon()
	await _human()
	await _xiyou()
	XBattleLayout.ACTOR_SIZE = keep_s
	XMira.LIFT_ART = true
	XBattlerSprite.INPUT_WALK = true
	_finish()


func _prep_mira(dragon: bool) -> Callable:
	return func(s: XState):
		s.switches[2494] = true
		s.actor_advance[XMira.ACTOR] = 3
		var m := s.actor(XMira.ACTOR)
		m.learn_skill(10161)
		if dragon:
			m.state_ids.append(XMira.DRAGON)


func _sprite_of(b: XBattleScene, id: int) -> XBattlerSprite:
	for a in b.logic.actors:
		if int(a.actor_id) == id:
			return b.sprites[a]
	return null


func _settle(sp: XBattlerSprite) -> void:
	sp.refresh_idle()
	await _frames(3)


func _tex(sp: XBattlerSprite) -> String:
	var t = (sp.sprite as Sprite2D).texture
	return str(t.resource_path) if t else ""


func _dragon() -> void:
	var b := await _battle(BOSS_TROOP, [168], _prep_mira(true))
	var sp := _sprite_of(b, 168)
	var a: XActor = sp.battler
	b.logic._state_add(a, XMira.DRAGON)
	await _until(func(): return str(sp._look_key).contains("MiraDragon"), 60)
	a.hp = a.mhp
	_check("dragon.inputting", b._active == a and b.inputting, [b._active, b.inputting])
	# 满血：解放后上限 ×2，回满后 rate 1
	b._active = null
	await _frames(3)
	await _settle(sp)
	_check("dragon.full_idle_walk", sp.motion == "walk" and _tex(sp).contains("UserSV_MiraDragon0_"), [sp.motion, _tex(sp), a.hp, a.mhp])
	# 生命 12%（T197 样张的读数）
	a.hp = floorf(a.mhp * 0.12)
	await _settle(sp)
	_check("dragon.low_not_active_dying", sp.motion == "dying" and _tex(sp).ends_with("UserSV_MiraDragon14_0.png"), [sp.motion, _tex(sp)])
	b._active = a
	await _frames(3)
	_check("dragon.low_input_walk", sp.motion == "walk" and _tex(sp).contains("UserSV_MiraDragon0_"), [sp.motion, _tex(sp)])
	b._refresh_status(false)
	await _shot("修后_黑龙生命12%_输入中", "T206 修后 · 黑龙生命 12% · 轮到输入 → walk（0 号）")
	a.hp = a.mhp  # 防御指令行动中（不算 acting）：照旧防御，不强制 walk
	b.inputting = false
	a.guarding = true
	await _settle(sp)
	_check("dragon.guard_action_guard", sp.motion == "guard", sp.motion)
	a.guarding = false
	b.inputting = true
	a.hp = floorf(a.mhp * 0.12)
	await _settle(sp)
	XBattlerSprite.INPUT_WALK = false
	await _frames(3)
	_check("rollback.dragon_input_dying", sp.motion == "dying" and _tex(sp).ends_with("UserSV_MiraDragon14_0.png"), [sp.motion, _tex(sp)])
	b._refresh_status(false)
	await _shot("修前_黑龙生命12%_输入中", "T206 修前 · 黑龙生命 12% · 轮到输入 → 濒死（14 号）")
	XBattlerSprite.INPUT_WALK = true
	await _frames(3)
	_check("dragon.switch_back_walk", sp.motion == "walk", sp.motion)
	a.hp = a.mhp
	await _settle(sp)
	b._refresh_status(false)
	await _shot("修后_黑龙满血_输入中", "T206 修后 · 黑龙满血 · 轮到输入 → walk（0 号）")
	await _close(b)


func _human() -> void:
	var b := await _battle(BOSS_TROOP, [168], _prep_mira(false))
	var sp := _sprite_of(b, 168)
	var a: XActor = sp.battler
	a.hp = a.mhp
	_check("human.key", sp._look_key.contains("MiraHuman_u2"), sp._look_key)
	a.hp = floorf(a.mhp * 0.12)
	await _settle(sp)
	_check("human.low_input_walk", b._active == a and sp.motion == "walk" and _tex(sp).contains("Codex_Mira_SV_u2"), [sp.motion, _tex(sp)])
	b._active = null
	await _frames(3)
	_check("human.low_not_active_dying", sp.motion == "dying", sp.motion)
	await _close(b)


func _xiyou() -> void:
	var b := await _battle(BOSS_TROOP, [1], Callable())
	var sp := _sprite_of(b, 1)
	var a: XActor = sp.battler
	a.hp = floorf(a.mhp * 0.12)
	await _settle(sp)
	_check("xiyou.low_input_walk", b._active == a and sp.motion == "walk", sp.motion)
	XBattlerSprite.INPUT_WALK = false
	await _frames(3)
	_check("rollback.xiyou_input_dying", sp.motion == "dying", sp.motion)
	XBattlerSprite.INPUT_WALK = true
	b._active = null
	await _frames(3)
	_check("xiyou.low_not_active_dying", sp.motion == "dying", sp.motion)
	a.hp = a.mhp
	await _settle(sp)
	_check("xiyou.full_walk", sp.motion == "walk", sp.motion)
	await _close(b)
