class_name XHangUp
extends RefCounted
## XdRs_HangUp「真·在线挂机」第一批：开关、范围内随机走动遇敌、自动战斗、战后死亡停止、定时自动存档、挂机计时。
## 地图的面板/横幅在 map/hang_up_overlay.gd，接线在 XMapScene。设置页（范围、快捷界面、快速战斗、逃跑、技能顺序、
## 自动吃药、自动卖出、屏蔽掉落）是第二批；设置值已按正式版默认存在 XState.hang_up 里。
## - 开启（G 键或面板按钮）：挂机禁用（插件指令 ProhibitHangUp）时只清除状态；当前地图有遇敌表才开始（确定音、
##   以玩家位置为原点），否则蜂鸣并提示「这个地图没有敌人！」。关闭：取消音，挂机时长计入总计。
## - 明雷怪（事件备注 <Enemy>）：正式全部地图都没有这种事件，不做；有无敌人只看遇敌表。
## - 挂机中：玩家不能手动移动、不能开菜单；不在移动时，离原点曼哈顿距离 ≤ 范围就随机走一步，否则朝原点走
##   （moveTowardPosition：先走差距大的方向，走不通再走另一方向）。战斗中队员按自动战斗行动，胜利不显示结算。
## - 每次战斗结束（不论是否挂机）：死亡停止开着且队伍里有人阵亡就停止挂机（O-016：原版不在挂机时也播一声取消音）。
## - 自动存档：挂机计时每满 10 分钟（saveMnt）记一次，回到地图时存到开局固定存档位并提示「已自动存储」；
##   正式版判断时没有看「自动储存」设置（needAutoSave 未被调用）；O-017 让该设置生效（AUTO_SAVE_SETTING）。
## - 读档后不在挂机（DataManager.loadGame 清除）：运行状态不进存档。

const DEFAULTS := {"range": 10, "showInter": true, "fastFt": false, "deathStop": true, "autoSave": true,
	"RareEscape": false, "UnprecedentedEscape": false, "CommonEscape": false, "DropShield": false}
## O-016：只在挂机中因阵亡停止时播放取消音；设 false 恢复原版（任何战斗结束有人阵亡都播）。
const SILENT_WHEN_IDLE := true
## O-017：「自动储存」设置生效、说明写实际存档位（开局选的固定存档位）；设 false 恢复原版（开关无效、说明写 saveId 参数，空为 1）。
const AUTO_SAVE_SETTING := true


static func params() -> Dictionary:
	return XDB.plugin("XdRs_HangUp")


static func settings(s: XState) -> Dictionary:
	for k in DEFAULTS:
		if not s.hang_up.has(k):
			s.hang_up[k] = DEFAULTS[k]
	return s.hang_up


static func enabled(s: XState) -> bool:
	return s != null and not bool(s.flags.get("HangUpProhibited", false))


static func is_active(s: XState) -> bool:
	return enabled(s) and s.hang_up_active and s.hang_up_origin.x >= 0


static func inter_show(s: XState) -> bool:
	return enabled(s) and bool(settings(s).showInter)


## 挂机时长文字（不在挂机时「---」）
static func time_text(s: XState) -> String:
	if not is_active(s):
		return "---"
	var sec := floori(s.hang_up_count / 60.0)
	return "%02d:%02d:%02d" % [floori(sec / 3600.0), floori(sec / 60.0) % 60, sec % 60]


static func save_frames() -> int:
	return maxi(1, int(str(params().get("saveMnt", "1"))) if str(params().get("saveMnt", "")).is_valid_int() else 1) * 3600


## 开始（readyStart）。返回提示文字（空为无），由地图显示。
static func ready_start(s: XState, has_enemy: bool, at: Vector2i) -> String:
	if not enabled(s):
		clear(s)
		return ""
	if not has_enemy:
		XSound.system(3)
		return str(params().get("nmText", ""))
	XSound.system(1)
	s.hang_up_active = true
	s.hang_up_origin = at
	return ""


## 自动存档写入的存档位（设置页「自动储存」说明里的 \f）
static func auto_save_slot(s: XState) -> int:
	if AUTO_SAVE_SETTING:
		return int(s.flags.get("SaveGameId", 0)) if s else 0
	var v := str(params().get("saveId", ""))
	return int(v) if v.is_valid_int() and int(v) != 0 else 1


static func stop(s: XState) -> void:
	XSound.system(2)
	clear(s)


static func clear(s: XState) -> void:
	s.hang_up_active = false
	s.hang_up_origin = Vector2i(-1, -1)
	s.hang_up_total += s.hang_up_count
	s.hang_up_count = 0
	s.hang_up_save_pending = false


## 地图与战斗场景每帧（refreshHuTime）：计时，每满存档间隔记一次待存
static func tick(s: XState) -> void:
	if not is_active(s):
		return
	s.hang_up_count += 1
	var n := save_frames()
	if s.hang_up_count >= n and s.hang_up_count % n == 0 and (not AUTO_SAVE_SETTING or bool(settings(s).autoSave)):
		s.hang_up_save_pending = true


## 战斗结束（refrishHangUp）
static func after_battle(s: XState) -> void:
	if not bool(settings(s).deathStop):
		return
	if s.members().any(func(a): return a.is_dead()):
		if is_active(s) or not SILENT_WHEN_IDLE:
			stop(s)
		else:
			clear(s)


static func in_range(origin: Vector2i, p: Vector2i, r: int) -> bool:
	return absi(p.x - origin.x) + absi(p.y - origin.y) <= r


## 下一步要试的方向（按顺序，走通一个即止）。随机走动 moveRandom＝2/4/6/8 任一；回原点同 moveTowardPosition。
static func next_dirs(s: XState, at: Vector2i) -> Array:
	var o := s.hang_up_origin
	if in_range(o, at, int(settings(s).range)):
		return [2 + randi_range(0, 3) * 2]
	return toward(at, o)


static func toward(at: Vector2i, target: Vector2i) -> Array:
	var sx := at.x - target.x
	var sy := at.y - target.y
	var h := 4 if sx > 0 else 6
	var v := 8 if sy > 0 else 2
	if absi(sx) > absi(sy):
		return [h, v] if sy != 0 else [h]
	if sy != 0:
		return [v, h] if sx != 0 else [v]
	return []
