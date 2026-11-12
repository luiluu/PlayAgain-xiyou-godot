extends Node
## 地图事件对照（效率改造第二步）：用 MV 参照引擎的 event_probe（generated/oracle/events.json）里同一批用例，
## 以同样的初始状态与应答在 Godot 的 MVInterpreter 上运行，逐项比较可观察的输出（trace）与状态变化（delta）。
## - 宿主是记录用的替身（EventHost）：不开画面、不进战斗，文字/选项/场所移动/战斗/商店/场景/存档/输入/提示只记录并按约定应答
##   （选项默认项，同一组第 4 次起取最后一项；数值 0；输入「测试」；战斗胜利），与 event_probe.cjs 相同。
## - 不比较：移动路线、动画、气泡、画面效果、音频（替身不执行）；参照引擎本身出错或没跑完的用例只列出。
## - 已知不一致登记在 tests/event_compare_baseline.json（用例 → 不一致的项目）：新出现的不一致用例或项目（退步）使测试失败；
##   登记里的用例变一致时提示更新登记（--update-baseline）。
## 参数（-- 之后）：--out=<目录> 写对照报告；--update-baseline 用本次结果重写登记；--only=<前缀,…> 只跑部分用例；
## --coverage=<文件> 另记每例实际执行到的指令（「位置:下标」，位置＝mMeEpP 或 ceN），写成 JSON，给 03_转换工具/事件写法覆盖.py 统计哪些写法有原版对照（eventsreg1）；JSON 里另有 byCase（用例号含 #变体 → 该例执行到的指令），--only 只跑某个变体时分得出是谁走到的。

const ORACLE := "res://modes/xiyou/generated/oracle/events.json"
const ORACLE_STATES := "res://modes/xiyou/generated/oracle/event_states.json"
const BASELINE := "res://tests/event_compare_baseline.json"
## 解释器跳过（认不出）的脚本／指令基线：用例 → {写法键: 次数}。新出现的跳过＝红（审查：解释器整段跳过不能无痕）；--update-baseline 重写
const SKIPPED_BASELINE := "res://tests/event_skipped_baseline.json"
const PARTY := [1, 8, 10, 9]
const MAX_STEPS := 20000
const KNOWN_ORACLE_ERRORS := []
## 随机数按序列循环取的用例（同参照 event_probe.cjs RANDOM_SEQUENCES）：随机伙伴重抽到不重复，固定 0.5 会死循环
const RANDOM_SEQUENCES := {"ce1344": [0.5, 0.1, 0.9, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.05], "m221e3p0": [0.5, 0.1, 0.9, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.05]}

## 分段（tools-compare-split）：全部用例（基础＋有状态变体，按 oracle 里的顺序编号）按序号对 shards 取余分给各场景，本场景只跑 shard 那一份。
## 每个用例都从空白新游戏起跑，互不依赖，所以分开跑与整份跑的逐例结果相同。shards＝1 就是原来的整份单场景（回退办法：场景里改 shards=1 并删掉 _b…等分段场景）。
## 登记重写（--update-baseline）、报告（--out）、覆盖（--coverage、print_coverage）要看全部用例，这几个参数一出现就自动按整份跑（输出与分段前逐字一致）；
## 命令行可用 --shards=N --shard=K 临时改分法。完整性类检查（oracle_cases_complete、分发覆盖、states_*）只在第 0 段做。
@export var shards := 1
@export var shard := 0
var results := []
var _saved_seal_fix := {}
var _saved_gate_fix := {}
var _saved_floor12 := true
var out_dir := ""
var update_baseline := false
var only: Array = []
var coverage_out := ""
var coverage := {}
## 用例号（含 #变体）→ 该例实际执行到的「位置:下标」；coverage 是它们的并集（根游标位置去掉了 #变体，分不出是哪个变体走到的，BK2）
var coverage_by_case := {}
## 云端拿覆盖表用（floor9）：true 时照 --coverage 记，结尾把 executed 分段打到输出（行首「COVERAGE_PART=」），日志里拼回；
## 云端只在失败时上传日志，所以这时故意记一条失败（只给临时场景用）
@export var print_coverage := false


## 记执行到的指令（只在 --coverage 时用）：根游标记用例的页（去掉 #变体），公共事件子游标记 ceN，别的子游标不记
class CoverInterp:
	extends MVInterpreter
	var cover: Dictionary
	var cover_label := ""
	## 记原始下标：MVEventCore._merge_choices 把相邻的「404＋102」从 list 里删掉合成一个菜单，之后的下标都前移 2，
	## 按游标下标记会把合并菜单后段记错位置（m217 晶石工作台约 1300 个实例因此显示没执行到；八戒 interp3）。
	## 在执行前给每条指令记上原始下标（键 COV_I），记覆盖时用它；公共事件子游标在 _make_child 时补记（第一次见到的列表还没合并过）
	const COV_I := "_cov_i"
	static func tag(commands: Array) -> void:
		if commands.is_empty() or (commands[0] as Dictionary).has(COV_I):
			return
		for i in commands.size():
			commands[i][COV_I] = i
	func _make_child(commands: Array) -> MVEventCore:
		tag(commands)
		var sub := CoverInterp.new(host, map_id, event_id, commands)
		sub.cover = cover
		return sub
	func _execute(c: Dictionary):
		var where := cover_label if _depth == 0 else ("ce%d" % common_id if common_id > 0 else "")
		var start := index
		var before := list.duplicate() if where != "" and int(c.code) in [101, 102] else []
		var r = super._execute(c)
		if where != "":
			# 合并菜单删掉的「404＋102」原版也执行到（同一个菜单）：按原始下标补记
			if before.size() > list.size():
				for d in before:
					if not list.any(func(x): return is_same(x, d)):
						cover["%s:%d" % [where, int(d.get(COV_I, -1))]] = true
			# 101 会把紧跟的 401（文字行）和 102／103 合成一条消息一起消费，这些续行下标也算执行到（BK）
			var last := start
			if int(c.code) == 101:
				last = index
			for i in range(start, mini(last, list.size() - 1) + 1):
				cover["%s:%d" % [where, int(list[i].get(COV_I, i))]] = true
		return r


class FakePlayer:
	extends RefCounted
	var transparent := false
	var direction := 2
	var grid := Vector2i.ZERO
	func queue_redraw() -> void:
		pass
	## 门事件里「设置移动路线（玩家）」：参照只记指令序列与状态变化，不对比走位，这里不走
	func force_move_route(_route: Dictionary) -> void:
		pass
	func is_route_forcing() -> bool:
		return false
	## 事件里「显示气泡图标」作用在玩家身上（m158e1p1#a2）：气泡不比较，只别崩
	func start_balloon(_id: int) -> void:
		pass
	func is_balloon_playing() -> bool:
		return false


## 记录用宿主：接口同 XMapScene（MVInterpreter / MVScript 用到的部分）
class EventHost:
	extends Node
	var trace: Array = []
	var seen := {}
	var player := FakePlayer.new()
	## 预设 answers（eventsreg2）：依次应答选项（第几项）与数值输入（填的数），用完回到默认；同 event_state_probe.cjs
	var answers: Array = []

	func show_message(msg: Dictionary) -> int:
		var e := {"t": "msg", "face": str(msg.get("face", "")), "index": int(msg.get("index", 0)), "lines": msg.get("lines", [])}
		var pick := 0
		if msg.has("choices"):
			var sig := JSON.stringify(msg.choices)
			seen[sig] = int(seen.get(sig, 0)) + 1
			pick = msg.choices.size() - 1 if seen[sig] > 3 else (int(msg.default) if int(msg.get("default", -1)) >= 0 else 0)
			if not answers.is_empty():
				pick = clampi(int(answers.pop_front()), 0, msg.choices.size() - 1)
			e.choices = msg.choices
			e.pick = pick
		elif msg.has("digits"):
			e.number = true
			pick = int(answers.pop_front()) if not answers.is_empty() else 0
			e.pick = pick
		if msg.has("choices") or msg.has("digits") or not e.lines.is_empty():
			trace.append(e)
		return pick

	## 脚本里直接加消息（$gameMessage.add，如专属角色招募）：同 101 文字
	func show_text(face: String, idx: int, lines: Array, _background := 0, _position := 2) -> void:
		show_message({"face": face, "index": idx, "lines": lines})

	func transfer(id: int, x: int, y: int, d: int, _fade_type := 0) -> void:
		trace.append({"t": "transfer", "map": id, "x": x, "y": y, "d": d})
		var s := XState.current
		if id != s.map_id:
			s.battleback = []  # 同 map_scene：换图清 283 的设定（MV Game_Map.setup 重设）
		s.map_id = id
		s.x = x
		s.y = y
		if d > 0:
			s.direction = d

	## 预设 battleResult（accept5）：战斗结果 0 胜、1 逃、2 败，同参照 event_state_probe 的战斗回调
	var preset_battle_result := 0

	func start_battle(troop_id: int, can_escape: bool, can_lose: bool) -> int:
		trace.append({"t": "battle", "troop": troop_id, "escape": can_escape, "lose": can_lose})
		return preset_battle_result

	func open_shop(goods: Array, _purchase_only: bool) -> void:
		trace.append({"t": "shop", "goods": goods.map(func(g): return [int(g[0]), int(g[1])])})

	func open_training() -> void:
		trace.append({"t": "scene", "name": "Scene_ActorAttributePlusPoints"})

	func open_warehouse() -> void:
		trace.append({"t": "scene", "name": "Scene_Warehouse"})

	func open_actor_warehouse() -> void:
		trace.append({"t": "scene", "name": "Star_Scene_ActorWarehouse"})

	func open_star_warehouse(save_mode: bool) -> void:
		trace.append({"t": "scene", "name": "Scene_StarSaveWarehouse" if save_mode else "Scene_StarWarehouse"})

	func open_change_clothes() -> void:
		trace.append({"t": "scene", "name": "Scene_ChangeClothes"})

	func open_forget_skill(_actor_id: int) -> void:
		trace.append({"t": "scene", "name": "Star_Scene_ForgetSkill"})

	func open_actor_advanced() -> void:
		trace.append({"t": "scene", "name": "Scene_ActorAdvanced"})

	func open_inlay_book() -> void:
		trace.append({"t": "scene", "name": "Scene_EquipInlayBook"})

	func open_race_menu(_rank := 0) -> void:
		trace.append({"t": "scene", "name": "Scene_CodexBindMenu"})

	func input_text(prompt: String, _default := "") -> String:
		trace.append({"t": "prompt", "text": prompt})
		return "测试"

	func save_game(slot: int) -> bool:
		trace.append({"t": "save", "slot": slot})
		return true

	func toast(text: String) -> void:
		trace.append({"t": "toast", "text": text})

	func return_to_title() -> void:
		trace.append({"t": "scene", "name": "Scene_Title"})

	func game_over() -> void:
		trace.append({"t": "scene", "name": "Scene_Gameover"})

	func set_followers_visible(v: bool) -> void:
		XState.current.followers_visible = v

	func gather_followers() -> void:
		pass

	func refresh_events() -> void:
		pass

	## Game_Interpreter.character：-1 为玩家（朝向同 XState，新游戏朝下）；事件不在替身里
	func character(id: int, _this_event: int):
		if id == -1:
			player.direction = XState.current.direction
			player.grid = Vector2i(XState.current.x, XState.current.y)
			return player
		return null

	## 指令 283：同 map_scene.change_battleback，写 XState.battleback（新观察面记它）
	func change_battleback(name1: String, name2: String) -> void:
		XState.current.battleback = [name1, name2]

	func show_animation(_ch, _anim_id: int):
		return null

	## MV command221/222：淡出/淡入并等待 fadeSpeed（24 帧）
	func fade(_out: bool) -> void:
		for i in range(24):
			await get_tree().process_frame

	## 游戏时间按帧走（同参照引擎每帧先 Graphics.frameCount +1 再跑解释器，playtime = 帧数/60 取整）：
	## 每例开始记第 1 帧（参照第一条指令在 frameCount 1）；之后在 process_frame 信号里先计帧——本节点比解释器的 await 先连上，
	## 等待指令恢复时已计入这一帧，第 k 段等待后是 1＋20k 帧，同参照。按整数帧数换算，不逐帧累加 1/60（120 帧会累加成 1.999…）
	var _frames := 0
	var _base_seconds := 0.0

	func _ready() -> void:
		get_tree().process_frame.connect(_tick)

	func start_frames(s: XState) -> void:
		_base_seconds = s.play_seconds
		_frames = 1
		s.play_seconds = _base_seconds + _frames / 60.0

	func _tick() -> void:
		if XState.current:
			_frames += 1
			XState.current.play_seconds = _base_seconds + _frames / 60.0

	func play_bgm(_a) -> void:
		pass

	func play_bgs(_a) -> void:
		pass

	func play_me(_a) -> void:
		pass

	func play_se(_a) -> void:
		pass


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--update-baseline":
			update_baseline = true
		elif arg.begins_with("--only="):
			only = Array(arg.substr(7).split(",", false))
		elif arg.begins_with("--coverage="):
			coverage_out = arg.substr(11)
		elif arg.begins_with("--shards="):
			shards = int(arg.substr(9))
		elif arg.begins_with("--shard="):
			shard = int(arg.substr(8))
	if print_coverage and coverage_out == "":
		coverage_out = "user://event_compare_coverage.json"
	if update_baseline or out_dir != "" or coverage_out != "" or not only.is_empty():
		shards = 1
		shard = 0
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func _run() -> void:
	GameApp.fast_headless_frames()  # 替身按帧计（游戏时间每帧 1/60 秒、淡入淡出 24 帧），不看真实时间：headless 不睡（82→15 秒，见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_event_compare"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	# 比原版翻译：副本的难度／挂机恢复优化（O-038／O-040）关掉，由 tests/xiyou_dungeon 单独对照
	XDungeon.restore_difficulty = false
	# 大厅全图鉴 NPC 只留怪物图鉴（Kyo 11-12，O-待定·大厅全图鉴 NPC）：比原版翻译时照原版整页，由 tests/xiyou_lobby_debug_npc 单独量
	XLobbyDebugNpc.BOOK_ONLY = false
	XDungeon.restore_hang_up = false
	XDungeon.battle_end_counts = false
	# 死内容做活的数据补丁（一护卍解 Map213、CE2508、CE2478 魔攻；O-184／O-185）：对照原版语义，关掉；补丁本身由 xiyou_floor_odds、xiyou_nanoha 核
	XDeadContent.ICHIGO_BANKAI = false
	XDeadContent.DOMAIN_ALL_MATK = false
	XDeadContent.clear_cache()
	# 漩涡二阶段、苍龙重做与解放（XRift／XCanglong／RELEASE_CANGLONG，优化登记三条）：对照原版语义，关掉；本身由 tests/xiyou_rift2_canglong 核
	XCanglong.original_data()
	# O-120 副本门判定修正（变量 5＝1）：对照原版语义，关掉；修正本身由 tests/xiyou_floor_reach075 核（有状态变体 m23e2p0#s1 咬着这个差异）
	# 只对修正表里那几扇门的用例关（逐用例设，见循环里）；其余用例保持修正生效的真实路径（审查 41 P3-6）
	_saved_seal_fix = MVInterpreter.seal_check_fix
	# O-120（B2）厄运王座宝箱深渊门的修正（提示后改走「离开」分支）：同上，只对修正表里的事件关（eventsreg3 m80e13p2#g3 走到这句提示）
	_saved_gate_fix = MVInterpreter.removed_gate_fix
	# O-076 十二层守层者给 12 成就的修正（原版给 13）：只对 m23e1p0／m65e2p0 两例关（逐用例设，见循环里）；修正本身由成就专项核（events4 快照加了本局成就后咬出 m23e1p0／m65e2p0）
	_saved_floor12 = XAchievement.FLOOR12_FIX
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check("oracle_loaded", oracle is Dictionary and oracle.has("cases"))
	if not (oracle is Dictionary):
		_finish()
		return
	var expected_ids := []
	var manifest: Dictionary = XDB.load_json("manifest.json")
	for id in manifest.slice.maps:
		for ev in XDB.map(int(id)).get("events", []):
			if not ev is Dictionary:
				continue
			for p in ev.pages.size():
				if ev.pages[p].list.any(func(c): return int(c.code) != 0):
					expected_ids.append("m%de%dp%d" % [int(id), int(ev.id), p])
	for id in manifest.slice.commonEvents:
		if XDB.rec("CommonEvents", int(id)).get("list", []).any(func(c): return int(c.code) != 0):
			expected_ids.append("ce%d" % int(id))
	var actual_ids: Array = oracle.cases.map(func(c): return str(c.id))
	expected_ids.sort()
	actual_ids.sort()
	var first_shard := shard == 0
	if first_shard:
		check("oracle_cases_complete", expected_ids == actual_ids, [expected_ids.size(), actual_ids.size()])
		_check_dispatch_cases(manifest)
	var baseline: Dictionary = {}
	if FileAccess.file_exists(BASELINE):
		var b = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		baseline = b if b is Dictionary else {}
	var known: Dictionary = baseline.get("mismatch", {})
	var skipped_baseline: Dictionary = {}
	if FileAccess.file_exists(SKIPPED_BASELINE):
		var sb = JSON.parse_string(FileAccess.get_file_as_string(SKIPPED_BASELINE))
		skipped_baseline = sb.get("cases", {}) if sb is Dictionary else {}
	if first_shard:
		check("skipped_baseline_present", FileAccess.file_exists(SKIPPED_BASELINE) or update_baseline)
	var host := EventHost.new()
	add_child(host)
	var report := []
	var mismatched := {}
	var oracle_errors := []
	# 有状态变体（event_state_probe：同一批事件页，运行前按预设改好初始状态，让新游戏走不到的分支被量到；号为 基础号#tag）
	var all_cases: Array = oracle.cases.duplicate()
	# 文件缺失不能静默跳过变体（审查 41 P2-1：测试通过但变体没比＝空绿）：缺就失败，补量用 07_开发环境/补跑事件状态探针.py（检查.sh／新建工作树.sh 会自动跑）
	if first_shard:
		check("states_present", FileAccess.file_exists(ORACLE_STATES))
	if FileAccess.file_exists(ORACLE_STATES):
		var st = JSON.parse_string(FileAccess.get_file_as_string(ORACLE_STATES))
		if first_shard:
			check("states_loaded", st is Dictionary and st.has("cases"))
		if st is Dictionary and st.has("cases"):
			all_cases.append_array(st.cases)
			if first_shard:
				check("states_cases_present", st.cases.size() > 0)
	for case_index in all_cases.size():
		var c: Dictionary = all_cases[case_index]
		if shards > 1 and case_index % shards != shard:
			continue
		if not only.is_empty() and not only.any(func(p): return str(c.id).begins_with(p)):
			continue
		# 参照引擎出错或没跑完（如随机数固定后「抽到不同的为止」的循环）的用例不比较，只列出
		if c.has("errors") or not bool(c.get("finished", true)):
			oracle_errors.append(c.id)
			continue
		# 有状态变体：跨存档变量（899／900／1000／1476…）的全局存储，参照侧每例都从第一次开局的快照起跑（event_state_probe
		# NEW_GAME_SNAPSHOT 只在第一例真开局，之后换回开局时的 $gameVariables），前一例设的跨存档变量带不进下一例；
		# 这边每个变体前都清空存储，两边才一致（accept1 可优化，events6：之前只在第一个变体前清，m4e56p0#b1 预设 1476 带进 m158e1p1#a2）。
		# 基础用例的历史两边本来就同序，不清
		if str(c.id).contains("#"):
			DirAccess.remove_absolute(XGlobalVars.path())
			XGlobalVars._loaded_path = "<unloaded>"
		var door := RegEx.create_from_string("^m(\\d+)e(\\d+)p").search(str(c.id))
		MVInterpreter.seal_check_fix = {} if door != null and _saved_seal_fix.has("%s:%s" % [door.get_string(1), door.get_string(2)]) else _saved_seal_fix
		MVInterpreter.removed_gate_fix = {} if door != null and _saved_gate_fix.has("%s:%s" % [door.get_string(1), door.get_string(2)]) else _saved_gate_fix
		# O-076 只对两张十二层守层者的用例关（审查 42 P3-4），其余用例保持修正生效
		XAchievement.FLOOR12_FIX = _saved_floor12 and not (str(c.id).begins_with("m23e1p0") or str(c.id).begins_with("m65e2p0"))
		var got := await _run_case(c, host)
		var diffs := _compare(c, got)
		var row := {"id": c.id, "ok": diffs.is_empty(), "diffs": diffs, "skipped": got.skipped, "aborted": got.aborted}
		report.append(row)
		if not diffs.is_empty():
			mismatched[c.id] = diffs.map(func(d): return d.split(":")[0])
	var ok_count := report.filter(func(r): return r.ok).size()
	# 跳过基线：本次各用例的跳过写法（键＝指令码＋原文前 40 字）；基线里没有的＝新增跳过
	var skipped_now := {}
	for r in report:
		if not r.skipped.is_empty():
			skipped_now[r.id] = r.skipped
	var new_skips := []
	for id in skipped_now:
		for k in skipped_now[id]:
			if not skipped_baseline.get(id, {}).has(k):
				new_skips.append("%s | %s" % [id, k])
	var gone_skips := 0
	for id in skipped_baseline:
		if report.any(func(r): return r.id == id):
			for k in skipped_baseline[id]:
				if not skipped_now.get(id, {}).has(k):
					gone_skips += 1
	print("EVENT_SKIPPED ", JSON.stringify({"cases": skipped_now.size(), "keys": skipped_now.values().reduce(func(a, v): return a + v.size(), 0), "new": new_skips.size(), "noLongerSkipped": gone_skips}))
	for n in new_skips.slice(0, 30):
		print("NEW_SKIP ", n)
	# 退步：登记外的用例不一致，或登记内的用例出现登记外的不一致项目（trace/variables/…）
	var regressions := mismatched.keys().filter(func(id):
		return not known.has(id) or mismatched[id].any(func(k): return not known[id].has(k)))
	var fixed := known.keys().filter(func(id): return not mismatched.has(id) and report.any(func(r): return r.id == id))
	print("EVENT_COMPARE ", JSON.stringify({"cases": report.size(), "match": ok_count, "mismatch": mismatched.size(),
		"oracleErrors": oracle_errors, "regressions": regressions, "nowMatching": fixed}))
	for id in regressions:
		print("REGRESSION ", id, " ", report.filter(func(r): return r.id == id)[0].diffs.slice(0, 3))
	if update_baseline and only.is_empty():
		var f := FileAccess.open(ProjectSettings.globalize_path(BASELINE), FileAccess.WRITE)
		# 说明照登记里原有的写（各例的理由是人写的），没有登记时用默认说明
		f.store_string(JSON.stringify({"note": str(baseline.get("note", "地图事件对照的已知不一致（tests/xiyou_event_compare 写入；--update-baseline 重写）。值为不一致的项目。现存 1 例：m4e73p0 商店向导「战力短板」一段来自 CodexZones 五乘区预算，按数值平衡不移植（O-044／O-050）。")),
			"source": str(oracle.get("sourceIdentity", {}).get("releaseVersion", "")), "match": ok_count, "cases": report.size(), "mismatch": mismatched}, "\t", true))
		f.close()
	if update_baseline and only.is_empty():
		var fs := FileAccess.open(ProjectSettings.globalize_path(SKIPPED_BASELINE), FileAccess.WRITE)
		fs.store_string(JSON.stringify({"note": "地图事件对照里解释器跳过（认不出）的脚本／指令（tests/xiyou_event_compare 写入；--update-baseline 重写）。键＝指令码＋原文前 40 字。新增＝红；补好解释器后用 --update-baseline 删。全库写法清单另见 tests/fixtures/script_census_known.json（脚本普查）。",
			"cases": skipped_now}, "\t", true))
		fs.close()
	if out_dir != "":
		_write_report(report, oracle_errors)
	if coverage_out != "":
		var fc := FileAccess.open(coverage_out, FileAccess.WRITE)
		var keys := coverage.keys()
		keys.sort()
		fc.store_string(JSON.stringify({"note": "xiyou_event_compare --coverage：对照里实际执行到的指令（位置:下标）", "executed": keys, "byCase": coverage_by_case}))
		fc.close()
		if print_coverage:
			for i in range(0, keys.size(), 2000):
				print("COVERAGE_PART=", JSON.stringify(keys.slice(i, i + 2000)))
			# 云端只在失败时上传日志：这个场景故意记一条失败，好把覆盖表带回来（只给 _cov 临时场景用，不进常规名单）
			check("coverage_printed_upload_log", false, keys.size())
	check("no_new_skipped", new_skips.is_empty() or update_baseline, new_skips.slice(0, 20))
	check("no_regressions", regressions.is_empty() or update_baseline, regressions)
	check("preset_keys_known", bad_preset_keys.is_empty(), bad_preset_keys)
	check("no_new_oracle_errors", oracle_errors.all(func(id): return KNOWN_ORACLE_ERRORS.has(id)), oracle_errors)
	check("cases_ran", report.size() > 0)
	_finish()


## 地图事件分发（Codex 审查第 11、12 项）：上面的用例只单独执行一页的指令，量不到并行页每帧重起、换页终止、自主移动。
## 这些由 tests/xiyou_map_dispatch 在真实地图场景逐帧对照 map_dispatch_oracle（mv_oracle/map_dispatch_probe.cjs）。这里守住覆盖面：
## 切片里每个并行页（触发 4）都要有 par.m<地图>e<事件> 用例；自主路线（移动类型 3）与强制路线（205）用到的移动指令都要是 MVCharacter 认得的，
## 路线脚本（45）只认 YEP_EventChasePlayer 的「this._fleeRange = N」类设定。新出现的并行页或新写法会在这里变红，去补探针用例或实现。
const DISPATCH_ORACLE := "res://tests/fixtures/map_dispatch_oracle.json"
const DISPATCH_ROUTE_CODES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
	29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 44, 45]

func _check_dispatch_cases(manifest: Dictionary) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DISPATCH_ORACLE))
	var ids: Array = d.cases.map(func(c): return str(c.id)) if d is Dictionary else []
	var missing := []
	var bad_codes := {}
	var bad_scripts := []
	var re := RegEx.create_from_string("^\\s*this\\._(fleeRange|fleeSpeed|sightLock|returnWait|seePlayer|returnAfter|alertBalloon)\\s*=")
	var scan_route := func(route) -> void:
		if not route is Dictionary:
			return
		for cmd in route.get("list", []):
			if not DISPATCH_ROUTE_CODES.has(int(cmd.code)):
				bad_codes[int(cmd.code)] = true
			elif int(cmd.code) == 45 and re.search(str(cmd.parameters[0])) == null:
				bad_scripts.append(str(cmd.parameters[0]))
	for id in manifest.slice.maps:
		for ev in XDB.map(int(id)).get("events", []):
			if not ev is Dictionary:
				continue
			for pg in ev.pages:
				if int(pg.trigger) == 4 and pg.list.any(func(c): return int(c.code) != 0):
					var key := "par.m%de%d" % [int(id), int(ev.id)]
					if not ids.any(func(x): return x.begins_with(key)):
						missing.append(key)
				if int(pg.moveType) == 3:
					scan_route.call(pg.moveRoute)
				for c in pg.list:
					if int(c.code) == 205:
						scan_route.call(c.parameters[1])
	check("dispatch_parallel_pages_covered", d is Dictionary and missing.is_empty(), missing)
	check("dispatch_route_codes_known", bad_codes.is_empty(), bad_codes.keys())
	check("dispatch_route_scripts_known", bad_scripts.is_empty(), bad_scripts)


func _finish() -> void:
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XGlobalVars.path())
	XGlobalVars._loaded_path = "<unloaded>"
	MVInterpreter.seal_check_fix = _saved_seal_fix
	MVInterpreter.removed_gate_fix = _saved_gate_fix
	XAchievement.FLOOR12_FIX = _saved_floor12
	DirAccess.remove_absolute(XSave.dir())
	MVInterpreter.max_steps = 0
	MVInterpreter.fixed_random = -1.0
	MVInterpreter.random_sequence = []
	XDungeon.restore_difficulty = true
	XDungeon.restore_hang_up = true
	XDungeon.battle_end_counts = true
	XDungeon.battle = {}
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _run_case(c: Dictionary, host: EventHost) -> Dictionary:
	var s := XState.new_game_blank()
	s.difficulty = 3
	for id in PARTY:
		s.add_actor(id)
	s.map_id = int(c.map)
	# 参照把玩家放在事件所在格（公共事件在大厅 0,0）：藏宝图等脚本读玩家坐标
	s.x = 0
	s.y = 0
	XState.current = s
	host.trace = []
	host.seen = {}
	var list: Array
	if str(c.kind) == "common":
		list = XDB.rec("CommonEvents", int(c.common)).get("list", []).duplicate(true)
	else:
		var ev = null
		for e in XDB.map(int(c.map)).get("events", []):
			if e is Dictionary and int(e.id) == int(c.event):
				ev = e
		list = ev.pages[int(c.page)].list.duplicate(true) if ev != null else []
		if ev != null:
			s.x = int(ev.x)
			s.y = int(ev.y)
	# 第一条仓库指令就是 show 的页（如青霞第 2 页，正常流程里仓库已由第 1 页建好）：参照探针先建好默认仓库，这边同样
	for cmd in list:
		if int(cmd.code) == 356 and str(cmd.parameters[0]).begins_with("PHWarehouse "):
			if str(cmd.parameters[0]).begins_with("PHWarehouse show "):
				XWarehouse.create(s, str(cmd.parameters[0]).substr(len("PHWarehouse show ")))
			break
	XHangUp.started_flag = false   # 参照每例把挂机标记换回开局值（运行期全局，不随新局清）
	_apply_preset(s, c.get("preset", {}))
	host.preset_battle_result = int(c.get("preset", {}).get("battleResult", 0))
	XDungeon.battle = {}       # $gameTroop 每例新游戏都是空的
	s.orb_seed = 2147483648    # 参照固定 Math.random＝0.5 后开新局：宝珠随机流种子 floor(0.5×2³²)
	var watch := _watch_actors(list)
	XConfig.achievements().clear()   # 同上：全局成就记录（物品成就只在全局还没有时触发）
	XConfig.designations().clear()   # 参照每例 ConfigManager.applyData({}) 重置称号
	XConfig.designations()   # ensure_loaded；漩涡过场播过的键同样每例清空（不清时前一例 mark('rift1') 让整份跑里的 m4e76p0 门关上，分段甲 a4）
	(XConfig._values.codexWhisperSeen as Array).clear()
	# cc 地图页 m5：预设 designations＝已解锁的称号号（同参照 ConfigManager.DesignationN[N] = true），放在上面每例清空之后
	for id in c.get("preset", {}).get("designations", []):
		XConfig.designations()[str(int(id))] = true
	var before := _snap(s, watch)
	MVInterpreter.max_steps = MAX_STEPS
	MVInterpreter.fixed_random = 0.5
	MVInterpreter.random_sequence = RANDOM_SEQUENCES.get(str(c.id), [])  # 同参照 event_probe 的 RANDOM_SEQUENCES
	var preset: Dictionary = c.get("preset", {})
	if preset.has("random_seq"):
		MVInterpreter.random_sequence = (preset.random_seq as Array).map(func(x): return float(x))  # 预设 random_seq（eventsreg2，键名同 accept5），同参照
	host.answers = (preset.get("answers", []) as Array).duplicate()
	MVInterpreter._sequence_at = 0
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp: MVInterpreter
	if coverage_out != "":
		CoverInterp.tag(list)
		var ci := CoverInterp.new(host, int(c.map), int(c.event), list)
		var case_cover := {}
		ci.cover = case_cover
		ci.cover_label = str(c.id).get_slice("#", 0)
		interp = ci
	else:
		interp = MVInterpreter.new(host, int(c.map), int(c.event), list)
	host.start_frames(s)
	await interp.run()
	if coverage_out != "":
		var case_keys: Array = interp.cover.keys()
		case_keys.sort()
		coverage_by_case[str(c.id)] = case_keys
		for k in case_keys:
			coverage[k] = true
	var skipped := {}
	for k in interp.skipped:
		var key := "%d %s" % [int(k.code), str(k.text).left(40)]
		skipped[key] = int(skipped.get(key, 0)) + 1
	return {"trace": host.trace.duplicate(true), "delta": _delta(before, _snap(XState.current, watch)), "skipped": skipped, "aborted": MVInterpreter.aborted}


## 有状态变体的初始状态（同 event_state_probe.cjs applyPreset，顺序相同）
## 预设键白名单（同参照 event_state_probe.cjs PRESET_KEYS）：不认识的键记下来，测试红（审查 49）
const PRESET_KEYS := ["difficulty", "party", "actors", "answers", "armors", "battleResult", "dead", "defeats", "gold", "items", "maxLevel", "playerDirection", "playtime", "random_seq", "selfSwitches", "switches", "variables", "weapons", "hangUp", "designations"]
## cc 分段甲 a6：actors.N 下认的子键（同参照 ACTOR_PRESET_KEYS）；不认识的记成坏键「actors.N.键」
const ACTOR_PRESET_KEYS := ["level", "skills", "forget", "armors", "weapons", "paramPlus", "hp", "mp", "states"]
var bad_preset_keys := []

func _apply_preset(s: XState, p: Dictionary) -> void:
	if p.is_empty():
		return
	for k in p.keys():
		if not PRESET_KEYS.has(k) and not bad_preset_keys.has(k):
			bad_preset_keys.append(k)
	if p.has("difficulty"):
		s.difficulty = int(p.difficulty)
	for id in p.get("party", []):
		s.add_actor(int(id))
	# cc 分段甲 a3：等级上限（同参照「maxlevel equal N」），在角色等级之前摆
	if p.has("maxLevel"):
		s.actor_max_level = int(p.maxLevel)
	for id in p.get("actors", {}):
		var a := s.actor(int(id))
		var spec: Dictionary = p.actors[id]
		for k in spec.keys():
			var bad := "actors.%s.%s" % [id, k]
			if not ACTOR_PRESET_KEYS.has(k) and not bad_preset_keys.has(bad):
				bad_preset_keys.append(bad)
		if spec.has("level"):
			a.change_level_mv(int(spec.level))
		for sk in spec.get("skills", []):
			a.learn_skill(int(sk))
		for sk in spec.get("forget", []):  # actors.N.forget：忘掉开局就会的技能，同参照 forgetSkill
			a.forget_skill(int(sk))
		# 八戒 DR：actors.N.armors＝直接穿上的防具底材，同参照 forceChangeEquip（etype 对应的第一个槽，不看能否装备、不进背包）
		var gears := []
		for ar in spec.get("armors", []):
			gears.append(XActor.make_equip("armor", int(ar)))
		for wp in spec.get("weapons", []):  # actors.N.weapons：同参照，武器（etype 1）
			gears.append(XActor.make_equip("weapon", int(wp)))
		for item in gears:
			var slot := a.equip_slots().find(int(item.get("etypeId", -1)))
			if slot >= 0:
				a.equips[slot] = item
				a.refresh_passive()
				a.release_unequippable()
				a.refresh_passive()
		# cc 分段甲 a6：角色状态门，同参照顺序（能力 → 状态 → HP → MP）。paramPlus 同指令 317（XParamPlus.add 后夹 HP／MP）；
		# states 同 Game_Battler.addState（死者不加，同 mv_script 的 addState 整段）；hp／mp 同 setHp／setMp（refresh 夹到上限）
		for i in spec.get("paramPlus", {}):
			XParamPlus.add(s, int(id), int(i), float(spec.paramPlus[i]))
			a.hp = minf(a.hp, a.mhp)
			a.mp = minf(a.mp, a.mmp)
		for st in spec.get("states", []):
			if not a.state_ids.has(1):
				a.add_state(int(st))
		if spec.has("hp"):
			a.hp = clampf(float(spec.hp), 0.0, a.mhp)
			a.refresh_resources()
		if spec.has("mp"):
			a.mp = clampf(float(spec.mp), 0.0, a.mmp)
			a.refresh_resources()
	if p.has("gold"):
		s.gold = int(p.gold)
	for id in p.get("items", {}):
		s.gain_item(int(id), int(p.items[id]))
	for id in p.get("weapons", {}):
		s.gain_gear("weapon", int(id), int(p.weapons[id]))
	for id in p.get("armors", {}):
		s.gain_gear("armor", int(id), int(p.armors[id]))
	for k in p.get("switches", {}):
		s.set_switch(int(k), bool(p.switches[k]))
	for k in p.get("variables", {}):
		s.set_variable(int(k), float(p.variables[k]))
	for id in p.get("defeats", {}):
		for _i in int(p.defeats[id]):
			XEnemyBook.add_defeat(s, int(id))
	for id in p.get("dead", []):
		var dead_actor := s.actor(int(id))
		dead_actor.hp = 0.0
		dead_actor.refresh_resources()  # 同 MV setHp(0)：refresh 挂死亡状态
	for k in p.get("selfSwitches", {}):
		s.self_switches[str(k)] = bool(p.selfSwitches[k])
	# cc 地图页 m5：预设 hangUp＝正在挂机（参照设 XdRsData.hangUp.GuaJiStartBettleOk），开守层者「你正在挂机」门。
	# 这里摆成挂机中（原点取玩家位置），同时设原版标记，GATE_ACTIVE_ONLY 两支都开门
	if p.has("hangUp") and bool(p.hangUp):
		s.hang_up_active = true
		s.hang_up_origin = Vector2i(maxi(s.x, 0), maxi(s.y, 0))
		XHangUp.started_flag = true
	if p.has("playerDirection"):
		s.direction = int(p.playerDirection)  # accept5：同参照 $gamePlayer.setDirection
	if p.has("playtime"):
		# tools75：游玩秒数，同参照 Graphics.frameCount＝秒×60；host.start_frames 以它为起点。只收非负整数秒（参照侧报错），别的记成坏键
		var pt := float(p.playtime)
		if pt < 0.0 or pt != floorf(pt):
			bad_preset_keys.append("playtime=%s" % p.playtime)
		else:
			s.play_seconds = pt


# ---- 状态快照与变化（与 event_probe.cjs 的 snap/delta 同一结构） ----
## 观察面扩充（events3）：指令点名的队伍外角色也进快照；规则同 event_probe.cjs 的 watchActors
func _watch_actors(list: Array, depth: int = 0, out: Array = []) -> Array:
	var re := RegEx.new()
	re.compile("\\$gameActors\\.actor\\((\\d+)\\)")
	for cmd in list:
		var code := int(cmd.code)
		var p: Array = cmd.get("parameters", [])
		var id := -1
		if code >= 311 and code <= 318:
			if p.size() > 1 and int(p[0]) == 0:
				id = int(p[1])
		elif code in [129, 319, 320, 321, 324, 325]:
			id = int(p[0])
		elif code == 355 or code == 655:
			if str(p[0]).contains("$dataActors.length") or str(p[0]).contains("$gameActors.length"):
				for n in range(1, XDB.table("Actors").size()):
					if not str(XDB.rec("Actors", n).get("name", "")).is_empty() and not out.has(n):
						out.append(n)
			for m in re.search_all(str(p[0])):
				var n := int(m.get_string(1))
				if not out.has(n):
					out.append(n)
		elif code == 117 and depth < 4:
			_watch_actors(XDB.rec("CommonEvents", int(p[0])).get("list", []), depth + 1, out)
		if id >= 0 and not out.has(id):
			out.append(id)
	return out.filter(func(i): return i >= 1 and XDB.rec("Actors", i).size() > 0)


func _snap(s: XState, watch: Array = []) -> Dictionary:
	var sw := {}
	for k in s.switches:
		if s.switches[k]:
			sw[str(k)] = true
	var vars := {}
	for k in s.variables:
		var v = s.variables[k]
		if v is float or v is int:
			if float(v) != 0.0:
				vars[str(k)] = float(v)
		elif str(v) != "":
			vars[str(k)] = str(v)
	var ss := {}
	for k in s.self_switches:
		if s.self_switches[k]:
			ss[str(k)] = true
	var items := {}
	for k in s.items:
		if int(s.items[k]) != 0:
			items[str(k)] = int(s.items[k])
	var weapons := {}
	var armors := {}
	for g in s.gear:
		var table: Dictionary = weapons if str(g.get("kind", "")) == "weapon" else armors
		var base := str(int(g.get("base", 0)))
		table[base] = int(table.get(base, 0)) + 1
	var actors := {}
	var ids: Array = Array(s.party).duplicate()
	for id in watch:
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		var a := s.actor(id)
		var skills := Array(a.skill_ids).duplicate()
		skills.sort()
		actors[str(id)] = {"name": a.display_name(), "level": a.level, "classId": a.class_id, "skills": skills, "states": _sorted_ints(a.state_ids),
			"hp": a.hp, "mp": a.mp, "paramPlus": _param_plus_row(s, id)}
	var flags := {}
	for k in s.flags:
		if str(k).begins_with("DCultyL"):
			flags[str(k)] = bool(s.flags[k])
		elif str(k) == "SaveGameId":
			flags[str(k)] = float(s.flags[k])
	return {"switches": sw, "variables": vars, "selfSwitches": ss, "gold": s.gold, "items": items, "weapons": weapons, "armors": armors,
		"party": Array(s.party).duplicate(), "actors": actors, "difficulty": s.difficulty, "encounter": s.encounter_enabled,
		"followers": s.followers_visible, "actorName": s.actor_name, "actorMaxLevel": s.actor_max_level, "flags": flags,
		"designations": _true_keys(XConfig.designations()), "achievements": _true_keys(s.achievements, true),
		"screen": s.screen.target_snapshot(),
		"battleback": _effective_battleback(s)}


## MV 的 $gameMap._battleback1Name／2Name：283 设过用设的；否则（Game_Map.setupBattleback）地图指定了战斗背景用地图的，没指定为空。
## Godot 把「283 的覆盖」与「地图指定」分开存（开战时才合，map_scene.battle_map），这里按同样的优先级合成再比
func _effective_battleback(s: XState) -> Array:
	if s.battleback.size() == 2:
		return [str(s.battleback[0]), str(s.battleback[1])]
	var m := XDB.map(s.map_id)
	if bool(m.get("specifyBattleback", false)):
		return [str(m.get("battleback1Name", "")), str(m.get("battleback2Name", ""))]
	return ["", ""]


## 指令 317 累计的能力加成（八项；没改过＝全 0，同参照 _paramPlus 初值）
func _param_plus_row(s: XState, id: int) -> Array:
	var row = s.mv_param_plus.get(str(id))
	var out := []
	for i in 8:
		out.append(float(row[i]) if row is Array and row.size() > i else 0.0)
	return out


func _sorted_ints(a: Array) -> Array:
	var out := Array(a).duplicate()
	out.sort()
	return out


## 字典里值为真的键（字符串，按字符串序，同参照 Object.keys().sort()）；skip_time：丢掉「<ID>Time」
func _true_keys(d: Dictionary, skip_time := false) -> Array:
	var out := []
	for k in d:
		if d[k] and not (skip_time and str(k).ends_with("Time")):
			out.append(str(k))
	out.sort()
	return out


func _map_delta(a: Dictionary, b: Dictionary, empty) -> Dictionary:
	var out := {}
	var keys := a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var x = a.get(k, empty)
		var y = b.get(k, empty)
		if JSON.stringify(x) != JSON.stringify(y):
			out[k] = (float(y) - float(x)) if empty is int and (x is int or x is float) and (y is int or y is float) else y
	return out


func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {}
	var put := func(k: String, v):
		if v is Dictionary and v.is_empty():
			return
		d[k] = v
	put.call("switches", _map_delta(a.switches, b.switches, false))
	put.call("variables", _map_delta(a.variables, b.variables, 0))
	put.call("selfSwitches", _map_delta(a.selfSwitches, b.selfSwitches, false))
	if a.gold != b.gold:
		d.gold = float(b.gold - a.gold)
	for k in ["items", "weapons", "armors"]:
		put.call(k, _map_delta(a[k], b[k], 0))
	if JSON.stringify(a.party) != JSON.stringify(b.party):
		d.party = b.party
	var actors := {}
	for id in b.actors:
		var x: Dictionary = a.actors.get(id, {})
		var y: Dictionary = b.actors[id]
		var ch := {}
		for f in y:
			if JSON.stringify(x.get(f)) != JSON.stringify(y[f]):
				ch[f] = y[f]
		if not ch.is_empty():
			actors[id] = ch
	put.call("actors", actors)
	for k in ["difficulty", "encounter", "followers", "actorName", "actorMaxLevel"]:
		if a[k] != b[k]:
			d[k] = b[k]
	put.call("flags", _map_delta(a.flags, b.flags, null))
	for k in ["designations", "achievements", "battleback"]:
		if JSON.stringify(a[k]) != JSON.stringify(b[k]):
			d[k] = b[k]
	if JSON.stringify(a.screen) != JSON.stringify(b.screen):
		d.screen = b.screen
	return d


# ---- 比较 ----
## JSON 往返后比较（数字一律浮点，键一律字符串）
static func _norm(v):
	return JSON.parse_string(JSON.stringify(v))


func _trace_norm(trace: Array) -> Array:
	return trace.map(func(e):
		var x: Dictionary = e.duplicate(true)
		if x.t == "msg" and x.has("number"):
			x.number = true
		if x.t == "transfer":
			x.erase("d")
		if x.t == "msg" and x.has("choices"):
			# 选项里的控制符：原版脚本拼的选项直接带 ESC（\x1b，即 convertEscapeCharacters 之后的写法，如称号选项 \x1bI[0]），
			# 重制写成反斜杠；显示时两者一样，比较前统一成反斜杠（悟空 dmg2，m4e1p2／p3）
			x.choices = (x.choices as Array).map(func(t): return str(t).replace(char(27), "\\"))
		return _norm(x))


func _compare(c: Dictionary, got: Dictionary) -> Array:
	var diffs := []
	var want_trace := _trace_norm(c.trace)
	# O-027／O-062：落点修正是有意的优化，参照里的原版落点按同一张表换算后再比
	for e in want_trace:
		if e.t == "transfer":
			var to: Vector2i = MVInterpreter.TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [int(c.map), int(c.get("event", 0)), int(e.map), int(e.x), int(e.y)], Vector2i(int(e.x), int(e.y)))
			e.x = float(to.x)
			e.y = float(to.y)
	var got_trace := _trace_norm(got.trace)
	for i in range(maxi(want_trace.size(), got_trace.size())):
		var w = want_trace[i] if i < want_trace.size() else null
		var g = got_trace[i] if i < got_trace.size() else null
		if JSON.stringify(w) != JSON.stringify(g):
			diffs.append("trace:%d 原版 %s ｜ Godot %s" % [i, JSON.stringify(w).left(160), JSON.stringify(g).left(160)])
			break
	var want_delta: Dictionary = _norm(c.delta)
	# O-085：精魂下限是 0（原版可扣成负数）。两边每例都从新局 0 精魂起，原版净扣成负数的，重制夹在 0、差量为空
	# （ce823／ce824 裴钱扣 500、m189e1p0 扣 99999999）。先扣成负数再加回来的写法会照旧报不一致，到时再看
	# 预设给了精魂的变体：起点不是 0，只有净扣后真的低于 0 才算夹在 0（m4e10p0#b2 预设 1000 精魂、扣 1000 并未触底）
	if XState.GOLD_FLOOR_ZERO and float(want_delta.get("gold", 0.0)) + float(c.get("preset", {}).get("gold", 0.0)) < 0.0:
		want_delta.erase("gold")
	var got_delta: Dictionary = _norm(got.delta)
	var keys := want_delta.keys()
	for k in got_delta.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		if JSON.stringify(want_delta.get(k)) != JSON.stringify(got_delta.get(k)):
			diffs.append("%s: 原版 %s ｜ Godot %s" % [k, JSON.stringify(want_delta.get(k)).left(200), JSON.stringify(got_delta.get(k)).left(200)])
	if got.aborted:
		diffs.append("aborted: Godot 超过 %d 步" % MAX_STEPS)
	return diffs


func _write_report(report: Array, oracle_errors: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("事件对照.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": report, "oracleErrors": oracle_errors}, "\t"))
	f.close()
	var lines := ["# 地图事件对照报告", "", "一致 %d / %d；参照引擎出错或未结束 %d：%s" % [report.filter(func(r): return r.ok).size(), report.size(), oracle_errors.size(), ", ".join(oracle_errors)], ""]
	var kinds := {}
	var skip_total := {}
	for r in report:
		for d in r.diffs:
			var k := str(d).split(":")[0]
			kinds[k] = int(kinds.get(k, 0)) + 1
		for k in r.skipped:
			skip_total[k] = int(skip_total.get(k, 0)) + int(r.skipped[k])
	lines.append("## 不一致项目分布")
	for k in kinds:
		lines.append("- %s：%d 个用例" % [k, kinds[k]])
	lines.append("")
	lines.append("## Godot 跳过的指令（按次数）")
	var sk := skip_total.keys()
	sk.sort_custom(func(a, b): return skip_total[a] > skip_total[b])
	for k in sk.slice(0, 60):
		lines.append("- %d × %s" % [skip_total[k], k])
	lines.append("")
	lines.append("## 不一致的用例")
	for r in report:
		if not r.ok:
			lines.append("- **%s**" % r.id)
			for d in r.diffs:
				lines.append("  - " + str(d))
	f = FileAccess.open(out_dir.path_join("事件对照.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
