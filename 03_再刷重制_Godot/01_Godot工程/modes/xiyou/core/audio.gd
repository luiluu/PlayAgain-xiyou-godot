class_name XAudio
extends RefCounted
## 西游四条总线：配置音量×事件本身音量，设置立即影响已在播放的声音。
const SYMBOLS := {"BGM": "bgmVolume", "BGS": "bgsVolume", "ME": "meVolume", "SE": "seVolume"}

static func bus(channel: String) -> String:
	return "Xiyou" + channel

static func ensure_buses() -> void:
	for channel in SYMBOLS:
		if AudioServer.get_bus_index(bus(channel)) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus(channel))
			AudioServer.set_bus_send(i, "Master")

static func apply_volumes(values: Dictionary) -> void:
	ensure_buses()
	for channel in SYMBOLS:
		var i := AudioServer.get_bus_index(bus(channel))
		var percent := clampi(int(values.get(SYMBOLS[channel], 40)), 0, 100)
		AudioServer.set_bus_mute(i, percent == 0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxi(percent, 1) / 100.0))

static func bind(player: AudioStreamPlayer, channel: String) -> void:
	XConfig.ensure_loaded()
	ensure_buses()
	player.bus = bus(channel)

## AudioManager._replayFadeTime：ME 放完（stopMe）、战斗结束回放地图曲（replayBgm）时 BGM 淡入的秒数
const REPLAY_FADE := 0.5

## WebAudio.fadeIn：增益从 0 线性升到原音量（按线性增益走，不是按分贝）。播放器不在树里时不淡（直接原音量）
static func fade_in(player: AudioStreamPlayer, seconds := REPLAY_FADE) -> void:
	if player == null or not player.is_inside_tree():
		return
	# 上一次还没淡完：先收掉，目标音量用上一次记下的（不然会把半路的小音量当目标）
	var old = player.get_meta("fade_tween") if player.has_meta("fade_tween") else null
	var target := player.volume_db
	if old is Tween and old.is_valid():
		old.kill()
		target = float(player.get_meta("fade_target", target))
	player.set_meta("fade_target", target)
	var gain := db_to_linear(target)
	player.volume_db = -80.0
	var t := player.create_tween()
	player.set_meta("fade_tween", t)
	t.tween_method(func(k: float): player.volume_db = linear_to_db(maxf(k * gain, 0.0001)), 0.0, 1.0, seconds)
	t.tween_callback(func(): player.volume_db = target)

## 收掉还在走的淡入（换歌、改音量前调用），音量回到淡入的目标值
static func stop_fade(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var old = player.get_meta("fade_tween") if player.has_meta("fade_tween") else null
	if old is Tween and old.is_valid():
		old.kill()
		player.volume_db = float(player.get_meta("fade_target", player.volume_db))
	if player.has_meta("fade_tween"):
		player.remove_meta("fade_tween")
