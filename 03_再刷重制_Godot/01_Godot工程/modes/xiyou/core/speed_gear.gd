class_name XSpeedGear
## 原版 Drill_SpeedGear「变速齿轮」（v0.28 与 v0.62.12 都启用，参数「初始齿轮速度」1.6）：Game_System.initialize 把
## SceneManager._deltaTime 设成 1/60/1.6，MV 主循环（updateMain 的累加器）每真实秒跑 96 次 updateScene——地图、战斗、菜单
## 所有按帧计的东西都快 1.6 倍（Kyo 11-06 实机：「原版动作稍快」）。绑定变量关、数据里没有「>变速齿轮」插件指令，所以全程固定。
## 声音：AudioManager.updateBufferParameters 被它覆写成 pitch = 原 pitch + (齿轮 − 1) × 声音变速同步率 0.10（1.6 时 +0.06，
## 播放速率随之加快）。
## 重制照做：物理帧率 60 × 齿轮、Engine.time_scale = 齿轮（物理帧的 delta 仍是 1/60 秒，逐帧逻辑、计时器、补间同比加快，
## 同测试快进 GameApp.fast_forward 的做法）；声音用 AudioServer.playback_speed_scale = 1 + (齿轮 − 1) × 同步率
## （原版是加在各自 pitch 上，pitch 100 时相同，其它 pitch 差不到 1%）。
## 复现原版，不登记 O 号；ENABLED = false 回到重制原来的 60 帧／秒（回退开关）。
## headless（测试）不改：测试按物理帧比对，快进由 GameApp.fast_forward 管。

static var ENABLED := true
## 测试用：headless 下也照设（tests/xiyou_speed_gear 断言入口确实设了倍率）
static var HEADLESS_APPLY := false

## set_engine 设下的 time_scale（齿轮那一份）；play_seconds 等按真实时间计的量用 real_seconds 把它除掉
static var engine_rate := 1.0

const BASE_TICKS := 60
const BASE_STEPS := 8


## 当前齿轮速度（插件没启用或开关关时为 1）
static func rate() -> float:
	if not ENABLED:
		return 1.0
	var p := XDB.plugin("Drill_SpeedGear")
	if p.is_empty():
		return 1.0
	return maxf(0.05, float(p.get("初始齿轮速度", "1")))


## 声音速率倍数（声音是否变速关时为 1）
static func sound_scale() -> float:
	var p := XDB.plugin("Drill_SpeedGear")
	if not ENABLED or p.is_empty() or str(p.get("声音是否变速", "true")) != "true":
		return 1.0
	return 1.0 + (rate() - 1.0) * float(p.get("声音变速同步率", "0.25"))


## 进西游模式时调用（标题）
static func apply() -> void:
	if DisplayServer.get_name() == "headless" and not HEADLESS_APPLY:
		return
	set_engine(rate(), sound_scale())


## 回模式选择时还原
static func reset() -> void:
	set_engine(1.0, 1.0)


static func set_engine(r: float, sound: float) -> void:
	var ticks := maxi(1, roundi(BASE_TICKS * r))
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = maxi(BASE_STEPS, ceili(BASE_STEPS * r))
	Engine.time_scale = float(ticks) / BASE_TICKS
	engine_rate = Engine.time_scale
	AudioServer.playback_speed_scale = sound


## 原版游戏时间 playtime() 是 Graphics.frameCount / 60：frameCount 每次 render 加 1，齿轮只让 updateScene 多跑、不多 render，
## 所以游戏时间按真实时间走、不随齿轮变快（审查第 52 期 P2-2）。_process 的 delta 乘过 time_scale，这里除掉齿轮那一份；
## 别的倍率（测试快进、平台离线追帧 CATCH_UP_SPEED）照旧算进去。
static func real_seconds(delta: float) -> float:
	return delta / maxf(0.05, engine_rate)
