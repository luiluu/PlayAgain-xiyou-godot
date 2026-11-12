class_name MVCharacter
extends Node2D
## 地图上的角色（玩家与事件共用），移植 MV Game_CharacterBase 的格子移动、行走图与动画规则。
## 行走图：文件名带 $ 为单人图（3×4 帧），否则一张 8 人（每人 3×4 帧）；带 ! 的物件不上移 6 像素。

const TS := MVTiles.TILE_SIZE
## 角色上方（优先级 2）的 z_index：地图上层图块是 10（XMapScene.load_map）
const ABOVE_UPPER_Z := 11

var grid := Vector2i.ZERO
var real := Vector2.ZERO           # 以格为单位的实际位置（移动中为小数）
var direction := 2
var move_speed := 4                # MV 1..6，4 为标准
var move_frequency := 3
var pattern := 1
## Game_CharacterBase._originalPattern：停下后回到的帧（resetPattern）。玩家、跟随者是 1；事件是本页图的 pattern
## （Game_Event.setupPageSettings，MVEvent.refresh 设）。-1＝用行走图的停步序号 _walk.stand。
## 重制原先一律回到 stand：本页图 pattern 0、只画了第一列的行走图（大厅绪绪 1xuxu，800×529 只有左上一格有图）
## 停 6 帧后换到空白的第二列，人就不见了（玩家反馈 v0.01「买碎片的 NPC 图标丢失」）。
var original_pattern := -1
var through := false
var priority_type := 1             # 0 角色下方 1 同层 2 角色上方
var walk_anime := true
var step_anime := false
var direction_fix := false
var transparent := false
var character_name := ""
var character_index := 0
var tile_id := 0
var opacity := 255
## Game_Vehicle._altitude：screenY 减去它（只有飞艇用，见 XMapScene._refresh_airship_sprite）
var altitude := 0
var _tex: Texture2D
## 行走图格式（XAppearance.walk：格子、序列、停步序号、方向行），默认 MV 3×4
var _walk := {"cell": Vector2(48, 48), "origin": Vector2.ZERO, "sequence": [0, 1, 2, 1], "stand": 1, "rows": {2: 0, 4: 1, 6: 2, 8: 3}}
var _anime_count := 0.0
var _stop_count := 0
var tilemap: MVTilemap
## 移动路线（Game_Character.forceMoveRoute / updateRoutineMove）
var _route: Dictionary = {}
var _route_index := 0
var _route_wait := 0
var _route_forcing := false
var _route_ok := true
## forceMoveRoute 记下的原路线（Game_Character.memorizeMoveRoute／restoreMoveRoute）：强制路线走完后自定义路线（类型 3）从这里接着走
var _orig_route: Dictionary = {}
var _orig_index := 0
var _has_orig := false
var _route_restored := false
## Game_CharacterBase._stopCount 的「停了多少帧」用途（自主移动按它与频率决定何时走下一步）：停着每帧加一，转向、走成一步、跳跃清零。
## （_stop_count 是行走动画回到站立帧用的另一个计数，见 _update_animation）
var _idle_count := 0
## 自主移动与路线里的随机（随机移动、随机转向等）：画面随机流，不动规则随机数。fixed_random ≥ 0 时固定（对照测试用，同参照的 Math.random＝0.5）
static var fixed_random := -1.0
var _motion_rng: RandomNumberGenerator
## O-230：原版强制路线结束时 restoreMoveRoute 还原了自定义路线的序号，紧接着 advanceMoveRouteIndex 又把它加一，自定义路线（移动类型 3）
## 每被强制一次就跳过一条（左右来回的路线被强制一次后一路往一边偏）；换页时也不清记下的原路线，之后的强制路线结束会还原成旧页的路线。
## 重制默认修好：还原后不再加一、换页时清掉记下的原路线。设为 false 恢复原版（专项两边都跑，所以是 static var）。
static var route_resume_fix := true
## 走一格每帧的距离倍数（复现原版，不是优化）：正式版 js/rpg_οbjects.js（文件名里是希腊字母 ο，index.html 载入的就是它）的
## Game_CharacterBase.distancePerFrame 写成 2×2^速度÷256，比 MV 默认快一倍（冻结 v0.28 第 6549 行、v0.62.12 第 6550 行都是）。
## 作者有意改的，和 Drill_SpeedGear 的全局 1.6 倍帧率相乘才是原版实际速度，两边各自对齐。设为 1.0 回到 MV 默认（回退开关）。
static var move_distance_scale := 2.0
## 跳跃（Game_CharacterBase.jump / updateJump）
var _jump_peak := 0
var _jump_count := 0
## 气泡（Sprite_Balloon：8 帧 × 速度 8 ＋ 停留 waitTime 帧，图 Balloon.png 每格 48）。正式版 SSEP_BattleSpeedUp_v2
## 把 Sprite_Balloon.waitTime 改成 Balloon ÷ BattleSpeed(Default) ÷ BattleSpeed(Default)＝12÷2÷2＝3（地图上也生效；
## OkayKeyBoost 参数 false），ui10 前照 MV 默认 12，气泡多停 9 帧。原版开了战斗加速（QuickMode，Shift／按钮切，模块级变量，地图上也一直生效）
## 时是 12÷2÷8＝0.75 帧；重制用 O-006 的四档战斗变速代替 QuickMode，所以变速开着（四倍／三倍／二倍）时照 0.75，OFF 时 3（ui13，审查 46 P3-2）。
var balloon_id := 0
var _balloon_t := 0.0   # Sprite_Balloon._duration（waitTime 可能是小数 0.75）
static var _balloon_tex: Texture2D
var _balloon_layer: Node2D    # 气泡单独一层（MV 的 Sprite_Balloon 加在角色精灵的父节点上，不受闪光、隐藏影响）
var _anim_hidden := false     # 动画 flashScope 3 隐藏目标（Sprite_Character.hide）


func set_image(name: String, index: int) -> void:
	pose_original = name  # MOG_CharPoses setImage → setRealCharName：记原名（跑步保持帧数不清）
	_set_image(name, index)


## 换姿势图（不改记下的原名）
func _set_image(name: String, index: int) -> void:
	character_name = name
	character_index = index
	frames_offset = frames_offset_of(name)
	tile_id = 0
	var p := XDB.img_path("characters", name) if name != "" else ""
	_tex = load(p) if p != "" else null
	_walk = XAppearance.walk(name, index, _tex)
	queue_redraw()

func set_tile_image(id: int) -> void:
	tile_id = id
	character_name = ""
	_tex = null
	queue_redraw()

func locate(x: int, y: int) -> void:
	grid = Vector2i(x, y)
	real = Vector2(x, y)
	_sync_position()

func is_big() -> bool:
	return character_name.begins_with("$") or character_name.begins_with("!$")

func is_object() -> bool:
	return character_name.begins_with("!")

func is_moving() -> bool:
	return not real.is_equal_approx(Vector2(grid))

func is_jumping() -> bool:
	return _jump_count > 0

func jump_height() -> float:
	return (_jump_peak * _jump_peak - pow(absf(_jump_count - _jump_peak), 2)) / 2.0

func distance_per_frame() -> float:
	return pow(2.0, move_speed) / 256.0 * move_distance_scale

static func dir_offset(d: int) -> Vector2i:
	match d:
		2: return Vector2i(0, 1)
		4: return Vector2i(-1, 0)
		6: return Vector2i(1, 0)
		8: return Vector2i(0, -1)
	return Vector2i.ZERO

static func reverse_dir(d: int) -> int:
	return 10 - d


func set_direction(d: int) -> void:
	if not direction_fix and d > 0:
		direction = d
	_idle_count = 0   # Game_CharacterBase.setDirection 不论朝向锁定都 resetStopCount
	queue_redraw()


## 能否朝 d 走一步：地图双向通行＋与其他同层角色碰撞（由地图场景提供 is_blocked）。
func can_pass(d: int) -> bool:
	return can_pass_at(grid, d)

## Game_CharacterBase.canPass(x, y, d)：从 from 朝 d 走一步（斜走的两步判定要从别的格子起算）
func can_pass_at(from: Vector2i, d: int) -> bool:
	if tilemap == null:
		return false
	var to := tilemap.round_cell(from + dir_offset(d))
	if not tilemap.is_valid(to):
		return false
	if through:
		return true
	if not tilemap.is_passable(from.x, from.y, d) or not tilemap.is_passable(to.x, to.y, reverse_dir(d)):
		return false
	var scene = get_parent().get_parent() if get_parent() else null
	if scene and scene.has_method("is_blocked") and scene.is_blocked(to, self):
		return false
	return true

func move_straight(d: int) -> bool:
	set_direction(d)
	if can_pass(d):
		step_by(dir_offset(d))
		return true
	return false

## 走一格：循环地图越过边缘时格子绕回另一侧，实际位置跟着平移一整张图，仍从原处走过去
## （MV moveStraight 的 _x = roundXWithDirection、_realX = xWithDirection(_x, 反方向)）
func step_by(off: Vector2i) -> void:
	var to := grid + off
	grid = tilemap.round_cell(to) if tilemap else to
	real += Vector2(grid - to)


func _physics_process(_delta: float) -> void:
	update_character()
	_update_pose()


# ---- MOG_CharPoses 姿势（只有玩家与队伍跟随；正式参数只开了奔跑、跳跃，名单只有「角色奔跑-3」＝CXK-lan-qiu）----
## setRealCharName 记下的原名；pose_dash 是 _poses.dash[1]（跑步姿势的保持帧数，跑着时每帧回到 3）
var pose_original := ""
var pose_dash := 0

## MOG_CharPoses setCharacterFrames：图名里的 X数字／Y数字（不分大小写，任意位置）是行走图的偏移——朝右 +X、朝左 −X、上下不偏，
## 竖向一律 +Y；气泡跟着偏，技能动画不偏（Sprite_Animation 再减回去）。正式数据里只有 103 波风水门 TZX01、146 苍龙破晓 TZX04、
## 147 天剑 非天 TZX03 带 X。同一处的 S数字（动画加速）、(F数字)（多帧行走图）没有照做：只有一个楼梯事件 !fsm_Stairs01 被 S 误认，见交付单。
var frames_offset := Vector2.ZERO

static func frames_offset_of(name: String) -> Vector2:
	var out := Vector2.ZERO
	var ex := RegEx.create_from_string("(?i)X(\\d+\\.*\\d*)").search(name)
	if ex:
		out.x = float(ex.get_string(1))
	var ey := RegEx.create_from_string("(?i)Y(\\d+\\.*\\d*)").search(name)
	if ey:
		out.y = float(ey.get_string(1))
	return out

## 此刻的偏移（updateCharPosesPosition）
func frames_shift() -> Vector2:
	var x := frames_offset.x if direction == 6 else (-frames_offset.x if direction == 4 else 0.0)
	return Vector2(x, frames_offset.y)

## 插件参数「角色奔跑-N」（N＝getActorId）；空＝照原图
static func run_pose(actor_id: int) -> String:
	return str(XDB.plugin("MOG_CharPoses").get("角色奔跑-%d" % actor_id, "")) if actor_id > 0 else ""

## 玩家、跟随覆写；事件（getActorId 0、奔跑姿势关）不做
func _update_pose() -> void:
	pass

## Game_CharacterBase.updateSetPose 的奔跑一支（跳跃名单为空＝原图，站立姿势关）：保持帧数没走完就不换；
## 否则正在跑步姿势＝「角色奔跑-N」（没配就是原图）并把保持帧数设回 3，不然回原图
func _apply_dash_pose(dashing: bool, actor_id: int) -> void:
	if pose_original == "" or tile_id > 0:
		return
	if pose_dash > 0:
		if dashing:
			pose_dash = 3
		pose_dash -= 1
		return
	var name := pose_original
	if dashing:
		pose_dash = 3
		var run := run_pose(actor_id)
		if run != "":
			name = run
	if name != character_name:
		_set_image(name, character_index)

func update_character() -> void:
	if not is_moving() and not is_jumping():
		_update_stop()
	if is_jumping():
		_jump_count -= 1
		real.x = (real.x * _jump_count + grid.x) / (_jump_count + 1.0)
		real.y = (real.y * _jump_count + grid.y) / (_jump_count + 1.0)
		if _jump_count == 0:
			real = Vector2(grid)
		_sync_position()
	elif is_moving():
		var dist := distance_per_frame()
		real.x = move_toward(real.x, grid.x, dist)
		real.y = move_toward(real.y, grid.y, dist)
		_sync_position()
	_update_animation()
	if balloon_id > 0:
		_balloon_t -= 1
		if _balloon_t <= 0:
			balloon_id = 0
		if _balloon_layer:
			_balloon_layer.queue_redraw()


## Game_Character.updateStop：停着的帧计数，有强制路线就走强制路线（MVEvent 再接自主移动）
func _update_stop() -> void:
	_idle_count += 1
	if _route_forcing:
		_update_route()


# ---- 移动路线（MV Game_Character.processMoveCommand 的常用部分）----
## Game_Character.forceMoveRoute：没记过原路线才记（memorizeMoveRoute），强制期间自主移动停下
func force_move_route(route: Dictionary) -> void:
	if not _has_orig:
		_orig_route = _route
		_orig_index = _route_index
		_has_orig = true
	_route = route
	_route_index = 0
	_route_wait = 0
	_route_forcing = true

func is_route_forcing() -> bool:
	return _route_forcing

## Game_Character.setMoveRoute（换页时设成新页的自定义路线）：同时取消强制路线
func set_move_route(route: Dictionary) -> void:
	_route = route
	_route_index = 0
	_route_forcing = false
	if route_resume_fix:
		_has_orig = false
		_orig_route = {}

## Game_Character.restoreMoveRoute
func _restore_route() -> void:
	if _has_orig:
		_route = _orig_route
		_route_index = _orig_index
	_has_orig = false
	_orig_route = {}

## Game_Character.updateRoutineMove（强制路线与移动类型 3 的自定义路线共用）
func _update_route() -> void:
	if _route_wait > 0:
		_route_wait -= 1
		return
	var list: Array = _route.get("list", [])
	_route_ok = true
	if _route_index >= list.size():
		# 原版：序号越过末尾时什么也不做。强制路线缺结束指令时这里结束强制（原有保护，不然「等待完成」的 205 会一直等）
		if _route_forcing:
			_route_forcing = false
			_restore_route()
		return
	_route_restored = false
	_process_move(list[_route_index])
	if _route_restored and route_resume_fix:
		_route_restored = false
		return
	_route_restored = false
	# Game_Character.advanceMoveRouteIndex（作用在当前路线上：强制路线刚结束时已是还原后的原路线）
	if _route_ok or bool(_route.get("skippable", false)):
		_route_index += 1
		if bool(_route.get("repeat", false)) and _route_index >= (_route.get("list", []) as Array).size() - 1:
			_route_index = 0

## 自主移动与路线里的随机整数 [0, n)（Math.randomInt）
func _roll(n: int) -> int:
	if fixed_random >= 0.0:
		return mini(int(floor(fixed_random * n)), n - 1)
	if _motion_rng == null:
		_motion_rng = RandomNumberGenerator.new()
		_motion_rng.randomize()
	return _motion_rng.randi_range(0, n - 1)

## 地图场景（角色挂在场景的 chars 层下）
func _map_scene() -> Node:
	return get_parent().get_parent() if get_parent() else null

## 场景里的玩家（接近／远离／转向玩家用）；没有时返回 null
func _player_ref() -> MVCharacter:
	var scene = _map_scene()
	if scene != null and "player" in scene and scene.player is MVCharacter:
		return scene.player
	return null

## Game_Character.deltaXFrom／deltaYFrom：自己减对方，循环地图取较短的一边
func _delta_from(cell: Vector2i) -> Vector2i:
	return tilemap.delta(grid, cell) if tilemap else grid - cell

## Game_Character.moveTowardCharacter
func move_toward_character(c: MVCharacter) -> void:
	var dlt := _delta_from(c.grid)
	if absi(dlt.x) > absi(dlt.y):
		_route_ok = move_straight(4 if dlt.x > 0 else 6)
		if not _route_ok and dlt.y != 0:
			_route_ok = move_straight(8 if dlt.y > 0 else 2)
	elif dlt.y != 0:
		_route_ok = move_straight(8 if dlt.y > 0 else 2)
		if not _route_ok and dlt.x != 0:
			_route_ok = move_straight(4 if dlt.x > 0 else 6)

## Game_Character.moveAwayFromCharacter
func move_away_from_character(c: MVCharacter) -> void:
	var dlt := _delta_from(c.grid)
	if absi(dlt.x) > absi(dlt.y):
		_route_ok = move_straight(6 if dlt.x > 0 else 4)
		if not _route_ok and dlt.y != 0:
			_route_ok = move_straight(2 if dlt.y > 0 else 8)
	elif dlt.y != 0:
		_route_ok = move_straight(2 if dlt.y > 0 else 8)
		if not _route_ok and dlt.x != 0:
			_route_ok = move_straight(6 if dlt.x > 0 else 4)

## Game_Character.turnTowardCharacter／turnAwayFromCharacter
func turn_toward_character(c: MVCharacter, away := false) -> void:
	var dlt := _delta_from(c.grid)
	if absi(dlt.x) > absi(dlt.y):
		set_direction((6 if dlt.x > 0 else 4) if away else (4 if dlt.x > 0 else 6))
	elif dlt.y != 0:
		set_direction((2 if dlt.y > 0 else 8) if away else (8 if dlt.y > 0 else 2))

## Game_Character.moveRandom：随机一个方向，走得通才走（走不通不算失败，路线照常往下）
func move_random() -> void:
	var d := 2 + _roll(4) * 2
	if can_pass(d):
		move_straight(d)

## Game_CharacterBase.moveDiagonally／canPassDiagonally
func move_diagonally(horz: int, vert: int) -> bool:
	var x2 := tilemap.round_cell(grid + dir_offset(horz)) if tilemap else grid + dir_offset(horz)
	var y2 := tilemap.round_cell(grid + dir_offset(vert)) if tilemap else grid + dir_offset(vert)
	var ok := (can_pass_at(grid, vert) and can_pass_at(Vector2i(grid.x, y2.y), horz)) or (can_pass_at(grid, horz) and can_pass_at(Vector2i(x2.x, grid.y), vert))
	if ok:
		step_by(dir_offset(horz) + dir_offset(vert))
		_idle_count = 0
	if direction == reverse_dir(horz):
		set_direction(horz)
	if direction == reverse_dir(vert):
		set_direction(vert)
	return ok

## 移动路线里的脚本（指令 45）：基类不认，MVEvent 认 YEP_EventChasePlayer 的设定
func _route_script(text: String) -> void:
	push_warning("移动路线脚本尚未支持：" + text)

func _process_move(cmd: Dictionary) -> void:
	var p: Array = cmd.get("parameters", [])
	match int(cmd.get("code", 0)):
		0:
			# Game_Character.processRouteEnd
			if bool(_route.get("repeat", false)):
				_route_index = -1
			elif _route_forcing:
				_route_forcing = false
				_restore_route()
				_route_restored = true
		1, 2, 3, 4:
			_route_ok = move_straight([2, 4, 6, 8][int(cmd.code) - 1])
		5, 6, 7, 8:
			# 左下、右下、左上、右上
			_route_ok = move_diagonally([4, 6, 4, 6][int(cmd.code) - 5], [2, 2, 8, 8][int(cmd.code) - 5])
		9:
			move_random()
		10, 11:
			var target := _player_ref()
			if target != null:
				if int(cmd.code) == 10:
					move_toward_character(target)
				else:
					move_away_from_character(target)
		12:
			_route_ok = move_straight(direction)
		13:
			var d := direction
			var fix := direction_fix
			direction_fix = true
			_route_ok = move_straight(reverse_dir(d))
			direction_fix = fix
		14:
			jump(int(p[0]), int(p[1]))
		15:
			_route_wait = int(p[0]) - 1
		16, 17, 18, 19:
			set_direction([2, 4, 6, 8][int(cmd.code) - 16])
		20:
			set_direction({2: 4, 4: 8, 6: 2, 8: 6}.get(direction, direction))
		21:
			set_direction({2: 6, 4: 2, 6: 8, 8: 4}.get(direction, direction))
		22:
			set_direction(reverse_dir(direction))
		23:
			if _roll(2) == 0:
				set_direction({2: 4, 4: 8, 6: 2, 8: 6}.get(direction, direction))
			else:
				set_direction({2: 6, 4: 2, 6: 8, 8: 4}.get(direction, direction))
		24:
			set_direction(2 + _roll(4) * 2)
		25, 26:
			var target := _player_ref()
			if target != null:
				turn_toward_character(target, int(cmd.code) == 26)
		29:
			move_speed = int(p[0])
		30:
			move_frequency = int(p[0])
		31, 32:
			walk_anime = int(cmd.code) == 31
		33, 34:
			step_anime = int(cmd.code) == 33
		35, 36:
			direction_fix = int(cmd.code) == 35
		37, 38:
			through = int(cmd.code) == 37
		39, 40:
			transparent = int(cmd.code) == 39
			queue_redraw()
		41:
			set_image(str(p[0]), int(p[1]))
		42:
			opacity = int(p[0])
			queue_redraw()
		44:
			var path := XDB.audio_path("se", str(p[0].get("name", ""))) if p.size() > 0 and p[0] is Dictionary else ""
			if path != "":
				var player := AudioStreamPlayer.new()
				XAudio.bind(player, "SE")
				player.stream = load(path)
				player.volume_db = linear_to_db(float(p[0].get("volume", 90)) / 100.0)
				player.pitch_scale = float(p[0].get("pitch", 100)) / 100.0
				add_child(player)
				player.play()
				player.finished.connect(player.queue_free)
		45:
			_route_script(str(p[0]) if p.size() > 0 else "")
		_:
			push_warning("移动路线指令 %d 尚未支持" % int(cmd.get("code", 0)))

## Game_CharacterBase.jump：朝位移方向转身，峰高 10 + 距离 − 速度，帧数为峰高的两倍
func jump(dx: int, dy: int) -> void:
	if absi(dx) > absi(dy):
		if dx != 0:
			set_direction(4 if dx < 0 else 6)
	elif dy != 0:
		set_direction(8 if dy < 0 else 2)
	grid += Vector2i(dx, dy)
	var distance := roundi(sqrt(dx * dx + dy * dy))
	_jump_peak = 10 + distance - move_speed
	_jump_count = _jump_peak * 2
	_stop_count = 0
	_idle_count = 0
	pattern = int(_walk.stand)


# ---- 气泡 ----
func start_balloon(id: int) -> void:
	balloon_id = id
	_balloon_t = 8 * 8 + balloon_wait()
	if _balloon_layer == null:
		_balloon_layer = Node2D.new()
		_balloon_layer.draw.connect(_draw_balloon)
		add_child(_balloon_layer)
	_balloon_layer.queue_redraw()
	queue_redraw()

## Sprite_Balloon.waitTime（SSEP 覆写，见 balloon_id 处）；BALLOON_SSEP = false 回到 MV 默认 12（回退开关）
static var BALLOON_SSEP := true
## 变速档（XConfig.battle_speed，1 四倍…4 OFF）；speed_override 非 0 时用它（测试用）
static var speed_override := 0
static func balloon_wait() -> float:
	if not BALLOON_SSEP:
		return 12.0
	var p := XDB.plugin("SSEP_BattleSpeedUp_v2")
	var base := maxf(float(p.get("BattleSpeed (Default)", "2")), 1.0)
	var boost := maxf(float(p.get("BattleSpeed (Boost)", "8")), 1.0)
	var tier := speed_override if speed_override != 0 else XConfig.battle_speed()
	return float(p.get("Balloon", "12")) / base / (boost if tier < 4 else base)

## Sprite_Balloon.frameIndex；还没 updateFrame（帧号 −1）时返回 −1
func balloon_frame() -> int:
	if balloon_id <= 0:
		return -1
	return 7 - maxi(floori((_balloon_t - balloon_wait()) / 8.0), 0)

func is_balloon_playing() -> bool:
	return balloon_id > 0

## Game_CharacterBase.animationWait：(9 − 速度) × 3。installNativeRavenRuntime 包装：队长（玩家）或跟随者是渡鸦 167 时
## ×1.35 四舍五入（披风三帧变化大，放慢步行帧；不改移动速度和别人）。事件没有对应角色，照旧。
## O-195（交付单「优化登记草稿」渡鸦地图步行帧）：RAVEN_WALK_SLOW = false 回到移植前（渡鸦和别人一样快）。
static var RAVEN_WALK_SLOW := true

func animation_wait() -> int:
	var wait := (9 - move_speed) * 3
	var a = walking_actor()
	if RAVEN_WALK_SLOW and a is XActor and int(a.actor_id) == XRaven.ACTOR:
		return roundi(wait * 1.35)
	return wait

## 地图上「走着的角色」（Game_Follower.actor／玩家取队长）；事件没有
func walking_actor():
	return null

## 停下后回到的帧：事件是本页图的 pattern，其余是行走图的停步序号
func origin_pattern() -> int:
	return original_pattern if original_pattern >= 0 else int(_walk.stand)

func _update_animation() -> void:
	if is_moving() and walk_anime or step_anime:
		_anime_count += 1.5 if is_moving() else 1.0
	elif pattern != origin_pattern():
		_stop_count += 1
		if _stop_count > 6:
			pattern = origin_pattern()
			_anime_count = 0
			queue_redraw()
	var wait := animation_wait()
	if _anime_count >= wait:
		_anime_count = 0
		_stop_count = 0
		pattern = (pattern + 1) % (_walk.sequence as Array).size()
		queue_redraw()

func _sync_position() -> void:
	var at := real + (tilemap.loop_shift(real) if tilemap and (tilemap.loop_x or tilemap.loop_y) else Vector2.ZERO)
	position = Vector2(at.x * TS + TS / 2.0, at.y * TS + TS - (jump_height() if is_jumping() else 0.0) - altitude)
	# screenZ＝优先级×2＋1（1／3／5），上层图块 z 4（ShaderTilemap._upperLayer）：角色上方的压在上层图块（地图 z_index 10）之上
	z_index = (0 if priority_type == 1 else (-1 if priority_type == 0 else ABOVE_UPPER_Z))
	queue_redraw()


func _draw() -> void:
	if transparent or opacity <= 0 or _anim_hidden:
		return
	_draw_body()


## 技能动画目标（Sprite_Animation._target）：flashScope 1 用 Sprite.setBlendColor 的颜色混合（只作用在行走图上）
func set_anim_blend(c: Color) -> void:
	if c.a <= 0.0 and not material is ShaderMaterial:
		return
	if not material is ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = XBattlerSprite.body_shader()
		material = mat
	(material as ShaderMaterial).set_shader_parameter("blend", c)


func anim_blend() -> Color:
	return (material as ShaderMaterial).get_shader_parameter("blend") if material is ShaderMaterial else Color(0, 0, 0, 0)


## flashScope 3：隐藏到时间点结束（气泡照常显示）
func set_anim_hidden(h: bool) -> void:
	_anim_hidden = h
	queue_redraw()


## 行走图高度（气泡、动画定位用）
func sprite_height() -> float:
	if tile_id > 0:
		return TS
	if _tex == null:
		return 0.0
	return _walk.cell.y


## Sprite_Balloon：帧号 = 7 − floor((剩余 − waitTime) / 8)，画在角色头顶（行走图高度处）。
## 气泡精灵加在角色精灵的父节点上，透明、不透明度 0 的角色照样画气泡（Sprite_Character.updateBalloon 不看可见性）；
## setup 那一帧还没 updateFrame（loadBitmap 的 setFrame(0,0,0,0)），帧号算出 −1 时不画。
func _draw_balloon() -> void:
	if balloon_id <= 0:
		return
	if _balloon_tex == null:
		var p := XDB.img_path("system", "Balloon")
		if p != "":
			_balloon_tex = load(p)
	if _balloon_tex == null:
		return
	var frame := balloon_frame()
	if frame < 0:
		return
	var shift := 0.0 if is_object() else 6.0
	var off := frames_shift()
	_balloon_layer.draw_texture_rect_region(_balloon_tex, Rect2(off.x - 24, off.y - sprite_height() - shift - 48, 48, 48), Rect2(frame * 48, (balloon_id - 1) * 48, 48, 48))


func _draw_body() -> void:
	var mod := Color(1, 1, 1, opacity / 255.0)
	if tile_id > 0 and tilemap != null:
		_draw_tile_image(mod)
		return
	if _tex == null:
		return
	var pw: float = _walk.cell.x
	var ph: float = _walk.cell.y
	var seq: Array = _walk.sequence
	var pat: int = seq[pattern % seq.size()]
	var row: int = _walk.rows.get(direction, 0)
	var src := Rect2(_walk.origin.x + pat * pw, _walk.origin.y + row * ph, pw, ph)
	var shift := 0.0 if is_object() else 6.0
	var off := frames_shift()
	draw_texture_rect_region(_tex, Rect2(off.x - pw / 2.0, off.y - ph - shift, pw, ph), src, mod)

func _draw_tile_image(mod: Color) -> void:
	var set_number := 5 + floori(tile_id / 256.0)
	var tex: Texture2D = tilemap.sheets[set_number] if set_number < tilemap.sheets.size() else null
	if tex == null:
		return
	var sx := (floori(tile_id / 128.0) % 2 * 8 + tile_id % 8) * TS
	var sy := (floori(tile_id % 256 / 8.0) % 16) * TS
	draw_texture_rect_region(tex, Rect2(-TS / 2.0, -TS, TS, TS), Rect2(sx, sy, TS, TS), mod)
