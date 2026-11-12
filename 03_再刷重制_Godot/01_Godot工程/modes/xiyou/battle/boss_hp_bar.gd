class_name XBossHpBar
extends Node2D
## MOG_BossHP v2.3 Boss 血条（战斗顶部：固定框、彩虹生命条、头像、血量数字、Boss 名）。只显示，不参与结算。
## 参数全读正式西游的插件参数（XDB.plugin("MOG_BossHP")）；素材在 img/bosshp/（Boss_HP_A 框 507×78、Boss_HP_B 条 1392×22、
## Boss_HP_C2 数字 450×28 共 15 格、boss-N-头像）。坐标为原版 1280×720 画面坐标，节点放在战斗画面原点。
## - 哪些敌人算 Boss：插件参数 boss-1…boss-569 列的敌人编号（_bosshp_meter，与备注 <boss> 的 Boss 判定无关）。
##   开战时取敌群里「最后一个」是 Boss 且未隐藏的敌人建条；开战时没有就整场不建。
## - 条跟着「最后被命中的 Boss」走（Game_Action.apply 记 $gameTemp._battler_bhp_temp）：换目标时红条与数字从该次命中前的血量起算。
## - 每帧（Sprite_BossHP.update）：条纹流动（每帧 4px，蓝红共用一个周期 3 段）；受伤震动头像（整个条 y 在 −3…+2 随机，共 80 帧）；
##   红条（下半，拖尾）每帧下降 1+差/160；数字每帧追 1+⌊差/30⌋；蓝条（上半）即时。大差值的两处都封顶（O-188、O-237，见 red_step／number_step）。
##   淡出：对话忙、战斗结束（胜利／逃跑／失败）、Boss 死亡时不透明度每帧 −5，否则 +5；首帧直接满。
## - 数字：≥1 万加单位（万／亿／兆／京），＜100 取 2 位小数、＜1000 取 1 位、其余取整，去掉末尾 0；字符间距 20（图格 30 宽，叠着画，同原版）。
## - 状态图标：原版被 Codex_BossStatusSummary 藏起（换成下方状态面板），所以这里不画。
## - 原版缺陷，修好（O-228，rules-bugfix1 照搬清单第 2 条）：敌人变身（transform）后血条的名字、头像仍是旧编号的；
##   开战时没有 Boss、之后才现身（追加）或变身成 Boss 的，整场不建条。现在：条跟着的敌人编号变了就换名字和头像；
##   还没建条时每帧按开战时的规则再挑一次（敌群里最后一个是 Boss 且未隐藏的），挑到就建。回退开关 REBUILD = false：照原版。

## 冻结后跟进 v0.37（installNativeZhenqiRuntime「首领血条」Z.bossHpEnemy）：除插件名单外，心魔／天劫瓶颈之战（敌群 901／823）、
## 心魔训练敌群（770）里的敌人，和神兵试炼的神兵之仙（Z.WEAPON_BOSS 或备注 <CodexZhenqi: weapon N>）也显示首领血条。
## 只走显示层：名单里的 Boss 优先（敌群里最后一个且未隐藏）；名单里一个也没有时才取这类敌人里最后一个未隐藏的。
## 它们的头像为空（face_name 返回 ""）、小血条不出现（原版 hpGaugeVisible 对它们返回 false）。
## false＝v0.28 的范围（只认插件名单）；换源（v0.62.12）集成分支已翻成 true（O-203，回退＝改回 false）。
static var RANGE_V037 := true
static var REBUILD := true

const LIST_LENGTH := 569
const SHAKE_FRAMES := 80
const UNITS := ["", "万", "亿", "兆", "京"]
const UNIT_THRESHOLDS := [1.0, 10000.0, 100000000.0, 1000000000000.0, 10000000000000000.0]
const DIGIT_FRAMES := 15

static var _boss_list := {}  # 敌人编号 → 头像文件名（空串＝无头像）
static var _tex_cache := {}

var hp_source: Callable   # (enemy) -> {hp, mhp, dead}：画面读数
var busy_source: Callable  # () -> bool：对话窗忙（$gameMessage.isBusy）

var battler = null        # 条现在跟着的 Boss
var layout_alpha := 0     # 0…255，框、条、名、数字共用
var hp_red := 0.0         # _hp_data[2]
var hp_number := 0.0      # _hp_data[6]
var shake := 0            # _hp_data[7]
var flow := 0.0           # 蓝红条的流动偏移（_hp_meter_*Flow[3]）
var ended_flag := false   # $gameTemp._battler_bhp_temp[2]
var digits: Array = []    # 当前数字字符串拆成的字符
var first_frame := true
var _temp_target = null
var _temp_hp := 0.0
var _temp_shake := 0
var _known := {}          # 敌人 → 上一帧读到的血量（命中前的血量）
var _ext_flags := {}      # 敌人 → 是否 v0.37 范围内（开战时定，不随变身变）
var _meter_flags := {}    # 敌人 → 曾经算过 Boss（_bosshp_meter 一旦为真不再清）
var _rng := RandomNumberGenerator.new()
var _name_canvas: XMVCanvas
var _name_text := ""
var _face_tex: Texture2D = null
var _base_y := 0.0
var _enemies: Array = []   # 开战时的敌群（同一个数组，现身／变身后再挑）
var _shown_id := 0         # 名字、头像对应的敌人编号


static func params() -> Dictionary:
	return XDB.plugin("MOG_BossHP")


static func _num(key: String, fallback: float) -> float:
	var p := params()
	var s := str(p.get(key, "")).strip_edges()
	return float(s) if s != "" else fallback


## 固定框左上角（平移-固定框 X／Y）
static func layout_pos() -> Vector2:
	return Vector2(_num("平移-固定框 X", 150.0), _num("平移-固定框 Y", 10.0))


## 固定框底边的 y（框图高 78）；Boss 状态面板的折叠栏贴在它下面
static func layout_bottom() -> float:
	return layout_pos().y + 78.0


static func boss_list() -> Dictionary:
	if _boss_list.is_empty():
		var p := params()
		for i in range(1, LIST_LENGTH + 1):
			var raw := str(p.get("boss-%d" % i, "0")).strip_edges()
			var id := int(raw) if raw.is_valid_int() else 0
			if id > 0:
				_boss_list[id] = str(p.get("boss-%d-头像" % i, "")).strip_edges()  # 同一编号多次出现，后面的盖前面的
	return _boss_list


## checkBossHPnoteTag：敌人编号在插件参数的 Boss 名单里
static func is_listed(enemy_id: int) -> bool:
	return boss_list().has(enemy_id)


## Z.bossHpEnemy：神兵之仙（WEAPON_BOSS 或备注标签）或在心魔／天劫／心魔训练敌群里；插件名单里的不算（_codexZqBossHp＝没有 _bosshp_meter）
static func is_extended(enemy_id: int) -> bool:
	if not RANGE_V037 or is_listed(enemy_id):
		return false
	if not _ext_cache.has(enemy_id):
		_ext_cache[enemy_id] = _in_extended_range(enemy_id)
	return bool(_ext_cache[enemy_id])


static var _ext_cache := {}


static func _in_extended_range(enemy_id: int) -> bool:
	if XZhenqi.WEAPON_BOSS.has(enemy_id):
		return true
	var tag := RegEx.create_from_string("<CodexZhenqi:\\s*weapon\\s+\\d+>")
	if tag.search(str(XDB.rec("Enemies", enemy_id).get("note", ""))) != null:
		return true
	var troops := []
	troops.append_array(XZhenqi.TRIAL_TROOP.values())
	troops.append_array(XZhenqi.HEART_TROOP.values())
	for tid in troops:
		for m in XDB.rec("Troops", int(tid)).get("members", []):
			if int(m.get("enemyId", 0)) == enemy_id:
				return true
	return false


## 敌人头上的小血条：YEP 的 hpGaugeVisible，再加上 v0.37 的 hpGaugeVisible 包装（显示首领血条的敌人不出小血条）
static func small_gauge_visible(e) -> bool:
	return e.hp_gauge_visible() and not is_extended(int(e.enemy_id))


static func face_name(enemy_id: int) -> String:
	return str(boss_list().get(enemy_id, ""))


static func _tex(folder: String, file: String) -> Texture2D:
	if file == "":
		return null
	var p := XDB.img_path(folder, file)
	if p == "":
		return null
	if not _tex_cache.has(p):
		_tex_cache[p] = load(p)
	return _tex_cache[p]


## Game_Enemy._bosshp_meter：名单里有就永远算（变身后也不清）
func is_meter(e) -> bool:
	if not (e is XEnemy):
		return false
	if _meter_flags.has(e):
		return true
	if is_listed(int(e.enemy_id)):
		_meter_flags[e] = true
		return true
	return false


## v0.37 _codexZqBossHp：非名单、但属于上面范围的敌人
func is_extended_enemy(e) -> bool:
	if not (e is XEnemy):
		return false
	if _ext_flags.has(e):
		return bool(_ext_flags[e])
	_ext_flags[e] = not is_meter(e) and is_extended(int(e.enemy_id))
	return bool(_ext_flags[e])


## checkBossHpEnemies：敌群里最后一个是 Boss 且未隐藏的（v0.37 起名单里没有时再取范围内最后一个）
func pick(enemies: Array):
	var found = null
	for e in enemies:
		if is_meter(e) and not e.hidden:
			found = e
	if found == null and RANGE_V037:
		for e in enemies:
			if is_extended_enemy(e) and not e.hidden:
				found = e
	return found


## 开战建条：没有 Boss 就什么都不画
func setup(enemies: Array) -> void:
	_rng.randomize()
	_enemies = enemies
	for e in enemies:
		_known[e] = _read(e).hp
	battler = pick(enemies)
	if battler == null:
		visible = false
		return
	_build()


func _build() -> void:
	visible = true
	_temp_target = battler
	_temp_hp = _known[battler]
	position = layout_pos()
	_base_y = position.y
	_face_tex = _tex("bosshp", face_name(int(battler.enemy_id)))
	_name_canvas = XMVCanvas.new()
	_name_canvas.size = Vector2(300, 48)
	_name_canvas.position = Vector2(_num("平移-boss名 X", 36.0), _num("平移-boss名 Y", 23.0))
	_name_canvas.painter = _paint_name
	add_child(_name_canvas)
	_name_text = _enemy_name(battler)
	_shown_id = int(battler.enemy_id)
	hp_red = _read(battler).mhp
	hp_number = 0.0
	_refresh_number()


func _read(e) -> Dictionary:
	if hp_source.is_valid():
		return hp_source.call(e)
	return {"hp": e.hp, "mhp": e.mhp, "dead": e.is_dead()}


func _enemy_name(e) -> String:
	return e.original_name()


## Game_Action.apply：命中 Boss 时记目标、命中前血量、是否掉血（掉血 → 震动 80 帧）
func applied(target, hp_after: float) -> void:
	if battler == null or not (is_meter(target) or is_extended_enemy(target)):
		return
	_temp_target = target
	_temp_hp = float(_known.get(target, hp_after))
	_temp_shake = SHAKE_FRAMES if _temp_hp > hp_after else 0
	_known[target] = hp_after


## processVictory／processAbort／processDefeat
func ended() -> void:
	ended_flag = true


func _need_fade() -> bool:
	if busy_source.is_valid() and busy_source.call():
		return true
	if ended_flag or battler == null:
		return true
	return bool(_read(battler).dead)


func _physics_process(_delta: float) -> void:
	step()


## Sprite_BossHP.update 一帧
func step() -> void:
	if battler == null:
		if not REBUILD or ended_flag:
			return
		battler = pick(_enemies)
		if battler == null:
			return
		for e in _enemies:
			if not _known.has(e):
				_known[e] = _read(e).hp
		_build()
	if REBUILD and int(battler.enemy_id) != _shown_id:
		_refresh_identity()
	var speed := _num("流动速度", 4.0)
	var flowing := str(params().get("生命条是否流动", "true")) == "true"
	var period := 1392.0 / 3.0 * 2.0 if flowing else 0.0
	if flowing:
		flow += speed
		if flow > period:
			flow = 0.0
	if _temp_shake != 0:
		shake = _temp_shake
		_temp_shake = 0
	_fade()
	if _temp_target != battler:
		_refresh_all()
	var r := _read(battler)
	var hp: float = r.hp
	position.y = _base_y  # refresh_blue_meter 每帧把 y 归位
	if hp_red != hp:
		var d := red_step(hp)
		if hp_red > hp:
			hp_red = maxf(hp_red - d, hp)
		else:
			hp_red = minf(hp_red + d, hp)
	if hp_number != hp:
		var n := number_step(hp)
		if hp_number < hp:
			hp_number = minf(hp_number + n, hp)
		else:
			hp_number = maxf(hp_number - n, hp)
		_refresh_number()
	if str(params().get("受伤是否震动头像", "true")) == "true" and shake > 0:
		shake -= 1
		position.y = -3.0 + _base_y + floorf(_rng.randf() * 6.0)
		if shake <= 0:
			position.y = _base_y
	first_frame = false
	for e in _known:
		_known[e] = _read(e).hp
	if _name_canvas != null:
		_name_canvas.modulate.a = layout_alpha / 255.0
		_name_canvas.queue_redraw()
	queue_redraw()


func _fade() -> void:
	if first_frame:
		layout_alpha = 255
		return
	layout_alpha = clampi(layout_alpha + (-5 if _need_fade() else 5), 0, 255)


## 优化 O-188（ui11）：原版红条每帧走 1+差/160，差越大越慢收拢（千万级血量一下打掉要拖几十秒）。
## 开着时每次目标血量变了重新计 RED_CAP_FRAMES 帧，每帧至少走「剩余差 ÷ 剩余帧」，所以最迟约 1.5 秒追上；
## 小伤害原版本来就更快，照原版。RED_TRAIL_CAP = false 回到原版。
static var RED_TRAIL_CAP := true
const RED_CAP_FRAMES := 90
var _red_target := INF
var _red_left := 0


func red_step(hp: float) -> float:
	var diff := absf(hp_red - hp)
	var d := 1.0 + diff / 160.0
	if not RED_TRAIL_CAP:
		return d
	if hp != _red_target:
		_red_target = hp
		_red_left = RED_CAP_FRAMES
	var cap := diff / maxf(1.0, float(_red_left))
	_red_left = maxi(1, _red_left - 1)
	return maxf(d, cap)


## 优化 O-237（ui5）：原版数字每帧追 1+⌊差/30⌋，也是越大越慢（差 1 万 188 帧、千万 392 帧约 6.5 秒、十亿 528 帧；
## 开战从 0 爬到满也是），红条已封顶（O-188）后数字反倒比红条慢得多。开着时同红条的做法：每次目标血量变了重新计
## NUMBER_CAP_FRAMES 帧，每帧至少走 ⌈剩余差 ÷ 剩余帧⌉（取整，数字不出小数），最迟约 0.75 秒到位、先于红条；
## 前面几帧仍是原版步长，只截掉尾巴；差 < 65 原版本来 45 帧内就到，跟原版一样。
## NUMBER_CAP = false 回到原版。
static var NUMBER_CAP := true
const NUMBER_CAP_FRAMES := 45
var _num_target := INF
var _num_left := 0


func number_step(hp: float) -> float:
	var diff := absf(hp_number - hp)
	var n := 1.0 + floorf(diff / 30.0)
	if not NUMBER_CAP:
		return n
	if hp != _num_target:
		_num_target = hp
		_num_left = NUMBER_CAP_FRAMES
	var cap := ceilf(diff / maxf(1.0, float(_num_left)))
	_num_left = maxi(1, _num_left - 1)
	return maxf(n, cap)


## refresh_all：条换到另一个 Boss
func _refresh_all() -> void:
	battler = _temp_target
	hp_red = _temp_hp
	hp_number = _temp_hp
	_num_target = INF
	_refresh_number()
	_name_text = _enemy_name(battler)
	_shown_id = int(battler.enemy_id)
	var id := int(battler.enemy_id)
	if is_listed(id):
		_face_tex = _tex("bosshp", face_name(id))


## 条跟着的敌人变身了：名字、头像换成新编号的（REBUILD）
func _refresh_identity() -> void:
	_name_text = _enemy_name(battler)
	_shown_id = int(battler.enemy_id)
	_face_tex = _tex("bosshp", face_name(_shown_id))


## 数字字符串（单位、小数位规则同原版）
static func format_number(value: float) -> String:
	var unit := 0
	var shown := value
	for i in range(UNIT_THRESHOLDS.size() - 1, -1, -1):
		if value >= UNIT_THRESHOLDS[i]:
			shown = value / UNIT_THRESHOLDS[i]
			unit = i
			break
	if unit == 0:
		return str(int(floorf(shown)))
	var places := 0
	if shown < 100.0:
		places = 2
	elif shown < 1000.0:
		places = 1
	var text := _to_fixed(shown, places)
	if places > 0:
		text = RegEx.create_from_string("\\.?0+$").sub(text, "")
	return text + UNITS[unit]


## JS Number.toFixed：恰好一半时取大
static func _to_fixed(x: float, places: int) -> String:
	var scale := pow(10.0, places)
	var n := floorf(x * scale + 0.5)
	var s := str(int(n))
	if places == 0:
		return s
	while s.length() <= places:
		s = "0" + s
	return s.substr(0, s.length() - places) + "." + s.substr(s.length() - places)


func _refresh_number() -> void:
	if str(params().get("是否显示生命数值", "true")) != "true":
		digits = []
		return
	var limit := int(_num("生命数值最大显示位", 6.0))
	var text := format_number(hp_number)
	digits = []
	for i in range(mini(text.length(), limit)):
		digits.append(text[i])


static func digit_frame(ch: String) -> int:
	match ch:
		"万": return 10
		"亿": return 11
		"兆": return 12
		"京": return 13
		".": return 14
	return maxi(0, int(ch)) if ch.is_valid_int() else 0


## 名字颜色：EnemyNameColorByDifficulty 改了 Bitmap.drawText，与数据库敌人原名相同的文字换成难度色（普通天蓝等）；
## refresh_name 画的正是 enemy().name，所以 Boss 血条上的名字也是难度色（原版读数：难度 3 画成 #4499ff；
## 重制原来一直白字，八戒 rules-battle-pixel 截图对照查出）。
func name_color() -> Color:
	if battler == null or not ("difficulty_id" in battler):
		return Color.WHITE
	return XEnemy.name_color(_name_text, int(battler.difficulty_id), Color.WHITE)


func _paint_name(c: XMVCanvas) -> void:
	c.text(_name_text, 0, 0, 300, "left", name_color(), int(_num("boss名字体大小", 18.0)), 48)


func _draw() -> void:
	if battler == null or layout_alpha <= 0:
		return
	var col := Color(1, 1, 1, layout_alpha / 255.0)
	var a := _tex("bosshp", str(params().get("资源-固定框", "")))
	if a != null:
		draw_texture(a, Vector2.ZERO, col)
	var b := _tex("bosshp", str(params().get("资源-生命条", "")))
	if b != null:
		var origin := Vector2(_num("平移-生命条 X", 22.0), _num("平移-生命条 Y", 28.0))
		var flowing := str(params().get("生命条是否流动", "true")) == "true"
		var seg := float(b.get_width()) / 3.0 if flowing else float(b.get_width())
		var half := float(b.get_height()) / 2.0
		var r := _read(battler)
		var mhp: float = maxf(float(r.mhp), 1.0)
		var fx := flow if flowing else 0.0
		var red_w := seg * hp_red / mhp
		if red_w > 0.0:
			# 红条与蓝条同一坐标（原版 _hp_meter_red.y＝_hp_meter_blue.y），只是取图的下半；蓝条盖在上面，掉血后才露出右边一截。
			# 重制原来画到下一行（y＋半高），满血也多一道紫红带子（八戒 rules-battle-pixel 截图对照）。
			draw_texture_rect_region(b, Rect2(origin, Vector2(red_w, half)), Rect2(fx, half, red_w, half), col)
		var blue_w := seg * float(r.hp) / mhp
		if blue_w > 0.0:
			draw_texture_rect_region(b, Rect2(origin, Vector2(blue_w, half)), Rect2(fx, 0, blue_w, half), col)
	if _face_tex != null:
		draw_texture(_face_tex, Vector2(_num("平移-头像 X", -50.0), _num("平移-头像 Y", 10.0)), col)
	var n := _tex("bosshp", str(params().get("资源-生命数值", "")))
	if n != null:
		var w := float(n.get_width()) / DIGIT_FRAMES
		var h := float(n.get_height())
		var nx := _num("平移-生命数值 X", 460.0)
		var ny := _num("平移-生命数值 Y", 32.0)
		for i in range(digits.size()):
			draw_texture_rect_region(n, Rect2(nx + 20.0 * i, ny, w, h), Rect2(digit_frame(digits[i]) * w, 0, w, h), col)
