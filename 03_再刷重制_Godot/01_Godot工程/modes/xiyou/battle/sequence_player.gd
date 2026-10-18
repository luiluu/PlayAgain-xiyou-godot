class_name XSequencePlayer
extends RefCounted
## YEP 行动序列的画面部分，逐物理帧复现正式版的行动机（读数见 ui_reference __seqRef 与 tests/fixtures/action_sequence_oracle.json）。
## 结算已由 XActionSequence 做完，这里只按它记下的 seq_phase / seq / seq_target / seq_end 与命中记录演出。
## 每帧顺序同 Scene_Battle.update：镜头（$gameScreen.update）→ 行动机（BattleManager.update，日志窗忙时跳过）
## → 战斗者精灵 → 日志窗（Window_BattleLog.update：等待计数每帧 −2，否则检查等待模式，否则执行一个排队方法）。
## - 行动机：phaseChange 一帧换段（下一帧才执行该段指令）；段内指令连续执行到返回 false 为止，段空了当帧转 phaseChange；
##   target 段换下一个目标在同一帧继续；最后一段之后再一帧 endAction。
## - 返回 false（占一帧以上）的指令照正式版各插件：DISPLAY ACTION、CLEAR BATTLE LOG、WAIT 系列、MOTION、FACE、FLOAT、
##   OPACITY、HIDE/SHOW BATTLE HUD、PERFORM ACTION、MOTION WAIT（角色）、ACTION COMMON EVENT、COMMON EVENT、EVAL，
##   以及不认识的行（注释、拆坏的备注标签）。
## - ACTION EFFECT 每个命中在日志窗排 7 个方法（状态有变化再加 3 个），一帧执行一个，期间行动机不前进。
## - 正式版 WY 插件锁死战斗者坐标：移动、前进、后退、击退只计时（WAIT FOR MOVEMENT 照等），画面不动。
## - 公共事件、变量、开关、EVAL 不在这里执行（ACTION COMMON EVENT/COMMON EVENT 只占帧）。

const MESSAGE_SPEED := 16          # Window_BattleLog.messageSpeed
const LOG_WAIT_STEP := 2           # SSEP LogWaitCount Default
const ANIM_BASE_DELAY := 2         # SSEP LogAnime BaseDelay 8，Sprite_Animation.setup 里 ÷2 两次
const ANIM_NEXT_DELAY := 3         # LogAnime NextDelay 12 ÷ 4

var scene: XBattleScene
var user: XBattler
var skill: Dictionary
var entries: Array = []
var pos := 0
var phase := "phaseChange"
var frame := 0
## 日志窗
var wait_count := 0
var wait_mode := ""
var methods: Array = []
var lines := 0
var base_lines: Array = []
var anims: Array = []
## 测试用：每帧（精灵更新之后）调用 on_frame.call(self)；cmds 记 [帧, 指令名]
var on_frame := Callable()
var cmds: Array = []
var done := false
## ACTION COMMON EVENT / COMMON EVENT 预约了公共事件：下一帧 BattleManager.updateEvent 占掉（事件本身不在这里执行）
var _event_pending := false


static func create(s: XBattleScene, action: Dictionary, list: Array) -> XSequencePlayer:
	var p := XSequencePlayer.new()
	p.scene = s
	p.user = action.user
	p.skill = action.skill
	p.entries = list
	return p


func play() -> void:
	var tree := scene.get_tree()
	scene.seq_player = self
	for sp in scene.sprites.values():
		sp.seq_driven = true
	while not done:
		scene.camera.update()
		if not _busy():
			_step()
		for sp in scene.sprites.values():
			(sp as XBattlerSprite).seq_update()
		scene.apply_camera()
		if on_frame.is_valid():
			on_frame.call(self)
		_log_update()
		frame += 1
		await tree.physics_frame
	for sp in scene.sprites.values():
		sp.seq_driven = false
	scene.seq_player = null


func _busy() -> bool:
	return wait_count > 0 or wait_mode != "" or not methods.is_empty()


# ---- 行动机 ----
func _step() -> void:
	if _event_pending:
		_event_pending = false
		return
	if phase == "phaseChange":
		if pos >= entries.size() or entries[pos].type == "seq_end":
			done = true
			return
		var e: Dictionary = entries[pos]
		pos += 1
		phase = "actionTargetList" if e.get("phase", "") == "target" else "actionList"
		return
	while pos < entries.size():
		var e: Dictionary = entries[pos]
		match e.type:
			"seq_phase", "seq_end":
				phase = "phaseChange"
				return
			"seq_target":
				pos += 1
			"seq":
				pos += 1
				cmds.append([frame, e.name])
				if not _exec(e):
					return
			_:
				pos += 1
	phase = "phaseChange"


## 紧跟在指令后面的结算记录（命中、反击、反射、倒下）
func _results() -> Array:
	var out := []
	while pos < entries.size() and not str(entries[pos].type).begins_with("seq"):
		out.append(entries[pos])
		pos += 1
	return out


func _sprite(b) -> XBattlerSprite:
	return scene.sprites.get(b)


func _speed_frames(n: float) -> int:
	return ceili(n / (5 - XConfig.battle_speed()))


## Game_Battler.spriteCanMove：能行动（restriction < 4 且活着）
static func can_move(b: XBattler) -> bool:
	if b.is_dead():
		return false
	for st in b.states():
		if int(st.get("restriction", 0)) >= 4:
			return false
	return true


func _exec(e: Dictionary) -> bool:
	var name: String = e.name
	var args: Array = e.args
	var a0: Array = e.get("a0", [])
	var cam := XConfig.flag("battleCamera")
	# ---- YEP_X_ActSeqPack3 镜头 ----
	match name:
		"CAMERA CLAMP ON", "CAMERA CLAMP OFF":
			if cam:
				scene.camera.clamp_on = name == "CAMERA CLAMP ON"
			return true
		"CAMERA FOCUS", "FOCUS CAMERA":
			if not cam:
				return true
			if a0.is_empty():
				return false
			scene.camera.focus = a0
			var t := XBattleCamera.focus_type(str(args[1]).to_upper() if args.size() > 1 else "CENTER")
			scene.camera.focus_x = t[0]
			scene.camera.focus_y = t[1]
			scene.camera.cam_dur = _speed_frames(_num(args, 2, 30))
			return true
		"CAMERA OFFSET", "OFFSET CAMERA":
			if cam and not args.is_empty():
				var v := _num(args, 1, 100)
				match str(args[0]).to_upper():
					"LEFT": scene.camera.off_x = -v
					"RIGHT": scene.camera.off_x = v
					"UP": scene.camera.off_y = -v
					"DOWN": scene.camera.off_y = v
			return true
		"CAMERA PAN", "PAN CAMERA":
			if cam and not args.is_empty():
				var v := _num(args, 1, 100)
				match str(args[0]).to_upper():
					"LEFT": scene.camera.cam_x -= v
					"RIGHT": scene.camera.cam_x += v
					"UP": scene.camera.cam_y -= v
					"DOWN": scene.camera.cam_y += v
				scene.camera.cam_dur = int(_num(args, 2, 30))
			return true
		"CAMERA SCREEN":
			return _camera_screen(args, a0) if cam else true
		"RESET CAMERA":
			scene.camera.reset(int(_num(args, 0, 30)))
			return true
		"RESET ZOOM":
			scene.camera.zoom_to(1.0, int(_num(args, 0, 30)))
			return true
		"WAIT FOR CAMERA":
			if not cam:
				return true
			wait_mode = "camera"
			return false
		"WAIT FOR ZOOM":
			if not cam:
				return true
			wait_mode = "zoom"
			return false
		"ZOOM":
			if not cam:
				return true
			var a := str(args[0]) if not args.is_empty() else ""
			var m := RegEx.create_from_string("(\\d+)([%％])").search(a)
			var s := float(m.get_string(1)) * 0.01 if m else a.to_float()
			scene.camera.zoom_to(s if s != 0.0 else 1.0, int(_num(args, 1, 30)))
			return true
	# ---- YEP_X_ActSeqPack2 ----
	if name == "ATTACK ANIMATION":
		_attack_animation(a0)
		return true
	if name == "ENEMY EFFECT":
		if a0.is_empty():
			return true
		for t in a0:
			if t is XEnemy and args.size() > 1:
				match str(args[1]).to_upper():
					"WHITEN": _whiten(t)
					"BLINK": _sprite(t).blink()
		return true
	var sub: Array = e.get("sub", [])
	if name.begins_with("FACE ") and not sub.is_empty():
		return _face(sub, args)
	if name in ["FADE IN", "FADE OUT", "FLASH SCREEN", "TINT SCREEN", "SHAKE SCREEN"]:
		return false
	if name.begins_with("FLOAT ") and not sub.is_empty():
		_float_or_jump(sub, args, true)
		return false
	if name == "HIDE BATTLE HUD" or name == "SHOW BATTLE HUD":
		scene.ui.visible = name == "SHOW BATTLE HUD"
		return false
	if name.begins_with("JUMP ") and not sub.is_empty():
		_float_or_jump(sub, args, false)
		return true
	if name.begins_with("MOTION "):
		return _motion(name.substr(7), args, a0)
	if name.begins_with("MOVE ") and not sub.is_empty():
		return _move(sub, args, a0)
	if name.begins_with("OPACITY ") and not sub.is_empty():
		var a := str(args[0]) if not args.is_empty() else ""
		var v := -1.0
		var m := RegEx.create_from_string("(\\d+)([%％])").search(a)
		if m:
			v = clampf(floorf(float(m.get_string(1)) * 0.01 * 255.0), 0.0, 255.0)
		else:
			m = RegEx.create_from_string("(\\d+)").search(a)
			if m:
				v = float(m.get_string(1))
		if v >= 0.0:
			for t in sub:
				_sprite(t).setup_opacity(v, _speed_frames(_num(args, 1, 12)))
		return false
	match name:
		"WAIT FOR FLOAT":
			wait_mode = "float"
			return false
		"WAIT FOR JUMP":
			wait_mode = "jump"
			return false
		"WAIT FOR OPACITY":
			wait_mode = "opacity"
			return false
	# ---- YEP_X_ActSeqPack1 ----
	if RegEx.create_from_string("^(?:ADD|REMOVE)[ ](.*)[ ](?:BUFF|DEBUFF)").search(name) \
			or RegEx.create_from_string("^(?:ADD_STATE|ADD STATE|REMOVE_STATE|REMOVE STATE)[ ]\\d").search(name):
		return not a0.is_empty()
	var am := RegEx.create_from_string("ANIMATION[ ](\\d+)").search(name)
	if am:
		var id := int(am.get_string(1))
		if id <= 0 or a0.is_empty():
			return false
		_normal_animation(a0, id)
		return true
	if name in ["BGM", "MUSIC", "SONG", "BGS", "AMBIENCE", "ME", "FANFARE"]:
		return true
	if name == "BREAK ACTION" or name == "COLLAPSE" or name == "COMMON EVENT" or name in ["REFRESH STATUS", "REFRESH WINDOW"]:
		if name == "BREAK ACTION":
			phase = "phaseChange"
		if name == "COMMON EVENT":
			_event_pending = int(_num(args, 0, 0)) > 0
		_play_results(_results())
		return false
	if name.begins_with("CHANGE SWITCH") or name.begins_with("CHANGE VARIABLE") or name.begins_with("GOLD "):
		return true
	if RegEx.create_from_string("(?:GAIN|LOSE)[ ](.*)[ ](\\d+)").search(name):
		return true
	if name == "EVAL" or name == "SCRIPT":
		return args.is_empty()
	if name in ["SE", "SOUND", "SFX"]:
		_se(args)
		return true
	var hm := RegEx.create_from_string("^(HP|MP|TP)[ ]").search(name)
	if hm:
		if a0.is_empty():
			return false
		var show := args.any(func(x): return str(x).to_upper() == "SHOW")
		for g in e.get("gains", []):
			if show:
				if g[1] != "TP":
					scene._popup(g[0], -float(g[2]), false, "", g[1] == "MP")
				_push_results(false)
		return true
	# ---- YEP_BattleEngineCore ----
	match name:
		"":
			return true
		"ACTION ANIMATION":
			_action_animation(a0 if not args.is_empty() and str(args[0]) != "" else e.targets)
			return true
		"ACTION COMMON EVENT":
			_event_pending = skill.get("effects", []).any(func(ef): return int(ef.get("code", 0)) == 44 and int(ef.get("dataId", 0)) > 0)
			return false
		"ACTION EFFECT":
			_play_results(_results())
			return true
		"ANI WAIT", "ANIWAIT", "ANIMATION WAIT":
			wait_count = int(_num(args, 0, 0)) * XConfig.battle_speed()
			return false
		"CAST ANIMATION":
			_cast_animation()
			return true
		"CLEAR BATTLE LOG":
			_clear_log()
			return false
		"DEATH BREAK":
			_play_results(_results())
			if e.get("broke", false):
				phase = "phaseChange"
				return false
			return true
		"DISPLAY ACTION":
			methods.append(["addText", skill])
			return false
		"IMMORTAL":
			_play_results(_results())
			return true
		"MOTION WAIT":
			return _motion_wait(a0)
		"PERFORM ACTION":
			_perform_action()
			if user is XActor:
				wait_count += int(XDB.plugin("SSEP_BattleSpeedUp_v2").get("YEP Battle MotionWait", "20")) / _ssep()
				return false
			return true
		"PERFORM FINISH":
			_perform_finish()
			return true
		"PERFORM START":
			_sprite(user).refresh_idle()
			return true
		"WAIT":
			wait_count = _speed_frames(_num(args, 0, 0))
			return false
		"WAIT FOR ANIMATION":
			wait_mode = "animation"
			return false
		"WAIT FOR EFFECT":
			wait_mode = "effect"
			return false
		"WAIT FOR MOVEMENT":
			wait_mode = "movement"
			return false
		"WAIT FOR NEW LINE":
			if lines > (base_lines.back() if not base_lines.is_empty() else 0):
				wait_count = MESSAGE_SPEED
			return false
		"WAIT FOR POPUPS":
			wait_mode = "popups"
			return false
	# 不认识的行：BattleManager.processActionSequence 返回 false
	_play_results(_results())
	return false


func _ssep() -> int:
	return maxi(1, int(XDB.plugin("SSEP_BattleSpeedUp_v2").get("BattleSpeed (Default)", "2")))


static func _num(args: Array, i: int, fallback: float) -> float:
	if i >= args.size():
		return fallback
	var t := str(args[i]).strip_edges()
	return t.to_float() if t.is_valid_float() and t.to_float() != 0.0 else fallback


# ---- 日志窗 ----
func _log_update() -> void:
	if wait_count > 0:
		wait_count = maxi(0, wait_count - LOG_WAIT_STEP)
		return
	if wait_mode != "":
		if _waiting(wait_mode):
			return
		wait_mode = ""
	if methods.is_empty():
		return
	var m: Array = methods.pop_front()
	match m[0]:
		"addText":
			lines += 1
			scene._log_action(m[1])
			wait_count = MESSAGE_SPEED
		"pushBaseLine":
			base_lines.append(lines)
		"popBaseLine":
			var b: int = base_lines.pop_back() if not base_lines.is_empty() else 0
			if lines > b:
				lines = b
				if lines == 0:
					scene._banner("")
		"waitForNewLine":
			if lines > (base_lines.back() if not base_lines.is_empty() else 0):
				wait_count = MESSAGE_SPEED


func _waiting(mode: String) -> bool:
	match mode:
		"movement":
			return scene.sprites.values().any(func(s): return s.move_left > 0)
		"animation":
			anims = anims.filter(func(a): return is_instance_valid(a) and a.is_inside_tree())
			return not anims.is_empty()
		"effect":
			return scene.sprites.values().any(func(s): return s.effect_left > 0)
		"float":
			return scene.sprites.values().any(func(s): return s.is_floating())
		"jump":
			return scene.sprites.values().any(func(s): return s.is_jumping())
		"opacity":
			return scene.sprites.values().any(func(s): return s.is_changing_opacity())
		"camera":
			return scene.camera.is_panning()
		"zoom":
			return scene.camera.is_zooming()
		"popups":
			return scene._popups.values().any(func(l): return l.any(func(p): return is_instance_valid(p)))
	return false


func _clear_log() -> void:
	lines = 0
	scene._banner("")


## displayActionResults：pushBaseLine ×2、popupDamage ×2、（状态变化时 pushBaseLine、waitForNewLine、popBaseLine）、
## waitForNewLine、popBaseLine ×2
func _push_results(status: bool) -> void:
	methods.append(["pushBaseLine"])
	methods.append(["pushBaseLine"])
	methods.append(["popupDamage"])
	methods.append(["popupDamage"])
	if status:
		methods.append(["pushBaseLine"])
		methods.append(["waitForNewLine"])
		methods.append(["popBaseLine"])
	methods.append(["waitForNewLine"])
	methods.append(["popBaseLine"])
	methods.append(["popBaseLine"])


func _play_results(list: Array) -> void:
	for l in list:
		match l.type:
			"hit":
				if scene._hit_visual(l):
					scene._collapse_visual(l.target)
				_push_results(not (l.added.is_empty() and l.removed.is_empty()))
			"counter":
				scene._banner(str(XDB.system().terms.messages.counterAttack).replace("%1", l.user.display_name()))
				var a := scene._start_animation(scene._attack_animation(l.user), l.target)
				if a:
					anims.append(a)
				wait_mode = "animation"
			"reflect":
				scene._banner(str(XDB.system().terms.messages.magicReflection).replace("%1", l.target.display_name()))
				var a := scene._start_animation(int(skill.get("animationId", 0)), l.user)
				if a:
					anims.append(a)
				wait_mode = "animation"
			"collapse":
				scene._collapse_visual(l.target)
	scene._refresh_status(false)


# ---- 动画 ----
## Window_BattleLog.showNormalAnimation：画面中央的动画每个目标都放（不延迟），其余按目标依次延迟
func _normal_animation(targets: Array, id: int, mirror := false) -> void:
	var data := XDB.rec("Animations", id)
	var delay := ANIM_BASE_DELAY
	var seen := []
	for t in targets:
		if seen.has(t):
			continue
		seen.append(t)
		var a := scene._start_animation(id, t)
		if a == null:
			continue
		if mirror:
			a.scale.x = -1.0
		if int(data.get("position", 1)) != 3:
			a.wait = delay
			delay += ANIM_NEXT_DELAY
		anims.append(a)


func _attack_animation(targets: Array) -> void:
	_normal_animation(targets, scene._attack_animation(user))


func _action_animation(targets: Array) -> void:
	var id := int(skill.get("animationId", 0))
	if id < 0:
		_attack_animation(targets)
	else:
		_normal_animation(targets, id)


## castAnimation：备注 <Cast Animation: n>，否则按命中类型（必中 0、物理 52、魔法 51）；普通攻击、防御、物品不放
func _cast_animation() -> void:
	if XBattleLogic.is_item(skill) or int(skill.id) in [XBattleLogic.ATTACK_SKILL, XBattleLogic.GUARD_SKILL]:
		return
	var id := 0
	var meta: Dictionary = skill.get("meta", {})
	if meta.has("Cast Animation"):
		id = int(str(meta["Cast Animation"]).strip_edges())
	else:
		var p := XDB.plugin("YEP_BattleEngineCore")
		id = int(p.get(["Certain Hit Animation", "Physical Animation", "Magical Animation"][clampi(int(skill.get("hitType", 0)), 0, 2)], "0"))
	if id > 0:
		_normal_animation([user], id)


func _se(args: Array) -> void:
	if args.is_empty():
		return
	var p := XDB.plugin("YEP_X_ActSeqPack1")
	var name := str(args[0])
	var path := XDB.audio_path("se", name)
	if path == "" or scene.se == null:
		return
	scene.se.stream = load(path)
	scene.se.volume_db = linear_to_db(_num(args, 1, float(p.get("Default Volume", "90"))) / 100.0)
	scene.se.pitch_scale = _num(args, 2, float(p.get("Default Pitch", "100"))) / 100.0
	scene.se.play()


# ---- 动作、朝向、浮空、跳跃、移动 ----
func _perform_action() -> void:
	if user is XActor:
		scene._perform_action(user, skill)
	else:
		_whiten(user)


func _whiten(b: XBattler) -> void:
	var sp := _sprite(b)
	sp.flash(Color(1, 1, 1))
	sp.effect_left = maxi(sp.effect_left, 16)


## actionPerformFinish（ASP3 先把缩放与镜头 30 帧复位）：行动者 performActionEnd，活着的全员 spriteReturnHome
func _perform_finish() -> void:
	scene.camera.zoom_to(1.0, 30)
	scene.camera.reset(30)
	for b in scene.logic.alive(scene.logic.actors) + scene.logic.alive(scene.logic.enemies):
		var sp := _sprite(b)
		if can_move(b):
			sp.set_mirror(false)
			sp.move_left = XBattleTiming.move_frames(12)
		sp.refresh_idle()
	_sprite(user).refresh_idle()


func _motion_wait(a0: Array) -> bool:
	if not a0.is_empty() and a0[0] is XActor:
		wait_count += 12
		return false
	return true


## actionMotionTarget
func _motion(kind: String, args: Array, movers: Array) -> bool:
	var k := kind.strip_edges().to_lower()
	if k == "wait":
		return _motion_wait(movers)
	if k == "standby":
		k = "wait"
	if movers.is_empty():
		return true
	var weapon := not (args.size() > 1 and str(args[1]).to_upper() == "NO WEAPON")
	for b in movers:
		var sp := _sprite(b)
		match k:
			"attack":
				if b is XActor:
					var v := (b as XActor).attack_visual()
					sp.set_motion(v.motion)
					if int(v.image) > 0:
						sp.start_weapon(int(v.image))
			"randattack":
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				sp.set_motion(["thrust", "swing", "missile"][rng.randi() % 3])
			"thrust", "swing", "missile":
				sp.set_motion(k)
				if b is XActor and weapon:
					var v := (b as XActor).attack_visual()
					if int(v.image) > 0:
						sp.start_weapon(int(v.image))
			"walk", "move":
				sp.set_motion("walk")
			"damage", "hit":
				sp.set_motion("damage")
			_:
				sp.set_motion(k if k in ["wait", "chant", "guard", "evade", "skill", "spell", "item", "escape", "victory",
					"dying", "abnormal", "sleep", "dead"] else "wait")
	return false


func _face_point(b: XBattler, px: float, away := false) -> void:
	if not can_move(b):
		return
	var sp := _sprite(b)
	var right := sp.position.x > px
	# 角色朝左为正向：点在左边时朝前；敌人朝右为正向
	var forward := right if b is XActor else not right
	sp.set_mirror(forward == away)


func _face(movers: Array, args: Array) -> bool:
	var cmd := str(args[0]).to_upper() if not args.is_empty() else ""
	match cmd:
		"FORWARD", "NORMAL":
			for b in movers:
				if can_move(b):
					_sprite(b).set_mirror(false)
		"BACKWARD", "MIRROR":
			for b in movers:
				if can_move(b):
					_sprite(b).set_mirror(true)
		"HOME", "ORIGIN":
			for b in movers:
				_face_point(b, _sprite(b).home.x)
		_:
			var away := cmd.begins_with("AWAY FROM ")
			var spec := cmd.substr(10) if away else cmd
			var group := XActionSequence.create(scene.logic, user, skill, []).visual_targets(spec)
			if group.is_empty():
				return false
			var x := 0.0
			for t in group:
				x += _sprite(t).position.x
			for b in movers:
				_face_point(b, x / group.size(), away)
	return false


func _float_or_jump(movers: Array, args: Array, is_float: bool) -> void:
	var cmd := str(args[0]) if not args.is_empty() else ""
	var frames := _speed_frames(_num(args, 1, 12))
	var peak := 1.0
	var pixels := 0.0
	var m := RegEx.create_from_string("(\\d+)([%％])").search(cmd)
	if m:
		peak = float(m.get_string(1)) * 0.01
	else:
		m = RegEx.create_from_string("(\\d+)").search(cmd)
		if m:
			pixels = float(m.get_string(1))
			peak = 0.0
	for b in movers:
		if not can_move(b):
			continue
		var sp := _sprite(b)
		var rate := peak + pixels / sp.frame_size().y
		if is_float:
			sp.setup_float(rate, frames)
		else:
			sp.setup_jump(rate, frames)


## actionMove：坐标被锁，只记移动帧数、动作与朝向（与目标位置比较）
func _move(movers: Array, args: Array, dest: Array) -> bool:
	var cmd := str(args[0]).to_upper() if not args.is_empty() else ""
	var frames := 12.0
	match cmd:
		"HOME", "ORIGIN", "RETURN":
			frames = _num(args, 1, 12)
			for b in movers:
				_start_move(b, frames)
				_sprite(b).set_motion("walk" if cmd != "RETURN" else "evade")
				if cmd != "RETURN":
					_face_point(b, _sprite(b).home.x)
				elif can_move(b):
					_sprite(b).set_mirror(false)
			return true
		"FORWARD", "FORWARDS", "BACKWARD", "BACKWARDS":
			frames = _num(args, 2, 12)
			for b in movers:
				_start_move(b, frames)
				_sprite(b).set_motion("walk")
				if can_move(b):
					_sprite(b).set_mirror(cmd.begins_with("BACKWARD"))
			return true
		"POINT", "POSITION", "COORDINATE", "SCREEN", "SCREEN POS", "COORDINATES":
			frames = _num(args, 3, 12)
			for b in movers:
				_start_move(b, frames)
				_sprite(b).set_motion("walk")
			return true
	if dest.is_empty():
		return false
	frames = _num(args, 2, 12)
	var x := 0.0
	for t in dest:
		x += _sprite(t).position.x
	for b in movers:
		_start_move(b, frames)
		_face_point(b, x / dest.size())
	return true


func _start_move(b: XBattler, frames: float) -> void:
	if can_move(b):
		_sprite(b).move_left = XBattleTiming.move_frames(int(frames))


func _camera_screen(args: Array, a0: Array) -> bool:
	if args.is_empty():
		return true
	var cmd := str(args[0]).to_upper()
	var c := scene.camera
	var points := {"TOP LEFT": Vector2(0, 0), "UPPER LEFT": Vector2(0, 0), "FAR LEFT": Vector2(0, 360), "ABSOLUTE LEFT": Vector2(0, 360),
		"BOTTOM LEFT": Vector2(0, 720), "LOWER LEFT": Vector2(0, 720), "TOP CENTER": Vector2(640, 0), "UPPER CENTER": Vector2(640, 0),
		"CENTER": Vector2(640, 360), "MIDDLE": Vector2(640, 360), "BOTTOM CENTER": Vector2(640, 720), "LOWER CENTER": Vector2(640, 720),
		"TOP RIGHT": Vector2(1280, 0), "UPPER RIGHT": Vector2(1280, 0), "FAR RIGHT": Vector2(1280, 360), "ABSOLUTE RIGHT": Vector2(1280, 360),
		"BOTTOM RIGHT": Vector2(1280, 720), "LOWER RIGHT": Vector2(1280, 720)}
	if points.has(cmd):
		c.cam_x = points[cmd].x
		c.cam_y = points[cmd].y
		c.cam_dur = int(_num(args, 1, 30))
		return true
	if cmd in ["POINT", "POSITION", "COORDINATE", "SCREEN", "SCREEN POS", "COORDINATES"]:
		c.cam_x = _num(args, 1, 0)
		c.cam_y = _num(args, 2, 0)
		c.cam_dur = int(_num(args, 3, 30))
		return true
	if a0.is_empty():
		return false
	var t := XBattleCamera.focus_type(str(args[1]).to_upper() if args.size() > 1 else "")
	c.cam_x = c.target_pos_x(a0, t[0])
	c.cam_y = c.target_pos_y(a0, t[1])
	c.cam_dur = int(_num(args, 2, 30))
	return true
