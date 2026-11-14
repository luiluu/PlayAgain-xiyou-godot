class_name XHangUp
extends RefCounted
## XdRs_HangUp「真·在线挂机」第一批：开关、范围内随机走动遇敌、自动战斗、战后死亡停止、定时自动存档、挂机计时。
## 地图的面板/横幅在 map/hang_up_overlay.gd，接线在 XMapScene；设置页在 ui/hang_up_options.gd（主菜单 → 设置 → 挂机设置）。
## 第二批已接：快速战斗、三种逃跑、屏蔽掉落（见下）；技能次数/顺序、自动吃药、自动卖出在 core/hang_up_auto.gd。
## - 开启（G 键或面板按钮）：挂机禁用（插件指令 ProhibitHangUp）时只清除状态；当前地图有遇敌表才开始（确定音、
##   以玩家位置为原点），否则蜂鸣并提示「这个地图没有敌人！」。关闭：取消音，挂机时长计入总计。
## - 明雷怪（事件备注 <Enemy>）：正式全部地图都没有这种事件，不做；有无敌人只看遇敌表。
## - 挂机中：玩家不能手动移动、不能开菜单；不在移动时，离原点曼哈顿距离 ≤ 范围就随机走一步，否则朝原点走
##   （moveTowardPosition：先走差距大的方向，走不通再走另一方向）。战斗中队员按自动战斗行动，胜利不显示结算。
## - 每次战斗结束（不论是否挂机）：死亡停止开着且队伍里有人阵亡就停止挂机（O-016：原版不在挂机时也播一声取消音）。
## - 自动存档：挂机计时每满 10 分钟（saveMnt）记一次，回到地图时存到开局固定存档位并提示「已自动存储」；
##   正式版判断时没有看「自动储存」设置（needAutoSave 未被调用）；O-017 让该设置生效（AUTO_SAVE_SETTING）。
## - 读档后不在挂机（DataManager.loadGame 清除）：运行状态不进存档。
## - 快速战斗（isFastFighting＝挂机中且 fastFt）：插件跳过开战/胜利/失败/奖励信息与行动动画，但它在插件列表第 3 位，
##   开战信息与 Window_BattleLog.startAction 被后面的 YEP_BattleEngineCore 整个替换、胜利/奖励信息被 Olivia 结算取代，
##   v0.16 实测只剩「失败信息」会被跳过（挂机胜利本来不出任何信息）。
## - 逃跑（BattleManager.updateTurn）：每次处理回合前按敌群备注判断，成立就 processEscape（逃跑率 1，必定成功），
##   不看「能否逃跑」；任一敌人有 <DontEsc> 就不逃。规则见 should_escape。O-019：原版判断的是开始挂机时设的全局标记
##   GuaJiStartBettleOk（读档、回标题都不清除），这里改看是否正在挂机。
## - 屏蔽掉落（isDropShield＝挂机中且 DropShield）：掉落里旧品质 1/2/3（普通/优秀/精良）的武器防具去掉。

const DEFAULTS := {"range": 10, "showInter": true, "fastFt": false, "deathStop": true, "autoSave": true,
	"RareEscape": false, "UnprecedentedEscape": false, "CommonEscape": false, "DropShield": false}
## O-016：只在挂机中因阵亡停止时播放取消音；设 false 恢复原版（任何战斗结束有人阵亡都播）。
static var SILENT_WHEN_IDLE := true
## O-017：「自动储存」设置生效、说明写实际存档位（开局选的固定存档位）；设 false 恢复原版（开关无效、说明写 saveId 参数，空为 1）。
static var AUTO_SAVE_SETTING := true
## O-273：守层者等事件「你正在挂机，无法挑战」的门（条件脚本 XdRsData.hangUp.GuaJiStartBettleOk，14 个首领事件）。
## 原版看全局标记：开始挂机时设、按键停止时清，读档、回标题都不清，读档后没在挂机也会被拦；这里改看是否正在挂机。
## 设 false 恢复原版（看 started_flag：开始挂机时设、stop 时清，同一次运行内读档不清）。
static var GATE_ACTIVE_ONLY := true
## O-373：挂机被禁用（新游戏开局 Map001 就 ProhibitHangUp，要先按 L＝公共事件 484 或找大厅大工匠开启）时，
## 原版按 G 什么都不做、也没有提示，玩家以为挂机坏了（v0.01.06 玩家反馈）。这里改成按 G 时照 L 的公共事件走一遍：
## 副本外直接开启并提示「摆烂功能已开启」，副本里提示去传送门重置；开启后再按 G 才开始挂机。设 false 恢复原版（只清除状态）。
static var KEY_ENABLES := true
## 原版的 GuaJiStartBettleOk（只在 GATE_ACTIVE_ONLY＝false 时用）：运行期全局，不进存档
static var started_flag := false


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

## 当前存档在挂机（XPlatform.idle_probe 用：安卓后台补跑、挂机时不锁屏）。
static func current_active() -> bool:
	return XState.current != null and is_active(XState.current)


## O-379：触屏设备上挂机被禁用时，原版连快捷界面带按钮一起藏起来；安卓没有 L 键，只能回大厅找大工匠开（v0.01.07 Kyo 反馈安卓挂机开不了）。
## 这里触屏设备禁用时也显示快捷界面，点按钮走 XMapScene.toggle_hang_up：禁用时照 L 的公共事件 484 开启并提示（KEY_ENABLES）。
## 设 false 恢复原版（禁用时不显示）。桌面有 G／L 键，照原版藏着。
## 副本里（变量 21 非 0，进门时 ProhibitHangUp）原版本来就不能挂机，这里照原版藏起来（v0.01.09 玩家反馈「进副本挂机按钮也没消失」，
## O-379 原先连副本里也显示；点了只会提示去传送门重置）。只改副本这一处，开局 Map001 等其他禁用场景照 O-379 显示。
static var TOUCH_SHOW_PROHIBITED := true


static func inter_show(s: XState) -> bool:
	if s == null:
		return false
	return (enabled(s) or (TOUCH_SHOW_PROHIBITED and KEY_ENABLES and XPlatform.is_touch() and not XDungeon.inside(s))) and bool(settings(s).showInter)


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
	started_flag = true
	XHangUpAuto.on_start(s)
	return ""


## 事件条件脚本 XdRsData.hangUp.GuaJiStartBettleOk（mv_script eval_expr 的 hang_up_gate()），见 GATE_ACTIVE_ONLY
static func gate(s: XState) -> bool:
	return is_active(s) if GATE_ACTIVE_ONLY else started_flag


## 自动存档写入的存档位（设置页「自动储存」说明里的 \f）
static func auto_save_slot(s: XState) -> int:
	if AUTO_SAVE_SETTING:
		return int(s.flags.get("SaveGameId", 0)) if s else 0
	var v := str(params().get("saveId", ""))
	return int(v) if v.is_valid_int() and int(v) != 0 else 1


static func stop(s: XState) -> void:
	XSound.system(2)
	started_flag = false
	clear(s)
	XHangUpAuto.on_stop()


## 结束当前存档的挂机（XPlatform.idle_stopper：安卓通知上按了「停止挂机」，android-bgidle1）。
static func stop_current() -> void:
	if current_active():
		stop(XState.current)


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


static func fast_fighting(s: XState) -> bool:
	return is_active(s) and bool(settings(s).fastFt)


## XdRs_HangUp 的 BattleManager.updateTurn：逐个敌人逐行备注（按 [\r\n]+ 切开、整行比较）。
## 小怪逃跑开着时任何一行都算数，但遇到没开对应开关的「HangUp Rare / HangUp Unprecedented」行即中断（之后的敌人也不再算），
## 原版这样写的结果：只要敌群里有一只被排除的稀有/前所未见敌人就不逃。没开小怪逃跑时，有对应标记且开了对应开关才逃。
static func should_escape(s: XState, enemies: Array) -> bool:
	if not is_active(s):
		return false
	var cfg := settings(s)
	var common := bool(cfg.CommonEscape)
	var escape := false
	var broken := false
	for e in enemies:
		var note := RegEx.create_from_string("[\r\n]+").sub(str(e.data().get("note", "")), "\n", true)
		for line in note.split("\n"):
			var rare: bool = line == "HangUp Rare"
			var unseen: bool = line == "HangUp Unprecedented"
			if not ((rare and cfg.RareEscape) or (unseen and cfg.UnprecedentedEscape) or common):
				continue
			if common:
				if (unseen and not cfg.UnprecedentedEscape) or (rare and not cfg.RareEscape):
					broken = true
				if broken:
					escape = false
					break
			escape = true
	for e in enemies:
		if e.data().get("meta", {}).has("DontEsc"):
			return false
	return escape


## Game_Enemy.makeDropItems 的屏蔽：武器/防具里 meta.quality 正好是 "1"/"2"/"3" 的去掉（drops 为 {kind, id}）
static func shield_drops(s: XState, drops: Array) -> Array:
	if not (is_active(s) and bool(settings(s).DropShield)):
		return drops
	return drops.filter(func(d):
		var table: String = {2: "Weapons", 3: "Armors"}.get(int(d.kind), "")
		return table == "" or not str(XDB.rec(table, int(d.id)).get("meta", {}).get("quality", "")) in ["1", "2", "3"])


static func in_range(origin: Vector2i, p: Vector2i, r: int) -> bool:
	return absi(p.x - origin.x) + absi(p.y - origin.y) <= r


## 下一步要试的方向（按顺序，走通一个即止）。随机走动 moveRandom＝2/4/6/8 任一；回原点同 moveTowardPosition。
## back_to：回原点时朝向的格子，循环地图上传离 at 较近的那一份原点（deltaXFrom），默认原点本身；范围仍按原点直接相减（distanceX）
static func next_dirs(s: XState, at: Vector2i, back_to = null) -> Array:
	var o := s.hang_up_origin
	if in_range(o, at, int(settings(s).range)):
		return [2 + s.world_random().next_int_inclusive(0, 3, "hang_up_direction") * 2]
	return toward(at, o if back_to == null else back_to)


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
