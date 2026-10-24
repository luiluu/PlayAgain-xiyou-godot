class_name XScreenFx
extends RefCounted
## $gameScreen 的色调与天气（指令 223 更改画面色调、236 设置天气）；随 XState 存档。
## 逐帧更新同 Game_Screen.updateTone／updateWeather（每帧一次，由地图场景在物理帧里调用 update）。

var tone := [0.0, 0.0, 0.0, 0.0]          # [红, 绿, 蓝, 灰度]，-255～255 / 0～255
var tone_target := [0.0, 0.0, 0.0, 0.0]
var tone_duration := 0
var weather_type := "none"                # none / rain / storm / snow
var weather_power := 0.0
var weather_power_target := 0.0
var weather_duration := 0


## Game_Screen.startTint
func start_tint(t: Array, duration: int) -> void:
	tone_target = [float(t[0]), float(t[1]), float(t[2]), float(t[3])]
	tone_duration = duration
	if tone_duration == 0:
		tone = tone_target.duplicate()


## Game_Screen.changeWeather：type 为 none 且 duration>0 时保留原类型，渐弱到 0 后才变 none
func change_weather(type: String, power: int, duration: int) -> void:
	if type != "none" or duration == 0:
		weather_type = type
	weather_power_target = 0.0 if type == "none" else float(power)
	weather_duration = duration
	if duration == 0:
		weather_power = weather_power_target


func update() -> void:
	if tone_duration > 0:
		var d := float(tone_duration)
		for i in range(4):
			tone[i] = (tone[i] * (d - 1.0) + tone_target[i]) / d
		tone_duration -= 1
	if weather_duration > 0:
		var d := float(weather_duration)
		weather_power = (weather_power * (d - 1.0) + weather_power_target) / d
		weather_duration -= 1
		if weather_duration == 0 and weather_power_target == 0.0:
			weather_type = "none"


func has_tone() -> bool:
	return tone[0] != 0.0 or tone[1] != 0.0 or tone[2] != 0.0 or tone[3] != 0.0


## 事件对照用的终态：色调取目标值，天气只在目标强度不为 0 时记类型（渐弱中的旧类型不算）
func target_snapshot() -> Dictionary:
	return {"tone": tone_target.duplicate(), "weather": weather_type if weather_power_target != 0.0 else "none",
		"power": weather_power_target}


func to_dict() -> Dictionary:
	return {"tone": tone, "toneTarget": tone_target, "toneDuration": tone_duration, "weatherType": weather_type,
		"weatherPower": weather_power, "weatherPowerTarget": weather_power_target, "weatherDuration": weather_duration}


static func from_dict(d) -> XScreenFx:
	var s := XScreenFx.new()
	if not d is Dictionary:
		return s
	for key in ["tone", "toneTarget"]:
		var a = d.get(key, [])
		if a is Array and a.size() == 4:
			var arr := [float(a[0]), float(a[1]), float(a[2]), float(a[3])]
			if key == "tone":
				s.tone = arr
			else:
				s.tone_target = arr
	s.tone_duration = int(d.get("toneDuration", 0))
	var wt := str(d.get("weatherType", "none"))
	s.weather_type = wt if ["none", "rain", "storm", "snow"].has(wt) else "none"
	s.weather_power = float(d.get("weatherPower", 0.0))
	s.weather_power_target = float(d.get("weatherPowerTarget", 0.0))
	s.weather_duration = int(d.get("weatherDuration", 0))
	return s
