extends "res://tests/xiyou_battle_actor_size.gd"
## 【cc·天启篇】T197：大型变身（米拉黑龙、渡鸦神话）BIG_FORM_H＝200 试样（队伍栏展开／收起 × 首领战／小怪战，另出变身角色头顶宝石入镜张）。
## 按 XBattleLayout.BIG_FORM_H＝200 各出首领战、小怪战原尺寸截图（队伍、站位、敌群与 T188 _big_forms 一致），
## 并记录每档是否压右上队伍栏、是否叠队友、是否出屏（只记录不断言：这是给 Kyo 挑的样张，不是验收）。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_big_form_sizes.tscn -- --out=<目录>
const HEIGHTS := [200.0]


func _run() -> void:
	if _windowed():
		get_window().size = Vector2i(1280, 720)
		await _frames(5)
		DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 1
	XSave.dir_override = "user://test_xiyou_big_form_sizes"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XConfig.set_party_formation(XPartyFormation.ROWS)
	XEnemy.force_roll = 100.0
	var keep_h: float = XBattleLayout.BIG_FORM_H
	var keep_s: float = XBattleLayout.ACTOR_SIZE
	XBattleLayout.ACTOR_SIZE = 1.6
	var report := []
	for h in HEIGHTS:
		XBattleLayout.BIG_FORM_H = h
		for troop in [MOB_TROOP, BOSS_TROOP]:
			for fold_open in [true, false]:
				var b := await _battle(troop, [1, 11, 167, 168], func(s: XState):
					s.switches[2494] = true
					s.raven["myth"] = 3
					s.actor_advance[XMira.ACTOR] = 3
					var m := s.actor(XMira.ACTOR)
					m.learn_skill(10161)
					m.state_ids.append(XMira.DRAGON))
				var by := {}
				for a in b.logic.actors:
					by[a.actor_id] = b.sprites[a]
				var mira: XBattlerSprite = by[168]
				b.logic._state_add(mira.battler, XMira.DRAGON)
				await _until(func(): return str(mira._look_key).contains("MiraDragon"), 60)
				await _frames(5)
				b.party_fold.set_expanded(fold_open, false)
				await _secs(1.0)
				var pr := b.party_rect()
				var panel := Rect2(pr.position - b._origin, pr.size)
				var row := {"h": h, "troop": ("首领战" if troop == BOSS_TROOP else "小怪战"), "fold": "展开" if fold_open else "收起", "cmd": [], "actors": []}
				var hit_panel := []
				var overlap := []
				var off := []
				var ids := by.keys()
				for id in ids:
					var sp: XBattlerSprite = by[id]
					var r := _body(sp)
					row.actors.append({"id": id, "screen_h": snappedf(_screen_h(sp), 0.1), "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
					if r.grow(-6.0).intersects(panel):
						hit_panel.append(id)
					if r.position.y < 0.0 or r.position.x < 0.0 or r.end.x > XBattleScene.BOX.x:
						off.append(id)
					for j in ids:
						if int(j) > int(id) and r.grow(-6.0).intersects(_body(by[j]).grow(-6.0)):
							overlap.append([id, j])
				row["panel"] = [panel.position.x, panel.position.y, panel.size.x, panel.size.y]
				row["hit_panel"] = hit_panel
				row["overlap"] = overlap
				row["off_screen"] = off
				report.append(row)
				await _shot("样张_%d_%s_%s" % [int(h), row.troop, row.fold], "BIG_FORM_H＝%d · %s · 队伍栏%s" % [int(h), row.troop, row.fold])
				var cw: Control = b.cmd_win
				if cw != null and is_instance_valid(cw):
					var cr := cw.get_global_rect()
					row["cmd"] = [cr.position.x, cr.position.y, cr.size.x, cr.size.y]
				if troop == BOSS_TROOP:
					for id in [167, 168]:
						var sp2: XBattlerSprite = by[id]
						var gr: Rect2 = XTurnMarker.gem_rect(b.turn_marker.anchor_for(sp2.battler))
						row["gem_%d" % id] = {"rect": [gr.position.x, gr.position.y, gr.size.x, gr.size.y], "off": gr.position.y < 0.0 or gr.position.x < 0.0 or gr.end.x > XBattleScene.BOX.x, "in_panel": gr.intersects(panel)}
						cw.hide()
						cw.active = false
						b.turn_marker.set_target(sp2.battler)
						await _secs(1.2)
						await _shot("样张_%d_%s_%s_头顶宝石_%d" % [int(h), row.troop, row.fold, id], "头顶宝石 · %d · 队伍栏%s" % [id, row.fold])
				await _close(b)
	XBattleLayout.BIG_FORM_H = keep_h
	XBattleLayout.ACTOR_SIZE = keep_s
	if _windowed():
		var f := FileAccess.open(out_dir.path_join("样张记录.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	for row in report:
		print("ROW ", JSON.stringify(row))
	_finish()

