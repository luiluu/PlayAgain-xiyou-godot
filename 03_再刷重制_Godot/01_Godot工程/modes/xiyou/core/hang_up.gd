class_name XHangUp
extends RefCounted
## XdRs_HangUp「真·在线挂机」第一批：开关、范围内随机走动遇敌、自动战斗、战后死亡停止、定时自动存档、挂机计时。
## 地图的面板/横幅在 map/hang_up_overlay.gd，接线在 XMapScene；设置页在 ui/hang_up_options.gd（主菜单 → 设置 → 挂机设置）。
## 第二批已接：快速战斗、三种逃跑、屏蔽掉落（见下）；技能次数/顺序、自动吃药、自动卖出的子页与规则未做。
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
