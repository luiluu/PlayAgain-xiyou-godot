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
