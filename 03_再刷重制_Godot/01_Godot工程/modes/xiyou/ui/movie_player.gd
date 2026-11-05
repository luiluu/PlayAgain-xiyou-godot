class_name XMoviePlayer
extends CanvasLayer
## 事件指令 261 播放电影（Graphics.playVideo，原版只有宇智波鼬 CE1514「血轮眼开」、CE1516「幻术世界」两段，都在战斗里）。
## 原版：<video> 盖在画布上（zIndex 2）、播放期间画布透明（_updateVisibility），大小同游戏画面 1280×720，音量＝主音量；
## 解释器等待到片子放完（waitMode 'video'），不能跳过；$.toaster 提示（zIndex 50000）仍在片子上面。
## Godot 4 放不了 WebM，转换器把片子转成 movies/<名>/0001.jpg… 逐帧图＋ movies/<名>.ogg 音轨＋ movies/<名>.json {fps, frames}
## （xiyou_export.py export_movie），这里按经过的时间逐帧换图，同时放音轨；放完发 finished 并移除自己。

signal finished

const LAYER := 89          # 在 XToast（90）下面、地图与战斗画面上面
static var played: Array = []   # 放过的片名（测试核对用）

var movie := ""
var fps := 30.0
var frames := 0
var shown := -1            # 当前显示的帧（0 起）
var elapsed := 0.0
var _start_ms := 0
var _rect: TextureRect
var _audio: AudioStreamPlayer


static func info(name: String) -> Dictionary:
	var path := "%smovies/%s.json" % [XDB.BASE, name]
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary and int(data.get("frames", 0)) > 0 else {}


static func frame_path(name: String, i: int) -> String:
	return "%smovies/%s/%04d.jpg" % [XDB.BASE, name, i + 1]


## 开始放一段片子，返回播放器（await 它的 finished）；没有转出的片子（云端缺 ffmpeg 等）返回 null，调用方照常往下走
static func start(name: String) -> XMoviePlayer:
	played.append(name)
	var meta := info(name)
	var tree := Engine.get_main_loop() as SceneTree
	if meta.is_empty() or tree == null:
		return null
	var p := XMoviePlayer.new()
	p.movie = name
	p.fps = maxf(float(meta.get("fps", 30)), 1.0)
	p.frames = int(meta.frames)
	tree.root.add_child(p)
	return p


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := ColorRect.new()
	back.color = Color.BLACK   # 画布透明后露出的是网页底色（黑）
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP   # 放映期间挡住画面下面的点击
	add_child(back)
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	var ogg := "%smovies/%s.ogg" % [XDB.BASE, movie]
	if ResourceLoader.exists(ogg):
		_audio = AudioStreamPlayer.new()   # 主音量（Graphics.setVideoVolume ← AudioManager.masterVolume），不走四条分类总线
		_audio.stream = load(ogg)
		add_child(_audio)
		_audio.play()
	_show(0)
	_start_ms = Time.get_ticks_msec()


## 按墙钟算帧（不累加 delta：首帧的 delta 带着载入时间，会让片子提前放完、与音轨错开）
func _process(_delta: float) -> void:
	elapsed = (Time.get_ticks_msec() - _start_ms) / 1000.0
	var f := int(elapsed * fps)
	if f >= frames:
		set_process(false)
		if _audio != null:
			_audio.stop()
		finished.emit()
		queue_free()
		return
	if f != shown:
		_show(f)


func _show(i: int) -> void:
	var p := frame_path(movie, i)
	if ResourceLoader.exists(p):
		_rect.texture = load(p)   # 只留当前一帧（1280×720 共 160 多帧，全载进来太占内存）
	shown = i
