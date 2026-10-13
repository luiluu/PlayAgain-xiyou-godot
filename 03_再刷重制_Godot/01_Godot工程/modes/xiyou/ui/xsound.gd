class_name XSound
extends RefCounted
## 界面音效（MV SoundManager / AudioManager.playSe）：可重叠播放，音量按 MV 线性比例（90 → 0.9），音高 100 = 原速。
## system(n) 取 System.json sounds[n]：0 光标、1 确定、2 取消、3 蜂鸣……

const POOL := 8
static var _players: Array = []
static var _next := 0
static var _cache := {}


static func play(name: String, volume := 90, pitch := 100) -> void:
	if name == "":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not _cache.has(name):
		var p := XDB.audio_path("se", name)
		_cache[name] = load(p) if p != "" else null
	var stream: AudioStream = _cache[name]
	if stream == null:
		return
	if _players.is_empty() or not is_instance_valid(_players[0]):
		_players.clear()
		for i in range(POOL):
			var a := AudioStreamPlayer.new()
			tree.root.add_child.call_deferred(a)
			_players.append(a)
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	if not player.is_inside_tree():
		return
	player.stream = stream
	player.volume_db = linear_to_db(maxf(volume, 1) / 100.0)
	player.pitch_scale = maxf(pitch, 10) / 100.0
	player.play()


static func system(index: int) -> void:
	var sounds: Array = XDB.system().get("sounds", [])
	if index < 0 or index >= sounds.size() or not sounds[index] is Dictionary:
		return
	var s: Dictionary = sounds[index]
	play(str(s.get("name", "")), int(s.get("volume", 90)), int(s.get("pitch", 100)))
