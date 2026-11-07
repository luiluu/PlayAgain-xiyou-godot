class_name XAutoSave
extends RefCounted
## 安卓切后台自动存档（cc 平台 DT 2026-11-06，O-215·安卓切后台存档）。原版切后台只暂停、不存档，手机把游戏杀掉就丢掉
## 上次存档之后的进度；这里在切后台那一刻（APPLICATION_PAUSED，或手机上先到的 FOCUS_OUT）存一份到单独的自动存档文件
## （XSave.save_auto，不碰手动存档位）。只在地图上、事件不在跑（含商店等事件里开的页面）、不在战斗／主菜单／传送页时存；
## 同一次切后台的几个通知只写一次；写失败只记日志、不弹窗。桌面不触发。
## 回退：ON_PAUSE = false（切后台只暂停，同原版）。
## 检查点（cc 平台 EH 2026-11-07，Codex 报告第 5 项，O-221·自动存档检查点）：切后台时正开着菜单或在战斗里就存不了，
## 手机这时杀进程会丢掉上次存档后的进度；所以进主菜单时、开战前（地图上、事件没在跑时）也各存一份到同一个自动存档，
## 不存战斗中间态。
## 开战前的检查点（cc 平台 EJ 2026-11-07，审查第 51 期 P2-1）：原来放在 start_battle 里，可所有入口都先置了 busy，
## blocker 见 busy 就跳过，一次也没存过。改由各入口在置 busy／开打之前调 battle_checkpoint：随机遇敌在 _encounter
## 置 busy 前；事件战斗（指令 301）、小猫试炼、真气闭关在开打前，这三处是事件里开的战斗，busy 不算阻挡（读回来
## 事件会从头再跑，总装定接受）。挂机中跳过（挂机已有定时存）；不挂机时两次战斗检查点至少隔 BATTLE_GAP_MSEC。
## 回退：CHECKPOINTS = false（只在切后台时存）。
## 事件里开的战斗不存检查点（cc 平台 FB 2026-11-07，审查第 52 期 P2-1，并入 O-221）：存档不带解释器进度，
## 读回来事件不会重跑；可事件常是「先扣东西再开打」（Map207 奇兽地事件 3 先扣奇兽捕捉许可证再打 319，Map046／Map147
## 连战中间扣奖碑），301 那一刻存下的是「扣了、没打」，战斗里被杀、读回来东西没了、仗也没了。所以 in_event 的三处
## （301、小猫试炼、真气闭关）一律跳过，自动存档留在更早那份（事件开始前），只有随机遇敌开战前存。
## 回退：EVENT_BATTLES = true（事件里开的战斗也存，busy 不算阻挡，即 11-07 dev.393 的做法）。

static var ON_PAUSE := true
static var CHECKPOINTS := true
static var EVENT_BATTLES := false
## 这么久之内再来的切后台通知当成同一次（PAUSED 和 FOCUS_OUT 前后脚到）。
const DEDUP_MSEC := 3000
## 两次战斗检查点至少隔这么久（总装定 60 秒）
const BATTLE_GAP_MSEC := 60000
static var _last_battle_msec := -1000000

## 上一次的结果（测试看）："saved"、"fail"、"dup"、"skip:<原因>"
static var last_result := ""
static var _last_msec := -1000000


static func reset() -> void:
	_last_msec = -1000000
	_last_battle_msec = -1000000
	last_result = ""


## 地图现在能不能存；"" 是能存，否则是原因。
static func blocker(map) -> String:
	if not XPlatform.is_mobile():
		return "desktop"
	if not ON_PAUSE:
		return "off"
	if map == null or not is_instance_valid(map) or not map.is_inside_tree():
		return "no_map"
	if XState.current == null:
		return "no_state"
	if map._in_battle:
		return "battle"
	if map.busy:
		return "event"
	if map._menu_open:
		return "menu"
	if map.transfer_page != null:
		return "transfer"
	return ""


## 切后台时调（XPlatform.pause_hook，地图 _ready 里挂上）。返回 last_result。
static func on_pause(map, now_msec := Time.get_ticks_msec()) -> String:
	var why := blocker(map)
	if why != "":
		last_result = "skip:" + why
		return last_result
	if now_msec - _last_msec <= DEDUP_MSEC:
		last_result = "dup"
		return last_result
	_last_msec = now_msec
	if XSave.save_auto():
		last_result = "saved"
	else:
		last_result = "fail"
		push_warning("切后台自动存档没写成：" + XSave.auto_path())
	return last_result


## 检查点：进主菜单（"menu"）、开战前（"battle"）调，要在置 _menu_open／_in_battle 之前。
## 返回 last_result："checkpoint:<what>"、"fail" 或 "skip:<原因>"；不占切后台的去重窗口。
static func checkpoint(map, what: String, in_event := false) -> String:
	var why := blocker(map)
	if in_event and why == "event":
		why = ""
	if why == "" and not CHECKPOINTS:
		why = "checkpoints_off"
	if why != "":
		last_result = "skip:" + why
		return last_result
	if XSave.save_auto():
		last_result = "checkpoint:" + what
	else:
		last_result = "fail"
		push_warning("自动存档检查点没写成：" + XSave.auto_path())
	return last_result


## 开战前的检查点：各开战入口在置 busy／开打之前调（in_event＝事件里开的战斗：默认跳过；EVENT_BATTLES 开着时 busy 不算阻挡）。
## 挂机中跳过；距上次战斗检查点不到 BATTLE_GAP_MSEC 也跳过。返回 last_result。
static func battle_checkpoint(map, in_event := false, now_msec := Time.get_ticks_msec()) -> String:
	if in_event and not EVENT_BATTLES:
		last_result = "skip:in_event"
		return last_result
	if XState.current != null and XHangUp.is_active(XState.current):
		last_result = "skip:hangup"
		return last_result
	if now_msec - _last_battle_msec < BATTLE_GAP_MSEC:
		last_result = "skip:recent"
		return last_result
	var r := checkpoint(map, "battle", in_event)
	if r == "checkpoint:battle":
		_last_battle_msec = now_msec
	return r
